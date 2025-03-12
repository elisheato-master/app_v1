package com.example.app_v1

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import kotlinx.coroutines.*
import java.util.concurrent.TimeUnit

class LocationService : Service() {
    private val TAG = "LocationService"
    private val NOTIFICATION_CHANNEL_ID = "location_tracking_channel"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_NAME = "com.example.app_v1/location_channel"
    
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationRequest: LocationRequest
    private lateinit var locationCallback: LocationCallback
    
    private var groupName: String = ""
    private var userName: String = ""
    
    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.IO + serviceJob)
    
    private var lastLocation: Location? = null
    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createLocationRequest()
        createLocationCallback()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            groupName = intent.getStringExtra("groupName") ?: ""
            userName = intent.getStringExtra("userName") ?: ""
            val dartCallbackHandle = intent.getLongExtra("dartCallbackHandle", 0)
            Log.d(TAG, "Service started with groupName: $groupName, userName: $userName")
            
            if (dartCallbackHandle != 0L) {
                initFlutterEngine(dartCallbackHandle)
            }
        }
        
        startForeground()
        startLocationUpdates()
        startPeriodicUpdates()
        
        return START_STICKY
    }

    private fun initFlutterEngine(callbackHandle: Long) {
        serviceScope.launch {
            try {
                val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
                if (callbackInfo == null) {
                    Log.e(TAG, "Failed to lookup callback")
                    return@launch
                }
                
                flutterEngine = FlutterEngine(this@LocationService)
                flutterEngine?.dartExecutor?.executeDartCallback(
                    DartExecutor.DartCallback(
                        applicationContext.assets,
                        FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                        callbackInfo
                    )
                )
                
                methodChannel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL_NAME)
                
                // Initialize the MongoDB connection via Flutter
                val params = HashMap<String, Any>()
                params["groupName"] = groupName
                params["userName"] = userName
                withContext(Dispatchers.Main) {
                    methodChannel?.invokeMethod("initializeDatabase", params)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing Flutter engine", e)
            }
        }
    }

    private fun createLocationRequest() {
        locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10000)
            .setWaitForAccurateLocation(false)
            .setMinUpdateIntervalMillis(5000)
            .setMaxUpdateDelayMillis(15000)
            .build()
    }

    private fun createLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                for (location in locationResult.locations) {
                    lastLocation = location
                    Log.d(TAG, "Location: ${location.latitude}, ${location.longitude}")
                }
            }
        }
    }

    private fun startLocationUpdates() {
        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission not granted", e)
        }
    }

    private fun startPeriodicUpdates() {
        serviceScope.launch {
            while (isActive) {
                try {
                    delay(2 * 60 * 1000) // 2 minutes
                    lastLocation?.let { sendLocationToFlutter(it) }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in periodic updates", e)
                }
            }
        }
    }

    private fun sendLocationToFlutter(location: Location) {
        serviceScope.launch {
            try {
                Log.d(TAG, "Sending location to Flutter for MongoDB storage")
                
                val locationData = HashMap<String, Any>()
                locationData["latitude"] = location.latitude
                locationData["longitude"] = location.longitude
                locationData["timestamp"] = System.currentTimeMillis()
                locationData["accuracy"] = location.accuracy
                locationData["provider"] = location.provider
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    locationData["verticalAccuracy"] = location.verticalAccuracyMeters
                }
                
                withContext(Dispatchers.Main) {
                    methodChannel?.invokeMethod("saveLocation", locationData)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending location to Flutter", e)
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Used for tracking location in the background"
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startForeground() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Location Tracking")
            .setContentText("Tracking location in background")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        fusedLocationClient.removeLocationUpdates(locationCallback)
        serviceJob.cancel()
        flutterEngine?.destroy()
        Log.d(TAG, "Service destroyed")
    }
}
