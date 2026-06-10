import 'package:flutter/material.dart';

import '../models/question_draft.dart';
import '../services/draft_service.dart';

class QuestionDraftingPage extends StatefulWidget {
  const QuestionDraftingPage({super.key});

  @override
  State<QuestionDraftingPage> createState() => _QuestionDraftingPageState();
}

class _QuestionDraftingPageState extends State<QuestionDraftingPage> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _topicController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  int _correctIndex = 0;
  String _difficulty = 'Medium';

  @override
  void dispose() {
    _questionController.dispose();
    _topicController.dispose();
    for (final c in _optionControllers) c.dispose();
    super.dispose();
  }

  void _saveDraft({bool showFeedback = true}) {
    if (!_formKey.currentState!.validate()) return;
    final options = List<Option>.generate(
      _optionControllers.length,
      (i) => Option(
        text: _optionControllers[i].text.trim(),
        isCorrect: i == _correctIndex,
      ),
    );
    final draft = QuestionDraft(
      teacherId: 'local_teacher',
      questionText: _questionController.text.trim(),
      options: options,
      topics: _topicController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      difficulty: _difficulty,
    );
    DraftService().saveDraft(draft);
    if (mounted) {
      setState(() {});
      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Draft saved')));
      }
    }
  }

  void _submitDraft() {
    _saveDraft(showFeedback: false);
    final last = DraftService().drafts.last;
    DraftService().submitDraft(last.id!);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft submitted to review pool')),
      );
      Navigator.of(context).pop();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'submitted':
        return const Color(0xFFF59E0B);
      case 'in_review':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.blueGrey.shade600),
        ),
      ],
    );
  }

  Widget _helperCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
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

  @override
  Widget build(BuildContext context) {
    final service = DraftService();
    final recentDrafts = service.recentDrafts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Drafting'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                label: Text('${service.drafts.length} drafts'),
                backgroundColor: const Color(0xFFDBEAFE),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 1000;

            final formCard = Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle(
                        'Draft a new MCQ',
                        'Write a question that is clear, balanced, and easy to review.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _questionController,
                        decoration: const InputDecoration(
                          labelText: 'Question text',
                          prefixIcon: Icon(Icons.quiz_rounded),
                        ),
                        maxLines: 4,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter question text'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Options',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose the correct answer using the selector on the left.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_optionControllers.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: i == _correctIndex
                                  ? const Color(0xFFF8FAFC)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Radio<int>(
                                  value: i,
                                  groupValue: _correctIndex,
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _correctIndex = v);
                                    }
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _optionControllers[i],
                                    decoration: InputDecoration(
                                      labelText: 'Option ${i + 1}',
                                      prefixIcon: const Icon(
                                        Icons.short_text_rounded,
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Enter option text'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _topicController,
                        decoration: const InputDecoration(
                          labelText: 'Topics (comma separated)',
                          prefixIcon: Icon(Icons.local_offer_rounded),
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        value: _difficulty,
                        items: const ['Easy', 'Medium', 'Hard']
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _difficulty = v ?? 'Medium'),
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                          prefixIcon: Icon(Icons.bar_chart_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saveDraft,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Save draft'),
                          ),
                          FilledButton.icon(
                            onPressed: _submitDraft,
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Submit to review pool'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );

            final helperColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _helperCard(
                  icon: Icons.lightbulb_rounded,
                  title: 'Writing tip',
                  body:
                      'Keep the stem concise, avoid double negatives, and make distractors plausible.',
                ),
                const SizedBox(height: 16),
                _helperCard(
                  icon: Icons.rule_rounded,
                  title: 'Review checklist',
                  body:
                      'Check topic alignment, difficulty, and that exactly one option is correct.',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent drafts',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        if (recentDrafts.isEmpty)
                          Text(
                            'No drafts saved yet.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.blueGrey.shade600),
                          )
                        else
                          ...recentDrafts.map(
                            (draft) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            draft.questionText,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(
                                            draft.status.toUpperCase(),
                                          ),
                                          backgroundColor: _statusColor(
                                            draft.status,
                                          ).withValues(alpha: 0.12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Chip(label: Text(draft.difficulty)),
                                        Chip(
                                          label: Text(
                                            '${draft.options.length} options',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: formCard),
                  const SizedBox(width: 20),
                  SizedBox(width: 360, child: helperColumn),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: const Color(0xFF1D4ED8),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teacher drafting workspace',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create strong MCQs, submit them for committee review, and keep your recent drafts visible.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                formCard,
                const SizedBox(height: 16),
                helperColumn,
              ],
            );
          },
        ),
      ),
    );
  }
}
