import 'package:flutter/foundation.dart';
import '../models/announcement.dart';
import '../models/mesh_status.dart';
import '../models/message.dart';
import '../models/person.dart';
import '../models/user_profile.dart';

abstract class EmergencyService extends ChangeNotifier {
  MeshStatus get meshStatus;
  List<Person> get nearbyPeople;
  List<Person> get familyMembers;
  List<Person> get conversations;
  List<Message> get recentBroadcasts;
  List<EmergencyAnnouncement> get announcements;
  UserProfile? get userProfile;
  bool get isOnboardingCompleted;
  String get selectedLanguage;

  List<Message> getMessages(String personId);
  Person? getPersonById(String id);

  void triggerSOS();
  void cancelSOS();
  void sendMessage({
    required String receiverId,
    required String content,
    MessagePriority priority = MessagePriority.normal,
  });
  void sendBroadcast({required String content});

  void pingPerson(String personId);
  int pingFamilyAll();
  void addPersonToFamily(Person person);
  void updateRealBattery(int batteryPercent);
  Future<void> saveUserProfile(UserProfile profile);
  Future<void> setLanguage(String lang);
}
