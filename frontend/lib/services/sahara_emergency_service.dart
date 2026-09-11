import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/announcement.dart';
import '../models/mesh_status.dart';
import '../models/message.dart' as ui_msg;
import '../models/message_model.dart';
import '../models/person.dart';
import '../models/user_profile.dart';
import '../utils/broadcast_localizer.dart';
import 'backend_client.dart';
import 'backend_sync_service.dart';
import 'emergency_service.dart';
import 'mesh_service.dart';
import 'native_bridge.dart';
import 'nearby_transport.dart';
import 'notification_service.dart';

/// Production implementation of [EmergencyService] providing complete end-to-end
/// integration between Flutter UI, SQLite persistence, real Android Nearby Connections,
/// and the Python backend synchronization engine.
class SaharaEmergencyService extends EmergencyService {
  final DatabaseHelper db;
  final BackendClient backendClient;
  late final BackendSyncService syncService;

  MeshService? _meshService;
  MeshTransport? _transport;

  String _myNodeId = '';
  String _myUserId = '';
  UserProfile? _userProfile;
  String _selectedLanguage = 'English';

  MeshStatus _meshStatus = MeshStatus(
    isMeshActive: false,
    nearbyCount: 0,
    batteryLevel: 85,
    activeRelays: 0,
    isBroadcastingSOS: false,
    lastSynced: DateTime.now(),
  );

  final List<Person> _nearbyPeople = [];
  final List<Person> _familyMembers = [];
  final Map<String, List<ui_msg.Message>> _conversationMessages = {};
  final List<EmergencyAnnouncement> _announcements = [];

  StreamSubscription<List<String>>? _peersSub;
  StreamSubscription<MessagePacket>? _messagesSub;
  StreamSubscription<MessagePacket>? _sosSub;
  StreamSubscription<MessagePacket>? _broadcastSub;

  SaharaEmergencyService({
    DatabaseHelper? dbHelper,
    BackendClient? client,
    MeshTransport? customTransport,
    MeshService? customMeshService,
    String? nodeId,
    String? userId,
  })  : db = dbHelper ?? DatabaseHelper.instance,
        backendClient = client ?? BackendClient() {
    syncService = BackendSyncService(client: backendClient, db: db);
    _transport = customTransport;
    _meshService = customMeshService;
    if (nodeId != null && nodeId.isNotEmpty) _myNodeId = nodeId;
    if (userId != null && userId.isNotEmpty) _myUserId = userId;
  }

  // ---------------------------------------------------------------------------
  // Getters implementing EmergencyService
  // ---------------------------------------------------------------------------

  @override
  MeshStatus get meshStatus => _meshStatus;

  @override
  List<Person> get nearbyPeople => List.unmodifiable(_nearbyPeople);

  @override
  List<Person> get familyMembers => List.unmodifiable(_familyMembers);

  @override
  List<Person> get conversations {
    final Set<String> activeIds = _conversationMessages.keys.toSet();
    final List<Person> result = [];

    for (final id in activeIds) {
      final person = getPersonById(id) ??
          Person(
            id: id,
            name: id,
            relation: PersonRelation.nearby,
            status: PersonStatus.unreachable,
            hops: 1,
            lastSeen: 'Recently',
            locationAvailable: false,
            lastKnownLocation: 'Mesh Node',
          );
      result.add(person);
    }
    return result;
  }

  @override
  List<ui_msg.Message> get recentBroadcasts {
    final list = <ui_msg.Message>[];
    for (final a in _announcements) {
      list.add(ui_msg.Message(
        id: a.id,
        senderId: 'SYSTEM',
        receiverId: 'BROADCAST',
        senderName: a.source,
        content: a.message,
        timestamp: DateTime.now(),
        type: ui_msg.MessageType.broadcast,
        priority: a.severity == AnnouncementSeverity.evacuation
            ? ui_msg.MessagePriority.critical
            : ui_msg.MessagePriority.high,
        isFromMe: false,
      ));
    }
    return list;
  }

  @override
  List<EmergencyAnnouncement> get announcements => List.unmodifiable(_announcements);

  @override
  UserProfile? get userProfile => _userProfile;

  @override
  bool get isOnboardingCompleted => _userProfile?.isCompleted ?? false;

  @override
  String get selectedLanguage => _selectedLanguage;

