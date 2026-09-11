import '../models/announcement.dart';
import '../models/mesh_status.dart';
import '../models/message.dart';
import '../models/person.dart';
import '../models/user_profile.dart';
import 'emergency_service.dart';
import 'native_bridge.dart';

class MockService extends EmergencyService {
  MeshStatus _meshStatus = MeshStatus(
    isMeshActive: true,
    nearbyCount: 12,
    batteryLevel: 85, // Updated dynamically from real Android BatteryManager
    activeRelays: 4,
    isBroadcastingSOS: false,
    lastSynced: DateTime.now(),
  );

  UserProfile? _userProfile;
  String _selectedLanguage = 'English';

  final List<Person> _people = [
    // Family members
    const Person(
      id: 'fam_mother',
      name: 'Mother',
      relation: PersonRelation.family,
      status: PersonStatus.reachable,
      hops: 3,
      lastSeen: 'Just now',
      locationAvailable: true,
      lastKnownLocation: 'Sector 4 Community Center',
      coordinates: '28.5355° N, 77.3910° E (±4m)',
      phoneNumber: '+91 98100 12345',
    ),
    const Person(
      id: 'fam_father',
      name: 'Father',
      relation: PersonRelation.family,
      status: PersonStatus.reachable,
      hops: 1,
      lastSeen: '1 min ago',
      locationAvailable: true,
      lastKnownLocation: 'Safe Zone B - Relief Camp',
      coordinates: '28.5390° N, 77.3880° E (±6m)',
      phoneNumber: '+91 98100 67890',
    ),
    const Person(
      id: 'fam_sister',
      name: 'Sister',
      relation: PersonRelation.family,
      status: PersonStatus.unreachable,
      hops: 0,
      lastSeen: '8 min ago',
      locationAvailable: false,
      lastKnownLocation: 'City College Gym (Prior Report)',
      coordinates: '28.5270° N, 77.4010° E (Stale)',
      phoneNumber: '+91 98100 11223',
    ),

    // Emergency Team & Contacts
    const Person(
      id: 'contact_rahul',
      name: 'Rahul',
      relation: PersonRelation.nearby,
      status: PersonStatus.reachable,
      hops: 2,
      lastSeen: '3 min ago',
      locationAvailable: true,
      lastKnownLocation: 'Gate 2 Crossroad',
      coordinates: '28.5312° N, 77.3945° E',
    ),
    const Person(
      id: 'contact_emergency_team',
      name: 'Emergency Team',
      relation: PersonRelation.emergencyTeam,
      status: PersonStatus.reachable,
      hops: 1,
      lastSeen: 'Just now',
      locationAvailable: true,
      lastKnownLocation: 'Sector 3 Command HQ',
      coordinates: '28.5388° N, 77.3820° E',
    ),

    // Additional Nearby Mesh Peers
    const Person(
      id: 'peer_priya',
      name: 'Priya S.',
      relation: PersonRelation.nearby,
      status: PersonStatus.reachable,
      hops: 1,
      lastSeen: 'Just now',
      locationAvailable: true,
      lastKnownLocation: 'Block A Shelter',
    ),
    const Person(
      id: 'peer_dr_neha',
      name: 'Dr. Neha (Medic)',
      relation: PersonRelation.emergencyTeam,
      status: PersonStatus.reachable,
      hops: 1,
      lastSeen: '1 min ago',
      locationAvailable: true,
      lastKnownLocation: 'First-Aid Tent #2',
    ),
    const Person(
      id: 'peer_amit',
      name: 'Amit K.',
      relation: PersonRelation.nearby,
      status: PersonStatus.reachable,
      hops: 2,
      lastSeen: '2 min ago',
      locationAvailable: false,
      lastKnownLocation: 'North Overpass',
    ),
    const Person(
      id: 'peer_medical_post',
      name: 'Medical Post 3',
      relation: PersonRelation.emergencyTeam,
      status: PersonStatus.reachable,
      hops: 2,
      lastSeen: '4 min ago',
      locationAvailable: true,
      lastKnownLocation: 'Civic Hospital Annex',
    ),
    const Person(
      id: 'peer_sahil',
      name: 'Sahil V.',
      relation: PersonRelation.nearby,
      status: PersonStatus.reachable,
      hops: 3,
      lastSeen: '4 min ago',
      locationAvailable: false,
      lastKnownLocation: 'Market Square',
    ),
    const Person(
      id: 'peer_guard_post',
      name: 'Gate 4 Guard Post',
      relation: PersonRelation.emergencyTeam,
      status: PersonStatus.reachable,
      hops: 2,
      lastSeen: '5 min ago',
      locationAvailable: true,
      lastKnownLocation: 'Gate 4 Perimeter',
    ),
    const Person(
      id: 'peer_relay_node',
      name: 'Mesh Relay Node #04',
      relation: PersonRelation.nearby,
      status: PersonStatus.reachable,
      hops: 1,
      lastSeen: 'Just now',
      locationAvailable: true,
      lastKnownLocation: 'Water Tower Repeater',
    ),
    const Person(
      id: 'peer_sunita',
      name: 'Sunita D.',
      relation: PersonRelation.nearby,
      status: PersonStatus.reachable,
      hops: 2,
      lastSeen: '6 min ago',
      locationAvailable: false,
      lastKnownLocation: 'East Apartments',
    ),
  ];

