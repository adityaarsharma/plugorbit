// Saves WP admin auth cookies so tests don't re-login every run
const { test: setup, expect } = require('@playwright/test');
const path = require('path');

const AUTH_FILE = path.join(__dirname, '../../.auth/wp-admin.json');

setup('authenticate as WordPress admin', async ({ page }) => {
  const WP_USER = process.env.WP_ADMIN_USER || 'admin';
  const WP_PASS = process.env.WP_ADMIN_PASS || 'password';

  await page.goto('/wp-login.php');
  await page.getByLabel('Username or Email Address').fill(WP_USER);
  await page.getByLabel('Password').fill(WP_PASS);
  await page.getByRole('button', { name: 'Log In' }).click();
  await expect(page).toHaveURL(/wp-admin/);

  await page.context().storageState({ path: AUTH_FILE });
});
