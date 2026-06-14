import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      'iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gYJDg0uF8Fk9QAAADNJREFUaN7tmzENAAAIA4V/GqaY4G4E9NIETXp3EgUFBQUFBQUFBQUFBQUFBQUFBQUFBYXhAsT5AgJ1C0k0AAAAAElFTkSuQmCC';
  static const String _presetOrangeLogoBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gYJDg0v5RscfgAAADNJREFUaN7tmzENAAAIA4V/GqaY4FEE9NIETXp3EgUFBQUFBQUFBQUFBQUFBQUFBQUFBYXhAsT5AgJ/CwkaAAAAAElFTkSuQmCC';

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

  Future<void> _simulateCustomLogoUpload() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Uploading branding image...';
    });

    await Future.delayed(const Duration(seconds: 1));

    const String mockUploadedGreenLogo =
        'iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gYJDg0x7xK89gAAADNJREFUaN7tmzENAAAIA4V/GqaY4FIE9NIETXp3EgUFBQUFBQUFBQUFBQUFBQUFBQUFBYXhAsT5AgI5CwkdAAAAAElFTkSuQmCC';

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _selectedLogoType = 'custom';
        _customLogoBase64 = mockUploadedGreenLogo;
        _customLogoFileName = 'university_green_logo.png';
        _statusMessage = 'Logo uploaded successfully.';
      });
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
                    onTap: _isProcessing ? null : _simulateCustomLogoUpload,
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
