const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// Uses application default credentials (requires `firebase login` via Firebase CLI)
initializeApp({ projectId: 'examdrafter' });

const db = getFirestore();

async function seed() {
  const examId = 'test-exam-001';

  // ⚠️  Replace with your actual Firebase Auth UID.
  // Find it: Firebase Console → Authentication → Users → copy the UID column.
  const YOUR_UID = 'REPLACE_WITH_YOUR_UID';

  await db.collection('users').doc(YOUR_UID).set({
    email: 'you@example.com',
    displayName: 'Test Admin',
    role: 'admin',
  });

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