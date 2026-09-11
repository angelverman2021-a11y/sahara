import '../models/person.dart';

/// Centralized presentation-only demo sample data configuration.
///
/// Toggle [showDemoData] to `false` for final production builds where the app
/// should start completely clean without sample presentation entries.
class DemoConfig {
  /// Centralized toggle for presentation mode demo entries.
  /// Set to [false] for clean production builds.
  static const bool showDemoData = true;

  /// Sample demo family members for fresh installations.
  /// These are presentation-only entries that do not participate in real mesh routing.
  static const List<Person> demoFamilyMembers = [
    Person(
      id: 'demo_fam_mom',
      name: 'Mom — Priya Arora',
      relation: PersonRelation.family,
      status: PersonStatus.unreachable,
      hops: 2,
      lastSeen: 'Earlier today',
      locationAvailable: true,
      lastKnownLocation: 'Sector 4, Block C',
      phoneNumber: '+91 98100 11223',
      isDemo: true,
    ),
    Person(
      id: 'demo_fam_dad',
      name: 'Dad — Rajesh Arora',
      relation: PersonRelation.family,
      status: PersonStatus.unreachable,
      hops: 1,
      lastSeen: '15m ago',
      locationAvailable: true,
      lastKnownLocation: 'Civil Hospital Area',
      phoneNumber: '+91 98100 44556',
      isDemo: true,
    ),
    Person(
      id: 'demo_fam_sister',
      name: 'Sister — Riya Arora',
      relation: PersonRelation.family,
      status: PersonStatus.unreachable,
      hops: 2,
      lastSeen: '1h ago',
      locationAvailable: true,
      lastKnownLocation: 'University Campus',
      phoneNumber: '+91 98100 77889',
      isDemo: true,
    ),
  ];

  /// Sample demo nearby people for fresh installations.
  /// These are presentation-only entries that do not participate in real mesh routing.
  static const List<Person> demoNearbyPeople = [
    Person(
      id: 'demo_peer_aarav',
      name: 'Aarav Mehta',
      relation: PersonRelation.nearby,
      status: PersonStatus.unreachable,
      hops: 1,
      lastSeen: 'Sample node',
      locationAvailable: true,
      lastKnownLocation: '~45m away • Sector 4',
      phoneNumber: '+91 98765 01001',
      coordinates: '28.5355° N, 77.3910° E',
      isDemo: true,
    ),
    Person(
      id: 'demo_peer_ananya',
      name: 'Ananya Sharma',
      relation: PersonRelation.nearby,
      status: PersonStatus.unreachable,
      hops: 1,
      lastSeen: 'Sample node',
      locationAvailable: true,
      lastKnownLocation: '~120m away • North Gate',
      phoneNumber: '+91 98765 01002',
      coordinates: '28.5362° N, 77.3925° E',
      isDemo: true,
    ),
    Person(
      id: 'demo_peer_rohan',
      name: 'Rohan Verma',
      relation: PersonRelation.nearby,
      status: PersonStatus.unreachable,
      hops: 2,
      lastSeen: 'Sample node',
      locationAvailable: true,
      lastKnownLocation: '~80m away • Main Road',
      phoneNumber: '+91 98765 01003',
      coordinates: '28.5348° N, 77.3895° E',
      isDemo: true,
    ),
    Person(
      id: 'demo_peer_priya',
      name: 'Priya Nair',
      relation: PersonRelation.nearby,
      status: PersonStatus.unreachable,
      hops: 2,
      lastSeen: 'Sample node',
      locationAvailable: true,
      lastKnownLocation: '~160m away • Relief Camp B',
      phoneNumber: '+91 98765 01004',
      coordinates: '28.5370° N, 77.3930° E',
      isDemo: true,
    ),
  ];
}
