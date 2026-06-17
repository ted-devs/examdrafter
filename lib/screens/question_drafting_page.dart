import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam_request.dart';
import '../models/exam_curation.dart';
import '../models/question.dart';
import '../models/taxonomy.dart';
import '../services/auth_service.dart';
import '../services/draft_service.dart';
import '../services/notification_service.dart';

class QuestionDraftingPage extends StatefulWidget {
  const QuestionDraftingPage({super.key});

  @override
  State<QuestionDraftingPage> createState() => _QuestionDraftingPageState();
}

class _QuestionDraftingPageState extends State<QuestionDraftingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final DraftService _draftService = DraftService();

  bool _isLoading = true;
  String? _currentUid;
  bool _isRevisionMode = false;

  // Active delegations matching this teacher
  List<Map<String, dynamic>> _activeDelegations = [];
  Map<String, dynamic>? _selectedDelegation;

  // Questions matching the selected delegation
  List<Question> _teacherQuestions = [];
  bool _isLoadingQuestions = false;

  // Selected question in the editor (null means creating a new one)
  Question? _editingQuestion;
  bool _isNewQuestion = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _questionTextController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  int _correctOptionIndex = 0;
  String _difficulty = 'Medium';
  List<String> _selectedTopicIds = [];

  // Topics for the selected course
  List<Topic> _courseTopics = [];

  static const primaryBlue = Color(0xFF1D4ED8);
  static const lightBlueBg = Color(0xFFEFF6FF);

  @override
  void initState() {
    super.initState();
    _currentUid = _authService.currentUser?.uid;
    for (int i = 0; i < 4; i++) {
      _optionControllers.add(TextEditingController());
    }
    _loadDelegations();
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 5) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption() {
    if (_optionControllers.length > 4) {
      setState(() {
        final removed = _optionControllers.removeLast();
        removed.dispose();
        if (_correctOptionIndex >= _optionControllers.length) {
          _correctOptionIndex = 0;
        }
      });
    }
  }

  Future<void> _loadDelegations() async {
    if (_currentUid == null) return;

    setState(() => _isLoading = true);

    try {
      final curationsSnap = await _firestore.collection('curations').get();
      final List<Map<String, dynamic>> delegations = [];

      for (final doc in curationsSnap.docs) {
        final data = doc.data();
        final curation = ExamCuration.fromMap(data, doc.id);

        // Find if this teacher is delegated
        final matchingDelegations = curation.teacherDelegations.where((d) => d.teacherUid == _currentUid).toList();
        if (matchingDelegations.isNotEmpty) {
          final teacherDelegation = matchingDelegations.first;

          // Fetch matching exam request
          final reqDoc = await _firestore.collection('exam_requests').doc(curation.examRequestId).get();
          if (reqDoc.exists) {
            final request = ExamRequest.fromMap(reqDoc.data()!, reqDoc.id);

            // Fetch course details
            final courseDoc = await _firestore.collection('courses').doc(request.courseId).get();
            String courseCode = request.courseId;
            String courseName = 'Unknown Course';
            if (courseDoc.exists) {
              final cData = courseDoc.data()!;
              courseCode = cData['code'] ?? '';
              courseName = cData['name'] ?? '';
            }

            delegations.add({
              'curation': curation,
              'request': request,
              'delegation': teacherDelegation,
              'courseCode': courseCode,
              'courseName': courseName,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _activeDelegations = delegations;
          _isLoading = false;
        });

        // Auto select first delegation if available
        if (delegations.isNotEmpty) {
          _selectDelegation(delegations.first);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading delegations: $e')),
        );
      }
    }
  }

  Future<void> _selectDelegation(Map<String, dynamic> delegation) async {
    setState(() {
      _selectedDelegation = delegation;
      _editingQuestion = null;
      _isNewQuestion = false;
    });

    final request = delegation['request'] as ExamRequest;
    await _loadQuestionsForRequest(request.id, request.courseId);
    await _loadTopicsForCourse(request.courseId);
  }

  Future<void> _loadQuestionsForRequest(String requestId, String courseId) async {
    if (_currentUid == null) return;

    setState(() => _isLoadingQuestions = true);

    try {
      final snap = await _firestore
          .collection('questions')
          .where('authorUid', isEqualTo: _currentUid)
          .where('sourceDraftId', isEqualTo: requestId)
          .snapshots()
          .first;

      final questions = snap.docs
          .map((doc) => Question.fromMap(doc.data(), doc.id))
          .where((q) => q.status != 'deprecated')
          .toList();

      if (mounted) {
        setState(() {
          _teacherQuestions = questions;
          _isLoadingQuestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingQuestions = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load questions: $e')),
        );
      }
    }
  }

  Future<void> _loadTopicsForCourse(String courseId) async {
    try {
      final snap = await _firestore.collection('topics').get();
      final topics = snap.docs
          .map((doc) => Topic.fromMap(doc.data(), doc.id))
          .where((topic) => topic.courseIds.contains(courseId))
          .toList();

      if (mounted) {
        setState(() {
          _courseTopics = topics;
        });
      }
    } catch (_) {}
  }

  void _startNewQuestion() {
    final delegation = _selectedDelegation!['delegation'] as TeacherDelegation;
    if (_teacherQuestions.length >= delegation.questionCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quota Met! You cannot add more than ${delegation.questionCount} questions.')),
      );
      return;
    }

    setState(() {
      _editingQuestion = null;
      _isNewQuestion = true;
      _isRevisionMode = false;
      _questionTextController.clear();
      
      while (_optionControllers.length < 4) {
        _optionControllers.add(TextEditingController());
      }
      while (_optionControllers.length > 4) {
        final controller = _optionControllers.removeLast();
        controller.dispose();
      }

      for (final controller in _optionControllers) {
        controller.clear();
      }
      _correctOptionIndex = 0;
      _difficulty = 'Medium';
      _selectedTopicIds = [];
    });
  }

  void _selectQuestion(Question question) {
    setState(() {
      _editingQuestion = question;
      _isNewQuestion = false;
      _isRevisionMode = false;
      _questionTextController.text = question.questionText;
      _difficulty = question.difficulty;
      _selectedTopicIds = List.from(question.topics);

      while (_optionControllers.length < question.options.length) {
        _optionControllers.add(TextEditingController());
      }
      while (_optionControllers.length > question.options.length) {
        final controller = _optionControllers.removeLast();
        controller.dispose();
      }

      // Populate option controllers
      for (int i = 0; i < _optionControllers.length; i++) {
        _optionControllers[i].text = question.options[i].text;
        if (question.options[i].isCorrect) {
          _correctOptionIndex = i;
        }
      }
      if (_correctOptionIndex >= _optionControllers.length) {
        _correctOptionIndex = 0;
      }
    });
  }

  Future<void> _recallQuestion(String questionId) async {
    setState(() => _isLoading = true);
    try {
      await _draftService.recallToDraft(questionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question successfully recalled to draft.')),
        );
      }
      final request = _selectedDelegation!['request'] as ExamRequest;
      await _loadQuestionsForRequest(request.id, request.courseId);
      // Select the recalled question
      if (_editingQuestion?.id == questionId) {
        final updatedQ = _teacherQuestions.firstWhere((q) => q.id == questionId);
        _selectQuestion(updatedQ);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to recall question: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveOrSubmitQuestion(bool submit) async {
    if (!_formKey.currentState!.validate() || _selectedDelegation == null || _currentUid == null) return;

    final request = _selectedDelegation!['request'] as ExamRequest;

    final List<Option> options = [];
    for (int i = 0; i < _optionControllers.length; i++) {
      options.add(Option(
        text: _optionControllers[i].text.trim(),
        isCorrect: _correctOptionIndex == i,
      ));
    }

    if (_selectedTopicIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one learning topic.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tempQ = Question(
        id: _isNewQuestion ? '' : (_editingQuestion?.id ?? ''),
        sourceDraftId: request.id,
        version: _editingQuestion?.version ?? 1,
        questionText: _questionTextController.text.trim(),
        options: options,
        topics: _selectedTopicIds,
        difficulty: _difficulty,
        courseId: request.courseId,
        authorUid: _currentUid!,
        status: _editingQuestion?.status ?? 'draft',
        createdAt: _editingQuestion?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _draftService.saveQuestion(
        question: tempQ,
        submit: submit,
        isRevision: _isRevisionMode,
      );

      if (submit) {
        // Send notification to course committee leads and members
        try {
          final authorDoc = await _firestore.collection('users').doc(_currentUid).get();
          final authorName = authorDoc.data()?['displayName'] ?? 'A teacher';
          
          final courseCode = _selectedDelegation!['courseCode'] ?? request.courseId;
          final courseName = _selectedDelegation!['courseName'] ?? '';

          await NotificationService().sendNotificationToCourseRole(
            courseId: request.courseId,
            targetRoles: ['committee_lead', 'committee_member'],
            title: 'Question Submitted for Curation',
            message: '$authorName submitted a new question for $courseCode - $courseName.',
            type: 'question_submitted',
            relatedRequestId: request.id,
          );
        } catch (e) {
          // Safe fallback for notification failures
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(submit ? 'Question successfully submitted!' : 'Draft question saved.')),
        );
        setState(() {
          _editingQuestion = null;
          _isNewQuestion = false;
          _isRevisionMode = false;
        });
        await _loadQuestionsForRequest(request.id, request.courseId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save question: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('questions').doc(questionId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question successfully deleted.')),
        );
        setState(() {
          _editingQuestion = null;
          _isNewQuestion = false;
        });
        final request = _selectedDelegation!['request'] as ExamRequest;
        await _loadQuestionsForRequest(request.id, request.courseId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete question: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _activeDelegations.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    }

    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Teacher MCQ Drafting Workspace',
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
        // Left Column: Active delegations list
        SizedBox(
          width: 380,
          child: Card(
            margin: const EdgeInsets.only(left: 24, bottom: 24, top: 12),
            child: _buildDelegationsList(),
          ),
        ),
        // Right Column: Editor & Question list
        Expanded(
          child: _selectedDelegation == null
              ? _buildEmptyState()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Curation pool / questions written so far
                    SizedBox(
                      width: 320,
                      child: Card(
                        margin: const EdgeInsets.only(left: 20, bottom: 24, top: 12),
                        child: _buildQuestionsPool(),
                      ),
                    ),
                    // Editor workspace
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(left: 20, right: 24, bottom: 24, top: 12),
                        child: _buildEditorWorkspace(),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSingleLayout() {
    return _selectedDelegation == null
        ? _buildDelegationsList(padding: const EdgeInsets.all(24.0))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedDelegation = null),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Delegations'),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Course: ${_selectedDelegation!['courseCode']} - ${_selectedDelegation!['courseName']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildQuestionsPool(),
                const SizedBox(height: 16),
                _buildEditorWorkspace(),
              ],
            ),
          );
  }

  Widget _buildDelegationsList({EdgeInsets padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 8)}) {
    if (_activeDelegations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_off_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No active question drafting delegations',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: padding,
      itemCount: _activeDelegations.length,
      separatorBuilder: (context, idx) => const Divider(height: 1),
      itemBuilder: (context, idx) {
        final del = _activeDelegations[idx];
        final request = del['request'] as ExamRequest;
        final teacherDel = del['delegation'] as TeacherDelegation;
        final isSelected = _selectedDelegation?['request']?.id == request.id;

        return ListTile(
          selected: isSelected,
          selectedTileColor: lightBlueBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '${del['courseCode']} - ${del['courseName']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Section: ${request.section}\nAllocated Quota: ${teacherDel.questionCount} Questions\nDeadline: ${request.internalDeadline!.toLocal().toString().split(' ')[0]}',
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => _selectDelegation(del),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No delegation selected',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
          ),
          SizedBox(height: 8),
          Text(
            'Select a course delegation from the left list to start writing questions.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsPool() {
    final delegation = _selectedDelegation!['delegation'] as TeacherDelegation;
    final totalQuestions = _teacherQuestions.length;
    final isQuotaMet = totalQuestions >= delegation.questionCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Drafted MCQ Pool',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isQuotaMet ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalQuestions / ${delegation.questionCount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isQuotaMet ? Colors.green : Colors.amber[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isQuotaMet ? null : _startNewQuestion,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Question'),
          ),
          if (isQuotaMet) ...[
            const SizedBox(height: 8),
            const Text(
              'Quota met! Submissions locked.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingQuestions
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : _teacherQuestions.isEmpty
                    ? const Center(
                        child: Text(
                          'No questions created yet. Click "Add Question" above to start.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _teacherQuestions.length,
                        separatorBuilder: (context, idx) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final q = _teacherQuestions[idx];
                          final isEditingThis = _editingQuestion?.id == q.id;

                          return Card(
                            color: isEditingThis ? lightBlueBg : const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isEditingThis ? primaryBlue : Colors.grey[200]!,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _selectQuestion(q),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      q.questionText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: q.status == 'submitted'
                                                ? Colors.blue.withValues(alpha: 0.12)
                                                : Colors.amber.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            q.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: q.status == 'submitted' ? Colors.blue : Colors.amber[800],
                                            ),
                                          ),
                                        ),
                                        Text(
                                          q.difficulty,
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorWorkspace() {
    if (!_isNewQuestion && _editingQuestion == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_note_rounded, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No question selected for editing',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Click "Add Question" or select a question card from the pool.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final isReadOnly = !_isNewQuestion &&
        ((_editingQuestion?.status == 'submitted') ||
            (_editingQuestion?.status == 'approved' && !_isRevisionMode));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _isNewQuestion ? 'Draft New MCQ Question' : 'MCQ Question Editor',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: primaryBlue),
                    ),
                  ),
                  if (_editingQuestion?.status == 'submitted') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'SUBMITTED',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _recallQuestion(_editingQuestion!.id),
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text('Recall', style: TextStyle(fontSize: 12)),
                    ),
                  ] else if (_editingQuestion?.status == 'approved') ...[
                    if (!_isRevisionMode) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'APPROVED',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _isRevisionMode = true),
                        icon: const Icon(Icons.history_rounded, size: 16),
                        label: const Text('Revise', style: TextStyle(fontSize: 12)),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'REVISING',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 11),
                        ),
                      ),
                  ] else if (_editingQuestion != null && !isReadOnly)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () => _deleteQuestion(_editingQuestion!.id),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _questionTextController,
                maxLines: 4,
                enabled: !isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Question Statement',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the question text';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Options (${_optionControllers.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (!isReadOnly)
                    Row(
                      children: [
                        if (_optionControllers.length > 4)
                          TextButton.icon(
                            onPressed: _removeOption,
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                            label: const Text('Remove Option', style: TextStyle(fontSize: 12)),
                          ),
                        if (_optionControllers.length < 5)
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                            label: const Text('Add Option', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_optionControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: i,
                        // ignore: deprecated_member_use
                        groupValue: _correctOptionIndex,
                        // ignore: deprecated_member_use
                        onChanged: isReadOnly
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _correctOptionIndex = val);
                                }
                              },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _optionControllers[i],
                          enabled: !isReadOnly,
                          decoration: InputDecoration(
                            labelText: 'Option ${String.fromCharCode(65 + i)}',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Option text cannot be empty';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: const InputDecoration(labelText: 'Difficulty Level'),
                items: const [
                  DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'Hard', child: Text('Hard')),
                ],
                onChanged: isReadOnly ? null : (val) => setState(() => _difficulty = val!),
              ),
              const SizedBox(height: 24),
              const Text(
                'Associated Learning Topics:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (_courseTopics.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No topics registered for this course section. Please notify the administrator.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _courseTopics.map((topic) {
                    final isSelected = _selectedTopicIds.contains(topic.name);
                    return FilterChip(
                      label: Text(topic.name),
                      selected: isSelected,
                      onSelected: isReadOnly
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTopicIds.add(topic.name);
                                } else {
                                  _selectedTopicIds.remove(topic.name);
                                }
                              });
                            },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 32),
              if (!isReadOnly)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _saveOrSubmitQuestion(false),
                        icon: const Icon(Icons.save_as_rounded),
                        label: const Text('Save as Draft'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _saveOrSubmitQuestion(true),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Submit to Pool'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
