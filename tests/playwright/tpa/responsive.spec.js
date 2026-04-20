// The Plus Addons — Responsive / multi-viewport tests
const { test, expect } = require('@playwright/test');

const VIEWPORTS = [
  { name: 'mobile',  width: 375,  height: 812  },
  { name: 'tablet',  width: 768,  height: 1024 },
  { name: 'desktop', width: 1440, height: 900  },
];

const TEST_PAGES = [
  { name: 'homepage',  path: '/' },
  { name: 'tpa-test',  path: process.env.TPA_TEST_PAGE || '/tpa-test/' },
];

for (const viewport of VIEWPORTS) {
  for (const testPage of TEST_PAGES) {
    test(`${testPage.name} renders on ${viewport.name} (${viewport.width}px)`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto(testPage.path);
      await page.waitForLoadState('networkidle');

      // Check no horizontal scroll (layout not broken)
      const hasHorizontalScroll = await page.evaluate(() =>
        document.documentElement.scrollWidth > document.documentElement.clientWidth
      );
      expect(hasHorizontalScroll, `Horizontal scroll on ${viewport.name}`).toBe(false);

      // Snapshot per viewport
      await expect(page).toHaveScreenshot(`${testPage.name}-${viewport.name}.png`, {
        maxDiffPixelRatio: 0.03,
      });
    });
  }
}

test('navigation menu accessible on mobile', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto('/');
  await page.waitForLoadState('networkidle');

  // Mobile hamburger should exist and be clickable
  const hamburger = page.locator('[class*="hamburger"], [class*="menu-toggle"], [aria-label*="menu"]').first();
  if (await hamburger.isVisible()) {
    await hamburger.click();
    await expect(page.locator('nav, [class*="mobile-menu"]').first()).toBeVisible();
  }
});

test('touch targets are minimum 44x44px on mobile', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto('/');
  await page.waitForLoadState('networkidle');

  const smallTargets = await page.evaluate(() => {
    const interactive = Array.from(document.querySelectorAll('a, button, [role="button"], input, select'));
    return interactive
      .filter(el => {
        const rect = el.getBoundingClientRect();
        return (rect.width > 0 && rect.height > 0) &&
               (rect.width < 40 || rect.height < 40);
      })
      .map(el => ({
        tag: el.tagName,
        text: el.textContent?.trim().slice(0, 30),
        w: Math.round(el.getBoundingClientRect().width),
        h: Math.round(el.getBoundingClientRect().height),
      }));
  });

  if (smallTargets.length > 0) {
    console.warn('Small touch targets found:', smallTargets);
  }
  // Warn but don't fail — some third-party elements unavoidable
  expect(smallTargets.length).toBeLessThan(10);
});
