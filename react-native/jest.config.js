/**
 * The model layer is pure TypeScript with no React Native imports, so it runs
 * under plain ts-jest with no native mocking and no emulator. That is
 * deliberate: the posture rules are the part most likely to break, and they
 * should be the cheapest thing to test.
 */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.ts'],
  collectCoverageFrom: ['src/model/**/*.ts', 'src/decode.ts'],
};
