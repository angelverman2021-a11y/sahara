import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_localizations.dart';
import '../../utils/date_input_formatter.dart';
import '../../utils/location_helper.dart';

class PersonalDetailsScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String initialDob;
  final String initialLocation;
  final String? initialPhotoPath;
  final void Function({
    required String name,
    required String phone,
    required String dob,
    required String location,
    String? photoPath,
  }) onContinue;

  const PersonalDetailsScreen({
    super.key,
    this.initialName = '',
    this.initialPhone = '',
    this.initialDob = '',
    this.initialLocation = '',
    this.initialPhotoPath,
    required this.onContinue,
  });

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _dobController;
  late final TextEditingController _locationController;
  String? _photoPath;
  bool _isLocating = false;
  String? _locationError;
  bool _awaitingLocationSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _dobController = TextEditingController(text: widget.initialDob);
    _locationController = TextEditingController(text: widget.initialLocation);
    _photoPath = widget.initialPhotoPath;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingLocationSettings) {
      _awaitingLocationSettings = false;
      _useCurrentOnDemandLocation(autoRetry: true);
    }
  }

  void _handlePickPhoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('select_profile_photo'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryNavy),
                  title: Text(
                    context.tr('take_photo'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickImageFromSource(ImageSource.camera);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryNavy),
                  title: Text(
                    context.tr('choose_gallery'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickImageFromSource(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _photoPath = pickedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access photo: $e'),
            backgroundColor: AppTheme.emergencyRed,
          ),
        );
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1998, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.textPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      _dobController.text = formatted;
    }
  }

  Future<void> _useCurrentOnDemandLocation({bool autoRetry = false}) async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    final result = await LocationHelper.getCurrentOnDemandLocation();

    if (!mounted) return;

    setState(() {
      _isLocating = false;
    });

    switch (result.status) {
      case LocationResultStatus.success:
        setState(() {
          _locationController.text = result.displayText;
          _locationError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('location_detected')),
            backgroundColor: AppTheme.activeGreen,
            duration: const Duration(seconds: 2),
          ),
        );
        break;

      case LocationResultStatus.serviceDisabled:
        setState(() {
          _locationError = context.tr('location_services_disabled');
        });
        if (!autoRetry) {
          _showEnableLocationServicesDialog();
        }
        break;

      case LocationResultStatus.permissionDenied:
        setState(() {
          _locationError = context.tr('location_permission_denied');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('location_permission_denied')),
            backgroundColor: AppTheme.emergencyRed,
            action: SnackBarAction(
              label: context.tr('retry'),
              textColor: Colors.white,
              onPressed: () => _useCurrentOnDemandLocation(),
            ),
          ),
        );
        break;

      case LocationResultStatus.permissionDeniedForever:
        setState(() {
          _locationError = context.tr('location_permission_denied_forever');
        });
        if (!autoRetry) {
          _showPermissionSettingsDialog();
        }
        break;

      case LocationResultStatus.timeout:
      case LocationResultStatus.error:
        setState(() {
          _locationError = result.errorMessage ?? 'Could not detect GPS fix. Please enter manually.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'GPS signal weak or unavailable.'),
            backgroundColor: AppTheme.relayAmber,
            action: SnackBarAction(
              label: context.tr('retry'),
              textColor: Colors.white,
              onPressed: () => _useCurrentOnDemandLocation(),
            ),
          ),
        );
        break;
    }
  }

  void _showEnableLocationServicesDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius)),
        title: Row(
          children: [
            const Icon(Icons.location_off_outlined, color: AppTheme.emergencyRed, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('enable_location_services'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          context.tr('enable_location_services_desc'),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13.5,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _awaitingLocationSettings = true;
              await LocationHelper.openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius)),
            ),
            child: Text(context.tr('open_settings')),
          ),
        ],
      ),
    );
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius)),
        title: Row(
          children: [
            const Icon(Icons.security_outlined, color: AppTheme.emergencyRed, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('location_permission_required'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          context.tr('location_permission_settings_desc'),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13.5,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _awaitingLocationSettings = true;
              await LocationHelper.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius)),
            ),
            child: Text(context.tr('open_settings')),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onContinue(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        dob: _dobController.text.trim(),
        location: _locationController.text.trim(),
        photoPath: _photoPath,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoPath != null && File(_photoPath!).existsSync();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(context.tr('your_details')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('personal_info'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('gov_id_hint'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Profile Photo
                Center(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: _handlePickPhoto,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            border: Border.all(color: AppTheme.surfaceBorderStrong),
                          ),
                          child: hasPhoto
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(AppTheme.radius),
                                  child: Image.file(
                                    File(_photoPath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 26,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.tr('add_photo'),
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _handlePickPhoto,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          foregroundColor: AppTheme.textPrimary,
                        ),
                        child: Text(
                          hasPhoto ? context.tr('change_photo') : context.tr('select_profile_photo'),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Full Name
                Text(
                  context.tr('full_name'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: context.tr('name_hint'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('name_req');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mobile Number
                Text(
                  context.tr('contact_number'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: context.tr('phone_hint'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('phone_req');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date of Birth
                Text(
                  context.tr('date_of_birth'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dobController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [DateInputFormatter()],
                  maxLength: 10,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: InputDecoration(
                    hintText: 'DD/MM/YYYY',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      onPressed: _selectDateOfBirth,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('dob_req');
                    }
                    if (!DateInputFormatter.isValidDate(value)) {
                      return context.tr('dob_invalid');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Current Location (On-Demand Real GPS)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('current_location'),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    InkWell(
                      onTap: _isLocating ? null : _useCurrentOnDemandLocation,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLocating)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.activeGreen,
                              ),
                            )
                          else
                            const Icon(Icons.my_location, size: 14, color: AppTheme.activeGreen),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('use_current_location'),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.activeGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: context.tr('location_hint'),
                    suffixIcon: _isLocating
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          )
                        : (_locationController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _locationController.clear();
                                    _locationError = null;
                                  });
                                },
                              )
                            : null),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('location_req');
                    }
                    return null;
                  },
                ),
                if (_locationError != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.emergencyRedLight,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppTheme.emergencyRedBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppTheme.emergencyRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationError!,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: AppTheme.emergencyRed,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _useCurrentOnDemandLocation(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            context.tr('retry'),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.emergencyRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // Continue Button
                ElevatedButton(
                  onPressed: _submit,
                  child: Text(context.tr('continue_btn')),
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