  late final Map<String, List<Message>> _messages;
  final List<Message> _broadcasts = [];

  MockService() {
    final now = DateTime.now();
    _messages = {
      'fam_mother': [
        Message(
          id: 'm1_1',
          senderId: 'fam_mother',
          receiverId: 'me',
          senderName: 'Mother',
          content: 'Power went out in our block. Are you safe?',
          timestamp: now.subtract(const Duration(minutes: 7)),
          isFromMe: false,
          hops: 3,
        ),
        Message(
          id: 'm1_2',
          senderId: 'me',
          receiverId: 'fam_mother',
          senderName: 'You',
          content: 'I am safe at the north entrance. Cell tower is down, using Sahara mesh.',
          timestamp: now.subtract(const Duration(minutes: 5)),
          isFromMe: true,
          hops: 1,
        ),
        Message(
          id: 'm1_3',
          senderId: 'fam_mother',
          receiverId: 'me',
          senderName: 'Mother',
          content: 'Are you safe?',
          timestamp: now.subtract(const Duration(minutes: 2)),
          isFromMe: false,
          hops: 3,
        ),
      ],
      'contact_rahul': [
        Message(
          id: 'm2_1',
          senderId: 'contact_rahul',
          receiverId: 'me',
          senderName: 'Rahul',
          content: 'Heavy water logging on Main Street.',
          timestamp: now.subtract(const Duration(minutes: 10)),
          isFromMe: false,
          hops: 2,
        ),
        Message(
          id: 'm2_2',
          senderId: 'contact_rahul',
          receiverId: 'me',
          senderName: 'Rahul',
          content: 'Road is blocked near Gate 2',
          timestamp: now.subtract(const Duration(minutes: 5)),
          isFromMe: false,
          hops: 2,
        ),
      ],
      'contact_emergency_team': [
        Message(
          id: 'm3_1',
          senderId: 'contact_emergency_team',
          receiverId: 'me',
          senderName: 'Emergency Team',
          content: 'Attention: Relief camp at Community Center Sector 4 is operational.',
          timestamp: now.subtract(const Duration(minutes: 25)),
          isFromMe: false,
          priority: MessagePriority.high,
          hops: 1,
        ),
        Message(
          id: 'm3_2',
          senderId: 'contact_emergency_team',
          receiverId: 'me',
          senderName: 'Emergency Team',
          content: 'Evacuation route updated',
          timestamp: now.subtract(const Duration(minutes: 12)),
          isFromMe: false,
          priority: MessagePriority.high,
          hops: 1,
        ),
      ],
      'fam_father': [
        Message(
          id: 'm4_1',
          senderId: 'fam_father',
          receiverId: 'me',
          senderName: 'Father',
          content: 'We reached Relief Camp B. Medical team is here.',
          timestamp: now.subtract(const Duration(minutes: 15)),
          isFromMe: false,
          hops: 1,
        ),
      ],
      'fam_sister': [
        Message(
          id: 'm5_1',
          senderId: 'fam_sister',
          receiverId: 'me',
          senderName: 'Sister',
          content: 'Phone battery low. Waiting near the main auditorium.',
          timestamp: now.subtract(const Duration(minutes: 30)),
          isFromMe: false,
          hops: 0,
        ),
      ],
    };

    _broadcasts.add(
      Message(
        id: 'b_init',
        senderId: 'contact_emergency_team',
        receiverId: 'all',
        senderName: 'Emergency Team',
        content: 'Safe shelter available at Sector 4 Community Center with drinking water.',
        timestamp: now.subtract(const Duration(minutes: 18)),
        type: MessageType.broadcast,
        priority: MessagePriority.high,
        isFromMe: false,
        hops: 1,
      ),
    );

    _initFromNative();
  }

