class LocationModel {
  final double latitude;
  final double longitude;
  final int timestamp;
  final double accuracy;
  final String provider;
  final double? verticalAccuracy;

  LocationModel({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.provider,
    this.verticalAccuracy,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'accuracy': accuracy,
      'provider': provider,
    };
    
    if (verticalAccuracy != null) {
      data['verticalAccuracy'] = verticalAccuracy;
    }
    
    return data;
  }

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: json['latitude'],
      longitude: json['longitude'],
      timestamp: json['timestamp'],
      accuracy: json['accuracy'],
      provider: json['provider'],
      verticalAccuracy: json['verticalAccuracy'],
    );
  }
}
