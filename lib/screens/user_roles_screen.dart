import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserRolesScreen extends StatefulWidget {
  const UserRolesScreen({super.key});

  @override
  State<UserRolesScreen> createState() => _UserRolesScreenState();
}

class _UserRolesScreenState extends State<UserRolesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  static const primaryBlue = Color(0xFF1E3A8A);
  static const accentBlue = Color(0xFF3B82F6);
  static const lightBlueBg = Color(0xFFEFF6FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Role Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Registered Users',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search by email or name...',
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // User List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: accentBlue));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final users = snapshot.data!.docs
                      .map((doc) => UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                      .where((u) {
                        final email = u.email.toLowerCase();
                        final name = (u.displayName ?? '').toLowerCase();
                        return email.contains(_searchQuery) || name.contains(_searchQuery);
                      })
                      .toList();

                  if (users.isEmpty) {
                    return _buildEmptyState(title: 'No matching users found');
                  }

                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (context, idx) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final user = users[idx];
                      final globalRole = user.roles['global'] ?? 'user';

                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: lightBlueBg,
                                child: Text(
                                  (user.displayName ?? user.email).substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName ?? 'Unnamed User',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryBlue),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.email,
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 10),
                                    // Roles indicators
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        // Global Role chip
                                        Chip(
                                          label: Text(
                                            'Global: ${globalRole.replaceAll('_', ' ').toUpperCase()}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          backgroundColor: _getRoleColor(globalRole),
                                          side: BorderSide.none,
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        // Context specific roles count
                                        if (user.roles.length > 1)
                                          Chip(
                                            label: Text(
                                              '${user.roles.length - 1} Course Roles',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primaryBlue),
                                            ),
                                            backgroundColor: lightBlueBg,
                                            side: BorderSide.none,
                                            padding: EdgeInsets.zero,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.shield_rounded, size: 16),
                                label: const Text('Manage Roles'),
                                onPressed: () => _showManageRolesDialog(user),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return const Color(0xFFDC2626); // Red
      case 'admin':
        return const Color(0xFFD97706); // Orange
      default:
        return const Color(0xFF059669); // Green
    }
  }

  Widget _buildEmptyState({String title = 'No users registered'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
          ),
          const SizedBox(height: 8),
          Text(
            'Ensure users register and log in at least once to populate their profile documents.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- Manage Roles Dialog ---
  void _showManageRolesDialog(UserProfile user) {
    final Map<String, String> tempRoles = Map.from(user.roles);
    String globalRole = tempRoles['global'] ?? 'user';

    // Temp selection for adding course-specific roles
    String? selectedCourseId;
    String selectedContextRole = 'teacher';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Manage Roles: ${user.displayName ?? user.email}'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Global Role Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: globalRole,
                        decoration: const InputDecoration(labelText: 'Global Role'),
                        items: const [
                          DropdownMenuItem(value: 'user', child: Text('User (Default)')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              globalRole = val;
                              tempRoles['global'] = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Course-Specific Access / Roles',
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 15),
                      ),
                      const SizedBox(height: 12),

                      // Add course-specific role controls
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 2,
                            child: StreamBuilder<QuerySnapshot>(
                              stream: _firestore.collection('courses').snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const LinearProgressIndicator();
                                final docs = snapshot.data!.docs;

                                // Filter out already selected courses in UI to prevent duplicates
                                final availableDocs = docs.where((doc) => !tempRoles.containsKey('course_${doc.id}')).toList();

                                return DropdownButtonFormField<String>(
                                  initialValue: selectedCourseId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Course'),
                                  items: availableDocs.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text('${data['code']} - ${data['name']}'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      selectedCourseId = val;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedContextRole,
                              decoration: const InputDecoration(labelText: 'Role'),
                              items: const [
                                DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                                DropdownMenuItem(value: 'committee_member', child: Text('Committee')),
                                DropdownMenuItem(value: 'committee_lead', child: Text('Committee Lead')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedContextRole = val;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: accentBlue, size: 36),
                            onPressed: selectedCourseId == null
                                ? null
                                : () {
                                    setDialogState(() {
                                      tempRoles['course_$selectedCourseId'] = selectedContextRole;
                                      selectedCourseId = null; // Reset selection
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Display list of currently assigned context roles
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.all(8),
                          children: tempRoles.keys
                              .where((key) => key.startsWith('course_'))
                              .map((key) {
                                final courseId = key.replaceFirst('course_', '');
                                final role = tempRoles[key]!;

                                return FutureBuilder<DocumentSnapshot>(
                                  future: _firestore.collection('courses').doc(courseId).get(),
                                  builder: (context, snapshot) {
                                    String details = 'Course: $courseId';
                                    if (snapshot.hasData && snapshot.data!.exists) {
                                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                                      details = '${data?['code'] ?? ''} - ${data?['name'] ?? ''}';
                                    }

                                    return ListTile(
                                      title: Text(details, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      subtitle: Text(
                                        role.replaceAll('_', ' ').toUpperCase(),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentBlue),
                                      ),
                                      dense: true,
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () {
                                          setDialogState(() {
                                            tempRoles.remove(key);
                                          });
                                        },
                                      ),
                                    );
                                  },
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Update user profile document in Firestore
                    await _firestore.collection('users').doc(user.uid).set({
                      'roles': tempRoles,
                    }, SetOptions(merge: true));

                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
