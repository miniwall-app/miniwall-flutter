import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:miniwall_flutter_example/main.dart';

void main() {
  testWidgets('buttons that need a key start disabled', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byKey(const Key('configure-button')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('result-text')), 200, scrollable: find.byType(Scrollable).first); // below the template field, out of the first screen
    expect(find.byKey(const Key('result-text')), findsOneWidget);
  });
}
