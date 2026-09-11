// SAHARA — Multi-Hop Mesh Service
// Core offline communication engine.
// Standard library only (dart:async, dart:convert, dart:collection, dart:math).
//
// "The core mesh routing logic uses lightweight Dart standard libraries and avoids
// third-party dependencies in the routing layer. Final APK size depends on the
// selected native transport implementation."

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/message_model.dart';

/// Event types emitted by the transport layer.
enum MeshTransportEventType {
  peerDiscovered,
  peerConnected,
  peerDisconnected,
  packetReceived,
}

/// A transport event encapsulating peer lifecycle or raw data delivery.
class MeshTransportEvent {
  final MeshTransportEventType type;
  final String peerId;
  final List<int>? data;

  const MeshTransportEvent({
    required this.type,
    required this.peerId,
    this.data,
  });
}

/// Abstract transport layer decoupling mesh routing logic from specific hardware SDKs
/// (e.g. Google Nearby Connections, Bluetooth Low Energy, or Wi-Fi Direct).
abstract class MeshTransport {
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<bool> sendRawPacket(String peerId, List<int> bytes);
  Stream<MeshTransportEvent> get events;
}

/// In-memory loopback transport for simulation and multi-node unit testing.
class MockMeshTransport implements MeshTransport {
  final String localNodeId;
  final StreamController<MeshTransportEvent> _controller =
      StreamController<MeshTransportEvent>.broadcast();

  final Set<String> _connectedPeers = <String>{};

  static final Map<String, MockMeshTransport> _activeNodes = {};

  MockMeshTransport({required this.localNodeId}) {
    _activeNodes[localNodeId] = this;
  }

  @override
  Stream<MeshTransportEvent> get events => _controller.stream;

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<bool> sendRawPacket(String peerId, List<int> bytes) async {
    final target = _activeNodes[peerId];
    if (target != null && target._connectedPeers.contains(localNodeId)) {
      target._controller.add(MeshTransportEvent(
        type: MeshTransportEventType.packetReceived,
        peerId: localNodeId,
        data: bytes,
      ));
      return true;
    }
    return false;
  }

  /// Helper to connect this simulated node with another peer node bidirectionally.
  void connectTo(String peerId) {
    final target = _activeNodes[peerId];
    if (target == null) return;

    _connectedPeers.add(peerId);
    target._connectedPeers.add(localNodeId);

    _controller.add(MeshTransportEvent(
      type: MeshTransportEventType.peerConnected,
      peerId: peerId,
    ));
    target._controller.add(MeshTransportEvent(
      type: MeshTransportEventType.peerConnected,
      peerId: localNodeId,
    ));
  }

  /// Helper to disconnect two simulated nodes.
  void disconnectFrom(String peerId) {
    final target = _activeNodes[peerId];
    _connectedPeers.remove(peerId);
    target?._connectedPeers.remove(localNodeId);

    _controller.add(MeshTransportEvent(
      type: MeshTransportEventType.peerDisconnected,
      peerId: peerId,
    ));
    target?._controller.add(MeshTransportEvent(
      type: MeshTransportEventType.peerDisconnected,
      peerId: localNodeId,
    ));
  }

  void dispose() {
    _activeNodes.remove(localNodeId);
    _controller.close();
  }

  static void resetNetwork() {
    _activeNodes.clear();
  }
}

/// Core SAHARA Mesh Service implementing multi-hop forwarding, deduplication,
/// TTL management, store-and-forward, SOS/broadcast propagation, and P2P messaging.
class MeshService {
  /// Physical mesh node ID of this device (used for physical routing, e.g. "NODE_A01")
  final String myNodeId;

  /// Permanent backend-generated SAHARA user ID (e.g. "SH-ZJHD")
  final String myUserId;

  /// Underlying transport abstraction
  final MeshTransport transport;

  // ---------------------------------------------------------------------------
  // Internal State
  // ---------------------------------------------------------------------------

  /// LRU-style set of seen message IDs to suppress echo loops and duplicate floods
  final Set<String> _seenMessageIds = <String>{};
  static const int _maxSeenCache = 1000;

  /// Currently connected peer node IDs
  final Set<String> _connectedPeers = <String>{};