  String get myNodeId => _myNodeId;
  String get myUserId => _myUserId;

  @override
  List<ui_msg.Message> getMessages(String personId) {
    return _conversationMessages[personId] ?? [];
  }

  @override
  Person? getPersonById(String id) {
    for (final f in _familyMembers) {
      if (f.id == id || f.phoneNumber == id) return f;
    }
    for (final p in _nearbyPeople) {
      if (p.id == id || p.phoneNumber == id) return p;
    }
    if (_transport is NearbyConnectionsTransport) {
      final name = (_transport as NearbyConnectionsTransport).discoveredNodeNames[id];
      if (name != null && name.isNotEmpty) {
        return Person(
          id: id,
          name: name,
          relation: PersonRelation.nearby,
          status: PersonStatus.reachable,
          hops: 1,
          lastSeen: 'Just now',
          locationAvailable: true,
          lastKnownLocation: 'Nearby Radio Range',
        );
      }
    }
    return null;
  }

  @override
  List<Person> get allKnownPeople {
    final map = <String, Person>{};
    for (final p in _familyMembers) {
      map[p.id] = p;
    }
    for (final p in _nearbyPeople) {
      map[p.id] = p;
    }
    return map.values.toList();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle & Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    // 1. Load User Profile from Native Bridge
    _userProfile = await NativeBridge.getProfile();
    if (_userProfile != null && _userProfile!.language.isNotEmpty) {
      _selectedLanguage = _userProfile!.language;
    }

    // 2. Load or generate permanent Node ID and User ID
    final prefs = await SharedPreferences.getInstance();
    _myNodeId = prefs.getString('sahara_node_id') ?? '';
    if (_myNodeId.isEmpty) {
      final rand = Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0').toUpperCase();
      _myNodeId = 'NODE_$rand';
      await prefs.setString('sahara_node_id', _myNodeId);
    }

    _myUserId = prefs.getString('sahara_user_id') ?? '';
    if (_myUserId.isEmpty) {
      final rand = Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0').toUpperCase();
      _myUserId = 'SH-$rand';
      await prefs.setString('sahara_user_id', _myUserId);
    }

    // 3. Load backend URL
    final savedUrl = await BackendClient.getStoredBackendUrl();
    backendClient.setBaseUrl(savedUrl);

    // 4. Load persisted data from SQLite
    await _loadPersistedData();

    // 5. Initialize Mesh Service with appropriate transport
    if (_transport == null) {
      if (NativeBridge.isAndroidDevice) {
        _transport = NearbyConnectionsTransport(
          localNodeId: _myNodeId,
          localDisplayName: _userProfile?.fullName,
        );
      } else {
        _transport = MockMeshTransport(localNodeId: _myNodeId);
      }
    } else if (_transport is NearbyConnectionsTransport) {
      (_transport as NearbyConnectionsTransport).localDisplayName = _userProfile?.fullName;
    }

    _meshService ??= MeshService(
      myNodeId: _myNodeId,
      myUserId: _myUserId,
      transport: _transport!,
    );

    // 6. Subscribe to Mesh Events
    _setupMeshListeners();

    // 7. Request runtime Android permissions & start mesh if granted
    await _initBluetoothAndMesh();

    // 8. Fetch real battery level
    try {
      final battery = await NativeBridge.getBatteryLevel();
      _meshStatus = _meshStatus.copyWith(batteryLevel: battery);
    } catch (_) {}

    // 9. Initial background sync with backend if online
    unawaited(syncWithBackend());

    notifyListeners();
  }

