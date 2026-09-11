// SAHARA — Real Android P2P Transport Layer
// Implements Google Nearby Connections (P2P_CLUSTER) for offline phone-to-phone communication.
// Strictly decouples physical hardware transport from the MeshService routing engine.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import 'mesh_service.dart';

/// Concrete [MeshTransport] implementation powered by Google Nearby Connections.
///
/// Operates 100% offline using hybrid radio discovery (Bluetooth LE, Bluetooth Classic,
/// and Wi-Fi Direct). Uses [Strategy.P2P_CLUSTER] to allow devices to advertise and
/// discover simultaneously, enabling M-to-N mesh formations.
///
/// Maintains internal bidirectional mapping between physical SAHARA [node_id]
/// and Google Nearby ephemeral session [endpointId].
class NearbyConnectionsTransport implements MeshTransport {
  /// Physical mesh node ID of this device (e.g., "NODE_A01")
  final String localNodeId;

  /// Service identifier matching across all SAHARA emergency nodes
  final String serviceId;

  /// Underlying Nearby Connections topology strategy (P2P_CLUSTER by default)
  final Strategy strategy;

  /// Nearby Connections API wrapper instance
  final Nearby nearby;

  // ---------------------------------------------------------------------------
  // Internal State & Mapping
  // ---------------------------------------------------------------------------

  final StreamController<MeshTransportEvent> _eventsController =
      StreamController<MeshTransportEvent>.broadcast();

  /// Maps SAHARA physical node_id -> Nearby session endpointId
  final Map<String, String> _nodeIdToEndpointId = <String, String>{};

  /// Maps Nearby session endpointId -> SAHARA physical node_id
  final Map<String, String> _endpointIdToNodeId = <String, String>{};

  /// Currently connected peer node IDs
  final Set<String> _connectedPeers = <String>{};

  bool _isDiscovering = false;
  bool _isAdvertising = false;

  NearbyConnectionsTransport({
    required this.localNodeId,
    this.serviceId = 'com.sahara.emergency.mesh',
    this.strategy = Strategy.P2P_CLUSTER,
    Nearby? nearby,
  }) : nearby = nearby ?? Nearby();

  // ---------------------------------------------------------------------------
  // MeshTransport Interface Implementation
  // ---------------------------------------------------------------------------

  @override
  Stream<MeshTransportEvent> get events => _eventsController.stream;

  /// Starts concurrent advertising and discovery using P2P_CLUSTER.
  @override
  Future<void> startDiscovery() async {
    await _startAdvertising();
    await _startDiscovering();
  }

  /// Stops advertising and discovery on this device.
  @override
  Future<void> stopDiscovery() async {
    if (_isAdvertising) {
      try {
        await nearby.stopAdvertising();
      } catch (_) {}
      _isAdvertising = false;
    }

    if (_isDiscovering) {
      try {
        await nearby.stopDiscovery();
      } catch (_) {}
      _isDiscovering = false;
    }
  }

