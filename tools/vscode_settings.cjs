#!/usr/bin/env node
'use strict';

// Microsoft's JSONC editor preserves comments, trailing commas and other profiles.
const fs = require('node:fs');
const parser = require('../vendor/jsonc-parser/lib/umd/main.js');

function object(node, label) {
  if (!node || node.type !== 'object') throw new Error(`${label} precisa ser objeto JSON`);
  const names = new Set();
  for (const property of node.children || []) {
    const name = property.children[0].value;
    if (names.has(name)) throw new Error(`chave repetida em ${label}: ${name}`);
    names.add(name);
  }
}

function parse(text) {
  const errors = [];
  const tree = parser.parseTree(text, errors, { allowTrailingComma: true, disallowComments: false });
  if (errors.length) throw new Error(`JSONC inválido na posição ${errors[0].offset}`);
  object(tree, 'settings.json');
  const profiles = parser.findNodeAtLocation(tree, ['terminal.integrated.profiles.linux']);
  if (profiles) object(profiles, 'terminal.integrated.profiles.linux');
  return tree;
}

function update(original, desired) {
  const bom = original.startsWith('\uFEFF') ? '\uFEFF' : '';
  let text = original.slice(bom.length);
  if (!text.trim()) text += '{}';
  // A comments-only document is a valid fresh settings file in VS Code.
  if (!parser.stripComments(text).trim()) text += (text.endsWith('\n') ? '' : '\n') + '{}';
  parse(text);
  const indentation = text.match(/(?:^|\n)([ \t]+)"/);
  const unit = indentation ? indentation[1] : '  ';
  const formattingOptions = {
    insertSpaces: !unit.includes('\t'),
    tabSize: unit.includes('\t') ? 2 : unit.length,
    eol: text.includes('\r\n') ? '\r\n' : '\n',
  };
  const updates = [
    [['editor.fontFamily'], desired['editor.fontFamily']],
    [['terminal.integrated.fontFamily'], desired['terminal.integrated.fontFamily']],
    [['terminal.integrated.defaultProfile.linux'], desired['terminal.integrated.defaultProfile.linux']],
    [['terminal.integrated.profiles.linux', 'Juno Bash'], desired['terminal.integrated.profiles.linux']['Juno Bash']],
  ];
  for (const [path, value] of updates) {
    const current = parser.getNodeValue(parser.findNodeAtLocation(parse(text), path));
    if (JSON.stringify(current) === JSON.stringify(value)) continue;
    text = parser.applyEdits(text, parser.modify(text, path, value, { formattingOptions }));
  }
  parse(text);
  return bom + text;
}

function main() {
  if (process.argv.length !== 5) throw new Error('Uso: vscode_settings.cjs ENTRADA SAÍDA PERFIL');
  const [input, output, profile] = process.argv.slice(2);
  const original = fs.existsSync(input) ? fs.readFileSync(input, 'utf8') : '';
  const desired = JSON.parse(fs.readFileSync(profile, 'utf8'));
  fs.writeFileSync(output, update(original, desired), 'utf8');
}

if (require.main === module) {
  try { main(); } catch (error) {
    console.error(`Configurações VS Code recusadas: ${error.message}`);
    process.exitCode = 1;
  }
}
module.exports = { update };