  /// Store-and-forward outbox buffer for undelivered packets
  final List<MessagePacket> _storeAndForwardBuffer = <MessagePacket>[];
  static const int _maxBufferSize = 200;

  StreamSubscription<MeshTransportEvent>? _transportSub;

  // ---------------------------------------------------------------------------
  // Reactive Event Streams for Flutter UI
  // ---------------------------------------------------------------------------

  final StreamController<MessagePacket> _messageController =
      StreamController<MessagePacket>.broadcast();
  final StreamController<MessagePacket> _broadcastController =
      StreamController<MessagePacket>.broadcast();
  final StreamController<MessagePacket> _sosController =
      StreamController<MessagePacket>.broadcast();
  final StreamController<MessagePacket> _pingController =
      StreamController<MessagePacket>.broadcast();
  final StreamController<List<String>> _peersController =
      StreamController<List<String>>.broadcast();

  /// Stream of incoming direct P2P messages addressed to this node
  Stream<MessagePacket> get onMessageReceived => _messageController.stream;

  /// Stream of emergency broadcasts propagated across the mesh
  Stream<MessagePacket> get onBroadcastReceived => _broadcastController.stream;

  /// Stream of high-priority SOS alerts received or relayed
  Stream<MessagePacket> get onSosReceived => _sosController.stream;

  /// Stream of peer ping check alerts
  Stream<MessagePacket> get onPingReceived => _pingController.stream;

  /// Stream of currently connected nearby peer node IDs
  Stream<List<String>> get onPeersChanged => _peersController.stream;

  /// Current number of directly connected nearby nodes
  int get connectedPeerCount => _connectedPeers.length;

  /// Currently connected peer IDs list snapshot
  List<String> get connectedPeers => List.unmodifiable(_connectedPeers);

  /// Current items queued in store-and-forward buffer
  List<MessagePacket> get pendingBuffer => List.unmodifiable(_storeAndForwardBuffer);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  MeshService({
    required this.myNodeId,
    required this.myUserId,
    required this.transport,
  }) {
    _transportSub = transport.events.listen(_handleTransportEvent);
  }

  /// Starts peer discovery
  Future<void> start() async {
    await transport.startDiscovery();
  }

  /// Stops peer discovery
  Future<void> stop() async {
    await transport.stopDiscovery();
  }

  /// Disposes streams and listeners
  void dispose() {
    _transportSub?.cancel();
    _messageController.close();
    _broadcastController.close();
    _sosController.close();
    _pingController.close();
    _peersController.close();
  }

  // ---------------------------------------------------------------------------
  // Transport Event Handling
  // ---------------------------------------------------------------------------

  void _handleTransportEvent(MeshTransportEvent event) {
    switch (event.type) {
      case MeshTransportEventType.peerConnected:
        _handlePeerConnected(event.peerId);
        break;
      case MeshTransportEventType.peerDisconnected:
        _handlePeerDisconnected(event.peerId);
        break;
      case MeshTransportEventType.packetReceived:
        if (event.data != null) {
          _handleRawPacket(event.peerId, event.data!);
        }
        break;
      case MeshTransportEventType.peerDiscovered:
        break;
    }
  }

  void _handlePeerConnected(String peerId) {
    if (_connectedPeers.add(peerId)) {
      _peersController.add(List.unmodifiable(_connectedPeers));
      // Flush eligible store-and-forward messages to newly connected peer
      _flushStoreAndForwardBuffer(peerId);
    }
  }

  void _handlePeerDisconnected(String peerId) {
    if (_connectedPeers.remove(peerId)) {
      _peersController.add(List.unmodifiable(_connectedPeers));
    }
  }

  // ---------------------------------------------------------------------------
  // Packet Ingestion & Multi-Hop Relay Logic
  // ---------------------------------------------------------------------------

  void _handleRawPacket(String fromPeerId, List<int> rawBytes) {
    debugPrint('[SAHARA MESH RECEIVE] Raw packet received from $fromPeerId: ${rawBytes.length} bytes');
    try {
      final packet = MessagePacket.fromUtf8Bytes(rawBytes);
      debugPrint('[SAHARA DECODE] Successfully decoded MessagePacket: id=${packet.messageId}, sender=${packet.senderId} (${packet.senderNodeId}), receiver=${packet.receiverId} (${packet.receiverNodeId}), type=${packet.type}, ttl=${packet.ttl}');
      handleIncomingPacket(fromPeerId, packet);
    } catch (e, stack) {
      debugPrint('[SAHARA DECODE] FAILED to decode packet from $fromPeerId: $e\n$stack');
      debugPrint('[SAHARA DROP] Malformed packet from $fromPeerId dropped');
    }
  }

