import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/service_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
import '../widgets/person_tile.dart';
import 'chat_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleCollectivePing(BuildContext context, dynamic service) {
    service.pingFamilyAll();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ping sent to all family members',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.textPrimary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAddFamilyDialog(BuildContext context, dynamic service) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          title: Text(
            context.tr('add_to_family'),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: context.tr('full_name'),
                  hintText: 'e.g. Ramesh Sharma',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: context.tr('phone_number'),
                  hintText: 'e.g. +91 98100 12345',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isNotEmpty) {
                  final newPerson = Person(
                    id: 'fam_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    phoneNumber: phone,
                    relation: PersonRelation.family,
                    status: PersonStatus.reachable,
                    hops: 1,
                    lastSeen: 'Just now',
                    locationAvailable: true,
                    lastKnownLocation: 'Discovered in mesh range',
                  );
                  service.addPersonToFamily(newPerson);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr('added_to_family', {'name': name}),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: AppTheme.primaryNavy,
                    ),
                  );
                }
              },
              child: Text(context.tr('save')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = EmergencyServiceScope.of(context);
    final family = service.familyMembers;
    final reachableCount = family.where((m) => m.isReachable).length;

    final query = _searchController.text.trim().toLowerCase();
    final filteredFamily = query.isEmpty
        ? family
        : family.where((m) {
            final nameMatch = m.name.toLowerCase().contains(query);
            final phoneMatch = m.phoneNumber?.toLowerCase().contains(query) ?? false;
            return nameMatch || phoneMatch;
          }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(context.tr('family')),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: context.tr('add_to_family'),
            onPressed: () => _showAddFamilyDialog(context, service),
          ),
        ],
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
                  hintText: 'Search family by name or phone...',
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

            // Top Status Summary Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              color: AppTheme.blueSurfaceTint.withValues(alpha: 0.5),
              child: Row(
                children: [
                  const Icon(
                    Icons.family_restroom_rounded,
                    color: AppTheme.primaryNavy,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$reachableCount of ${family.length} Family Members Reachable over Mesh',
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

            // Collective Ping Button (ONE collective action for entire family)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleCollectivePing(context, service),
                  icon: const Icon(Icons.sensors_rounded, size: 18),
                  label: Text(
                    context.tr('ping_all_family'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                ),
              ),
            ),

            // Member List (Individual ping buttons removed from family members)
            Expanded(
              child: filteredFamily.isEmpty
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
                            query.isEmpty
                                ? 'No family members added.'
                                : 'No family member matching "$query"',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showAddFamilyDialog(context, service),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                            label: const Text('Add as family'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredFamily.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final member = filteredFamily[index];
                        return PersonTile(
                          person: member,
                          onTap: () => _showFamilyDetailModal(context, service, member),
                          onMessageTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(person: member),
                              ),
                            );
                          },
                          // Individual ping removed for family per specification
                          onPingTap: null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFamilyDetailModal(BuildContext context, dynamic service, Person person) {
    final isReachable = person.isReachable;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMedium)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: person.isDemo
                            ? AppTheme.surfaceSubtle
                            : (isReachable ? AppTheme.activeGreenLight : AppTheme.surfaceSubtle),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(
                          color: person.isDemo
                              ? AppTheme.surfaceBorder
                              : (isReachable ? AppTheme.activeGreenBorder : AppTheme.surfaceBorder),
                        ),
                      ),
                      child: Text(
                        person.isDemo
                            ? 'Demo Contact'
                            : (isReachable ? 'Reachable' : 'Not reachable'),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: person.isDemo
                              ? AppTheme.textSecondary
                              : (isReachable ? AppTheme.activeGreen : AppTheme.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),

                _detailRow('Relationship', person.relationLabel),
                if (person.phoneNumber != null && person.phoneNumber!.isNotEmpty)
                  _detailRow('Phone Number', person.phoneNumber!),
                _detailRow(
                  'Mesh Hops',
                  person.isDemo
                      ? 'Sample contact (no peer)'
                      : (isReachable ? '${person.hops} hops' : 'Out of mesh range'),
                ),
                _detailRow('Last Known Location', person.lastKnownLocation),
                if (person.coordinates != null)
                  _detailRow('Coordinates', person.coordinates!),
                _detailRow('Last Seen Time', person.lastSeen),

                const SizedBox(height: 20),

                // Message action
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(modalContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(person: person),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: Text('Message ${person.name}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
