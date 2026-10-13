import QtQuick
import Quickshell.Io

// Runs short-lived commands and calls back with (exitCode, stdout, stderr). stdin, if
// given, is written then closed, so secrets and tokens never show up in argv.
QtObject {
    id: root

    function run(command, stdinText, cb) {
        var p = _procComp.createObject(root, { command: command, stdinEnabled: stdinText !== null });
        p.started.connect(function () {
            if (stdinText !== null) {
                p.write(stdinText);
                p.stdinEnabled = false;
            }
        });
        p.exited.connect(function (code) {
            var out = p.stdout.text, err = p.stderr.text;
            p.destroy();
            cb(code, out, err);
        });
        p.running = true;
    }

    property Component _procComp: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }
}
