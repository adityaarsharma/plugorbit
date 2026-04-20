// @ts-check
const { defineConfig } = require('@playwright/test');

const BASE_URL = process.env.WP_TEST_URL || 'http://localhost:8892';

module.exports = defineConfig({
  testDir: './tests',
  timeout: 90_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  retries: 1,

  reporter: [
    ['html', { outputFolder: '../../reports/nexterwp/playwright-html', open: 'never' }],
    ['line'],
  ],

  use: {
    baseURL: BASE_URL,
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'on-first-retry',
  },

  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
  ],
});
