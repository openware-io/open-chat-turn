'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const root = path.join(__dirname, '..');
const dist = path.join(root, 'dist');

fs.mkdirSync(dist, { recursive: true });

execSync(
    [
        'npx',
        'esbuild',
        'vendor-entry.js',
        '--bundle',
        '--platform=node',
        '--target=node18',
        '--outfile=dist/vendor.js',
    ].join(' '),
    { stdio: 'inherit', cwd: root, shell: true },
);

const indexSrc = fs.readFileSync(path.join(root, 'index.js'), 'utf8');
const indexOut = indexSrc.replace(
    /require\s*\(\s*['"]node-turn['"]\s*\)/,
    "require('./vendor.js')",
);
fs.writeFileSync(path.join(dist, 'turn.js'), indexOut);
