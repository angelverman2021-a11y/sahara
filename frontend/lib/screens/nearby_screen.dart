import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/service_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/person_tile.dart';
import 'chat_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handlePing(BuildContext context, dynamic service, Person peer) {
    service.pingPerson(peer.id);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ping sent to ${peer.name}',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.textPrimary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleAddAsFamily(BuildContext context, dynamic service, Person peer) {
    service.addPersonToFamily(peer);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${peer.name} to Family',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primaryNavy,
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = EmergencyServiceScope.of(context);
    final nearbyPeople = service.nearbyPeople;

    final query = _searchController.text.trim().toLowerCase();
    final filteredPeople = query.isEmpty
        ? nearbyPeople
        : nearbyPeople.where((p) {
            final nameMatch = p.name.toLowerCase().contains(query);
            final phoneMatch = p.phoneNumber?.toLowerCase().contains(query) ?? false;
            final locMatch = p.lastKnownLocation.toLowerCase().contains(query);
            return nameMatch || phoneMatch || locMatch;
          }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Nearby Mesh Network'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.surface,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search nearby by name, phone or location...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  filled: true,
                  fillColor: AppTheme.surfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Divider(height: 1),

            // Mesh Topology Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              color: AppTheme.blueSurfaceTint.withValues(alpha: 0.5),
              child: Row(
                children: [
                  const Icon(
                    Icons.radar_rounded,
                    color: AppTheme.primaryNavy,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${nearbyPeople.length} Devices Discovered in Local Mesh Range',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Discovered Peers List
            Expanded(
              child: filteredPeople.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No nearby peers matching "$query"',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredPeople.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final peer = filteredPeople[index];
                        final isAlreadyFamily = peer.relation == PersonRelation.family;

                        return PersonTile(
                          person: peer,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(person: peer),
                              ),
                            );
                          },
                          onMessageTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(person: peer),
                              ),
                            );
                          },
                          // Individual ping retained for nearby peers
                          onPingTap: () => _handlePing(context, service, peer),
                          // Add as family button if not yet family
                          onAddAsFamilyTap: isAlreadyFamily
                              ? null
                              : () => _handleAddAsFamily(context, service, peer),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
