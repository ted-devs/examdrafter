import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/question.dart';

class PdfGeneratorService {
  static pw.Font? _cachedRegularFont;
  static pw.Font? _cachedBoldFont;

  static Future<void> _loadFonts() async {
    if (_cachedRegularFont != null && _cachedBoldFont != null) return;
    try {
      final regularUri = Uri.parse('https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Regular.ttf');
      final boldUri = Uri.parse('https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Bold.ttf');
      
      final regularData = await NetworkAssetBundle(Uri.parse('')).load(regularUri.toString());
      final boldData = await NetworkAssetBundle(Uri.parse('')).load(boldUri.toString());
      
      _cachedRegularFont = pw.Font.ttf(regularData);
      _cachedBoldFont = pw.Font.ttf(boldData);
    } catch (e) {
      debugPrint('Failed to load online Unicode fonts: $e. Falling back to default PDF fonts.');
    }
  }

  // Fisher-Yates shuffle
  static List<T> _shuffle<T>(List<T> list) {
    final random = Random();
    final result = List<T>.from(list);
    for (int i = result.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }

  static Future<Map<String, String?>> generateLocalPdfs({
    required Map<String, dynamic> courseInfo,
    required Map<String, dynamic> requestInfo,
    required List<Question> questions,
    required bool generateTwoSets,
    String? logoBase64,
  }) async {
    // Load Unicode fonts once before rendering sets
    await _loadFonts();

    // Generate Set A (Standard)
    final setABytes = await _generateSingleSetPdf(
      courseInfo: courseInfo,
      requestInfo: requestInfo,
      questions: questions,
      setName: 'A',
      logoBase64: logoBase64,
    );
    final setAPdfBase64 = base64Encode(setABytes);

    String? setBPdfBase64;
    if (generateTwoSets) {
      // Shuffle questions
      var shuffledQuestions = _shuffle(questions);
      // Shuffle options for each question
      shuffledQuestions = shuffledQuestions.map((q) {
        return Question(
          id: q.id,
          sourceDraftId: q.sourceDraftId,
          version: q.version,
          questionText: q.questionText,
          options: _shuffle(q.options),
          topics: q.topics,
          difficulty: q.difficulty,
          courseId: q.courseId,
          authorUid: q.authorUid,
          status: q.status,
          createdAt: q.createdAt,
          updatedAt: q.updatedAt,
        );
      }).toList();

      final setBBytes = await _generateSingleSetPdf(
        courseInfo: courseInfo,
        requestInfo: requestInfo,
        questions: shuffledQuestions,
        setName: 'B',
        logoBase64: logoBase64,
      );
      setBPdfBase64 = base64Encode(setBBytes);
    }

    return {
      'setAPdf': setAPdfBase64,
      'setBPdf': setBPdfBase64,
    };
  }

  static String _sanitizeText(String text) {
    return text
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('\u2013', '-') // en dash
        .replaceAll('\u2014', '-') // em dash
        .replaceAll('\u2018', "'") // left single quote
        .replaceAll('\u2019', "'") // right single quote
        .replaceAll('\u201c', '"') // left double quote
        .replaceAll('\u201d', '"') // right double quote
        .replaceAll('\u00a0', ' ') // non-breaking space
        .replaceAll('\u200b', ''); // zero-width space
  }

  static Future<List<int>> _generateSingleSetPdf({
    required Map<String, dynamic> courseInfo,
    required Map<String, dynamic> requestInfo,
    required List<Question> questions,
    required String setName,
    String? logoBase64,
  }) async {
    pw.ThemeData? theme;
    if (_cachedRegularFont != null) {
      theme = pw.ThemeData.withFont(
        base: _cachedRegularFont!,
        bold: _cachedBoldFont,
      );
    }
    final pdf = pw.Document(theme: theme);

    pw.MemoryImage? logoImage;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(logoBase64.trim().replaceAll('\n', '').replaceAll('\r', ''));
        logoImage = pw.MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error decoding logo base64: $e');
      }
    }

    final String courseCode = _sanitizeText(courseInfo['code'] ?? '');
    final String courseName = _sanitizeText(courseInfo['name'] ?? '');
    final String section = _sanitizeText(requestInfo['section'] ?? '');
    final String semester = _sanitizeText(requestInfo['semester'] ?? 'N/A');
    final String year = _sanitizeText(requestInfo['year'] ?? 'N/A');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Image(logoImage, width: 50, height: 50),
                  pw.SizedBox(width: 15),
                ],
                pw.Column(
                  children: [
                    pw.Text(
                      'INSTITUTIONAL EXAM PAPER',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Set $setName',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Metadata Grid
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Course: $courseCode - $courseName',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text('Section: $section',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Term: $semester $year',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text('Time Allowed: 2 Hours', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey300, thickness: 1),
            pw.SizedBox(height: 15),

            // Questions
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final q = entry.value;
              final String qText = _sanitizeText(q.questionText);

              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 15),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'Q${index + 1}. ',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                          pw.TextSpan(
                            text: qText,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    ...q.options.asMap().entries.map((optEntry) {
                      final oIdx = optEntry.key;
                      final option = optEntry.value;
                      final String oText = _sanitizeText(option.text);
                      final optionPrefix = String.fromCharCode(65 + oIdx); // A, B, C, D, E
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 15, bottom: 4),
                        child: pw.Text(
                          '$optionPrefix) $oText',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    // Answer Key Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Set $setName - ANSWER KEY',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              ...questions.asMap().entries.map((entry) {
                final index = entry.key;
                final q = entry.value;
                final correctIdx = q.options.indexWhere((opt) => opt.isCorrect);
                final correctOptionLetter = correctIdx != -1 ? String.fromCharCode(65 + correctIdx) : 'N/A';
                final String topicsText = _sanitizeText(q.topics.join(', '));
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    'Question ${index + 1}:  [ $correctOptionLetter ]  -  (Topic: $topicsText)',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
