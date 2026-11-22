(function () {
    'use strict';
    const settings = JSON.parse(document.getElementById('bge-settings').textContent);
    const debug = new URLSearchParams(location.search).get('debug') === '1';
    const status = document.getElementById('status');
    const statusText = document.getElementById('status-text');
    const restart = document.getElementById('restart');

    function showStatus(text, canRestart) {
        statusText.textContent = text;
        restart.hidden = !canRestart;
        status.hidden = false;
    }

    brs.subscribe('bge-standalone', function (event, data) {
        if (event === 'started') {
            status.hidden = true;
            window.__bgeStarted = true;
        } else if (event === 'closed') {
            if (window.bgeHost) {
                window.bgeHost.quit();
            } else {
                showStatus('Game ended', true);
            }
        } else if (event === 'error') {
            window.__bgeError = String(data);
            showStatus('Error: ' + data, true);
        }
    });

    async function fetchBuffer(url) {
        const res = await fetch(url);
        if (!res.ok) {
            throw new Error('could not load ' + url + ' (HTTP ' + res.status + ')');
        }
        return res.arrayBuffer();
    }

    async function start() {
        showStatus('Loading…', false);
        brs.execute('game.zip', await fetchBuffer('game.zip'), { clearDisplayOnExit: false });
    }

    async function main() {
        // brs.initialize() fetches common.zip without awaiting it, so execute() can run
        // before the common: volume exists (no fonts/audio, app crashes). Passing it in avoids the race.
        const deviceInfo = { assets: await fetchBuffer('assets/common.zip') };
        if (settings.sceneGraph) {
            // Path is relative to brs.worker.js.
            deviceInfo.extensions = new Map([['brs-scenegraph', './brs-sg.js']]);
        }
        await brs.initialize(deviceInfo, { disableDebug: !debug, debugToConsole: debug, showStats: debug });
        await start();
    }

    restart.addEventListener('click', function () {
        start().catch(function (e) {
            showStatus('Error: ' + e.message, true);
        });
    });
    main().catch(function (e) {
        window.__bgeError = e.message;
        showStatus('Error: ' + e.message, true);
    });
})();
