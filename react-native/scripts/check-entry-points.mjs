// Verifies every path package.json advertises actually exists in the build.
//
//   node scripts/check-entry-points.mjs
//
// This exists because it already went wrong once: `prepare` ran tsc with
// `emitDeclarationOnly`, so `lib/commonjs/index.js` and `lib/module/index.js`
// were never built — yet `main` and `module` pointed at them. Nothing caught
// it, because Metro resolves the `react-native` field to src/ and never reads
// `main`. The break would only have surfaced for a consumer using `require`,
// Jest in a host app, or any bundler reading `main` — i.e. after publishing.
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));

/** Collects every field that names a file consumers will resolve. */
function entryPoints() {
  const found = [];

  for (const field of ['main', 'module', 'types', 'react-native', 'source']) {
    if (pkg[field]) found.push([field, pkg[field]]);
  }

  const walk = (node, label) => {
    if (typeof node === 'string') {
      found.push([label, node]);
      return;
    }
    if (node && typeof node === 'object') {
      for (const [key, value] of Object.entries(node)) {
        walk(value, `${label}.${key}`);
      }
    }
  };
  if (pkg.exports) walk(pkg.exports, 'exports');

  return found;
}

const missing = [];
for (const [label, target] of entryPoints()) {
  const path = resolve(root, target);
  const ok = existsSync(path);
  console.log(`${ok ? '  ok  ' : ' MISS '}${label.padEnd(36)} -> ${target}`);
  if (!ok) missing.push(`${label} -> ${target}`);
}

if (missing.length > 0) {
  console.error(
    `\n${missing.length} declared entry point(s) do not exist.\n` +
      `Run \`npm run prepare\` first; if they are still missing, package.json ` +
      `and the build output disagree.`,
  );
  process.exit(1);
}

console.log(`\nAll ${entryPoints().length} entry points resolve.`);
