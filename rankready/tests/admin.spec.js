// @ts-check
const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.WP_TEST_URL || 'http://localhost:8890';
const WP_USER  = process.env.WP_USER     || 'admin';
const WP_PASS  = process.env.WP_PASS     || 'password';

test.describe('RankReady Admin — smoke test', () => {

  test.beforeEach( async ({ page }) => {
    await page.goto( BASE_URL + '/wp-login.php' );
    await expect( page ).toHaveURL( /wp-login/, { timeout: 30_000 } );
    await page.fill( '#user_login', WP_USER );
    await page.fill( '#user_pass', WP_PASS );
    await page.click( '#wp-submit' );
    await expect( page ).toHaveURL( /wp-admin/, { timeout: 30_000 } );
  });

  test('Dashboard tab loads and shows stat cards', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=dashboard' );
    await expect( page.locator('.rr-stats-row') ).toBeVisible();
    await expect( page.locator('.rr-info-grid') ).toBeVisible();

    const stats = page.locator('.rr-stat');
    await expect( stats ).toHaveCount( 4 );

    const cards = page.locator('.rr-dash-feature');
    await expect( cards ).toHaveCount( 6 );

    await page.screenshot({ path: '../../reports/rankready/dashboard.png', fullPage: false });
  });

  test('6 tabs render with correct labels', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready' );
    const tabs = page.locator('.rr-tabs .nav-tab');
    await expect( tabs ).toHaveCount( 6 );

    const labels = ['Dashboard', 'Content AI', 'Authority', 'AI Crawlers', 'Settings', 'Advanced'];
    for ( const label of labels ) {
      await expect( page.locator('.rr-tabs').getByText( label ) ).toBeVisible();
    }
  });

  test('Content AI tab loads Summary and FAQ sections', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=content' );
    await expect( page.getByText( 'AI Summary' ).first() ).toBeVisible();
    await expect( page.getByText( 'FAQ Generator' ).first() ).toBeVisible();

    const submits = page.locator('input[type="submit"]');
    await expect( submits ).toHaveCount( 2 );

    await page.screenshot({ path: '../../reports/rankready/content-ai-tab.png', fullPage: true });
  });

  test('Authority tab loads Author Box and Schema sections', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=authority' );
    await expect( page.getByText( 'Author Box' ).first() ).toBeVisible();
    await expect( page.getByText( 'Schema Automation' ).first() ).toBeVisible();
  });

  test('AI Crawlers tab loads', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=crawlers' );
    await expect( page.locator('.rr-tab-content') ).toBeVisible();
    await expect( page.locator('body') ).not.toContainText( 'Fatal error' );
  });

  test('Settings tab loads API key form', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=settings' );
    await expect( page.locator('#rr_api_key') ).toBeVisible();
  });

  test('Advanced tab loads without fatal errors', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=advanced' );
    await expect( page.locator('.rr-tab-content') ).toBeVisible();
    await expect( page.locator('body') ).not.toContainText( 'Fatal error' );
  });

  test('Legacy tab slugs redirect to correct tabs', async ({ page }) => {
    // ?tab=summary → Content AI
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=summary' );
    await expect( page.locator('.rr-tab-content') ).toBeVisible();
    await expect( page.getByText( 'AI Summary' ).first() ).toBeVisible();

    // ?tab=api → Settings
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=api' );
    await expect( page.locator('#rr_api_key') ).toBeVisible();

    // ?tab=author → Authority
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=author' );
    await expect( page.getByText( 'Author Box' ).first() ).toBeVisible();
  });

  test('Display Options collapsible expands on click', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=content' );
    const details = page.locator('.rr-details').first();
    await expect( details ).toBeVisible();
    await details.click();
    await expect( page.locator('#rr_summary_label, [name="rr_label"]').first() ).toBeVisible({ timeout: 5_000 });
  });

  test('No PHP fatal errors on any tab', async ({ page }) => {
    const tabs = ['dashboard', 'content', 'authority', 'crawlers', 'settings', 'advanced'];
    for ( const tab of tabs ) {
      await page.goto( BASE_URL + '/wp-admin/admin.php?page=rankready&tab=' + tab );
      await expect( page.locator('body') ).not.toContainText( 'Fatal error' );
      await expect( page.locator('body') ).not.toContainText( 'Parse error' );
    }
  });

  test('LLMs.txt endpoint returns plain text', async ({ page }) => {
    const response = await page.request.get( BASE_URL + '/llms.txt' );
    expect( response.status() ).toBe( 200 );
    expect( response.headers()['content-type'] ).toContain( 'text/plain' );
  });

  test('Plugin activates — no activation fatal', async ({ page }) => {
    await page.goto( BASE_URL + '/wp-admin/plugins.php' );
    await expect( page.locator('body') ).not.toContainText( 'Fatal error' );
    await expect( page.locator('[data-slug="rankready"]') ).toBeVisible();
  });

});
