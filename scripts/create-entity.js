#!/usr/bin/env node
// Scaffolds a new BGE.GameEntity subclass under examples/<example>/src/source/Entities
// from scripts/entityTemplate.bs.
//
// Usage: node scripts/create-entity.js [example] [EntityName]
//   example    - directory name under examples/, e.g. "quickstart"
//                prompted for interactively if omitted
//   EntityName - the class name, e.g. "Player" -> Entities/Player.bs
//                prompted for interactively if omitted

const path = require('path');
const { runCli } = require('./scaffold-class.js');

if (require.main === module) {
  runCli({
    classKind: 'Entity',
    subDir: path.join('Entities'),
    templatePath: path.join(__dirname, 'entityTemplate.bs'),
    printNextSteps(filePath, className) {
      const relativePath = path.relative(process.cwd(), filePath);
      console.log(`Created ${relativePath}`);
      console.log('');
      console.log('Next steps:');
      console.log(`  # add it to a room, e.g. in a Room's onCreate(): m.game.addEntity(new ${className}(m.game))`);
    },
  });
}
