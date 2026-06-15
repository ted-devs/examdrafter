import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam_request.dart';
import '../models/exam_curation.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class CommitteeDelegationScreen extends StatefulWidget {
  const CommitteeDelegationScreen({super.key});

  @override
  State<CommitteeDelegationScreen> createState() => _CommitteeDelegationScreenState();
}

class _CommitteeDelegationScreenState extends State<CommitteeDelegationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Logged in user profile
  UserProfile? _currentUserProfile;
  bool _isLoadingProfile = true;

  // Selected exam request and states
  ExamRequest? _selectedRequest;
  DateTime? _internalDeadline;
  List<TeacherDelegation> _delegations = [];

  // Teachers for the selected course
  List<UserProfile> _courseTeachers = [];
  bool _isLoadingTeachers = false;
  String? _selectedTeacherUid;

  // Question counters for delegation form
  int _teacherEasyCount = 0;
  int _teacherMediumCount = 0;
  int _teacherHardCount = 0;

  bool _isSubmitting = false;

  static const primaryBlue = Color(0xFF1D4ED8);
  static const lightBlueBg = Color(0xFFEFF6FF);

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
      _isLoadingTeachers = true;
      _courseTeachers = [];
      _selectedTeacherUid = null;
      _teacherEasyCount = 0;
      _teacherMediumCount = 0;
      _teacherHardCount = 0;
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
          _isLoadingTeachers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load course teachers: $e')),
        );
      }
    }
  }

  // Check if current user is authorized to manage the request
  bool _isAuthorizedForRequest(ExamRequest req) {
    if (_currentUserProfile == null) return false;
    if (_currentUserProfile!.hasGlobalRole('super_admin') || _currentUserProfile!.hasGlobalRole('admin')) {
      return true;
    }
    // Check if user is committee lead or member for this request's course
    final role = _currentUserProfile!.roles['course_${req.courseId}'];
    return role == 'committee_lead' || role == 'committee_member';
  }

  void _selectRequest(ExamRequest req) {
    setState(() {
      _selectedRequest = req;
      _internalDeadline = req.internalDeadline;
      _delegations = [];
    });
    _loadTeachersForCourse(req.courseId);
    _loadExistingCurationIfAny(req.id);
  }

  Future<void> _loadExistingCurationIfAny(String requestId) async {
    try {
      final doc = await _firestore.collection('curations').doc(requestId).get();
      if (doc.exists && mounted && _selectedRequest?.id == requestId) {
        final curation = ExamCuration.fromMap(doc.data()!, doc.id);
        setState(() {
          _delegations = curation.teacherDelegations;
        });
      }
    } catch (_) {
      // Non-fatal, just start with empty delegations list
    }
  }

  void _addTeacherDelegation() {
    if (_selectedTeacherUid == null || _selectedRequest == null) return;

    final existingIndex = _delegations.indexWhere((d) => d.teacherUid == _selectedTeacherUid);
    final count = _teacherEasyCount + _teacherMediumCount + _teacherHardCount;

    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please delegate at least 1 question.')),
      );
      return;
    }

    setState(() {
      final delegation = TeacherDelegation(
        teacherUid: _selectedTeacherUid!,
        courseId: _selectedRequest!.courseId,
        questionCount: count, // Represent total delegated questions count
      );

      if (existingIndex >= 0) {
        _delegations[existingIndex] = delegation;
      } else {
        _delegations.add(delegation);
      }

      // Reset counters
      _selectedTeacherUid = null;
      _teacherEasyCount = 0;
      _teacherMediumCount = 0;
      _teacherHardCount = 0;
    });
  }

  void _removeDelegation(int index) {
    setState(() {
      _delegations.removeAt(index);
    });
  }

  bool _isTimelineValid() {
    if (_selectedRequest == null || _internalDeadline == null) return false;
    final cutoff = _selectedRequest!.adminDeadline.subtract(const Duration(hours: 24));
    return _internalDeadline!.isBefore(cutoff) || _internalDeadline!.isAtSameMomentAs(cutoff);
  }

  // Validate that the total delegated question count matches the requested count
  bool _isDelegationComplete() {
    if (_selectedRequest == null) return false;
    final totalDelegated = _delegations.fold<int>(0, (acc, d) => acc + d.questionCount);
    return totalDelegated == _selectedRequest!.questionCount;
  }

  Future<void> _submitDelegation() async {
    if (_selectedRequest == null || _internalDeadline == null) return;
    if (!_isTimelineValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timeline error: Internal deadline must be at least 24 hours before admin deadline.')),
      );
      return;
    }
    if (!_isDelegationComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quota mismatch: Sum of delegations must match requested questions quota.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final curation = ExamCuration(
        examRequestId: _selectedRequest!.id,
        teacherDelegations: _delegations,
        votes: {},
        selectedQuestionIds: [],
      );

      // Save curation details
      await _firestore.collection('curations').doc(_selectedRequest!.id).set(curation.toMap());

      // Update exam request status
      await _firestore.collection('exam_requests').doc(_selectedRequest!.id).update({
        'status': ExamRequestStatus.delegated.toJson(),
        'internalDeadline': Timestamp.fromDate(_internalDeadline!),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timeline and teacher quotas successfully delegated!')),
        );
        setState(() {
          _selectedRequest = null;
          _internalDeadline = null;
          _delegations = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit delegation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _selectInternalDeadline() async {
    if (_selectedRequest == null) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _internalDeadline ?? DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: _selectedRequest!.adminDeadline,
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
        _internalDeadline = picked;
      });
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
          'Section Committee Delegation',
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
        // Left Column: Pending requests list
        SizedBox(
          width: 380,
          child: Card(
            margin: const EdgeInsets.only(left: 24, bottom: 24, top: 12),
            child: _buildRequestsList(),
          ),
        ),
        // Right Column: Delegation details form
        Expanded(
          child: _selectedRequest == null
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 12),
                  child: _buildDelegationForm(),
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
                  label: const Text('Back to Requests'),
                ),
                const SizedBox(height: 16),
                _buildDelegationForm(),
              ],
            ),
          );
  }

  Widget _buildRequestsList({EdgeInsets padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 8)}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('exam_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryBlue));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoRequestsPlaceholder();
        }

        final docs = snapshot.data!.docs;
        final list = docs
            .map((doc) => ExamRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((req) =>
                _isAuthorizedForRequest(req) &&
                (req.status == ExamRequestStatus.commissioned ||
                    req.status == ExamRequestStatus.returnedForRevision))
            .toList();

        if (list.isEmpty) {
          return _buildNoRequestsPlaceholder();
        }

        return ListView.separated(
          padding: padding,
          itemCount: list.length,
          separatorBuilder: (context, idx) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final req = list[idx];
            final isSelected = _selectedRequest?.id == req.id;

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
                'Section: ${req.section}\nQuota: ${req.questionCount} questions',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: req.status == ExamRequestStatus.returnedForRevision
                  ? const Chip(
                      label: Text('REVISION', style: TextStyle(fontSize: 10, color: Colors.white)),
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

  Widget _buildNoRequestsPlaceholder() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No pending exam requests',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Requests commissioned by Admins will appear here for quota delegation.',
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
          Icon(Icons.arrow_back_rounded, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Select an exam request',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
          ),
          SizedBox(height: 8),
          Text(
            'Choose a pending request from the left list to configure timelines and split quotas.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDelegationForm() {
    final req = _selectedRequest!;
    final totalDelegated = _delegations.fold<int>(0, (acc, d) => acc + d.questionCount);
    final quotaMatches = totalDelegated == req.questionCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: Details
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request Details',
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
                _buildDetailRow('Required Quota', '${req.questionCount} Questions'),
                _buildDetailRow(
                  'Admin Deadline',
                  '${req.adminDeadline.toLocal().toString().split(' ')[0]} (Verification cutoff)',
                ),
                if (req.revisionNotes != null && req.revisionNotes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Admin Revision Notes',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          req.revisionNotes!,
                          style: TextStyle(color: Colors.red[900], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Card 2: Timeline configuration
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teacher Drafting Timeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryBlue),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the internal deadline for teachers. Must be at least 24 hours prior to the Admin Deadline.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _selectInternalDeadline,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(
                    _internalDeadline == null
                        ? 'Set Teacher Deadline'
                        : 'Teacher Deadline: ${_internalDeadline!.toLocal().toString().split(' ')[0]}',
                  ),
                ),
                if (_internalDeadline != null && !_isTimelineValid()) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Error: Timeline must end at least 24 hours before the Admin Deadline.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Card 3: Delegate to Teachers
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delegate Quotas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryBlue),
                ),
                const SizedBox(height: 16),
                if (_isLoadingTeachers)
                  const Center(child: LinearProgressIndicator())
                else if (_courseTeachers.isEmpty)
                  const Text(
                    'No teachers registered for this course. Please assign teachers in User Role Management first.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTeacherUid,
                    decoration: const InputDecoration(labelText: 'Select Teacher'),
                    items: _courseTeachers.map((t) {
                      return DropdownMenuItem(
                        value: t.uid,
                        child: Text(t.displayName ?? t.email),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedTeacherUid = val),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Questions Allocation:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAllocationCounter(
                          'Easy',
                          _teacherEasyCount,
                          (v) => setState(() => _teacherEasyCount = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAllocationCounter(
                          'Medium',
                          _teacherMediumCount,
                          (v) => setState(() => _teacherMediumCount = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildAllocationCounter(
                          'Hard',
                          _teacherHardCount,
                          (v) => setState(() => _teacherHardCount = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _selectedTeacherUid == null ? null : _addTeacherDelegation,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add / Update Delegation'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Card 4: Summary of current delegations
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delegated Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryBlue),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: quotaMatches ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$totalDelegated / ${req.questionCount} Delegated',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: quotaMatches ? Colors.green : Colors.amber[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_delegations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No delegations configured yet.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _delegations.length,
                    itemBuilder: (context, idx) {
                      final del = _delegations[idx];
                      final teacher = _courseTeachers.firstWhere(
                        (t) => t.uid == del.teacherUid,
                        orElse: () => UserProfile(
                          uid: del.teacherUid,
                          email: 'unknown@user.com',
                          displayName: 'Unknown Teacher',
                          createdAt: DateTime.now(),
                          roles: {},
                        ),
                      );

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(teacher.displayName ?? teacher.email, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Quota: ${del.questionCount} questions allocated'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () => _removeDelegation(idx),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Submit action
        ElevatedButton(
          onPressed: _isSubmitting || !_isTimelineValid() || !_isDelegationComplete() ? null : _submitDelegation,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Publish Timelines & Quotas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildAllocationCounter(String label, int val, ValueChanged<int> onChange) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: val > 0 ? () => onChange(val - 1) : null,
            ),
            Text('$val', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => onChange(val + 1),
            ),
          ],
        )
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
            width: 130,
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
