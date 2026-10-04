class Earthquake {
  final String id, source, place;
  final double? magnitude, latitude, longitude, depthKm, distanceKm, mmi;
  final int? timeEpoch;
  final String? magType;
  final dynamic tsunami;
  const Earthquake({required this.id,required this.source,required this.place,this.magnitude,this.latitude,this.longitude,this.depthKm,this.distanceKm,this.mmi,this.timeEpoch,this.magType,this.tsunami});
  factory Earthquake.fromJson(Map<String,dynamic> j)=>Earthquake(id:'${j['id']??''}',source:'${j['source']??''}',place:'${j['place']??'Lokasi tidak diketahui'}',magnitude:(j['magnitude'] as num?)?.toDouble(),latitude:(j['latitude'] as num?)?.toDouble(),longitude:(j['longitude'] as num?)?.toDouble(),depthKm:(j['depth_km'] as num?)?.toDouble(),distanceKm:(j['distance_km'] as num?)?.toDouble(),mmi:(j['mmi'] as num?)?.toDouble(),timeEpoch:(j['time_epoch'] as num?)?.toInt(),magType:j['mag_type']?.toString(),tsunami:j['tsunami']);
}
