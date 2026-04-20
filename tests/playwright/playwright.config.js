// @ts-check
const { defineConfig, devices } = require('@playwright/test');

const BASE_URL = process.env.WP_TEST_URL || 'http://localhost:8888';

module.exports = defineConfig({
  testDir: './',
  timeout: 120_000,
  expect: { timeout: 30_000 },
  fullyParallel: false, // keep false for WP Playground (port conflicts)
  workers: process.env.CI ? 1 : 2,
  retries: process.env.CI ? 2 : 0,

  reporter: [
    ['html', { outputFolder: '../../reports/playwright-html', open: 'never' }],
    ['json', { outputFile: '../../reports/playwright-results.json' }],
    ['line'],
  ],

  use: {
    baseURL: BASE_URL,
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'on-first-retry',
    // WordPress admin credentials
    storageState: process.env.WP_AUTH_FILE || undefined,
  },

  projects: [
    // Auth setup — runs once, saves cookies
    {
      name: 'setup',
      testMatch: '**/auth.setup.js',
    },

    // Desktop Chrome — main test run
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
      dependencies: ['setup'],
    },

    // Mobile viewport — responsive checks
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
      dependencies: ['setup'],
      testMatch: '**/responsive.spec.js',
    },

    // Tablet viewport
    {
      name: 'tablet',
      use: { ...devices['iPad Pro'] },
      dependencies: ['setup'],
      testMatch: '**/responsive.spec.js',
    },
  ],

  // WP Playground server for CI
  ...(process.env.USE_PLAYGROUND === 'true' ? {
    webServer: {
      command: 'npx @wp-playground/cli server --blueprint=setup/playground-blueprint.json',
      url: 'http://localhost:9400',
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
    },
  } : {}),
});