  /// Ingests and processes a decoded [MessagePacket] through deduplication,
  /// TTL checking, stream delivery, and mesh relay.
  void handleIncomingPacket(String fromPeerId, MessagePacket packet) {
    debugPrint('[SAHARA MESH RECEIVE] Packet entered mesh engine: id=${packet.messageId}, type=${packet.type}, fromPeer=$fromPeerId, senderNode=${packet.senderNodeId}');
    _processPacket(fromPeerId, packet);
  }

  void _processPacket(String fromPeerId, MessagePacket packet) {
    // 1. Duplicate Prevention: Check if already seen
    if (_seenMessageIds.contains(packet.messageId)) {
      debugPrint('[SAHARA DROP] Duplicate packet ignored: ${packet.messageId}');
      return;
    }

    // 2. Mark as seen
    _recordSeenMessageId(packet.messageId);

    // 3. TTL Validation
    if (packet.ttl <= 0) {
      debugPrint('[SAHARA DROP] Packet ${packet.messageId} dropped: TTL <= 0 (ttl=${packet.ttl})');
      return;
    }

    // 4. Routing & Stream Delivery by Message Type
    debugPrint('[SAHARA ROUTE] Processing packet: id=${packet.messageId}, type=${packet.type}, dest=${packet.receiverNodeId}, myNodeId=$myNodeId');
    if (packet.type == MessageType.sos) {
      _handleSosPacket(fromPeerId, packet);
    } else if (packet.type == MessageType.broadcast) {
      _handleBroadcastPacket(fromPeerId, packet);
    } else if (packet.type == MessageType.text) {
      _handleDirectTextPacket(fromPeerId, packet);
    } else if (packet.type == MessageType.ping) {
      _handlePingPacket(fromPeerId, packet);
    } else {
      // General direct delivery for system/handshake/status/profile packets
      final isForMe = packet.receiverNodeId.trim().toUpperCase() == myNodeId.trim().toUpperCase() ||
          (packet.receiverId.isNotEmpty && packet.receiverId.trim().toUpperCase() == myUserId.trim().toUpperCase()) ||
          packet.receiverNodeId.trim().toUpperCase() == myUserId.trim().toUpperCase() ||
          packet.receiverNodeId == 'BROADCAST' ||
          packet.receiverNodeId.isEmpty;

      if (isForMe) {
        debugPrint('[SAHARA DELIVER] System packet (${packet.type}) delivered locally: id=${packet.messageId}');
        _messageController.add(packet.copyWith(status: MessageStatus.delivered));
      } else {
        debugPrint('[SAHARA ROUTE] System packet (${packet.type}) addressed to ${packet.receiverNodeId} (not me: $myNodeId). Evaluating relay...');
        if (packet.ttl > 1) {
          final relayed = packet.copyWithDecrementedTtl();
          _routeOrBufferDirectMessage(fromPeerId, relayed);
        } else {
          debugPrint('[SAHARA DROP] System packet ${packet.messageId} dropped: TTL expired (ttl=${packet.ttl})');
        }
      }
    }
  }

  /// SOS: High-priority distress alert.
  /// Delivers locally on EVERY node, decrements TTL, and relays to all other peers.
  void _handleSosPacket(String fromPeerId, MessagePacket packet) {
    debugPrint('[SAHARA DELIVER] SOS packet delivered locally: ${packet.messageId}');
    // Deliver to local SOS stream for UI display and audio alerts
    _sosController.add(packet);

    // Relay through mesh if TTL allows
    if (packet.ttl > 1) {
      final relayed = packet.copyWithDecrementedTtl();
      debugPrint('[SAHARA ROUTE] Relaying SOS ${packet.messageId} with new TTL=${relayed.ttl}');
      _relayToAllPeersExcept(fromPeerId, relayed);
    } else {
      debugPrint('[SAHARA DROP] SOS ${packet.messageId} relay halted: TTL reached limit (ttl=${packet.ttl})');
    }
  }

