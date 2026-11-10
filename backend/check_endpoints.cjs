const fs = require('fs');
const path = require('path');
const dir = 'backend/dashboard/src/lib/components';
fs.readdirSync(dir).forEach(file => {
  if (file.endsWith('.svelte')) {
    const content = fs.readFileSync(path.join(dir, file), 'utf8');
    const regex = /apiRequest\((\s*['"`][^'"`]+['"`])/g;
    let match;
    while ((match = regex.exec(content)) !== null) {
      console.log(file, '->', match[1].trim());
    }
  }
});
