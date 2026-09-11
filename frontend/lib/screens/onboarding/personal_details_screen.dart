import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_localizations.dart';
import '../../utils/date_input_formatter.dart';

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

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _dobController;
  late final TextEditingController _locationController;
  String? _photoPath;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _dobController = TextEditingController(text: widget.initialDob);
    _locationController = TextEditingController(text: widget.initialLocation);
    _photoPath = widget.initialPhotoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    super.dispose();
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

  Future<void> _useCurrentOnDemandLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('location_services_disabled')),
              backgroundColor: AppTheme.emergencyRed,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('location_permission_denied')),
                backgroundColor: AppTheme.emergencyRed,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('location_permission_denied_forever')),
              backgroundColor: AppTheme.emergencyRed,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('acquiring_location')),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      String addressText = '';
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.subLocality,
            p.locality,
            p.subAdministrativeArea,
            p.administrativeArea,
          ].where((s) => s != null && s.trim().isNotEmpty).toSet().toList();
          if (parts.isNotEmpty) {
            addressText = parts.join(', ');
          }
        }
      } catch (_) {}

      final latStr = '${position.latitude.abs().toStringAsFixed(4)}° ${position.latitude >= 0 ? "N" : "S"}';
      final lonStr = '${position.longitude.abs().toStringAsFixed(4)}° ${position.longitude >= 0 ? "E" : "W"}';

      if (mounted) {
        setState(() {
          if (addressText.isNotEmpty) {
            _locationController.text = '$addressText ($latStr, $lonStr)';
          } else {
            _locationController.text = '$latStr, $lonStr';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retrieve location: $e'),
            backgroundColor: AppTheme.emergencyRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
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
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('location_req');
                    }
                    return null;
                  },
                ),
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
