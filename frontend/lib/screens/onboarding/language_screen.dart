import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_localizations.dart';

class LanguageScreen extends StatefulWidget {
  final String initialLanguage;
  final void Function(String language) onContinue;

  const LanguageScreen({
    super.key,
    this.initialLanguage = 'English',
    required this.onContinue,
  });

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(context.tr('select_language')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('language_preference'),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('disaster_coverage_desc'),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 15 Disaster-Region Languages List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: SupportedLanguages.list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = SupportedLanguages.list[index];
                        final name = item['name']!;
                        final native = item['native']!;
                        final displayLabel = name == native ? name : '$name / $native';
                        final isSelected = _selectedLanguage == name || _selectedLanguage == displayLabel;

                        return Material(
                          color: isSelected ? AppTheme.blueSurfaceTint : AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedLanguage = name;
                              });
                            },
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppTheme.radius),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.secondaryBlue
                                      : AppTheme.surfaceBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayLabel,
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? AppTheme.primaryNavy : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.secondaryBlue
                                            : AppTheme.surfaceBorderStrong,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Center(
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppTheme.secondaryBlue,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Continue Button at bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
              ),
              child: ElevatedButton(
                onPressed: () {
                  widget.onContinue(_selectedLanguage);
                },
                child: Text(context.tr('continue_btn')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
