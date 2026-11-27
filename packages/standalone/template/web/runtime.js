(function () {
    'use strict';
    const settings = JSON.parse(document.getElementById('bge-settings').textContent);
    const debug = new URLSearchParams(location.search).get('debug') === '1';
    const status = document.getElementById('status');
    const statusText = document.getElementById('status-text');
    const restart = document.getElementById('restart');
    let initialized = false;

    function showStatus(text, canRestart) {
        statusText.textContent = text;
        restart.hidden = !canRestart;
        restart.disabled = false;
        status.hidden = false;
    }

    function fail(message) {
        window.__bgeError = message;
        showStatus('Error: ' + message, true);
    }

    brs.subscribe('bge-standalone', function (event, data) {
        if (event === 'started') {
            status.hidden = true;
            window.__bgeStarted = true;
        } else if (event === 'closed') {
            // `data` is the exit reason. A game quitting (Back, End()) reports EXIT_USER_NAV;
            // anything else (EXIT_BRIGHTSCRIPT_CRASH, ...) is shown rather than silently closing.
            if (data !== 'EXIT_USER_NAV') {
                fail('Game crashed (' + data + ')');
            } else if (window.bgeHost) {
                window.bgeHost.quit();
            } else {
                showStatus('Game ended', true);
            }
        } else if (event === 'error') {
            fail(data && data.message ? data.message : String(data));
        }
    });

    async function fetchBuffer(url) {
        const res = await fetch(url);
        if (!res.ok) {
            throw new Error('could not load ' + url + ' (HTTP ' + res.status + ')');
        }
        return res.arrayBuffer();
    }

    async function initialize() {
        // brs.initialize() fetches common.zip without awaiting it, so execute() can run
        // before the common: volume exists (no fonts/audio, app crashes). Passing it in avoids the race.
        const deviceInfo = { assets: await fetchBuffer('assets/common.zip') };
        if (settings.sceneGraph) {
            // Path is relative to brs.worker.js.
            deviceInfo.extensions = new Map([['brs-scenegraph', './brs-sg.js']]);
        }
        await brs.initialize(deviceInfo, { disableDebug: !debug, debugToConsole: debug, showStats: debug });
        initialized = true;
    }

    async function start() {
        window.__bgeStarted = false;
        delete window.__bgeError;
        showStatus('Loading…', false);
        if (!initialized) {
            await initialize();
        }
        brs.execute('game.zip', await fetchBuffer('game.zip'), { clearDisplayOnExit: false });
    }

    function run() {
        start().catch(function (e) {
            fail(e && e.message ? e.message : String(e));
        });
    }

    restart.addEventListener('click', function () {
        // Guard against double clicks while the restart is in flight.
        restart.disabled = true;
        restart.hidden = true;
        run();
    });
    run();
})();
