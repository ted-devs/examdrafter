import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';
import '../services/draft_service.dart';

class ApprovedQuestionsPage extends StatefulWidget {
  const ApprovedQuestionsPage({super.key});

  @override
  State<ApprovedQuestionsPage> createState() => _ApprovedQuestionsPageState();
}

class _ApprovedQuestionsPageState extends State<ApprovedQuestionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DraftService _draftService = DraftService();
  bool _isWorking = false;

  Future<void> _createNewVersion(Question item) async {
    if (_isWorking) return;
    final controller = TextEditingController(text: item.questionText);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Create new version'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Updated question text',
            prefixIcon: Icon(Icons.edit_note_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _isWorking = true);
      try {
        final newVersion = item.copyWithNewVersion(
          newQuestionText: result,
          newStatus: 'draft',
        );
        await _draftService.saveQuestion(
          question: newVersion,
          submit: false,
          isRevision: true,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('New version created as draft')));
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create new version: $error')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isWorking = false);
        }
      }
    }
  }

  Color _versionColor(Question item) {
    if (item.errorDoNotUse) {
      return const Color(0xFFEF4444);
    }
    return item.version == 1
        ? const Color(0xFF10B981)
        : const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Approved Questions Library',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('questions')
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1D4ED8)));
          }

          final List<Question> bank = snapshot.hasData
              ? snapshot.data!.docs
                  .map((doc) => Question.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                  .where((q) => !q.errorDoNotUse)
                  .toList()
              : [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: const Color(0xFF0F172A),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Approved Question Library',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This is the immutable archive of approved questions. Create a new version whenever an approved question needs correction.',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        _LibraryStat(
                          label: 'Active',
                          value: '${bank.length}',
                          color: const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (bank.isEmpty)
                  const _ApprovedEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bank.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, i) {
                      final item = bank[i];
                      final versionColor = _versionColor(item);

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.questionText,
                                      style: Theme.of(context).textTheme.titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Chip(
                                    label: Text('v${item.version}'),
                                    backgroundColor: versionColor.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: item.options.map((opt) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Icon(
                                          opt.isCorrect
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_off_rounded,
                                          color: opt.isCorrect ? Colors.green : Colors.grey,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            opt.text,
                                            style: TextStyle(
                                              fontWeight: opt.isCorrect ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    children: item.topics.map((t) => Chip(label: Text(t))).toList(),
                                  ),
                                  const Spacer(),
                                  IconButton.filledTonal(
                                    onPressed: () => _createNewVersion(item),
                                    icon: const Icon(Icons.history_rounded),
                                    tooltip: 'Revise approved question',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LibraryStat extends StatelessWidget {
  const _LibraryStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Container(width: 24, height: 4, color: color),
      ],
    );
  }
}

class _ApprovedEmptyState extends StatelessWidget {
  const _ApprovedEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No approved questions in library yet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
