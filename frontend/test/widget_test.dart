import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra/main.dart';
import 'package:sahra/models/announcement.dart';
import 'package:sahra/services/mock_service.dart';
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
      mockService: mockService,
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
    expect(find.textContaining('Peers nearby'), findsOneWidget);

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
      mockService: mockService,
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
      mockService: mockService,
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
    await tester.pumpAndSettle();

    // Verify message is added to UI locally
    expect(find.text('I am safe and reaching the camp now.'), findsOneWidget);
  });

  testWidgets('Family screen collective ping and search work', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      mockService: mockService,
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
    final mockService = MockService();
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

    expect(find.text('Nearby People'), findsAtLeastNWidgets(1));
    expect(find.textContaining('People Discovered in Range'), findsOneWidget);

    // Nearby tiles have individual Ping
    expect(find.text('Ping'), findsAtLeastNWidgets(1));

    // Tap ping on first peer
    final firstPing = find.text('Ping').first;
    await tester.tap(firstPing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Ping sent to'), findsOneWidget);

    // Tap "Add to Family" on non-family peer
    final addFamilyBtn = find.text('Add to Family').first;
    await tester.ensureVisible(addFamilyBtn);
    await tester.tap(addFamilyBtn);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Added'), findsOneWidget);
  });

  testWidgets('Emergency Broadcast flow with severity selector adds immediately to feed', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      mockService: mockService,
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
      mockService: mockService,
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
      mockService: mockService,
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
      mockService: mockService,
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
      mockService: mockService,
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
}

