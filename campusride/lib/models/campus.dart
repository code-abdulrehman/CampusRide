class Campus {
  final String campusId;
  final String campusName;
  final String address;
  final String code;
  final double latitude;
  final double longitude;
  final int openingHour;
  final int closingHour;

  const Campus({
    required this.campusId,
    required this.campusName,
    required this.address,
    this.code = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.openingHour = 8,
    this.closingHour = 20,
  });

  factory Campus.fromApi(Map<String, dynamic> json) => Campus(
        campusId: (json['id'] ?? json['campusId']) as String,
        campusName: (json['name'] ?? json['campusName'] ?? '') as String,
        address: (json['address'] ?? '') as String,
        code: (json['code'] ?? '') as String,
        latitude: ((json['latitude'] ?? 0) as num).toDouble(),
        longitude: ((json['longitude'] ?? 0) as num).toDouble(),
        openingHour: (json['openingHour'] ?? 8) as int,
        closingHour: (json['closingHour'] ?? 20) as int,
      );

  static List<Campus> sampleCampuses = const [
    Campus(campusId: 'campus_a', campusName: 'Campus A', address: 'Campus A Road, City'),
    Campus(campusId: 'main', campusName: 'Main Campus', address: 'University Main Campus'),
    Campus(campusId: 'campus_b', campusName: 'Campus B', address: 'Campus B Road, City'),
    Campus(campusId: 'campus_c', campusName: 'Campus C', address: 'Campus C Road, City'),
  ];
}
