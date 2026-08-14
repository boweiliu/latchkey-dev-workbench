// Patch a copied/bundled latchkey dist to register the huggingface service.
// Operates on COMPILED output. Usage: node patch_bundle_hf.js <dist/src dir> <staged huggingface.js path>
const fs = require('fs');
const path = require('path');

const srcDir = process.argv[2];
const stagedJs = process.argv[3];

// 1. Drop in the compiled huggingface service.
const dest = path.join(srcDir, 'services', 'huggingface.js');
fs.copyFileSync(stagedJs, dest);
console.log('huggingface.js copied:', fs.existsSync(dest));

// 2. Export it from services/index.js (idempotent).
const indexPath = path.join(srcDir, 'services', 'index.js');
let index = fs.readFileSync(indexPath, 'utf8');
if (!/from '\.\/huggingface\.js'/.test(index)) {
  index = index.replace(/\s*$/, '\n') + "export { Huggingface, HUGGINGFACE } from './huggingface.js';\n";
  fs.writeFileSync(indexPath, index);
}
console.log('index exports huggingface:', /from '\.\/huggingface\.js'/.test(fs.readFileSync(indexPath, 'utf8')));

// 3. Register HUGGINGFACE in serviceRegistry.js (import symbol + registry array), idempotent.
const regPath = path.join(srcDir, 'serviceRegistry.js');
let reg = fs.readFileSync(regPath, 'utf8');
if (!/\bHUGGINGFACE\b/.test(reg)) {
  reg = reg.replace(
    /import\s*\{([^}]*)\}\s*from\s*(['"])\.\/services\/index\.js\2/,
    (m, names, q) => `import {${names.replace(/,?\s*$/, '')}, HUGGINGFACE } from ${q}./services/index.js${q}`
  );
  reg = reg.replace(
    /(new ServiceRegistry\(\[)([\s\S]*?)(\]\s*\))/,
    (m, open, body, close) => `${open}${body.replace(/,?\s*$/, '')},\n    HUGGINGFACE,\n${close}`
  );
  fs.writeFileSync(regPath, reg);
}
const after = fs.readFileSync(regPath, 'utf8');
console.log('registry import has HUGGINGFACE:', /import\s*\{[^}]*\bHUGGINGFACE\b[^}]*\}\s*from\s*['"]\.\/services\/index\.js/.test(after));
console.log('registry array has HUGGINGFACE:', /new ServiceRegistry\(\[[\s\S]*\bHUGGINGFACE\b[\s\S]*\]\s*\)/.test(after));