  Future<void> _initFromNative() async {
    try {
      final realBattery = await NativeBridge.getBatteryLevel();
      _meshStatus = _meshStatus.copyWith(batteryLevel: realBattery);

      final profile = await NativeBridge.getProfile();
      if (profile != null) {
        _userProfile = profile;
        _selectedLanguage = profile.language;
      }
      notifyListeners();
    } catch (_) {}
  }

  @override
  MeshStatus get meshStatus => _meshStatus;

  @override
  List<Person> get nearbyPeople => _people.where((p) => p.status == PersonStatus.reachable).toList();

  @override
  List<Person> get familyMembers => _people.where((p) => p.relation == PersonRelation.family).toList();

  @override
  List<Person> get conversations {
    final convIds = ['fam_mother', 'contact_rahul', 'contact_emergency_team', 'fam_father', 'fam_sister'];
    return convIds
        .map((id) => _people.firstWhere((p) => p.id == id))
        .toList();
  }

  @override
  List<Message> get recentBroadcasts => List.unmodifiable(_broadcasts);

  final List<EmergencyAnnouncement> _announcements = [
    const EmergencyAnnouncement(
      id: 'ann_1',
      title: 'Cyclone Warning',
      message: 'Heavy rainfall and wind speeds up to 65 km/h expected in your sector. Move to designated storm shelters.',
      source: 'Disaster Response Cell',
      timeAgo: '12 min ago',
      severity: AnnouncementSeverity.warning,
    ),
    const EmergencyAnnouncement(
      id: 'ann_2',
      title: 'Flood Evacuation Notice',
      message: 'Evacuation route active via North Bypass. Relief camp #3 open at Central High School.',
      source: 'Emergency Network',
      timeAgo: '25 min ago',
      severity: AnnouncementSeverity.evacuation,
    ),
    const EmergencyAnnouncement(
      id: 'ann_3',
      title: 'Clean Water & Food Supply',
      message: 'Potable water tankers and ration kits available at Community Grounds Gate 2 until 6:00 PM.',
      source: 'Relief Team',
      timeAgo: '45 min ago',
      severity: AnnouncementSeverity.advisory,
    ),
  ];

  @override
  List<EmergencyAnnouncement> get announcements => List.unmodifiable(_announcements);

  @override
  UserProfile? get userProfile => _userProfile;

  @override
  bool get isOnboardingCompleted => _userProfile?.isCompleted ?? false;

  @override
  String get selectedLanguage => _selectedLanguage;

  @override
  List<Message> getMessages(String personId) {
    return List.unmodifiable(_messages[personId] ?? []);
  }

