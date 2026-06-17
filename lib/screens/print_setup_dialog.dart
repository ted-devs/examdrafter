import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../services/pdf_generator_service.dart';
import '../utils/download_helper.dart';
import '../models/question.dart';
import '../models/exam_request.dart';
import '../models/exam_curation.dart';


class PrintSetupDialog extends StatefulWidget {
  final String examRequestId;

  const PrintSetupDialog({
    super.key,
    required this.examRequestId,
  });

  @override
  State<PrintSetupDialog> createState() => _PrintSetupDialogState();
}

class _PrintSetupDialogState extends State<PrintSetupDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _generateTwoSets = true;
  String _selectedLogoType = 'none'; // 'none' | 'preset_blue' | 'preset_orange' | 'custom'
  String? _customLogoBase64;
  String? _customLogoFileName;

  bool _isProcessing = false;
  String _statusMessage = '';

  // Preset solid color logo PNGs (base64)
  static const String _presetBlueLogoBase64 =
      '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';
  static const String _presetOrangeLogoBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAABOASURBVGhQDVoJVFRXtkVgv/1/sjpD5ydpk6zVq1e6k/T6+Z1Ofsbf6W4zdrdmNnGMsUVQQZxHDCAOKCKCIqIMKiAg4oCzOMtUgIpBRAWBokCoiaEKqt5wC9j/3/veffWqMK7Fut737nDOPXufc+55FWAwVMBqtaKiogI2u421Vpvat+n6dJzNivLycvaczlPeK/1y3XitpevRcXabMs/uncfX8Rmvaw0GwwOeK3JReQ2Vvu8D6EO6qMVqYQ8tqlIWi9LnSrH3BuV5eQUdb2Wt2WJWlOTrWCxMCGV+Oax8Xb6eOo/36Xx6CP776lu+H5eP9v3lDuCL0s3NZmVRbiG2iCqctriqDBeKCWM2w1BZqS3OnqvjuFJ8cz6P70f7/GS96+qU0AmrzPfKw8fR5wHaIuriHAb+8OKtVYUVg1lFBbq6utSTt6JSVYb27V12RQmroowCF0U4Oo7ChO5Dx+mV05S10b4vnIa1nBaGCgT4vGTC+Z6c3kJK3ys0FZL27XadMJUGFS7c/GWK0ByGKtbLyuhzbgmzTgkvd/TysFbtaxbScVfjCCeyj8Zq32eyBh8vbKrKrqC79iIa90bAuXcuLHHj0J/4ORwJY+He8R2cSV/CtfUr2OP+gb6t49G+ZRJ6TySi9vgeWNpb1ZNVYGRXHY4/fPVycgQwbjG4GxSL/Kz5+Ilo7+ni5bDbbKg5lQ/HgSh0xf0dwvZvQU6sh6f2JIi5AaLNBMnegd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf4BVp5ce5fh7p2DufQd7rlyB3W9BdfRZyrw1CpxFiZxM8lkZ4bp6CfHQNxB0T0Jf5e1mR';

  static const Color primaryBlue = Color(0xFF1D4ED8);

  String? _getLogoBase64() {
    switch (_selectedLogoType) {
      case 'preset_blue':
        return _presetBlueLogoBase64;
      case 'preset_orange':
        return _presetOrangeLogoBase64;
      case 'custom':
        return _customLogoBase64;
      default:
        return null;
    }
  }

  Future<void> _handleCustomLogoUpload() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Opening file picker...';
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _statusMessage = 'Processing branding image...';
        });

        final file = result.files.first;
        Uint8List? fileBytes = file.bytes;

        if (fileBytes == null && file.path != null && !kIsWeb) {
          final ioFile = io.File(file.path!);
          fileBytes = await ioFile.readAsBytes();
        }

        if (fileBytes != null) {
          final String base64String = base64Encode(fileBytes);
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _selectedLogoType = 'custom';
              _customLogoBase64 = base64String;
              _customLogoFileName = file.name;
              _statusMessage = 'Logo uploaded successfully.';
            });
          }
        } else {
          throw Exception('Could not read file data.');
        }
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Upload failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File pick failed: $e')),
        );
      }
    }
  }

  Future<void> _generatePdfs() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Initiating PDF Generation...';
    });

    final logoBase64 = _getLogoBase64();
    await _generateLocalPdfs(logoBase64);
  }

  Future<void> _generateLocalPdfs(String? logoBase64) async {
    try {
      // 1. Fetch Exam Request
      setState(() => _statusMessage = 'Loading exam request details...');
      final reqSnap = await _firestore.collection('exam_requests').doc(widget.examRequestId).get();
      if (!reqSnap.exists) {
        throw Exception('Exam Request not found in Firestore.');
      }
      final req = ExamRequest.fromMap(reqSnap.data()!, reqSnap.id);

      // 2. Fetch Curation Details
      setState(() => _statusMessage = 'Loading curation question list...');
      final curationSnap = await _firestore.collection('curations').doc(widget.examRequestId).get();
      if (!curationSnap.exists) {
        throw Exception('Exam Curation record not found in Firestore.');
      }
      final curation = ExamCuration.fromMap(curationSnap.data()!, curationSnap.id);
      final List<String> selectedIds = curation.selectedQuestionIds;

      if (selectedIds.isEmpty) {
        throw Exception('No curated questions are present in this request.');
      }

      // 3. Fetch Course details
      setState(() => _statusMessage = 'Fetching course information...');
      final courseSnap = await _firestore.collection('courses').doc(req.courseId).get();
      final Map<String, dynamic> courseInfo = {
        'code': req.courseId,
        'name': 'Unknown Course',
      };
      if (courseSnap.exists) {
        final cData = courseSnap.data()!;
        courseInfo['code'] = cData['code'] ?? req.courseId;
        courseInfo['name'] = cData['name'] ?? 'Unknown Course';
      }

      // 4. Fetch Questions
      setState(() => _statusMessage = 'Loading question contents...');
      final List<Question> fetchedQuestions = [];
      for (final qId in selectedIds) {
        final qSnap = await _firestore.collection('questions').doc(qId).get();
        if (qSnap.exists) {
          fetchedQuestions.add(Question.fromMap(qSnap.data()!, qSnap.id));
        }
      }

      if (fetchedQuestions.isEmpty) {
        throw Exception('Could not fetch any of the curated questions from Firestore.');
      }

      // 5. Generate PDFs
      setState(() => _statusMessage = 'Rendering PDF files locally...');
      final results = await PdfGeneratorService.generateLocalPdfs(
        courseInfo: courseInfo,
        requestInfo: {
          'section': req.section,
          'semester': req.semester,
          'year': req.year,
        },
        questions: fetchedQuestions,
        generateTwoSets: _generateTwoSets,
        logoBase64: logoBase64,
      );

      setState(() => _statusMessage = 'Dispatching files to browser...');
      final String setAPdf = results['setAPdf']!;
      downloadPdf(setAPdf, 'Exam_Set_A.pdf');

      if (_generateTwoSets && results['setBPdf'] != null) {
        final String setBPdf = results['setBPdf']!;
        downloadPdf(setBPdf, 'Exam_Set_B.pdf');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam PDFs generated and downloaded successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Export failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.print_rounded, color: primaryBlue, size: 28),
          SizedBox(width: 12),
          Text(
            'Print Setup & PDF Export',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Configure institutional branding and version options before exporting the final exam paper PDFs.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Set B option
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: primaryBlue,
                title: const Text(
                  'Generate Set B (Shuffled Version)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Randomizes the order of questions and choices to discourage cheating.',
                  style: TextStyle(fontSize: 12),
                ),
                value: _generateTwoSets,
                onChanged: _isProcessing
                    ? null
                    : (val) {
                        setState(() => _generateTwoSets = val);
                      },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Logo Preset Selector
              const Text(
                'Institutional Logo Branding',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LogoOptionCard(
                    title: 'No Logo',
                    icon: Icons.block,
                    isSelected: _selectedLogoType == 'none',
                    onTap: _isProcessing
                        ? null
                        : () => setState(() => _selectedLogoType == 'none'),
                  ),
                  _LogoOptionCard(
                    title: 'Blue Crest',
                    icon: Icons.shield,
                    iconColor: Colors.blue,
                    isSelected: _selectedLogoType == 'preset_blue',
                    onTap: _isProcessing
                        ? null
                        : () => setState(() => _selectedLogoType == 'preset_blue'),
                  ),
                  _LogoOptionCard(
                    title: 'Orange Crest',
                    icon: Icons.military_tech_rounded,
                    iconColor: Colors.orange,
                    isSelected: _selectedLogoType == 'preset_orange',
                    onTap: _isProcessing
                        ? null
                        : () => setState(() => _selectedLogoType == 'preset_orange'),
                  ),
                  _LogoOptionCard(
                    title: _customLogoFileName ?? 'Upload File',
                    icon: Icons.cloud_upload_rounded,
                    iconColor: primaryBlue,
                    isSelected: _selectedLogoType == 'custom',
                    onTap: _isProcessing ? null : _handleCustomLogoUpload,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_isProcessing) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _generatePdfs,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Generate & Download'),
        ),
      ],
    );
  }
}

class _LogoOptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const _LogoOptionCard({
    required this.title,
    required this.icon,
    this.iconColor,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D4ED8) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor ?? (isSelected ? const Color(0xFF1D4ED8) : Colors.grey)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF1D4ED8) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
