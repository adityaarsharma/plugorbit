/**
 * Orbit — Generic Plugin Setup Runner
 *
 * Reads setup/plugins/{slug}.setup.json and runs the WP-CLI commands before tests.
 * Each plugin defines what WP options, user meta, sample content, and WP-CLI commands
 * to run to put the plugin in a "real user has configured this" state.
 *
 * Usage:
 *   node setup/plugin-setup.js --plugin plugin-b
 *   node setup/plugin-setup.js --plugin plugin-a
 *   node setup/plugin-setup.js --all
 *
 * Or from playwright globalSetup:
 *   const { runSetup } = require('./setup/plugin-setup.js');
 *   await runSetup('plugin-b');
 */

const { execSync } = require('child_process');
const path = require('path');
const fs   = require('fs');

const WP_ENV_DIR = path.join(__dirname, '../.wp-env-site/default');

function wpCli(cmd) {
  try {
    const result = execSync(`npx wp-env run cli wp ${cmd}`, {
      cwd: WP_ENV_DIR,
      encoding: 'utf8',
      timeout: 30000,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return { ok: true, out: result.trim() };
  } catch (e) {
    return { ok: false, err: e.stderr?.trim() || e.message };
  }
}

function loadPluginConfig(slug) {
  const file = path.join(__dirname, 'plugins', `${slug}.setup.json`);
  if (!fs.existsSync(file)) {
    console.error(`[orbit-setup] No setup config found for plugin: ${slug}`);
    console.error(`  Create: ${file}`);
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

async function runSetup(slug) {
  const config = loadPluginConfig(slug);
  console.log(`\n[orbit-setup] Setting up: ${config.name || slug}`);
  console.log(`[orbit-setup] Goal: ${config.goal || 'configure plugin as real user would'}\n`);

  // 1. WP Options
  if (config.options) {
    for (const [key, value] of Object.entries(config.options)) {
      const r = wpCli(`option update ${key} '${value}' --format=json`);
      console.log(`  option ${key}: ${r.ok ? '✓' : '✗ ' + r.err}`);
    }
  }

  // 2. User meta (e.g. custom plugin role capabilities)
  if (config.user_meta) {
    for (const [userId, meta] of Object.entries(config.user_meta)) {
      for (const [key, value] of Object.entries(meta)) {
        const r = wpCli(`user meta update ${userId} ${key} '${value}'`);
        console.log(`  user ${userId} meta ${key}: ${r.ok ? '✓' : '✗ ' + r.err}`);
      }
    }
  }

  // 3. Sample content (posts/pages/options)
  if (config.sample_content) {
    for (const item of config.sample_content) {
      if (item.type === 'post') {
        // Check if post already exists
        const check = wpCli(`post list --post_type=${item.post_type || 'post'} --name="${item.slug}" --fields=ID --format=count`);
        if (check.ok && parseInt(check.out) > 0) {
          console.log(`  post "${item.slug}": already exists, skipping`);
          continue;
        }
        const cmd = [
          `post create`,
          `--post_title="${item.title}"`,
          `--post_name="${item.slug}"`,
          `--post_type=${item.post_type || 'post'}`,
          `--post_status=publish`,
          `--post_content="${(item.content || 'Sample content for UAT testing.').replace(/"/g, '\\"')}"`,
          item.meta ? `--meta_input='${JSON.stringify(item.meta)}'` : '',
        ].filter(Boolean).join(' ');
        const r = wpCli(cmd);
        console.log(`  post "${item.title}": ${r.ok ? '✓ ID:' + r.out.match(/\d+/)?.[0] : '✗ ' + r.err}`);
      }
    }
  }

  // 4. Raw WP-CLI commands
  if (config.cli_commands) {
    for (const cmd of config.cli_commands) {
      const r = wpCli(cmd);
      console.log(`  wp ${cmd}: ${r.ok ? '✓' : '✗ ' + r.err}`);
    }
  }

  console.log(`\n[orbit-setup] ${slug} ready.\n`);
}

// CLI entrypoint
if (require.main === module) {
  const args = process.argv.slice(2);
  const pluginArg = args.find(a => a.startsWith('--plugin='))?.split('=')[1]
    || (args.indexOf('--plugin') >= 0 ? args[args.indexOf('--plugin') + 1] : null);
  const all = args.includes('--all');

  if (all) {
    const dir = path.join(__dirname, 'plugins');
    const configs = fs.readdirSync(dir).filter(f => f.endsWith('.setup.json'));
    Promise.all(configs.map(f => runSetup(f.replace('.setup.json', '')))).catch(console.error);
  } else if (pluginArg) {
    runSetup(pluginArg).catch(console.error);
  } else {
    console.error('Usage: node setup/plugin-setup.js --plugin <slug> | --all');
    process.exit(1);
  }
}

module.exports = { runSetup, wpCli };
