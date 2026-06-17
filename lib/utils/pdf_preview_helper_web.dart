// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

void previewPdf(String base64Data, String fileName) {
  try {
    final bytes = base64Decode(base64Data.trim().replaceAll('\n', '').replaceAll('\r', ''));
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  } catch (e) {
    html.window.alert('Failed to preview PDF: $e');
  }
}
