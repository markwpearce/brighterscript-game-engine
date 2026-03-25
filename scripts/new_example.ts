#!/usr/bin/env node

import * as inquirer from '@inquirer/prompts';

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

import { Chalk } from 'chalk';
import sharp from 'sharp';


function camelize(str: string) {
    return str.replace(/(?:^\w|[A-Z]|\b\w|\s+)/g, function (match, index) {
        if (+match === 0) return ""; // or if (/\s+/.test(match)) for white spaces
        return index === 0 ? match.toLowerCase() : match.toUpperCase();
    });
}

async function replaceTextInFile(filePath: string, newName: string) {
    try {
        // 1. Read the file content
        const data = fs.readFileSync(filePath, 'utf8');

        // 2. Replace the placeholder
        // We use a Regular Expression with the 'g' flag to replace ALL instances
        const updatedContent = data.replace(/{{exampleName}}/g, newName);

        // 3. Write the updated content back to the file
        fs.writeFileSync(filePath, updatedContent, 'utf8');
    } catch (err) {
        console.error('Error handling the file:', err);
    }
}

async function addTextToImage(
    inputPath: string,
    outputPath: string,
    text: string,
    fontSize: number,
): Promise<void> {
    try {
        // 1. Get dimensions of the original image
        const metadata = await sharp(inputPath).metadata();
        const width = metadata.width ?? 800;
        const height = metadata.height ?? 600;

        // 2. Create an SVG string for the text
        // You can customize font-size, color, and positioning here
        const svgText = `
      <svg width="${width}" height="${height}">
        <style>
          .title { fill: white; font-size: ${fontSize}px; font-weight: bold; font-family: sans-serif; }
          .shadow { fill: black; font-size: ${fontSize}px; font-weight: bold; font-family: sans-serif; opacity: 0.5; }
        </style>
        <text x="51%" y="51%" text-anchor="middle" class="shadow">${text}</text>
        <text x="50%" y="50%" text-anchor="middle" class="title">${text}</text>
      </svg>
    `;

        // 3. Composite the text SVG over the original image
        await sharp(inputPath)
            .composite([
                {
                    input: Buffer.from(svgText),
                    top: 0,
                    left: 0,
                },
            ])
            .png() // Ensure the output is PNG
            .toFile(outputPath);

        console.log(`Image saved to ${outputPath}`);
    } catch (error) {
        console.error('Error processing image:', error);
    }
}

async function addOptionToVsCodeTasks(tasksFilePath: string, newOptionName: string) {
    try {
        // 1. Read and parse the file
        const rawData = await fs.promises.readFile(tasksFilePath, 'utf8');
        const config: TasksJson = JSON.parse(rawData);

        // 2. Locate the specific input
        // tasks.json inputs are usually in an 'inputs' array
        if (!config.inputs) {
            console.error("No 'inputs' section found in tasks.json");
            return;
        }

        const targetInput = config.inputs.find(input => input.id === 'example');

        if (targetInput && Array.isArray(targetInput.options)) {
            // 3. Add the new option if it doesn't already exist
            if (!targetInput.options.includes(newOptionName)) {
                targetInput.options.push(newOptionName);
                console.log(`Added "${newOptionName}" to input 'example'.`);
            } else {
                console.log(`Option "${newOptionName}" already exists.`);
            }

            // 4. Save the file back with 4-space indentation to keep it pretty
            await fs.promises.writeFile(tasksFilePath, JSON.stringify(config, null, 4), 'utf8');
            console.log('tasks.json updated successfully!');
        } else {
            console.error("Could not find input with ID 'example' or it has no options array.");
        }
    } catch (err) {
        console.error('Error processing tasks.json:', err);
    }
}

async function main() {

    const chalk = new Chalk();

    console.log(chalk.blue("🚀 Welcome to create-frontend-site!"));


    const projectName = await inquirer.input({
        message: "Project name:",
    });

    const projectNameCamel = camelize(projectName);
    const targetDir = path.join(process.cwd(), "examples", projectNameCamel);
    const templateDir = path.join(process.cwd(), "scripts", "exampleTemplate");

    if (fs.existsSync(targetDir)) {
        console.error(chalk.red("❌ Example already exists."));
        process.exit(1);

    }

    fs.mkdirSync(targetDir, { recursive: true });
    fs.cpSync(templateDir, targetDir, { recursive: true });

    console.log(chalk.yellow("📝 Adding Project Name..."));
    replaceTextInFile(path.join(targetDir, "src", "manifest"), projectName);

    console.log(chalk.yellow("🖼️ Updating Splash Screen..."));

    const imageText = `BGE: ${projectName}`;

    const imagesToUpdate = [
        { fileName: "Splash_HD.png", fontSize: 48 },
        { fileName: "Splash_SD.png", fontSize: 36 },
        { fileName: "Channel_Icon_HD.png", fontSize: 24 },
        { fileName: "Channel_Icon_SD.png", fontSize: 16 }
    ];

    for (const { fileName, fontSize } of imagesToUpdate) {
        await addTextToImage(
            path.join(templateDir, "src", "images", fileName),
            path.join(targetDir, "src", "images", fileName),
            imageText,
            fontSize
        );
    }



    console.log(chalk.yellow("📦 Installing dependencies..."));
    execSync("npm install", { cwd: targetDir, stdio: "inherit" });

    console.log(chalk.yellow("🔧 Updating Debug Task..."));
    await addOptionToVsCodeTasks(path.join(process.cwd(), ".vscode", "tasks.json"), projectNameCamel);

    console.log(chalk.green("\n✅ Project is ready!"));
}



main();



export interface TasksJson {
    version: string;
    tasks?: TaskDescription[];
    inputs?: TaskInput[];
}

export interface TaskDescription {
    label: string;
    type: "shell" | "process" | string;
    command?: string;
    args?: string[];
    group?: string | { kind: string; isDefault?: boolean };
    presentation?: any;
    problemMatcher?: string | string[];
    [key: string]: any; // To support custom task types
}

export interface TaskInput {
    id: string;
    type: "promptString" | "pickString" | "command";
    description?: string;
    default?: string;
    options?: string[]; // This is what you were modifying!
}