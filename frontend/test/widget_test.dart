import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra/main.dart';
import 'package:sahra/models/announcement.dart';
import 'package:sahra/models/message_model.dart';
import 'package:sahra/models/user_profile.dart';
import 'package:sahra/screens/splash_screen.dart';
import 'package:sahra/services/mesh_service.dart';
import 'package:sahra/services/mock_service.dart';
import 'package:sahra/services/notification_service.dart';
import 'package:sahra/utils/app_localizations.dart';
import 'package:sahra/utils/broadcast_localizer.dart';
import 'package:sahra/utils/date_input_formatter.dart';
import 'package:sahra/utils/location_helper.dart';
import 'package:sahra/widgets/app_logo.dart';
import 'package:sahra/widgets/brand_title.dart';
import 'package:sahra/widgets/person_tile.dart';
import 'package:sahra/widgets/sos_button.dart';
import 'package:shared_preferences/shared_preferences.dart';


void setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('Sahara Home Screen renders key emergency elements without logo in header and without footer', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // 1. Verify Top-left has BrandTitle (*Sahara*) but NO AppLogo
    expect(find.byType(BrandTitle), findsAtLeastNWidgets(1));
    expect(find.text('Sahara'), findsAtLeastNWidgets(1));
    expect(find.byType(AppLogo), findsNothing);

    // 2. Subtitle
    expect(find.text('OFFLINE EMERGENCY MESH NETWORK'), findsOneWidget);

    // 3. Compact Mesh Status
    expect(find.text('Mesh Active'), findsOneWidget);
    expect(find.textContaining('meshes available'), findsOneWidget);

    // 4. Prominent Circular SOS Button
    expect(find.byType(SosButton), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('EMERGENCY'), findsAtLeastNWidgets(1));

    // 5. Emergency Broadcast feed (Existing announcements visible immediately on Home)
    expect(find.text('EMERGENCY BROADCAST'), findsOneWidget);
    expect(find.text('Cyclone Warning'), findsOneWidget);
    expect(find.text('Flood Evacuation Notice'), findsOneWidget);
    expect(find.text('Send emergency broadcast'), findsOneWidget);

    // 6. Navigation items
    expect(find.text('COMMUNICATION & CONTACTS'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Nearby People'), findsOneWidget);

    // 7. Footer removed as requested
    expect(find.text('Decentralized P2P Mesh • Works without cellular coverage'), findsNothing);
  });

  testWidgets('SOS confirmation and broadcast flow works end-to-end', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Tap circular SOS button on Home
    await tester.tap(find.byType(SosButton));
    await tester.pumpAndSettle();

    // Should be on SosScreen in confirmation mode
    expect(find.text('EMERGENCY SOS'), findsAtLeastNWidgets(1));
    expect(find.text('CRITICAL'), findsOneWidget);
    final confirmBtn = find.text('CONFIRM EMERGENCY SOS');
    expect(confirmBtn, findsOneWidget);

    // Confirm SOS
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Should transition to SOS SENT state
    expect(find.text('SOS ACTIVE'), findsAtLeastNWidgets(1));
    expect(find.text('Broadcasting'), findsOneWidget);

    // Cancel SOS
    final cancelBtn = find.text('CANCEL SOS');
    await tester.ensureVisible(cancelBtn);
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    // Back to confirmation prompt
    expect(find.text('CONFIRM EMERGENCY SOS'), findsOneWidget);
  });

  testWidgets('Messages and Chat flow sends message locally', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Navigate to Messages
    final messagesCard = find.text('Messages');
    await tester.ensureVisible(messagesCard);
    await tester.tap(messagesCard);
    await tester.pumpAndSettle();

    expect(find.text('Emergency Messages'), findsOneWidget);
    expect(find.text('Mother'), findsOneWidget);
    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('Emergency Team'), findsOneWidget);

    // Open Mother conversation
    await tester.tap(find.text('Mother'));
    await tester.pumpAndSettle();

    // Verify Chat screen
    expect(find.text('Connected • 3 hops'), findsOneWidget);
    expect(find.text('Are you safe?'), findsOneWidget);

    // Type a new message
    await tester.enterText(find.byType(TextField), 'I am safe and reaching the camp now.');
    await tester.pumpAndSettle();

    // Tap Send
    await tester.tap(find.byTooltip('Send Mesh Message'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Verify message is added to UI locally
    expect(find.text('I am safe and reaching the camp now.'), findsOneWidget);
  });

  testWidgets('Family screen collective ping and search work', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Navigate to Family
    final familyCard = find.text('Family');
    await tester.ensureVisible(familyCard);
    await tester.tap(familyCard);
    await tester.pumpAndSettle();

    expect(find.text('Family'), findsAtLeastNWidgets(1));
    expect(find.text('Ping All Family'), findsOneWidget);

    // Tap collective "Ping All Family"
    await tester.tap(find.text('Ping All Family'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify collective feedback
    expect(find.text('Ping sent to all family members'), findsOneWidget);

    // Test Search
    final searchInput = find.widgetWithText(TextField, 'Search family by name or phone...');
    expect(searchInput, findsOneWidget);
    await tester.enterText(searchInput, 'Father');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PersonTile, 'Father'), findsOneWidget);
    expect(find.text('Mother'), findsNothing);
  });

  testWidgets('Nearby screen titled "Nearby People" with search, ping and Add to family', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService(initialPeers: ['NODE_6829AE']);
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Navigate to Nearby People
    final nearbyCard = find.text('Nearby People');
    await tester.ensureVisible(nearbyCard);
    await tester.tap(nearbyCard);
    await tester.pumpAndSettle();

    expect(find.text('Nearby People'), findsAtLeastNWidgets(1));
    expect(find.textContaining('People Discovered in Range'), findsOneWidget);
    // Real user name displayed, NOT raw node_id
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('NODE_6829AE'), findsNothing);

    // Nearby tiles have individual Ping
    expect(find.text('Ping'), findsAtLeastNWidgets(1));

    // Tap ping on first peer
    final firstPing = find.text('Ping').first;
    await tester.tap(firstPing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Ping sent to Aarav Sharma'), findsOneWidget);

    // Tap "Add to Family" on non-family peer
    final addFamilyBtn = find.text('Add to Family').first;
    await tester.ensureVisible(addFamilyBtn);
    await tester.tap(addFamilyBtn);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Added Aarav Sharma to Family'), findsOneWidget);
  });

  testWidgets('Real physical mesh peer connect and disconnect updates UI reactively', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      mockService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Initially 0 peers
    expect(find.textContaining('meshes available'), findsOneWidget);
    expect(find.textContaining('0 mesh peers detected'), findsOneWidget);

    // Navigate to Nearby People
    final nearbyCard = find.text('Nearby People');
    await tester.ensureVisible(nearbyCard);
    await tester.tap(nearbyCard);
    await tester.pumpAndSettle();

    expect(find.text('0 People Discovered in Range'), findsOneWidget);
    expect(find.text('Searching for nearby SAHARA devices...'), findsOneWidget);

    // Simulate real peer connection (e.g. NODE_6829AE -> Aarav Sharma)
    mockService.updateConnectedPeers(['NODE_6829AE']);
    await tester.pumpAndSettle();

    // UI updates reactively with user's real name!
    expect(find.text('1 People Discovered in Range'), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('NODE_6829AE'), findsNothing);
    expect(find.text('Mesh Peer'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Reachable • 1 hop'), findsOneWidget);

    // Simulate peer disconnection
    mockService.updateConnectedPeers([]);
    await tester.pumpAndSettle();

    // UI updates reactively to 0 peers
    expect(find.text('0 People Discovered in Range'), findsOneWidget);
    expect(find.text('Searching for nearby SAHARA devices...'), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsNothing);
  });

  testWidgets('Unknown mesh peer resolves to safe fallback "Mesh Peer" rather than NODE_xxxxxx', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService(initialPeers: ['NODE_UNKNOWN_99']);
    await tester.pumpWidget(SaharaApp(
      mockService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Navigate to Nearby People
    final nearbyCard = find.text('Nearby People');
    await tester.ensureVisible(nearbyCard);
    await tester.tap(nearbyCard);
    await tester.pumpAndSettle();

    expect(find.text('1 People Discovered in Range'), findsOneWidget);
    // Never display NODE_xxxxxx as the person's name
    expect(find.text('NODE_UNKNOWN_99'), findsNothing);
    expect(find.text('Mesh Peer'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Reachable • 1 hop'), findsOneWidget);
  });

  testWidgets('Emergency Broadcast flow with severity selector adds immediately to feed', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Navigate to Broadcast via Send emergency broadcast button
    final broadcastBtn = find.text('Send emergency broadcast');
    await tester.ensureVisible(broadcastBtn);
    await tester.tap(broadcastBtn);
    await tester.pumpAndSettle();

    expect(find.text('Emergency Broadcast'), findsAtLeastNWidgets(1));
    expect(find.text('BROADCAST SEVERITY'), findsOneWidget);
    expect(find.text('Advisory'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Evacuation'), findsOneWidget);

    // Select Evacuation severity
    await tester.tap(find.text('Evacuation'));
    await tester.pumpAndSettle();

    // Tap a template suggestion
    await tester.tap(find.text('Road blocked near Gate 2.'));
    await tester.pumpAndSettle();

    // Tap BROADCAST MESSAGE
    final submitBroadcastBtn = find.widgetWithText(ElevatedButton, 'BROADCAST MESSAGE');
    await tester.ensureVisible(submitBroadcastBtn);
    await tester.tap(submitBroadcastBtn);
    await tester.pumpAndSettle();

    // Verify confirmation state
    expect(find.text('BROADCAST SENT'), findsAtLeastNWidgets(1));
    expect(find.text('Recipients reached'), findsOneWidget);

    // Return to Home
    await tester.tap(find.text('Return to Home'));
    await tester.pumpAndSettle();

    // Verify new Evacuation announcement appears immediately in Home feed!
    expect(find.text('EVACUATION'), findsNWidgets(2));
    expect(find.text('Road blocked near Gate 2.'), findsOneWidget);
  });

  testWidgets('Language switch visibly translates the UI across disaster languages', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Switch language to Hindi
    await mockService.setLanguage('Hindi');
    await tester.pumpAndSettle();

    // Check that Home screen elements are in Hindi
    expect(find.text('मेश सक्रिय'), findsOneWidget);
    expect(find.text('आपातकालीन प्रसारण'), findsOneWidget);
    expect(find.text('संचार एवं संपर्क'), findsOneWidget);
    expect(find.text('संदेश'), findsOneWidget);
    expect(find.text('परिवार'), findsOneWidget);
    expect(find.text('आस-पास के लोग'), findsOneWidget);

    // Switch to Odia
    await mockService.setLanguage('Odia');
    await tester.pumpAndSettle();

    expect(find.text('ମେଶ୍ ସକ୍ରିୟ'), findsOneWidget);
    expect(find.text('ଜରୁରୀକାଳୀନ ପ୍ରସାରଣ'), findsOneWidget);
    expect(find.text('ପରିବାର'), findsOneWidget);

    // Switch to Telugu
    await mockService.setLanguage('Telugu');
    await tester.pumpAndSettle();

    expect(find.text('మెష్ యాక్టివ్‌గా ఉంది'), findsOneWidget);
    expect(find.text('కుటుంబం'), findsOneWidget);
    expect(find.text('దగ్గరలోని వ్యక్తులు'), findsOneWidget);

    // Switch to Marathi
    await mockService.setLanguage('Marathi');
    await tester.pumpAndSettle();

    expect(find.text('मेश सक्रिय'), findsOneWidget);
    expect(find.text('कुटुंब'), findsOneWidget);

    // Switch to Tamil
    await mockService.setLanguage('Tamil');
    await tester.pumpAndSettle();

    expect(find.text('மெஷ் செயல்படுகிறது'), findsOneWidget);
    expect(find.text('குடும்பம்'), findsOneWidget);

    // Switch to Kannada
    await mockService.setLanguage('Kannada');
    await tester.pumpAndSettle();

    expect(find.text('ಮೆಶ್ ಸಕ್ರಿಯವಾಗಿದೆ'), findsOneWidget);
    expect(find.text('ಕುಟುಂಬ'), findsOneWidget);

    // Switch to Punjabi
    await mockService.setLanguage('Punjabi');
    await tester.pumpAndSettle();

    expect(find.text('ਮੈਸ਼ ਸਰਗਰਮ ਹੈ'), findsOneWidget);
    expect(find.text('ਪਰਿਵਾਰ'), findsOneWidget);

    // Switch to Kashmiri
    await mockService.setLanguage('Kashmiri');
    await tester.pumpAndSettle();

    expect(find.text('मेश चालू छु'), findsOneWidget);
    expect(find.text('खानदान'), findsOneWidget);

    // Switch back to English
    await mockService.setLanguage('English');
    await tester.pumpAndSettle();

    expect(find.text('Mesh Active'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
  });

  testWidgets('Welcome screen has large logo without outer card', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: false,
    ));
    await tester.pumpAndSettle();

    // Welcome Screen has official logo directly on background
    expect(find.byType(AppLogo), findsOneWidget);
    final logoWidget = tester.widget<AppLogo>(find.byType(AppLogo));
    expect(logoWidget.height, 150);
    expect(logoWidget.width, 280);
    expect(find.text('Get Started'), findsOneWidget);
  });

  test('DateInputFormatter strictly validates and formats DD/MM/YYYY', () {
    expect(DateInputFormatter.formatDigits('12052004'), '12/05/2004');
    expect(DateInputFormatter.formatDigits('1205'), '12/05');
    expect(DateInputFormatter.formatDigits('12'), '12');
    expect(DateInputFormatter.isValidDate('12/05/2004'), true);
    expect(DateInputFormatter.isValidDate('31/02/2020'), false); // Invalid Feb 31
    expect(DateInputFormatter.isValidDate('35/10/2020'), false); // Invalid day 35
  });

  testWidgets('Home Global Contact Search searches by name and phone number inline', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // 1. Search bar is present on Home screen
    final searchField = find.widgetWithText(TextField, 'Search people by name or phone number');
    expect(searchField, findsOneWidget);

    // 2. Type "Mother"
    await tester.enterText(searchField, 'Mother');
    await tester.pumpAndSettle();

    // Search results are rendered on Home
    expect(find.textContaining('PEOPLE FOUND'), findsOneWidget);
    expect(find.text('Mother'), findsAtLeastNWidgets(1));
    expect(find.text('+91 98100 12345'), findsOneWidget);

    // 3. Type phone number "67890" (Father's phone is +91 98100 67890)
    await tester.enterText(searchField, '67890');
    await tester.pumpAndSettle();

    expect(find.text('Father'), findsOneWidget);
    expect(find.text('+91 98100 67890'), findsOneWidget);

    // 4. Test Ping action on search result
    final pingBtn = find.widgetWithText(OutlinedButton, 'Ping');
    expect(pingBtn, findsAtLeastNWidgets(1));
    await tester.tap(pingBtn.first);
    await tester.pumpAndSettle();
    expect(find.text('Ping sent to Father'), findsOneWidget);

    // 5. Clear search query
    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();

    // Results view closes, standard Home is visible
    expect(find.textContaining('PEOPLE FOUND'), findsNothing);
    expect(find.text('EMERGENCY BROADCAST'), findsOneWidget);
  });

  test('LocationHelper cleanly formats coordinates and handles fallback', () {
    expect(
      LocationHelper.formatCoordinates(28.5355, 77.3910, 5),
      '28.5355° N, 77.3910° E (±5m)',
    );
    expect(
      LocationHelper.formatCoordinates(-12.3456, -45.6789),
      '12.3456° S, 45.6789° W',
    );
  });

  test('BroadcastLocalizer translates default announcements across all 10 languages non-destructively', () {
    final mockService = MockService();
    final announcements = mockService.announcements;
    expect(announcements.isNotEmpty, true);

    final cycloneWarning = announcements.firstWhere((a) => a.id == 'ann_1');

    // 1. Original data is preserved internally
    expect(cycloneWarning.title, 'Cyclone Warning');
    expect(
      cycloneWarning.message,
      'Heavy rainfall and wind speeds up to 65 km/h expected in your sector. Move to designated storm shelters.',
    );

    // 2. English (en)
    expect(cycloneWarning.localizedTitle('en'), 'Cyclone Warning');

    // 3. Hindi (hi)
    expect(cycloneWarning.localizedTitle('hi'), 'चक्रवात की चेतावनी');
    expect(
      cycloneWarning.localizedMessage('hi'),
      'आपके क्षेत्र में भारी वर्षा और 65 किमी/घंटा तक की हवाओं की संभावना है। निर्धारित तूफान आश्रयों में जाएं।',
    );

    // 4. Odia (or)
    expect(cycloneWarning.localizedTitle('or'), 'ବାତ୍ୟା ସତର୍କତା');
    expect(
      cycloneWarning.localizedMessage('or'),
      'ଆପଣଙ୍କ ଅଞ୍ଚଳରେ ପ୍ରବଳ ବର୍ଷା ଏବଂ ୬୫ କିମି/ଘଣ୍ଟା ବେଗରେ ପବନ ବହିବାର ସମ୍ଭାବନା ଅଛି। ନିର୍ଦ୍ଧାରିତ ବାତ୍ୟା ଆଶ୍ରୟସ୍ଥଳକୁ ଯାଆନ୍ତୁ।',
    );

    // 5. Bengali (bn)
    expect(cycloneWarning.localizedTitle('bn'), 'ঘূর্ণিঝড় সতর্কতা');

    // 6. Assamese (as)
    expect(cycloneWarning.localizedTitle('as'), 'ঘূৰ্ণীবতাহৰ সতৰ্কবাণী');

    // 7. Malayalam (ml)
    expect(cycloneWarning.localizedTitle('ml'), 'ചുഴലിക്കാറ്റ് മുന്നറിയിപ്പ്');

    // 8. Gujarati (gu)
    expect(cycloneWarning.localizedTitle('gu'), 'વાવાઝોડાની ચેતવણી');

    // 9. Maithili (mai)
    expect(cycloneWarning.localizedTitle('mai'), 'चक्रवातक चेतावनी');

    // 10. Bodo (brx)
    expect(cycloneWarning.localizedTitle('brx'), 'बारहुंखा सांग्रांथि');

    // 11. Telugu (te)
    expect(cycloneWarning.localizedTitle('te'), 'తుఫాను హెచ్చరిక');
  });

  test('Broadcast content falls back gracefully to original language for untranslated custom broadcasts', () {
    const custom = EmergencyAnnouncement(
      id: 'ann_custom_99',
      title: 'Custom Incident Alert',
      message: 'Small fire contained in Sector 5 workshop. No casualties.',
      source: 'Local Watch',
      timeAgo: 'Just now',
    );

    // When no translations map is provided, falls back cleanly to original text
    expect(custom.localizedTitle('hi'), 'Custom Incident Alert');
    expect(custom.localizedMessage('hi'), 'Small fire contained in Sector 5 workshop. No casualties.');
    expect(custom.localizedTitle('or'), 'Custom Incident Alert');
    expect(custom.localizedMessage('bn'), 'Small fire contained in Sector 5 workshop. No casualties.');

    // Never returns empty string
    expect(custom.localizedTitle('te').isNotEmpty, true);
    expect(custom.localizedMessage('te').isNotEmpty, true);
  });

  test('Newly composed broadcast generates full 10-language translations when using quick suggestion template', () {
    final translations = BroadcastLocalizer.getTranslationsForComposed(
      title: 'Emergency Warning',
      message: 'Road blocked near Gate 2.',
      severity: AnnouncementSeverity.warning,
      source: 'You',
    );

    expect(translations['hi']?.title, 'आपातकालीन चेतावनी');
    expect(translations['hi']?.message, 'गेट 2 के पास सड़क अवरुद्ध है।');
    expect(translations['or']?.title, 'ଜରୁରୀକାଳୀନ ସତର୍କତା');
    expect(translations['or']?.message, 'ଗେଟ୍ ୨ ନିକଟରେ ରାସ୍ତା ଅବରୋଧ ଅଛି।');
    expect(translations['bn']?.title, 'জরুরি সতর্কতা');
    expect(translations['bn']?.message, 'গেট ২ এর কাছে রাস্তা বন্ধ রয়েছে।');
  });

  testWidgets('Home EmergencyBroadcastFeed content translates dynamically when language is switched', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // In English initially:
    expect(find.text('Cyclone Warning'), findsOneWidget);
    expect(
      find.text('Heavy rainfall and wind speeds up to 65 km/h expected in your sector. Move to designated storm shelters.'),
      findsOneWidget,
    );

    // Switch language to Hindi:
    mockService.setLanguage('Hindi');
    await tester.pumpAndSettle();

    // Verified: Announcement title and message changed to Hindi!
    expect(find.text('चक्रवात की चेतावनी'), findsOneWidget);
    expect(
      find.text('आपके क्षेत्र में भारी वर्षा और 65 किमी/घंटा तक की हवाओं की संभावना है। निर्धारित तूफान आश्रयों में जाएं।'),
      findsOneWidget,
    );

    // Switch language to Odia:
    mockService.setLanguage('Odia');
    await tester.pumpAndSettle();

    // Verified: Announcement title changed to Odia!
    expect(find.text('ବାତ୍ୟା ସତର୍କତା'), findsOneWidget);
  });


  test('All 15 disaster-region languages are defined in SupportedLanguages', () {
    expect(SupportedLanguages.list.length, 15);
    final codes = SupportedLanguages.list.map((l) => l['code']).toList();
    expect(codes, containsAll([
      'en', 'hi', 'or', 'bn', 'as',
      'ml', 'gu', 'mai', 'brx', 'te',
      'mr', 'ta', 'kn', 'pa', 'ks',
    ]));

    final nativeNames = SupportedLanguages.list.map((l) => l['native']).toList();
    expect(nativeNames, containsAll([
      'English', 'हिन्दी', 'ଓଡ଼ିଆ', 'বাংলা', 'অসমীয়া',
      'മലയാളം', 'ગુજરાતી', 'मैथिली', 'बड़ो', 'తెలుగు',
      'मराठी', 'தமிழ்', 'ಕನ್ನಡ', 'ਪੰਜਾਬੀ', 'कॉशुर',
    ]));
  });

  test('AppLocalizations codeForLanguage recognizes all 15 languages', () {
    expect(AppLocalizations.codeForLanguage('English'), 'en');
    expect(AppLocalizations.codeForLanguage('Hindi'), 'hi');
    expect(AppLocalizations.codeForLanguage('Odia'), 'or');
    expect(AppLocalizations.codeForLanguage('Bengali'), 'bn');
    expect(AppLocalizations.codeForLanguage('Assamese'), 'as');
    expect(AppLocalizations.codeForLanguage('Malayalam'), 'ml');
    expect(AppLocalizations.codeForLanguage('Gujarati'), 'gu');
    expect(AppLocalizations.codeForLanguage('Maithili'), 'mai');
    expect(AppLocalizations.codeForLanguage('Bodo'), 'brx');
    expect(AppLocalizations.codeForLanguage('Telugu'), 'te');
    expect(AppLocalizations.codeForLanguage('Marathi'), 'mr');
    expect(AppLocalizations.codeForLanguage('Tamil'), 'ta');
    expect(AppLocalizations.codeForLanguage('Kannada'), 'kn');
    expect(AppLocalizations.codeForLanguage('Punjabi'), 'pa');
    expect(AppLocalizations.codeForLanguage('Kashmiri'), 'ks');
  });

  test('BroadcastLocalizer produces all 15 language translations for composed broadcasts and SOS', () {
    final translations = BroadcastLocalizer.getTranslationsForComposed(
      title: 'Cyclone Warning',
      message: 'Road blocked near Gate 2.',
      severity: AnnouncementSeverity.warning,
      source: 'Disaster Cell',
    );

    const expected15 = [
      'en', 'hi', 'or', 'bn', 'as',
      'ml', 'gu', 'mai', 'brx', 'te',
      'mr', 'ta', 'kn', 'pa', 'ks',
    ];

    for (final lang in expected15) {
      expect(translations.containsKey(lang), true, reason: 'Missing composed broadcast translation for $lang');
      expect(translations[lang]?.title.isNotEmpty, true);
      expect(translations[lang]?.message.isNotEmpty, true);
    }

    final sos = BroadcastLocalizer.getSosTranslations('28.5355° N, 77.3910° E');
    for (final lang in expected15) {
      expect(sos.containsKey(lang), true, reason: 'Missing SOS translation for $lang');
      expect(sos[lang]?.contains('28.5355° N, 77.3910° E'), true);
    }
  });

  testWidgets('SplashScreen displays pure white background and official Sahara logo', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();

    await tester.pumpWidget(SaharaApp(
      mockService: mockService,
      showSplashScreen: true,
      initialIsOnboarded: true,
    ));

    // Initially on SplashScreen
    expect(find.byType(SplashScreen), findsOneWidget);

    // Verify background color is pure white
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.white);

    // Verify official Sahara logo asset is centered
    expect(find.byType(Image), findsOneWidget);
    final imageWidget = tester.widget<Image>(find.byType(Image));
    expect((imageWidget.image as AssetImage).assetName, 'assets/images/sahara_logo.png');

    // Wait for the timer and navigation
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
  });

  test('NotificationService handles triggers and MockService generates notifications', () async {
    final notificationService = NotificationService();
    final hasPerm = await notificationService.checkPermission();
    expect(hasPerm, true);

    // Trigger emergency broadcast notification
    await notificationService.showEmergencyBroadcastNotification(
      title: 'Cyclone Alert',
      message: 'Take shelter immediately',
      severity: AnnouncementSeverity.evacuation,
    );

    // Trigger family message notification
    await notificationService.showFamilyMessageNotification(
      senderName: 'Mother',
      content: 'Power is out',
      personId: 'fam_mother',
    );

    final mockService = MockService();
    mockService.receiveFamilyMessage(
      senderId: 'fam_mother',
      content: 'Testing incoming family message',
    );

    final messages = mockService.getMessages('fam_mother');
    expect(messages.last.content, 'Testing incoming family message');
    expect(messages.last.isFromMe, false);
  });

  testWidgets('Tapping broadcast in EmergencyBroadcastFeed opens detail dialog', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      emergencyService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Tap on Cyclone Warning broadcast
    await tester.tap(find.text('Cyclone Warning'));
    await tester.pumpAndSettle();

    // Verify detail dialog is shown
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cyclone Warning'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Heavy rainfall and wind speeds up to 65 km/h'),
      ),
      findsOneWidget,
    );

    // Tap close
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Real physical mesh peer direct message flow transmits, receives and renders across two nodes with strict user_id vs node_id identity separation', (WidgetTester tester) async {
    setPhoneViewport(tester);

    final transportA = MockMeshTransport(localNodeId: 'NODE_AAA111');
    final transportB = MockMeshTransport(localNodeId: 'NODE_BBB222');

    final meshServiceA = MeshService(
      myNodeId: 'NODE_AAA111',
      myUserId: 'SH-USERA',
      transport: transportA,
    );

    final meshServiceB = MeshService(
      myNodeId: 'NODE_BBB222',
      myUserId: 'SH-USERB',
      transport: transportB,
    );

    final mockServiceA = MockService(meshService: meshServiceA);
    final mockServiceB = MockService(meshService: meshServiceB);

    // Register Node B's user ID on MockService A
    mockServiceA.registerPeerUserId('NODE_BBB222', 'SH-USERB');

    // Connect Node A and Node B bidirectionally
    transportA.connectTo('NODE_BBB222');

    // Listen to packet received at Node B
    MessagePacket? packetAtB;
    final subB = meshServiceB.onMessageReceived.listen((p) {
      packetAtB = p;
    });

    // Pump UI for Node B (Recipient phone)
    await tester.pumpWidget(SaharaApp(
      mockService: mockServiceB,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Node B sees 1 peer nearby
    expect(find.textContaining('1 meshes available'), findsOneWidget);

    // Node A sends direct message to Node B
    mockServiceA.sendMessage(
      receiverId: 'NODE_BBB222',
      content: 'Emergency Alert: High water level near Bridge 4!',
    );

    await tester.pumpAndSettle();

    // Verify MessagePacket identity separation on the wire:
    // sender_id = user_id (SH-USERA), NOT node_id
    // sender_node_id = physical node_id (NODE_AAA111)
    // receiver_id = user_id (SH-USERB), NOT node_id
    // receiver_node_id = physical node_id (NODE_BBB222)
    expect(packetAtB, isNotNull);
    expect(packetAtB!.senderId, 'SH-USERA');
    expect(packetAtB!.senderNodeId, 'NODE_AAA111');
    expect(packetAtB!.receiverId, 'SH-USERB');
    expect(packetAtB!.receiverNodeId, 'NODE_BBB222');
    expect(packetAtB!.content, 'Emergency Alert: High water level near Bridge 4!');

    // Node B learned Node A's user_id automatically from the incoming packet!
    expect(mockServiceB.resolvePeerUserId('NODE_AAA111'), 'SH-USERA');

    final messagesCard = find.text('Messages');
    await tester.ensureVisible(messagesCard);
    await tester.tap(messagesCard);
    await tester.pumpAndSettle();

    // Node B's conversation list shows the message from Node A!
    expect(find.text('Emergency Alert: High water level near Bridge 4!'), findsOneWidget);

    // Open chat with Node A on Node B
    await tester.tap(find.text('Emergency Alert: High water level near Bridge 4!'));
    await tester.pumpAndSettle();

    // Message is displayed in chat bubble
    expect(find.text('Emergency Alert: High water level near Bridge 4!'), findsWidgets);

    subB.cancel();
    meshServiceA.dispose();
    meshServiceB.dispose();
    transportA.dispose();
    transportB.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('MeshService strict identity separation: sender_id and receiver_id are user_id, sender_node_id and receiver_node_id are node_id', () async {
    final transportA = MockMeshTransport(localNodeId: 'NODE_AAA111');
    final transportB = MockMeshTransport(localNodeId: 'NODE_BBB222');

    final meshServiceA = MeshService(
      myNodeId: 'NODE_AAA111',
      myUserId: 'SH-USERA',
      transport: transportA,
    );

    final meshServiceB = MeshService(
      myNodeId: 'NODE_BBB222',
      myUserId: 'SH-USERB',
      transport: transportB,
    );

    transportA.connectTo('NODE_BBB222');
    await Future.delayed(const Duration(milliseconds: 50));

    MessagePacket? packetAtB;
    final subB = meshServiceB.onMessageReceived.listen((p) {
      packetAtB = p;
    });

    MessagePacket? packetAtA;
    final subA = meshServiceA.onMessageReceived.listen((p) {
      packetAtA = p;
    });

    await meshServiceA.sendDirectMessage(
      receiverNodeId: 'NODE_BBB222',
      receiverUserId: 'SH-USERB',
      content: 'Ping from Node A',
    );
    await Future.delayed(const Duration(milliseconds: 50));

    expect(packetAtB, isNotNull);
    expect(packetAtB!.senderId, 'SH-USERA');
    expect(packetAtB!.senderNodeId, 'NODE_AAA111');
    expect(packetAtB!.receiverId, 'SH-USERB');
    expect(packetAtB!.receiverNodeId, 'NODE_BBB222');

    await meshServiceB.sendDirectMessage(
      receiverNodeId: 'NODE_AAA111',
      receiverUserId: 'SH-USERA',
      content: 'Pong from Node B',
    );
    await Future.delayed(const Duration(milliseconds: 50));

    expect(packetAtA, isNotNull);
    expect(packetAtA!.senderId, 'SH-USERB');
    expect(packetAtA!.senderNodeId, 'NODE_BBB222');
    expect(packetAtA!.receiverId, 'SH-USERA');
    expect(packetAtA!.receiverNodeId, 'NODE_AAA111');

    await subA.cancel();
    await subB.cancel();
    meshServiceA.dispose();
    meshServiceB.dispose();
    transportA.dispose();
    transportB.dispose();
  });

  test('Identity mapping: resolvePeerUserId and resolvePeerNodeId strictly separate User ID from Node ID', () {
    final mockService = MockService();

    // Known device pairs from SAHARA test directory / test devices
    expect(mockService.resolvePeerUserId('NODE_6829AE'), 'SH-6829');
    expect(mockService.resolvePeerNodeId('SH-6829'), 'NODE_6829AE');

    expect(mockService.resolvePeerUserId('NODE_33D404'), 'SH-33D4');
    expect(mockService.resolvePeerNodeId('SH-33D4'), 'NODE_33D404');

    expect(mockService.resolvePeerUserId('NODE_A01'), 'SH-A01');
    expect(mockService.resolvePeerNodeId('SH-A01'), 'NODE_A01');

    // Local contact IDs resolve to their physical node_id and user_id
    expect(mockService.resolvePeerNodeId('fam_mother'), 'NODE_J10');
    expect(mockService.resolvePeerUserId('fam_mother'), 'SH-J10');

    // User ID directly passed returns itself as user_id
    expect(mockService.resolvePeerUserId('SH-ZJHD'), 'SH-ZJHD');

    // Node ID directly passed returns itself as node_id
    expect(mockService.resolvePeerNodeId('NODE_TEST99'), 'NODE_TEST99');

    // Fallback derivation for arbitrary unknown nodes generates canonical SH-XXXX
    expect(mockService.resolvePeerUserId('NODE_DEADBEEF'), 'SH-DEAD');

    // Learned peer registrations update mappings dynamically
    mockService.registerPeerUserId('NODE_CUSTOM1', 'SH-CUST1');
    expect(mockService.resolvePeerUserId('NODE_CUSTOM1'), 'SH-CUST1');
    expect(mockService.resolvePeerNodeId('SH-CUST1'), 'NODE_CUSTOM1');

    mockService.dispose();
  });

  test('Store and Forward: A -> B while C is unavailable, B buffers packet, forwards upon C connection, flushes buffer, deduplicates, and decrements TTL', () async {
    MockMeshTransport.resetNetwork();

    final transportA = MockMeshTransport(localNodeId: 'NODE_AAA111');
    final transportB = MockMeshTransport(localNodeId: 'NODE_BBB222');
    final transportC = MockMeshTransport(localNodeId: 'NODE_CCC333');

    final meshServiceA = MeshService(
      myNodeId: 'NODE_AAA111',
      myUserId: 'SH-USERA',
      transport: transportA,
    );

    final meshServiceB = MeshService(
      myNodeId: 'NODE_BBB222',
      myUserId: 'SH-USERB',
      transport: transportB,
    );

    final meshServiceC = MeshService(
      myNodeId: 'NODE_CCC333',
      myUserId: 'SH-USERC',
      transport: transportC,
    );

    // Initial state: A connects to B. C is disconnected / unavailable.
    transportA.connectTo('NODE_BBB222');
    await Future.delayed(const Duration(milliseconds: 50));

    expect(meshServiceA.connectedPeers, contains('NODE_BBB222'));
    expect(meshServiceB.connectedPeers, contains('NODE_AAA111'));
    expect(meshServiceB.connectedPeers.contains('NODE_CCC333'), isFalse);
    expect(meshServiceC.connectedPeers.isEmpty, isTrue);

    final receivedMessagesAtC = <MessagePacket>[];
    final subC = meshServiceC.onMessageReceived.listen((packet) {
      receivedMessagesAtC.add(packet);
    });

    // Step 1: A sends a direct TEXT message to C (initial TTL = 8)
    await meshServiceA.sendDirectMessage(
      receiverNodeId: 'NODE_CCC333',
      receiverUserId: 'SH-USERC',
      content: 'Store & Forward Test: Water supplies delivered to Sector 3.',
      ttl: 8,
    );
    await Future.delayed(const Duration(milliseconds: 50));

    // Step 2: C is unreachable, so B must store the message locally in its store-and-forward outbox
    // Node A sent to B with decremented TTL = 7.
    // Node B received at TTL = 7, determined it is a relay for C (not directly connected, no other forward peers),
    // and buffered it with decremented TTL = 6.
    expect(meshServiceB.pendingBuffer.length, 1);
    final bufferedPacket = meshServiceB.pendingBuffer.first;
    expect(bufferedPacket.receiverNodeId, 'NODE_CCC333');
    expect(bufferedPacket.receiverId, 'SH-USERC');
    expect(bufferedPacket.senderNodeId, 'NODE_AAA111');
    expect(bufferedPacket.senderId, 'SH-USERA');
    expect(bufferedPacket.content, 'Store & Forward Test: Water supplies delivered to Sector 3.');
    expect(bufferedPacket.ttl, 6); // TTL decreased on forwarding/relay (8 -> 7 -> 6)

    // C has NOT received anything while unavailable
    expect(receivedMessagesAtC.isEmpty, isTrue);

    // Step 3 & 4: C later becomes reachable (connects to B)
    transportB.connectTo('NODE_CCC333');
    await Future.delayed(const Duration(milliseconds: 50));

    // Stored message must automatically be forwarded to C
    expect(receivedMessagesAtC.length, 1);
    final deliveredToC = receivedMessagesAtC.first;
    expect(deliveredToC.messageId, bufferedPacket.messageId);
    expect(deliveredToC.content, 'Store & Forward Test: Water supplies delivered to Sector 3.');
    expect(deliveredToC.senderId, 'SH-USERA');
    expect(deliveredToC.senderNodeId, 'NODE_AAA111');
    expect(deliveredToC.receiverId, 'SH-USERC');
    expect(deliveredToC.receiverNodeId, 'NODE_CCC333');
    expect(deliveredToC.ttl, 6); // Received with decremented TTL
    expect(deliveredToC.status, MessageStatus.delivered);

    // Step 5: After successful delivery to C, B's stored copy must be removed/flushed
    expect(meshServiceB.pendingBuffer.isEmpty, isTrue);

    // Step 6: Deduplication must prevent duplicate delivery to C
    // If the same packet is re-transmitted across transport, C must drop it
    await transportB.sendRawPacket('NODE_CCC333', deliveredToC.toUtf8Bytes());
    await Future.delayed(const Duration(milliseconds: 50));

    // Count of delivered messages at C remains 1 (no duplicate delivered)
    expect(receivedMessagesAtC.length, 1);

    await subC.cancel();
    meshServiceA.dispose();
    meshServiceB.dispose();
    meshServiceC.dispose();
    transportA.dispose();
    transportB.dispose();
    transportC.dispose();
    MockMeshTransport.resetNetwork();
  });

  test('Store and Forward: Isolated node A buffers locally when 0 peers, flushes upon connecting to B', () async {
    MockMeshTransport.resetNetwork();

    final transportA = MockMeshTransport(localNodeId: 'NODE_AAA111');
    final transportB = MockMeshTransport(localNodeId: 'NODE_BBB222');

    final meshServiceA = MeshService(
      myNodeId: 'NODE_AAA111',
      myUserId: 'SH-USERA',
      transport: transportA,
    );

    final meshServiceB = MeshService(
      myNodeId: 'NODE_BBB222',
      myUserId: 'SH-USERB',
      transport: transportB,
    );

    // Initially A has 0 connected peers
    expect(meshServiceA.connectedPeers.isEmpty, isTrue);

    MessagePacket? packetAtB;
    final subB = meshServiceB.onMessageReceived.listen((p) {
      packetAtB = p;
    });

    // A sends message to B while isolated
    await meshServiceA.sendDirectMessage(
      receiverNodeId: 'NODE_BBB222',
      receiverUserId: 'SH-USERB',
      content: 'Isolated message test',
    );

    // A buffers locally
    expect(meshServiceA.pendingBuffer.length, 1);
    expect(packetAtB, isNull);

    // Later A connects to B
    transportA.connectTo('NODE_BBB222');
    await Future.delayed(const Duration(milliseconds: 50));

    // A automatically flushes to B, removing from buffer
    expect(meshServiceA.pendingBuffer.isEmpty, isTrue);
    expect(packetAtB, isNotNull);
    expect(packetAtB!.content, 'Isolated message test');

    await subB.cancel();
    meshServiceA.dispose();
    meshServiceB.dispose();
    transportA.dispose();
    transportB.dispose();
    MockMeshTransport.resetNetwork();
  });
}

