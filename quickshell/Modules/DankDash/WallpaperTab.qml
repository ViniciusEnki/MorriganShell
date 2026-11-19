import Qt.labs.folderlistmodel
import qs.Services
import QtCore
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Common
import qs.Modals.FileBrowser
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    implicitWidth: SettingsData.showWeekNumber ? 736 : 700
    implicitHeight: 410

    property string wallpaperDir: ""
    readonly property string searchQuery: wallpaperSearchField.text
    property var filteredWallpaperPaths: []
    readonly property int wallpaperCount: filteredWallpaperPaths.length
    property bool active: false
    property bool searchExpanded: false
    property Item focusTarget: searchExpanded ? wallpaperSearchField : searchToggleButton
    property Item tabBarItem: null
    property int gridIndex: 0
    property Item keyForwardTarget: null
    property var parentPopout: null
    property bool enableAnimation: false
    property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    property string selectedFileName: ""
    property var targetScreen: null
    property string targetScreenName: targetScreen ? targetScreen.name : ""
    // Shared with the wallpaper FileBrowser via CacheData.fileBrowserSettings["wallpaper"]
    property string sortBy: "name"
    property bool sortAscending: true
    // Forces the grid to rebuild when the folder model reorders in place.
    property int gridRevision: 0

    // Recursive wallpaper model
    property var recursiveWallpaperPaths: []
    property bool recursiveModelLoading: false
    property bool recursiveModelReady: false

    // Process for recursive find
    Process {
        id: wallpaperFindProcess
        property int currentGeneration: 0
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.onWallpaperFindFinished(text, wallpaperFindProcess.currentGeneration);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    log.warn("[WallpaperTab] find stderr:", { stderr: text.trim(), generation: wallpaperFindProcess.currentGeneration });
                }
            }
        }
        onExited: {
            // Handled via onWallpaperFindFinished with empty output
        }
    }

    signal requestTabChange(int newIndex)

    function refreshAfterSort() {
        // Defer until FolderListModel finishes reordering.
        Qt.callLater(() => {
            rebuildWallpaperList(true);
        });
    }

    function cleanFilePath(path) {
        return path ? path.toString().replace(/^file:\/\//, '') : "";
    }

    function wallpaperPathAt(index) {
        if (index < 0 || index >= wallpaperCount)
            return "";
        return filteredWallpaperPaths[index] || "";
    }

    function searchTerms() {
        const query = searchQuery.trim().toLowerCase();
        return query ? query.split(/\s+/).filter(t => t.length > 0) : [];
    }

    function matchesTerms(terms, fileName, filePath) {
        if (terms.length === 0)
            return true;

        const haystack = (fileName + " " + filePath).toLowerCase();
        for (let i = 0; i < terms.length; i++) {
            if (haystack.indexOf(terms[i]) === -1)
                return false;
        }
        return true;
    }

    function rebuildWallpaperList(preferCurrentWallpaper) {
        const paths = [];

        // Use recursive model if ready, otherwise fall back to FolderListModel
        if (recursiveModelReady) {
            const terms = searchTerms();
            for (let i = 0; i < recursiveWallpaperPaths.length; i++) {
                const filePath = recursiveWallpaperPaths[i];
                if (!filePath)
                    continue;
                if (terms.length > 0) {
                    const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
                    if (!matchesTerms(terms, fileName, filePath))
                        continue;
                }
                paths.push(filePath);
            }
        } else if (wallpaperFolderModel.status === FolderListModel.Ready) {
            const terms = searchTerms();
            const rowCount = wallpaperFolderModel.count;
            for (let i = 0; i < rowCount; i++) {
                const filePath = cleanFilePath(wallpaperFolderModel.get(i, "filePath"));
                if (!filePath)
                    continue;
                if (terms.length > 0) {
                    const fileName = wallpaperFolderModel.get(i, "fileName") || filePath.substring(filePath.lastIndexOf('/') + 1);
                    if (!matchesTerms(terms, fileName, filePath))
                        continue;
                }
                paths.push(filePath);
            }
        }

        const selectCurrent = preferCurrentWallpaper && visible && active;
        if (selectCurrent) {
            enableAnimation = false;
            const currentWallpaper = getCurrentWallpaper();
            let matched = false;
            if (currentWallpaper) {
                for (let i = 0; i < paths.length; i++) {
                    if (paths[i] === currentWallpaper) {
                        gridIndex = i;
                        matched = true;
                        break;
                    }
                }
            }
            if (!matched) {
                gridIndex = 0;
            }
        } else {
            gridIndex = Math.min(gridIndex, Math.max(0, paths.length - 1));
        }

        filteredWallpaperPaths = paths;
        gridRevision++;
        updateSelectedFileName();
        if (selectCurrent) {
            Qt.callLater(() => {
                enableAnimation = true;
            });
        }
    }

    function focusSearch() {
        searchExpanded = true;
        Qt.callLater(() => {
            wallpaperSearchField.forceActiveFocus();
            wallpaperSearchField.selectAll();
        });
    }

    function clearSearch() {
        wallpaperSearchField.clear();
    }

    function collapseSearch() {
        clearSearch();
        searchExpanded = false;
        if (keyForwardTarget)
            keyForwardTarget.forceActiveFocus();
    }

    onSortByChanged: refreshAfterSort()
    onSortAscendingChanged: refreshAfterSort()
    onSearchQueryChanged: {
        gridIndex = 0;
        searchDebounce.restart();
    }

    function loadSort() {
        const s = CacheData.fileBrowserSettings["wallpaper"];
        if (s) {
            sortBy = s.sortBy || "name";
            sortAscending = s.sortAscending !== undefined ? s.sortAscending : true;
        }
    }

    function persistSort() {
        let settings = CacheData.fileBrowserSettings;
        if (!settings["wallpaper"])
            settings["wallpaper"] = {};
        settings["wallpaper"].sortBy = sortBy;
        settings["wallpaper"].sortAscending = sortAscending;
        CacheData.fileBrowserSettings = settings;
        CacheData.saveCache();
    }

    function getCurrentWallpaper() {
        if (SessionData.perMonitorWallpaper && targetScreenName) {
            return SessionData.getMonitorWallpaper(targetScreenName);
        }
        return SessionData.wallpaperPath;
    }

    function getWallpaperDirectory() {
        // Use configured cycling folder path if set, regardless of whether cycling is enabled
        // This allows the Dashboard gallery to show all images from the configured folder
        if (SessionData.perMonitorWallpaper && targetScreenName) {
            const monitorSettings = SessionData.getMonitorCyclingSettings(targetScreenName);
            if (monitorSettings.folderPath) {
                return monitorSettings.folderPath;
            }
            // Fall back to global cycling folder path if monitor-specific path is not configured
            if (SessionData.wallpaperCyclingFolderPath) {
                return SessionData.wallpaperCyclingFolderPath;
            }
        } else if (SessionData.wallpaperCyclingFolderPath) {
            return SessionData.wallpaperCyclingFolderPath;
        }

        // Fallback: current wallpaper directory
        const currentWallpaper = getCurrentWallpaper();
        if (currentWallpaper && !currentWallpaper.startsWith("#")) {
            return currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'));
        }
        return "";
    }

    function setCurrentWallpaper(path) {
        if (SessionData.perMonitorWallpaper && targetScreenName) {
            SessionData.setMonitorWallpaper(targetScreenName, path);
            // Do NOT clear the cycling folder path when selecting a specific wallpaper image
            // The cycling folder should only be cleared when explicitly choosing a new cycling folder
        } else {
            SessionData.setWallpaper(path);
            // Do NOT clear wallpaperCyclingFolderPath when selecting a specific wallpaper image
            SessionData.saveSettings();
        }
    }

    onGridIndexChanged: {
        updateSelectedFileName();
    }

    onVisibleChanged: {
        if (visible && active) {
            setInitialSelection();
        }
    }

    Component.onCompleted: {
        loadSort();
        loadWallpaperDirectory();
    }

    Connections {
        target: CacheData
        function onFileBrowserSettingsChanged() {
            loadSort();
        }
    }

    onActiveChanged: {
        if (active && visible) {
            setInitialSelection();
        }
    }

    function goToNextCell() {
        if (gridIndex + 1 < wallpaperCount) {
            gridIndex++;
        } else if (wallpaperCount > 1) {
            gridIndex = 0;
        }
    }

    function goToPrevCell() {
        if (gridIndex > 0) {
            gridIndex--;
        } else if (wallpaperCount > 1) {
            gridIndex = wallpaperCount - 1;
        }
    }

    function closeOverlays() {
        if (sortMenu.visible || pageJumpPopup.visible) {
            sortMenu.visible = false;
            pageJumpPopup.visible = false;
            return true;
        }
        return false;
    }

    function handleKeyEvent(event) {
        if (event.key === Qt.Key_Escape) {
            if (closeOverlays())
                return true;
            if (searchQuery !== "") {
                clearSearch();
                return true;
            }
            if (searchExpanded) {
                collapseSearch();
                return true;
            }
            return false;
        }

        if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            closeOverlays();
            focusSearch();
            return true;
        }
        const columns = 4;

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (gridIndex >= 0 && gridIndex < wallpaperCount) {
                const filePath = filteredWallpaperPaths[gridIndex];
                if (filePath) {
                    setCurrentWallpaper(filePath);
                }
            }
            return true;
        }

        if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            if (I18n.isRtl) {
                goToPrevCell();
            } else {
                goToNextCell();
            }
            return true;
        }

        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            if (I18n.isRtl) {
                goToNextCell();
            } else {
                goToPrevCell();
            }
            return true;
        }

        if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            if (gridIndex + columns < wallpaperCount) {
                gridIndex += columns;
            } else if (wallpaperCount > 1) {
                gridIndex = wallpaperCount - 1;
            }
            return true;
        }

        if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            if (gridIndex >= columns) {
                gridIndex -= columns;
            } else if (wallpaperCount > 1) {
                gridIndex = 0;
            }
            return true;
        }

        if (event.key === Qt.Key_PageUp) {
            gridIndex = Math.max(0, gridIndex - columns * 4);
            return true;
        }

        if (event.key === Qt.Key_PageDown) {
            gridIndex = Math.min(wallpaperCount - 1, gridIndex + columns * 4);
            return true;
        }

        if (event.key === Qt.Key_Home && (event.modifiers & Qt.ControlModifier)) {
            gridIndex = 0;
            return true;
        }

        if (event.key === Qt.Key_End && (event.modifiers & Qt.ControlModifier)) {
            gridIndex = Math.max(0, wallpaperCount - 1);
            return true;
        }

        return false;
    }

    function setInitialSelection() {
        enableAnimation = false;
        const currentWallpaper = getCurrentWallpaper();
        if (!currentWallpaper || wallpaperCount === 0) {
            gridIndex = 0;
            updateSelectedFileName();
            Qt.callLater(() => {
                enableAnimation = true;
            });
            return;
        }

        for (var i = 0; i < wallpaperCount; i++) {
            const filePath = filteredWallpaperPaths[i];
            if (filePath === currentWallpaper) {
                gridIndex = i;
                updateSelectedFileName();
                Qt.callLater(() => {
                    enableAnimation = true;
                });
                return;
            }
        }
        gridIndex = 0;
        updateSelectedFileName();
        Qt.callLater(() => {
            enableAnimation = true;
        });
    }

    function loadWallpaperDirectory() {
        const dir = getWallpaperDirectory();

        if (!dir) {
            if (CacheData.wallpaperLastPath && CacheData.wallpaperLastPath !== "") {
                wallpaperDir = CacheData.wallpaperLastPath;
            } else {
                wallpaperDir = "";
                recursiveWallpaperPaths = [];
                recursiveModelReady = true;
                rebuildWallpaperList(true);
                return;
            }
        } else {
            wallpaperDir = dir;
        }

        // Start recursive find
        startRecursiveFind();
    }

    function buildFindCommand(dir) {
        return ["sh", "-c", 'find -L "$1" -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jxl" -o -iname "*.avif" -o -iname "*.heif" -o -iname "*.exr" \\) 2>/dev/null | sort', "find", dir];
    }

    function startRecursiveFind() {
        if (recursiveModelLoading) {
            return;
        }

        if (!wallpaperDir) {
            recursiveWallpaperPaths = [];
            recursiveModelLoading = false;
            recursiveModelReady = true;
            rebuildWallpaperList(true);
            return;
        }

        recursiveModelLoading = true;
        recursiveModelReady = false;

        wallpaperFindProcess.currentGeneration++;
        const generation = wallpaperFindProcess.currentGeneration;

        const cmd = buildFindCommand(wallpaperDir);
        wallpaperFindProcess.currentGeneration = generation;
        wallpaperFindProcess.command = cmd;
        wallpaperFindProcess.running = true;
    }

    function onWallpaperFindFinished(output, generation) {
        if (generation !== wallpaperFindProcess.currentGeneration) {
            return;
        }

        if (!output || !output.trim()) {
            recursiveWallpaperPaths = [];
            recursiveModelLoading = false;
            recursiveModelReady = true;
            rebuildWallpaperList(true);
            return;
        }

        const lines = output.trim().split('\n');
        const paths = [];

        for (let i = 0; i < lines.length; i++) {
            const filePath = lines[i].trim();
            if (!filePath)
                continue;

            const ext = filePath.split('.').pop().toLowerCase();
            if (!["jpg", "jpeg", "png", "bmp", "gif", "webp", "jxl", "avif", "heif", "exr"].includes(ext)) {
                continue;
            }

            paths.push(filePath);
        }

        // Sort paths
        paths.sort();

        recursiveWallpaperPaths = paths;
        recursiveModelLoading = false;
        recursiveModelReady = true;

        rebuildWallpaperList(true);
    }

    function updateSelectedFileName() {
        if (wallpaperCount === 0) {
            selectedFileName = "";
            return;
        }

        if (gridIndex >= 0 && gridIndex < wallpaperCount) {
            const filePath = filteredWallpaperPaths[gridIndex];
            if (filePath) {
                selectedFileName = filePath.substring(filePath.lastIndexOf('/') + 1);
                return;
            }
        }
        selectedFileName = "";
    }

    Connections {
        target: SessionData
        function onWallpaperPathChanged() {
            loadWallpaperDirectory();
            if (visible && active) {
                setInitialSelection();
            }
        }
        function onMonitorWallpapersChanged() {
            loadWallpaperDirectory();
            if (visible && active) {
                setInitialSelection();
            }
        }
        function onPerMonitorWallpaperChanged() {
            loadWallpaperDirectory();
            if (visible && active) {
                setInitialSelection();
            }
        }
    }

    onTargetScreenNameChanged: {
        loadWallpaperDirectory();
        if (visible && active) {
            setInitialSelection();
        }
    }

    Connections {
        target: wallpaperFolderModel
        function onCountChanged() {
            if (wallpaperFolderModel.status === FolderListModel.Ready)
                rebuildWallpaperList(true);
        }
        function onStatusChanged() {
            rebuildWallpaperList(wallpaperFolderModel.status === FolderListModel.Ready);
        }
    }

    // Trigger rebuild when recursive model becomes ready
    onRecursiveModelReadyChanged: {
        if (recursiveModelReady) {
            rebuildWallpaperList(true);
        }
    }

    Timer {
        id: searchDebounce

        interval: 60
        repeat: false
        onTriggered: root.rebuildWallpaperList(false)
    }

    FolderListModel {
        id: wallpaperFolderModel

        showDirsFirst: false
        showDotAndDotDot: false
        showHidden: false
        caseSensitive: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
        showFiles: true
        showDirs: false
        sortField: {
            switch (root.sortBy) {
            case "size":
                return FolderListModel.Size;
            case "modified":
                return FolderListModel.Time;
            case "type":
                return FolderListModel.Type;
            default:
                return FolderListModel.Name;
            }
        }
        sortReversed: !root.sortAscending
        folder: wallpaperDir ? "file://" + wallpaperDir.split('/').map(s => encodeURIComponent(s)).join('/') : ""
    }

    Item {
        id: searchKeyHandler

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                event.accepted = false;
                if (root.keyForwardTarget)
                    root.keyForwardTarget.Keys.pressed(event);
                return;
            }

            const ctrlHomeOrEnd = (event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Home || event.key === Qt.Key_End);
            const gridNavigationKey = event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape || ctrlHomeOrEnd;
            if (!gridNavigationKey)
                return;

            event.accepted = root.handleKeyEvent(event);
            if (!event.accepted && root.keyForwardTarget)
                root.keyForwardTarget.Keys.pressed(event);
        }
    }

    Loader {
        id: wallpaperBrowserLoader

        active: false

        sourceComponent: FileBrowserSurfaceModal {
            browserTitle: I18n.tr("Select Wallpaper Directory", "wallpaper directory file browser title")
            browserIcon: "folder_open"
            browserType: "wallpaper"
            showHiddenFiles: false
            fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
            parentPopout: root.parentPopout

            onFileSelected: path => {
                const cleanPath = path.replace(/^file:\/\//, '');
                root.setCurrentWallpaper(cleanPath);

                const dirPath = cleanPath.substring(0, cleanPath.lastIndexOf('/'));
                if (dirPath) {
                    root.wallpaperDir = dirPath;
                    CacheData.wallpaperLastPath = dirPath;
                    CacheData.saveCache();
                }
                close();
            }
        }
    }

    Item {
        id: contentRoot
        anchors.fill: parent

        GridView {
            id: gridView
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50
            cellWidth: width / 4
            cellHeight: cellWidth * 9 / 16
            interactive: true
            keyNavigationEnabled: true
            activeFocusOnTab: true
            focus: root.active
            highlightFollowsCurrentItem: true
            highlightMoveDuration: root.enableAnimation ? Theme.shortDuration : 0
            currentIndex: root.gridIndex
            cacheBuffer: Math.max(0, height * 1)
            model: root.filteredWallpaperPaths
            clip: true

            onCountChanged: {
            }

            onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex !== root.gridIndex) {
                    root.gridIndex = currentIndex;
                }
            }

            Connections {
                target: root
                function onGridIndexChanged() {
                    if (gridView.currentIndex !== root.gridIndex) {
                        gridView.currentIndex = root.gridIndex;
                    }
                }
                function onFilteredWallpaperPathsChanged() {
                    if (gridView.currentIndex >= gridView.count) {
                        gridView.currentIndex = Math.max(0, gridView.count - 1);
                        root.gridIndex = gridView.currentIndex;
                    }
                }
            }

            delegate: Item {
                width: gridView.cellWidth
                height: gridView.cellHeight

                property string wallpaperPath: modelData || ""
                property bool isSelected: getCurrentWallpaper() === modelData

                Rectangle {
                    id: wallpaperCard
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    radius: Theme.cornerRadius

                    Rectangle {
                        anchors.fill: parent
                        color: isSelected ? Theme.primaryPressed : Theme.withAlpha(Theme.primaryPressed, 0)
                        radius: parent.radius

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    // Image with clipping - inset by border width when selected
                    ClippingRectangle {
                        id: imageClip
                        anchors.fill: parent
                        anchors.margins: isSelected ? 3 : 0
                        radius: wallpaperCard.radius - (isSelected ? 3 : 0)
                        color: "transparent"

                        CachingImage {
                            id: thumbnailImage
                            anchors.fill: parent
                            imagePath: modelData || ""
                            maxCacheSize: 256
                            animate: false
                            opacity: status === Image.Ready ? 1 : 0

                            onStatusChanged: {
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }

                    // Selection border (inset, rendered above image)
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: isSelected ? Theme.primary : "transparent"
                        border.width: isSelected ? 3 : 0
                        radius: wallpaperCard.radius

                        Behavior on border.width {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    // Check badge in top-right corner
                    Rectangle {
                        width: 24
                        height: 24
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        radius: 12
                        color: isSelected ? Theme.primary : "transparent"
                        visible: isSelected

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            name: "check"
                            size: 12
                            color: Theme.onPrimary
                        }
                    }

                    StateLayer {
                        anchors.fill: parent
                        cornerRadius: parent.radius
                        stateColor: Theme.primary
                    }

                    MouseArea {
                        id: wallpaperMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            gridView.currentIndex = index;
                            if (modelData) {
                                setCurrentWallpaper(modelData);
                            }
                        }
                    }
                }
            }
        }

        DankSpinner {
            anchors.centerIn: gridView
            size: 40
            visible: wallpaperFolderModel.status === FolderListModel.Loading && wallpaperFolderModel.count === 0
        }

        StyledText {
            anchors.centerIn: gridView
            visible: wallpaperFolderModel.status === FolderListModel.Ready && root.wallpaperCount === 0
            text: root.searchQuery.trim() !== "" ? I18n.tr("No results found") : I18n.tr("No wallpapers found\n\nClick the folder icon below to browse")
            font.pixelSize: 14
            color: Theme.outline
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Column {
        id: bottomToolbar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        spacing: Theme.spacingXS

        StyledText {
            width: parent.width
            height: 18
            text: selectedFileName
            font.pixelSize: 12
            color: Theme.surfaceText
            opacity: 0.5
            visible: selectedFileName !== ""
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            width: controlsRow.width + actionButtons.width + spacing
            height: 32
            spacing: Theme.spacingS

            Row {
                id: controlsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "skip_previous"
                    iconSize: 20
                    buttonSize: 32
                    enabled: wallpaperCount > 1
                    opacity: enabled ? 1.0 : 0.3
                    tooltipText: I18n.tr("Previous wallpaper")
                    tooltipSide: "top"
                    onClicked: {
                        goToPrevCell();
                    }
                }

                StyledText {
                    id: pageIndicator
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.wallpaperCount > 0 ? (root.wallpaperCount === 1 ? I18n.tr("%1 wallpaper  •  %2 of %3").arg(root.wallpaperCount).arg(root.gridIndex + 1).arg(root.wallpaperCount) : I18n.tr("%1 wallpapers  •  %2 of %3").arg(root.wallpaperCount).arg(root.gridIndex + 1).arg(root.wallpaperCount)) : I18n.tr("No wallpapers")
                    font.pixelSize: 14
                    color: pageIndicatorMouseArea.containsMouse && pageIndicatorMouseArea.enabled ? Theme.primary : Theme.surfaceText
                    opacity: 0.7

                    MouseArea {
                        id: pageIndicatorMouseArea
                        anchors.fill: parent
                        enabled: wallpaperCount > 1
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            sortMenu.visible = false;
                            pageJumpPopup.visible = !pageJumpPopup.visible;
                        }
                        onEntered: if (enabled)
                            pageJumpTooltip.show(I18n.tr("Jump to wallpaper"), pageIndicator, 0, 0, "top")
                        onExited: pageJumpTooltip.hide()
                    }

                    DankTooltipV2 {
                        id: pageJumpTooltip
                    }
                }

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "skip_next"
                    iconSize: 20
                    buttonSize: 32
                    enabled: wallpaperCount > 1
                    opacity: enabled ? 1.0 : 0.3
                    tooltipText: I18n.tr("Next wallpaper")
                    tooltipSide: "top"
                    onClicked: {
                        goToNextCell();
                    }
                }
            }

            Row {
                id: actionButtons

                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankActionButton {
                    id: sortButton
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "filter_list"
                    iconSize: 20
                    buttonSize: 32
                    opacity: 0.7
                    enabled: wallpaperFolderModel.count > 0
                    tooltipText: I18n.tr("Sort wallpapers")
                    tooltipSide: "top"
                    onClicked: {
                        pageJumpPopup.visible = false;
                        sortMenu.visible = !sortMenu.visible;
                    }
                }

                DankActionButton {
                    id: browseButton
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "folder_open"
                    iconSize: 20
                    buttonSize: 32
                    opacity: 0.7
                    tooltipText: I18n.tr("Choose wallpaper folder")
                    tooltipSide: "top"
                    onClicked: {
                        wallpaperBrowserLoader.active = true;
                        wallpaperBrowserLoader.item.open();
                    }
                }

                Item {
                    id: searchControl

                    anchors.verticalCenter: parent.verticalCenter
                    width: root.searchExpanded ? 190 : 32
                    height: 32
                    clip: true

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    DankActionButton {
                        id: searchToggleButton

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "search"
                        iconSize: 20
                        buttonSize: 32
                        opacity: root.searchExpanded ? 0 : 0.7
                        visible: opacity > 0
                        tooltipText: I18n.tr("Search...")
                        tooltipSide: "top"
                        onClicked: root.focusSearch()

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    DankTextField {
                        id: wallpaperSearchField

                        anchors.fill: parent
                        topPadding: Theme.spacingXS
                        bottomPadding: Theme.spacingXS
                        leftIconName: "search"
                        leftIconSize: 18
                        showClearButton: false
                        rightAccessoryWidth: root.searchQuery !== "" ? 54 : 26
                        placeholderText: I18n.tr("Search...")
                        keyForwardTargets: [searchKeyHandler]
                        opacity: root.searchExpanded ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    DankActionButton {
                        anchors.right: collapseSearchButton.left
                        anchors.verticalCenter: parent.verticalCenter
                        z: 2
                        iconName: "backspace"
                        iconSize: 16
                        buttonSize: 28
                        opacity: root.searchExpanded && root.searchQuery !== "" ? 0.7 : 0
                        visible: opacity > 0
                        tooltipText: I18n.tr("Clear")
                        tooltipSide: "top"
                        onClicked: root.clearSearch()

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    DankActionButton {
                        id: collapseSearchButton

                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        z: 2
                        iconName: "close"
                        iconSize: 16
                        buttonSize: 28
                        opacity: root.searchExpanded ? 0.7 : 0
                        visible: opacity > 0
                        tooltipText: I18n.tr("Close")
                        tooltipSide: "top"
                        onClicked: root.collapseSearch()

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }
                }
            }
        }

        DankSpinner {
            anchors.centerIn: gridView
            size: 40
            visible: wallpaperFolderModel.status === FolderListModel.Loading && wallpaperFolderModel.count === 0
        }

        StyledText {
            anchors.centerIn: gridView
            visible: wallpaperFolderModel.status === FolderListModel.Ready && root.wallpaperCount === 0
            text: root.searchQuery.trim() !== "" ? I18n.tr("No results found") : I18n.tr("No wallpapers found\n\nClick the folder icon below to browse")
            font.pixelSize: 14
            color: Theme.outline
            horizontalAlignment: Text.AlignHCenter
        }
    }

    function jumpToPage(value) {
        const n = parseInt(value);
        if (!isNaN(n)) {
            gridIndex = Math.max(0, Math.min(wallpaperCount - 1, n - 1));
        }
        pageJumpPopup.visible = false;
    }

    // Click anywhere outside an open overlay to dismiss it.
    MouseArea {
        anchors.fill: parent
        z: 99
        visible: sortMenu.visible || pageJumpPopup.visible
        enabled: visible
        onClicked: closeOverlays()
    }

    BackdropBlur {
        visible: sortMenu.visible
        z: 100
        width: sortMenu.width
        height: sortMenu.height
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.spacingM
        anchors.bottomMargin: 56
        radius: Theme.cornerRadius
        sourceItem: contentRoot
    }

    FileBrowserSortMenu {
        id: sortMenu
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.spacingM
        anchors.bottomMargin: 56
        z: 101
        surfaceColor: Theme.readableSurface
        sortBy: root.sortBy
        sortAscending: root.sortAscending
        onSortBySelected: value => {
            root.sortBy = value;
            root.persistSort();
        }
        onSortOrderSelected: ascending => {
            root.sortAscending = ascending;
            root.persistSort();
        }
    }

    BackdropBlur {
        visible: pageJumpPopup.visible
        z: 100
        width: pageJumpPopup.width
        height: pageJumpPopup.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 56
        radius: Theme.cornerRadius
        sourceItem: contentRoot
    }

    StyledRect {
        id: pageJumpPopup
        width: 180
        height: jumpColumn.height + Theme.spacingM * 2
        color: Theme.readableSurface
        radius: Theme.cornerRadius
        border.color: Theme.outlineMedium
        border.width: 1
        visible: false
        z: 101
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 56

        onVisibleChanged: {
            if (visible) {
                pageJumpField.text = (root.gridIndex + 1).toString();
                pageJumpField.forceActiveFocus();
                pageJumpField.selectAll();
            }
        }

        Column {
            id: jumpColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingXS

            StyledText {
                text: I18n.tr("Jump to wallpaper (1 - %1)").arg(root.wallpaperCount)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                font.weight: Font.Medium
            }

            DankTextField {
                id: pageJumpField
                width: parent.width
                placeholderText: "1 - " + root.wallpaperCount
                maximumLength: 6
                topPadding: Theme.spacingS
                bottomPadding: Theme.spacingS
                validator: IntValidator {
                    bottom: 1
                    top: root.wallpaperCount
                }
                onAccepted: root.jumpToPage(text)
            }
        }
    }
}