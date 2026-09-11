import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra/main.dart';
import 'package:sahra/services/mock_service.dart';
import 'package:sahra/utils/date_input_formatter.dart';
import 'package:sahra/widgets/app_logo.dart';
import 'package:sahra/widgets/brand_title.dart';
import 'package:sahra/widgets/person_tile.dart';
import 'package:sahra/widgets/sos_button.dart';

void setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Sahara Home Screen renders key emergency elements in correct hierarchy', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      mockService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // 1. Verify Official Logo & Brand Title (*Sahara*)
    expect(find.byType(AppLogo), findsAtLeastNWidgets(1));
    expect(find.byType(BrandTitle), findsAtLeastNWidgets(1));
    expect(find.text('Sahara'), findsAtLeastNWidgets(1));

    // 2. Subtitle
    expect(find.text('OFFLINE EMERGENCY MESH NETWORK'), findsOneWidget);

    // 3. Compact Mesh Status
    expect(find.text('Mesh Active'), findsOneWidget);
    expect(find.text('${mockService.meshStatus.nearbyCount} nearby'), findsOneWidget);

    // 4. Prominent Circular SOS Button (Standalone, not enclosed in rectangular card)
    expect(find.byType(SosButton), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('EMERGENCY'), findsAtLeastNWidgets(1));

    // 5. Emergency Broadcast feed (Existing announcements visible immediately on Home)
    expect(find.text('EMERGENCY BROADCAST'), findsOneWidget);
    expect(find.text('Cyclone Warning'), findsOneWidget);
    expect(find.text('Flood Evacuation Notice'), findsOneWidget);
    expect(find.text('Send emergency broadcast'), findsOneWidget);

    // 6. Quick Navigation Section
    expect(find.text('COMMUNICATION & CONTACTS'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Nearby'), findsOneWidget);

    // 7. Decentralized footer
    expect(find.text('Decentralized P2P Mesh • Works without cellular coverage'), findsOneWidget);
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
    expect(find.text('Send Emergency SOS?'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    final confirmBtn = find.text('CONFIRM EMERGENCY SOS');
    expect(confirmBtn, findsOneWidget);

    // Confirm SOS
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Should transition to SOS SENT state
    expect(find.text('SOS SENT'), findsOneWidget);
    expect(find.text('Broadcasting'), findsOneWidget);
    expect(find.text('Relays available (4 active)'), findsOneWidget);

    // Cancel SOS
    final cancelBtn = find.text('Cancel SOS Broadcast');
    await tester.ensureVisible(cancelBtn);
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    // Back to confirmation prompt
    expect(find.text('Send Emergency SOS?'), findsOneWidget);
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

    expect(find.text('Family Safety Status'), findsOneWidget);
    expect(find.text('Ping myself to all'), findsOneWidget);

    // Tap collective "Ping myself to all"
    await tester.tap(find.text('Ping myself to all'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify collective feedback
    expect(find.text('Ping sent to all family members'), findsOneWidget);

    // Individual pings should NOT be on family tiles
    expect(find.text('Ping myself to them'), findsNothing);

    // Test Search
    final searchInput = find.widgetWithText(TextField, 'Search family by name or phone...');
    expect(searchInput, findsOneWidget);
    await tester.enterText(searchInput, 'Father');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PersonTile, 'Father'), findsOneWidget);
    expect(find.text('Mother'), findsNothing);
  });

  testWidgets('Nearby screen individual ping, search and Add as family work', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      mockService: mockService,
      initialIsOnboarded: true,
    ));
    await tester.pumpAndSettle();

    // Navigate to Nearby
    final nearbyCard = find.text('Nearby');
    await tester.ensureVisible(nearbyCard);
    await tester.tap(nearbyCard);
    await tester.pumpAndSettle();

    expect(find.text('Nearby Mesh Network'), findsOneWidget);

    // Nearby tiles HAVE individual "Ping myself to them"
    expect(find.text('Ping myself to them'), findsAtLeastNWidgets(1));

    // Tap ping on first peer
    final firstPing = find.text('Ping myself to them').first;
    await tester.tap(firstPing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Ping sent to'), findsOneWidget);

    // Tap "Add as family" on non-family peer
    final addFamilyBtn = find.text('Add as family').first;
    await tester.ensureVisible(addFamilyBtn);
    await tester.tap(addFamilyBtn);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('to Family'), findsOneWidget);
  });

  testWidgets('Emergency Broadcast flow sends broadcast and shows confirmation', (WidgetTester tester) async {
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

    // Tap a template suggestion
    await tester.tap(find.text('Road blocked near Gate 2.'));
    await tester.pumpAndSettle();

    // Tap BROADCAST MESSAGE
    final submitBroadcastBtn = find.widgetWithText(ElevatedButton, 'BROADCAST MESSAGE');
    await tester.ensureVisible(submitBroadcastBtn);
    await tester.tap(submitBroadcastBtn);
    await tester.pumpAndSettle();

    // Verify confirmation state
    expect(find.text('BROADCAST SENT'), findsOneWidget);
    expect(find.text('Recipients reached'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('5-Step First-Launch Onboarding flow in exact approved order', (WidgetTester tester) async {
    setPhoneViewport(tester);
    final mockService = MockService();
    await tester.pumpWidget(SaharaApp(
      mockService: mockService,
      initialIsOnboarded: false,
    ));
    await tester.pumpAndSettle();

    // 1. Welcome Screen (with official logo)
    expect(find.textContaining('Welcome'), findsOneWidget);
    expect(find.byType(AppLogo), findsAtLeastNWidgets(1));
    expect(find.byType(BrandTitle), findsAtLeastNWidgets(1));
    final getStartedBtn = find.widgetWithText(ElevatedButton, 'Get Started');
    expect(getStartedBtn, findsOneWidget);
    await tester.tap(getStartedBtn);
    await tester.pumpAndSettle();

    // 2. Language Selection Screen (Language comes FIRST after Welcome)
    expect(find.text('Select your language'), findsOneWidget);
    expect(find.text('Odia / ଓଡ଼ିଆ'), findsOneWidget);
    expect(find.text('Bengali / বাংলা'), findsOneWidget);
    expect(find.text('Assamese / অসমীয়া'), findsOneWidget);
    expect(find.text('Malayalam / മലയാളം'), findsOneWidget);
    expect(find.text('Gujarati / ગુજરાતી'), findsOneWidget);
    expect(find.text('Maithili / मैथिली'), findsOneWidget);
    expect(find.text('Bodo / बड़ो'), findsOneWidget);
    expect(find.text('Telugu / తెలుగు'), findsOneWidget);

    // Tap Assamese
    await tester.tap(find.text('Assamese / অসমীয়া'));
    await tester.pumpAndSettle();

    final langContinueBtn = find.widgetWithText(ElevatedButton, 'Continue');
    await tester.tap(langContinueBtn);
    await tester.pumpAndSettle();

    // 3. Personal Details Screen (Strict DD/MM/YYYY formatting)
    expect(find.text('Personal Information'), findsOneWidget);
    final textFields = find.byType(TextFormField);
    // Name
    await tester.enterText(textFields.at(0), 'Arun Sharma');
    // Mobile
    await tester.enterText(textFields.at(1), '+91 9876543210');
    // DOB
    await tester.enterText(textFields.at(2), '15/08/1990');
    // Location
    await tester.enterText(textFields.at(3), 'Guwahati Relief Camp 2');
    await tester.pumpAndSettle();

    final detailsContinueBtn = find.widgetWithText(ElevatedButton, 'Continue');
    await tester.ensureVisible(detailsContinueBtn);
    await tester.tap(detailsContinueBtn);
    await tester.pumpAndSettle();

    // 4. Emergency Contacts Screen
    expect(find.text('Emergency Contacts'), findsOneWidget);
    final contactFields = find.byType(TextFormField);
    await tester.enterText(contactFields.at(0), 'Sunita Sharma');
    await tester.enterText(contactFields.at(1), 'Mother');
    await tester.enterText(contactFields.at(2), '+91 9876500001');
    await tester.pumpAndSettle();

    final contactsContinueBtn = find.widgetWithText(ElevatedButton, 'Continue');
    await tester.ensureVisible(contactsContinueBtn);
    await tester.tap(contactsContinueBtn);
    await tester.pumpAndSettle();

    // 5. Completion Screen
    expect(find.text("You're ready."), findsOneWidget);
    expect(find.text('Arun Sharma'), findsOneWidget);
    expect(find.text('Assamese'), findsOneWidget);

    // Tap "Continue to Sahara"
    final finishBtn = find.widgetWithText(ElevatedButton, 'Continue to ');
    await tester.tap(finishBtn);
    await tester.pumpAndSettle();

    // Transitioned to Home Screen
    expect(find.text('OFFLINE EMERGENCY MESH NETWORK'), findsOneWidget);
    expect(find.byType(SosButton), findsOneWidget);
  });

  test('DateInputFormatter strictly validates and formats DD/MM/YYYY', () {
    expect(DateInputFormatter.formatDigits('12052004'), '12/05/2004');
    expect(DateInputFormatter.formatDigits('1205'), '12/05');
    expect(DateInputFormatter.formatDigits('12'), '12');
    expect(DateInputFormatter.isValidDate('12/05/2004'), true);
    expect(DateInputFormatter.isValidDate('31/02/2020'), false); // Invalid Feb 31
    expect(DateInputFormatter.isValidDate('35/10/2020'), false); // Invalid day 35
  });
}
