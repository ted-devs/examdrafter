import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/question.dart';

class PdfGeneratorService {
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

  static Future<Map<String, String>> generateLocalPdfs({
    required Map<String, dynamic> courseInfo,
    required Map<String, dynamic> requestInfo,
    required List<Question> questions,
    required bool generateTwoSets,
    String? logoBase64,
  }) async {
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
      'setBPdf': ?setBPdfBase64,
    };
  }

  static Future<List<int>> _generateSingleSetPdf({
    required Map<String, dynamic> courseInfo,
    required Map<String, dynamic> requestInfo,
    required List<Question> questions,
    required String setName,
    String? logoBase64,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(logoBase64.trim().replaceAll('\n', '').replaceAll('\r', ''));
        logoImage = pw.MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error decoding logo base64: $e');
      }
    }

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
                    pw.Text('Course: ${courseInfo['code'] ?? ''} - ${courseInfo['name'] ?? ''}',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text('Section: ${requestInfo['section'] ?? ''}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Term: ${requestInfo['semester'] ?? 'N/A'} ${requestInfo['year'] ?? 'N/A'}',
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
                            text: q.questionText,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    ...q.options.asMap().entries.map((optEntry) {
                      final oIdx = optEntry.key;
                      final option = optEntry.value;
                      final optionPrefix = String.fromCharCode(65 + oIdx); // A, B, C, D, E
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 15, bottom: 4),
                        child: pw.Text(
                          '$optionPrefix) ${option.text}',
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
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    'Question ${index + 1}:  [ $correctOptionLetter ]  -  (Topic: ${q.topics.join(', ')})',
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
