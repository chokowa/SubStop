import 'package:flutter_test/flutter_test.dart';
import 'package:substop/main.dart';

void main() {
  testWidgets('SubStopApp builds', (tester) async {
    await tester.pumpWidget(const SubStopApp());
    expect(find.text('SubStop'), findsOneWidget);
  });
}
