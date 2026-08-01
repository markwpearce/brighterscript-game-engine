#!/usr/bin/env node
// Scaffolds a new BGE.Room subclass under examples/<example>/src/source/Rooms
// from scripts/roomTemplate.bs.
//
// Usage: node scripts/create-room.js [example] [RoomName]
//   example  - directory name under examples/, e.g. "quickstart"
//              prompted for interactively if omitted
//   RoomName - the class name, e.g. "MainRoom" -> Rooms/MainRoom.bs
//              prompted for interactively if omitted

const path = require('path');
const { runCli } = require('./scaffold-class.js');

if (require.main === module) {
  runCli({
    classKind: 'Room',
    subDir: path.join('Rooms'),
    templatePath: path.join(__dirname, 'roomTemplate.bs'),
    printNextSteps(filePath, className) {
      const relativePath = path.relative(process.cwd(), filePath);
      console.log(`Created ${relativePath}`);
      console.log('');
      console.log('Next steps (typically in main.bs):');
      console.log(`  game.defineRoom(new ${className}(game))`);
      console.log(`  game.changeRoom("${className}")  # or via this example's getRoomNames(), if it has one`);
    },
  });
}
