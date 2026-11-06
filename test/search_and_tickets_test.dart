import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitpulse_mobile/screens/search_screen.dart';

void main() {
  testWidgets('HighlightText marca en negritas lo que viene entre <em>', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: HighlightText('Ruta por el <em>parque</em> &amp; más', style: TextStyle(fontSize: 14))),
    ));
    final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final parts = rich.children!.cast<TextSpan>();
    expect(parts.map((s) => s.text).join(), 'Ruta por el parque & más');
    final marked = parts.firstWhere((s) => s.text == 'parque');
    expect(marked.style?.fontWeight, FontWeight.w800);
  });
}
