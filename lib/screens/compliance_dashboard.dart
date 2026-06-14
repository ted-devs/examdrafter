import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam_request.dart';
import '../models/exam_curation.dart';
import '../models/user_profile.dart';
import '../models/extension_request.dart';
import '../services/auth_service.dart';

class ComplianceDashboard extends StatefulWidget {
  const ComplianceDashboard({super.key});

  @override
  State<ComplianceDashboard> createState() => _ComplianceDashboardState();
}

class _ComplianceDashboardState extends State<ComplianceDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  UserProfile? _currentUserProfile;
  bool _isLoadingProfile = true;

  ExamRequest? _selectedRequest;
  ExamCuration? _selectedCuration;
  List<UserProfile> _courseTeachers = [];

  bool _isActionSubmitting = false;

  static const Color primaryBlue = Color(0xFF1D4ED8);
  static const Color lightBlueBg = Color(0xFFEFF6FF);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _currentUserProfile = UserProfile.fromMap(doc.data()!, doc.id);
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user profile: $e')),
        );
      }
    }
  }

  Future<void> _loadTeachersForCourse(String courseId) async {
    setState(() {
      _courseTeachers = [];
    });

    try {
      final snap = await _firestore.collection('users').get();
      final teachers = snap.docs
          .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
          .where((user) => user.roles['course_$courseId'] == 'teacher')
          .toList();

      if (mounted) {
        setState(() {
          _courseTeachers = teachers;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load course teachers: $e')),
        );
      }
    }
  }

  bool _isAuthorizedForRequest(ExamRequest req) {
    if (_currentUserProfile == null) return false;
    if (_currentUserProfile!.hasGlobalRole('super_admin') || _currentUserProfile!.hasGlobalRole('admin')) {
      return true;
    }
    final role = _currentUserProfile!.roles['course_${req.courseId}'];
    return role == 'committee_lead' || role == 'committee_member';
  }

  Future<void> _selectRequest(ExamRequest req) async {
    setState(() {
      _selectedRequest = req;
      _selectedCuration = null;
    });

    _loadTeachersForCourse(req.courseId);

    try {
      final curationSnap = await _firestore.collection('curations').doc(req.id).get();
      if (curationSnap.exists && mounted && _selectedRequest?.id == req.id) {
        setState(() {
          _selectedCuration = ExamCuration.fromMap(curationSnap.data()!, curationSnap.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load curation data: $e')),
        );
      }
    }
  }

  Future<int> _fetchTeacherDraftedCount(String teacherUid, String courseId) async {
    try {
      final snap = await _firestore
          .collection('questions')
          .where('authorUid', isEqualTo: teacherUid)
          .where('courseId', isEqualTo: courseId)
          .get();
      return snap.docs.length;
    } catch (e) {
      debugPrint('Error fetching teacher drafted count: $e');
      return 0;
    }
  }

  Future<void> _showReassignQuotaDialog(TeacherDelegation delegation, int currentDrafted) async {
    if (_selectedRequest == null || _selectedCuration == null) return;

    final remainingQuota = delegation.questionCount - currentDrafted;
    if (remainingQuota <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This teacher has already completed their quota assignment.')),
      );
      return;
    }

    String? targetTeacherUid;
    int reassignCount = remainingQuota;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final otherTeachers = _courseTeachers.where((t) => t.uid != delegation.teacherUid).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Reassign Quota', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Reassign remaining uncompleted quota ($remainingQuota questions) from the non-compliant teacher to another course teacher.',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (otherTeachers.isEmpty)
                    const Text(
                      'No other teachers found for this course to reassign quota to.',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Reassign to Teacher'),
                      items: otherTeachers.map((t) {
                        return DropdownMenuItem(
                          value: t.uid,
                          child: Text(t.displayName ?? t.email),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => targetTeacherUid = val),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reassigned Count:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: reassignCount > 1 ? () => setDialogState(() => reassignCount--) : null,
                            ),
                            Text('$reassignCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: reassignCount < remainingQuota ? () => setDialogState(() => reassignCount++) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: targetTeacherUid == null ? null : () => Navigator.pop(context, true),
                  child: const Text('Reassign'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && targetTeacherUid != null && mounted) {
      setState(() => _isActionSubmitting = true);

      try {
        final batch = _firestore.batch();

        // 1. Update teacher delegations in curation
        final List<TeacherDelegation> newDelegations = [];
        bool targetFound = false;

        for (final del in _selectedCuration!.teacherDelegations) {
          if (del.teacherUid == delegation.teacherUid) {
            // Decrement quota
            newDelegations.add(TeacherDelegation(
              teacherUid: del.teacherUid,
              courseId: del.courseId,
              questionCount: del.questionCount - reassignCount,
            ));
          } else if (del.teacherUid == targetTeacherUid) {
            // Increment quota
            targetFound = true;
            newDelegations.add(TeacherDelegation(
              teacherUid: del.teacherUid,
              courseId: del.courseId,
              questionCount: del.questionCount + reassignCount,
            ));
          } else {
            newDelegations.add(del);
          }
        }

        if (!targetFound) {
          // Add new delegation for target teacher
          newDelegations.add(TeacherDelegation(
            teacherUid: targetTeacherUid!,
            courseId: delegation.courseId,
            questionCount: reassignCount,
          ));
        }

        // Filter out delegations with 0 quota
        final filteredDelegations = newDelegations.where((d) => d.questionCount > 0).toList();

        final curationRef = _firestore.collection('curations').doc(_selectedRequest!.id);
        batch.update(curationRef, {
          'teacherDelegations': filteredDelegations.map((d) => d.toMap()).toList(),
        });

        // 2. Add System Notification
        final notifyRef = _firestore.collection('notifications').doc();
        final targetTeacher = _courseTeachers.firstWhere((t) => t.uid == targetTeacherUid);
        final sourceTeacher = _courseTeachers.firstWhere((t) => t.uid == delegation.teacherUid);
        batch.set(notifyRef, {
          'title': 'Quota Reassigned',
          'message': '$reassignCount questions quota shifted from ${sourceTeacher.displayName ?? sourceTeacher.email} to ${targetTeacher.displayName ?? targetTeacher.email} for course ${_selectedRequest!.courseId}.',
          'type': 'quota_reassigned',
          'relatedRequestId': _selectedRequest!.id,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teacher quota successfully reassigned.')),
          );
          // Reload curation
          _selectRequest(_selectedRequest!);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reassign quota: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isActionSubmitting = false);
        }
      }
    }
  }

  Future<void> _showRequestExtensionDialog() async {
    if (_selectedRequest == null) return;

    DateTime? selectedDate;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Request Extension', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Submit an extension request to the Admin for a revised drafting deadline.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 2)),
                        firstDate: DateTime.now(),
                        lastDate: _selectedRequest!.adminDeadline,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(
                      selectedDate == null
                          ? 'Select Requested Date'
                          : 'Requested Date: ${selectedDate!.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Extension',
                      hintText: 'Explain why the extra timeline is required...',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedDate == null ? null : () => Navigator.pop(context, true),
                  child: const Text('Submit Request'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && selectedDate != null && mounted) {
      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A reason is required to submit an extension request.')),
        );
        return;
      }

      setState(() => _isActionSubmitting = true);

      try {
        final batch = _firestore.batch();
        final extRef = _firestore.collection('extension_requests').doc();
        final notifyRef = _firestore.collection('notifications').doc();

        // 1. Create extension request
        final request = ExtensionRequest(
          id: extRef.id,
          examRequestId: _selectedRequest!.id,
          courseId: _selectedRequest!.courseId,
          requestedByUid: _authService.currentUser?.uid ?? '',
          currentDeadline: _selectedRequest!.internalDeadline ?? DateTime.now(),
          requestedDeadline: selectedDate!,
          reason: reason,
          status: 'pending',
        );
        batch.set(extRef, request.toMap());

        // 2. Create notification
        batch.set(notifyRef, {
          'title': 'Extension Requested',
          'message': 'Extension requested for ${_selectedRequest!.courseId} until ${selectedDate!.toLocal().toString().split(' ')[0]}. Reason: $reason',
          'type': 'extension_request',
          'relatedRequestId': _selectedRequest!.id,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Extension request successfully submitted to Admin.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit extension request: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isActionSubmitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    }

    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Compliance & Exceptions Board',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLargeScreen ? _buildSplitLayout() : _buildSingleLayout(),
    );
  }

  Widget _buildSplitLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 380,
          child: Card(
            margin: const EdgeInsets.only(left: 24, bottom: 24, top: 12),
            child: _buildRequestsList(),
          ),
        ),
        Expanded(
          child: _selectedRequest == null
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 12),
                  child: _buildCurationComplianceDetails(),
                ),
        ),
      ],
    );
  }

  Widget _buildSingleLayout() {
    return _selectedRequest == null
        ? _buildRequestsList(padding: const EdgeInsets.all(24.0))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedRequest = null),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Requests List'),
                ),
                const SizedBox(height: 16),
                _buildCurationComplianceDetails(),
              ],
            ),
          );
  }

  Widget _buildRequestsList({EdgeInsets padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 8)}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('exam_requests')
          .where('status', whereIn: [
            ExamRequestStatus.delegated.toJson(),
            ExamRequestStatus.curating.toJson(),
          ])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryBlue));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoActiveRequestsPlaceholder();
        }

        final docs = snapshot.data!.docs;
        final list = docs
            .map((doc) => ExamRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where(_isAuthorizedForRequest)
            .toList();

        if (list.isEmpty) {
          return _buildNoActiveRequestsPlaceholder();
        }

        return ListView.separated(
          padding: padding,
          itemCount: list.length,
          separatorBuilder: (context, idx) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final req = list[idx];
            final isSelected = _selectedRequest?.id == req.id;

            final isOverdue = req.internalDeadline != null && req.internalDeadline!.isBefore(DateTime.now());

            return ListTile(
              selected: isSelected,
              selectedTileColor: lightBlueBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('courses').doc(req.courseId).get(),
                builder: (context, courseSnapshot) {
                  String courseName = req.courseId;
                  if (courseSnapshot.hasData && courseSnapshot.data!.exists) {
                    final data = courseSnapshot.data!.data() as Map<String, dynamic>?;
                    courseName = '${data?['code'] ?? ''} - ${data?['name'] ?? ''}';
                  }
                  return Text(
                    courseName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  );
                },
              ),
              subtitle: Text(
                'Section: ${req.section}\nDeadline: ${req.internalDeadline?.toLocal().toString().split(' ')[0] ?? 'Not Set'}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: isOverdue
                  ? const Chip(
                      label: Text('OVERDUE', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.redAccent,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                    )
                  : null,
              onTap: () => _selectRequest(req),
            );
          },
        );
      },
    );
  }

  Widget _buildNoActiveRequestsPlaceholder() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No active delegations',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Courses currently being drafted/curated will show here for monitoring.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Select delegated request',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
          ),
          SizedBox(height: 8),
          Text(
            'Select a course delegation to review teacher progress, manage exceptions, and request extensions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCurationComplianceDetails() {
    final req = _selectedRequest!;
    final isDeadlinePassed = req.internalDeadline != null && req.internalDeadline!.isBefore(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delegation Oversight',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: primaryBlue),
                ),
                const SizedBox(height: 16),
                FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('courses').doc(req.courseId).get(),
                  builder: (context, courseSnapshot) {
                    String courseText = req.courseId;
                    if (courseSnapshot.hasData && courseSnapshot.data!.exists) {
                      final data = courseSnapshot.data!.data() as Map<String, dynamic>?;
                      courseText = '${data?['code'] ?? ''} - ${data?['name'] ?? ''}';
                    }
                    return _buildDetailRow('Course', courseText);
                  },
                ),
                _buildDetailRow('Section', req.section),
                _buildDetailRow('Total Quota Needed', '${req.questionCount} questions'),
                _buildDetailRow(
                  'Internal Deadline',
                  req.internalDeadline?.toLocal().toString().split(' ')[0] ?? 'N/A',
                ),
                _buildDetailRow(
                  'Admin Deadline',
                  req.adminDeadline.toLocal().toString().split(' ')[0],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Teacher Quotas & Progress',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            OutlinedButton.icon(
              onPressed: _isActionSubmitting ? null : _showRequestExtensionDialog,
              icon: const Icon(Icons.timer_outlined),
              label: const Text('Request Deadline Extension'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_selectedCuration == null)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: primaryBlue)))
        else if (_selectedCuration!.teacherDelegations.isEmpty)
          const Text('No teachers delegated to this curation.', style: TextStyle(color: Colors.grey))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedCuration!.teacherDelegations.length,
            itemBuilder: (context, idx) {
              final del = _selectedCuration!.teacherDelegations[idx];

              return FutureBuilder<int>(
                future: _fetchTeacherDraftedCount(del.teacherUid, req.courseId),
                builder: (context, draftedSnapshot) {
                  final draftedCount = draftedSnapshot.data ?? 0;
                  final isNonCompliant = isDeadlinePassed && draftedCount < del.questionCount;
                  final userTeacher = _courseTeachers.firstWhere(
                    (t) => t.uid == del.teacherUid,
                    orElse: () => UserProfile(
                      uid: del.teacherUid,
                      email: 'teacher@examdrafter.com',
                      displayName: 'Unknown Teacher',
                      createdAt: DateTime.now(),
                      roles: {},
                    ),
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  userTeacher.displayName ?? userTeacher.email,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              if (isNonCompliant)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  child: const Text(
                                    'NON-COMPLIANT',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Quota allocation: ${del.questionCount} questions',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              Text(
                                '$draftedCount / ${del.questionCount} Drafted',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: draftedCount >= del.questionCount ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: del.questionCount > 0 ? (draftedCount / del.questionCount) : 0,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              draftedCount >= del.questionCount ? Colors.green : Colors.orange,
                            ),
                          ),
                          if (isNonCompliant) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _isActionSubmitting
                                      ? null
                                      : () => _showReassignQuotaDialog(del, draftedCount),
                                  icon: const Icon(Icons.published_with_changes_rounded, size: 18),
                                  label: const Text('Reassign Remaining Quota'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