  /// BROADCAST: Local hazard announcement.
  /// Delivers locally on EVERY node once, decrements TTL, and relays to all other peers.
  void _handleBroadcastPacket(String fromPeerId, MessagePacket packet) {
    debugPrint('[SAHARA DELIVER] Broadcast packet delivered locally: ${packet.messageId}');
    // Deliver to local broadcast stream
    _broadcastController.add(packet);

    // Relay through mesh if TTL allows
    if (packet.ttl > 1) {
      final relayed = packet.copyWithDecrementedTtl();
      debugPrint('[SAHARA ROUTE] Relaying broadcast ${packet.messageId} with new TTL=${relayed.ttl}');
      _relayToAllPeersExcept(fromPeerId, relayed);
    } else {
      debugPrint('[SAHARA DROP] Broadcast ${packet.messageId} relay halted: TTL reached limit (ttl=${packet.ttl})');
    }
  }

  /// DIRECT TEXT: Person-to-person communication.
  /// Delivers to local chat ONLY when receiver matches myNodeId, myUserId, or BROADCAST.
  /// Intermediate nodes forward silently without displaying in their chat.
  void _handleDirectTextPacket(String fromPeerId, MessagePacket packet) {
    final isForMe = packet.receiverNodeId.trim().toUpperCase() == myNodeId.trim().toUpperCase() ||
        (packet.receiverId.isNotEmpty && packet.receiverId.trim().toUpperCase() == myUserId.trim().toUpperCase()) ||
        packet.receiverNodeId.trim().toUpperCase() == myUserId.trim().toUpperCase() ||
        packet.receiverNodeId == 'BROADCAST';

    debugPrint('[SAHARA ROUTE] Destination check for ${packet.messageId}: destNode="${packet.receiverNodeId}" vs myNode="$myNodeId", destUser="${packet.receiverId}" vs myUser="$myUserId", match=$isForMe');

    if (isForMe) {
      debugPrint('[SAHARA DELIVER] Direct text packet reached destination $myNodeId! id=${packet.messageId}, from=${packet.senderNodeId}');
      _messageController.add(packet.copyWith(status: MessageStatus.delivered));
      return;
    }

    // Intermediate relay node: do NOT display locally.
    // Relay toward destination if TTL allows.
    debugPrint('[SAHARA ROUTE] Packet ${packet.messageId} addressed to ${packet.receiverNodeId} (not me: $myNodeId). Evaluating relay...');
    if (packet.ttl > 1) {
      final relayed = packet.copyWithDecrementedTtl();
      debugPrint('[SAHARA ROUTE] Relaying packet ${packet.messageId} with new TTL=${relayed.ttl}');
      _routeOrBufferDirectMessage(fromPeerId, relayed);
    } else {
      debugPrint('[SAHARA DROP] Packet ${packet.messageId} dropped: TTL expired for forwarding (ttl=${packet.ttl})');
    }
  }

  /// PING: Radio connectivity check and alert.
  void _handlePingPacket(String fromPeerId, MessagePacket packet) {
    final isForMe = packet.receiverNodeId.trim().toUpperCase() == myNodeId.trim().toUpperCase() ||
        (packet.receiverId.isNotEmpty && packet.receiverId.trim().toUpperCase() == myUserId.trim().toUpperCase()) ||
        packet.receiverNodeId.trim().toUpperCase() == myUserId.trim().toUpperCase() ||
        packet.receiverNodeId == 'BROADCAST' ||
        packet.receiverId == 'ALL_PEERS';

    if (isForMe) {
      debugPrint('[SAHARA DELIVER] Ping packet reached destination $myNodeId! id=${packet.messageId}, from=${packet.senderNodeId}');
      _pingController.add(packet);
    }

    // Relay if broadcast or multi-hop
    if (packet.ttl > 1) {
      final relayed = packet.copyWithDecrementedTtl();
      if (packet.receiverNodeId == 'BROADCAST' || packet.receiverId == 'ALL_PEERS') {
        _relayToAllPeersExcept(fromPeerId, relayed);
      } else if (!isForMe) {
        _routeOrBufferDirectMessage(fromPeerId, relayed);
      }
    }
  }

