import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/approved_questions_page.dart';
import 'screens/delegation_page.dart';
import 'screens/login_page.dart';
import 'screens/question_drafting_page.dart';
import 'screens/review_pool_page.dart';
import 'services/auth_service.dart';
import 'services/draft_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam Drafter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D4ED8)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF5F7FB),
          foregroundColor: Color(0xFF0F172A),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blueGrey.shade100),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blueGrey.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.6),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1D4ED8),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            side: const BorderSide(color: Color(0xFF93C5FD)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF1F5F9),
          selectedColor: const Color(0xFFDBEAFE),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: BorderSide.none,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DraftService _draftService = DraftService();
  final TextEditingController _examIdController = TextEditingController(
    text: DraftService().firestoreExamId,
  );
  bool _useFirestore = DraftService().useFirestore;

  @override
  void dispose() {
    _examIdController.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      setState(() {});
    }
  }

  void _signOut() async {
    try {
      await AuthService().signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.blueGrey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.95),
                      color.withValues(alpha: 0.72),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
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
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.cloud_sync_rounded,
                    color: Color(0xFF4338CA),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backend test mode',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toggle Firestore persistence for drafts, votes, quotas, and the question bank.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _useFirestore,
                  onChanged: (value) {
                    setState(() {
                      _useFirestore = value;
                      _draftService.useFirestore = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _examIdController,
              decoration: const InputDecoration(
                labelText: 'Firestore exam request ID',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
              onChanged: (value) {
                _draftService.firestoreExamId = value.trim().isEmpty
                    ? 'default_exam'
                    : value.trim();
              },
            ),
            const SizedBox(height: 10),
            Text(
              'When enabled, the app writes to `exam_requests/{examId}` and `question_bank` using the current exam request ID.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.blueGrey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDrafts = _draftService.drafts.length;
    final reviewQueue = _draftService.submittedDrafts.length;
    final approved = _draftService.questionBank.length;
    final votes = _draftService.totalVotes;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Collaborative drafting, review, and approved-question management',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.blueGrey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _open(const DelegationPage()),
            icon: const Icon(Icons.groups_rounded),
            label: const Text('Delegation'),
          ),
          TextButton.icon(
            onPressed: () => _open(const QuestionDraftingPage()),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('New Draft'),
          ),
          TextButton.icon(
            onPressed: () => _open(const ReviewPoolPage()),
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('Review Pool'),
          ),
          TextButton.icon(
            onPressed: () => _open(const ApprovedQuestionsPage()),
            icon: const Icon(Icons.library_books_rounded),
            label: const Text('Approved'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _signOut,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1D4ED8),
                    const Color(0xFF2563EB).withValues(alpha: 0.92),
                    const Color(0xFF38BDF8).withValues(alpha: 0.88),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 900;
                  final left = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Part 2 workspace',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'A calmer, clearer home for teachers and committee members.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.08,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Draft questions, review submissions, and manage approved items from one friendly dashboard.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          Chip(
                            label: Text('Teacher drafting'),
                            backgroundColor: Colors.white,
                          ),
                          Chip(
                            label: Text('Committee review'),
                            backgroundColor: Colors.white,
                          ),
                          Chip(
                            label: Text('Approved archive'),
                            backgroundColor: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  );

                  final right = Card(
                    color: Colors.white.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today\'s focus',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 12),
                          const _FocusItem(
                            icon: Icons.edit_note_rounded,
                            text: 'Create a polished MCQ draft.',
                          ),
                          const _FocusItem(
                            icon: Icons.fact_check_rounded,
                            text: 'Vote submissions into the review pool.',
                          ),
                          const _FocusItem(
                            icon: Icons.library_books_rounded,
                            text: 'Lock approved questions into the bank.',
                          ),
                        ],
                      ),
                    ),
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: left),
                        const SizedBox(width: 20),
                        SizedBox(width: 320, child: right),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [left, const SizedBox(height: 20), right],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Workspace at a glance',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 1000
                    ? 4
                    : constraints.maxWidth > 700
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 16)) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: width,
                      child: _metricCard(
                        'Drafts created',
                        '$totalDrafts',
                        Icons.edit_document,
                        const Color(0xFF2563EB),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _metricCard(
                        'Review queue',
                        '$reviewQueue',
                        Icons.fact_check_rounded,
                        const Color(0xFFF59E0B),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _metricCard(
                        'Approved bank',
                        '$approved',
                        Icons.library_books_rounded,
                        const Color(0xFF10B981),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _metricCard(
                        'Votes cast',
                        '$votes',
                        Icons.how_to_vote_rounded,
                        const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Quick actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 320,
                  child: _actionCard(
                    title: 'Write a new draft',
                    subtitle:
                        'Create MCQs with options, topics, and difficulty.',
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: () => _open(const QuestionDraftingPage()),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: _actionCard(
                    title: 'Review submissions',
                    subtitle: 'Vote keep or drop and resolve ties.',
                    icon: Icons.fact_check_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () => _open(const ReviewPoolPage()),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: _actionCard(
                    title: 'Open approved bank',
                    subtitle: 'Browse locked questions and create versions.',
                    icon: Icons.library_books_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () => _open(const ApprovedQuestionsPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Persistence controls',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _backendCard(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent activity',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_draftService.recentDrafts.isEmpty)
              const _EmptyActivityCard()
            else
              Column(
                children: _draftService.recentDrafts.map((draft) {
                  final statusColor = switch (draft.status) {
                    'approved' => const Color(0xFF10B981),
                    'rejected' => const Color(0xFFEF4444),
                    'submitted' => const Color(0xFFF59E0B),
                    'in_review' => const Color(0xFF0EA5E9),
                    _ => const Color(0xFF64748B),
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.description_rounded,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Chip(
                                        label: Text(draft.status.toUpperCase()),
                                        backgroundColor: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: [
                                      Chip(label: Text(draft.difficulty)),
                                      Chip(
                                        label: Text(
                                          '${draft.options.length} options',
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          draft.topics.isEmpty
                                              ? 'No topics'
                                              : draft.topics.join(', '),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (draft.committeeNote != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      draft.committeeNote!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.blueGrey.shade600,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _FocusItem extends StatelessWidget {
  const _FocusItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard();

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
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.inbox_rounded, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nothing yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Start by creating a draft or opening the review pool to see activity here.',
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const MyHomePage(title: 'Exam Drafter Dashboard');
        }
        return const LoginPage();
      },
    );
  }
}