  Future<void> _loadPersistedData() async {
    // Load contacts
    final contacts = await db.getAllContacts();
    _familyMembers.clear();
    _nearbyPeople.clear();

    for (final c in contacts) {
      final person = Person(
        id: c['id'] as String,
        name: c['name'] as String? ?? 'Contact',
        relation: c['relation'] == 'family'
            ? PersonRelation.family
            : (c['relation'] == 'team'
                ? PersonRelation.emergencyTeam
                : PersonRelation.nearby),
        status: PersonStatus.unreachable,
        hops: c['hops'] as int? ?? 1,
        lastSeen: c['last_seen'] as String? ?? 'Offline',
        locationAvailable: (c['location_available'] as int? ?? 0) == 1,
        lastKnownLocation: c['last_known_location'] as String? ?? 'Mesh Node',
        coordinates: c['coordinates'] as String?,
        phoneNumber: c['phone_number'] as String?,
      );

      if (person.relation == PersonRelation.family) {
        _familyMembers.add(person);
      } else {
        _nearbyPeople.add(person);
      }
    }

    // Load messages from SQLite
    final allMessages = await db.getAllMessages();
    _conversationMessages.clear();

    for (final p in allMessages) {
      final isFromMe = p.senderId == _myUserId || p.senderNodeId == _myNodeId;
      final peerId = isFromMe ? p.receiverNodeId : p.senderNodeId;
      final senderName = isFromMe
          ? (_userProfile?.fullName ?? 'You')
          : (getPersonById(peerId)?.name ?? peerId);

      final msg = ui_msg.Message(
        id: p.messageId,
        senderId: p.senderId,
        receiverId: p.receiverId,
        senderName: senderName,
        content: p.content,
        timestamp: DateTime.fromMillisecondsSinceEpoch(p.timestamp),
        type: p.type == MessageType.sos
            ? ui_msg.MessageType.sosAlert
            : (p.type == MessageType.broadcast
                ? ui_msg.MessageType.broadcast
                : ui_msg.MessageType.text),
        priority: p.priority == MessagePriority.highest
            ? ui_msg.MessagePriority.critical
            : (p.priority == MessagePriority.high
                ? ui_msg.MessagePriority.high
                : ui_msg.MessagePriority.normal),
        isDelivered: p.status == MessageStatus.delivered || p.status == MessageStatus.synced,
        isFromMe: isFromMe,
        hops: 8 - p.ttl,
      );

      _conversationMessages.putIfAbsent(peerId, () => []).add(msg);
    }

    // Load emergency reports from SQLite into announcements
    final storedReports = await db.getAllEmergencyReports();
    _announcements.clear();

    // Include default emergency guidelines for disaster areas
    _announcements.addAll([
      EmergencyAnnouncement(
        id: 'ann_def_1',
        title: 'Cyclone Warning',
        message:
            'Heavy rainfall and wind speeds up to 65 km/h expected in your sector. Move to designated storm shelters.',
        source: 'IMD Alert Network',
        timeAgo: '10 min ago',
        severity: AnnouncementSeverity.warning,
        translations: BroadcastLocalizer.getTranslationsForComposed(
          title: 'Cyclone Warning',
          message:
              'Heavy rainfall and wind speeds up to 65 km/h expected in your sector. Move to designated storm shelters.',
          severity: AnnouncementSeverity.warning,
          source: 'IMD Alert Network',
        ),
      ),
      EmergencyAnnouncement(
        id: 'ann_def_2',
        title: 'Flood Evacuation Notice',
        message:
            'Water levels rising near river basin. Evacuation route B active. Keep battery disciplined and join mesh.',
        source: 'Disaster Relief Force',
        timeAgo: '25 min ago',
        severity: AnnouncementSeverity.evacuation,
        translations: BroadcastLocalizer.getTranslationsForComposed(
          title: 'Flood Evacuation Notice',
          message:
              'Water levels rising near river basin. Evacuation route B active. Keep battery disciplined and join mesh.',
          severity: AnnouncementSeverity.evacuation,
          source: 'Disaster Relief Force',
        ),
      ),
    ]);

    for (final r in storedReports) {
      final isEvac = (r['type'] as String? ?? '').contains('EVAC') ||
          (r['priority'] as String? ?? '') == 'Highest';
      _announcements.add(EmergencyAnnouncement(
        id: r['report_id'] as String,
        title: r['type'] as String? ?? 'Emergency Alert',
        message: r['details'] as String? ?? '',
        source: r['sender_id'] as String? ?? 'Mesh Alert',
        timeAgo: 'Recently',
        severity: isEvac ? AnnouncementSeverity.evacuation : AnnouncementSeverity.warning,
        translations: BroadcastLocalizer.getTranslationsForComposed(
          title: r['type'] as String? ?? 'Emergency Alert',
          message: r['details'] as String? ?? '',
          severity: isEvac ? AnnouncementSeverity.evacuation : AnnouncementSeverity.warning,
          source: r['sender_id'] as String? ?? 'Mesh Alert',
        ),
      ));
    }
  }

