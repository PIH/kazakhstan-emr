// UI checks of a running system. Runs as the local e2e-test user (e2e-user.sql, added to a copy)
// and only opens the fake test patient, never real patients' pages.
const { defineConfig } = require('@playwright/test');
// BASE_URL points the checks at another system, e.g. BASE_URL=https://127.0.0.2

module.exports = defineConfig({
  testDir: './tests',
  globalSetup: './global-setup.js',
  timeout: 120_000,
  workers: 1,
  reporter: [['list']],
  use: {
    baseURL: process.env.BASE_URL || 'https://localhost',
    ignoreHTTPSErrors: true,
    viewport: { width: 1400, height: 1000 },
    screenshot: 'only-on-failure',
  },
});
