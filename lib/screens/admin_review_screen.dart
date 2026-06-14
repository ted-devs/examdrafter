import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam_request.dart';
import '../models/exam_curation.dart';
import '../models/question.dart';
import '../services/auth_service.dart';
import 'print_setup_dialog.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  ExamRequest? _selectedRequest;
  List<Question> _questions = [];
  bool _isLoadingQuestions = false;

  bool _isSubmitting = false;

  static const primaryBlue = Color(0xFF1D4ED8);
  static const lightBlueBg = Color(0xFFEFF6FF);

  // Controller for dialogs
  final _dialogTextController = TextEditingController();
  String _selectedSemester = 'Fall';
  final _yearController = TextEditingController(text: DateTime.now().year.toString());

  @override
  void dispose() {
    _dialogTextController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _selectRequest(ExamRequest req) async {
    setState(() {
      _selectedRequest = req;
      _questions = [];
      _isLoadingQuestions = true;
    });

    try {
      // 1. Fetch Curation Details
      final curationSnap = await _firestore.collection('curations').doc(req.id).get();
      if (!curationSnap.exists) {
        setState(() => _isLoadingQuestions = false);
        return;
      }

      final curation = ExamCuration.fromMap(curationSnap.data()!, curationSnap.id);
      final List<String> selectedIds = curation.selectedQuestionIds;

      if (selectedIds.isEmpty) {
        setState(() {
          _questions = [];
          _isLoadingQuestions = false;
        });
        return;
      }

      // 2. Fetch curated questions details
      final List<Question> fetched = [];
      for (final id in selectedIds) {
        final qSnap = await _firestore.collection('questions').doc(id).get();
        if (qSnap.exists) {
          fetched.add(Question.fromMap(qSnap.data()!, qSnap.id));
        }
      }

      if (mounted && _selectedRequest?.id == req.id) {
        setState(() {
          _questions = fetched;
          _isLoadingQuestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingQuestions = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load curation questions: $e')),
        );
      }
    }
  }

  Future<void> _approveExamRequest() async {
    if (_selectedRequest == null) return;
    _yearController.text = DateTime.now().year.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Approve & Lock Exam Paper', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tag the exam paper with academic term metadata before finalizing.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedSemester,
                    decoration: const InputDecoration(labelText: 'Semester'),
                    items: const [
                      DropdownMenuItem(value: 'Fall', child: Text('Fall')),
                      DropdownMenuItem(value: 'Spring', child: Text('Spring')),
                      DropdownMenuItem(value: 'Summer', child: Text('Summer')),
                    ],
                    onChanged: (val) => setDialogState(() => _selectedSemester = val!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _yearController,
                    decoration: const InputDecoration(labelText: 'Academic Year'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Approve & Lock'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isSubmitting = true);
      try {
        final batch = _firestore.batch();
        final reqRef = _firestore.collection('exam_requests').doc(_selectedRequest!.id);

        batch.update(reqRef, {
          'status': ExamRequestStatus.approved.toJson(),
          'semester': _selectedSemester,
          'year': _yearController.text.trim(),
          'approvedAt': Timestamp.fromDate(DateTime.now()),
          'approvedByUid': _authService.currentUser?.uid ?? '',
        });

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exam paper successfully approved and locked.')),
          );
          setState(() {
            _selectedRequest = null;
            _questions = [];
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to approve request: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  Future<void> _rejectExamRequest() async {
    if (_selectedRequest == null) return;
    _dialogTextController.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Return for Revision', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Please provide clear revision notes explaining the corrections required.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dialogTextController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Revision Notes',
                  hintText: 'Describe changes needed (e.g. difficulty adjustment)...',
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
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('Return to Committee'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final notes = _dialogTextController.text.trim();
      if (notes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revision notes are required to return a request.')),
        );
        return;
      }

      setState(() => _isSubmitting = true);
      try {
        final batch = _firestore.batch();
        final reqRef = _firestore.collection('exam_requests').doc(_selectedRequest!.id);
        final notifyRef = _firestore.collection('notifications').doc();

        batch.update(reqRef, {
          'status': ExamRequestStatus.returnedForRevision.toJson(),
          'revisionNotes': notes,
        });

        // Add System Notification
        batch.set(notifyRef, {
          'title': 'Revision Required',
          'message': 'Curated paper for section ${_selectedRequest!.section} returned: $notes',
          'type': 'revision_returned',
          'relatedRequestId': _selectedRequest!.id,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exam request returned to Committee for revision.')),
          );
          setState(() {
            _selectedRequest = null;
            _questions = [];
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to return request: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  void _triggerPrintSetup() {
    if (_selectedRequest == null) return;
    showDialog(
      context: context,
      builder: (context) => PrintSetupDialog(examRequestId: _selectedRequest!.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Exam Request Review Board',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            indicatorColor: primaryBlue,
            labelColor: primaryBlue,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.rate_review_rounded), text: 'Pending Review'),
              Tab(icon: Icon(Icons.archive_rounded), text: 'Approved & Print'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Pending Review
            isLargeScreen
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 380,
                        child: Card(
                          margin: const EdgeInsets.only(left: 24, bottom: 24, top: 12),
                          child: _buildRequestsList(ExamRequestStatus.submittedToAdmin),
                        ),
                      ),
                      Expanded(
                        child: _selectedRequest == null || _selectedRequest!.status != ExamRequestStatus.submittedToAdmin
                            ? _buildEmptyState('No pending review request selected')
                            : Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 12),
                                      child: _buildReviewPanel(isPending: true),
                                    ),
                                  ),
                                  _buildActionButtons(isPending: true),
                                ],
                              ),
                      ),
                    ],
                  )
                : _buildSingleLayout(ExamRequestStatus.submittedToAdmin, isPending: true),

            // Tab 2: Approved / Print
            isLargeScreen
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 380,
                        child: Card(
                          margin: const EdgeInsets.only(left: 24, bottom: 24, top: 12),
                          child: _buildRequestsList(ExamRequestStatus.approved),
                        ),
                      ),
                      Expanded(
                        child: _selectedRequest == null || _selectedRequest!.status != ExamRequestStatus.approved
                            ? _buildEmptyState('No approved request selected')
                            : Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 12),
                                      child: _buildReviewPanel(isPending: false),
                                    ),
                                  ),
                                  _buildActionButtons(isPending: false),
                                ],
                              ),
                      ),
                    ],
                  )
                : _buildSingleLayout(ExamRequestStatus.approved, isPending: false),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleLayout(ExamRequestStatus targetStatus, {required bool isPending}) {
    return _selectedRequest == null || _selectedRequest!.status != targetStatus
        ? _buildRequestsList(targetStatus, padding: const EdgeInsets.all(24.0))
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _selectedRequest = null),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back to List'),
                      ),
                      const SizedBox(height: 16),
                      _buildReviewPanel(isPending: isPending),
                    ],
                  ),
                ),
              ),
              _buildActionButtons(isPending: isPending),
            ],
          );
  }

  Widget _buildRequestsList(ExamRequestStatus status, {EdgeInsets padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 8)}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('exam_requests')
          .where('status', isEqualTo: status.toJson())
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryBlue));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No requests in ${status == ExamRequestStatus.submittedToAdmin ? "pending review" : "approved"} state.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final list = docs
            .map((doc) => ExamRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();

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
                'Section: ${req.section}\nCurated: ${req.questionCount} questions',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => _selectRequest(req),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            msg,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPanel({required bool isPending}) {
    final req = _selectedRequest!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exam Specs Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Curated Exam Summary',
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
                _buildDetailRow('Target Section', req.section),
                _buildDetailRow('Question Count', '${req.questionCount} Questions'),
                _buildDetailRow(
                  'Difficulty Distribution',
                  req.difficultyDistribution.entries.map((e) => '${e.key}: ${e.value}').join(', '),
                ),
                _buildDetailRow(
                  'Created On',
                  req.createdAt.toLocal().toString().split('.')[0],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Curated Questions Preview',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),

        if (_isLoadingQuestions)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: primaryBlue)))
        else if (_questions.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48.0),
              child: Text(
                'No questions linked to this curated list.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final q = _questions[index];
              return _buildQuestionPreviewCard(q, index + 1);
            },
          ),
      ],
    );
  }

  Widget _buildQuestionPreviewCard(Question q, int index) {
    final difficultyColor = q.difficulty.toLowerCase() == 'easy'
        ? Colors.green
        : q.difficulty.toLowerCase() == 'hard'
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Question $index',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryBlue),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: difficultyColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    q.difficulty,
                    style: TextStyle(color: difficultyColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              q.questionText,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Column(
              children: q.options.map((option) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: option.isCorrect ? Colors.green.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: option.isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        option.isCorrect ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                        color: option.isCorrect ? Colors.green : Colors.grey[400],
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.text,
                          style: TextStyle(
                            fontWeight: option.isCorrect ? FontWeight.bold : FontWeight.normal,
                            color: option.isCorrect ? Colors.green[900] : Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons({required bool isPending}) {
    if (_selectedRequest == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        child: isPending
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _rejectExamRequest,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.assignment_return_rounded),
                      label: const Text('Return for Revision', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _approveExamRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Approve & Lock Exam', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _triggerPrintSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Print Setup & Export PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
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
