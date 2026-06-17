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
import 'screens/delegation_page.dart';
import 'screens/question_drafting_page.dart';
import 'screens/review_pool_page.dart';
import 'screens/approved_questions_page.dart';
import 'screens/admin_review_screen.dart';
import 'screens/compliance_dashboard.dart';
import 'screens/profile_screen.dart';

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

  Widget _menuItem({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool showFull,
    required bool showIconOnly,
  }) {
    if (showFull) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    } else if (showIconOnly) {
      return IconButton(
        tooltip: label,
        icon: Icon(icon),
        onPressed: onPressed,
      );
    }
    return const SizedBox.shrink();
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

          _buildExtensionRequestsSection(),
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
            stream: isSuperAdmin
                ? _firestore
                    .collection('exam_requests')
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots()
                : _firestore
                    .collection('exam_requests')
                    .where('createdByUid', isEqualTo: AuthService().currentUser?.uid ?? '')
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const _EmptyActivityCard();
              }

              var docs = snapshot.data!.docs;
              if (!isSuperAdmin) {
                docs = List.from(docs);
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>?)?['createdAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>?)?['createdAt'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime); // descending
                });
                if (docs.length > 5) {
                  docs = docs.sublist(0, 5);
                }
              }

              return Column(
                children: docs.map((doc) {
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
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          if (status == 'submitted_to_admin' || status == 'approved') {
                            _open(const AdminReviewScreen());
                          } else if (status == 'commissioned' || status == 'returned_for_revision' || status == 'delegated') {
                            _open(const DelegationPage());
                          } else {
                            _open(const ReviewPoolPage());
                          }
                        },
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

  Widget _buildExtensionRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Pending Extension Requests',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('extension_requests')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'All extensions processed. No pending requests.',
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final extMap = doc.data() as Map<String, dynamic>;
                final extId = doc.id;
                final courseId = extMap['courseId'] ?? '';
                final examRequestId = extMap['examRequestId'] ?? '';
                final requestedDeadline = (extMap['requestedDeadline'] as Timestamp).toDate();
                final currentDeadline = (extMap['currentDeadline'] as Timestamp).toDate();
                final reason = extMap['reason'] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Course: $courseId',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'PENDING',
                                style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Current Internal Deadline: ${currentDeadline.toLocal().toString().split(' ')[0]}'),
                        Text(
                          'Requested New Deadline: ${requestedDeadline.toLocal().toString().split(' ')[0]}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reason: "$reason"',
                          style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                try {
                                  final batch = _firestore.batch();
                                  batch.update(_firestore.collection('extension_requests').doc(extId), {
                                    'status': 'rejected',
                                  });
                                  batch.set(_firestore.collection('notifications').doc(), {
                                    'title': 'Extension Request Rejected',
                                    'message': 'Extension request for course $courseId was rejected by Admin.',
                                    'type': 'extension_request_rejected',
                                    'relatedRequestId': examRequestId,
                                    'createdAt': Timestamp.fromDate(DateTime.now()),
                                  });
                                  await batch.commit();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  final batch = _firestore.batch();
                                  batch.update(_firestore.collection('extension_requests').doc(extId), {
                                    'status': 'approved',
                                  });
                                  batch.update(_firestore.collection('exam_requests').doc(examRequestId), {
                                    'internalDeadline': Timestamp.fromDate(requestedDeadline),
                                  });
                                  batch.set(_firestore.collection('notifications').doc(), {
                                    'title': 'Extension Request Approved',
                                    'message': 'Extension request for course $courseId was approved. New deadline: ${requestedDeadline.toLocal().toString().split(' ')[0]}.',
                                    'type': 'extension_request_approved',
                                    'relatedRequestId': examRequestId,
                                    'createdAt': Timestamp.fromDate(DateTime.now()),
                                  });
                                  await batch.commit();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text('Approve'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUserDashboard(BuildContext context, String displayName, Map<String, dynamic> roles) {
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
            'My Course Assignments & Roles',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (roles.entries.any((entry) => entry.key.startsWith('course_')))
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: roles.entries
                  .where((entry) => entry.key.startsWith('course_'))
                  .map((entry) {
                    final courseId = entry.key.replaceFirst('course_', '');
                    final role = entry.value;

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('courses').doc(courseId).get(),
                      builder: (context, snapshot) {
                        String courseName = courseId;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          courseName = '${data?['code'] ?? ''} - ${data?['name'] ?? ''}';
                        }

                        final roleColor = switch (role) {
                          'committee_lead' => const Color(0xFFD97706),
                          'committee_member' => const Color(0xFF2563EB),
                          _ => const Color(0xFF059669),
                        };

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                role == 'teacher' ? Icons.edit_note_rounded : Icons.supervised_user_circle_rounded,
                                color: roleColor,
                              ),
                            ),
                            title: Text(
                              courseName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              'Role: ${role.toString().replaceAll('_', ' ').toUpperCase()}',
                              style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(Icons.school_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No Course Assignments',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You currently have no active course roles. Please contact an Admin to assign you as a teacher or committee member.',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
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

        final isTeacher = roles.entries.any((entry) => entry.key.startsWith('course_') && entry.value == 'teacher');
        final isCommittee = roles.entries.any((entry) => entry.key.startsWith('course_') && (entry.value == 'committee_lead' || entry.value == 'committee_member'));

        final width = MediaQuery.of(context).size.width;
        final showFullMenu = width > 1300;
        final showCompactMenu = width > 900 && width <= 1300;

        final List<Widget> menuButtons = [];

        if (isSuperAdmin) {
          menuButtons.add(
            _menuItem(
              label: 'Taxonomy',
              icon: Icons.business_rounded,
              onPressed: () => _open(const TaxonomyManagementScreen()),
              showFull: showFullMenu,
              showIconOnly: showCompactMenu,
            ),
          );
        }

        if (isAnyAdmin) {
          menuButtons.addAll([
            _menuItem(
              label: 'Roles',
              icon: Icons.shield_rounded,
              onPressed: () => _open(const UserRolesScreen()),
              showFull: showFullMenu,
              showIconOnly: showCompactMenu,
            ),
            _menuItem(
              label: 'Commission',
              icon: Icons.assignment_rounded,
              onPressed: () => _open(const ExamCommissionForm()),
              showFull: showFullMenu,
              showIconOnly: showCompactMenu,
            ),
            _menuItem(
              label: 'Delegation',
              icon: Icons.assignment_ind_rounded,
              onPressed: () => _open(const DelegationPage()),
              showFull: showFullMenu,
              showIconOnly: showCompactMenu,
            ),
            _menuItem(
              label: 'Curation',
              icon: Icons.rate_review_rounded,
              onPressed: () => _open(const ReviewPoolPage()),
              showFull: showFullMenu,
              showIconOnly: showCompactMenu,
            ),
            _menuItem(
              label: 'Review Board',
              icon: Icons.verified_user_rounded,
              onPressed: () => _open(const AdminReviewScreen()),
              showFull: showFullMenu,
              showIconOnly: showCompactMenu,
            ),
            _menuItem(
              label: 'Question Bank',
              icon: Icons.library_books_rounded,
              onPressed: () => _open(const ApprovedQuestionsPage()),
              showFull: showFullMenu,
              showIconOnly: showCompactMenu,
            ),
          ]);
        } else {
          if (isTeacher) {
            menuButtons.add(
              _menuItem(
                label: 'Drafting',
                icon: Icons.edit_note_rounded,
                onPressed: () => _open(const QuestionDraftingPage()),
                showFull: showFullMenu,
                showIconOnly: showCompactMenu,
              ),
            );
          }
          if (isCommittee) {
            menuButtons.addAll([
              _menuItem(
                label: 'Delegation',
                icon: Icons.assignment_ind_rounded,
                onPressed: () => _open(const DelegationPage()),
                showFull: showFullMenu,
                showIconOnly: showCompactMenu,
              ),
              _menuItem(
                label: 'Curation',
                icon: Icons.rate_review_rounded,
                onPressed: () => _open(const ReviewPoolPage()),
                showFull: showFullMenu,
                showIconOnly: showCompactMenu,
              ),
              _menuItem(
                label: 'Compliance',
                icon: Icons.warning_amber_rounded,
                onPressed: () => _open(const ComplianceDashboard()),
                showFull: showFullMenu,
                showIconOnly: showCompactMenu,
              ),
            ]);
          }
        }

        // Clean out empty placeholders from list
        menuButtons.removeWhere((w) => w is SizedBox);

        // Build mobile drawer if screen is narrow
        Widget? mobileDrawer;
        if (!showFullMenu && !showCompactMenu) {
          mobileDrawer = Drawer(
            child: SafeArea(
              child: Column(
                children: [
                  UserAccountsDrawerHeader(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                      ),
                    ),
                    accountName: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    accountEmail: Text(
                      AuthService().currentUser?.email ?? '',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        if (isSuperAdmin)
                          ListTile(
                            leading: const Icon(Icons.business_rounded, color: Color(0xFF1D4ED8)),
                            title: const Text('Taxonomy Management'),
                            onTap: () {
                              Navigator.pop(context);
                              _open(const TaxonomyManagementScreen());
                            },
                          ),
                        if (isAnyAdmin) ...[
                          ListTile(
                            leading: const Icon(Icons.shield_rounded, color: Color(0xFF1D4ED8)),
                            title: const Text('User Role Management'),
                            onTap: () {
                              Navigator.pop(context);
                              _open(const UserRolesScreen());
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.assignment_rounded, color: Color(0xFF1D4ED8)),
                            title: const Text('Commission Exam'),
                            onTap: () {
                              Navigator.pop(context);
                              _open(const ExamCommissionForm());
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF1D4ED8)),
                            title: const Text('Committee Delegation'),
                            onTap: () {
                              Navigator.pop(context);
                              _open(const DelegationPage());
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.rate_review_rounded, color: Color(0xFF1D4ED8)),
                            title: const Text('Curation Board'),
                            onTap: () {
                              Navigator.pop(context);
                              _open(const ReviewPoolPage());
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.verified_user_rounded, color: Color(0xFF1D4ED8)),
                            title: const Text('Exam Review Board'),
                            onTap: () {
                              Navigator.pop(context);
                              _open(const AdminReviewScreen());
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.library_books_rounded, color: Color(0xFF1D4ED8)),
                            title: const Text('Question Bank Library'),
                            onTap: () {
                              Navigator.pop(context);
                              _open(const ApprovedQuestionsPage());
                            },
                          ),
                        ] else ...[
                          if (isTeacher)
                            ListTile(
                              leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF1D4ED8)),
                              title: const Text('MCQ Drafting Workspace'),
                              onTap: () {
                                Navigator.pop(context);
                                _open(const QuestionDraftingPage());
                              },
                            ),
                          if (isCommittee) ...[
                            ListTile(
                              leading: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF1D4ED8)),
                              title: const Text('Committee Delegation'),
                              onTap: () {
                                Navigator.pop(context);
                                _open(const DelegationPage());
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.rate_review_rounded, color: Color(0xFF1D4ED8)),
                              title: const Text('Curation Board'),
                              onTap: () {
                                Navigator.pop(context);
                                _open(const ReviewPoolPage());
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFF1D4ED8)),
                              title: const Text('Compliance Board'),
                              onTap: () {
                                Navigator.pop(context);
                                _open(const ComplianceDashboard());
                              },
                            ),
                          ],
                        ],
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.person_rounded, color: Color(0xFF1D4ED8)),
                          title: const Text('My Profile'),
                          onTap: () {
                            Navigator.pop(context);
                            _open(const ProfileScreen());
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                          title: const Text('Sign Out'),
                          onTap: () {
                            Navigator.pop(context);
                            _signOut();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

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
              ...menuButtons,
              if (showFullMenu || showCompactMenu) ...[
                IconButton(
                  tooltip: 'My Profile',
                  icon: const Icon(Icons.person_rounded),
                  onPressed: () => _open(const ProfileScreen()),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Sign Out',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: _signOut,
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
          drawer: mobileDrawer,
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
