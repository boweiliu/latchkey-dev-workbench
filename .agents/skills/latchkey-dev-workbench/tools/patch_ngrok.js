// Patch a copied latchkey dist to register the ngrok service.
// Usage: node patch_ngrok.js <dist/src dir> <staged ngrok.js path>
const fs = require('fs');
const path = require('path');

const srcDir = process.argv[2];
const stagedNgrok = process.argv[3];

// 1. Drop in the compiled ngrok service.
const dest = path.join(srcDir, 'services', 'ngrok.js');
fs.copyFileSync(stagedNgrok, dest);
console.log('ngrok.js copied:', fs.existsSync(dest));

// 2. Export it from services/index.js (idempotent).
const indexPath = path.join(srcDir, 'services', 'index.js');
let index = fs.readFileSync(indexPath, 'utf8');
if (!/from '\.\/ngrok\.js'/.test(index)) {
  index = index.replace(/\s*$/, '\n') + "export { Ngrok, NGROK } from './ngrok.js';\n";
  fs.writeFileSync(indexPath, index);
}
console.log('index exports ngrok:', /from '\.\/ngrok\.js'/.test(fs.readFileSync(indexPath, 'utf8')));

// 3. Register NGROK in serviceRegistry.js (import symbol + registry array), idempotent.
const regPath = path.join(srcDir, 'serviceRegistry.js');
let reg = fs.readFileSync(regPath, 'utf8');
if (!/\bNGROK\b/.test(reg)) {
  // add NGROK to the import from './services/index.js'
  reg = reg.replace(
    /import\s*\{([^}]*)\}\s*from\s*(['"])\.\/services\/index\.js\2/,
    (m, names, q) => `import {${names.replace(/,?\s*$/, '')}, NGROK } from ${q}./services/index.js${q}`
  );
  // add NGROK to the SERVICE_REGISTRY array (before its closing ]) )
  reg = reg.replace(
    /(new ServiceRegistry\(\[)([\s\S]*?)(\]\s*\))/,
    (m, open, body, close) => `${open}${body.replace(/,?\s*$/, '')},\n    NGROK,\n${close}`
  );
  fs.writeFileSync(regPath, reg);
}
const after = fs.readFileSync(regPath, 'utf8');
console.log('registry import has NGROK:', /import\s*\{[^}]*\bNGROK\b[^}]*\}\s*from\s*['"]\.\/services\/index\.js/.test(after));
console.log('registry array has NGROK:', /new ServiceRegistry\(\[[\s\S]*\bNGROK\b[\s\S]*\]\s*\)/.test(after));
