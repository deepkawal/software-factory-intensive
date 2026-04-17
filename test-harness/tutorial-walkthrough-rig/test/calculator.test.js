const { add, subtract } = require('../src/calculator');

describe('calculator', () => {
  test('add returns the sum of two numbers', () => {
    expect(add(2, 3)).toBe(5);
  });

  test('subtract returns the difference of two numbers', () => {
    expect(subtract(5, 3)).toBe(2);
  });
});
