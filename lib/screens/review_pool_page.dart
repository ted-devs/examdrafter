import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam_request.dart';
import '../models/exam_curation.dart';
import '../models/question.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class ReviewPoolPage extends StatefulWidget {
  const ReviewPoolPage({super.key});

  @override
  State<ReviewPoolPage> createState() => _ReviewPoolPageState();
}

class _ReviewPoolPageState extends State<ReviewPoolPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  UserProfile? _currentUserProfile;
  bool _isLoadingProfile = true;

  ExamRequest? _selectedRequest;
  ExamCuration? _selectedCuration;
  List<Question> _questions = [];
  bool _isLoadingQuestions = false;

  // Selected questions checked by the lead
  List<String> _selectedQuestionIds = [];

  bool _isFinalizing = false;

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

  bool _isAuthorizedForRequest(ExamRequest req) {
    if (_currentUserProfile == null) return false;
    if (_currentUserProfile!.hasGlobalRole('super_admin') || _currentUserProfile!.hasGlobalRole('admin')) {
      return true;
    }
    final role = _currentUserProfile!.roles['course_${req.courseId}'];
    return role == 'committee_lead' || role == 'committee_member';
  }

  bool _isCommitteeLead() {
    if (_currentUserProfile == null || _selectedRequest == null) return false;
    if (_currentUserProfile!.hasGlobalRole('super_admin') || _currentUserProfile!.hasGlobalRole('admin')) {
      return true;
    }
    final role = _currentUserProfile!.roles['course_${_selectedRequest!.courseId}'];
    return role == 'committee_lead';
  }

  Future<void> _selectRequest(ExamRequest req) async {
    setState(() {
      _selectedRequest = req;
      _questions = [];
      _selectedQuestionIds = [];
      _isLoadingQuestions = true;
    });

    _listenToCurationAndQuestions(req.id);
  }

  void _listenToCurationAndQuestions(String requestId) {
    // Set up snapshot listener for the curation document to get real-time votes
    _firestore.collection('curations').doc(requestId).snapshots().listen((curationSnap) {
      if (!curationSnap.exists || !mounted || _selectedRequest?.id != requestId) return;

      final curation = ExamCuration.fromMap(curationSnap.data()!, curationSnap.id);

      // Fetch questions associated with this request (only submitted/approved questions are curatable)
      _firestore
          .collection('questions')
          .where('sourceDraftId', isEqualTo: requestId)
          .snapshots()
          .listen((questionsSnap) {
        if (!mounted || _selectedRequest?.id != requestId) return;

        final questions = questionsSnap.docs
            .map((doc) => Question.fromMap(doc.data(), doc.id))
            .where((q) => q.status == 'submitted' || q.status == 'approved')
            .toList();

        setState(() {
          _selectedCuration = curation;
          _questions = questions;
          _selectedQuestionIds = List.from(curation.selectedQuestionIds);
          _isLoadingQuestions = false;
        });
      });
    });
  }

  Future<void> _toggleVote(String questionId) async {
    if (_currentUserProfile == null || _selectedRequest == null) return;
    final uid = _currentUserProfile!.uid;

    final docRef = _firestore.collection('curations').doc(_selectedRequest!.id);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final curation = ExamCuration.fromMap(data, snapshot.id);

        final votesMap = Map<String, List<String>>.from(curation.votes);
        final list = votesMap[questionId] != null ? List<String>.from(votesMap[questionId]!) : <String>[];

        if (list.contains(uid)) {
          list.remove(uid);
        } else {
          list.add(uid);
        }

        votesMap[questionId] = list;

        transaction.update(docRef, {'votes': votesMap});
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to vote: $e')),
        );
      }
    }
  }

  void _toggleQuestionSelection(String questionId) {
    if (!_isCommitteeLead()) return;

    setState(() {
      if (_selectedQuestionIds.contains(questionId)) {
        _selectedQuestionIds.remove(questionId);
      } else {
        _selectedQuestionIds.add(questionId);
      }
    });

    // Save selected list immediately to Firestore curation document
    _firestore.collection('curations').doc(_selectedRequest!.id).update({
      'selectedQuestionIds': _selectedQuestionIds,
    });
  }

  void _autoSelectTopVoted() {
    if (_selectedRequest == null || _questions.isEmpty) return;

    final req = _selectedRequest!;
    final selectedIds = <String>[];

    // Group questions by difficulty (case insensitive match)
    final Map<String, List<Question>> questionsByDiff = {
      'easy': [],
      'medium': [],
      'hard': [],
    };

    for (final q in _questions) {
      final diff = q.difficulty.toLowerCase();
      if (questionsByDiff.containsKey(diff)) {
        questionsByDiff[diff]!.add(q);
      } else {
        questionsByDiff['medium']!.add(q); // fallback
      }
    }

    // Function to calculate net vote count
    int getVoteCount(Question q) {
      if (_selectedCuration == null) return 0;
      return _selectedCuration!.votes[q.id]?.length ?? 0;
    }

    // Sort each group by votes desc and pick up to required count
    req.difficultyDistribution.forEach((difficultyKey, requiredCount) {
      final list = questionsByDiff[difficultyKey.toLowerCase()] ?? [];
      list.sort((a, b) => getVoteCount(b).compareTo(getVoteCount(a)));

      final selectedForCategory = list.take(requiredCount).map((q) => q.id).toList();
      selectedIds.addAll(selectedForCategory);
    });

    setState(() {
      _selectedQuestionIds = selectedIds;
    });

    _firestore.collection('curations').doc(req.id).update({
      'selectedQuestionIds': _selectedQuestionIds,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Automatically selected top voted questions matching the quotas.')),
    );
  }

  // Count difficulty distribution of currently selected questions
  Map<String, int> _getCurrentDistribution() {
    final Map<String, int> dist = {'Easy': 0, 'Medium': 0, 'Hard': 0};
    for (final id in _selectedQuestionIds) {
      final q = _questions.firstWhere((item) => item.id == id, orElse: () => Question(
        id: '',
        sourceDraftId: '',
        version: 1,
        questionText: '',
        options: [],
        topics: [],
        difficulty: 'Medium',
        courseId: '',
        authorUid: '',
        status: 'draft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      if (q.id.isNotEmpty) {
        final difficultyStr = q.difficulty;
        final cleanDiff = difficultyStr.substring(0, 1).toUpperCase() + difficultyStr.substring(1).toLowerCase();
        dist[cleanDiff] = (dist[cleanDiff] ?? 0) + 1;
      }
    }
    return dist;
  }

  bool _isSelectionQuotaMet() {
    if (_selectedRequest == null) return false;
    final req = _selectedRequest!;
    final currentDist = _getCurrentDistribution();

    bool matches = true;
    req.difficultyDistribution.forEach((key, requiredVal) {
      final cleanKey = key.substring(0, 1).toUpperCase() + key.substring(1).toLowerCase();
      if ((currentDist[cleanKey] ?? 0) != requiredVal) {
        matches = false;
      }
    });

    return matches && _selectedQuestionIds.length == req.questionCount;
  }

  Future<void> _finalizeCuration() async {
    if (_selectedRequest == null || _currentUserProfile == null) return;
    if (!_isSelectionQuotaMet()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot finalize: Selected questions do not match the required difficulty distribution quota.')),
      );
      return;
    }

    setState(() => _isFinalizing = true);

    try {
      final batch = _firestore.batch();
      final reqRef = _firestore.collection('exam_requests').doc(_selectedRequest!.id);
      final curationRef = _firestore.collection('curations').doc(_selectedRequest!.id);

      // Update exam request status
      batch.update(reqRef, {
        'status': ExamRequestStatus.submittedToAdmin.toJson(),
      });

      // Update curation doc with finalization details
      batch.update(curationRef, {
        'finalizedByUid': _currentUserProfile!.uid,
        'finalizedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Update selected questions to approved status
      for (final questionId in _selectedQuestionIds) {
        final qRef = _firestore.collection('questions').doc(questionId);
        batch.update(qRef, {'status': 'approved'});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam curation finalized and submitted to Admin successfully!')),
        );
        setState(() {
          _selectedRequest = null;
          _selectedCuration = null;
          _questions = [];
          _selectedQuestionIds = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to finalize curation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFinalizing = false);
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
          'Committee Curation Board',
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
        // Left Column: Active curation requests
        SizedBox(
          width: 380,
          child: Card(
            margin: const EdgeInsets.only(left: 24, bottom: 24, top: 12),
            child: _buildRequestsList(),
          ),
        ),
        // Right Column: Curation board & questions list
        Expanded(
          child: _selectedRequest == null
              ? _buildEmptyState()
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 12),
                        child: _buildCurationBoard(),
                      ),
                    ),
                    _buildCurationBottomBar(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSingleLayout() {
    return _selectedRequest == null
        ? _buildRequestsList(padding: const EdgeInsets.all(24.0))
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
                        label: const Text('Back to Requests'),
                      ),
                      const SizedBox(height: 16),
                      _buildCurationBoard(),
                    ],
                  ),
                ),
              ),
              _buildCurationBottomBar(),
            ],
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
                (req.status == ExamRequestStatus.delegated ||
                    req.status == ExamRequestStatus.curating ||
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
                'Section: ${req.section}\nRequired Quota: ${req.questionCount} questions',
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
            Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No active curations',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Exam requests in drafting or curating phases will appear here for collaborative review.',
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
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No curation requested',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
          ),
          SizedBox(height: 8),
          Text(
            'Select an active course curation request from the left list to review questions.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCurationBoard() {
    final req = _selectedRequest!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Curation Info',
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
                  'Required Distribution',
                  req.difficultyDistribution.entries.map((e) => '${e.key}: ${e.value}').join(', '),
                ),
                _buildDetailRow(
                  'Admin Deadline',
                  req.adminDeadline.toLocal().toString().split(' ')[0],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Questions Pool title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Submitted Questions (${_questions.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (_isCommitteeLead() && _questions.isNotEmpty)
              TextButton.icon(
                onPressed: _autoSelectTopVoted,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Auto-select Top Voted'),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_isLoadingQuestions)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: primaryBlue)))
        else if (_questions.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48.0),
              child: Text(
                'No questions submitted yet by delegated teachers.',
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
              return _buildQuestionCurationCard(q);
            },
          ),
      ],
    );
  }

  Widget _buildQuestionCurationCard(Question q) {
    final hasVoted = _selectedCuration?.votes[q.id]?.contains(_currentUserProfile?.uid) ?? false;
    final voteCount = _selectedCuration?.votes[q.id]?.length ?? 0;
    final isSelected = _selectedQuestionIds.contains(q.id);
    final isLead = _isCommitteeLead();

    final difficultyColor = q.difficulty.toLowerCase() == 'easy'
        ? Colors.green
        : q.difficulty.toLowerCase() == 'hard'
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? primaryBlue : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Author, Difficulty, Selection
            Row(
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(q.authorUid).get(),
                  builder: (context, userSnapshot) {
                    String authorName = 'Unknown Teacher';
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      final uData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      authorName = uData?['displayName'] ?? uData?['email'] ?? 'Unknown';
                    }
                    return Text(
                      'By: $authorName',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13),
                    );
                  },
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
                    style: TextStyle(color: difficultyColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isLead) ...[
                  const SizedBox(width: 12),
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) => _toggleQuestionSelection(q.id),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Question Text
            Text(
              q.questionText,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),

            // Options List
            Column(
              children: q.options.map((option) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: option.isCorrect ? Colors.green.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
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
                        size: 18,
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
            const SizedBox(height: 12),

            // Topics and Voting Action
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: q.topics.map((topicName) {
                      return Chip(
                        label: Text(topicName, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: Colors.grey[300]!),
                      );
                    }).toList(),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _toggleVote(q.id),
                  isSelected: hasVoted,
                  selectedIcon: const Icon(Icons.thumb_up_rounded, size: 18, color: primaryBlue),
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                  style: IconButton.styleFrom(
                    foregroundColor: hasVoted ? primaryBlue : Colors.grey[700],
                  ),
                ),
                Text(
                  '$voteCount votes',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurationBottomBar() {
    if (_selectedRequest == null) return const SizedBox.shrink();

    final req = _selectedRequest!;
    final isQuotaMet = _isSelectionQuotaMet();
    final currentDist = _getCurrentDistribution();
    final isLead = _isCommitteeLead();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Curation Progress:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${_selectedQuestionIds.length} / ${req.questionCount} Selected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isQuotaMet ? Colors.green : Colors.orange,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: req.difficultyDistribution.entries.map((e) {
                final cleanKey = e.key.substring(0, 1).toUpperCase() + e.key.substring(1).toLowerCase();
                final current = currentDist[cleanKey] ?? 0;
                final target = e.value;
                final met = current == target;
                return Text(
                  '$cleanKey: $current/$target',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: met ? FontWeight.bold : FontWeight.normal,
                    color: met ? Colors.green : Colors.grey[600],
                  ),
                );
              }).toList(),
            ),
            if (isLead) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isFinalizing || !isQuotaMet ? null : _finalizeCuration,
                child: _isFinalizing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Finalize & Lock Curation',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
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
