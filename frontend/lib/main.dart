import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_coordinator.dart';
import 'services/mesh_service.dart';
import 'services/mock_service.dart';
import 'services/native_bridge.dart';
import 'services/nearby_transport.dart';
import 'services/service_scope.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for clean Indian utility aesthetic
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ---------------------------------------------------------------------------
  // 1. Android Runtime Permissions
  // ---------------------------------------------------------------------------
  if (NativeBridge.isAndroidDevice) {
    debugPrint('[SAHARA BOOT] Requesting Android runtime permissions for Nearby Connections...');
    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.nearbyWifiDevices,
        Permission.location,
      ].request();

      final allGranted = statuses.values.every((s) => s.isGranted);
      debugPrint('[SAHARA BOOT] Android runtime permissions result: $statuses (All granted: $allGranted)');
    } catch (e) {
      debugPrint('[SAHARA BOOT] Error requesting runtime permissions: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Persistent Identity Resolution
  // ---------------------------------------------------------------------------
  // Preserves stable physical device node_id and permanent SAHARA user_id across reboots.
  final prefs = await SharedPreferences.getInstance();

  var nodeId = prefs.getString('sahara_node_id');
  if (nodeId == null || nodeId.isEmpty) {
    final randomHex = (Random().nextInt(0xFFFFFF) + 0x100000).toRadixString(16).toUpperCase();
    nodeId = 'NODE_$randomHex';
    await prefs.setString('sahara_node_id', nodeId);
    debugPrint('[SAHARA IDENTITY] Generated and persisted new stable node_id: $nodeId');
  } else {
    debugPrint('[SAHARA IDENTITY] Loaded existing stable node_id: $nodeId');
  }

  var userId = prefs.getString('sahara_user_id');
  if (userId == null || userId.isEmpty) {
    final randomHex = (Random().nextInt(0xefff) + 0x1000).toRadixString(16).toUpperCase();
    userId = 'SH-$randomHex';
    await prefs.setString('sahara_user_id', userId);
    debugPrint('[SAHARA IDENTITY] Generated and persisted new stable user_id: $userId');
  } else {
    debugPrint('[SAHARA IDENTITY] Loaded existing stable user_id: $userId');
  }

  // ---------------------------------------------------------------------------
  // 3. Real Nearby P2P Transport & MeshService Wiring
  // ---------------------------------------------------------------------------
  debugPrint('[SAHARA BOOT] Initializing NearbyConnectionsTransport for Node: $nodeId...');
  final transport = NearbyConnectionsTransport(localNodeId: nodeId);

  debugPrint('[SAHARA BOOT] Initializing MeshService (Node: $nodeId, User: $userId)...');
  final meshService = MeshService(
    myNodeId: nodeId,
    myUserId: userId,
    transport: transport,
  );

  // Wire MeshService stream logging to trace real physical device interaction in logcat
  meshService.onPeersChanged.listen((peers) {
    debugPrint('[SAHARA MESH EVENT] Connected peers updated: count=${peers.length}, list=$peers');
  });

  meshService.onMessageReceived.listen((packet) {
    debugPrint('[SAHARA MESH EVENT] Direct Message received from ${packet.senderNodeId} (${packet.senderId}): "${packet.content}" [TTL=${packet.ttl}]');
  });

  meshService.onSosReceived.listen((packet) {
    debugPrint('[SAHARA MESH EVENT] SOS Alert received from ${packet.senderNodeId} (${packet.senderId}): "${packet.content}" [TTL=${packet.ttl}]');
  });

  meshService.onBroadcastReceived.listen((packet) {
    debugPrint('[SAHARA MESH EVENT] Broadcast received from ${packet.senderNodeId}: "${packet.content}" [TTL=${packet.ttl}]');
  });

  // ---------------------------------------------------------------------------
  // 4. Start Radio Discovery
  // ---------------------------------------------------------------------------
  debugPrint('[SAHARA BOOT] Starting MeshService discovery over Nearby Connections...');
  try {
    await meshService.start();
    debugPrint('[SAHARA BOOT] MeshService discovery successfully started on $nodeId!');
  } catch (e, stack) {
    debugPrint('[SAHARA BOOT] Error starting MeshService discovery: $e\n$stack');
  }

  // ---------------------------------------------------------------------------
  // 5. UI Initialization
  // ---------------------------------------------------------------------------
  final mockService = MockService(meshService: meshService);
  final isProfileComplete = await NativeBridge.isProfileComplete();

  runApp(SaharaApp(
    mockService: mockService,
    meshService: meshService,
    initialIsOnboarded: isProfileComplete,
  ));
}

class SaharaApp extends StatelessWidget {
  final MockService mockService;
  final MeshService? meshService;
  final bool initialIsOnboarded;

  const SaharaApp({
    super.key,
    required this.mockService,
    this.meshService,
    this.initialIsOnboarded = false,
  });

  @override
  Widget build(BuildContext context) {
    return EmergencyServiceScope(
      service: mockService,
      child: MaterialApp(
        title: 'Sahara',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: initialIsOnboarded
            ? const HomeScreen()
            : const OnboardingCoordinator(),
      ),
    );
  }
}
