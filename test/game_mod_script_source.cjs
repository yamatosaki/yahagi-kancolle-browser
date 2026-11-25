const fs = require('node:fs');
const path = require('node:path');

function readGameModScript(file) {
  const kotlin = fs.readFileSync(file, 'utf8');
  return kotlin.match(/val source: String\s*=\s*"""([\s\S]*?)"""/)[1]
    .replace(/\$\{(GameModChsBgmNames|GameModChsTextScript)\.source\}/g,
      (_, name) => readGameModScript(path.join(path.dirname(file), name + '.kt')))
    .replaceAll("${'$'}", '$');
}

module.exports = {readGameModScript};
