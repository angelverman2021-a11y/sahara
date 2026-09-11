import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/announcement.dart';
import '../models/mesh_status.dart';
import '../models/message.dart';
import '../models/message_model.dart' show MessagePacket;
import '../models/person.dart';
import '../models/user_profile.dart';
import '../utils/broadcast_localizer.dart';
import 'emergency_service.dart';
import 'mesh_service.dart';
import 'native_bridge.dart';
import 'notification_service.dart';


class MockService extends EmergencyService {
  final MeshService? meshService;
  StreamSubscription<List<String>>? _peersSubscription;
  StreamSubscription<MessagePacket>? _messageSubscription;
  StreamSubscription<MessagePacket>? _broadcastSubscription;
  StreamSubscription<MessagePacket>? _sosSubscription;
  List<Person> _realNearbyPeers = [];

  /// Mapping of known physical node IDs to human-readable names
  /// sourced from the SAHARA directory / dataset / test devices.
  static const Map<String, String> _knownNodeToName = {
    'NODE_6829AE': 'Aarav Sharma',
    'NODE_A01': 'Aarav Sharma',
    'NODE_B02': 'Sunita Devi',
    'NODE_C03': 'Ramesh Kumar',
    'NODE_D04': 'Priya Das',
    'NODE_E05': 'Bikash Borah',
    'NODE_F06': 'Lakshmi Patel',
    'NODE_G07': 'Manoj Soren',
    'NODE_H08': 'Deepika Roy',
    'NODE_I09': 'Angel',
    'NODE_J10': 'Mother',
    'NODE_K11': 'Father',
    'NODE_L12': 'Sister',
    'NODE_M13': 'Rahul',
    'NODE_N14': 'Priya',
    'NODE_O15': 'Arjun',
    'NODE_P16': 'Neha',
    'NODE_Q17': 'Karan',
    'NODE_R18': 'Ananya',
    'NODE_S19': 'Rohit',
    'NODE_T20': 'Meera',
    'NODE_U21': 'Aman',
    'NODE_V22': 'Simran',
    'NODE_W23': 'Vivek',
    'NODE_X24': 'Ishita',
    'NODE_Y25': 'Aditya',
    'NODE_Z26': 'Kavya',
    'NODE_AA27': 'Varun',
    'NODE_AB28': 'Riya',
  };

  /// Mapping of known physical node IDs to permanent SAHARA user IDs (SH-XXXX)
  /// sourced from the SAHARA directory / dataset / test devices.
  static const Map<String, String> _knownNodeToUserId = {
    'NODE_6829AE': 'SH-6829',
    'NODE_33D404': 'SH-33D4',
    'NODE_A01': 'SH-A01',
    'NODE_B02': 'SH-B02',
    'NODE_C03': 'SH-C03',
    'NODE_D04': 'SH-D04',
    'NODE_E05': 'SH-E05',
    'NODE_F06': 'SH-F06',
    'NODE_G07': 'SH-G07',
    'NODE_H08': 'SH-H08',
    'NODE_I09': 'SH-I09',
    'NODE_J10': 'SH-J10',
    'NODE_K11': 'SH-K11',
    'NODE_L12': 'SH-L12',
    'NODE_M13': 'SH-M13',
    'NODE_N14': 'SH-N14',
    'NODE_O15': 'SH-O15',
    'NODE_P16': 'SH-P16',
    'NODE_Q17': 'SH-Q17',
    'NODE_R18': 'SH-R18',
    'NODE_S19': 'SH-S19',
    'NODE_T20': 'SH-T20',
    'NODE_U21': 'SH-U21',
    'NODE_V22': 'SH-V22',
    'NODE_W23': 'SH-W23',
    'NODE_X24': 'SH-X24',
    'NODE_Y25': 'SH-Y25',
    'NODE_Z26': 'SH-Z26',
    'NODE_AA27': 'SH-AA27',
    'NODE_AB28': 'SH-AB28',
  };

