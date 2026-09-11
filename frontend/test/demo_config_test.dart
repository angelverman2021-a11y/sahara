import 'package:flutter_test/flutter_test.dart';
import 'package:sahra/config/demo_config.dart';
import 'package:sahra/models/person.dart';

void main() {
  group('DemoConfig verification', () {
    test('showDemoData is enabled for presentation mode', () {
      expect(DemoConfig.showDemoData, isTrue);
    });

    test('Demo nearby people contains required sample users', () {
      final nearby = DemoConfig.demoNearbyPeople;
      expect(nearby.length, 4);

      final names = nearby.map((p) => p.name).toList();
      expect(names, contains('Aarav Mehta'));
      expect(names, contains('Ananya Sharma'));
      expect(names, contains('Rohan Verma'));
      expect(names, contains('Priya Nair'));

      for (final person in nearby) {
        expect(person.isDemo, isTrue);
        expect(person.id.startsWith('demo_'), isTrue);
        expect(person.relation, isNot(PersonRelation.family));
      }
    });

    test('Demo family members contains sample family contacts', () {
      final family = DemoConfig.demoFamilyMembers;
      expect(family.length, 3);

      for (final member in family) {
        expect(member.isDemo, isTrue);
        expect(member.id.startsWith('demo_'), isTrue);
        expect(member.relation, equals(PersonRelation.family));
      }
    });

    test('No ID collisions between demo nearby and demo family', () {
      final allIds = [
        ...DemoConfig.demoNearbyPeople.map((p) => p.id),
        ...DemoConfig.demoFamilyMembers.map((p) => p.id),
      ];
      final uniqueIds = allIds.toSet();
      expect(allIds.length, equals(uniqueIds.length));
    });
  });
}
