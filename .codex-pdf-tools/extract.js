const fs = require('fs');
const path = require('path');
const pdf = require('./node_modules/pdf-parse');
(async () => {
  for (const name of ['aa.pdf', 'antigravity_promptlari.html.pdf']) {
    const file = path.join('..', 'prompts-tasarým', name);
    const dataBuffer = fs.readFileSync(file);
    const data = await pdf(dataBuffer);
    console.log('###FILE### ' + name);
    console.log(data.text.slice(0, 12000));
    console.log('\n###END###\n');
  }
})();
