# Part 3 — PDF Export & Logo Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `generateExamPdf` Firebase Cloud Function (Node.js + PDFKit) and the logo upload Flutter UI, testable end-to-end with seeded Firestore data.

**Architecture:** An HTTP callable Cloud Function fetches exam data from Firestore, generates Set A and/or Set B PDFs with PDFKit, uploads them to Firebase Storage, and returns signed download URLs. Flutter handles logo upload to Storage before triggering the function, then displays the returned links.

**Tech Stack:** Node.js 20, Firebase Functions v2, PDFKit, Jest, Flutter, firebase_storage, cloud_functions, file_picker, url_launcher.

---

## File Structure

**Cloud Functions (new `functions/` directory):**
- `functions/package.json` — dependencies and Jest config
- `functions/index.js` — exports the callable function
- `functions/src/randomize.js` — Fisher-Yates shuffle (pure function)
- `functions/src/pdfBuilder.js` — PDF layout and rendering with PDFKit
- `functions/src/generateExamPdf.js` — orchestration: Firestore → PDF → Storage → return URLs
- `functions/test/randomize.test.js` — Jest tests
- `functions/test/pdfBuilder.test.js` — Jest tests
- `functions/scripts/seedFirestore.js` — seeds test exam + questions

**Flutter (additions to existing structure):**
- `pubspec.yaml` — add firebase_storage, cloud_functions, file_picker, url_launcher, cloud_firestore
- `lib/services/storage_service.dart` — logo upload to Firebase Storage
- `lib/services/pdf_generation_service.dart` — calls generateExamPdf Cloud Function
- `lib/widgets/print_setup_dialog.dart` — logo upload dialog + set selection
- `lib/screens/pdf_result_screen.dart` — shows Set A / Set B download links
- `lib/main.dart` — add temporary "Print Test Exam" button to MyHomePage

---

## Task 1: Initialize Firebase Cloud Functions

**Files:**
- Create: `functions/package.json`
- Create: `functions/index.js`
- Create: `functions/.eslintrc.js`

> **Prerequisite:** Make sure you have Node.js and the Firebase CLI installed.
> Run `node -v` and `firebase --version` to confirm. If not installed:
> `npm install -g firebase-tools` then `firebase login`.

- [ ] **Step 1: Initialize Firebase in the project**

Run from the repo root (this is interactive — select as instructed below):
```
firebase init
```
When prompted:
- **Which features?** → select `Functions` only (space to select, enter to confirm)
- **Project?** → select `Use an existing project` → `examdrafter`
- **Language?** → `JavaScript`
- **ESLint?** → `Yes`
- **Install dependencies?** → `Yes`

This creates the `functions/` directory with a default `index.js` and `package.json`.

- [ ] **Step 2: Install PDFKit and Jest**

```
cd functions
npm install pdfkit
npm install --save-dev jest
```

- [ ] **Step 3: Add Jest config to package.json**

Open `functions/package.json`. Add `"test": "jest"` to the scripts section and add the Jest config block. The final `package.json` should look like:

```json
{
  "name": "functions",
  "description": "Cloud Functions for Firebase",
  "scripts": {
    "lint": "eslint .",
    "serve": "firebase emulators:start --only functions",
    "shell": "firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log",
    "test": "jest"
  },
  "engines": {
    "node": "20"
  },
  "main": "index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0",
    "pdfkit": "^0.15.0"
  },
  "devDependencies": {
    "eslint": "^8.15.0",
    "eslint-config-google": "^0.14.0",
    "jest": "^29.0.0"
  },
  "jest": {
    "testEnvironment": "node"
  },
  "private": true
}
```

- [ ] **Step 4: Create the test directory**

```
mkdir functions/test
mkdir functions/src
mkdir functions/scripts
```

- [ ] **Step 5: Replace the default index.js**

Replace the content of `functions/index.js` with:

```js
const { initializeApp } = require('firebase-admin/app');
initializeApp();

const { generateExamPdf } = require('./src/generateExamPdf');
exports.generateExamPdf = generateExamPdf;
```

- [ ] **Step 6: Commit**

```
git add functions/
git commit -m "chore: initialize Firebase Cloud Functions with PDFKit and Jest"
```

---

## Task 2: Implement randomize.js (TDD)

**Files:**
- Create: `functions/src/randomize.js`
- Create: `functions/test/randomize.test.js`

- [ ] **Step 1: Write the failing test**

