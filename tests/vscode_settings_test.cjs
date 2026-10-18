'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const parser = require('../vendor/jsonc-parser/lib/umd/main.js');
const { update } = require('../tools/vscode_settings.cjs');
const desired = JSON.parse(fs.readFileSync(require('node:path').join(__dirname,
  '../config/juno-gnome/terminal-settings.json'), 'utf8'));

const source = `{
    // Preserve the user's editor preferences.
    "editor.fontSize": 15,
    "editor.fontFamily": "old",
    "terminal.integrated.profiles.linux": {
        // This shell remains available.
        "Custom": { "path": "/usr/bin/zsh", "args": ["-l"] },
    },
    "workbench.colorTheme": "My Theme", // Preserve trailing comments.
}
`;
const result = update(source, desired);
const parsed = parser.parse(result, [], { allowTrailingComma: true });
assert.equal(parsed['editor.fontFamily'], "'JetBrains Mono', monospace");
assert.equal(parsed['terminal.integrated.fontFamily'], 'JetBrainsMono Nerd Font Mono');
assert.equal(parsed['terminal.integrated.defaultProfile.linux'], 'Juno Bash');
assert.deepEqual(parsed['terminal.integrated.profiles.linux'].Custom,
  { path: '/usr/bin/zsh', args: ['-l'] });
assert.deepEqual(parsed['terminal.integrated.profiles.linux']['Juno Bash'],
  { path: '/usr/bin/bash', args: [] });
assert.equal(parsed['editor.fontSize'], 15);
assert.equal(parsed['workbench.colorTheme'], 'My Theme');
for (const comment of ["// Preserve the user's editor preferences.",
  '// This shell remains available.', '// Preserve trailing comments.']) {
  assert.ok(result.includes(comment), comment);
}
assert.equal(update(result, desired), result, 'Repeated staging must be byte-identical');
for (const empty of ['', '  \n', '// user comment\n', '/* user comment */']) {
  const updated = update(empty, desired);
  assert.equal(parser.parse(updated)['terminal.integrated.defaultProfile.linux'], 'Juno Bash');
  if (empty.includes('comment')) assert.ok(updated.startsWith(empty));
}
const crlf = '\uFEFF{\r\n\t"editor.fontSize": 16,\r\n}\r\n';
const crlfResult = update(crlf, desired);
assert.ok(crlfResult.startsWith('\uFEFF'));
assert.ok(!crlfResult.replaceAll('\r\n', '').includes('\n'), 'Keep CRLF');
assert.ok(crlfResult.includes('\t"editor.fontSize": 16'));
for (const invalid of ['[]', 'null', '{"editor.fontFamily":',
  '{"editor.fontFamily":"a", "editor.fontFamily":"b"}',
  '{"terminal.integrated.profiles.linux":null}',
  '{"terminal.integrated.profiles.linux":{"Other":{}, "Other":{}}}']) {
  assert.throws(() => update(invalid, desired));
}
console.log('VS Code JSONC: comentários, perfis, BOM, CRLF, conflitos e idempotência validados.');
