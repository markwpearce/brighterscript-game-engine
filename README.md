# BrighterScript Game Engine

An object oriented game engine for the Roku, written in [BrighterScript](https://github.com/rokucommunity/brighterscript), and (someday) available via [ROPM](https://github.com/rokucommunity/ropm).

This project is designed to be used with VScode.

This was originally forked from [Roku-gameEngine](https://github.com/Romans-I-XVI/Roku-gameEngine) by Austin Sojka, and converted into BrighterScript. This work owes a lot to this original project!

## Introduction

The purpose of this project is to make it easy to develop games for the Roku in an object oriented fashion. Similar to how you would with an engine such as Phaser, HaxeFlixel, Gamemaker or Unity (minus any visual software that is).

## Cloning and Running Examples

The BrighterScript Game Engine public repository is on [Github](https://github.com/markwpearce/brighterscript-game-engine/)

Clone the project:

```
git clone https://github.com/markwpearce/brighterscript-game-engine.git
```

This project includes various example Roku apps in the `examples` directory. To run them, you will need a Roku and have it set up properly for doing development. See: https://developer.roku.com/en-ca/docs/developer-program/getting-started/developer-setup.md.

To run the examples:

Install dependencies:

```
cd brighterscript-game-engine
npm install
```

You will need to set up each project in the examples directories. You can do this by using this script:

```
npm run prepare-examples
```

### Build from the command line:

You can manually build the examples from the command line and manually add the zip files to your Roku:

```
npm run build-examples
```

The above command will generate example .zip files like `./examples/asteroids/out/bge-asteroids.zip`

### Open the Workspace in VS Code:

We recommend you install the great [Brightscript Language VSCode Extension](https://marketplace.visualstudio.com/items?itemName=RokuCommunity.brightscript).

Create/edit a `.env` file to specify the details for you target Roku device:

```env
ROKU_USERNAME=<roku development username - default is rokudev>
ROKU_PASSWORD=<roku development password>
ROKU_HOST=<local IP address of the target roku>
```

Then simply run one of the Debug configurations from the Debug tab.

## Installation

_NOTE - Not available yet from ropm!_

Use ropm:

```
ropm install brighterscript-game-engine
```

Suggestion - use a shorter prefix (we use `bge` in the documentation):

```
ropm install bge@npm:brighterscript-game-engine
```

## Documentation

Documentation can be found [here](https://markwpearce.github.io/brighterscript-game-engine)