Create `functions/test/randomize.test.js`:

```js
const { shuffleArray } = require('../src/randomize');

test('returns array of the same length', () => {
  const input = [1, 2, 3, 4, 5];
  expect(shuffleArray(input).length).toBe(5);
});

test('contains all original elements', () => {
  const input = [1, 2, 3, 4, 5];
  const result = shuffleArray(input);
  expect([...result].sort((a, b) => a - b)).toEqual([...input].sort((a, b) => a - b));
});

test('does not mutate the original array', () => {
  const input = [1, 2, 3, 4, 5];
  const copy = [...input];
  shuffleArray(input);
  expect(input).toEqual(copy);
});

test('works with objects (options array)', () => {
  const options = [
    { label: 'A', text: 'one', isCorrect: false },
    { label: 'B', text: 'two', isCorrect: true },
    { label: 'C', text: 'three', isCorrect: false },
  ];
  const result = shuffleArray(options);
  expect(result.length).toBe(3);
  expect(result.find(o => o.isCorrect)).toBeDefined();
});
```

- [ ] **Step 2: Run test to verify it fails**

```
cd functions && npm test -- test/randomize.test.js
```
Expected: FAIL — `Cannot find module '../src/randomize'`

- [ ] **Step 3: Implement randomize.js**

Create `functions/src/randomize.js`:

```js
function shuffleArray(array) {
  const arr = [...array];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

module.exports = { shuffleArray };
```

- [ ] **Step 4: Run test to verify it passes**

```
cd functions && npm test -- test/randomize.test.js
```
Expected: PASS — 4 tests passing

- [ ] **Step 5: Commit**

```
git add functions/src/randomize.js functions/test/randomize.test.js
git commit -m "feat: implement Fisher-Yates shuffle for exam randomization"
```

---

## Task 3: Implement pdfBuilder.js (TDD)

**Files:**
- Create: `functions/src/pdfBuilder.js`
- Create: `functions/test/pdfBuilder.test.js`

- [ ] **Step 1: Write the failing test**

Create `functions/test/pdfBuilder.test.js`:

```js
const { buildExamPdf } = require('../src/pdfBuilder');

const mockExam = {
  courseName: 'Mathematics 101',
  semester: 'S1',
  year: 2026,
};

const mockQuestions = [
  {
    text: 'What is 2 + 2?',
    options: [
      { label: 'A', text: '3', isCorrect: false },
      { label: 'B', text: '4', isCorrect: true },
      { label: 'C', text: '5', isCorrect: false },
      { label: 'D', text: '6', isCorrect: false },
    ],
    topicName: 'Arithmetic',
    difficulty: 'Easy',
  },
  {
    text: 'What is the derivative of x²?',
    options: [
      { label: 'A', text: 'x', isCorrect: false },
      { label: 'B', text: '2x', isCorrect: true },
      { label: 'C', text: '2', isCorrect: false },
      { label: 'D', text: 'x²', isCorrect: false },
    ],
    topicName: 'Calculus',
    difficulty: 'Medium',
  },
];

test('returns a non-empty Buffer', async () => {
  const buffer = await buildExamPdf(mockExam, mockQuestions, 'A', null);
  expect(Buffer.isBuffer(buffer)).toBe(true);
  expect(buffer.length).toBeGreaterThan(1000);
});

test('works for Set B with shuffled questions', async () => {
  const buffer = await buildExamPdf(mockExam, [...mockQuestions].reverse(), 'B', null);
  expect(Buffer.isBuffer(buffer)).toBe(true);
  expect(buffer.length).toBeGreaterThan(1000);
});

test('works without a logo (null logoUrl)', async () => {
  await expect(buildExamPdf(mockExam, mockQuestions, 'A', null)).resolves.toBeDefined();
});
```

- [ ] **Step 2: Run test to verify it fails**

```
cd functions && npm test -- test/pdfBuilder.test.js
```
Expected: FAIL — `Cannot find module '../src/pdfBuilder'`

- [ ] **Step 3: Implement pdfBuilder.js**

Create `functions/src/pdfBuilder.js`:

