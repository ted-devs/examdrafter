jest.setTimeout(15000);

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
