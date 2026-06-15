// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void downloadPdf(String base64Data, String fileName) {
  final rawData = base64Data.replaceAll('\n', '').replaceAll('\r', '').trim();
  final href = 'data:application/pdf;base64,$rawData';
  html.AnchorElement(href: href)
    ..setAttribute('download', fileName)
    ..click();
}