```js
const PDFDocument = require('pdfkit');
const https = require('https');
const http = require('http');

function fetchImageBuffer(url) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    client.get(url, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

function buildExamPdf(exam, questions, set, logoUrl) {
  return new Promise(async (resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 50, bufferPages: true });
      const buffers = [];
      doc.on('data', (chunk) => buffers.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(buffers)));
      doc.on('error', reject);

      // --- Header ---
      const headerY = doc.y;
      if (logoUrl) {
        try {
          const logoBuffer = await fetchImageBuffer(logoUrl);
          doc.image(logoBuffer, 50, headerY, { width: 60 });
        } catch (_) {
          // logo fetch failed — continue without it
        }
      }
      doc.fontSize(16).font('Helvetica-Bold')
        .text('Exam Drafter Institution', 50, headerY, { align: 'right' });

      doc.moveDown(0.5);
      doc.fontSize(11).font('Helvetica')
        .text(`Course: ${exam.courseName}`, { continued: true })
        .text(`Semester: ${exam.semester} ${exam.year}`, { align: 'right' });
      doc.text(`Set: ${set}`);

      doc.moveDown(0.8);
      doc.moveTo(50, doc.y).lineTo(doc.page.width - 50, doc.y).stroke();
      doc.moveDown(0.8);

      // --- Student info ---
      doc.text('Name: _________________________    Student ID: ____________    Date: ____________');
      doc.moveDown(1);

      // --- Instructions ---
      doc.font('Helvetica-Bold').text('Instructions: ', { continued: true })
        .font('Helvetica').text('Circle the letter of the correct answer.');
      doc.moveDown(1);

      // --- Questions ---
      questions.forEach((q, index) => {
        const questionY = doc.y;
        const remainingSpace = doc.page.height - doc.page.margins.bottom - questionY;
        if (remainingSpace < 120) {
          doc.addPage();
        }

        doc.font('Helvetica-Bold').text(`${index + 1}.`, 50, doc.y, { continued: true, width: 20 })
          .font('Helvetica').text(` ${q.text}`, { width: doc.page.width - 120 });
        doc.moveDown(0.3);

        q.options.forEach((opt) => {
          doc.text(`    ${opt.label}.  ${opt.text}`, { indent: 20 });
        });
        doc.moveDown(0.8);
      });

      // --- Page numbers ---
      const range = doc.bufferedPageRange();
      for (let i = range.start; i < range.start + range.count; i++) {
        doc.switchToPage(i);
        doc.fontSize(9).font('Helvetica')
          .text(
            `Page ${i + 1} of ${range.count}`,
            50,
            doc.page.height - doc.page.margins.bottom - 10,
            { align: 'right' },
          );
      }

      doc.flushPages();
      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

module.exports = { buildExamPdf };
```

- [ ] **Step 4: Run test to verify it passes**

```
cd functions && npm test -- test/pdfBuilder.test.js
```
Expected: PASS — 3 tests passing

- [ ] **Step 5: Commit**

```
git add functions/src/pdfBuilder.js functions/test/pdfBuilder.test.js
git commit -m "feat: implement PDFKit exam paper builder"
```

---

## Task 4: Implement generateExamPdf Cloud Function

**Files:**
- Create: `functions/src/generateExamPdf.js`

> This function calls Firestore and Storage — unit testing requires the Firebase emulator. We test the pure logic (randomize, pdfBuilder) via Jest and verify this function via end-to-end test in Task 8.

- [ ] **Step 1: Create generateExamPdf.js**

Create `functions/src/generateExamPdf.js`:

```js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { buildExamPdf } = require('./pdfBuilder');
const { shuffleArray } = require('./randomize');

exports.generateExamPdf = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  const uid = request.auth.uid;
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(uid).get();

  if (!userDoc.exists || userDoc.data().role !== 'admin') {
    throw new HttpsError('permission-denied', 'Only Admins can generate PDFs.');
  }

  const { examId, sets, logoUrl: providedLogoUrl } = request.data;

  if (!examId || !Array.isArray(sets) || sets.length === 0) {
    throw new HttpsError('invalid-argument', 'examId and sets[] are required.');
  }

  const examDoc = await db.collection('exams').doc(examId).get();
  if (!examDoc.exists) {
    throw new HttpsError('not-found', `Exam ${examId} not found.`);
  }
  const exam = examDoc.data();

  const questionsSnap = await db
    .collection('exams').doc(examId)
    .collection('questions')
    .orderBy('order')
    .get();
  const questions = questionsSnap.docs.map((doc) => doc.data());

  // Use the logo URL passed from Flutter (freshly uploaded) or fall back to the one stored on the exam
  const logoUrl = providedLogoUrl || exam.logoUrl || null;

  const bucket = getStorage().bucket();
  const pdfUrls = {};

  if (sets.includes('A')) {
    const buffer = await buildExamPdf(exam, questions, 'A', logoUrl);
    const file = bucket.file(`exams/${examId}/setA.pdf`);
    await file.save(buffer, { contentType: 'application/pdf' });
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 7 * 24 * 60 * 60 * 1000,
    });
    pdfUrls.setA = url;
  }

  if (sets.includes('B')) {
    const shuffledQuestions = shuffleArray(questions).map((q) => ({
      ...q,
      options: shuffleArray(q.options),
    }));
    const buffer = await buildExamPdf(exam, shuffledQuestions, 'B', logoUrl);
    const file = bucket.file(`exams/${examId}/setB.pdf`);
    await file.save(buffer, { contentType: 'application/pdf' });
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 7 * 24 * 60 * 60 * 1000,
    });
    pdfUrls.setB = url;
  }

  await db.collection('exams').doc(examId).update({
    pdfUrls,
    updatedAt: new Date(),
  });

  return { pdfUrls };
});
```

