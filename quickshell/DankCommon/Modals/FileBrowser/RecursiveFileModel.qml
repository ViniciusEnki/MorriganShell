import QtQuick
import Qt.labs.folderlistmodel
import qs.DankCommon.Common

Item {
    id: root
    width: 0
    height: 0

    // Force recompilation by using a unique component name
    property string _componentVersion: "v20241115c"

    property string folder: ""
    property var nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
    property bool showHidden: false
    property bool showDirs: true
    property int sortField: 0 // 0=Name, 1=Size, 2=Time, 3=Type
    property bool sortReversed: false
    property bool recursive: false

    signal modelReady()
    signal errorOccurred(string message)
    signal runFindCommand(var command, int generation)

    readonly property var _imageExtensions: ["jpg", "jpeg", "png", "bmp", "gif", "webp", "jxl", "avif", "heif", "exr"]
readonly property int _forceReload: 1

    property var _dirModel: null
    property var _combinedModel: null
    property bool _loading: false

    // Timers
    property var _nonRecursiveTimer: null
    property var _dirCheckTimer: null

    // State flags for recursive loading
    property bool _dirsAdded: false
    property bool _filesLoaded: false
    property int _nonRecursiveCheckCount: 0
    property int _dirCheckCount: 0

    // Generation token for concurrency control
    property int _generation: 0
    property bool _startInProgress: false

    function start() {
        // Reentrancy guard - if start() is called while already in progress, skip
        if (_startInProgress) {
            return;
        }

        _startInProgress = true;

        try {
            // Increment generation to invalidate any pending callbacks from previous runs
            _generation++;
            var myGeneration = _generation;

            // Always stop previous process and timers, regardless of _loading state
            if (_nonRecursiveTimer) {
                _nonRecursiveTimer.stop();
                _nonRecursiveTimer = null;
            }
            if (_dirCheckTimer) {
                _dirCheckTimer.stop();
                _dirCheckTimer = null;
            }

            // Reset state flags
            _dirsAdded = false;
            _filesLoaded = false;
            _nonRecursiveCheckCount = 0;
            _dirCheckCount = 0;
            _loading = true;

            // Clear previous model
            if (_combinedModel) {
                _combinedModel.clear();
            } else {
                _combinedModel = Qt.createQmlObject('import QtQuick; ListModel {}', root);
            }

            if (root.recursive) {
                loadRecursive(myGeneration);
            } else {
                loadNonRecursive(myGeneration);
            }
        } finally {
            _startInProgress = false;
        }
    }

    function loadNonRecursive(generation) {
        // Use FolderListModel for non-recursive (existing behavior)
        if (!_dirModel) {
            _dirModel = Qt.createQmlObject('import Qt.labs.folderlistmodel; FolderListModel { showDirsFirst: true; showDotAndDotDot: false; showFiles: true; showDirs: true; caseSensitive: false }', root);
        }
        // FolderListModel expects file:// URL
        var folderUrl = "file://" + folder.split('/').map(function(s) { return encodeURIComponent(s); }).join('/');
        _dirModel.folder = folderUrl;
        _dirModel.nameFilters = nameFilters;
        _dirModel.showHidden = showHidden;

        // Wait for model to populate
        _nonRecursiveCheckCount = 0;
        var timer = Qt.createQmlObject('import QtQuick; Timer { interval: 50; repeat: true; onTriggered: root._checkNonRecursiveReady(' + generation + ') }', root);
        timer.start();
        _nonRecursiveTimer = timer;
    }

    function _checkNonRecursiveReady(generation) {
        // Discard if generation has changed
        if (generation !== _generation) {
            return;
        }

        if (_dirModel.count > 0 || _dirModel.status === FolderListModel.Ready) {
            _nonRecursiveTimer.stop();
            _nonRecursiveTimer = null;
            populateCombinedModel(_dirModel);
            _loading = false;
            modelReady();
        } else if (++_nonRecursiveCheckCount > 100) { // 5 second timeout
            _nonRecursiveTimer.stop();
            _nonRecursiveTimer = null;
            _loading = false;
            errorOccurred("Timeout loading directory");
        }
    }

    function loadRecursive(generation) {
        // Load directories using FolderListModel (for navigation)
        if (!_dirModel) {
            _dirModel = Qt.createQmlObject('import Qt.labs.folderlistmodel; FolderListModel { showDirsFirst: true; showDotAndDotDot: false; showFiles: false; showDirs: true; caseSensitive: false }', root);
        }
        // FolderListModel expects file:// URL
        var folderUrl = "file://" + folder.split('/').map(function(s) { return encodeURIComponent(s); }).join('/');
        _dirModel.folder = folderUrl;
        _dirModel.showHidden = showHidden;

        // Load files recursively using find command - delegate to parent FileBrowserContent
        var findCmd = buildFindCommand(folder);
        runFindCommand(findCmd, generation);

        // Also wait for dir model
        _dirCheckCount = 0;
        var timer = Qt.createQmlObject('import QtQuick; Timer { interval: 50; repeat: true; onTriggered: root._checkDirModelReady(' + generation + ') }', root);
        timer.start();
        _dirCheckTimer = timer;
    }

    function _checkDirModelReady(generation) {
        // Discard if generation has changed
        if (generation !== _generation) {
            return;
        }

        if (_dirModel.status === FolderListModel.Ready) {
            _dirCheckTimer.stop();
            _dirCheckTimer = null;
            // Add directories to combined model
            for (var i = 0; i < _dirModel.count; i++) {
                var item = _dirModel.get(i);
                _combinedModel.append({
                    fileName: item.fileName,
                    filePath: item.filePath,
                    fileIsDir: true,
                    fileSize: 0,
                    fileModified: item.fileModified
                });
            }
            _dirsAdded = true;
            _tryFinalize(generation);
        } else if (++_dirCheckCount > 100) {
            _dirCheckTimer.stop();
            _dirCheckTimer = null;
            _dirsAdded = true;
            _tryFinalize(generation);
        }
    }

    // Called by FileBrowserContent when find process completes
    function onFindFinished(output, generation) {
        // Discard if generation has changed
        if (generation !== _generation) {
            return;
        }

        if (!output || !output.trim()) {
            _filesLoaded = true;
            _tryFinalize(generation);
            return;
        }

        var lines = output.trim().split('\n');
        var addedCount = 0;
        for (var i = 0; i < lines.length; i++) {
            var filePath = lines[i].trim();
            if (!filePath)
                continue;

            // Only include files matching our extensions
            var ext = filePath.split('.').pop().toLowerCase();
            if (!_imageExtensions.includes(ext)) {
                continue;
            }

            var fileName = filePath.split('/').pop();
            var fileUrl = "file://" + filePath.split('/').map(function(s) { return encodeURIComponent(s); }).join('/');
            _combinedModel.append({
                fileName: fileName,
                filePath: fileUrl,
                fileIsDir: false,
                fileSize: 0,
                fileModified: new Date()
            });
            addedCount++;
        }

        _filesLoaded = true;
        _tryFinalize(generation);
    }

    function _tryFinalize(generation) {
        // Discard if generation has changed
        if (generation !== _generation) {
            return;
        }

        if (_dirsAdded && _filesLoaded) {
            sortCombinedModel();
            _loading = false;
            modelReady();
        }
    }

    function populateCombinedModel(sourceModel) {
        _combinedModel.clear();
        for (var i = 0; i < sourceModel.count; i++) {
            var item = sourceModel.get(i);
            _combinedModel.append({
                fileName: item.fileName,
                filePath: item.filePath,
                fileIsDir: item.fileIsDir,
                fileSize: item.fileSize,
                fileModified: item.fileModified
            });
        }
        sortCombinedModel();
    }

    function sortCombinedModel() {
        // Simple sort by name, dirs first
        var items = [];
        for (var i = 0; i < _combinedModel.count; i++) {
            items.push(_combinedModel.get(i));
        }

        items.sort(function(a, b) {
            // Dirs first
            if (a.fileIsDir !== b.fileIsDir)
                return a.fileIsDir ? -1 : 1;

            var nameA = a.fileName.toLowerCase();
            var nameB = b.fileName.toLowerCase();

            if (nameA < nameB)
                return sortReversed ? 1 : -1;
            if (nameA > nameB)
                return sortReversed ? -1 : 1;
            return 0;
        });

        _combinedModel.clear();
        for (var i = 0; i < items.length; i++) {
            _combinedModel.append(items[i]);
        }
    }

    function buildFindCommand(dir) {
        var extensions = _imageExtensions.map(function(e) { return '-iname "*.' + e + '"'; }).join(' -o ');
        return ["sh", "-c", 'find -L "$1" -type f \\(' + extensions + '\\) 2>/dev/null | sort', "find", dir];
    }

    property var model: _combinedModel
    property int count: _combinedModel ? _combinedModel.count : 0

    function get(index, role) {
        if (!_combinedModel || index < 0 || index >= _combinedModel.count)
            return undefined;
        return _combinedModel.get(index)[role];
    }

    Component.onDestruction: {
        if (_nonRecursiveTimer) {
            _nonRecursiveTimer.stop();
        }
        if (_dirCheckTimer) {
            _dirCheckTimer.stop();
        }
    }
}