  @override
  Person? getPersonById(String id) {
    try {
      return _people.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void triggerSOS() {
    _meshStatus = _meshStatus.copyWith(
      isBroadcastingSOS: true,
      activeRelays: 4,
      lastSynced: DateTime.now(),
    );

    _broadcasts.insert(
      0,
      Message(
        id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'me',
        receiverId: 'all',
        senderName: 'You (EMERGENCY SOS)',
        content: 'EMERGENCY DISTRESS SIGNAL: Assistance needed at current location (28.5355° N, 77.3910° E).',
        timestamp: DateTime.now(),
        type: MessageType.sosAlert,
        priority: MessagePriority.critical,
        isFromMe: true,
        hops: 1,
      ),
    );

    notifyListeners();
  }

  @override
  void cancelSOS() {
    _meshStatus = _meshStatus.copyWith(
      isBroadcastingSOS: false,
      lastSynced: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  void sendMessage({
    required String receiverId,
    required String content,
    MessagePriority priority = MessagePriority.normal,
  }) {
    final list = _messages.putIfAbsent(receiverId, () => []);
    final newMessage = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      receiverId: receiverId,
      senderName: 'You',
      content: content.trim(),
      timestamp: DateTime.now(),
      type: MessageType.text,
      priority: priority,
      isDelivered: true,
      isFromMe: true,
      hops: 1,
    );
    list.add(newMessage);
    notifyListeners();
  }

  @override
  void sendBroadcast({required String content}) {
    final newBroadcast = Message(
      id: 'b_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      receiverId: 'all',
      senderName: 'You',
      content: content.trim(),
      timestamp: DateTime.now(),
      type: MessageType.broadcast,
      priority: MessagePriority.high,
      isDelivered: true,
      isFromMe: true,
      hops: 1,
    );
    _broadcasts.insert(0, newBroadcast);
    notifyListeners();
  }

  @override
  void pingPerson(String personId) {
    // Service-level simulation of multi-hop mesh ping
    notifyListeners();
  }

  @override
  int pingFamilyAll() {
    final reachableCount = familyMembers.where((m) => m.isReachable).length;
    notifyListeners();
    return reachableCount;
  }

  @override
  void addPersonToFamily(Person person) {
    final existingIndex = _people.indexWhere(
      (p) => p.id == person.id || (person.phoneNumber != null && person.phoneNumber!.isNotEmpty && p.phoneNumber == person.phoneNumber),
    );
    if (existingIndex >= 0) {
      final existing = _people[existingIndex];
      _people[existingIndex] = Person(
        id: existing.id,
        name: existing.name,
        relation: PersonRelation.family,
        status: existing.status,
        hops: existing.hops,
        lastSeen: existing.lastSeen,
        locationAvailable: existing.locationAvailable,
        lastKnownLocation: existing.lastKnownLocation,
        coordinates: existing.coordinates,
        phoneNumber: existing.phoneNumber,
      );
    } else {
      _people.insert(
        0,
        Person(
          id: person.id.isNotEmpty ? person.id : 'fam_${DateTime.now().millisecondsSinceEpoch}',
          name: person.name,
          relation: PersonRelation.family,
          status: PersonStatus.reachable,
          hops: 1,
          lastSeen: 'Just now',
          locationAvailable: true,
          lastKnownLocation: person.lastKnownLocation.isNotEmpty ? person.lastKnownLocation : 'Discovered in mesh range',
          coordinates: person.coordinates,
          phoneNumber: person.phoneNumber,
        ),
      );
    }
    notifyListeners();
  }

  @override
  void updateRealBattery(int batteryPercent) {
    if (_meshStatus.batteryLevel != batteryPercent) {
      _meshStatus = _meshStatus.copyWith(batteryLevel: batteryPercent);
      notifyListeners();
    }
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    _userProfile = profile;
    _selectedLanguage = profile.language;
    await NativeBridge.saveProfile(profile);
    notifyListeners();
  }

  @override
  Future<void> setLanguage(String lang) async {
    _selectedLanguage = lang;
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(language: lang);
      await NativeBridge.saveProfile(_userProfile!);
    }
    notifyListeners();
  }
}