  void _routeOrBufferDirectMessage(String fromPeerId, MessagePacket packet) {
    // If destination node is directly connected, deliver straight to it
    final isDirectlyConnected = _connectedPeers.contains(packet.receiverNodeId) ||
        _connectedPeers.any((p) => p.trim().toUpperCase() == packet.receiverNodeId.trim().toUpperCase());

    if (isDirectlyConnected) {
      final targetPeer = _connectedPeers.firstWhere(
        (p) => p.trim().toUpperCase() == packet.receiverNodeId.trim().toUpperCase(),
        orElse: () => packet.receiverNodeId,
      );
      debugPrint('[SAHARA ROUTE] Target $targetPeer is directly connected. Forwarding packet ${packet.messageId}...');
      transport.sendRawPacket(targetPeer, packet.toUtf8Bytes());
      return;
    }

    // Otherwise, flood to all available peers except sender
    final targetPeers = _connectedPeers
        .where((p) => p.trim().toUpperCase() != fromPeerId.trim().toUpperCase())
        .toList();
    if (targetPeers.isNotEmpty) {
      debugPrint('[SAHARA ROUTE] Flooding packet ${packet.messageId} to ${targetPeers.length} peers: $targetPeers');
      final payload = packet.toUtf8Bytes();
      for (final peer in targetPeers) {
        transport.sendRawPacket(peer, payload);
      }
    } else {
      debugPrint('[SAHARA ROUTE] No forward peers available for ${packet.receiverNodeId}. Buffering in store-and-forward outbox');
      _bufferMessage(packet);
    }
  }

  void _relayToAllPeersExcept(String fromPeerId, MessagePacket packet) {
    final payload = packet.toUtf8Bytes();
    for (final peer in _connectedPeers) {
      if (peer.trim().toUpperCase() != fromPeerId.trim().toUpperCase()) {
        transport.sendRawPacket(peer, payload);
      }
    }
  }

  void _recordSeenMessageId(String messageId) {
    _seenMessageIds.add(messageId);
    if (_seenMessageIds.length > _maxSeenCache) {
      // Keep cache size bounded
      _seenMessageIds.remove(_seenMessageIds.first);
    }
  }

  // ---------------------------------------------------------------------------
  // Store-and-Forward Buffer Logic
  // ---------------------------------------------------------------------------

  void _bufferMessage(MessagePacket packet) {
    // Avoid buffering duplicates or expired packets
    if (packet.ttl <= 1) return;
    if (_storeAndForwardBuffer.any((p) => p.messageId == packet.messageId)) return;

    if (_storeAndForwardBuffer.length >= _maxBufferSize) {
      _storeAndForwardBuffer.removeAt(0); // Evict oldest
    }
    _storeAndForwardBuffer.add(packet);
  }

  void _flushStoreAndForwardBuffer(String newPeerId) {
    if (_storeAndForwardBuffer.isEmpty) return;

    final toRemove = <MessagePacket>[];

    for (final packet in List<MessagePacket>.from(_storeAndForwardBuffer)) {
      // Case A: Newly connected peer is the target destination
      if (packet.receiverNodeId.trim().toUpperCase() == newPeerId.trim().toUpperCase()) {
        transport.sendRawPacket(newPeerId, packet.toUtf8Bytes());
        toRemove.add(packet);
      }
      // Case B: Broadcast or SOS that can now continue through this new peer
      else if (packet.receiverNodeId == 'BROADCAST' || packet.type == MessageType.sos) {
        transport.sendRawPacket(newPeerId, packet.toUtf8Bytes());
      }
      // Case C: Direct message that can relay through new peer
      else {
        transport.sendRawPacket(newPeerId, packet.toUtf8Bytes());
      }
    }

    for (final p in toRemove) {
      _storeAndForwardBuffer.remove(p);
    }
  }

  // ---------------------------------------------------------------------------
  // Public Action APIs
  // ---------------------------------------------------------------------------