  void _resolveAndCacheSenderName(String peerNodeId, String peerDisplayName) {
    if (peerDisplayName.isEmpty || peerDisplayName == peerNodeId) return;

    bool changed = false;
    for (int i = 0; i < _nearbyPeople.length; i++) {
      if (_nearbyPeople[i].id == peerNodeId) {
        if (_nearbyPeople[i].name != peerDisplayName) {
          _nearbyPeople[i] = _nearbyPeople[i].copyWith(name: peerDisplayName);
          changed = true;
        }
      }
    }
    for (int i = 0; i < _familyMembers.length; i++) {
      if (_familyMembers[i].id == peerNodeId) {
        if (_familyMembers[i].name != peerDisplayName) {
          _familyMembers[i] = _familyMembers[i].copyWith(name: peerDisplayName);
          changed = true;
        }
      }
    }
    final msgs = _conversationMessages[peerNodeId];
    if (msgs != null) {
      for (int i = 0; i < msgs.length; i++) {
        if (!msgs[i].isFromMe && (msgs[i].senderName == peerNodeId || msgs[i].senderName.isEmpty)) {
          msgs[i] = msgs[i].copyWith(senderName: peerDisplayName);
          changed = true;
        }
      }
    }
    if (changed) {
      db.insertOrUpdateContact({
        'id': peerNodeId,
        'name': peerDisplayName,
        'relation': _familyMembers.any((f) => f.id == peerNodeId) ? 'family' : 'nearby',
        'status': 'reachable',
        'hops': 1,
        'last_seen': 'Just now',
        'location_available': 1,
        'last_known_location': 'Nearby Radio Range',
        'node_id': peerNodeId,
      });
      notifyListeners();
    }
  }