- [ ] **Step 2: Commit**

```
git add functions/src/generateExamPdf.js functions/index.js
git commit -m "feat: implement generateExamPdf Cloud Function"
```

---

## Task 5: Seed Firestore with Test Data

**Files:**
- Create: `functions/scripts/seedFirestore.js`

- [ ] **Step 1: Create the seed script**

Create `functions/scripts/seedFirestore.js`:

```js
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// Uses application default credentials (requires `firebase login` via Firebase CLI)
initializeApp({ projectId: 'examdrafter' });

const db = getFirestore();

async function seed() {
  const examId = 'test-exam-001';

  // ⚠️  Replace with your actual Firebase Auth UID.
  // Find it in Firebase Console → Authentication → Users → copy the UID column.
  const YOUR_UID = 'REPLACE_WITH_YOUR_UID';

  // Create your user document as Admin
  await db.collection('users').doc(YOUR_UID).set({
    email: 'you@example.com',
    displayName: 'Test Admin',
    role: 'admin',
  });

  // Create the test exam
  await db.collection('exams').doc(examId).set({
    title: 'Mathematics Final Exam',
    courseName: 'Mathematics 101',
    semester: 'S1',
    year: 2026,
    status: 'pending_admin_review',
    adminId: YOUR_UID,
    revisionNotes: null,
    pdfUrls: null,
    logoUrl: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  // Create test questions
  const questions = [
    {
      text: 'What is the derivative of x²?',
      options: [
        { label: 'A', text: 'x', isCorrect: false },
        { label: 'B', text: '2x', isCorrect: true },
        { label: 'C', text: '2', isCorrect: false },
        { label: 'D', text: 'x²', isCorrect: false },
      ],
      topicName: 'Calculus',
      difficulty: 'Easy',
      order: 1,
    },
    {
      text: 'What is the integral of 2x?',
      options: [
        { label: 'A', text: 'x² + C', isCorrect: true },
        { label: 'B', text: '2x² + C', isCorrect: false },
        { label: 'C', text: 'x + C', isCorrect: false },
        { label: 'D', text: '2 + C', isCorrect: false },
      ],
      topicName: 'Calculus',
      difficulty: 'Medium',
      order: 2,
    },
    {
      text: 'What is sin(90°)?',
      options: [
        { label: 'A', text: '0', isCorrect: false },
        { label: 'B', text: '0.5', isCorrect: false },
        { label: 'C', text: '1', isCorrect: true },
        { label: 'D', text: '-1', isCorrect: false },
      ],
      topicName: 'Trigonometry',
      difficulty: 'Easy',
      order: 3,
    },
  ];

  for (const q of questions) {
    await db.collection('exams').doc(examId).collection('questions').add(q);
  }

  console.log('✅  Seeded exam:', examId);
  process.exit(0);
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
```

- [ ] **Step 2: Run the seed script**

First, set the application default credentials:
```
firebase login
```

Then run:
```
cd functions && node scripts/seedFirestore.js
```
Expected output: `✅  Seeded exam: test-exam-001`

Verify in the Firebase Console → Firestore → `exams/test-exam-001` that the document and its `questions` subcollection exist.

- [ ] **Step 3: Commit**

```
git add functions/scripts/seedFirestore.js
git commit -m "chore: add Firestore seed script for test exam data"
```

---

## Task 6: Add Flutter Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add packages to pubspec.yaml**

