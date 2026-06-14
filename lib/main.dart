import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login_page.dart';
import 'screens/taxonomy_management_screen.dart';
import 'screens/user_roles_screen.dart';
import 'screens/exam_commission_form.dart';
import 'screens/committee_delegation_screen.dart';
import 'screens/teacher_drafting_screen.dart';
import 'screens/committee_curation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      if (mounted) {
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

  Widget _buildAdminDashboard(BuildContext context, bool isSuperAdmin, String displayName, Map<String, dynamic> roles) {
    return SingleChildScrollView(
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
                        'Administrative portal',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hello, $displayName!',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Manage taxonomy hierarchy, assign user roles, and commission exam requests.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        const Chip(
                          label: Text('Hierarchy'),
                          backgroundColor: Colors.white,
                        ),
                        const Chip(
                          label: Text('Role Assignments'),
                          backgroundColor: Colors.white,
                        ),
                        const Chip(
                          label: Text('Commissioning'),
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
                          'Portal status',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 12),
                        const _FocusItem(
                          icon: Icons.check_circle_outline_rounded,
                          text: 'Taxonomy management active.',
                        ),
                        const _FocusItem(
                          icon: Icons.check_circle_outline_rounded,
                          text: 'Role configurations online.',
                        ),
                        const _FocusItem(
                          icon: Icons.check_circle_outline_rounded,
                          text: 'Exam request submission open.',
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
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('departments').snapshots(),
                      builder: (context, snap) {
                        final count = snap.hasData ? snap.data!.docs.length : 0;
                        return _metricCard('Departments', '$count', Icons.business_rounded, const Color(0xFF2563EB));
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('sections').snapshots(),
                      builder: (context, snap) {
                        final count = snap.hasData ? snap.data!.docs.length : 0;
                        return _metricCard('Sections', '$count', Icons.layers_rounded, const Color(0xFF8B5CF6));
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('courses').snapshots(),
                      builder: (context, snap) {
                        final count = snap.hasData ? snap.data!.docs.length : 0;
                        return _metricCard('Courses', '$count', Icons.school_rounded, const Color(0xFF10B981));
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('exam_requests').snapshots(),
                      builder: (context, snap) {
                        final count = snap.hasData ? snap.data!.docs.length : 0;
                        return _metricCard('Exam Requests', '$count', Icons.assignment_rounded, const Color(0xFFF59E0B));
                      },
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
              if (isSuperAdmin)
                SizedBox(
                  width: 320,
                  child: _actionCard(
                    title: 'Taxonomy Management',
                    subtitle: 'Define departments, sections, courses, and topics.',
                    icon: Icons.business_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: () => _open(const TaxonomyManagementScreen()),
                  ),
                ),
              SizedBox(
                width: 320,
                child: _actionCard(
                  title: 'User Role Management',
                  subtitle: 'Manage permissions and assign teachers to courses.',
                  icon: Icons.shield_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => _open(const UserRolesScreen()),
                ),
              ),
              SizedBox(
                width: 320,
                child: _actionCard(
                  title: 'Commission Exam Paper',
                  subtitle: 'Create a new exam request for a course section.',
                  icon: Icons.assignment_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _open(const ExamCommissionForm()),
                ),
              ),
              SizedBox(
                width: 320,
                child: _actionCard(
                  title: 'Committee Delegation',
                  subtitle: 'Set timelines and split quotas among teachers.',
                  icon: Icons.assignment_ind_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _open(const CommitteeDelegationScreen()),
                ),
              ),
              SizedBox(
                width: 320,
                child: _actionCard(
                  title: 'Curation Board',
                  subtitle: 'Collaborate on question selection and voting.',
                  icon: Icons.rate_review_rounded,
                  color: const Color(0xFFEC4899),
                  onTap: () => _open(const CommitteeCurationScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent exam requests',
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
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('exam_requests')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const _EmptyActivityCard();
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final req = doc.data() as Map<String, dynamic>;
                  final status = req['status'] ?? 'commissioned';
                  final courseId = req['courseId'] ?? '';
                  final section = req['section'] ?? '';
                  final totalQ = req['questionCount'] ?? 0;

                  final statusColor = switch (status) {
                    'approved' => const Color(0xFF10B981),
                    'submitted_to_admin' => const Color(0xFF0EA5E9),
                    'commissioned' => const Color(0xFFF59E0B),
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
                                Icons.assignment_rounded,
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
                                        child: FutureBuilder<DocumentSnapshot>(
                                          future: _firestore.collection('courses').doc(courseId).get(),
                                          builder: (context, courseSnapshot) {
                                            String courseText = courseId;
                                            if (courseSnapshot.hasData && courseSnapshot.data!.exists) {
                                              final cData = courseSnapshot.data!.data() as Map<String, dynamic>?;
                                              courseText = '${cData?['code'] ?? ''} - ${cData?['name'] ?? ''}';
                                            }
                                            return Text(
                                              'Exam request for $courseText',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Chip(
                                        label: Text(status.toString().toUpperCase()),
                                        backgroundColor: statusColor.withValues(alpha: 0.12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: [
                                      Chip(label: Text('Section: $section')),
                                      Chip(label: Text('$totalQ questions quota')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserDashboard(BuildContext context, String displayName, Map<String, dynamic> roles) {
    final isTeacher = roles.entries.any((entry) => entry.key.startsWith('course_') && entry.value == 'teacher');
    final isCommittee = roles.entries.any((entry) => entry.key.startsWith('course_') && (entry.value == 'committee_lead' || entry.value == 'committee_member'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $displayName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome to Exam Drafter. Access your question drafting and curation workflows below.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (isTeacher)
                SizedBox(
                  width: 320,
                  child: _actionCard(
                    title: 'MCQ Drafting Workspace',
                    subtitle: 'Create, edit, and submit delegated exam questions.',
                    icon: Icons.edit_note_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: () => _open(const TeacherDraftingScreen()),
                  ),
                ),
              if (isCommittee) ...[
                SizedBox(
                  width: 320,
                  child: _actionCard(
                    title: 'Committee Delegation',
                    subtitle: 'Set timelines and split quotas among teachers.',
                    icon: Icons.assignment_ind_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () => _open(const CommitteeDelegationScreen()),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: _actionCard(
                    title: 'Curation Board',
                    subtitle: 'Collaborate on question selection and voting.',
                    icon: Icons.rate_review_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () => _open(const CommitteeCurationScreen()),
                  ),
                ),
              ],
              if (!isTeacher && !isCommittee)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'You currently have no active course roles. Please contact an Admin to assign you as a teacher or committee member.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('users')
          .doc(AuthService().currentUser?.uid ?? 'unknown')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final displayName = data?['displayName'] ?? 'User';
        final roles = data?['roles'] as Map<String, dynamic>? ?? {};
        final globalRole = roles['global'] ?? 'user';

        final isSuperAdmin = globalRole == 'super_admin';
        final isAdmin = globalRole == 'admin';
        final isAnyAdmin = isSuperAdmin || isAdmin;

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
                  isAnyAdmin ? 'Administrative Control Center' : 'Teacher & Committee Portal',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.blueGrey.shade600),
                ),
              ],
            ),
            actions: [
              if (isSuperAdmin)
                TextButton.icon(
                  onPressed: () => _open(const TaxonomyManagementScreen()),
                  icon: const Icon(Icons.business_rounded),
                  label: const Text('Taxonomy'),
                ),
              if (isAnyAdmin) ...[
                TextButton.icon(
                  onPressed: () => _open(const UserRolesScreen()),
                  icon: const Icon(Icons.shield_rounded),
                  label: const Text('Roles'),
                ),
                TextButton.icon(
                  onPressed: () => _open(const ExamCommissionForm()),
                  icon: const Icon(Icons.assignment_rounded),
                  label: const Text('Commission'),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Sign Out',
                icon: const Icon(Icons.logout_rounded),
                onPressed: _signOut,
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: isAnyAdmin
              ? _buildAdminDashboard(context, isSuperAdmin, displayName, roles)
              : _buildUserDashboard(context, displayName, roles),
        );
      },
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
                    'No requests yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Commission an exam request to see activity here.',
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
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          _ensureUserDocumentExists(snapshot.data!);
          return const MyHomePage(title: 'Exam Drafter Dashboard');
        }
        return const LoginPage();
      },
    );
  }

  void _ensureUserDocumentExists(User user) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'email': user.email ?? '',
          'displayName': user.displayName ?? (user.email ?? 'User').split('@')[0],
          'createdAt': FieldValue.serverTimestamp(),
          'roles': {
            'global': 'user',
          },
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error ensuring user document exists: $e');
    }
  }
}