  /// Sends raw packet bytes to a connected peer identified by its [node_id].
  ///
  /// Returns `true` on successful transmission dispatch, `false` otherwise.
  @override
  Future<bool> sendRawPacket(String peerId, List<int> bytes) async {
    debugPrint('[SAHARA TRANSPORT SEND] Initiating sendRawPacket to peerId=$peerId, byteCount=${bytes.length}...');

    // Case-insensitive fallback lookup for peer endpoint
    var endpointId = _nodeIdToEndpointId[peerId];
    if (endpointId == null) {
      for (final entry in _nodeIdToEndpointId.entries) {
        if (entry.key.trim().toUpperCase() == peerId.trim().toUpperCase()) {
          endpointId = entry.value;
          break;
        }
      }
    }

    final isConnected = _connectedPeers.contains(peerId) ||
        _connectedPeers.any((p) => p.trim().toUpperCase() == peerId.trim().toUpperCase());

    if (endpointId == null || !isConnected) {
      debugPrint('[SAHARA TRANSPORT SEND] FAILED: peer $peerId not connected (endpoint: $endpointId, connectedPeers: $_connectedPeers)');
      return false;
    }

    try {
      final payload = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      debugPrint('[SAHARA TRANSPORT SEND] Sending ${payload.length} bytes to peerNodeId=$peerId (endpoint=$endpointId)');
      await nearby.sendBytesPayload(endpointId, payload);
      debugPrint('[SAHARA TRANSPORT SEND] Dispatched ${payload.length} bytes to $peerId ($endpointId)');
      return true;
    } catch (e) {
      debugPrint('[SAHARA TRANSPORT SEND] ERROR sending packet to $peerId ($endpointId): $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Advertising Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _startAdvertising() async {
    if (_isAdvertising) return;

    try {
      debugPrint('[SAHARA TRANSPORT] Starting advertising as Node ID: $localNodeId...');
      final started = await nearby.startAdvertising(
        localNodeId,
        strategy,
        onConnectionInitiated: _handleConnectionInitiated,
        onConnectionResult: _handleConnectionResult,
        onDisconnected: _handleDisconnected,
        serviceId: serviceId,
      );
      _isAdvertising = started;
      debugPrint('[SAHARA TRANSPORT] Advertising started: $started (Node ID: $localNodeId)');
    } catch (e) {
      debugPrint('[SAHARA TRANSPORT] Advertising failed to start: $e');
      _isAdvertising = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Discovery Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _startDiscovering() async {
    if (_isDiscovering) return;

    try {
      debugPrint('[SAHARA TRANSPORT] Starting discovery as Node ID: $localNodeId...');
      final started = await nearby.startDiscovery(
        localNodeId,
        strategy,
        onEndpointFound: _handleEndpointFound,
        onEndpointLost: _handleEndpointLost,
        serviceId: serviceId,
      );
      _isDiscovering = started;
      debugPrint('[SAHARA TRANSPORT] Discovery started: $started (Node ID: $localNodeId)');
    } catch (e) {
      debugPrint('[SAHARA TRANSPORT] Discovery failed to start: $e');
      _isDiscovering = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Nearby Event Handlers
  // ---------------------------------------------------------------------------

  /// Triggered when a nearby SAHARA peer endpoint is discovered.
  void _handleEndpointFound(String endpointId, String endpointName, String serviceId) async {
    final peerNodeId = endpointName;
    debugPrint('[SAHARA TRANSPORT] Endpoint discovered: $endpointId -> Node ID: $peerNodeId');
    _endpointIdToNodeId[endpointId] = peerNodeId;
    _nodeIdToEndpointId[peerNodeId] = endpointId;

    _eventsController.add(MeshTransportEvent(
      type: MeshTransportEventType.peerDiscovered,
      peerId: peerNodeId,
    ));

    // In P2P_CLUSTER, initiate connection if not already connected
    if (!_connectedPeers.contains(peerNodeId)) {
      try {
        debugPrint('[SAHARA TRANSPORT] Requesting connection to $endpointId ($peerNodeId)...');
        await nearby.requestConnection(
          localNodeId,
          endpointId,
          onConnectionInitiated: _handleConnectionInitiated,
          onConnectionResult: _handleConnectionResult,
          onDisconnected: _handleDisconnected,
        );
      } catch (e) {
        debugPrint('[SAHARA TRANSPORT] Connection request collision/error with $peerNodeId: $e');
      }
    }
  }

  /// Triggered when a previously discovered endpoint is no longer in radio range.
  void _handleEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    final peerNodeId = _endpointIdToNodeId[endpointId];
    debugPrint('[SAHARA TRANSPORT] Endpoint lost: $endpointId ($peerNodeId)');
    if (peerNodeId != null && !_connectedPeers.contains(peerNodeId)) {
      _endpointIdToNodeId.remove(endpointId);
      _nodeIdToEndpointId.remove(peerNodeId);
    }
  }

  /// Triggered when either peer requests a connection. Automatically accepts.
  void _handleConnectionInitiated(String endpointId, ConnectionInfo info) async {
    final peerNodeId = info.endpointName;
    debugPrint('[SAHARA TRANSPORT] Connection initiated: $endpointId ($peerNodeId), incoming: ${info.isIncomingConnection}');
    _endpointIdToNodeId[endpointId] = peerNodeId;
    _nodeIdToEndpointId[peerNodeId] = endpointId;

    try {
      debugPrint('[SAHARA TRANSPORT] Auto-accepting connection with $endpointId ($peerNodeId)...');
      await nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (String epId, Payload payload) {
          debugPrint('[SAHARA TRANSPORT RECEIVE] Incoming payload from endpoint=$epId: type=${payload.type}, byteLength=${payload.bytes?.length}');
          if (payload.type == PayloadType.BYTES && payload.bytes != null) {
            final senderNodeId = _endpointIdToNodeId[epId] ?? epId;
            debugPrint('[SAHARA TRANSPORT RECEIVE] Resolved endpoint=$epId to peerNodeId=$senderNodeId (${payload.bytes!.length} bytes)');
            _eventsController.add(MeshTransportEvent(
              type: MeshTransportEventType.packetReceived,
              peerId: senderNodeId,
              data: payload.bytes,
            ));
          } else {
            debugPrint('[SAHARA DROP] Discarding non-byte or empty payload from endpoint=$epId');
          }
        },
        onPayloadTransferUpdate: (String epId, PayloadTransferUpdate update) {
          debugPrint('[SAHARA TRANSPORT RECEIVE] Transfer update for endpoint=$epId: status=${update.status}, bytes=${update.bytesTransferred}/${update.totalBytes}');
        },
      );
    } catch (e) {
      debugPrint('[SAHARA TRANSPORT] Error accepting connection from $peerNodeId: $e');
    }
  }

  /// Triggered when the mutual connection handshake succeeds or fails.
  void _handleConnectionResult(String endpointId, Status status) {
    final peerNodeId = _endpointIdToNodeId[endpointId] ?? endpointId;
    debugPrint('[SAHARA TRANSPORT] Connection result for $endpointId ($peerNodeId): $status');

    if (status == Status.CONNECTED) {
      _connectedPeers.add(peerNodeId);
      debugPrint('[SAHARA TRANSPORT] Peer connected: $peerNodeId (Total active peers: ${_connectedPeers.length})');
      _eventsController.add(MeshTransportEvent(
        type: MeshTransportEventType.peerConnected,
        peerId: peerNodeId,
      ));
    } else {
      _connectedPeers.remove(peerNodeId);
      _endpointIdToNodeId.remove(endpointId);
      _nodeIdToEndpointId.remove(peerNodeId);
      debugPrint('[SAHARA TRANSPORT] Peer connection failed/rejected: $peerNodeId');
      _eventsController.add(MeshTransportEvent(
        type: MeshTransportEventType.peerDisconnected,
        peerId: peerNodeId,
      ));
    }
  }

  /// Triggered when a peer disconnects or leaves radio range.
  void _handleDisconnected(String endpointId) {
    final peerNodeId = _endpointIdToNodeId.remove(endpointId) ?? endpointId;
    _nodeIdToEndpointId.remove(peerNodeId);
    _connectedPeers.remove(peerNodeId);

    debugPrint('[SAHARA TRANSPORT] Peer disconnected: $peerNodeId (Remaining active peers: ${_connectedPeers.length})');
    _eventsController.add(MeshTransportEvent(
      type: MeshTransportEventType.peerDisconnected,
      peerId: peerNodeId,
    ));
  }

  // ---------------------------------------------------------------------------
  // Diagnostics & Teardown
  // ---------------------------------------------------------------------------

  /// List of currently connected peer node IDs
  List<String> get connectedPeers => List.unmodifiable(_connectedPeers);

  /// Checks if a specific peer node ID is currently connected
  bool isPeerConnected(String peerId) => _connectedPeers.contains(peerId);

  /// Disconnects from a specific peer
  Future<void> disconnectPeer(String peerId) async {
    final endpointId = _nodeIdToEndpointId[peerId];
    if (endpointId != null) {
      try {
        await nearby.disconnectFromEndpoint(endpointId);
      } catch (_) {}
      _handleDisconnected(endpointId);
    }
  }

  /// Disposes streams and stops all radio activity
  void dispose() {
    stopDiscovery();
    try {
      nearby.stopAllEndpoints();
    } catch (_) {}
    _eventsController.close();
  }
}
