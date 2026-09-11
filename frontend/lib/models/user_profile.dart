import 'dart:convert';

class EmergencyContact {
  final String name;
  final String relationship;
  final String phoneNumber;

  const EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phoneNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'relationship': relationship,
      'phoneNumber': phoneNumber,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
    );
  }
}

class UserProfile {
  final String fullName;
  final String phoneNumber;
  final String dateOfBirth;
  final String currentLocation;
  final String? photoPath;
  final String language;
  final List<EmergencyContact> emergencyContacts;
  final bool isCompleted;

  const UserProfile({
    this.fullName = '',
    this.phoneNumber = '',
    this.dateOfBirth = '',
    this.currentLocation = '',
    this.photoPath,
    this.language = 'English',
    this.emergencyContacts = const [],
    this.isCompleted = false,
  });

  UserProfile copyWith({
    String? fullName,
    String? phoneNumber,
    String? dateOfBirth,
    String? currentLocation,
    String? photoPath,
    String? language,
    List<EmergencyContact>? emergencyContacts,
    bool? isCompleted,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      currentLocation: currentLocation ?? this.currentLocation,
      photoPath: photoPath ?? this.photoPath,
      language: language ?? this.language,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'dateOfBirth': dateOfBirth,
      'currentLocation': currentLocation,
      'photoPath': photoPath,
      'language': language,
      'emergencyContacts': emergencyContacts.map((c) => c.toMap()).toList(),
      'isCompleted': isCompleted,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) {
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      final contactsRaw = map['emergencyContacts'] as List<dynamic>? ?? [];
      final contacts = contactsRaw
          .map((c) => EmergencyContact.fromMap(c as Map<String, dynamic>))
          .toList();

      return UserProfile(
        fullName: map['fullName'] as String? ?? '',
        phoneNumber: map['phoneNumber'] as String? ?? '',
        dateOfBirth: map['dateOfBirth'] as String? ?? '',
        currentLocation: map['currentLocation'] as String? ?? '',
        photoPath: map['photoPath'] as String?,
        language: map['language'] as String? ?? 'English',
        emergencyContacts: contacts,
        isCompleted: map['isCompleted'] as bool? ?? false,
      );
    } catch (_) {
      return const UserProfile();
    }
  }
}

/// The 10 disaster-region focused Indian languages prioritized for
/// flood/cyclone-prone regions (Assam, Odisha, Bihar, West Bengal, Kerala, Gujarat, Andhra/Telangana).
class SupportedLanguages {
  static const List<Map<String, String>> list = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'or', 'name': 'Odia', 'native': 'ଓଡ଼ିଆ'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
    {'code': 'as', 'name': 'Assamese', 'native': 'অসমীয়া'},
    {'code': 'ml', 'name': 'Malayalam', 'native': 'മലയാളം'},
    {'code': 'gu', 'name': 'Gujarati', 'native': 'ગુજરાતી'},
    {'code': 'mai', 'name': 'Maithili', 'native': 'मैथिली'},
    {'code': 'brx', 'name': 'Bodo', 'native': 'बड़ो'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
  ];
}