  void _setupMeshListeners() {
    if (_meshService == null) return;

    // 1. Peer connection / disconnection changes
    _peersSub = _meshService!.onPeersChanged.listen((connectedNodeIds) {
      _meshStatus = _meshStatus.copyWith(
        nearbyCount: connectedNodeIds.length,
        isMeshActive: true,
        activeRelays: connectedNodeIds.length,
      );

      // Update reachable statuses
      for (int i = 0; i < _nearbyPeople.length; i++) {
        final isConnected = connectedNodeIds.contains(_nearbyPeople[i].id);
        _nearbyPeople[i] = _nearbyPeople[i].copyWith(
          status: isConnected ? PersonStatus.reachable : PersonStatus.unreachable,
          lastSeen: isConnected ? 'Just now' : _nearbyPeople[i].lastSeen,
        );
      }

      for (int i = 0; i < _familyMembers.length; i++) {
        final isConnected = connectedNodeIds.contains(_familyMembers[i].id);
        _familyMembers[i] = _familyMembers[i].copyWith(
          status: isConnected ? PersonStatus.reachable : PersonStatus.unreachable,
          lastSeen: isConnected ? 'Just now' : _familyMembers[i].lastSeen,
        );
      }

      // Add newly connected peers not yet present in nearbyPeople
      for (final peerId in connectedNodeIds) {
        if (!_nearbyPeople.any((p) => p.id == peerId) && !_familyMembers.any((f) => f.id == peerId)) {
          final discoveredName = (_transport is NearbyConnectionsTransport)
              ? (_transport as NearbyConnectionsTransport).discoveredNodeNames[peerId]
              : null;
          final displayName = (discoveredName != null && discoveredName.isNotEmpty)
              ? discoveredName
              : peerId;
          _nearbyPeople.add(Person(
            id: peerId,
            name: displayName,
            relation: PersonRelation.nearby,
            status: PersonStatus.reachable,
            hops: 1,
            lastSeen: 'Just now',
            locationAvailable: true,
            lastKnownLocation: 'Nearby Radio Range',
          ));
        }

        // Send handshake packet to newly connected peers so they know our user info
        _sendPeerHandshake(peerId);
      }

      notifyListeners();
    });

    // 2. Incoming messages
    _messagesSub = _meshService!.onMessageReceived.listen((packet) async {
      // Check if this is an internal handshake packet
      if (packet.type == 'STATUS' || packet.type == 'HANDSHAKE') {
        _handlePeerHandshakePacket(packet);
        return;
      }

      // Standard text message
      await db.insertMessage(packet);

      if (packet.senderName != null && packet.senderName!.isNotEmpty && packet.senderName != packet.senderNodeId) {
        _resolveAndCacheSenderName(packet.senderNodeId, packet.senderName!);
      }

      final senderName = getPersonById(packet.senderNodeId)?.name ??
          (packet.senderName != null && packet.senderName!.isNotEmpty ? packet.senderName! : packet.senderNodeId);

      final uiMessage = ui_msg.Message(
        id: packet.messageId,
        senderId: packet.senderId,
        receiverId: packet.receiverId,
        senderName: senderName,
        content: packet.content,
        timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
        type: ui_msg.MessageType.text,
        priority: ui_msg.MessagePriority.normal,
        isDelivered: true,
        isFromMe: false,
        hops: 8 - packet.ttl,
      );

      _conversationMessages.putIfAbsent(packet.senderNodeId, () => []).add(uiMessage);
      notifyListeners();

      final isFamily = _familyMembers.any((f) =>
          f.id == packet.senderNodeId ||
          f.id == packet.senderId ||
          (f.phoneNumber != null && f.phoneNumber!.isNotEmpty && f.phoneNumber == packet.senderId));
      if (isFamily) {
        NotificationService().showFamilyMessageNotification(
          senderName: senderName,
          content: packet.content,
          personId: packet.senderNodeId,
        );
      }
    });

    // 3. High-priority SOS received
    _sosSub = _meshService!.onSosReceived.listen((packet) async {
      await db.insertMessage(packet);
      await db.insertEmergencyReport({
        'report_id': packet.messageId,
        'sender_id': packet.senderId,
        'type': 'SOS',
        'priority': 'Highest',
        'details': packet.content,
        'timestamp': packet.timestamp,
        'status': 'PENDING',
      });

      _meshStatus = _meshStatus.copyWith(isBroadcastingSOS: true);

      if (packet.senderName != null && packet.senderName!.isNotEmpty && packet.senderName != packet.senderNodeId) {
        _resolveAndCacheSenderName(packet.senderNodeId, packet.senderName!);
      }
      final sourceName = getPersonById(packet.senderNodeId)?.name ??
          (packet.senderName != null && packet.senderName!.isNotEmpty ? packet.senderName! : packet.senderNodeId);

      final announcement = EmergencyAnnouncement(
        id: packet.messageId,
        title: 'DISTRESS SOS ALERT',
        message: packet.content,
        source: sourceName,
        timeAgo: 'Just now',
        severity: AnnouncementSeverity.evacuation,
        translations: BroadcastLocalizer.getTranslationsForComposed(
          title: 'DISTRESS SOS ALERT',
          message: packet.content,
          severity: AnnouncementSeverity.evacuation,
          source: sourceName,
        ),
      );

      _announcements.insert(0, announcement);
      notifyListeners();

      NotificationService().showEmergencyBroadcastNotification(
        title: 'DISTRESS SOS ALERT',
        message: packet.content,
        severity: AnnouncementSeverity.evacuation,
        id: packet.messageId,
      );
    });

    // 4. Emergency Broadcast received
    _broadcastSub = _meshService!.onBroadcastReceived.listen((packet) async {
      await db.insertMessage(packet);

      if (packet.senderName != null && packet.senderName!.isNotEmpty && packet.senderName != packet.senderNodeId) {
        _resolveAndCacheSenderName(packet.senderNodeId, packet.senderName!);
      }
      final sourceName = getPersonById(packet.senderNodeId)?.name ??
          (packet.senderName != null && packet.senderName!.isNotEmpty ? packet.senderName! : packet.senderNodeId);

      final announcement = EmergencyAnnouncement(
        id: packet.messageId,
        title: 'EMERGENCY BROADCAST',
        message: packet.content,
        source: sourceName,
        timeAgo: 'Just now',
        severity: AnnouncementSeverity.warning,
        translations: BroadcastLocalizer.getTranslationsForComposed(
          title: 'EMERGENCY BROADCAST',
          message: packet.content,
          severity: AnnouncementSeverity.warning,
          source: sourceName,
        ),
      );

      _announcements.insert(0, announcement);
      notifyListeners();

      NotificationService().showEmergencyBroadcastNotification(
        title: 'EMERGENCY BROADCAST',
        message: packet.content,
        severity: AnnouncementSeverity.warning,
        id: packet.messageId,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Bluetooth Discovery & Handshake Protocol
  // ---------------------------------------------------------------------------

  Future<void> _initBluetoothAndMesh() async {
    final hasPermissions = await NativeBridge.checkBluetoothPermissions();
    if (!hasPermissions) {
      await NativeBridge.requestBluetoothPermissions();
    }

    final isBtOn = await NativeBridge.isBluetoothEnabled();
    if (!isBtOn) {
      await NativeBridge.enableBluetooth();
    }

    try {
      await _meshService?.start();
      _meshStatus = _meshStatus.copyWith(isMeshActive: true);
    } catch (_) {
      _meshStatus = _meshStatus.copyWith(isMeshActive: false);
    }
  }

  Future<void> _sendPeerHandshake(String peerNodeId) async {
    try {
      final myName = _userProfile?.fullName ?? '';
      final payload = jsonEncode({
        'name': myName.isNotEmpty ? myName : 'SAHARA User',
        'phone': _userProfile?.phoneNumber ?? '',
        'user_id': _myUserId,
        'node_id': _myNodeId,
      });

      final handshakePacket = MessagePacket(
        messageId: 'HS_${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _myUserId,
        receiverId: peerNodeId,
        senderNodeId: _myNodeId,
        receiverNodeId: peerNodeId,
        type: 'STATUS',
        priority: MessagePriority.normal,
        content: payload,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        ttl: 1,
        status: MessageStatus.delivered,
        senderName: myName.isNotEmpty ? myName : 'SAHARA User',
      );

      await _transport?.sendRawPacket(peerNodeId, handshakePacket.toUtf8Bytes());
    } catch (_) {}
  }

  void _handlePeerHandshakePacket(MessagePacket packet) {
    try {
      final data = jsonDecode(packet.content) as Map<String, dynamic>;
      final peerName = data['name'] as String? ?? packet.senderName ?? packet.senderNodeId;
      final peerPhone = data['phone'] as String? ?? '';
      final peerUserId = data['user_id'] as String? ?? packet.senderId;
      final peerNodeId = packet.senderNodeId;

      final resolvedName = (peerName.isNotEmpty && peerName != peerNodeId)
          ? peerName
          : (packet.senderName != null && packet.senderName!.isNotEmpty && packet.senderName != peerNodeId
              ? packet.senderName!
              : peerNodeId);

      _resolveAndCacheSenderName(peerNodeId, resolvedName);

      final existingFamIdx = _familyMembers.indexWhere((f) =>
          f.id == peerNodeId || f.id == peerUserId || (peerPhone.isNotEmpty && f.phoneNumber == peerPhone));
      if (existingFamIdx >= 0) {
        _familyMembers[existingFamIdx] = _familyMembers[existingFamIdx].copyWith(
          name: resolvedName,
          status: PersonStatus.reachable,
          lastSeen: 'Just now',
          phoneNumber: peerPhone.isNotEmpty ? peerPhone : _familyMembers[existingFamIdx].phoneNumber,
        );
      }

      final existingIndex = _nearbyPeople.indexWhere((p) =>
          p.id == peerNodeId || p.id == peerUserId || (peerPhone.isNotEmpty && p.phoneNumber == peerPhone));
      final person = Person(
        id: peerNodeId,
        name: resolvedName,
        relation: PersonRelation.nearby,
        status: PersonStatus.reachable,
        hops: 1,
        lastSeen: 'Just now',
        locationAvailable: true,
        lastKnownLocation: 'Nearby Radio Range',
        phoneNumber: peerPhone.isNotEmpty ? peerPhone : null,
      );

      if (existingIndex >= 0) {
        _nearbyPeople[existingIndex] = person;
      } else if (existingFamIdx < 0) {
        _nearbyPeople.add(person);
      }

      // Persist contact in SQLite
      db.insertOrUpdateContact({
        'id': peerNodeId,
        'name': resolvedName,
        'relation': existingFamIdx >= 0 ? 'family' : 'nearby',
        'status': 'reachable',
        'hops': 1,
        'last_seen': 'Just now',
        'location_available': 1,
        'last_known_location': 'Nearby Radio Range',
        'phone_number': peerPhone,
        'user_id': peerUserId,
        'node_id': peerNodeId,
      });

      notifyListeners();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Messaging Actions
  // ---------------------------------------------------------------------------

  @override
  void sendMessage({
    required String receiverId,
    required String content,
    ui_msg.MessagePriority priority = ui_msg.MessagePriority.normal,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || _meshService == null) return;

    final person = getPersonById(receiverId);
    final targetNodeId = receiverId;
    final targetUserId = person?.phoneNumber ?? receiverId;

    String packetPriority = MessagePriority.normal;
    if (priority == ui_msg.MessagePriority.critical) {
      packetPriority = MessagePriority.highest;
    } else if (priority == ui_msg.MessagePriority.high) {
      packetPriority = MessagePriority.high;
    }

    final packetId = 'MSG_${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final now = DateTime.now();

    final myName = _userProfile?.fullName ?? 'You';

    final packet = MessagePacket(
      messageId: packetId,
      senderId: _myUserId,
      receiverId: targetUserId,
      senderNodeId: _myNodeId,
      receiverNodeId: targetNodeId,
      type: MessageType.text,
      priority: packetPriority,
      content: trimmed,
      timestamp: now.millisecondsSinceEpoch,
      ttl: 8,
      status: MessageStatus.pending,
      senderName: myName,
    );

    // Save to SQLite
    await db.insertMessage(packet);

    // Add to UI state
    final uiMessage = ui_msg.Message(
      id: packetId,
      senderId: _myUserId,
      receiverId: targetUserId,
      senderName: myName,
      content: trimmed,
      timestamp: now,
      type: ui_msg.MessageType.text,
      priority: priority,
      isDelivered: _meshService!.connectedPeers.contains(targetNodeId),
      isFromMe: true,
      hops: 1,
    );

    _conversationMessages.putIfAbsent(targetNodeId, () => []).add(uiMessage);
    notifyListeners();

    // Dispatch across mesh transport
    await _meshService!.sendDirectMessage(
      receiverNodeId: targetNodeId,
      receiverUserId: targetUserId,
      content: trimmed,
      senderName: myName,
      priority: packetPriority,
      messageId: packetId,
    );

    // Trigger background sync with backend if online
    unawaited(syncWithBackend());
  }

  @override
  void sendBroadcast({required String content}) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || _meshService == null) return;

    final myName = _userProfile?.fullName ?? 'SAHARA Alert';
    await _meshService!.sendEmergencyBroadcast(
      content: trimmed,
      senderName: myName,
    );
    unawaited(syncWithBackend());
    notifyListeners();

    NotificationService().showEmergencyBroadcastNotification(
      title: 'Emergency Broadcast Sent',
      message: trimmed,
      severity: AnnouncementSeverity.warning,
    );
  }

  @override
  void triggerSOS({String? locationCoordinates}) async {
    _meshStatus = _meshStatus.copyWith(isBroadcastingSOS: true);
    notifyListeners();

    final details = locationCoordinates != null && locationCoordinates.isNotEmpty
        ? 'CRITICAL SOS DISTRESS BEACON — Coordinates: $locationCoordinates'
        : 'CRITICAL SOS DISTRESS BEACON — Immediate Assistance Required';

    final packetId = 'SOS_${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}';
    final myName = _userProfile?.fullName ?? 'SOS Beacon';

    await db.insertEmergencyReport({
      'report_id': packetId,
      'sender_id': _myUserId,
      'type': 'SOS',
      'location': locationCoordinates,
      'priority': 'Highest',
      'details': details,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'PENDING',
    });

    await _meshService?.sendSosAlert(
      location: locationCoordinates,
      details: details,
      senderName: myName,
      messageId: packetId,
    );

    unawaited(syncWithBackend());

    NotificationService().showEmergencyBroadcastNotification(
      title: 'EMERGENCY DISTRESS BEACON',
      message: details,
      severity: AnnouncementSeverity.evacuation,
      id: packetId,
    );
  }

  @override
  void cancelSOS() {
    _meshStatus = _meshStatus.copyWith(isBroadcastingSOS: false);
    notifyListeners();
  }

  @override
  void pingPerson(String personId) async {
    if (_meshService == null) return;
    sendMessage(
      receiverId: personId,
      content: 'PING [Radio Connectivity Check]',
      priority: ui_msg.MessagePriority.normal,
    );
  }

  @override
  int pingFamilyAll() {
    int sent = 0;
    for (final member in _familyMembers) {
      if (member.isReachable) {
        pingPerson(member.id);
        sent++;
      }
    }
    return sent;
  }

  @override
  void addPersonToFamily(Person person) async {
    final updated = person.copyWith(relation: PersonRelation.family);
    final idx = _nearbyPeople.indexWhere((p) => p.id == person.id);
    if (idx >= 0) {
      _nearbyPeople.removeAt(idx);
    }

    final famIdx = _familyMembers.indexWhere((f) => f.id == person.id);
    if (famIdx >= 0) {
      _familyMembers[famIdx] = updated;
    } else {
      _familyMembers.add(updated);
    }

    await db.insertOrUpdateContact({
      'id': updated.id,
      'name': updated.name,
      'relation': 'family',
      'status': updated.status.name,
      'hops': updated.hops,
      'last_seen': updated.lastSeen,
      'location_available': updated.locationAvailable ? 1 : 0,
      'last_known_location': updated.lastKnownLocation,
      'coordinates': updated.coordinates,
      'phone_number': updated.phoneNumber,
      'user_id': updated.phoneNumber ?? updated.id,
      'node_id': updated.id,
    });

    // If online, sync to backend
    if (updated.phoneNumber != null) {
      unawaited(backendClient.addFamilyLink(
        familyId: 'FAM_$_myUserId',
        userId: _myUserId,
        familyMemberId: updated.phoneNumber!,
        relationship: 'Family',
      ));
    }

    notifyListeners();
  }

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
  List<Person> searchPeople(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    final results = allKnownPeople.where((p) {
      final nameMatch = p.name.toLowerCase().contains(clean);
      final phoneMatch = p.phoneNumber?.toLowerCase().contains(clean) ?? false;
      final locMatch = p.lastKnownLocation.toLowerCase().contains(clean);
      return nameMatch || phoneMatch || locMatch;
    }).toList();

    // If query looks like a phone number and backend is online, query backend asynchronously
    final digitsOnly = clean.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= 10 && !results.any((r) => r.phoneNumber?.contains(digitsOnly) ?? false)) {
      unawaited(_lookupRemotePhone(clean));
    }

    return results;
  }

  Future<void> _lookupRemotePhone(String rawPhone) async {
    try {
      final res = await backendClient.lookupByPhone(rawPhone);
      if (res != null) {
        final remoteUserId = res['user_id'] as String? ?? '';
        final remoteName = res['name'] as String? ?? 'Discovered User';
        final remoteStatus = res['status'] as String? ?? 'SAFE';

        final person = Person(
          id: remoteUserId,
          name: remoteName,
          relation: PersonRelation.nearby,
          status: PersonStatus.unreachable,
          hops: 1,
          lastSeen: 'Discovered via Backend',
          locationAvailable: false,
          lastKnownLocation: 'Registered User ($remoteStatus)',
          phoneNumber: rawPhone,
        );

        if (!_nearbyPeople.any((p) => p.id == person.id)) {
          _nearbyPeople.add(person);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  @override
  void updateRealBattery(int batteryPercent) {
    _meshStatus = _meshStatus.copyWith(batteryLevel: batteryPercent);
    notifyListeners();
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    _userProfile = profile;
    await NativeBridge.saveProfile(profile);

    // Register with backend
    try {
      final reg = await backendClient.registerUser(
        name: profile.fullName,
        phone: profile.phoneNumber,
        status: 'SAFE',
        userId: _myUserId,
      );
      if (reg != null && reg['user_id'] != null) {
        _myUserId = reg['user_id'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sahara_user_id', _myUserId);
      }
    } catch (_) {}

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

  // ---------------------------------------------------------------------------
  // Backend Cloud / LAN Sync
  // ---------------------------------------------------------------------------

  Future<SyncResult> syncWithBackend() async {
    final result = await syncService.syncAll(myUserId: _myUserId);
    if (result.success) {
      _meshStatus = _meshStatus.copyWith(lastSynced: syncService.lastSynced ?? DateTime.now());
      notifyListeners();
    }
    return result;
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    _messagesSub?.cancel();
    _sosSub?.cancel();
    _broadcastSub?.cancel();
    _meshService?.dispose();
    super.dispose();
  }
}
