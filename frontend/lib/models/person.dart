enum PersonStatus {
  reachable,
  unreachable,
  sosActive,
}

enum PersonRelation {
  family,
  emergencyTeam,
  nearby,
}

class Person {
  final String id;
  final String name;
  final PersonRelation relation;
  final PersonStatus status;
  final int hops;
  final String lastSeen;
  final bool locationAvailable;
  final String lastKnownLocation;
  final String? coordinates;
  final String? phoneNumber;
  final bool isDemo;

  const Person({
    required this.id,
    required this.name,
    required this.relation,
    required this.status,
    required this.hops,
    required this.lastSeen,
    required this.locationAvailable,
    required this.lastKnownLocation,
    this.coordinates,
    this.phoneNumber,
    this.isDemo = false,
  });

  bool get isReachable => status == PersonStatus.reachable;

  String get relationLabel {
    switch (relation) {
      case PersonRelation.family:
        return 'Family';
      case PersonRelation.emergencyTeam:
        return 'Emergency Responder';
      case PersonRelation.nearby:
        return 'Mesh Peer';
    }
  }

  Person copyWith({
    String? id,
    String? name,
    PersonRelation? relation,
    PersonStatus? status,
    int? hops,
    String? lastSeen,
    bool? locationAvailable,
    String? lastKnownLocation,
    String? coordinates,
    String? phoneNumber,
    bool? isDemo,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      status: status ?? this.status,
      hops: hops ?? this.hops,
      lastSeen: lastSeen ?? this.lastSeen,
      locationAvailable: locationAvailable ?? this.locationAvailable,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      coordinates: coordinates ?? this.coordinates,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}
