import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _aboutController;
  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _userProfile;

  static const primaryBlue = Color(0xFF1D4ED8);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _aboutController = TextEditingController();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          _userProfile = UserProfile.fromMap(doc.data()!, doc.id);
          _nameController.text = _userProfile?.displayName ?? '';
          _aboutController.text = _userProfile?.about ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isSaving = true;
    });

    try {
      final uid = _userProfile?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'displayName': _nameController.text.trim(),
          'about': _aboutController.text.trim(),
        });

        try {
          await _authService.currentUser?.updateDisplayName(_nameController.text.trim());
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully.')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(36.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Profile Avatar
                            Center(
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: primaryBlue.withValues(alpha: 0.1),
                                child: Text(
                                  (_nameController.text.isNotEmpty
                                          ? _nameController.text
                                          : (_userProfile?.email ?? 'U'))
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Email (Readonly)
                            TextFormField(
                              initialValue: _userProfile?.email,
                              readOnly: true,
                              enabled: false,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Display Name
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Display Name',
                                prefixIcon: Icon(Icons.person_outline),
                                hintText: 'Enter your name...',
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Display name is required.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // About Info
                            TextFormField(
                              controller: _aboutController,
                              maxLines: 4,
                              keyboardType: TextInputType.multiline,
                              decoration: const InputDecoration(
                                labelText: 'About Me',
                                prefixIcon: Icon(Icons.info_outline_rounded),
                                hintText: 'Tell us a bit about yourself...',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Display Roles context
                            const Text(
                              'Assigned Roles & Contexts',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_userProfile?.roles != null &&
                                _userProfile!.roles.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _userProfile!.roles.entries.map((entry) {
                                  final contextId = entry.key;
                                  final role = entry.value;
                                  final displayContext = contextId == 'global'
                                      ? 'Global Role'
                                      : 'Course: $contextId';
                                  return Chip(
                                    label: Text(
                                      '$displayContext: ${role.toUpperCase()}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: primaryBlue.withValues(alpha: 0.08),
                                  );
                                }).toList(),
                              )
                            else
                              const Text(
                                'No roles assigned yet.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            const SizedBox(height: 36),

                            // Save Button
                            ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
