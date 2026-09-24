#!/usr/bin/env node
// Scaffolds a new BGE.GameScene subclass under examples/<example>/src/source/Scenes
// from scripts/templates/sceneTemplate.bs.
//
// Usage: node scripts/create-scene.js [example] [SceneName]
//   example   - directory name under examples/, e.g. "quickstart"
//               prompted for interactively if omitted
//   SceneName - the class name, e.g. "MainScene" -> Scenes/MainScene.bs
//               prompted for interactively if omitted

const path = require('path');
const { runCli } = require('./scaffold-class.js');

if (require.main === module) {
  runCli({
    classKind: 'Scene',
    subDir: path.join('Scenes'),
    templatePath: path.join(__dirname, 'templates', 'sceneTemplate.bs'),
    printNextSteps(filePath, className) {
      const relativePath = path.relative(process.cwd(), filePath);
      console.log(`Created ${relativePath}`);
      console.log('');
      console.log('Next steps (typically in main.bs):');
      console.log(`  game.defineScene(new ${className}(game))`);
      console.log(`  game.changeScene("${className}")  # or via this example's getSceneNames(), if it has one`);
    },
  });
}
