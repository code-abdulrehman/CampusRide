class Campus {
  final String campusId;
  final String campusName;
  final String address;
  final double latitude;
  final double longitude;
  final int openingHour;
  final int closingHour;

  const Campus({
    required this.campusId,
    required this.campusName,
    required this.address,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.openingHour = 8,
    this.closingHour = 20,
  });

  static const List<Campus> sampleCampuses = [
    Campus(campusId: 'campus_a', campusName: 'Campus A', address: 'Campus A Road, City'),
    Campus(campusId: 'main', campusName: 'Main Campus', address: 'University Main Campus'),
    Campus(campusId: 'campus_b', campusName: 'Campus B', address: 'Campus B Road, City'),
    Campus(campusId: 'campus_c', campusName: 'Campus C', address: 'Campus C Road, City'),
  ];
}
