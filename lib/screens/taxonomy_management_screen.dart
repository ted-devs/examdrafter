import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/taxonomy.dart';

class TaxonomyManagementScreen extends StatefulWidget {
  const TaxonomyManagementScreen({super.key});

  @override
  State<TaxonomyManagementScreen> createState() => _TaxonomyManagementScreenState();
}

class _TaxonomyManagementScreenState extends State<TaxonomyManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Search queries
  String _deptSearch = '';
  String _courseSearch = '';
  String _topicSearch = '';
  String _sectionSearch = '';

  // Selection states for visualization
  String? _selectedDepartmentId;
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Define colors for the blue-and-white theme
  static const primaryBlue = Color(0xFF1E3A8A); // Deep Blue
  static const accentBlue = Color(0xFF3B82F6); // Vibrant Blue
  static const lightBlueBg = Color(0xFFEFF6FF); // Light Blue Background
  static const darkGrey = Color(0xFF374151);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Taxonomy & Hierarchy Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded), text: 'Departments'),
            Tab(icon: Icon(Icons.school_rounded), text: 'Courses'),
            Tab(icon: Icon(Icons.topic_rounded), text: 'Topics'),
            Tab(icon: Icon(Icons.layers_rounded), text: 'Sections'),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDepartmentsTab(theme),
            _buildCoursesTab(theme),
            _buildTopicsTab(theme),
            _buildSectionsTab(theme),
          ],
        ),
      ),
    );
  }

  // ================= DEPARTMENTS TAB =================

  Widget _buildDepartmentsTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderSection(
            title: 'Manage Departments',
            subtitle: 'Define institutional departments that house courses.',
            buttonText: 'Add Department',
            onSearchChanged: (val) => setState(() => _deptSearch = val.toLowerCase()),
            onButtonPressed: () => _showAddEditDepartmentDialog(),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('departments').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: accentBlue));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState('No departments found', 'Create a department to get started.');
                }

                final depts = snapshot.data!.docs
                    .map((doc) => Department.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .where((d) => d.name.toLowerCase().contains(_deptSearch) || d.code.toLowerCase().contains(_deptSearch))
                    .toList();

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 160,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: depts.length,
                  itemBuilder: (context, idx) {
                    final dept = depts[idx];
                    final isSelected = _selectedDepartmentId == dept.id;

                    return Card(
                      color: isSelected ? lightBlueBg : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? accentBlue : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _selectedDepartmentId = isSelected ? null : dept.id;
                            // Reset course selection when department selection changes
                            _selectedCourseId = null;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? accentBlue.withValues(alpha: 0.15) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      dept.code.toUpperCase(),
                                      style: TextStyle(
                                        color: isSelected ? primaryBlue : darkGrey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                                        onPressed: () => _showAddEditDepartmentDialog(department: dept),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                        onPressed: () => _showDeleteConfirmation(
                                          title: 'Delete Department',
                                          content: 'Are you sure you want to delete department "${dept.name}"? This will not automatically delete courses.',
                                          onConfirm: () => _firestore.collection('departments').doc(dept.id).delete(),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  dept.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  // ================= COURSES TAB =================

  Widget _buildCoursesTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderSection(
            title: 'Manage Courses',
            subtitle: _selectedDepartmentId != null
                ? 'Showing courses in selected department.'
                : 'Define courses and assign them to departments.',
            buttonText: 'Add Course',
            onSearchChanged: (val) => setState(() => _courseSearch = val.toLowerCase()),
            onButtonPressed: () => _showAddEditCourseDialog(),
            filterActive: _selectedDepartmentId != null,
            onClearFilter: () => setState(() => _selectedDepartmentId = null),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('courses').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: accentBlue));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState('No courses found', 'Create a course to populate this list.');
                }

                // Filter by department selection and search query
                var courses = snapshot.data!.docs
                    .map((doc) => Course.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                if (_selectedDepartmentId != null) {
                  courses = courses.where((c) => c.departmentId == _selectedDepartmentId).toList();
                }

                courses = courses
                    .where((c) => c.name.toLowerCase().contains(_courseSearch) || c.code.toLowerCase().contains(_courseSearch))
                    .toList();

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 180,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: courses.length,
                  itemBuilder: (context, idx) {
                    final course = courses[idx];
                    final isSelected = _selectedCourseId == course.id;

                    return Card(
                      color: isSelected ? lightBlueBg : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? accentBlue : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _selectedCourseId = isSelected ? null : course.id;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? accentBlue.withValues(alpha: 0.15) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      course.code.toUpperCase(),
                                      style: TextStyle(
                                        color: isSelected ? primaryBlue : darkGrey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                                        onPressed: () => _showAddEditCourseDialog(course: course),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                        onPressed: () => _showDeleteConfirmation(
                                          title: 'Delete Course',
                                          content: 'Are you sure you want to delete course "${course.name}"?',
                                          onConfirm: () => _firestore.collection('courses').doc(course.id).delete(),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Text(
                                  course.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Fetch department code asynchronously or simply query
                              FutureBuilder<DocumentSnapshot>(
                                future: _firestore.collection('departments').doc(course.departmentId).get(),
                                builder: (context, deptSnapshot) {
                                  String deptCode = '...';
                                  if (deptSnapshot.hasData && deptSnapshot.data!.exists) {
                                    final data = deptSnapshot.data!.data() as Map<String, dynamic>?;
                                    deptCode = (data?['code'] ?? '').toString().toUpperCase();
                                  }
                                  return Text(
                                    'Dept: $deptCode',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              )
                            ],
                          ),
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
    );
  }

  // ================= TOPICS TAB =================

  Widget _buildTopicsTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderSection(
            title: 'Manage Topics',
            subtitle: _selectedCourseId != null
                ? 'Showing topics mapped to selected course.'
                : 'Define core learning topics spanning multiple courses.',
            buttonText: 'Add Topic',
            onSearchChanged: (val) => setState(() => _topicSearch = val.toLowerCase()),
            onButtonPressed: () => _showAddEditTopicDialog(),
            filterActive: _selectedCourseId != null,
            onClearFilter: () => setState(() => _selectedCourseId = null),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('topics').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: accentBlue));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState('No topics found', 'Create a topic to complete the taxonomy.');
                }

                var topics = snapshot.data!.docs
                    .map((doc) => Topic.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                if (_selectedCourseId != null) {
                  topics = topics.where((t) => t.courseIds.contains(_selectedCourseId)).toList();
                }

                topics = topics.where((t) => t.name.toLowerCase().contains(_topicSearch)).toList();

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 180,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: topics.length,
                  itemBuilder: (context, idx) {
                    final topic = topics[idx];

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.topic_rounded, color: primaryBlue, size: 24),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                                      onPressed: () => _showAddEditTopicDialog(topic: topic),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                      onPressed: () => _showDeleteConfirmation(
                                        title: 'Delete Topic',
                                        content: 'Are you sure you want to delete topic "${topic.name}"?',
                                        onConfirm: () => _firestore.collection('topics').doc(topic.id).delete(),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Text(
                                topic.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Wrap(
                                spacing: 6,
                                children: topic.courseIds.map((cId) {
                                  return FutureBuilder<DocumentSnapshot>(
                                    future: _firestore.collection('courses').doc(cId).get(),
                                    builder: (context, courseSnapshot) {
                                      String courseName = '...';
                                      if (courseSnapshot.hasData && courseSnapshot.data!.exists) {
                                        final data = courseSnapshot.data!.data() as Map<String, dynamic>?;
                                        courseName = (data?['code'] ?? '').toString().toUpperCase();
                                      }
                                      return Chip(
                                        label: Text(
                                          courseName,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                        ),
                                        backgroundColor: lightBlueBg,
                                        side: BorderSide.none,
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      );
                                    },
                                  );
                                }).toList(),
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
    );
  }

  // ================= GENERAL WIDGET BUILDERS =================

  Widget _buildHeaderSection({
    required String title,
    required String subtitle,
    required String buttonText,
    required ValueChanged<String> onSearchChanged,
    required VoidCallback onButtonPressed,
    bool filterActive = false,
    VoidCallback? onClearFilter,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(buttonText),
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          if (filterActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: orangeAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: orangeAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_alt_rounded, size: 16, color: orangeAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Active parent filter applied',
                    style: TextStyle(fontSize: 13, color: orangeAccent, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onClearFilter,
                    child: const Icon(Icons.cancel_rounded, size: 16, color: orangeAccent),
                  )
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by keyword...',
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
    );
  }

  static const orangeAccent = Color(0xFFEA580C);

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ================= DIALOGS AND EDITING =================

  // --- Department Form Dialog ---
  void _showAddEditDepartmentDialog({Department? department}) {
    final nameController = TextEditingController(text: department?.name);
    final codeController = TextEditingController(text: department?.code);
    final isEdit = department != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Department' : 'Create Department'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Department Name', hintText: 'e.g. Computer Science'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Department Code', hintText: 'e.g. CS'),
                maxLength: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final code = codeController.text.trim();
                if (name.isEmpty || code.isEmpty) return;

                if (isEdit) {
                  await _firestore.collection('departments').doc(department.id).update({
                    'name': name,
                    'code': code,
                  });
                } else {
                  await _firestore.collection('departments').add({
                    'name': name,
                    'code': code,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                }
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
              child: Text(isEdit ? 'Save Changes' : 'Create'),
            ),
          ],
        );
      },
    );
  }

  // --- Course Form Dialog ---
  void _showAddEditCourseDialog({Course? course}) {
    final nameController = TextEditingController(text: course?.name);
    final codeController = TextEditingController(text: course?.code);
    String? selectedDeptId = course?.departmentId ?? _selectedDepartmentId;
    final isEdit = course != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Course' : 'Create Course'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dropdown to choose department
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('departments').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();

                      final depts = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        initialValue: selectedDeptId,
                        decoration: const InputDecoration(labelText: 'Department'),
                        items: depts.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text('${data['code']} - ${data['name']}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedDeptId = val;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Course Name', hintText: 'e.g. Data Structures'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(labelText: 'Course Code', hintText: 'e.g. CS102'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final code = codeController.text.trim();
                    if (name.isEmpty || code.isEmpty || selectedDeptId == null) return;

                    if (isEdit) {
                      await _firestore.collection('courses').doc(course.id).update({
                        'name': name,
                        'code': code,
                        'departmentId': selectedDeptId,
                      });
                    } else {
                      await _firestore.collection('courses').add({
                        'name': name,
                        'code': code,
                        'departmentId': selectedDeptId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Changes' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Topic Form Dialog ---
  void _showAddEditTopicDialog({Topic? topic}) {
    final nameController = TextEditingController(text: topic?.name);
    final List<String> selectedCourses = List.from(topic?.courseIds ?? []);
    if (selectedCourses.isEmpty && _selectedCourseId != null) {
      selectedCourses.add(_selectedCourseId!);
    }
    final isEdit = topic != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Topic' : 'Create Topic'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Topic Name', hintText: 'e.g. Binary Search Trees'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Associate with Course(s):',
                      style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    // Show a scrollable checklist of courses
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('courses').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final docs = snapshot.data!.docs;
                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, idx) {
                              final doc = docs[idx];
                              final data = doc.data() as Map<String, dynamic>;
                              final cId = doc.id;
                              final cCode = (data['code'] ?? '').toString().toUpperCase();
                              final cName = data['name'] ?? '';
                              final checked = selectedCourses.contains(cId);

                              return CheckboxListTile(
                                title: Text('$cCode - $cName', style: const TextStyle(fontSize: 13)),
                                value: checked,
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedCourses.add(cId);
                                    } else {
                                      selectedCourses.remove(cId);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty || selectedCourses.isEmpty) return;

                    if (isEdit) {
                      await _firestore.collection('topics').doc(topic.id).update({
                        'name': name,
                        'courseIds': selectedCourses,
                      });
                    } else {
                      await _firestore.collection('topics').add({
                        'name': name,
                        'courseIds': selectedCourses,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Changes' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= SECTIONS TAB =================

  Widget _buildSectionsTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderSection(
            title: 'Manage Sections',
            subtitle: _selectedCourseId != null
                ? 'Showing sections in selected course.'
                : 'Define sections associated with courses.',
            buttonText: 'Add Section',
            onSearchChanged: (val) => setState(() => _sectionSearch = val.toLowerCase()),
            onButtonPressed: () => _showAddEditSectionDialog(),
            filterActive: _selectedCourseId != null,
            onClearFilter: () => setState(() => _selectedCourseId = null),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('sections').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: accentBlue));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState('No sections found', 'Create a section to populate this list.');
                }

                // Filter by course selection and search query
                var sections = snapshot.data!.docs
                    .map((doc) => Section.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                if (_selectedCourseId != null) {
                  sections = sections.where((s) => s.courseId == _selectedCourseId).toList();
                }

                sections = sections
                    .where((s) => s.name.toLowerCase().contains(_sectionSearch))
                    .toList();

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 180,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (context, idx) {
                    final section = sections[idx];

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.layers_rounded, color: primaryBlue, size: 24),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                                      onPressed: () => _showAddEditSectionDialog(section: section),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                      onPressed: () => _showDeleteConfirmation(
                                        title: 'Delete Section',
                                        content: 'Are you sure you want to delete section "${section.name}"?',
                                        onConfirm: () => _firestore.collection('sections').doc(section.id).delete(),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Text(
                                section.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Fetch course code/name asynchronously
                            FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('courses').doc(section.courseId).get(),
                              builder: (context, courseSnapshot) {
                                String courseCode = '...';
                                if (courseSnapshot.hasData && courseSnapshot.data!.exists) {
                                  final data = courseSnapshot.data!.data() as Map<String, dynamic>?;
                                  courseCode = (data?['code'] ?? '').toString().toUpperCase();
                                }
                                return Text(
                                  'Course: $courseCode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            )
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
    );
  }

  // --- Section Form Dialog ---
  void _showAddEditSectionDialog({Section? section}) {
    final nameController = TextEditingController(text: section?.name);
    String? selectedCourseId = section?.courseId ?? _selectedCourseId;
    final isEdit = section != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Section' : 'Create Section'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dropdown to choose course
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('courses').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();

                      final courses = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        initialValue: selectedCourseId,
                        decoration: const InputDecoration(labelText: 'Course'),
                        items: courses.map((doc) {
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Section Name', hintText: 'e.g. Section A'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty || selectedCourseId == null) return;

                    if (isEdit) {
                      await _firestore.collection('sections').doc(section.id).update({
                        'name': name,
                        'courseId': selectedCourseId,
                      });
                    } else {
                      await _firestore.collection('sections').add({
                        'name': name,
                        'courseId': selectedCourseId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Changes' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Deletion Confirmation Dialog ---
  void _showDeleteConfirmation({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Text(content),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onConfirm();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