  /// Local directory contact ID to physical node ID mapping
  static const Map<String, String> _contactIdToNodeId = {
    'fam_mother': 'NODE_J10',
    'fam_father': 'NODE_K11',
    'fam_sister': 'NODE_L12',
    'contact_rahul': 'NODE_M13',
    'contact_emergency_team': 'NODE_A01',
    'peer_dr_neha': 'NODE_P16',
    'peer_medical_post': 'NODE_C03',
    'peer_guard_post': 'NODE_G07',
  };

  final Map<String, String> _customPeerNames = {};
  final Map<String, String> _customPeerUserIds = {};

  MeshStatus _meshStatus = MeshStatus(
    isMeshActive: true,
    nearbyCount: 0,
    batteryLevel: 85, // Updated dynamically from real Android BatteryManager
    activeRelays: 0,
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

    // Emergency Team & Contacts (Non-mesh local directory)
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
      id: 'peer_guard_post',
      name: 'Gate 4 Guard Post',
      relation: PersonRelation.emergencyTeam,
      status: PersonStatus.reachable,
      hops: 2,
      lastSeen: '5 min ago',
      locationAvailable: true,
      lastKnownLocation: 'Gate 4 Perimeter',
    ),
  ];

  late final Map<String, List<Message>> _messages;
  final List<Message> _broadcasts = [];

  MockService({this.meshService, List<String>? initialPeers}) {
    final now = DateTime.now();

    final ms = meshService;
    if (ms != null) {
      attachMeshService(ms);
    }
    if (initialPeers != null && initialPeers.isNotEmpty) {
      updateConnectedPeers(initialPeers);
    }
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

    const initBroadcastContent = 'Safe shelter available at Sector 4 Community Center with drinking water.';
    _broadcasts.add(
      Message(
        id: 'b_init',
        senderId: 'contact_emergency_team',
        receiverId: 'all',
        senderName: 'Emergency Team',
        content: initBroadcastContent,
        timestamp: now.subtract(const Duration(minutes: 18)),
        type: MessageType.broadcast,
        priority: MessagePriority.high,
        isFromMe: false,
        hops: 1,
        translations: BroadcastLocalizer.findTemplateTranslations(initBroadcastContent),
      ),
    );


    _initFromNative();
  }

  Future<void> _initFromNative() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('user_language');
      if (savedLang != null && savedLang.isNotEmpty) {
        _selectedLanguage = savedLang;
      }

      // Load any persisted peer name and user ID mappings from SharedPreferences
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('peer_name_')) {
          final peerNodeId = key.substring('peer_name_'.length);
          final peerName = prefs.getString(key);
          if (peerName != null && peerName.trim().isNotEmpty) {
            _customPeerNames[peerNodeId] = peerName.trim();
          }
        } else if (key.startsWith('peer_userid_')) {
          final peerNodeId = key.substring('peer_userid_'.length);
          final peerUserId = prefs.getString(key);
          if (peerUserId != null && peerUserId.trim().isNotEmpty) {
            _customPeerUserIds[peerNodeId] = peerUserId.trim();
          }
        }
      }
      if (_realNearbyPeers.isNotEmpty) {
        final currentPeerIds = _realNearbyPeers.map((p) => p.id).toList();
        updateConnectedPeers(currentPeerIds);
      }
    } catch (_) {}

    try {
      final realBattery = await NativeBridge.getBatteryLevel();
      _meshStatus = _meshStatus.copyWith(batteryLevel: realBattery);

      final profile = await NativeBridge.getProfile();
      if (profile != null) {
        _userProfile = profile;
        if (profile.language.isNotEmpty) {
          _selectedLanguage = profile.language;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  @override
  MeshStatus get meshStatus => _meshStatus;

  /// Resolves a physical mesh [nodeId] to a human-readable display name.
  /// Uses existing directory / test dataset mapping, persisted identity cache,
  /// or local contacts. Falls back to "Mesh Peer" if not yet resolved.
  String resolvePeerName(String nodeId) {
    if (_customPeerNames.containsKey(nodeId)) {
      return _customPeerNames[nodeId]!;
    }
    if (_knownNodeToName.containsKey(nodeId)) {
      return _knownNodeToName[nodeId]!;
    }
    for (final p in _people) {
      if (p.id == nodeId && p.name.isNotEmpty) {
        return p.name;
      }
    }
    return 'Mesh Peer';
  }

  /// Dynamically registers or caches a peer's identity (e.g., from handshake or sync)
  void registerPeerName(String nodeId, String name) {
    final clean = name.trim();
    if (clean.isNotEmpty) {
      _customPeerNames[nodeId] = clean;
      try {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('peer_name_$nodeId', clean);
        }).catchError((_) {});
      } catch (_) {}
      if (_realNearbyPeers.any((p) => p.id == nodeId)) {
        final currentPeerIds = _realNearbyPeers.map((p) => p.id).toList();
        updateConnectedPeers(currentPeerIds);
      }
    }
  }

  /// Resolves a peer identifier (node_id, contact ID, or user_id) to a permanent SAHARA User ID (SH-XXXX).
  String resolvePeerUserId(String identifier) {
    final cleanId = identifier.trim();
    if (cleanId.startsWith('SH-')) {
      return cleanId;
    }
    if (_customPeerUserIds.containsKey(cleanId)) {
      return _customPeerUserIds[cleanId]!;
    }
    if (_knownNodeToUserId.containsKey(cleanId)) {
      return _knownNodeToUserId[cleanId]!;
    }
    if (_contactIdToNodeId.containsKey(cleanId)) {
      final mappedNode = _contactIdToNodeId[cleanId]!;
      if (_knownNodeToUserId.containsKey(mappedNode)) {
        return _knownNodeToUserId[mappedNode]!;
      }
    }
    // Fallback: derive canonical SH-XXXX format from the hex / node ID
    final cleanHex = cleanId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .replaceFirst(RegExp(r'^NODE', caseSensitive: false), '');
    final suffix = cleanHex.length >= 4 ? cleanHex.substring(0, 4).toUpperCase() : cleanHex.toUpperCase();
    return 'SH-$suffix';
  }

  /// Resolves a peer identifier (user_id, contact ID, or node_id) to the physical routing Node ID (NODE_XXXX).
  String resolvePeerNodeId(String identifier) {
    final cleanId = identifier.trim();
    if (cleanId.startsWith('NODE_')) {
      return cleanId;
    }
    if (_contactIdToNodeId.containsKey(cleanId)) {
      return _contactIdToNodeId[cleanId]!;
    }
    // Reverse lookup in learned peer user IDs
    for (final entry in _customPeerUserIds.entries) {
      if (entry.value == cleanId) {
        return entry.key;
      }
    }
    // Reverse lookup in known node-to-user-id mapping
    for (final entry in _knownNodeToUserId.entries) {
      if (entry.value == cleanId) {
        return entry.key;
      }
    }
    return cleanId;
  }

  /// Dynamically registers or caches a peer's permanent user_id (e.g., learned from an incoming packet)
  void registerPeerUserId(String nodeId, String userId) {
    final cleanNode = nodeId.trim();
    final cleanUser = userId.trim();
    if (cleanNode.isNotEmpty && cleanUser.isNotEmpty && !cleanUser.startsWith('NODE_')) {
      _customPeerUserIds[cleanNode] = cleanUser;
      try {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('peer_userid_$cleanNode', cleanUser);
        }).catchError((_) {});
      } catch (_) {}
    }
  }

  void attachMeshService(MeshService meshService) {
    _peersSubscription?.cancel();
    _messageSubscription?.cancel();
    _broadcastSubscription?.cancel();
    _sosSubscription?.cancel();

    _peersSubscription = meshService.onPeersChanged.listen((peerList) {
      updateConnectedPeers(peerList);
    });

    _messageSubscription = meshService.onMessageReceived.listen((packet) {
      _handleIncomingMeshPacket(packet);
    });

    _broadcastSubscription = meshService.onBroadcastReceived.listen((packet) {
      _handleIncomingBroadcastPacket(packet);
    });

    _sosSubscription = meshService.onSosReceived.listen((packet) {
      _handleIncomingSosPacket(packet);
    });

    updateConnectedPeers(meshService.connectedPeers);
  }

  void _handleIncomingMeshPacket(MessagePacket packet) {
    debugPrint('[SAHARA DELIVER] Incoming packet ${packet.messageId} reached MockService: from ${packet.senderNodeId} (${packet.senderId}): "${packet.content}"');

    // Dynamically learn and associate peer user_id with peer node_id over the mesh
    if (packet.senderId.isNotEmpty && !packet.senderId.startsWith('NODE_')) {
      registerPeerUserId(packet.senderNodeId, packet.senderId);
    }

    final senderKey = packet.senderNodeId;
    final list = _messages.putIfAbsent(senderKey, () => []);

    // Deduplication in UI message list
    if (list.any((m) => m.id == packet.messageId)) {
      debugPrint('[SAHARA DROP] Duplicate message ${packet.messageId} already exists in UI conversation with $senderKey');
      return;
    }

    final incoming = Message(
      id: packet.messageId,
      senderId: senderKey,
      receiverId: 'me',
      senderName: resolvePeerName(senderKey),
      content: packet.content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
      type: MessageType.text,
      priority: packet.priority == 'Highest'
          ? MessagePriority.critical
          : (packet.priority == 'High' ? MessagePriority.high : MessagePriority.normal),
      isDelivered: true,
      isFromMe: false,
      hops: (8 - packet.ttl).clamp(1, 15),
    );
    list.add(incoming);
    debugPrint('[SAHARA DELIVER] Added incoming message to conversation with $senderKey (${incoming.senderName}). Notifying UI listeners!');
    notifyListeners();
  }

  void _handleIncomingBroadcastPacket(MessagePacket packet) {
    debugPrint('[SAHARA DELIVER] Incoming broadcast ${packet.messageId} reached MockService');

    // Dynamically learn sender user_id if valid
    if (packet.senderId.isNotEmpty && !packet.senderId.startsWith('NODE_')) {
      registerPeerUserId(packet.senderNodeId, packet.senderId);
    }

    if (_broadcasts.any((m) => m.id == packet.messageId)) {
      debugPrint('[SAHARA DROP] Duplicate broadcast ${packet.messageId} already in feed');
      return;
    }

    final newBroadcast = Message(
      id: packet.messageId,
      senderId: packet.senderNodeId,
      receiverId: 'all',
      senderName: resolvePeerName(packet.senderNodeId),
      content: packet.content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
      type: MessageType.broadcast,
      priority: MessagePriority.high,
      isDelivered: true,
      isFromMe: false,
      hops: (8 - packet.ttl).clamp(1, 15),
      translations: BroadcastLocalizer.findTemplateTranslations(packet.content),
    );
    _broadcasts.insert(0, newBroadcast);
    notifyListeners();
  }

  void _handleIncomingSosPacket(MessagePacket packet) {
    debugPrint('[SAHARA DELIVER] Incoming SOS alert ${packet.messageId} reached MockService');

    // Dynamically learn sender user_id if valid
    if (packet.senderId.isNotEmpty && !packet.senderId.startsWith('NODE_')) {
      registerPeerUserId(packet.senderNodeId, packet.senderId);
    }

    if (_broadcasts.any((m) => m.id == packet.messageId)) {
      debugPrint('[SAHARA DROP] Duplicate SOS alert ${packet.messageId} already in feed');
      return;
    }

    final newSos = Message(
      id: packet.messageId,
      senderId: packet.senderNodeId,
      receiverId: 'all',
      senderName: '${resolvePeerName(packet.senderNodeId)} (EMERGENCY SOS)',
      content: packet.content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
      type: MessageType.sosAlert,
      priority: MessagePriority.critical,
      isDelivered: true,
      isFromMe: false,
      hops: (8 - packet.ttl).clamp(1, 15),
      translations: BroadcastLocalizer.getSosTranslations(packet.content),
    );
    _broadcasts.insert(0, newSos);
    notifyListeners();
  }

  void updateConnectedPeers(List<String> peerNodeIds) {
    _realNearbyPeers = peerNodeIds.map((nodeId) {
      final displayName = resolvePeerName(nodeId);
      return Person(
        id: nodeId, // physical node_id preserved internally for mesh routing & debugging
        name: displayName, // user's actual human name, or safe fallback "Mesh Peer"
        relation: PersonRelation.nearby,
        status: PersonStatus.reachable,
        hops: 1,
        lastSeen: 'Just now',
        locationAvailable: false,
        lastKnownLocation: 'Nearby Mesh',
      );
    }).toList();

    _meshStatus = _meshStatus.copyWith(
      nearbyCount: peerNodeIds.length,
      activeRelays: peerNodeIds.length,
      lastSynced: DateTime.now(),
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _peersSubscription?.cancel();
    _messageSubscription?.cancel();
    _broadcastSubscription?.cancel();
    _sosSubscription?.cancel();
    super.dispose();
  }

  @override
  List<Person> get nearbyPeople => List.unmodifiable(_realNearbyPeers);

  @override
  List<Person> get familyMembers => _people.where((p) => p.relation == PersonRelation.family).toList();

  @override
  List<Person> get conversations {
    final convIds = ['fam_mother', 'contact_rahul', 'contact_emergency_team', 'fam_father', 'fam_sister'];
    final base = convIds
        .map((id) => getPersonById(id))
        .whereType<Person>()
        .toList();

    // Include any active mesh peer conversations
    for (final entry in _messages.entries) {
      if (entry.value.isNotEmpty && !base.any((p) => p.id == entry.key)) {
        final peer = getPersonById(entry.key);
        if (peer != null) {
          base.insert(0, peer);
        } else {
          base.insert(0, Person(
            id: entry.key,
            name: resolvePeerName(entry.key),
            relation: PersonRelation.nearby,
            status: PersonStatus.reachable,
            hops: 1,
            lastSeen: 'Just now',
            locationAvailable: false,
            lastKnownLocation: 'Nearby Mesh',
          ));
        }
      }
    }
    return List.unmodifiable(base);
  }

  @override
  List<Message> get recentBroadcasts => List.unmodifiable(_broadcasts);

  final List<EmergencyAnnouncement> _announcements = [
    EmergencyAnnouncement(
      id: 'ann_1',
      title: 'Cyclone Warning',
      message: 'Heavy rainfall and wind speeds up to 65 km/h expected in your sector. Move to designated storm shelters.',
      source: 'Disaster Response Cell',
      timeAgo: '12 min ago',
      severity: AnnouncementSeverity.warning,
      translations: BroadcastLocalizer.announcementCatalog['ann_1'],
    ),
    EmergencyAnnouncement(
      id: 'ann_2',
      title: 'Flood Evacuation Notice',
      message: 'Evacuation route active via North Bypass. Relief camp #3 open at Central High School.',
      source: 'Emergency Network',
      timeAgo: '25 min ago',
      severity: AnnouncementSeverity.evacuation,
      translations: BroadcastLocalizer.announcementCatalog['ann_2'],
    ),
    EmergencyAnnouncement(
      id: 'ann_3',
      title: 'Clean Water & Food Supply',
      message: 'Potable water tankers and ration kits available at Community Grounds Gate 2 until 6:00 PM.',
      source: 'Relief Team',
      timeAgo: '45 min ago',
      severity: AnnouncementSeverity.advisory,
      translations: BroadcastLocalizer.announcementCatalog['ann_3'],
    ),
  ];

  @override
  List<EmergencyAnnouncement> get announcements => List.unmodifiable(_announcements);

  @override
  void addAnnouncement(EmergencyAnnouncement announcement) {
    _announcements.insert(0, announcement);
    notifyListeners();

    NotificationService().showEmergencyBroadcastNotification(
      title: announcement.title,
      message: announcement.message,
      severity: announcement.severity,
      id: announcement.id,
    );
  }

  @override
  UserProfile? get userProfile => _userProfile;

  @override
  bool get isOnboardingCompleted => _userProfile?.isCompleted ?? false;

  @override
  String get selectedLanguage => _selectedLanguage;

  @override
  List<Message> getMessages(String personId) {
    if (_messages.containsKey(personId)) {
      return List.unmodifiable(_messages[personId]!);
    }
    final mappedNode = resolvePeerNodeId(personId);
    if (_messages.containsKey(mappedNode)) {
      return List.unmodifiable(_messages[mappedNode]!);
    }
    final mappedUser = resolvePeerUserId(personId);
    if (_messages.containsKey(mappedUser)) {
      return List.unmodifiable(_messages[mappedUser]!);
    }
    return const [];
  }

  @override
  Person? getPersonById(String id) {
    try {
      return _people.firstWhere((p) => p.id == id);
    } catch (_) {
      try {
        return _realNearbyPeers.firstWhere((p) => p.id == id);
      } catch (_) {
        if (id.startsWith('NODE_') || id.startsWith('SH-')) {
          return Person(
            id: id,
            name: resolvePeerName(id),
            relation: PersonRelation.nearby,
            status: PersonStatus.reachable,
            hops: 1,
            lastSeen: 'Just now',
            locationAvailable: false,
            lastKnownLocation: 'Nearby Mesh',
          );
        }
        return null;
      }
    }
  }

  @override
  List<Person> get allKnownPeople => List.unmodifiable([..._people, ..._realNearbyPeers]);

  @override
  List<Person> searchPeople(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final digitsOnly = query.replaceAll(RegExp(r'\D'), '');

    return [..._people, ..._realNearbyPeers].where((p) {
      final nameMatches = p.name.toLowerCase().contains(q);
      final idMatches = p.id.toLowerCase().contains(q);
      final phone = p.phoneNumber ?? '';
      final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
      final phoneMatches = (digitsOnly.isNotEmpty && phoneDigits.contains(digitsOnly)) ||
          phone.toLowerCase().contains(q);
      return nameMatches || idMatches || phoneMatches;
    }).toList();
  }

  @override
  void triggerSOS({String? locationCoordinates}) {
    _meshStatus = _meshStatus.copyWith(
      isBroadcastingSOS: true,
      activeRelays: 4,
      lastSynced: DateTime.now(),
    );

    final coords = (locationCoordinates != null && locationCoordinates.isNotEmpty)
        ? locationCoordinates
        : '28.5355° N, 77.3910° E';

    final details = 'EMERGENCY DISTRESS SIGNAL: Assistance needed at current location ($coords).';

    _broadcasts.insert(
      0,
      Message(
        id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'me',
        receiverId: 'all',
        senderName: 'You (EMERGENCY SOS)',
        content: details,
        timestamp: DateTime.now(),
        type: MessageType.sosAlert,
        priority: MessagePriority.critical,
        isFromMe: true,
        hops: 1,
        translations: BroadcastLocalizer.getSosTranslations(coords),
      ),
    );

    NotificationService().showEmergencyBroadcastNotification(
      title: 'EMERGENCY DISTRESS BEACON',
      message: 'Assistance needed at current location ($coords).',
      severity: AnnouncementSeverity.evacuation,
      id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
    );

    notifyListeners();

    final ms = meshService;
    if (ms != null) {
      debugPrint('[SAHARA SEND] Calling MeshService.sendSosAlert for coords: $coords');
      ms.sendSosAlert(location: coords, details: details).catchError((e, stack) {
        debugPrint('[SAHARA SEND] ERROR in MeshService.sendSosAlert: $e\n$stack');
      });
    }
  }

  @override
  void cancelSOS() {
    _meshStatus = _meshStatus.copyWith(
      isBroadcastingSOS: false,
      lastSynced: DateTime.now(),
    );
    notifyListeners();
  }

  /// Simulates receiving an incoming offline mesh message from a family member
  void receiveFamilyMessage({
    required String senderId,
    required String content,
  }) {
    final sender = getPersonById(senderId);
    final senderName = sender?.name ?? 'Family Member';
    final list = _messages.putIfAbsent(senderId, () => []);
    final newMessage = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      receiverId: 'me',
      senderName: senderName,
      content: content.trim(),
      timestamp: DateTime.now(),
      type: MessageType.text,
      priority: MessagePriority.normal,
      isDelivered: true,
      isFromMe: false,
      hops: sender?.hops ?? 1,
    );
    list.add(newMessage);
    notifyListeners();

    NotificationService().showFamilyMessageNotification(
      senderName: senderName,
      content: content.trim(),
      personId: senderId,
    );
  }

  @override
  void sendMessage({
    required String receiverId,
    required String content,
    MessagePriority priority = MessagePriority.normal,
  }) {
    debugPrint('[SAHARA SEND] UI initiated message send: receiverId=$receiverId, content="$content", priority=$priority');

    final receiverNodeId = resolvePeerNodeId(receiverId);
    final receiverUserId = resolvePeerUserId(receiverId);

    debugPrint('[SAHARA SEND] Resolved identities: receiverNodeId=$receiverNodeId, receiverUserId=$receiverUserId');

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

    final ms = meshService;
    if (ms != null) {
      debugPrint('[SAHARA SEND] Calling MeshService.sendDirectMessage: receiverNodeId=$receiverNodeId, receiverUserId=$receiverUserId');
      ms.sendDirectMessage(
        receiverNodeId: receiverNodeId,
        receiverUserId: receiverUserId,
        content: content.trim(),
        priority: priority == MessagePriority.critical
            ? 'Highest'
            : (priority == MessagePriority.high ? 'High' : 'Normal'),
      ).then((_) {
        debugPrint('[SAHARA SEND] MeshService.sendDirectMessage successfully dispatched for $receiverNodeId ($receiverUserId)');
      }).catchError((e, stack) {
        debugPrint('[SAHARA SEND] ERROR in MeshService.sendDirectMessage: $e\n$stack');
      });
    } else {
      debugPrint('[SAHARA SEND] MeshService is not attached, message saved in local store only');
    }

    // If sent to a family member, simulate incoming response after brief delay
    // to verify family notifications in background or testing
    final person = getPersonById(receiverId);
    if (person != null && person.relation == PersonRelation.family) {
      Future.delayed(const Duration(seconds: 3), () {
        if (_people.any((p) => p.id == receiverId)) {
          receiveFamilyMessage(
            senderId: receiverId,
            content: 'Received your message over mesh. We are safe and staying in shelter.',
          );
        }
      });
    }
  }

  @override
  void sendBroadcast({required String content}) {
    final trimmedContent = content.trim();
    final newBroadcast = Message(
      id: 'b_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      receiverId: 'all',
      senderName: 'You',
      content: trimmedContent,
      timestamp: DateTime.now(),
      type: MessageType.broadcast,
      priority: MessagePriority.high,
      isDelivered: true,
      isFromMe: true,
      hops: 1,
      translations: BroadcastLocalizer.findTemplateTranslations(trimmedContent),
    );
    _broadcasts.insert(0, newBroadcast);
    notifyListeners();

    final ms = meshService;
    if (ms != null) {
      debugPrint('[SAHARA SEND] Calling MeshService.sendEmergencyBroadcast for: "$trimmedContent"');
      ms.sendEmergencyBroadcast(content: trimmedContent).catchError((e, stack) {
        debugPrint('[SAHARA SEND] ERROR in MeshService.sendEmergencyBroadcast: $e\n$stack');
      });
    }
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_language', profile.language);
    } catch (_) {}
    await NativeBridge.saveProfile(profile);
    notifyListeners();
  }

  @override
  Future<void> setLanguage(String lang) async {
    _selectedLanguage = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_language', lang);
    } catch (_) {}
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(language: lang);
      await NativeBridge.saveProfile(_userProfile!);
    }
    notifyListeners();
  }
}