  /// Dispatches a high-priority PING alert to verify peer radio connectivity.
  Future<MessagePacket?> sendPing({
    required String targetNodeId,
    required String senderName,
    String? targetUserId,
  }) async {
    final messageId = 'PING_${myNodeId}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    debugPrint('[SAHARA-PING] CREATED id=$messageId');

    final packet = MessagePacket(
      messageId: messageId,
      senderId: myUserId,
      receiverId: targetUserId ?? targetNodeId,
      senderNodeId: myNodeId,
      receiverNodeId: targetNodeId,
      type: MessageType.ping,
      priority: MessagePriority.high,
      content: 'PING from $senderName',
      senderName: senderName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      status: MessageStatus.pending,
      ttl: 8,
    );

    debugPrint('[SAHARA-PING] SENT peer=$targetNodeId');
    _recordSeenMessageId(packet.messageId);

    if (targetNodeId == 'BROADCAST' || targetNodeId == 'ALL_PEERS') {
      final payload = packet.copyWithDecrementedTtl().toUtf8Bytes();
      for (final peer in _connectedPeers) {
        transport.sendRawPacket(peer, payload);
      }
    } else {
      _routeOrBufferDirectMessage('', packet.copyWithDecrementedTtl());
    }
    return packet;
  }

  /// Sends a direct person-to-person message through the mesh.
  /// [receiverNodeId] is the physical mesh node_id (used for routing).
  /// [receiverUserId] is the SAHARA user_id of the recipient (e.g. "SH-B02K").
  Future<void> sendDirectMessage({
    required String receiverNodeId,
    required String receiverUserId,
    required String content,
    String? senderName,
    String type = MessageType.text,
    String priority = MessagePriority.normal,
    int ttl = 8,
    String? messageId,
  }) async {
    // Ensure receiverId is a genuine SAHARA user_id (SH-XXXX), not a node_id
    String resolvedReceiverUserId = receiverUserId.trim();
    if (resolvedReceiverUserId.isEmpty || resolvedReceiverUserId.toUpperCase().startsWith('NODE_')) {
      final clean = receiverNodeId.replaceFirst(RegExp(r'^NODE_', caseSensitive: false), '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final suffix = clean.length >= 4 ? clean.substring(0, 4).toUpperCase() : clean.toUpperCase();
      resolvedReceiverUserId = 'SH-$suffix';
    }

    // Ensure senderId is a genuine SAHARA user_id (SH-XXXX)
    String resolvedSenderUserId = myUserId.trim();
    if (resolvedSenderUserId.isEmpty || resolvedSenderUserId.toUpperCase().startsWith('NODE_')) {
      final clean = myNodeId.replaceFirst(RegExp(r'^NODE_', caseSensitive: false), '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final suffix = clean.length >= 4 ? clean.substring(0, 4).toUpperCase() : clean.toUpperCase();
      resolvedSenderUserId = 'SH-$suffix';
    }

    final packet = MessagePacket(
      messageId: messageId ?? _generateMessageId(),
      senderId: resolvedSenderUserId,
      receiverId: resolvedReceiverUserId,
      senderNodeId: myNodeId,
      receiverNodeId: receiverNodeId,
      type: type,
      priority: priority,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: ttl,
      status: MessageStatus.pending,
      senderName: senderName,
    );

    debugPrint('[SAHARA PACKET] Outgoing MessagePacket created:');
    debugPrint('[SAHARA PACKET]   message_id:       ${packet.messageId}');
    debugPrint('[SAHARA PACKET]   sender_id:        ${packet.senderId}');
    debugPrint('[SAHARA PACKET]   receiver_id:      ${packet.receiverId}');
    debugPrint('[SAHARA PACKET]   sender_node_id:   ${packet.senderNodeId}');
    debugPrint('[SAHARA PACKET]   receiver_node_id: ${packet.receiverNodeId}');
    debugPrint('[SAHARA PACKET]   type:             ${packet.type}');
    debugPrint('[SAHARA PACKET]   priority:         ${packet.priority}');
    debugPrint('[SAHARA PACKET]   TTL:              ${packet.ttl}');

    final payloadBytes = packet.toUtf8Bytes();
    debugPrint('[SAHARA PACKET] MessagePacket serialized to UTF-8 bytes: length=${payloadBytes.length}');

    _recordSeenMessageId(packet.messageId);

    final outgoingPacket = packet.copyWithDecrementedTtl();
    final outgoingBytes = outgoingPacket.toUtf8Bytes();

    // Check if destination is directly connected (with case-insensitive fallback)
    final isDirectlyConnected = _connectedPeers.contains(receiverNodeId) ||
        _connectedPeers.any((p) => p.trim().toUpperCase() == receiverNodeId.trim().toUpperCase());

    if (isDirectlyConnected) {
      final targetPeer = _connectedPeers.firstWhere(
        (p) => p.trim().toUpperCase() == receiverNodeId.trim().toUpperCase(),
        orElse: () => receiverNodeId,
      );
      debugPrint('[SAHARA ROUTE] Direct peer connected: $targetPeer. Dispatching packet ${packet.messageId}...');
      await transport.sendRawPacket(targetPeer, outgoingBytes);
      return;
    }

    // Forward to all available peers
    if (_connectedPeers.isNotEmpty) {
      debugPrint('[SAHARA ROUTE] Target $receiverNodeId not directly connected. Flooding ${_connectedPeers.length} peers...');
      for (final peer in _connectedPeers) {
        await transport.sendRawPacket(peer, outgoingBytes);
      }
    } else {
      debugPrint('[SAHARA ROUTE] No peers connected. Buffering packet ${packet.messageId} in store-and-forward outbox');
      _bufferMessage(outgoingPacket);
    }
  }

  /// Direct convenience alias for [sendDirectMessage].
  Future<void> sendMessage({
    required String receiverNodeId,
    required String receiverUserId,
    required String content,
    String priority = MessagePriority.normal,
    int ttl = 8,
  }) => sendDirectMessage(
    receiverNodeId: receiverNodeId,
    receiverUserId: receiverUserId,
    content: content,
    priority: priority,
    ttl: ttl,
  );

  /// Sends an emergency broadcast to all reachable civilian nodes.
  Future<void> sendEmergencyBroadcast({
    required String content,
    String? senderName,
    String priority = MessagePriority.high,
    int ttl = 8,
    String? messageId,
  }) async {
    final packet = MessagePacket(
      messageId: messageId ?? _generateMessageId(),
      senderId: myUserId,
      receiverId: 'BROADCAST',
      senderNodeId: myNodeId,
      receiverNodeId: 'BROADCAST',
      type: MessageType.broadcast,
      priority: priority,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: ttl,
      status: MessageStatus.pending,
      senderName: senderName,
    );

    _recordSeenMessageId(packet.messageId);

    // Deliver to local broadcast stream as well
    _broadcastController.add(packet);

    final outgoingPacket = packet.copyWithDecrementedTtl();

    if (_connectedPeers.isNotEmpty) {
      final payload = outgoingPacket.toUtf8Bytes();
      for (final peer in _connectedPeers) {
        await transport.sendRawPacket(peer, payload);
      }
    } else {
      _bufferMessage(outgoingPacket);
    }
  }

  /// Sends a one-tap SOS emergency packet through the mesh.
  Future<void> sendSosAlert({
    String? location,
    required String details,
    String? senderName,
    int ttl = 10,
    String? messageId,
  }) async {
    final payloadContent = location != null && location.isNotEmpty
        ? 'LOCATION: $location | $details'
        : details;

    final packet = MessagePacket(
      messageId: messageId ?? _generateMessageId(),
      senderId: myUserId,
      receiverId: 'BROADCAST',
      senderNodeId: myNodeId,
      receiverNodeId: 'BROADCAST',
      type: MessageType.sos,
      priority: MessagePriority.highest,
      content: payloadContent,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: ttl,
      status: MessageStatus.pending,
      senderName: senderName,
    );

    _recordSeenMessageId(packet.messageId);

    // Deliver to local SOS stream
    _sosController.add(packet);

    final outgoingPacket = packet.copyWithDecrementedTtl();

    if (_connectedPeers.isNotEmpty) {
      final payload = outgoingPacket.toUtf8Bytes();
      for (final peer in _connectedPeers) {
        await transport.sendRawPacket(peer, payload);
      }
    } else {
      _bufferMessage(outgoingPacket);
    }
  }

  String _generateMessageId() {
    final randomPart = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final timePart = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    return 'MSG_${myNodeId}_${timePart}_$randomPart'.toUpperCase();
  }
}
