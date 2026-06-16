import 'package:flutter/material.dart';

import '../models/question_bank.dart';
import '../services/draft_service.dart';

class ApprovedQuestionsPage extends StatefulWidget {
  const ApprovedQuestionsPage({super.key});

  @override
  State<ApprovedQuestionsPage> createState() => _ApprovedQuestionsPageState();
}

class _ApprovedQuestionsPageState extends State<ApprovedQuestionsPage> {
  final DraftService _service = DraftService();
  bool _isWorking = false;

  Future<void> _createNewVersion(QuestionBankItem item) async {
    if (_isWorking) return;
    final controller = TextEditingController(text: item.questionText);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
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
        await _service.editApprovedQuestion(item.id, newQuestionText: result);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('New version created')));
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

  Color _versionColor(QuestionBankItem item) {
    if (item.errorDoNotUse) {
      return const Color(0xFFEF4444);
    }
    return item.version == 1
        ? const Color(0xFF10B981)
        : const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    final bank = _service.questionBank;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approved Questions'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                label: Text('${bank.length} in bank'),
                backgroundColor: const Color(0xFFDCFCE7),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                            'Approved question library',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This is the immutable archive. Create a new version whenever an approved question needs correction.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _LibraryStat(
                          label: 'Total',
                          value: '${bank.length}',
                          color: const Color(0xFF38BDF8),
                        ),
                        _LibraryStat(
                          label: 'Active',
                          value:
                              '${bank.where((item) => !item.errorDoNotUse).length}',
                          color: const Color(0xFF10B981),
                        ),
                        _LibraryStat(
                          label: 'Archived',
                          value:
                              '${bank.where((item) => item.errorDoNotUse).length}',
                          color: const Color(0xFFEF4444),
                        ),
                      ],
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
                              if (item.errorDoNotUse) ...[
                                const SizedBox(width: 8),
                                const Chip(label: Text('ERROR - DO NOT USE')),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text('Difficulty: ${item.difficulty}'),
                              ),
                              Chip(
                                label: Text(
                                  item.topics.isEmpty
                                      ? 'No topics'
                                      : item.topics.join(', '),
                                ),
                              ),
                              if (item.previousVersionId != null)
                                Chip(
                                  label: Text(
                                    'Prev: ${item.previousVersionId}',
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Options',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ...item.options.map(
                            (option) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    option.isCorrect
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 18,
                                    color: option.isCorrect
                                        ? const Color(0xFF10B981)
                                        : Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(option.text)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _isWorking
                                  ? null
                                  : () => _createNewVersion(item),
                              icon: const Icon(Icons.library_add_rounded),
                              label: const Text('Create new version'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LibraryStat extends StatelessWidget {
  const _LibraryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 34,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovedEmptyState extends StatelessWidget {
  const _ApprovedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.library_books_rounded,
                color: Color(0xFF047857),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No approved questions yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Once a review is approved, it will appear here as a locked library item.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
