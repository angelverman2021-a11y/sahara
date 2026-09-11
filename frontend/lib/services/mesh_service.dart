// SAHARA — Multi-Hop Mesh Service
// Core offline communication engine.
// Standard library only (dart:async, dart:convert, dart:collection, dart:math).
//
// "The core mesh routing logic uses lightweight Dart standard libraries and avoids
// third-party dependencies in the routing layer. Final APK size depends on the
// selected native transport implementation."

import 'dart:async';
import 'dart:math';

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
  final StreamController<List<String>> _peersController =
      StreamController<List<String>>.broadcast();

  /// Stream of incoming direct P2P messages addressed to this node
  Stream<MessagePacket> get onMessageReceived => _messageController.stream;

  /// Stream of emergency broadcasts propagated across the mesh
  Stream<MessagePacket> get onBroadcastReceived => _broadcastController.stream;

  /// Stream of high-priority SOS alerts received or relayed
  Stream<MessagePacket> get onSosReceived => _sosController.stream;

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
    try {
      final packet = MessagePacket.fromUtf8Bytes(rawBytes);
      _processPacket(fromPeerId, packet);
    } catch (_) {
      // Discard malformed packets silently to maintain resilience
    }
  }

  void _processPacket(String fromPeerId, MessagePacket packet) {
    // 1. Duplicate Prevention: Check if already seen
    if (_seenMessageIds.contains(packet.messageId)) {
      // Discard duplicate immediately (prevents loops and echo storms)
      return;
    }

    // 2. Mark as seen
    _recordSeenMessageId(packet.messageId);

    // 3. Routing & Stream Delivery by Message Type
    if (packet.type == MessageType.sos) {
      _handleSosPacket(fromPeerId, packet);
    } else if (packet.type == MessageType.broadcast) {
      _handleBroadcastPacket(fromPeerId, packet);
    } else if (packet.type == MessageType.text) {
      _handleDirectTextPacket(fromPeerId, packet);
    }
  }

  /// SOS: High-priority distress alert.
  /// Delivers locally on EVERY node, decrements TTL, and relays to all other peers.
  void _handleSosPacket(String fromPeerId, MessagePacket packet) {
    // Deliver to local SOS stream for UI display and audio alerts
    _sosController.add(packet);

    // Relay through mesh if TTL allows
    if (packet.ttl > 1) {
      final relayed = packet.copyWithDecrementedTtl();
      _relayToAllPeersExcept(fromPeerId, relayed);
    }
  }

  /// BROADCAST: Local hazard announcement.
  /// Delivers locally on EVERY node once, decrements TTL, and relays to all other peers.
  void _handleBroadcastPacket(String fromPeerId, MessagePacket packet) {
    // Deliver to local broadcast stream
    _broadcastController.add(packet);

    // Relay through mesh if TTL allows
    if (packet.ttl > 1) {
      final relayed = packet.copyWithDecrementedTtl();
      _relayToAllPeersExcept(fromPeerId, relayed);
    }
  }

  /// DIRECT TEXT: Person-to-person communication.
  /// Delivers to local chat ONLY when receiverNodeId matches myNodeId.
  /// Intermediate nodes forward silently without displaying in their chat.
  void _handleDirectTextPacket(String fromPeerId, MessagePacket packet) {
    if (packet.receiverNodeId == myNodeId) {
      // Reached destination! Deliver to local message stream
      _messageController.add(packet.copyWith(status: MessageStatus.delivered));
      return;
    }

    // Intermediate relay node: do NOT display locally.
    // Relay toward destination if TTL allows.
    if (packet.ttl > 1) {
      final relayed = packet.copyWithDecrementedTtl();
      _routeOrBufferDirectMessage(fromPeerId, relayed);
    }
  }

  void _routeOrBufferDirectMessage(String fromPeerId, MessagePacket packet) {
    // If destination node is directly connected, deliver straight to it
    if (_connectedPeers.contains(packet.receiverNodeId)) {
      transport.sendRawPacket(packet.receiverNodeId, packet.toUtf8Bytes());
      return;
    }

    // Otherwise, flood to all available peers except sender
    final targetPeers = _connectedPeers.where((p) => p != fromPeerId).toList();
    if (targetPeers.isNotEmpty) {
      for (final peer in targetPeers) {
        transport.sendRawPacket(peer, packet.toUtf8Bytes());
      }
    } else {
      // No suitable forward peer available right now -> store and forward
      _bufferMessage(packet);
    }
  }

  void _relayToAllPeersExcept(String fromPeerId, MessagePacket packet) {
    final payload = packet.toUtf8Bytes();
    for (final peer in _connectedPeers) {
      if (peer != fromPeerId) {
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
      if (packet.receiverNodeId == newPeerId) {
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

  /// Sends a direct person-to-person message through the mesh.
  /// [receiverNodeId] is the physical mesh node_id (used for routing).
  /// [receiverUserId] is the SAHARA user_id of the recipient (e.g. "SH-B02K").
  Future<void> sendDirectMessage({
    required String receiverNodeId,
    required String receiverUserId,
    required String content,
    String priority = MessagePriority.normal,
    int ttl = 8,
  }) async {
    final packet = MessagePacket(
      messageId: _generateMessageId(),
      senderId: myUserId,
      receiverId: receiverUserId,
      senderNodeId: myNodeId,
      receiverNodeId: receiverNodeId,
      type: MessageType.text,
      priority: priority,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: ttl,
      status: MessageStatus.pending,
    );

    _recordSeenMessageId(packet.messageId);

    final outgoingPacket = packet.copyWithDecrementedTtl();

    // If destination is directly connected, send straight to it
    if (_connectedPeers.contains(receiverNodeId)) {
      await transport.sendRawPacket(receiverNodeId, outgoingPacket.toUtf8Bytes());
      return;
    }

    // Forward to all available peers
    if (_connectedPeers.isNotEmpty) {
      final payload = outgoingPacket.toUtf8Bytes();
      for (final peer in _connectedPeers) {
        await transport.sendRawPacket(peer, payload);
      }
    } else {
      // Destination not reachable right now: buffer in store-and-forward
      _bufferMessage(outgoingPacket);
    }
  }

  /// Sends an emergency broadcast to all reachable civilian nodes.
  Future<void> sendEmergencyBroadcast({
    required String content,
    String priority = MessagePriority.high,
    int ttl = 8,
  }) async {
    final packet = MessagePacket(
      messageId: _generateMessageId(),
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
    int ttl = 10,
  }) async {
    final payloadContent = location != null && location.isNotEmpty
        ? 'LOCATION: $location | $details'
        : details;

    final packet = MessagePacket(
      messageId: _generateMessageId(),
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
