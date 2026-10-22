import QtQuick 2.12
import QtGraphicalEffects 1.12
import "../"

FocusScope {
    id: root

    readonly property string homeDir: "file:///media/developer/clean-home/"
    readonly property var defaultHidden: [
        "com.webos.app.igallery", "com.webos.app.mediadiscovery", "com.webos.app.sportsteamsettings",
        "com.webos.app.livepick-full", "amazon.alexa.view", "com.webos.app.lgchannels",
        "com.webos.app.homeconnect", "com.webos.app.roomconnect", "com.amazoff.patcher", "com.hbo.hbomax"
    ]
    readonly property int columns: 5
    readonly property string appId: "io.github.kiri11.cleanhome"

    property var main
    property alias shelfList: shelfListCompat
    property alias shelfListContainer: shelfListContainerCompat
    property alias topArea: topAreaCompat
    property alias editMenu: editMenuCompat
    property alias recents: recentsCompat
    property alias settingPopup: settingPopupCompat
    property alias appListArea: appGrid
    property alias editMenuLoaderStatus: editMenuLoader.status
    property bool isHalfMode: uiController.isHalfMode
    property bool showFooterButton: false
    property bool needResetModel: false
    property GlobalStyle styleSheet: GlobalStyle {}
    property int topAreaYPos: 0
    property int topAreaHeight: 0

    property bool wasShown: false
    property bool resetFocusPending: true
    property bool launching: false
    property string launchStatus: ""
    property date currentDate: new Date()
    property var config: ({})
    property bool hideApp: false
    property var apps: []
    property string appsKey: ""
    property var inputs: []
    property string inputsKey: ""
    property int lastAppIndex: 0
    property int moveFrom: -1
    property int lastInputIndex: 0
    readonly property bool homeActive: root.visible && rootWindow.active && uiController.homeShown && !uiController.isHiddenMode
    readonly property real designScale: Math.min(width / 1920, height / 1080)

    signal hideTransitonFinished()
    signal setShelfListModel(var viewState)
    signal resetShelves()
    signal clearShelfModel()
    signal allShelfListUpdate()

    focus: true
    anchors.fill: parent

    Item {
        id: shelfListContainerCompat
        state: "native"
        property bool transitionShelfListRunning: false
        property bool processingWheel: false
    }

    Item {
        id: shelfListCompat
        property int currentIndex: 0
        property int count: 0
        property var model: ({ count: 0 })
    }

    Item {
        id: topAreaCompat
        property int currentIndex: 0
        property int count: 0
        property real contentY: 0
        property var model: ({ count: 0 })
        property bool topShelfLoaded: true
    }

    Item {
        id: recentsCompat
        visible: false
    }

    Item {
        id: editMenuCompat
        property var shelfListEditPage: editMenuCompat
        function createSettingPopup() { root.showOptionMenu(); }
        function closeSettingPopup() { root.closeSettingPopup(); }
        function runVoiceEdit() {}
    }

    Item {
        id: settingPopupCompat
        visible: false
        property bool popupAnimationRunning: false
        property var pageHeaderModel
        property var pageComponentModel
        signal closed()
    }

    Loader {
        id: editMenuLoader
        active: false
        sourceComponent: Component { Item {} }
        visible: false
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1e33" }
            GradientStop { position: 1.0; color: "#0b0c14" }
        }
    }

    RadialGradient {
        anchors.fill: parent
        horizontalOffset: width * 0.28
        verticalOffset: -height * 0.38
        horizontalRadius: width * 0.55
        verticalRadius: height * 0.75
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#4a2f5c" }
            GradientStop { position: 1.0; color: "#004a2f5c" }
        }
        opacity: 0.55
    }

    RadialGradient {
        anchors.fill: parent
        horizontalOffset: -width * 0.32
        verticalOffset: -height * 0.18
        horizontalRadius: width * 0.45
        verticalRadius: height * 0.6
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#26365e" }
            GradientStop { position: 1.0; color: "#0026365e" }
        }
        opacity: 0.6
    }

    Item {
        id: canvas
        width: 1920; height: 1080
        scale: root.designScale
        anchors.centerIn: parent

        Text {
            x: 1208; y: 36; width: 600; height: 64
            text: Qt.formatTime(root.currentDate, "h:mm AP")
            color: "#f2f3f7"
            font.family: "LG Smart UI"; font.weight: Font.Light; font.pixelSize: 54
            horizontalAlignment: Text.AlignRight
        }
        Text {
            x: 1208; y: 100; width: 600; height: 32
            text: Qt.formatDate(root.currentDate, "ddd, MMM d")
            color: "#a9adbf"
            font.family: "LG Smart UI"; font.pixelSize: 26
            horizontalAlignment: Text.AlignRight
        }

        FocusScope {
            id: appGrid
            objectName: "appListArea"
            x: 0; y: 146; width: 1920; height: 2 * cellHeight
            clip: true
            focus: true
            readonly property int cellWidth: 346
            readonly property int cellHeight: 276
            readonly property int count: root.apps.length
            property int currentIndex: 0
            property int firstColumn: 0
            property bool moving: false
            property bool longPressed: false
            property bool okDown: false

            Item {
                x: 100 - appGrid.firstColumn * appGrid.cellWidth
                Repeater {
                    model: root.apps
                    delegate: Item {
                        id: appCell
                        readonly property var cell: root.cellOf(index)
                        readonly property bool focused: appGrid.activeFocus && appGrid.currentIndex === index
                        readonly property bool lifted: focused && appGrid.moving
                        x: cell.column * appGrid.cellWidth; y: cell.row * appGrid.cellHeight
                        width: appGrid.cellWidth; height: appGrid.cellHeight

                        Rectangle {
                            x: 6; y: 6; width: 324; height: 188
                            radius: 22
                            color: "transparent"
                            border.color: appCell.lifted ? "#9cc1ff" : "#ffffff"
                            border.width: 4
                            visible: appCell.focused
                        }
                        Rectangle {
                            id: tile
                            x: 12; y: 12; width: 312; height: 176
                            radius: 16
                            color: modelData.iconColor || "#232737"
                            border.color: "#1affffff"
                            border.width: 1
                            Image {
                                anchors.centerIn: parent
                                width: 120; height: 120
                                sourceSize.width: 130; sourceSize.height: 130
                                source: modelData.largeIcon ? "file://" + modelData.largeIcon : (modelData.icon ? "file://" + modelData.icon : "")
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }
                        }
                        Text {
                            x: 12; y: 202; width: 312; height: 40
                            text: appCell.lifted ? "‹  " + modelData.title + "  ›" : modelData.title
                            color: appCell.lifted ? "#9cc1ff" : (appCell.focused ? "#ffffff" : "#c9ccd8")
                            font.family: "LG Smart UI"; font.pixelSize: 28
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: tile
                            hoverEnabled: true
                            enabled: !appGrid.moving
                            onEntered: if (root.homeActive) root.focusApp(index)
                            onClicked: {
                                root.focusApp(index);
                                root.launchApp(modelData);
                            }
                        }
                    }
                }
            }

            Timer {
                id: longPressTimer
                interval: 700
                onTriggered: {
                    if (!appGrid.okDown || appGrid.moving) return;
                    appGrid.longPressed = true;
                    root.startMove();
                }
            }

            Keys.onPressed: {
                var i = currentIndex;
                var target = -1;
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
                    if (!event.isAutoRepeat && !okDown) {
                        okDown = true;
                        longPressed = false;
                        if (!moving) longPressTimer.restart();
                    }
                } else if (moving && root.isBackKey(event.key)) {
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    target = root.neighbor(i, event.key, moving);
                    if (target === -2 && !moving) root.focusInputs(root.cellOf(i).column - firstColumn);
                    else if (target >= 0 && moving) root.moveTo(target);
                    else if (target >= 0) root.focusApp(target);
                } else {
                    return;
                }
                event.accepted = true;
            }

            Keys.onReleased: {
                if (event.isAutoRepeat) return;
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
                    longPressTimer.stop();
                    var wasDown = okDown;
                    okDown = false;
                    if (!wasDown || longPressed) {
                        longPressed = false;
                    } else if (moving) {
                        root.finishMove();
                    } else if (currentIndex >= 0 && currentIndex < count) {
                        root.launchApp(root.apps[currentIndex]);
                    }
                    event.accepted = true;
                } else if (moving && root.isBackKey(event.key)) {
                    root.finishMove();
                    event.accepted = true;
                }
            }

            onActiveFocusChanged: if (!activeFocus && moving) root.finishMove()
        }

        Text {
            x: 112; y: 712; width: 1696; height: 36
            text: "Arrows move it · OK or Back to finish"
            color: "#9cc1ff"
            font.family: "LG Smart UI"; font.pixelSize: 28
            horizontalAlignment: Text.AlignRight
            visible: appGrid.moving
        }

        Text {
            x: 112; y: 712; width: 800; height: 36
            text: "Inputs & controls"
            color: "#a9adbf"
            font.family: "LG Smart UI"; font.pixelSize: 28
        }

        FocusScope {
            id: inputRow
            x: 106; y: 762; width: 1708; height: 120
            property int currentIndex: 0
            readonly property real itemWidth: root.inputs.length ? Math.min(330, (1696 - (root.inputs.length - 1) * 24) / root.inputs.length) : 0

            Repeater {
                id: inputRepeater
                model: root.inputs
                delegate: Item {
                    id: inputCell
                    x: index * (inputRow.itemWidth + 24); y: 0
                    width: inputRow.itemWidth + 12; height: 108
                    readonly property bool focused: inputRow.activeFocus && inputRow.currentIndex === index

                    Rectangle {
                        x: 0; y: 0; width: parent.width; height: parent.height
                        radius: 20
                        color: "transparent"
                        border.color: "#ffffff"
                        border.width: 4
                        visible: inputCell.focused
                    }
                    Rectangle {
                        id: inputFace
                        x: 6; y: 6; width: inputRow.itemWidth; height: 96
                        radius: 14
                        color: inputCell.focused ? "#3a3f55" : "#262a3c"
                        border.color: "#1affffff"
                        border.width: 1
                        opacity: modelData.plugged ? 1 : 0.55
                        Image {
                            id: inputIcon
                            x: 24; anchors.verticalCenter: parent.verticalCenter
                            width: 44; height: 44
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: inputIcon
                            source: inputIcon
                            color: "#e6e8f0"
                        }
                        Text {
                            x: 84; width: parent.width - 100
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.title
                            color: "#eef0f6"
                            font.family: "LG Smart UI"; font.pixelSize: 27
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        anchors.fill: inputFace
                        hoverEnabled: true
                        onEntered: if (root.homeActive) root.focusInputs(index)
                        onClicked: {
                            root.focusInputs(index);
                            root.launchApp(modelData);
                        }
                    }
                }
            }

            Keys.onPressed: {
                var i = currentIndex;
                if (event.key === Qt.Key_Left) {
                    if (i > 0) currentIndex = i - 1;
                } else if (event.key === Qt.Key_Right) {
                    if (i + 1 < root.inputs.length) currentIndex = i + 1;
                } else if (event.key === Qt.Key_Up) {
                    var column = appGrid.firstColumn + Math.min(i, root.columns - 1);
                    var up = root.indexAt(column, 1);
                    if (up < 0) up = root.indexAt(column, 0);
                    if (up < 0) up = appGrid.count - 1;
                    root.focusApp(up);
                } else if (event.key === Qt.Key_Down) {
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
                    if (!event.isAutoRepeat && i >= 0 && i < root.inputs.length) root.launchApp(root.inputs[i]);
                } else {
                    return;
                }
                event.accepted = true;
            }
            onCurrentIndexChanged: root.lastInputIndex = currentIndex
        }

        Text {
            x: 112; y: 1010; width: 1696; height: 30
            text: root.launchStatus
            color: "#e8c58a"
            font.family: "LG Smart UI"; font.pixelSize: 22
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    Timer {
        interval: Math.max(250, 60000 - root.currentDate.getSeconds() * 1000 - root.currentDate.getMilliseconds())
        repeat: true
        triggeredOnStart: true
        running: root.homeActive
        onTriggered: root.currentDate = new Date()
    }

    Timer {
        id: launchTimeout
        interval: 8000
        onTriggered: root.finishLaunch("the TV did not respond.")
    }

    Connections {
        target: systemProperties
        onLaunchPointsChanged: Qt.callLater(root.refreshApps)
        onUpdatedAppObjectChanged: Qt.callLater(root.refreshApps)
        onExternalDeviceListChanged: Qt.callLater(root.refreshInputs)
    }

    Connections {
        target: uiController
        onIsRecentModeChanged: {
            if (uiController.isRecentMode) {
                uiController.isRecentMode = false;
                root.goToTop();
            }
        }
    }

    Connections {
        target: uiController
        onHomeShownChanged: if (!uiController.homeShown) root.resetFocusPending = true
    }

    onHomeActiveChanged: {
        if (homeActive && resetFocusPending) {
            resetFocusPending = false;
            currentDate = new Date();
            Qt.callLater(function() { root.focusApp(0); });
        }
    }

    state: uiController.state

    onStateChanged: {
        if (state === "hidden") {
            if (!root.wasShown) return;
            uiController.isRecentMode = false;
            uiController.introRan = false;
            uiController.mainTransitionFinished = false;
            Qt.callLater(function() {
                if (root.state !== "hidden") return;
                root.wasShown = false;
                root.hideTransitonFinished();
                uiController.hideWindow();
            });
        } else if (state === "main") {
            root.wasShown = true;
            uiController.isFullHome = true;
            uiController.introRan = true;
            uiController.mainTransitionFinished = true;
            uiController.isRecentMode = false;
            root.currentDate = new Date();
            root.loadConfig();
            root.refreshApps();
            root.refreshInputs();
        } else if (state === "half" || state === "sub") {
            root.wasShown = true;
            uiController.isFullHome = false;
            uiController.introRan = true;
            uiController.mainTransitionFinished = true;
        } else if (state === "editMenu") {
            Qt.callLater(function() { uiController.goToState("main"); });
        }
    }

    Component.onCompleted: {
        loadConfig();
        refreshApps();
        refreshInputs();
    }

    function initialize() {
        currentDate = new Date();
        if (uiController.interfaces && uiController.interfaces.initApp && uiController.interfaces.initApp.closeAnimation)
            uiController.interfaces.initApp.closeAnimation();
        uiController.isFullHome = true;
        uiController.mainTransitionFinished = state === "main";
        uiController.mainRibbonReady = true;
        uiController.introRan = state === "main";
        refreshApps();
        refreshInputs();
        Qt.callLater(function() { root.focusApp(0); });
    }

    function readFile(name, done) {
        var request = new XMLHttpRequest();
        request.onreadystatechange = function() {
            if (request.readyState === XMLHttpRequest.DONE) done(request.responseText || "");
        };
        try {
            request.open("GET", homeDir + name);
            request.send();
        } catch (error) {
            done("");
        }
    }

    function loadConfig() {
        readFile("config.json", function(text) {
            try {
                root.config = text ? JSON.parse(text) : {};
            } catch (error) {
                root.launchStatus = "config.json is not valid JSON.";
            }
            root.refreshApps();
        });
        readFile("hide-app", function(text) {
            root.hideApp = text !== "";
            root.refreshApps();
        });
    }

    function openApp() {
        var points = systemProperties.launchPoints || [];
        for (var i = 0; i < points.length; i++) {
            if (points[i] && points[i].id === appId) {
                launchApp({ id: appId, launchPointId: points[i].launchPointId || "", params: {}, title: points[i].title || "Clean Home" });
                return;
            }
        }
    }

    function refreshApps() {
        var points = systemProperties.launchPoints || [];
        var hidden = config.hide || defaultHidden;
        var order = config.order || [];
        var visible = [];
        var i;
        for (i = 0; i < points.length; i++) {
            var lp = points[i];
            if (!lp || !lp.id || hidden.indexOf(lp.id) >= 0 || lp.visible === false || (hideApp && lp.id === appId)) continue;
            visible.push(lp);
        }
        var pinned = [], rest = [];
        for (i = 0; i < visible.length; i++) {
            if (order.indexOf(visible[i].id) >= 0) pinned.push(visible[i]);
            else rest.push(visible[i]);
        }
        pinned.sort(function(a, b) { return order.indexOf(a.id) - order.indexOf(b.id); });
        var list = pinned.concat(rest).map(function(lp) {
            return { kind: "app", id: lp.id, launchPointId: lp.launchPointId || "", params: lp.params || {},
                     title: lp.title || lp.id, iconColor: lp.iconColor || "", largeIcon: lp.largeIcon || "", icon: lp.icon || "" };
        });
        var key = JSON.stringify(list);
        if (key === appsKey) return;
        appsKey = key;
        apps = list;
        if (appGrid.currentIndex >= list.length) appGrid.currentIndex = Math.max(0, list.length - 1);
    }

    function refreshInputs() {
        var devices = systemProperties.externalDeviceList || [];
        var iconDir = "file:///usr/palm/plugins/inputapps/assets/2k/small/";
        var list = [];
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i];
            if (!d || !d.appId || !d.id || d.id.indexOf("HDMI") !== 0) continue;
            list.push({ kind: "input", id: d.appId, launchPointId: "", params: {},
                        title: d.label || ("HDMI " + d.port), icon: d.icon ? iconDir + d.icon : "",
                        plugged: d.connected !== false && d.hdmiPlugIn !== false });
        }
        list.push({ kind: "settings", id: "com.palm.app.settings", launchPointId: "", params: {},
                    title: "Settings", icon: "file:///usr/palm/applications/com.webos.app.home/qml/UserInterfaceLayer/Components/images/2k/home_setting.png",
                    plugged: true });
        var key = JSON.stringify(list);
        if (key === inputsKey) return;
        inputsKey = key;
        inputs = list;
    }

    function focusApp(index) {
        if (appGrid.count === 0) {
            focusInputs(0);
            return;
        }
        appGrid.currentIndex = Math.max(0, Math.min(appGrid.count - 1, index));
        lastAppIndex = appGrid.currentIndex;
        showColumn(cellOf(appGrid.currentIndex).column);
        appGrid.forceActiveFocus();
    }

    function pageWidth(page) {
        return Math.min(columns, Math.ceil((appGrid.count - page * 2 * columns) / 2));
    }

    function cellOf(index) {
        var page = Math.floor(index / (2 * columns));
        var k = index % (2 * columns);
        var width = pageWidth(page);
        return { column: page * columns + k % width, row: Math.floor(k / width) };
    }

    function indexAt(column, row) {
        if (column < 0 || row < 0 || row > 1) return -1;
        var page = Math.floor(column / columns);
        var width = pageWidth(page);
        if (column % columns >= width) return -1;
        var index = page * 2 * columns + row * width + column % columns;
        return index < appGrid.count ? index : -1;
    }

    function showColumn(column) {
        if (column < appGrid.firstColumn) appGrid.firstColumn = column;
        else if (column > appGrid.firstColumn + columns - 1) appGrid.firstColumn = column - columns + 1;
    }

    function neighbor(index, key, moving) {
        var c = cellOf(index);
        var t = -1;
        if (key === Qt.Key_Left) {
            t = indexAt(c.column - 1, c.row);
            if (t < 0) t = indexAt(c.column - 1, 0);
        } else if (key === Qt.Key_Right) {
            t = indexAt(c.column + 1, c.row);
            if (t < 0) t = indexAt(c.column + 1, 0);
            if (t < 0 && moving && index < appGrid.count - 1) t = appGrid.count - 1;
        } else if (key === Qt.Key_Up) {
            t = indexAt(c.column, c.row - 1);
        } else if (key === Qt.Key_Down) {
            t = c.row === 0 ? indexAt(c.column, 1) : -1;
            if (t < 0 && moving && c.row === 0 && index < appGrid.count - 1) t = appGrid.count - 1;
            if (t < 0 && !moving) t = -2;
        }
        return t === index ? -1 : t;
    }

    function isBackKey(key) {
        return key === Qt.Key_Escape || key === Qt.Key_Back || (uiController.webOS && key === uiController.webOS.Key_webOS_Back);
    }

    function startMove() {
        if (appGrid.count < 2) return;
        moveFrom = appGrid.currentIndex;
        appGrid.moving = true;
    }

    function moveTo(target) {
        var list = apps.slice();
        var item = list.splice(appGrid.currentIndex, 1)[0];
        list.splice(target, 0, item);
        appsKey = JSON.stringify(list);
        apps = list;
        focusApp(target);
    }

    function finishMove() {
        appGrid.moving = false;
        appGrid.longPressed = false;
        var to = appGrid.currentIndex;
        if (moveFrom < 0 || moveFrom === to) {
            moveFrom = -1;
            return;
        }
        moveFrom = -1;
        var points = systemProperties.launchPoints || [];
        var item = apps[to];
        var anchor = apps[to + 1] || apps[to - 1];
        var from = -1, at = -1;
        for (var i = 0; i < points.length; i++) {
            if (points[i].launchPointId === item.launchPointId) from = i;
            if (anchor && points[i].launchPointId === anchor.launchPointId) at = i;
        }
        if (from < 0 || at < 0) return;
        var position = apps[to + 1] ? (from < at ? at - 1 : at) : (from < at ? at : at + 1);
        var launchPoints = uiController.interfaces ? uiController.interfaces.launchPoints : null;
        if (launchPoints && launchPoints.moveLaunchPoint) launchPoints.moveLaunchPoint(item.launchPointId, position);
        else launchStatus = "Could not save the new order.";
    }

    function focusInputs(index) {
        if (root.inputs.length === 0) return;
        inputRow.currentIndex = Math.max(0, Math.min(root.inputs.length - 1, index));
        inputRow.forceActiveFocus();
    }

    function goToTop() {
        focusApp(0);
    }

    function startEdit(startPoint) {
        if (uiController.state === "editMenu") uiController.goToState("main");
    }

    function showOptionMenu() {
        launchApp({ id: "com.palm.app.settings", launchPointId: "", params: {}, title: "Settings" });
    }

    function createSettingPopup() { showOptionMenu(); }

    function closeSettingPopup() { focusApp(lastAppIndex); }

    function launchApp(item) {
        if (launching || !item) return;
        var application = uiController.interfaces ? uiController.interfaces.application : null;
        if (!application || !application.launchApp) {
            launchStatus = "Could not open " + item.title + ": the launch service is unavailable.";
            return;
        }
        launching = true;
        launchStatus = "";
        launchTimeout.restart();
        try {
            application.launchApp(item.id, item.launchPointId || "", item.params || {}, "launcher", function(response) {
                if (response && response.returnValue === true) root.finishLaunch("");
                else root.finishLaunch(response && response.errorText ? response.errorText : "the TV did not confirm the launch.");
            });
        } catch (error) {
            finishLaunch(error && error.message ? error.message : "the launch service is unavailable.");
        }
    }

    function finishLaunch(error) {
        launchTimeout.stop();
        launching = false;
        launchStatus = error ? "Could not open the app: " + error : "";
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_0) {
            if (!event.isAutoRepeat) openApp();
            event.accepted = true;
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            var n = event.key - Qt.Key_1;
            if (!event.isAutoRepeat && n < apps.length) {
                focusApp(n);
                launchApp(apps[n]);
            }
            event.accepted = true;
        }
    }
}
