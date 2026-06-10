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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
        useMaterial3: true,
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              try {
                await AuthService().signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(AuthService().currentUser?.uid ?? 'unknown')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final roles = data?['roles'] as Map<String, dynamic>? ?? {};
            final globalRole = roles['global'] ?? 'user';

            final isSuperAdmin = globalRole == 'super_admin';
            final isAdmin = globalRole == 'admin';
            final isAnyAdmin = isSuperAdmin || isAdmin;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Exam Drafter',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSuperAdmin
                            ? 'Super Admin Panel'
                            : (isAdmin ? 'Admin Panel' : 'User Portal'),
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.dashboard_rounded,
                    color: Color(0xFF1E3A8A),
                  ),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                if (isSuperAdmin)
                  ListTile(
                    leading: const Icon(
                      Icons.business_rounded,
                      color: Color(0xFF1E3A8A),
                    ),
                    title: const Text('Taxonomy Management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TaxonomyManagementScreen(),
                        ),
                      );
                    },
                  ),
                if (isAnyAdmin)
                  ListTile(
                    leading: const Icon(
                      Icons.shield_rounded,
                      color: Color(0xFF1E3A8A),
                    ),
                    title: const Text('User Role Management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserRolesScreen(),
                        ),
                      );
                    },
                  ),
                if (isAnyAdmin)
                  ListTile(
                    leading: const Icon(
                      Icons.assignment_rounded,
                      color: Color(0xFF1E3A8A),
                    ),
                    title: const Text('Commission Exam'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExamCommissionForm(),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: Color(0xFF3B82F6),
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to Exam Drafter',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Institutional Exam Drafting Portal',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Core portal views are under active development.',
                              style: TextStyle(
                                color: const Color(0xFF92400E),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Use the side navigation menu to access available features, or use the quick shortcut below to manage hierarchy taxonomy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TaxonomyManagementScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.business_rounded),
                      label: const Text('Go to Taxonomy Management'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
