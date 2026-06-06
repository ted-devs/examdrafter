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
