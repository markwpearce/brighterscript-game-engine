// bsc plugin for test builds of roScreen tests (everything that makes a BGE.Game).
//
// Rooibos runs every suite on the main thread inside its SceneGraph test scene, and reads or
// writes scene nodes before each suite (m.nodeContext.global, scene.testText). On a Roku those
// are rendezvous with the render thread, and once a BGE.Game has made an roScreen they never
// return: the app hangs after the first suite and Ctrl-C can't break in. So this patches the
// runner as it's written:
// - read the SceneGraph nodes once, before any suite runs, and skip the status-text writes
// - act as the simulator's render tier (GetGlobalAA().bgeDeviceRenderTier), so caps and scratch
//   sizes that depend on it are the same on a device as headless
// - drop each finished suite's own fields (Rooibos keeps every suite, and with it the spec's last
//   game and bitmaps) and collect them
// - collect garbage after every test: a BGE.Game has reference cycles, so its bitmaps (~3.7MB)
//   are only freed by the GC, and a device runs out of texture memory after ~300 tests
//
// SceneGraph tests (@SGNode suites) need the scene, so they run in their own build, which turns
// this off with `"roScreenTestRunner": false` in its bsconfig (see scripts/run-tests-sharded.js).
// A Rooibos upgrade that moves the patched code fails the build here rather than hanging on a
// device.

const PATCHES = {
    'source/rooibos/testrunner.brs': [
        {
            find: /\n(\s*)for each name in suiteNames\n/,
            // also pins BGE.getDeviceRenderTier() to simulator, so tier-dependent caps and sizes match
            // headless runs, and makes a bare suite (a stub stands in for its generated test data)
            // whose keys are Rooibos's own
            replace: (match, indent) => `\n${indent}cachedGlobal = m.nodeContext.global\n${indent}cachedTop = m.nodeContext.top\n${indent}cachedScene = cachedGlobal.testsScene\n${indent}GetGlobalAA().bgeDeviceRenderTier = "simulator"\n${indent}rooibosOwnKeys = __rooibos_BaseTestSuite_builder()\n${indent}rooibosOwnKeys.getTestSuiteData = function() as object\n${indent}    return {testGroups: [], isNodeTest: false}\n${indent}end function\n${indent}rooibosOwnKeys.new()\n${indent}for each name in suiteNames\n`
        },
        { find: /testSuite\.global = m\.nodeContext\.global/, replace: () => 'testSuite.global = cachedGlobal' },
        { find: /testSuite\.top = m\.nodeContext\.top/, replace: () => 'testSuite.top = cachedTop' },
        { find: /testSuite\.scene = m\.nodeContext\.global\.testsScene/, replace: () => 'testSuite.scene = cachedScene' },
        {
            // a fresh suite's keys are Rooibos's own; anything else (a spec's game, bitmaps...) goes
            find: /\n(\s*)m\.runTestSuite\(testSuite\)\n/,
            replace: (match, indent) => [
                '',
                `${indent}m.runTestSuite(testSuite)`,
                `${indent}for each suiteKey in testSuite.keys()`,
                `${indent}    suiteValueType = type(testSuite[suiteKey])`,
                `${indent}    if not rooibosOwnKeys.DoesExist(suiteKey) and suiteValueType <> "Function" and suiteValueType <> "roFunction" and suiteKey <> "testRunner" and suiteKey <> "testReporters" and suiteKey <> "global" and suiteKey <> "top" and suiteKey <> "scene" then`,
                `${indent}        testSuite[suiteKey] = invalid`,
                `${indent}    end if`,
                `${indent}end for`,
                `${indent}RunGarbageCollector()`,
                ''
            ].join('\n')
        },
        // status text on the scene: purely cosmetic, and a rendezvous
        { find: /\n(\s*)testSuite\.scene\.(testText|statusColor|failedText) = /g, replace: (match, indent) => `\n${indent}rooibosSceneText = ` },
        { find: /\n(\s*)m\.nodeContext\.global\.testsScene\.failedText = /, replace: (match, indent) => `\n${indent}rooibosSceneText = ` },
        // the result on the scene (another rendezvous) comes before the [Rooibos Result] line, which
        // run-tests-device.js waits for; the console reporters already printed everything in it
        { find: /\n(\s*)m\.nodeContext\.global\.testsScene\.rooibosTestResult = rooibosResult\n/, replace: (match, indent) => `\n${indent}rooibosSceneResult = rooibosResult\n` }
    ],
    'source/rooibos/testgroup.brs': [
        {
            // both the sync and @async paths
            find: /\n(\s*)m\.runSuiteFunction\(m\.afterEachFunctionName, "afterEach", (test|m\.currentTest)\)\n/g,
            replace: (match, indent, test) => `\n${indent}m.runSuiteFunction(m.afterEachFunctionName, "afterEach", ${test})\n${indent}RunGarbageCollector()\n`
        }
    ]
};

class RooibosRoScreenRunnerPlugin {
    constructor() {
        this.name = 'rooibos-roscreen-runner';
    }

    beforeWriteFile(event) {
        if (event.program.options.roScreenTestRunner === false) {
            return;
        }
        const pkgPath = event.file.pkgPath.replace(/\\/g, '/').toLowerCase();
        const patches = PATCHES[pkgPath];
        if (!patches) {
            return;
        }
        let code = event.file.data.toString();
        for (const patch of patches) {
            if (!patch.find.test(code)) {
                throw new Error(`rooibos-roscreen-runner: can't find ${patch.find} in ${event.file.pkgPath} - has Rooibos changed?`);
            }
            patch.find.lastIndex = 0;
            code = code.replace(patch.find, patch.replace);
        }
        event.file.data = Buffer.from(code);
    }
}

module.exports = () => new RooibosRoScreenRunnerPlugin();
module.exports.default = module.exports;
