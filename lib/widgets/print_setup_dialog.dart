import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../services/pdf_generation_service.dart';

class PrintSetupDialog extends StatefulWidget {
  final String examId;
  final String? existingLogoUrl;
  final void Function(Map<String, String> pdfUrls) onComplete;

  const PrintSetupDialog({
    super.key,
    required this.examId,
    required this.onComplete,
    this.existingLogoUrl,
  });

  @override
  State<PrintSetupDialog> createState() => _PrintSetupDialogState();
}

class _PrintSetupDialogState extends State<PrintSetupDialog> {
  final _storageService = StorageService();
  final _pdfService = PdfGenerationService();

  bool _isLoading = false;
  String? _error;
  Uint8List? _logoBytes;
  String _logoExtension = 'png';
  List<String> _selectedSets = ['A'];
  bool _useExisting = true;

  @override
  void initState() {
    super.initState();
    _useExisting = widget.existingLogoUrl != null;
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _logoBytes = file.bytes;
      _logoExtension = file.extension ?? 'png';
      _useExisting = false;
    });
  }

  Future<void> _generate() async {
    if (_selectedSets.isEmpty) {
      setState(() => _error = 'Select at least one set.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? logoUrl = widget.existingLogoUrl;

      if (_logoBytes != null) {
        logoUrl = await _storageService.uploadLogo(
          widget.examId,
          _logoBytes!,
          _logoExtension,
        );
      }

      final urls = await _pdfService.generatePdf(
        examId: widget.examId,
        sets: _selectedSets,
        logoUrl: logoUrl,
      );

      if (mounted) widget.onComplete(urls);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1E3A8A);

    return AlertDialog(
      title: const Text('Print Setup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Institution Logo', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (widget.existingLogoUrl != null && _useExisting)
              Row(
                children: [
                  Image.network(
                    widget.existingLogoUrl!,
                    height: 48,
                    errorBuilder: (_, _, _) => const Icon(Icons.image),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _useExisting = false),
                    child: const Text('Replace'),
                  ),
                ],
              )
            else if (_logoBytes != null)
              Row(
                children: [
                  Image.memory(_logoBytes!, height: 48),
                  const SizedBox(width: 8),
                  const Text('Logo selected', style: TextStyle(color: Colors.green)),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Logo (PNG/JPG)'),
              ),
            const SizedBox(height: 20),
            const Text('Generate', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Set A (original order)'),
              value: _selectedSets.contains('A'),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSets.add('A');
                  } else {
                    _selectedSets.remove('A');
                  }
                });
              },
              activeColor: primaryBlue,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Set B (shuffled)'),
              value: _selectedSets.contains('B'),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSets.add('B');
                  } else {
                    _selectedSets.remove('B');
                  }
                });
              },
              activeColor: primaryBlue,
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _generate,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Generate PDF'),
        ),
      ],
    );
  }
}
