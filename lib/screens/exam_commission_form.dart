import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam_request.dart';
import '../models/taxonomy.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class ExamCommissionForm extends StatefulWidget {
  const ExamCommissionForm({super.key});

  @override
  State<ExamCommissionForm> createState() => _ExamCommissionFormState();
}

class _ExamCommissionFormState extends State<ExamCommissionForm> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form inputs
  String _section = '';
  String? _selectedDeptId;
  String? _selectedSectionId;
  String? _selectedCourseId;
  DateTime? _adminDeadline;

  int _easyCount = 0;
  int _mediumCount = 0;
  int _hardCount = 0;

  bool _isLoading = false;

  static const primaryBlue = Color(0xFF1D4ED8);
  static const accentBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalQuestions = _easyCount + _mediumCount + _hardCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Commission Exam Paper',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(36.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Initiate Exam Request',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Specify course, section quota, and deadline details. This request will be sent to the Section Committee.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 28),

                        // Department Dropdown
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('departments').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const LinearProgressIndicator();
                            final docs = snapshot.data!.docs;

                            return DropdownButtonFormField<String>(
                              initialValue: _selectedDeptId,
                              decoration: const InputDecoration(
                                labelText: 'Department',
                                prefixIcon: Icon(Icons.business_rounded, color: primaryBlue),
                              ),
                              items: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem(
                                  value: doc.id,
                                  child: Text('${data['code']} - ${data['name']}'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedDeptId = val;
                                  _selectedSectionId = null; // Clear section when dept changes
                                  _selectedCourseId = null; // Clear course when dept changes
                                  _section = ''; // Clear section name when dept changes
                                });
                              },
                              validator: (val) => val == null ? 'Please select a department.' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Section Dropdown (Dependent on selected department)
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('sections').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const LinearProgressIndicator();
                            final docs = snapshot.data!.docs;

                            // Filter sections by selected department
                            final filteredSections = docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['departmentId'] == _selectedDeptId;
                            }).map((doc) => Section.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

                            return DropdownButtonFormField<String>(
                              key: ValueKey(_selectedDeptId),
                              initialValue: _selectedSectionId,
                              decoration: const InputDecoration(
                                labelText: 'Target Section',
                                prefixIcon: Icon(Icons.layers_rounded, color: primaryBlue),
                              ),
                              disabledHint: const Text('Select a department first'),
                              items: _selectedDeptId == null
                                  ? null
                                  : filteredSections.map((sec) {
                                      return DropdownMenuItem(
                                        value: sec.id,
                                        child: Text(sec.name),
                                      );
                                    }).toList(),
                              onChanged: _selectedDeptId == null
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _selectedSectionId = val;
                                        _selectedCourseId = null; // Clear course when section changes
                                        // Retrieve section name for the request
                                        final secDoc = filteredSections.firstWhere((s) => s.id == val);
                                        _section = secDoc.name;
                                      });
                                    },
                              validator: (val) => val == null ? 'Please select a section.' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Course Dropdown (Dependent on selected section)
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('courses').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const LinearProgressIndicator();
                            final docs = snapshot.data!.docs;

                            // Filter courses by selected section
                            final filteredCourses = docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['sectionId'] == _selectedSectionId;
                            }).toList();

                            return DropdownButtonFormField<String>(
                              key: ValueKey(_selectedSectionId),
                              initialValue: _selectedCourseId,
                              decoration: const InputDecoration(
                                labelText: 'Target Course',
                                prefixIcon: Icon(Icons.school_rounded, color: primaryBlue),
                              ),
                              disabledHint: const Text('Select a section first'),
                              items: _selectedSectionId == null
                                  ? null
                                  : filteredCourses.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      return DropdownMenuItem(
                                        value: doc.id,
                                        child: Text('${data['code']} - ${data['name']}'),
                                      );
                                    }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCourseId = val;
                                });
                              },
                              validator: (val) => val == null ? 'Please select a course.' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 28),

                        // Difficulty quota configuration
                        const Text(
                          'Question Quota & Difficulty Distribution',
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFFF8FAFC),
                          ),
                          child: Column(
                            children: [
                              _buildDifficultyCounter('Easy questions', _easyCount, (val) {
                                setState(() => _easyCount = val);
                              }),
                              const Divider(height: 24),
                              _buildDifficultyCounter('Medium questions', _mediumCount, (val) {
                                setState(() => _mediumCount = val);
                              }),
                              const Divider(height: 24),
                              _buildDifficultyCounter('Hard questions', _hardCount, (val) {
                                setState(() => _hardCount = val);
                              }),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Required Questions',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 14),
                                  ),
                                  Text(
                                    '$totalQuestions',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: accentBlue, fontSize: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Deadline datepicker
                        const Text(
                          'Admin Approval Deadline',
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _selectDeadline,
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: Text(
                            _adminDeadline == null
                                ? 'Pick Approval Deadline'
                                : 'Deadline: ${_adminDeadline!.toLocal().toString().split(' ')[0]}',
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Submit action
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Commission Exam Request',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildDifficultyCounter(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 32),
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryBlue),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: accentBlue),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        )
      ],
    );
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(days: 2)), // Deadline must be in the future
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _adminDeadline = picked;
      });
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final totalQuestions = _easyCount + _mediumCount + _hardCount;
    if (totalQuestions <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question to the quota.')),
      );
      return;
    }

    if (_adminDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an approval deadline.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUid = AuthService().currentUser?.uid ?? 'unknown_admin';

      final docRef = _firestore.collection('exam_requests').doc();
      final examReq = ExamRequest(
        id: docRef.id,
        section: _section,
        departmentId: _selectedDeptId!,
        courseId: _selectedCourseId!,
        questionCount: totalQuestions,
        difficultyDistribution: {
          'easy': _easyCount,
          'medium': _mediumCount,
          'hard': _hardCount,
        },
        adminDeadline: _adminDeadline!,
        status: ExamRequestStatus.commissioned,
        createdByUid: currentUid,
        createdAt: DateTime.now(),
      );

      await docRef.set(examReq.toMap());

      // Send notifications to course committee leads and members
      try {
        final courseDoc = await _firestore.collection('courses').doc(_selectedCourseId).get();
        final courseData = courseDoc.data();
        final courseCode = courseData?['code'] ?? _selectedCourseId;
        final courseName = courseData?['name'] ?? '';

        await NotificationService().sendNotificationToCourseRole(
          courseId: _selectedCourseId!,
          targetRoles: ['committee_lead', 'committee_member'],
          title: 'New Exam Request',
          message: 'A new exam request for $courseCode - $courseName (Section $_section) has been commissioned.',
          type: 'exam_commissioned',
          relatedRequestId: docRef.id,
        );
      } catch (e) {
        // Safe fallback for notification failures
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam Request successfully commissioned!')),
        );
        Navigator.pop(context); // Go back after success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to commission request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
