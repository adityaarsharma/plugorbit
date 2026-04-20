// @ts-check
const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.WP_TEST_URL || 'http://localhost:8892';
const WP_USER  = process.env.WP_USER     || 'admin';
const WP_PASS  = process.env.WP_PASS     || 'password';

test.describe('NexterWP Admin — smoke test', () => {

  test.beforeEach( async ({ page }) => {
    await page.goto( BASE_URL + '/wp-login.php' );
    await expect( page ).toHaveURL( /wp-login/, { timeout: 30_000 } );
    await page.fill( '#user_login', WP_USER );
    await page.fill( '#user_pass', WP_PASS );
    await page.click( '#wp-submit' );
    await expect( page ).toHaveURL( /wp-admin/, { timeout: 30_000 } );
  });

  test('Plugin activates — no activation fatal', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/plugins.php' );
    await expect( page.locator('body') ).not.toContainText( 'Fatal error' );
    await expect( page.locator('body') ).not.toContainText( 'Parse error' );
  });

  test('Admin dashboard loads without errors', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/' );
    await expect( page.locator('body') ).not.toContainText( 'Fatal error' );
    await expect( page.locator('body') ).not.toContainText( 'Warning:' );
    await page.screenshot({ path: '../../reports/nexterwp/admin-dashboard.png', fullPage: false });
  });

  test('Nexter admin page loads', async ({ page }) => {
    // Adjust page slug to match actual NexterWP admin menu slug
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=nexter' );
    await expect( page.locator('body') ).not.toContainText( 'Fatal error' );
  });

  test('Block editor loads on new post', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/post-new.php' );
    await expect( page.locator('body') ).not.toContainText( 'Fatal error' );
    // Block inserter should be present
    await expect( page.locator('.edit-post-header, .editor-header') ).toBeVisible({ timeout: 20_000 });
  });

  test('No JS console errors on admin pages', async ({ page }) => {
    const errors = [];
    page.on('console', msg => {
      if ( msg.type() === 'error' ) errors.push( msg.text() );
    });

    await page.goto( BASE_URL + '/wp-admin/' );
    await page.waitForLoadState('networkidle');

    // Filter out known third-party noise
    const realErrors = errors.filter( e =>
      !e.includes('net::ERR_BLOCKED') &&
      !e.includes('favicon')
    );
    expect( realErrors ).toHaveLength( 0 );
  });

  test('No PHP fatal errors on key admin pages', async ({ page }) => {
    const pages = [
      '/wp-admin/',
      '/wp-admin/plugins.php',
      '/wp-admin/themes.php',
      '/wp-admin/options-general.php',
    ];
    for ( const path of pages ) {
      await page.goto( BASE_URL + path );
      await expect( page.locator('body') ).not.toContainText( 'Fatal error' );
      await expect( page.locator('body') ).not.toContainText( 'Parse error' );
    }
  });

});
