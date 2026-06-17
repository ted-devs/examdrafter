// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('Test decoding and rendering of preset logos in PDF document', () async {
    const String presetBlueLogoBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    
    try {
      final bytes = base64Decode(presetBlueLogoBase64);
      final pdf = pw.Document();
      final logoImage = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          build: (context) {
            return pw.Center(
              child: pw.Image(logoImage, width: 50, height: 50),
            );
          },
        ),
      );
      final pdfBytes = await pdf.save();
      print('PDF generated successfully with blue logo. Bytes length: ${pdfBytes.length}');
    } catch (e) {
      print('Error generated: $e');
      fail('Failed: $e');
    }
  });
}
