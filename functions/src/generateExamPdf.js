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

  // Use logo URL passed from Flutter (freshly uploaded) or fall back to stored value
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
