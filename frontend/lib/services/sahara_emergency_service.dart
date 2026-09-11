import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/demo_config.dart';
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
  final Set<String> _verifiedPeers = <String>{};
  final Set<String> _processedEmergencyEventIds = <String>{};
  final Set<String> _processedPingIds = <String>{};
  final Set<String> _historyRequestedPeers = <String>{};
  String? _activeChatPersonId;

  @override
  void setActiveChatPersonId(String? personId) {
    _activeChatPersonId = personId;
  }

  StreamSubscription<List<String>>? _peersSub;
  StreamSubscription<MessagePacket>? _messagesSub;
  StreamSubscription<MessagePacket>? _sosSub;
  StreamSubscription<MessagePacket>? _broadcastSub;
  StreamSubscription<MessagePacket>? _pingSub;

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
  List<Person> get nearbyPeople {
    if (!DemoConfig.showDemoData) {
      return List.unmodifiable(_nearbyPeople);
    }
    final realIds = _nearbyPeople.map((p) => p.id).toSet();
    final demoPeers = DemoConfig.demoNearbyPeople.where((d) => !realIds.contains(d.id));
    return List.unmodifiable([..._nearbyPeople, ...demoPeers]);
  }

  @override
  List<Person> get familyMembers {
    if (!DemoConfig.showDemoData) {
      return List.unmodifiable(_familyMembers);
    }
    final realFamIds = _familyMembers.map((f) => f.id).toSet();
    final demoFam = DemoConfig.demoFamilyMembers.where((d) => !realFamIds.contains(d.id));
    return List.unmodifiable([..._familyMembers, ...demoFam]);
  }

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
            status: _verifiedPeers.contains(id) ? PersonStatus.reachable : PersonStatus.unreachable,
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
    final direct = _conversationMessages[personId];
    if (direct != null && direct.isNotEmpty) return direct;

    final person = getPersonById(personId);
    if (person != null) {
      if (person.phoneNumber != null && _conversationMessages.containsKey(person.phoneNumber)) {
        final msgs = _conversationMessages[person.phoneNumber];
        if (msgs != null && msgs.isNotEmpty) return msgs;
      }
      if (person.id != personId && _conversationMessages.containsKey(person.id)) {
        final msgs = _conversationMessages[person.id];
        if (msgs != null && msgs.isNotEmpty) return msgs;
      }
    }

    for (final entry in _conversationMessages.entries) {
      if (entry.key.trim().toUpperCase() == personId.trim().toUpperCase()) {
        return entry.value;
      }
    }
    return [];
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
      if (name != null && name.isNotEmpty && name != 'SAHARA User' && name != 'Sahara User') {
        return Person(
          id: id,
          name: name,
          relation: PersonRelation.nearby,
          status: _verifiedPeers.contains(id) ? PersonStatus.reachable : PersonStatus.unreachable,
          hops: 1,
          lastSeen: 'Discovered',
          locationAvailable: true,
          lastKnownLocation: 'Nearby Radio Range',
        );
      }
    }
    if (DemoConfig.showDemoData) {
      for (final f in DemoConfig.demoFamilyMembers) {
        if (f.id == id || f.phoneNumber == id) return f;
      }
      for (final p in DemoConfig.demoNearbyPeople) {
        if (p.id == id || p.phoneNumber == id) return p;
      }
    }
    return null;
  }

  @override
  List<Person> get allKnownPeople {
    final map = <String, Person>{};
    for (final p in familyMembers) {
      map[p.id] = p;
    }
    for (final p in nearbyPeople) {
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
      if (p.type == MessageType.broadcast || p.type == MessageType.sos) {
        _processedEmergencyEventIds.add(p.messageId);
      }
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
      final repId = r['report_id'] as String;
      _processedEmergencyEventIds.add(repId);
      final isEvac = (r['type'] as String? ?? '').contains('EVAC') ||
          (r['priority'] as String? ?? '') == 'Highest';
      final src = (r['sender_name'] as String?)?.isNotEmpty == true
          ? (r['sender_name'] as String)
          : (r['sender_id'] as String? ?? 'Mesh Alert');
      _announcements.add(EmergencyAnnouncement(
        id: repId,
        title: r['type'] as String? ?? 'Emergency Alert',
        message: r['details'] as String? ?? '',
        source: src,
        timeAgo: 'Recently',
        severity: isEvac ? AnnouncementSeverity.evacuation : AnnouncementSeverity.warning,
        translations: BroadcastLocalizer.getTranslationsForComposed(
          title: r['type'] as String? ?? 'Emergency Alert',
          message: r['details'] as String? ?? '',
          severity: isEvac ? AnnouncementSeverity.evacuation : AnnouncementSeverity.warning,
          source: src,
        ),
      ));
    }
  }

  void _resolveAndCacheSenderName(String peerNodeId, String peerDisplayName) {
    if (peerDisplayName.isEmpty ||
        peerDisplayName == peerNodeId ||
        peerDisplayName == 'SAHARA User' ||
        peerDisplayName == 'Sahara User') {
      return;
    }

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
        if (!msgs[i].isFromMe && (msgs[i].senderName == peerNodeId || msgs[i].senderName.isEmpty || msgs[i].senderName == 'SAHARA User')) {
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
        'status': _verifiedPeers.contains(peerNodeId) ? 'reachable' : 'unreachable',
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
      debugPrint('[SAHARA SERVICE] onPeersChanged: connected=$connectedNodeIds, currentlyVerified=$_verifiedPeers');

      for (final id in _verifiedPeers) {
        if (!connectedNodeIds.contains(id)) {
          debugPrint('[SAHARA-BG] CONNECTION_LOST_BACKGROUND peer=$id');
        }
      }

      // Drop peers that have physically disconnected from verified list
      _verifiedPeers.removeWhere((id) => !connectedNodeIds.contains(id));
      _historyRequestedPeers.removeWhere((id) => !connectedNodeIds.contains(id));

      _meshStatus = _meshStatus.copyWith(
        nearbyCount: _verifiedPeers.length,
        isMeshActive: connectedNodeIds.isNotEmpty,
        activeRelays: connectedNodeIds.length,
      );

      // Update reachable statuses: ONLY verified peers show as reachable in UI
      for (int i = 0; i < _nearbyPeople.length; i++) {
        final isVerified = _verifiedPeers.contains(_nearbyPeople[i].id);
        _nearbyPeople[i] = _nearbyPeople[i].copyWith(
          status: isVerified ? PersonStatus.reachable : PersonStatus.unreachable,
          lastSeen: isVerified ? 'Just now' : _nearbyPeople[i].lastSeen,
        );
      }

      for (int i = 0; i < _familyMembers.length; i++) {
        final isVerified = _verifiedPeers.contains(_familyMembers[i].id);
        _familyMembers[i] = _familyMembers[i].copyWith(
          status: isVerified ? PersonStatus.reachable : PersonStatus.unreachable,
          lastSeen: isVerified ? 'Just now' : _familyMembers[i].lastSeen,
        );
      }

      // Add newly connected peers not yet present in nearbyPeople
      for (final peerId in connectedNodeIds) {
        if (!_nearbyPeople.any((p) => p.id == peerId) && !_familyMembers.any((f) => f.id == peerId)) {
          final discoveredName = (_transport is NearbyConnectionsTransport)
              ? (_transport as NearbyConnectionsTransport).discoveredNodeNames[peerId]
              : null;
          final displayName = (discoveredName != null &&
                  discoveredName.isNotEmpty &&
                  discoveredName != 'SAHARA User' &&
                  discoveredName != 'Sahara User')
              ? discoveredName
              : peerId;

          _nearbyPeople.add(Person(
            id: peerId,
            name: displayName,
            relation: PersonRelation.nearby,
            status: _verifiedPeers.contains(peerId) ? PersonStatus.reachable : PersonStatus.unreachable,
            hops: 1,
            lastSeen: 'Discovered',
            locationAvailable: true,
            lastKnownLocation: 'Nearby Radio Range',
          ));
        }

        // Send application-level HANDSHAKE_INIT to verify bidirectional data path and exchange identity
        _sendPeerHandshakeInit(peerId);
      }

      notifyListeners();
    });

    // 2. Incoming messages
    _messagesSub = _meshService!.onMessageReceived.listen((packet) async {
      debugPrint('[SAHARA SERVICE] onMessageReceived: id=${packet.messageId}, type=${packet.type}, fromNode=${packet.senderNodeId}, fromUser=${packet.senderId}');
      debugPrint('[SAHARA-BG] PACKET_RECEIVED_BACKGROUND id=${packet.messageId} type=${packet.type}');

      // Check if this is an internal handshake/status/profile packet
      if (packet.type == 'STATUS' ||
          packet.type == 'HANDSHAKE' ||
          packet.type == 'HANDSHAKE_INIT' ||
          packet.type == 'HANDSHAKE_ACK' ||
          packet.type == 'PROFILE_UPDATE') {
        _handlePeerHandshakePacket(packet);
        return;
      }

      if (packet.type == 'HISTORY_REQUEST') {
        _handleHistoryRequest(packet);
        return;
      }

      if (packet.type == 'HISTORY_RESPONSE') {
        _handleHistoryResponse(packet);
        return;
      }

      // Standard text message: Persist safely to SQLite
      try {
        await db.insertMessage(packet);
      } catch (e) {
        debugPrint('[SAHARA DB] Error inserting incoming message: $e');
      }

      if (packet.senderName != null &&
          packet.senderName!.isNotEmpty &&
          packet.senderName != packet.senderNodeId &&
          packet.senderName != 'SAHARA User' &&
          packet.senderName != 'Sahara User') {
        _resolveAndCacheSenderName(packet.senderNodeId, packet.senderName!);
      }

      final senderName = getPersonById(packet.senderNodeId)?.name ??
          (packet.senderName != null && packet.senderName!.isNotEmpty && packet.senderName != 'SAHARA User'
              ? packet.senderName!
              : packet.senderNodeId);

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

      // Index under senderNodeId as well as senderId/user_id for seamless chat lookup
      _conversationMessages.putIfAbsent(packet.senderNodeId, () => []).add(uiMessage);
      if (packet.senderId.isNotEmpty && packet.senderId != packet.senderNodeId) {
        _conversationMessages.putIfAbsent(packet.senderId, () => []).add(uiMessage);
      }
      notifyListeners();

      final isFamily = _familyMembers.any((f) =>
          f.id == packet.senderNodeId ||
          f.id == packet.senderId ||
          (f.phoneNumber != null && f.phoneNumber!.isNotEmpty && f.phoneNumber == packet.senderId) ||
          (f.name.trim().isNotEmpty && f.name.trim().toLowerCase() == senderName.trim().toLowerCase()));

      final isCurrentlyViewingChat = _activeChatPersonId != null &&
          (_activeChatPersonId == packet.senderNodeId ||
           _activeChatPersonId == packet.senderId ||
           _activeChatPersonId == senderName);

      if (isFamily && !isCurrentlyViewingChat) {
        debugPrint('[SAHARA-NOTIFY] POSTING_FAMILY_NOTIFICATION sender=$senderName');
        await NotificationService().showFamilyMessageNotification(
          senderName: senderName,
          content: packet.content,
          personId: packet.senderNodeId,
        );
        debugPrint('[SAHARA-NOTIFY] VIBRATION_TRIGGERED');
        debugPrint('[SAHARA-NOTIFY] NOTIFICATION_POSTED');
      }
    });

    // 3. High-priority SOS received
    _sosSub = _meshService!.onSosReceived.listen((packet) async {
      debugPrint('[SAHARA SERVICE] onSosReceived: id=${packet.messageId}, from=${packet.senderNodeId}');
      debugPrint('[SAHARA-BG] PACKET_RECEIVED_BACKGROUND id=${packet.messageId} type=SOS');
      debugPrint('[SAHARA-BG] EMERGENCY_RECEIVED_BACKGROUND id=${packet.messageId}');
      try {
        await db.insertMessage(packet);
        await db.insertEmergencyReport({
          'report_id': packet.messageId,
          'sender_id': packet.senderId,
          'type': 'SOS',
          'priority': 'Highest',
          'details': packet.content,
          'timestamp': packet.timestamp,
          'status': 'PENDING',
          'sender_name': packet.senderName ?? packet.senderNodeId,
        });
      } catch (e) {
        debugPrint('[SAHARA DB] Error persisting SOS alert: $e');
      }

      if (packet.senderName != null &&
          packet.senderName!.isNotEmpty &&
          packet.senderName != packet.senderNodeId &&
          packet.senderName != 'SAHARA User') {
        _resolveAndCacheSenderName(packet.senderNodeId, packet.senderName!);
      }
      final sourceName = getPersonById(packet.senderNodeId)?.name ??
          (packet.senderName != null && packet.senderName!.isNotEmpty ? packet.senderName! : packet.senderNodeId);

      await handleEmergencyEvent(
        eventId: packet.messageId,
        title: 'DISTRESS SOS ALERT',
        message: packet.content,
        severity: AnnouncementSeverity.evacuation,
        sourceName: sourceName,
        isLive: true,
      );
    });

    // 4. Emergency Broadcast received
    _broadcastSub = _meshService!.onBroadcastReceived.listen((packet) async {
      debugPrint('[SAHARA SERVICE] onBroadcastReceived: id=${packet.messageId}, content=${packet.content}, from=${packet.senderNodeId}');
      debugPrint('[SAHARA-BG] PACKET_RECEIVED_BACKGROUND id=${packet.messageId} type=BROADCAST');
      debugPrint('[SAHARA-BG] EMERGENCY_RECEIVED_BACKGROUND id=${packet.messageId}');
      try {
        await db.insertMessage(packet);
        await db.insertEmergencyReport({
          'report_id': packet.messageId,
          'sender_id': packet.senderId,
          'type': 'BROADCAST',
          'priority': 'High',
          'details': packet.content,
          'timestamp': packet.timestamp,
          'status': 'DELIVERED',
          'sender_name': packet.senderName ?? packet.senderNodeId,
        });
      } catch (e) {
        debugPrint('[SAHARA DB] Error persisting broadcast: $e');
      }

      if (packet.senderName != null &&
          packet.senderName!.isNotEmpty &&
          packet.senderName != packet.senderNodeId &&
          packet.senderName != 'SAHARA User') {
        _resolveAndCacheSenderName(packet.senderNodeId, packet.senderName!);
      }
      final sourceName = getPersonById(packet.senderNodeId)?.name ??
          (packet.senderName != null && packet.senderName!.isNotEmpty ? packet.senderName! : packet.senderNodeId);

      await handleEmergencyEvent(
        eventId: packet.messageId,
        title: 'EMERGENCY BROADCAST',
        message: packet.content,
        severity: AnnouncementSeverity.warning,
        sourceName: sourceName,
        isLive: true,
      );
    });

    // 5. Peer Ping check received
    _pingSub = _meshService!.onPingReceived.listen((packet) async {
      debugPrint('[SAHARA-BG] PACKET_RECEIVED_BACKGROUND id=${packet.messageId} type=PING');
      debugPrint('[SAHARA-PING] RECEIVED id=${packet.messageId} from=${packet.senderName ?? packet.senderNodeId}');
      if (_processedPingIds.contains(packet.messageId)) {
        return;
      }
      _processedPingIds.add(packet.messageId);
      if (_processedPingIds.length > 200) {
        _processedPingIds.remove(_processedPingIds.first);
      }

      final pingSender = (packet.senderName != null && packet.senderName!.isNotEmpty && packet.senderName != 'SAHARA User')
          ? packet.senderName!
          : (getPersonById(packet.senderNodeId)?.name ?? packet.senderNodeId);

      await NotificationService().showPingNotification(
        senderName: pingSender,
        personId: packet.senderNodeId,
        id: packet.messageId,
      );
      debugPrint('[SAHARA-PING] NOTIFICATION_POSTED');
      debugPrint('[SAHARA-PING] VIBRATION_TRIGGERED');
    });
  }

  // ---------------------------------------------------------------------------
  // Bluetooth Discovery & Application-Level Handshake Protocol
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

    // Launch Android Foreground Service for locked-screen mesh survival
    await NativeBridge.startMeshForegroundService();
    debugPrint('[SAHARA-BG] MESH_LISTENER_ACTIVE service started');

    try {
      await _meshService?.start();
      _meshStatus = _meshStatus.copyWith(isMeshActive: true);
    } catch (_) {
      _meshStatus = _meshStatus.copyWith(isMeshActive: false);
    }
  }

  /// Sends application-level HANDSHAKE_INIT with challenge nonce to verify the data transport
  Future<void> _sendPeerHandshakeInit(String peerNodeId) async {
    try {
      final myName = _userProfile?.fullName.trim() ?? '';
      final nonce = Random().nextInt(0x7FFFFFFF).toString();
      final payload = jsonEncode({
        'type': 'HANDSHAKE_INIT',
        'name': myName,
        'phone': _userProfile?.phoneNumber ?? '',
        'user_id': _myUserId,
        'node_id': _myNodeId,
        'nonce': nonce,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final handshakePacket = MessagePacket(
        messageId: 'HS_INIT_${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _myUserId,
        receiverId: peerNodeId,
        senderNodeId: _myNodeId,
        receiverNodeId: peerNodeId,
        type: 'HANDSHAKE_INIT',
        priority: MessagePriority.highest,
        content: payload,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        ttl: 1,
        status: MessageStatus.delivered,
        senderName: myName,
      );

      debugPrint('[SAHARA HANDSHAKE] Sending HANDSHAKE_INIT to $peerNodeId (nonce=$nonce, name="$myName")...');
      await _transport?.sendRawPacket(peerNodeId, handshakePacket.toUtf8Bytes());
    } catch (e) {
      debugPrint('[SAHARA HANDSHAKE] Error sending HANDSHAKE_INIT to $peerNodeId: $e');
    }
  }

  /// Sends application-level HANDSHAKE_ACK echoing the peer's nonce to confirm verified connectivity
  Future<void> _sendPeerHandshakeAck(String peerNodeId, String peerNonce) async {
    try {
      final myName = _userProfile?.fullName.trim() ?? '';
      final payload = jsonEncode({
        'type': 'HANDSHAKE_ACK',
        'name': myName,
        'phone': _userProfile?.phoneNumber ?? '',
        'user_id': _myUserId,
        'node_id': _myNodeId,
        'ack_nonce': peerNonce,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final ackPacket = MessagePacket(
        messageId: 'HS_ACK_${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _myUserId,
        receiverId: peerNodeId,
        senderNodeId: _myNodeId,
        receiverNodeId: peerNodeId,
        type: 'HANDSHAKE_ACK',
        priority: MessagePriority.highest,
        content: payload,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        ttl: 1,
        status: MessageStatus.delivered,
        senderName: myName,
      );

      debugPrint('[SAHARA HANDSHAKE] Sending HANDSHAKE_ACK to $peerNodeId (ackNonce=$peerNonce, name="$myName")...');
      await _transport?.sendRawPacket(peerNodeId, ackPacket.toUtf8Bytes());
    } catch (e) {
      debugPrint('[SAHARA HANDSHAKE] Error sending HANDSHAKE_ACK to $peerNodeId: $e');
    }
  }

  /// Broadcasts profile changes across all verified peers so names update immediately without reconnect
  Future<void> _broadcastProfileUpdate() async {
    final myName = _userProfile?.fullName.trim() ?? '';
    if (myName.isEmpty || _meshService == null) return;

    final payload = jsonEncode({
      'type': 'PROFILE_UPDATE',
      'name': myName,
      'phone': _userProfile?.phoneNumber ?? '',
      'user_id': _myUserId,
      'node_id': _myNodeId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final updatePacket = MessagePacket(
      messageId: 'PROF_${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myUserId,
      receiverId: 'BROADCAST',
      senderNodeId: _myNodeId,
      receiverNodeId: 'BROADCAST',
      type: 'PROFILE_UPDATE',
      priority: MessagePriority.normal,
      content: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: 2,
      status: MessageStatus.delivered,
      senderName: myName,
    );

    debugPrint('[SAHARA PROFILE] Broadcasting PROFILE_UPDATE across mesh (newName="$myName")...');
    for (final peerId in _verifiedPeers) {
      try {
        await _transport?.sendRawPacket(peerId, updatePacket.toUtf8Bytes());
      } catch (_) {}
    }
  }

  void _handlePeerHandshakePacket(MessagePacket packet) {
    try {
      debugPrint('[SAHARA HANDSHAKE] Received system packet: type=${packet.type}, from=${packet.senderNodeId}');
      final data = jsonDecode(packet.content) as Map<String, dynamic>;
      final packetType = data['type'] as String? ?? packet.type;
      final rawPeerName = (data['name'] as String? ?? packet.senderName ?? '').trim();
      final peerPhone = (data['phone'] as String? ?? '').trim();
      final peerUserId = (data['user_id'] as String? ?? packet.senderId).trim();
      final peerNodeId = packet.senderNodeId.trim();

      // Resolve human display name (never accept generic fallback if real name or better identifier exists)
      String resolvedName = rawPeerName;
      if (resolvedName.isEmpty || resolvedName == 'SAHARA User' || resolvedName == 'Sahara User') {
        final cached = getPersonById(peerNodeId)?.name;
        if (cached != null &&
            cached.isNotEmpty &&
            cached != 'SAHARA User' &&
            cached != 'Sahara User' &&
            !cached.startsWith('NODE_')) {
          resolvedName = cached;
        } else if (peerPhone.isNotEmpty) {
          resolvedName = peerPhone;
        } else {
          resolvedName = peerNodeId;
        }
      }

      // Mark this peer as VERIFIED CONNECTED at the application level
      _verifiedPeers.add(peerNodeId);
      _meshStatus = _meshStatus.copyWith(
        nearbyCount: _verifiedPeers.length,
        isMeshActive: true,
      );

      // If it was an INIT packet, send back an ACK immediately!
      if (packetType == 'HANDSHAKE_INIT') {
        final nonce = data['nonce'] as String? ?? '';
        debugPrint('[SAHARA HANDSHAKE] Verified INIT from $peerNodeId ("$resolvedName"). Sending ACK...');
        _sendPeerHandshakeAck(peerNodeId, nonce);
      } else if (packetType == 'HANDSHAKE_ACK') {
        debugPrint('[SAHARA HANDSHAKE] Verified ACK received from $peerNodeId ("$resolvedName"). Bidirectional verification COMPLETE!');
      }

      // Automatically request existing emergency broadcast history from peer
      if (!_historyRequestedPeers.contains(peerNodeId)) {
        _historyRequestedPeers.add(peerNodeId);
        _sendHistoryRequest(peerNodeId, peerUserId);
      }

      // Update name in cache, memory lists, and contacts
      if (resolvedName != peerNodeId) {
        _resolveAndCacheSenderName(peerNodeId, resolvedName);
      }

      final existingFamIdx = _familyMembers.indexWhere((f) =>
          f.id == peerNodeId || f.id == peerUserId || (peerPhone.isNotEmpty && f.phoneNumber == peerPhone));
      if (existingFamIdx >= 0) {
        _familyMembers[existingFamIdx] = _familyMembers[existingFamIdx].copyWith(
          name: resolvedName != peerNodeId ? resolvedName : _familyMembers[existingFamIdx].name,
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

      // Persist contact in SQLite safely
      try {
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
      } catch (e) {
        debugPrint('[SAHARA DB] Error updating contact: $e');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[SAHARA HANDSHAKE] Error handling handshake packet: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Emergency Alert & History Sync Protocol
  // ---------------------------------------------------------------------------

  /// Centralized emergency alert handler with deduplication.
  /// When [isLive] is true (live incoming SOS or broadcast, or sender's own broadcast),
  /// triggers native heads-up notification and direct hardware vibration.
  Future<void> handleEmergencyEvent({
    required String eventId,
    required String title,
    required String message,
    required AnnouncementSeverity severity,
    required String sourceName,
    required bool isLive,
    String? coordinates,
  }) async {
    if (_processedEmergencyEventIds.contains(eventId)) {
      debugPrint('[SAHARA-NOTIFY] EVENT_DUPLICATE_DROPPED id=$eventId');
      return;
    }
    _processedEmergencyEventIds.add(eventId);

    final announcement = EmergencyAnnouncement(
      id: eventId,
      title: title,
      message: message,
      source: sourceName,
      timeAgo: 'Just now',
      severity: severity,
      translations: BroadcastLocalizer.getTranslationsForComposed(
        title: title,
        message: message,
        severity: severity,
        source: sourceName,
      ),
    );

    _announcements.insert(0, announcement);
    notifyListeners();

    if (isLive) {
      debugPrint('[SAHARA-NOTIFY] POSTING_EMERGENCY_NOTIFICATION id=$eventId title="$title" source="$sourceName"');
      await NotificationService().showEmergencyBroadcastNotification(
        title: title,
        message: message,
        severity: severity,
        id: eventId,
      );
      debugPrint('[SAHARA-NOTIFY] NOTIFICATION_POSTED');
      debugPrint('[SAHARA-NOTIFY] VIBRATION_TRIGGERED');
    }
  }

  /// Sends HISTORY_REQUEST to a connected peer to synchronize past emergency broadcasts.
  Future<void> _sendHistoryRequest(String peerNodeId, String peerUserId) async {
    try {
      debugPrint('[SAHARA-HISTORY] REQUEST_SENT target=$peerNodeId');
      final payload = jsonEncode({
        'type': 'HISTORY_REQUEST',
        'requester_node_id': _myNodeId,
        'requester_user_id': _myUserId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await _meshService?.sendDirectMessage(
        receiverNodeId: peerNodeId,
        receiverUserId: peerUserId,
        content: payload,
        type: MessageType.historyRequest,
        priority: MessagePriority.high,
      );
    } catch (e) {
      debugPrint('[SAHARA-HISTORY] Error sending HISTORY_REQUEST to $peerNodeId: $e');
    }
  }

  /// Handles incoming HISTORY_REQUEST by querying local emergency history and sending HISTORY_RESPONSE.
  Future<void> _handleHistoryRequest(MessagePacket packet) async {
    try {
      debugPrint('[SAHARA-HISTORY] REQUEST_RECEIVED from=${packet.senderNodeId}');
      final historyPackets = await db.getEmergencyBroadcastHistory(limit: 50);
      debugPrint('[SAHARA-HISTORY] Found ${historyPackets.length} historical emergency events to share');

      final historyList = historyPackets.map((p) => p.toJson()).toList();

      final payload = jsonEncode({
        'type': 'HISTORY_RESPONSE',
        'responder_node_id': _myNodeId,
        'responder_user_id': _myUserId,
        'events': historyList,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await _meshService?.sendDirectMessage(
        receiverNodeId: packet.senderNodeId,
        receiverUserId: packet.senderId,
        content: payload,
        type: MessageType.historyResponse,
        priority: MessagePriority.high,
      );
      debugPrint('[SAHARA-HISTORY] RESPONSE_SENT to=${packet.senderNodeId} count=${historyList.length}');
    } catch (e) {
      debugPrint('[SAHARA-HISTORY] Error handling HISTORY_REQUEST: $e');
    }
  }

  /// Handles incoming HISTORY_RESPONSE by persisting new historical broadcasts into SQLite
  /// and displaying them in UI, strictly suppressing any sound or vibration alert.
  Future<void> _handleHistoryResponse(MessagePacket packet) async {
    try {
      debugPrint('[SAHARA-HISTORY] RESPONSE_RECEIVED from=${packet.senderNodeId}');
      final data = jsonDecode(packet.content) as Map<String, dynamic>;
      final rawEvents = data['events'] as List<dynamic>? ?? [];
      debugPrint('[SAHARA-HISTORY] Received ${rawEvents.length} events in history response');

      int addedCount = 0;
      for (final raw in rawEvents) {
        if (raw is! Map<String, dynamic>) continue;
        final messageId = raw['message_id'] as String? ?? '';
        if (messageId.isEmpty) continue;

        if (_processedEmergencyEventIds.contains(messageId)) {
          debugPrint('[SAHARA-HISTORY] EVENT_DUPLICATE_IGNORED id=$messageId');
          continue;
        }
        _processedEmergencyEventIds.add(messageId);

        final senderId = raw['sender_id'] as String? ?? '';
        final senderNodeId = raw['sender_node_id'] as String? ?? '';
        final senderName = (raw['sender_name'] as String?)?.isNotEmpty == true
            ? raw['sender_name'] as String
            : (senderNodeId.isNotEmpty ? senderNodeId : 'Mesh Alert');
        final content = raw['content'] as String? ?? '';
        final eventType = raw['type'] as String? ?? 'BROADCAST';
        final timestampMs = raw['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        final eventTime = DateTime.fromMillisecondsSinceEpoch(timestampMs);

        final isSos = eventType == 'SOS';
        final isEvac = isSos || content.toUpperCase().contains('EVAC');

        final historyPacket = MessagePacket(
          messageId: messageId,
          senderId: senderId,
          receiverId: 'BROADCAST',
          senderNodeId: senderNodeId,
          receiverNodeId: 'BROADCAST',
          type: eventType,
          priority: isSos ? MessagePriority.highest : MessagePriority.high,
          content: content,
          timestamp: timestampMs,
          ttl: 8,
          status: MessageStatus.delivered,
          senderName: senderName,
        );

        try {
          await db.insertMessage(historyPacket);
          await db.insertEmergencyReport({
            'report_id': messageId,
            'sender_id': senderId,
            'type': eventType,
            'priority': isSos ? 'Highest' : 'High',
            'details': content,
            'timestamp': timestampMs,
            'status': 'DELIVERED',
            'sender_name': senderName,
          });
        } catch (e) {
          debugPrint('[SAHARA DB] Error inserting historical event: $e');
        }

        final diff = DateTime.now().difference(eventTime);
        final String timeAgoStr;
        if (diff.inDays > 0) {
          timeAgoStr = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeAgoStr = '${diff.inHours}h ago';
        } else if (diff.inMinutes > 0) {
          timeAgoStr = '${diff.inMinutes}m ago';
        } else {
          timeAgoStr = 'Recently';
        }

        _announcements.add(EmergencyAnnouncement(
          id: messageId,
          title: isSos ? 'DISTRESS SOS ALERT' : 'EMERGENCY BROADCAST',
          message: content,
          source: senderName,
          timeAgo: timeAgoStr,
          severity: isEvac ? AnnouncementSeverity.evacuation : AnnouncementSeverity.warning,
          translations: BroadcastLocalizer.getTranslationsForComposed(
            title: isSos ? 'DISTRESS SOS ALERT' : 'EMERGENCY BROADCAST',
            message: content,
            severity: isEvac ? AnnouncementSeverity.evacuation : AnnouncementSeverity.warning,
            source: senderName,
          ),
        ));
        addedCount++;
        debugPrint('[SAHARA-HISTORY] EVENT_MERGED id=$messageId from="$senderName"');
      }

      if (addedCount > 0) {
        notifyListeners();
      }
      debugPrint('[SAHARA-HISTORY] SYNC_COMPLETE merged=$addedCount events');
    } catch (e) {
      debugPrint('[SAHARA-HISTORY] Error handling HISTORY_RESPONSE: $e');
    }
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
    if (receiverId.startsWith('demo_')) {
      debugPrint('[SAHARA-SEND] Skipped mesh dispatch for demo contact: $receiverId');
      return;
    }

    final person = getPersonById(receiverId);

    // Resolve target physical node_id
    String targetNodeId = receiverId;
    if (!targetNodeId.toUpperCase().startsWith('NODE_')) {
      for (final p in allKnownPeople) {
        if ((p.id == receiverId || p.phoneNumber == receiverId) && p.id.toUpperCase().startsWith('NODE_')) {
          targetNodeId = p.id;
          break;
        }
      }
    }

    final targetUserId = person?.phoneNumber ?? receiverId;

    String packetPriority = MessagePriority.normal;
    if (priority == ui_msg.MessagePriority.critical) {
      packetPriority = MessagePriority.highest;
    } else if (priority == ui_msg.MessagePriority.high) {
      packetPriority = MessagePriority.high;
    }

    final packetId = 'MSG_${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final now = DateTime.now();
    final myName = _userProfile?.fullName.trim() ?? 'You';

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

    // 1. Instantly update UI optimistically for sender
    final isDeliveredNow = _verifiedPeers.contains(targetNodeId) ||
        (_meshService != null && _meshService!.connectedPeers.contains(targetNodeId));

    final uiMessage = ui_msg.Message(
      id: packetId,
      senderId: _myUserId,
      receiverId: targetUserId,
      senderName: myName,
      content: trimmed,
      timestamp: now,
      type: ui_msg.MessageType.text,
      priority: priority,
      isDelivered: isDeliveredNow,
      isFromMe: true,
      hops: 1,
    );

    _conversationMessages.putIfAbsent(receiverId, () => []).add(uiMessage);
    if (targetNodeId != receiverId) {
      _conversationMessages.putIfAbsent(targetNodeId, () => []).add(uiMessage);
    }
    notifyListeners();

    // 2. Persist safely in SQLite
    try {
      await db.insertMessage(packet);
    } catch (e) {
      debugPrint('[SAHARA DB] Error inserting outgoing message: $e');
    }

    // 3. Dispatch across mesh transport
    try {
      await _meshService!.sendDirectMessage(
        receiverNodeId: targetNodeId,
        receiverUserId: targetUserId,
        content: trimmed,
        senderName: myName,
        priority: packetPriority,
        messageId: packetId,
      );
      debugPrint('[SAHARA SEND] Successfully dispatched direct message $packetId to $targetNodeId');
    } catch (e) {
      debugPrint('[SAHARA SEND] Error sending direct message: $e');
    }

    // 4. Trigger background sync with backend if online
    unawaited(syncWithBackend());
  }

  @override
  void sendBroadcast({required String content}) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || _meshService == null) return;

    final myName = _userProfile?.fullName.trim() ?? 'SAHARA Alert';
    final packetId = 'BC_${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _meshService!.sendEmergencyBroadcast(
        content: trimmed,
        senderName: myName,
        messageId: packetId,
      );
      debugPrint('[SAHARA BROADCAST] Successfully dispatched emergency broadcast across mesh: "$trimmed"');
    } catch (e) {
      debugPrint('[SAHARA BROADCAST] Error dispatching emergency broadcast: $e');
    }
    unawaited(syncWithBackend());
  }

  @override
  void triggerSOS({String? locationCoordinates}) async {
    _meshStatus = _meshStatus.copyWith(isBroadcastingSOS: true);
    notifyListeners();

    final details = locationCoordinates != null && locationCoordinates.isNotEmpty
        ? 'CRITICAL SOS DISTRESS BEACON — Coordinates: $locationCoordinates'
        : 'CRITICAL SOS DISTRESS BEACON — Immediate Assistance Required';

    final packetId = 'SOS_${_myNodeId}_${DateTime.now().millisecondsSinceEpoch}';
    final myName = _userProfile?.fullName.trim() ?? 'SOS Beacon';

    try {
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
    } catch (e) {
      debugPrint('[SAHARA DB] Error inserting SOS report: $e');
    }

    try {
      await _meshService?.sendSosAlert(
        location: locationCoordinates,
        details: details,
        senderName: myName,
        messageId: packetId,
      );
      debugPrint('[SAHARA SOS] Successfully dispatched SOS alert $packetId across mesh');
    } catch (e) {
      debugPrint('[SAHARA SOS] Error sending SOS alert: $e');
    }

    unawaited(syncWithBackend());
  }

  @override
  void cancelSOS() {
    _meshStatus = _meshStatus.copyWith(isBroadcastingSOS: false);
    notifyListeners();
  }

  @override
  void pingPerson(String personId) async {
    if (_meshService == null) return;
    if (personId.startsWith('demo_')) {
      debugPrint('[SAHARA-PING] Skipped mesh dispatch for demo contact: $personId');
      return;
    }
    final person = getPersonById(personId);
    String targetNodeId = personId;
    if (!targetNodeId.toUpperCase().startsWith('NODE_')) {
      for (final p in allKnownPeople) {
        if ((p.id == personId || p.phoneNumber == personId) && p.id.toUpperCase().startsWith('NODE_')) {
          targetNodeId = p.id;
          break;
        }
      }
    }
    final targetUserId = person?.phoneNumber ?? personId;
    final myName = _userProfile?.fullName.trim() ?? 'You';

    debugPrint('[SAHARA-PING] SENT peer=$targetNodeId');
    await _meshService!.sendPing(
      targetNodeId: targetNodeId,
      senderName: myName,
      targetUserId: targetUserId,
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

    // Update transport display name & restart advertising with new composite name
    if (_transport is NearbyConnectionsTransport) {
      unawaited((_transport as NearbyConnectionsTransport).updateDisplayName(profile.fullName));
    }

    // Broadcast updated profile across mesh so all peers update their contact names immediately
    unawaited(_broadcastProfileUpdate());

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
    _pingSub?.cancel();
    _meshService?.dispose();
    super.dispose();
  }
}