Open `pubspec.yaml`. Replace the `dependencies` section with:

```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8
  firebase_core: ^3.1.0
  firebase_auth: ^5.1.0
  firebase_storage: ^12.1.0
  cloud_firestore: ^5.4.0
  cloud_functions: ^4.3.0
  file_picker: ^8.1.2
  url_launcher: ^6.3.0
```

- [ ] **Step 2: Install packages**

```
flutter pub get
```
Expected: no errors, packages resolved.

- [ ] **Step 3: Commit**

```
git add pubspec.yaml pubspec.lock
git commit -m "chore: add firebase_storage, cloud_functions, file_picker, url_launcher dependencies"
```

---

## Task 7: Implement StorageService

**Files:**
- Create: `lib/services/storage_service.dart`

- [ ] **Step 1: Create storage_service.dart**

```dart
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadLogo(String examId, Uint8List bytes, String extension) async {
    final ref = _storage.ref('logos/$examId/logo.$extension');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$extension'),
    );
    return await ref.getDownloadURL();
  }
}
```

- [ ] **Step 2: Commit**

```
git add lib/services/storage_service.dart
git commit -m "feat: implement StorageService for logo upload"
```

---

## Task 8: Implement PdfGenerationService

**Files:**
- Create: `lib/services/pdf_generation_service.dart`

- [ ] **Step 1: Create pdf_generation_service.dart**

```dart
import 'package:cloud_functions/cloud_functions.dart';

class PdfGenerationService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Map<String, String>> generatePdf({
    required String examId,
    required List<String> sets,
    String? logoUrl,
  }) async {
    final callable = _functions.httpsCallable('generateExamPdf');
    final result = await callable.call({
      'examId': examId,
      'sets': sets,
      if (logoUrl != null) 'logoUrl': logoUrl,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final urlMap = Map<String, dynamic>.from(data['pdfUrls'] as Map);
    return {
      if (urlMap['setA'] != null) 'setA': urlMap['setA'] as String,
      if (urlMap['setB'] != null) 'setB': urlMap['setB'] as String,
    };
  }
}
```

- [ ] **Step 2: Commit**

```
git add lib/services/pdf_generation_service.dart
git commit -m "feat: implement PdfGenerationService to call Cloud Function"
```

---

## Task 9: Implement PrintSetupDialog

**Files:**
- Create: `lib/widgets/print_setup_dialog.dart`

- [ ] **Step 1: Create print_setup_dialog.dart**

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../services/pdf_generation_service.dart';

class PrintSetupDialog extends StatefulWidget {
  final String examId;
  final String? existingLogoUrl;
  final void Function(Map<String, String> pdfUrls) onComplete;

  const PrintSetupDialog({
    super.key,
    required this.examId,
    required this.onComplete,
    this.existingLogoUrl,
  });

  @override
  State<PrintSetupDialog> createState() => _PrintSetupDialogState();
}

class _PrintSetupDialogState extends State<PrintSetupDialog> {
  final _storageService = StorageService();
  final _pdfService = PdfGenerationService();

  bool _isLoading = false;
  String? _error;
  String? _logoUrl;
  Uint8List? _logoBytes;
  String _logoExtension = 'png';
  List<String> _selectedSets = ['A'];
  bool _useExisting = true;

  @override
  void initState() {
    super.initState();
    _logoUrl = widget.existingLogoUrl;
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _logoBytes = file.bytes;
      _logoExtension = file.extension ?? 'png';
      _logoUrl = null;
      _useExisting = false;
    });
  }

  Future<void> _generate() async {
    if (_selectedSets.isEmpty) {
      setState(() => _error = 'Select at least one set.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? logoUrl = widget.existingLogoUrl;

      if (_logoBytes != null) {
        logoUrl = await _storageService.uploadLogo(
          widget.examId,
          _logoBytes!,
          _logoExtension,
        );
      }

      final urls = await _pdfService.generatePdf(
        examId: widget.examId,
        sets: _selectedSets,
        logoUrl: logoUrl,
      );

      if (mounted) widget.onComplete(urls);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1E3A8A);

    return AlertDialog(
      title: const Text('Print Setup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo section
            const Text('Institution Logo', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (widget.existingLogoUrl != null && _useExisting)
              Row(
                children: [
                  Image.network(widget.existingLogoUrl!, height: 48, errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _useExisting = false),
                    child: const Text('Replace'),
                  ),
                ],
              )
            else if (_logoBytes != null)
              Row(
                children: [
                  Image.memory(_logoBytes!, height: 48),
                  const SizedBox(width: 8),
                  const Text('Logo selected', style: TextStyle(color: Colors.green)),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Logo (PNG/JPG)'),
              ),

            const SizedBox(height: 20),

            // Set selection
            const Text('Generate', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Set A (original order)'),
              value: _selectedSets.contains('A'),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSets.add('A');
                  } else {
                    _selectedSets.remove('A');
                  }
                });
              },
              activeColor: primaryBlue,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Set B (shuffled)'),
              value: _selectedSets.contains('B'),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSets.add('B');
                  } else {
                    _selectedSets.remove('B');
                  }
                });
              },
              activeColor: primaryBlue,
              contentPadding: EdgeInsets.zero,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _generate,
          style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Generate PDF'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```
