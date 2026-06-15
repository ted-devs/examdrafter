import 'package:cloud_functions/cloud_functions.dart';

class PdfGenerationService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Map<String, String>> generatePdf({
    required String examId,
    required List<String> sets,
    String? logoUrl,
  }) async {
    final callable = _functions.httpsCallable('generateExamPdf');
    final result = await callable.call({
      'examId': examId,
      'sets': sets,
      'logoUrl': ?logoUrl,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final urlMap = Map<String, dynamic>.from(data['pdfUrls'] as Map);
    return {
      if (urlMap['setA'] != null) 'setA': urlMap['setA'] as String,
      if (urlMap['setB'] != null) 'setB': urlMap['setB'] as String,
    };
  }
}
