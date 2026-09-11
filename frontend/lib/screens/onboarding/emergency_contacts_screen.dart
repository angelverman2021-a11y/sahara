import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';

class EmergencyContactsScreen extends StatefulWidget {
  final List<EmergencyContact> initialContacts;
  final void Function(List<EmergencyContact> contacts) onContinue;

  const EmergencyContactsScreen({
    super.key,
    this.initialContacts = const [],
    required this.onContinue,
  });

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final List<_ContactFormItem> _items;

  @override
  void initState() {
    super.initState();
    if (widget.initialContacts.isNotEmpty) {
      _items = widget.initialContacts
          .map((c) => _ContactFormItem(
                nameController: TextEditingController(text: c.name),
                relationshipController: TextEditingController(text: c.relationship),
                phoneController: TextEditingController(text: c.phoneNumber),
              ))
          .toList();
    } else {
      _items = [
        _ContactFormItem(
          nameController: TextEditingController(),
          relationshipController: TextEditingController(),
          phoneController: TextEditingController(),
        ),
      ];
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addContact() {
    setState(() {
      _items.add(
        _ContactFormItem(
          nameController: TextEditingController(),
          relationshipController: TextEditingController(),
          phoneController: TextEditingController(),
        ),
      );
    });
  }

  void _removeContact(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index).dispose();
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final contacts = _items.map((item) {
        return EmergencyContact(
          name: item.nameController.text.trim(),
          relationship: item.relationshipController.text.trim(),
          phoneNumber: item.phoneController.text.trim(),
        );
      }).toList();

      widget.onContinue(contacts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Emergency contacts'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'These are trusted individuals to reach or notify during a disaster emergency.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                // Dynamic Contact Forms
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: AppTheme.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Contact ${index + 1}',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (_items.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  color: AppTheme.emergencyRed,
                                  tooltip: 'Remove Contact',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _removeContact(index),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Contact Name
                          const Text(
                            'Name',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: item.nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Meera Sharma',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter contact name' : null,
                          ),
                          const SizedBox(height: 10),

                          // Relationship
                          const Text(
                            'Relationship',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: item.relationshipController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Mother, Spouse, Sibling',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter relationship' : null,
                          ),
                          const SizedBox(height: 10),

                          // Phone Number
                          const Text(
                            'Phone number',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: item.phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: 'e.g. +91 98100 12345',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter phone number' : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Add Another Contact Button
                OutlinedButton.icon(
                  onPressed: _addContact,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add another contact'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.surfaceBorderStrong),
                  ),
                ),
                const SizedBox(height: 24),

                // Continue Button
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Continue'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactFormItem {
  final TextEditingController nameController;
  final TextEditingController relationshipController;
  final TextEditingController phoneController;

  _ContactFormItem({
    required this.nameController,
    required this.relationshipController,
    required this.phoneController,
  });

  void dispose() {
    nameController.dispose();
    relationshipController.dispose();
    phoneController.dispose();
  }
}