git add lib/widgets/print_setup_dialog.dart
git commit -m "feat: implement PrintSetupDialog with logo upload and set selection"
```

---

## Task 10: Implement PdfResultScreen

**Files:**
- Create: `lib/screens/pdf_result_screen.dart`

- [ ] **Step 1: Create pdf_result_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfResultScreen extends StatelessWidget {
  final Map<String, String> pdfUrls;

  const PdfResultScreen({super.key, required this.pdfUrls});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1E3A8A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated PDFs'),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text(
                'PDFs Generated Successfully',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              if (pdfUrls.containsKey('setA'))
                _DownloadButton(
                  label: 'Download Set A',
                  onTap: () => _openUrl(pdfUrls['setA']!),
                ),
              if (pdfUrls.containsKey('setB')) ...[
                const SizedBox(height: 16),
                _DownloadButton(
                  label: 'Download Set B',
                  onTap: () => _openUrl(pdfUrls['setB']!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DownloadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.download_rounded),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```
git add lib/screens/pdf_result_screen.dart
git commit -m "feat: implement PdfResultScreen with download links"
```

---

## Task 11: Wire Up in MyHomePage for Testing

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add the print button and imports to main.dart**

Open `lib/main.dart`. Replace the import section and the `MyHomePage`/`_MyHomePageState` classes with:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login_page.dart';
import 'screens/pdf_result_screen.dart';
import 'widgets/print_setup_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  void _openPrintDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => PrintSetupDialog(
        examId: 'test-exam-001',
        onComplete: (urls) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PdfResultScreen(pdfUrls: urls)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1E3A8A);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              try {
                await AuthService().signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Exam Drafter Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _openPrintDialog(context),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Print Test Exam'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const MyHomePage(title: 'Exam Drafter');
        }
        return const LoginPage();
      },
    );
  }
}
```

- [ ] **Step 2: Run the app and verify the button appears**

```
flutter run -d chrome
```
Expected: login → sign in → see dashboard with "Print Test Exam" button.

- [ ] **Step 3: Commit**

```
git add lib/main.dart
git commit -m "feat: wire PrintSetupDialog and PdfResultScreen into dashboard for testing"
```

---

## Task 12: Deploy Cloud Function and Test End-to-End

> **Prerequisite:** Firebase project must be on the **Blaze (pay-as-you-go)** plan to deploy Cloud Functions. Upgrade at console.firebase.google.com if needed.

- [ ] **Step 1: Deploy the Cloud Function**

```
cd functions && npm test
```
Expected: all Jest tests pass (randomize + pdfBuilder).

```
firebase deploy --only functions
```
Expected: `✔  Deploy complete!` with the function URL logged.

- [ ] **Step 2: Run the seed script if not already done**

```
cd functions && node scripts/seedFirestore.js
```

- [ ] **Step 3: Run the Flutter app and test the full flow**

```
flutter run -d chrome
```
1. Sign in with your account
2. Click "Print Test Exam"
3. Upload a logo (any PNG/JPG)
4. Select Set A and Set B
5. Click "Generate PDF"
6. Expected: `PdfResultScreen` with two download buttons
7. Click each button — PDFs should open in a new tab with correct layout

- [ ] **Step 4: Verify in Firebase Console**
- Firestore → `exams/test-exam-001` → `pdfUrls` field should be populated
- Storage → `exams/test-exam-001/setA.pdf` and `setB.pdf` should exist
- Storage → `logos/test-exam-001/logo.png` should exist

- [ ] **Step 5: Final commit**

```
git add .
git commit -m "chore: end-to-end PDF export working"
```
