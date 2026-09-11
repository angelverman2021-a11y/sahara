import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/backend_client.dart';
import '../services/emergency_service.dart';
import '../services/native_bridge.dart';
import '../services/notification_service.dart';
import '../services/sahara_emergency_service.dart';
import '../services/service_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
import '../widgets/brand_title.dart';
import '../widgets/emergency_broadcast_feed.dart';
import '../widgets/feature_card.dart';
import '../widgets/sos_button.dart';
import '../widgets/status_card.dart';
import 'broadcast_screen.dart';
import 'chat_screen.dart';
import 'family_screen.dart';
import 'messages_screen.dart';
import 'nearby_screen.dart';
import 'onboarding/language_screen.dart';
import 'sos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncBattery();
    _checkInitialNotification();
  }

  Future<void> _checkInitialNotification() async {
    try {
      final initialAction = await NotificationService().getInitialNotificationAction();
      if (initialAction != null && mounted) {
        NotificationService().handleNotificationAction(initialAction);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncBattery();
    }
  }

  Future<void> _syncBattery() async {
    try {
      final realLevel = await NativeBridge.getBatteryLevel();
      if (mounted) {
        final service = EmergencyServiceScope.of(context);
        service.updateRealBattery(realLevel);
      }
    } catch (_) {}
  }

  void _openLanguagePicker(BuildContext context, dynamic service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LanguageScreen(
          initialLanguage: service.selectedLanguage,
          onContinue: (lang) {
            service.setLanguage(lang);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showBackendSettings(BuildContext context, dynamic service) {
    if (service is! SaharaEmergencyService) return;

    final urlController = TextEditingController(text: service.backendClient.baseUrl);
    bool testing = false;
    String statusMessage = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync_rounded, color: AppTheme.primaryNavy, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Backend Server & Cloud Sync',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure the reachable IP or host of the SAHARA Python backend server on your local Wi-Fi / LAN network.',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Backend Base URL',
                      hintText: 'e.g. http://192.168.1.15:8000',
                      prefixIcon: Icon(Icons.link_rounded, size: 18),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  if (statusMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: statusMessage.contains('success') || statusMessage.contains('Online')
                              ? AppTheme.activeGreen
                              : AppTheme.emergencyRed,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: testing
                              ? null
                              : () async {
                                  setModalState(() {
                                    testing = true;
                                    statusMessage = 'Testing connectivity...';
                                  });
                                  final newUrl = urlController.text.trim();
                                  service.backendClient.setBaseUrl(newUrl);
                                  await BackendClient.saveStoredBackendUrl(newUrl);

                                  final ok = await service.backendClient.checkHealth();
                                  setModalState(() {
                                    testing = false;
                                    statusMessage = ok
                                        ? 'Server Online (Health Check Passed)'
                                        : 'Server Unreachable. Verify IP and Wi-Fi.';
                                  });
                                },
                          child: Text(testing ? 'Testing...' : 'Test Connection'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: testing
                              ? null
                              : () async {
                                  setModalState(() {
                                    testing = true;
                                    statusMessage = 'Synchronizing...';
                                  });
                                  final newUrl = urlController.text.trim();
                                  service.backendClient.setBaseUrl(newUrl);
                                  await BackendClient.saveStoredBackendUrl(newUrl);

                                  final res = await service.syncWithBackend();
                                  setModalState(() {
                                    testing = false;
                                    statusMessage = res.success
                                        ? 'Sync successful: ${res.messagesSynced} msg, ${res.reportsSynced} reports'
                                        : (res.errorMessage ?? 'Sync failed');
                                  });
                                },
                          child: const Text('Sync Now'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = EmergencyServiceScope.of(context);
    final meshStatus = service.meshStatus;
    final reachableCount = service.familyMembers.where((m) => m.isReachable).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Sahara Official Brand Header + Language Selector
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const BrandTitle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _showBackendSettings(context, service),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: AppTheme.surfaceBorder),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_sync_outlined, size: 15, color: AppTheme.primaryNavy),
                          SizedBox(width: 4),
                          Text(
                            'Sync',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _openLanguagePicker(context, service),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.blueSurfaceTint,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: AppTheme.surfaceBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 14, color: AppTheme.primaryNavy),
                          const SizedBox(width: 5),
                          Text(
                            service.selectedLanguage,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),

              // 2. Subtitle: OFFLINE EMERGENCY MESH NETWORK
              Text(
                context.tr('tagline'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 12),

              // Global Contact Search Bar
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('search_people_placeholder'),
                    hintStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),

              // If searching, show results inline
              if (_searchQuery.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildSearchResultsView(context, service),
                const SizedBox(height: 14),
              ] else ...[
                const SizedBox(height: 14),
              ],

              // 3. Compact Mesh/Network Status (Mesh Active, nearby count, real battery %)
              StatusCard(
                status: meshStatus,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NearbyScreen()),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 4. Prominent Circular SOS Button (Standalone, centered, not enclosed in a card)
              SosButton(
                isBroadcasting: meshStatus.isBroadcastingSOS,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SosScreen()),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 5. Emergency Broadcast Feed (Live announcements with dividers + distinct send button)
              EmergencyBroadcastFeed(
                announcements: service.announcements,
                onSendBroadcast: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BroadcastScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Section Label: Communication & Contacts
              Text(
                context.tr('comm_and_contacts'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),

              // 6. Messages
              FeatureCard(
                title: context.tr('messages'),
                subtitle: context.tr('conversations_count', {'count': service.conversations.length.toString()}),
                icon: Icons.chat_bubble_outline_rounded,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Text(
                    '${service.conversations.length}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),

              // 7. Family
              FeatureCard(
                title: context.tr('family'),
                subtitle: context.tr('family_reachable_count', {
                  'reachable': reachableCount.toString(),
                  'total': service.familyMembers.length.toString(),
                }),
                icon: Icons.family_restroom_rounded,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.activeGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FamilyScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),

              // 8. Nearby People
              FeatureCard(
                title: context.tr('nearby_people'),
                subtitle: context.tr('nearby_detected_count', {'count': meshStatus.nearbyCount.toString()}),
                icon: Icons.radar_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NearbyScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsView(BuildContext context, EmergencyService service) {
    final results = service.searchPeople(_searchQuery);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PEOPLE FOUND (${results.length})',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  child: Text(
                    context.tr('cancel'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.surfaceBorder),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  context.tr('no_people_found'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            )
          else
            for (int i = 0; i < results.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppTheme.surfaceBorder),
              _buildSearchResultRow(context, service, results[i]),
            ],
        ],
      ),
    );
  }

  Widget _buildSearchResultRow(BuildContext context, EmergencyService service, Person person) {
    final isFamily = person.relation == PersonRelation.family;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(person: person)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: isFamily ? AppTheme.primaryNavy : AppTheme.secondaryBlue,
              child: Text(
                person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Name and Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          person.name,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isFamily ? AppTheme.blueSurfaceTint : AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: AppTheme.surfaceBorder),
                        ),
                        child: Text(
                          isFamily
                              ? context.tr('family')
                              : (person.relation == PersonRelation.emergencyTeam
                                  ? 'Team'
                                  : context.tr('nearby')),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isFamily ? AppTheme.primaryNavy : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    person.phoneNumber ?? person.lastKnownLocation,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Actions: Ping and Add to Family
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () {
                    service.pingPerson(person.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('ping_sent_to', {'name': person.name})),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppTheme.primaryNavy,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: AppTheme.surfaceBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                  child: Text(
                    context.tr('ping'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isFamily) ...[
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () {
                      service.addPersonToFamily(person);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('added_to_family', {'name': person.name})),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.activeGreen,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                    ),
                    child: Text(
                      context.tr('add_as_family'),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
