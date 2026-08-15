pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Queued `magick` thumbnail generator, shared by the wallpaper grid
// (WallpaperPanel), the wallpaper picker list (WallpaperItem), and the
// theme list (AppearancePanel) - each of those used to run its own
// copy-pasted Process for this, and all three wrote to the same
// `<basename>.jpg` cache file regardless of the requested size, so
// whichever ran most recently clobbered the others' thumbnail (a 68x68
// theme icon could stomp a 240x135 wallpaper preview, or vice versa).
// Requests now go through one Process, queued so N missing thumbnails
// at once (e.g. first paint of a wallpaper grid) don't fork N concurrent
// `magick` processes, and the cache filename is keyed by size so
// different requested sizes for the same source never collide.
Singleton {
    id: root

    property var _queue: []
    property var _current: null

    signal ready(string key, bool ok)

    function keyFor(sourcePath, w, h) {
        var base = sourcePath.substring(sourcePath.lastIndexOf("/") + 1);
        return base + "-" + w + "x" + h;
    }

    function pathFor(sourcePath, w, h) {
        return ThemeState.thumbsDir + "/" + root.keyFor(sourcePath, w, h) + ".jpg";
    }

    // Enqueues generation if needed and returns the (eventual) cache path -
    // callers point their Image at this immediately; it's only actually
    // valid once `ready` fires for the same key (Image.Error until then,
    // which is what triggers the request in the first place).
    function request(sourcePath, w, h) {
        var job = {
            source: sourcePath,
            w: w,
            h: h,
            key: root.keyFor(sourcePath, w, h)
        };
        if (root._proc.running || root._current)
            root._queue.push(job);
        else
            root._run(job);
        return root.pathFor(sourcePath, w, h);
    }

    function _run(job) {
        root._current = job;
        root._proc.command = ["magick", job.source, "-resize", job.w + "x" + job.h + "^", "-gravity", "Center", "-extent", job.w + "x" + job.h, root.pathFor(job.source, job.w, job.h)];
        root._proc.running = true;
    }

    function _runNext() {
        if (root._proc.running || root._queue.length === 0)
            return;
        root._run(root._queue.shift());
    }

    property Process _proc: Process {
        onExited: (code, status) => {
            var job = root._current;
            root._current = null;
            if (job)
                root.ready(job.key, code === 0);
            Qt.callLater(root._runNext);
        }
    }
}
