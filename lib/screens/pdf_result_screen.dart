import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfResultScreen extends StatelessWidget {
  final Map<String, String> pdfUrls;

  const PdfResultScreen({super.key, required this.pdfUrls});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1E3A8A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated PDFs'),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text(
                'PDFs Generated Successfully',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              if (pdfUrls.containsKey('setA'))
                _DownloadButton(
                  label: 'Download Set A',
                  onTap: () => _openUrl(pdfUrls['setA']!),
                ),
              if (pdfUrls.containsKey('setB')) ...[
                const SizedBox(height: 16),
                _DownloadButton(
                  label: 'Download Set B',
                  onTap: () => _openUrl(pdfUrls['setB']!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DownloadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.download_rounded),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
