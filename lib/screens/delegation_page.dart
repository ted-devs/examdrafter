import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/draft_service.dart';

class DelegationPage extends StatefulWidget {
  const DelegationPage({super.key});

  @override
  State<DelegationPage> createState() => _DelegationPageState();
}

class _DelegationPageState extends State<DelegationPage> {
  final DraftService _service = DraftService();
  final _formKey = GlobalKey<FormState>();
  final _quotaController = TextEditingController(text: '3');
  final _notesController = TextEditingController();

  final List<_TeacherOption> _teachers = const [
    _TeacherOption('teacher_1', 'Dr. Amina'),
    _TeacherOption('teacher_2', 'Mr. Daniel'),
    _TeacherOption('teacher_3', 'Ms. Farah'),
  ];

  final List<_CourseOption> _courses = const [
    _CourseOption('course_math', 'Mathematics'),
    _CourseOption('course_cs', 'Computer Science'),
    _CourseOption('course_bio', 'Biology'),
  ];

  String _selectedTeacherId = 'teacher_1';
  String _selectedCourseId = 'course_math';
  DateTime? _deadline;
  bool _isSaving = false;

  @override
  void dispose() {
    _quotaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (selected != null) {
      setState(() => _deadline = selected);
    }
  }

  Future<void> _assignQuota() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final teacher = _teachers.firstWhere((item) => item.id == _selectedTeacherId);
      final course = _courses.firstWhere((item) => item.id == _selectedCourseId);

      await _service.assignTeacherQuota(
        teacherId: teacher.id,
        teacherName: teacher.name,
        courseId: course.id,
        courseName: course.name,
        quotaCount: int.parse(_quotaController.text.trim()),
        assignedBy: FirebaseAuth.instance.currentUser?.uid ?? 'committee_lead_1',
        deadline: _deadline,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quota assigned')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not assign quota: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'drafting':
        return const Color(0xFF0EA5E9);
      case 'reassigned':
        return const Color(0xFFF97316);
      case 'assigned':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotas = _service.teacherQuotas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delegation & Quotas'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                label: Text('${quotas.length} assignments'),
                backgroundColor: const Color(0xFFDBEAFE),
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
                            'Committee delegation board',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Assign quotas to teachers, set deadlines, and keep the distribution organized.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                        _DelegationStat(label: 'Active', value: '${quotas.where((q) => q.status == 'assigned' || q.status == 'drafting').length}', color: const Color(0xFF38BDF8)),
                        _DelegationStat(label: 'Completed', value: '${quotas.where((q) => q.status == 'completed').length}', color: const Color(0xFF10B981)),
                        _DelegationStat(label: 'Over quota', value: '${quotas.where((q) => q.isOverQuota).length}', color: const Color(0xFFEF4444)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 980;
                final formCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Assign quota', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 16),
                           DropdownButtonFormField<String>(
                            initialValue: _selectedTeacherId,
                            items: _teachers.map((teacher) => DropdownMenuItem(value: teacher.id, child: Text(teacher.name))).toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _selectedTeacherId = value);
                            },
                            decoration: const InputDecoration(labelText: 'Teacher', prefixIcon: Icon(Icons.person_rounded)),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCourseId,
                            items: _courses.map((course) => DropdownMenuItem(value: course.id, child: Text(course.name))).toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _selectedCourseId = value);
                            },
                            decoration: const InputDecoration(labelText: 'Course', prefixIcon: Icon(Icons.menu_book_rounded)),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _quotaController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Quota count', prefixIcon: Icon(Icons.confirmation_number_rounded)),
                            validator: (value) {
                              final parsed = int.tryParse(value ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Enter a valid quota count';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.note_alt_rounded)),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _pickDeadline,
                            icon: const Icon(Icons.date_range_rounded),
                            label: Text(_deadline == null ? 'Pick deadline' : 'Deadline: ${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _assignQuota,
                            icon: const Icon(Icons.assignment_turned_in_rounded),
                            label: Text(_isSaving ? 'Assigning...' : 'Assign quota'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                final listCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current assignments', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        if (quotas.isEmpty)
                          Text('No quotas assigned yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.blueGrey.shade600))
                        else
                          ...quotas.map((quota) {
                            final statusColor = _statusColor(quota.status);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text('${quota.teacherName} • ${quota.courseName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                        ),
                                        Chip(label: Text(quota.status.toUpperCase()), backgroundColor: statusColor.withValues(alpha: 0.12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Chip(label: Text('Quota: ${quota.submittedCount}/${quota.quotaCount}')),
                                        if (quota.deadline != null) Chip(label: Text('Deadline: ${quota.deadline!.toIso8601String().split('T').first}')),
                                        if (quota.notes != null) Chip(label: Text(quota.notes!)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: formCard),
                      const SizedBox(width: 20),
                      Expanded(flex: 3, child: listCard),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    formCard,
                    const SizedBox(height: 16),
                    listCard,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DelegationStat extends StatelessWidget {
  const _DelegationStat({required this.label, required this.value, required this.color});

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
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(width: 34, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
        ],
      ),
    );
  }
}

class _TeacherOption {
  const _TeacherOption(this.id, this.name);
  final String id;
  final String name;
}

class _CourseOption {
  const _CourseOption(this.id, this.name);
  final String id;
  final String name;
}
