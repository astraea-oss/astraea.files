//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Widgets

ShellRoot {
    id: root

    // Ember desktop shell for the primary display.
    property bool controlOpen: false // retained only for compatibility during testing
    property bool audioOpen: false
    property bool networkOpen: false
    property bool bluetoothOpen: false
    property bool notificationsOpen: false
    // A pinned notification centre survives outside clicks and other panels,
    // and reserves its width so tiled windows start at its right edge.
    property bool notificationsPinned: false
    onNotificationsPinnedChanged: columnWidthSync.restart()
    // Per-device; never synchronised. Persisted so a shell reload keeps it.
    property alias dnd: notificationState.dnd
    property bool mediaOpen: false
    property bool calendarOpen: false
    property bool powerOpen: false
    property bool launcherOpen: false
    property string launcherQuery: ""
    property int launcherIndex: 0
    property string volume: "--"
    property string ethernetState: "disconnected"
    property string ethernetConnection: "Ethernet"
    property string bluetooth: "Bluetooth"
    property bool bluetoothScanning: false
    property bool audioMuted: false
    property string inputVolume: "--"
    property bool inputMuted: false
    property var bluetoothDevices: []
    property var audioOutputs: []
    property var audioInputs: []
    property string lanInterface: "--"
    property string lanAddress: "--"
    property string gateway: "--"
    property string vpnState: "Disconnected"
    property string vpnRegion: "--"
    property string vpnAddress: "--"
    property string pingLatency: "--"
    readonly property int barWidth: 40
    readonly property int panelGap: 16
    readonly property int notificationPanelWidth: 360
    readonly property int hyprGap: 4 // mirrors general.gaps_out in hyprland.lua
    property var now: new Date()
    property string nowPlaying: "Nothing playing"
    property string notifications: ""
    // Arrival times in ms, keyed by notification id; reloads keep the original time.
    readonly property var notificationTimes: JSON.parse(notificationState.times)
    readonly property var notificationHistory: notificationServer.trackedNotifications.values.filter(n => !n.transient)
    readonly property int notificationPopupDuration: 6250
    readonly property int notificationPopupFade: 1000
    property bool notificationSoundEnabled: true
    readonly property real notificationSoundVolume: 0.25
    readonly property string notificationSoundFile: "/usr/share/sounds/freedesktop/stereo/message.oga"
    onDndChanged: if (dnd) notificationPopups.clear()
    onNotificationsOpenChanged: if (notificationsOpen) notificationPopups.clear(); else notificationsPinned = false
    property string focusedTitle: "Desktop"
    property bool focusTitleVisible: false
    property string lastFocusedWindowAddress: ""
    readonly property int focusTitleDuration: 2500
    property int activeWorkspace: 1
    property var workspaceIds: {
        let ids = [1, 2, 3, 4];
        let existing = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (let i = 0; i < existing.length; i++) {
            let id = existing[i].id;
            if (id > 4 && !ids.includes(id)) ids.push(id);
        }
        if (activeWorkspace > 4 && !ids.includes(activeWorkspace)) ids.push(activeWorkspace);
        return ids.sort((a, b) => a - b);
    }
    readonly property int volumePercent: Number(root.volume.replace("%", "")) || 0
    property var launcherApps: {
        let query = launcherQuery.trim().toLowerCase();
        let apps = DesktopEntries.applications.values;
        if (!query) {
            let recent = launcherHistory.ids || [];
            return [...apps].sort((a, b) => {
                let ai = recent.indexOf(a.id);
                let bi = recent.indexOf(b.id);
                if (ai < 0) ai = 9999;
                if (bi < 0) bi = 9999;
                return ai !== bi ? ai - bi : a.name.localeCompare(b.name);
            });
        }
        return apps.filter(app => (app.name + " " + app.genericName + " " + app.comment + " " + app.keywords.join(" ")).toLowerCase().includes(query))
                   .sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property var launcherTop: launcherApps.slice(0, 5)
    readonly property var launcherRest: launcherApps.slice(5)
    readonly property int launcherTopCount: launcherTop.length

    readonly property color ink: "#0e0207"
    readonly property color surface: "#18040a"
    readonly property color surfaceRaised: "#280711"
    readonly property color rose: "#f3c7d7"
    readonly property color muted: "#8f5365"
    readonly property color statusText: "#c58a9d"
    readonly property color ember: "#d81f53"
    readonly property color hot: "#ff3f9e"
    readonly property color amber: "#ffca45"
    readonly property color outline: "#6d1735"
    readonly property string uiFont: "JetBrains Mono"
    readonly property string iconFont: "Symbols Nerd Font"

    // Short control commands share a managed runner so their completion can
    // refresh status. Persistent GUI applications must be detached: reusing a
    // Process terminates its existing child before executing the next command.
    function run(command) { actionRunner.exec(["sh", "-c", command]); }
    function launch(command) { Quickshell.execDetached(["sh", "-c", command]); }
    function copyToClipboard(value) { if (value && value !== "--") clipboardRunner.exec(["wl-copy", value]); }
    function shortAudioName(name) {
        if (name.includes("Speaker")) return "Laptop speakers";
        if (name.includes("Digital Microphone")) return "Digital microphone";
        if (name.includes("Stereo Microphone")) return "Stereo microphone";
        let hdmi = name.match(/HDMI \/ DisplayPort ([0-9]+)/);
        if (hdmi) return "HDMI / DisplayPort " + hdmi[1];
        return name;
    }
    function daysInMonth(date) { return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate(); }
    function firstWeekday(date) { return (new Date(date.getFullYear(), date.getMonth(), 1).getDay() + 6) % 7; }
    function volumeIcon() { return audioMuted || volumePercent === 0 ? "󰖁" : volumePercent < 34 ? "󰕿" : volumePercent < 67 ? "󰖀" : "󰕾" }
    function ethernetIcon() { return ethernetState === "connected" ? "󰈀" : "󰈂" }
    function notificationTimestamp(timestamp) {
        if (!timestamp) return "";
        let received = new Date(timestamp);
        let today = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate());
        let receivedDay = new Date(received.getFullYear(), received.getMonth(), received.getDate());
        let dayOffset = Math.round((today.getTime() - receivedDay.getTime()) / 86400000);
        let time = Qt.formatDateTime(received, "HH:mm");
        if (dayOffset === 0) return "Today " + time;
        if (dayOffset === 1) return "Yesterday " + time;
        return Qt.formatDateTime(received, received.getFullYear() === root.now.getFullYear() ? "d MMM HH:mm" : "d MMM yyyy HH:mm");
    }
    function removeNotificationPopup(notificationId) {
        for (let i = notificationPopups.count - 1; i >= 0; i--) {
            if (notificationPopups.get(i).notificationId === notificationId)
                notificationPopups.remove(i);
        }
    }
    // Keep a notification in the centre. Pass an arrival time only for a fresh
    // arrival (or a canonical shared time); a reloaded entry passes none so it
    // keeps its recorded time instead of taking the reload time.
    function retainNotification(notification, timestamp) {
        if (timestamp !== undefined) {
            let times = Object.assign({}, root.notificationTimes);
            times[notification.id] = timestamp;
            notificationState.times = JSON.stringify(times);
        }
        notification.tracked = true;
    }
    // Expire, rather than dismiss, transients that no longer have a popup.
    function releaseTransients() {
        let shown = new Set();
        for (let i = 0; i < notificationPopups.count; i++) shown.add(notificationPopups.get(i).notificationId);
        for (const notification of [...notificationServer.trackedNotifications.values])
            if (notification.transient && !shown.has(notification.id)) notification.expire();
    }
    function showNotificationPopup(notification) {
        removeNotificationPopup(notification.id);
        if (root.notificationsOpen || root.dnd) return;
        // Copy display text so expiring a popup never dismisses its history entry.
        while (notificationPopups.count >= 4) notificationPopups.remove(0);
        notificationPopups.append({
            notificationId: notification.id,
            appLabel: notification.appName || "Notification",
            headline: notification.summary || "",
            message: (notification.body || "").replace(/<br\s*\/?\s*>/gi, "\n")
                .replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
                .replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, "&")
        });
    }
    function closePanels() { controlOpen = false; audioOpen = false; networkOpen = false; bluetoothOpen = false; notificationsOpen = notificationsPinned; mediaOpen = false; calendarOpen = false; powerOpen = false }
    function toggle(panelName) {
        let next = !root[panelName];
        closePanels();
        root[panelName] = next;
    }
    function launchApp(app) {
        let recent = launcherHistory.ids || [];
        launcherHistory.ids = [app.id].concat(recent.filter(id => id !== app.id)).slice(0, 18);
        // T3 Code must use its wrapper for its Wayland/Ozone flags. Use the
        // same shell + UWSM path that works from the terminal; desktop-entry
        // IDs vary between its normal and URL-handler entries.
        let appIdentity = (app.id + " " + app.name).toLowerCase();
        if (appIdentity.includes("t3code") || appIdentity.includes("t3 code"))
            root.launch("env -u ELECTRON_RUN_AS_NODE uwsm app -- /usr/bin/t3code");
        else
            app.execute();
        root.launcherOpen = false;
        root.launcherQuery = "";
    }

    Settings {
        id: launcherHistory
        location: "file:///home/tera/.config/quickshell/launcher-history.ini"
        category: "ember-launcher"
        property var ids: []
    }

    Process {
        id: actionRunner
        onRunningChanged: if (!running) statusRefresh.restart()
    }
    Process { id: clipboardRunner }
    Process {
        id: notificationChime
        command: ["pw-play", "--media-role", "Notification", "--volume",
            String(root.notificationSoundVolume), root.notificationSoundFile]
    }

    Process {
        id: statusPoll
        command: ["sh", "-c", "printf '%s\\n%s\\n%s\\n%s' \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%d%%\", $2 * 100}')\" \"$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}')\" \"$(playerctl metadata --format '{{artist}} — {{title}}' 2>/dev/null | head -1)\" \"$(hyprctl activewindow -j 2>/dev/null | sed -n 's/.*\\\"title\\\": \\\"\\([^\\\"]*\\\)\\\".*/\\1/p')\"" ]
        stdout: StdioCollector { id: statusOutput; onStreamFinished: {
            let lines = text.trim().split("\n");
            root.volume = lines[0] || "--";
            root.bluetooth = lines[1] === "yes" ? "Bluetooth on" : "Bluetooth off";
            root.nowPlaying = lines[2] || "Nothing playing";
            root.focusedTitle = lines[3] || "Desktop";
        }}
        running: true
    }
    Process {
        id: quickStatePoll
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q '\\[MUTED\\]' && echo yes || echo no" ]
        stdout: StdioCollector { onStreamFinished: {
            root.audioMuted = text.trim() === "yes";
        }}
        running: true
    }
    Process {
        id: inputStatePoll
        command: ["sh", "-c", "printf '%s\\n%s' \"$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{printf \"%d%%\", $2 * 100}')\" \"$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q '\\[MUTED\\]' && echo yes || echo no)\"" ]
        stdout: StdioCollector { onStreamFinished: {
            let lines = text.trim().split("\n");
            root.inputVolume = lines[0] || "--";
            root.inputMuted = lines[1] === "yes";
        }}
        running: true
    }
    Process {
        id: bluetoothDevicePoll
        command: ["sh", "-c", "bluetoothctl devices 2>/dev/null | while read -r kind address name; do info=$(bluetoothctl info \"$address\" 2>/dev/null); connected=$(printf '%s\\n' \"$info\" | awk -F': ' '/Connected:/ {print $2; exit}'); paired=$(printf '%s\\n' \"$info\" | awk -F': ' '/Paired:/ {print $2; exit}'); printf '%s|%s|%s|%s\\n' \"$name\" \"$address\" \"$connected\" \"$paired\"; done" ]
        stdout: StdioCollector { onStreamFinished: {
            let lines = text.trim() ? text.trim().split("\n") : [];
            let devices = [];
            for (let i = 0; i < lines.length; i++) {
                let fields = lines[i].split("|");
                if (fields.length >= 4) devices.push({ name: fields[0], address: fields[1], connected: fields[2] === "yes", paired: fields[3] === "yes" });
            }
            root.bluetoothDevices = devices;
        }}
        running: true
    }
    Process {
        id: bluetoothScanRunner
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        onRunningChanged: {
            root.bluetoothScanning = running;
            if (!running && !bluetoothDevicePoll.running) bluetoothDevicePoll.running = true;
        }
    }
    Process {
        id: audioDevicePoll
        command: ["sh", "-c", "wpctl status 2>/dev/null | awk '/├─ Sinks:/ {section=\"output\"; next} /├─ Sources:/ {section=\"input\"; next} /├─ Filters:/ {section=\"\"} section && match($0, /([* ]?) *([0-9]+)\\. (.*) \\[vol:/, a) { name=a[3]; sub(/ \\[vol:.*/, \"\", name); printf \"%s|%s|%s|%s\\n\", section, a[2], ($0 ~ /\\*/ ? \"yes\" : \"no\"), name }'" ]
        stdout: StdioCollector { onStreamFinished: {
            let outputs = [], inputs = [];
            let lines = text.trim() ? text.trim().split("\n") : [];
            for (let i = 0; i < lines.length; i++) {
                let fields = lines[i].split("|");
                if (fields.length >= 4) {
                    let entry = { id: fields[1], active: fields[2] === "yes", name: fields.slice(3).join("|") };
                    if (fields[0] === "output") outputs.push(entry); else if (fields[0] === "input") inputs.push(entry);
                }
            }
            root.audioOutputs = outputs;
            root.audioInputs = inputs;
        }}
        running: true
    }
    Process {
        id: networkDetailsPoll
        command: ["sh", "-c", "lan=$(ip route show default 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if($i==\"dev\") {print $(i+1); exit}}'); lanname=$(nmcli -g GENERAL.CONNECTION device show \"$lan\" 2>/dev/null | head -1); lanstate=$(nmcli -t -f DEVICE,STATE device status 2>/dev/null | awk -F: -v dev=\"$lan\" '$1==dev {print $2; exit}'); lanip=$(ip -4 -o addr show dev \"$lan\" scope global 2>/dev/null | awk '{print $4; exit}'); gw=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}'); vpnstate=$(piactl get connectionstate 2>/dev/null || echo Disconnected); vpnregion=$(piactl get region 2>/dev/null || echo --); vpnip=$(ip -4 -o addr show dev tun0 scope global 2>/dev/null | awk '{print $4; exit}'); latency=$(ping -n -c 1 -W 1 1.1.1.1 2>/dev/null | awk '/time=/ {match($0, /time=[0-9.]+/); value=substr($0, RSTART, RLENGTH); sub(\"time=\", \"\", value); print value \" ms\"; exit}'); printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n' \"$lan\" \"$lanname\" \"$lanstate\" \"$lanip\" \"$gw\" \"$vpnstate\" \"$vpnregion\" \"$vpnip\" \"$latency\"" ]
        stdout: StdioCollector { onStreamFinished: {
            let lines = text.trim().split("\n");
            root.lanInterface = lines[0] || "--";
            root.ethernetConnection = lines[1] || "Ethernet";
            root.ethernetState = lines[2] || "disconnected";
            root.lanAddress = lines[3] || "--";
            root.gateway = lines[4] || "--";
            root.vpnState = lines[5] || "Disconnected";
            root.vpnRegion = lines[6] || "--";
            root.vpnAddress = lines[7] || "--";
            root.pingLatency = lines[8] || "--";
        }}
        running: true
    }
    Process {
        id: workspacePoll
        command: ["sh", "-c", "hyprctl activeworkspace -j 2>/dev/null | sed -n 's/.*\\\"id\\\": *\\([0-9]*\\).*/\\1/p'" ]
        stdout: StdioCollector { onStreamFinished: { let n = Number(text.trim()); if (n > 0) root.activeWorkspace = n } }
        running: true
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: root.now = new Date()
    }
    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: {
            if (!statusPoll.running) statusPoll.running = true;
            if (!quickStatePoll.running) quickStatePoll.running = true;
            if (!inputStatePoll.running) inputStatePoll.running = true;
            if (!bluetoothDevicePoll.running) bluetoothDevicePoll.running = true;
            if (!audioDevicePoll.running) audioDevicePoll.running = true;
        }
    }
    Timer {
        id: statusRefresh
        interval: 750; repeat: false
        onTriggered: {
            if (!statusPoll.running) statusPoll.running = true;
            if (!quickStatePoll.running) quickStatePoll.running = true;
            if (!inputStatePoll.running) inputStatePoll.running = true;
            if (!bluetoothDevicePoll.running) bluetoothDevicePoll.running = true;
            if (!audioDevicePoll.running) audioDevicePoll.running = true;
            if (!networkDetailsPoll.running) networkDetailsPoll.running = true;
        }
    }
    Timer {
        interval: 12000; running: true; repeat: true
        onTriggered: if (!networkDetailsPoll.running) networkDetailsPoll.running = true
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { if (Hyprland.focusedWorkspace) root.activeWorkspace = Hyprland.focusedWorkspace.id }
        function onActiveToplevelChanged() {
            root.focusedTitle = Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "Desktop";
            let address = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : "desktop";
            if (address === root.lastFocusedWindowAddress) return;
            root.lastFocusedWindowAddress = address;
            root.focusTitleVisible = true;
            focusTitleTimer.restart();
        }
    }
    // Pinning changes the selected display's reserved width; let Hyprland rescale its column
    // width presets so they keep their pixel sizes. Also runs once at startup in case
    // the shell restarted while pinned. The delay lets the new exclusive zone
    // reach the compositor first.
    Timer {
        id: columnWidthSync
        interval: 250; running: true
        onTriggered: Quickshell.execDetached(["hyprctl", "eval", "require(\"/home/tera/.config/hypr/column_widths.lua\").sync()"])
    }
    Timer {
        id: focusTitleTimer
        interval: root.focusTitleDuration
        onTriggered: root.focusTitleVisible = false
    }
    IpcHandler {
        target: "ember"
        function toggleLauncher(): void {
            root.launcherOpen = !root.launcherOpen;
            root.launcherQuery = "";
            root.launcherIndex = 0;
        }
        function toggleNetwork(): void { root.toggle("networkOpen"); }
        function closePanels(): void { root.closePanels(); }
    }
    ListModel { id: notificationPopups; onCountChanged: Qt.callLater(root.releaseTransients) }

    // Survives shell reloads (not a full Quickshell restart).
    PersistentProperties {
        id: notificationState
        reloadableId: "emberNotificationState"
        property bool dnd: false
        // JSON text: JS objects in a var do not carry across a reload.
        property string times: "{}"
    }

    NotificationServer {
        id: notificationServer
        persistenceSupported: true
        actionsSupported: true
        bodyMarkupSupported: true
        // dismiss() is reserved for explicit user closure (Clear and the
        // per-entry button); presentation choices such as DND must never call it.
        onNotification: notification => {
            // Deferred for every path, including reload: transients restored
            // without a popup must still expire once restoration finishes.
            Qt.callLater(root.releaseTransients);
            // Reloaded history keeps its arrival time and must not replay popups or chimes.
            if (notification.lastGeneration) {
                root.retainNotification(notification);
                return;
            }
            // Transients stay out of history but are tracked while their popup
            // shows: Quickshell reports an untracked notification as dismissed.
            if (notification.transient) notification.tracked = true;
            else root.retainNotification(notification, Date.now());
            // DND only suppresses presentation, including critical urgency for now.
            if (root.dnd) return;
            root.showNotificationPopup(notification);
            if (root.notificationSoundEnabled && !notification.hints["suppress-sound"] && !notificationChime.running)
                notificationChime.running = true;
        }
    }

    component EmberButton: Rectangle {
        id: button
        property string glyph: ""
        property string label: ""
        property color glyphColor: root.rose
        property color labelColor: root.rose
        property int iconSize: 16
        property bool chrome: true
        property bool compact: false
        property bool active: false
        readonly property bool hovered: mouse.containsMouse
        signal pressed()
        width: button.label.length > 0 ? content.implicitWidth + (button.compact ? 6 : 14) : (button.compact ? 18 : 24); height: 24; radius: 0
        color: button.chrome && (mouse.containsMouse || button.active) ? root.surfaceRaised : "transparent"
        border.color: button.chrome && (mouse.containsMouse || button.active) ? root.outline : "transparent"
        RowLayout { id: content; anchors.centerIn: parent; spacing: button.compact ? 2 : 6
            Text { visible: button.glyph.length > 0; text: button.glyph; color: button.glyphColor; font.family: root.iconFont; font.pixelSize: button.iconSize }
            Text { visible: button.label.length > 0; text: button.label; color: button.labelColor; font.family: root.uiFont; font.pixelSize: 12 }
        }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: button.pressed() }
    }

    component EmberToggle: Rectangle {
        id: toggle
        property string label: ""
        property string detail: ""
        property bool checked: false
        signal toggled(bool value)
        width: parent ? parent.width : implicitWidth; height: 34
        Layout.fillWidth: true; Layout.preferredHeight: 34; Layout.maximumHeight: 34; implicitHeight: 34; radius: 4
        color: toggle.checked ? "#2b0c18" : root.surfaceRaised
        border.color: toggle.checked ? root.outline : "#401020"
        RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 9; spacing: 8
            ColumnLayout { Layout.fillWidth: true; spacing: 1
                Text { text: toggle.label; color: root.rose; font.family: root.uiFont; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { visible: toggle.detail.length > 0; text: toggle.detail; color: root.muted; font.family: root.uiFont; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Rectangle { width: 30; height: 16; radius: 8; color: toggle.checked ? root.hot : "#4a2531"
                Rectangle { width: 12; height: 12; radius: 6; anchors.verticalCenter: parent.verticalCenter; x: toggle.checked ? 16 : 2; color: root.rose
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
            }
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: toggle.toggled(!toggle.checked) }
    }

    component EmberChoice: Rectangle {
        id: choice
        property string label: ""
        property string detail: ""
        property bool selected: false
        signal chosen()
        width: parent ? parent.width : implicitWidth; height: 32
        Layout.fillWidth: true; Layout.preferredHeight: 32; Layout.maximumHeight: 32; implicitHeight: 32; radius: 4
        color: choice.selected ? "#2b0c18" : root.surfaceRaised
        border.color: choice.selected ? root.hot : "#401020"
        RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
            ColumnLayout { Layout.fillWidth: true; spacing: 1
                Text { text: choice.label; color: root.rose; font.family: root.uiFont; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: choice.detail; color: root.muted; font.family: root.uiFont; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Text { text: choice.selected ? "󰄬" : "󰄱"; color: choice.selected ? root.hot : root.muted; font.family: root.iconFont; font.pixelSize: 15 }
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: choice.chosen() }
    }

    component LauncherEntry: Rectangle {
        id: entry
        property var app
        property int entryIndex: 0
        width: launcherCard.width - 20; height: 40; radius: 2
        color: root.launcherIndex === entry.entryIndex ? root.surfaceRaised : (entryMouse.containsMouse ? "#210c0610" : "transparent")
        RowLayout { anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7; spacing: 8
            IconImage { source: Quickshell.iconPath(entry.app.icon); width: 22; height: 22 }
            ColumnLayout { Layout.fillWidth: true; spacing: 1
                Text { text: entry.app.name; color: root.rose; font.family: root.uiFont; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: entry.app.genericName || entry.app.comment; color: root.muted; font.family: root.uiFont; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
        MouseArea { id: entryMouse; anchors.fill: parent; hoverEnabled: true; onEntered: root.launcherIndex = entry.entryIndex; onClicked: root.launchApp(entry.app) }
    }

    PanelWindow {
        id: bar
        // EDIT ME: Select another entry here to pin the shell to a chosen display.
        screen: Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true }
        exclusiveZone: root.barWidth
        implicitWidth: root.barWidth
        color: root.ink
        Rectangle {
            anchors.fill: parent; radius: 0; color: root.ink
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: root.outline }
            Column {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
                spacing: 1
                Repeater { model: root.workspaceIds
                    delegate: Rectangle {
                        required property int modelData
                        width: root.barWidth; height: 34; radius: 0
                        color: root.activeWorkspace === modelData ? "#7a0c23" : (workspaceMouse.containsMouse ? root.surfaceRaised : "transparent")
                        Text { anchors.centerIn: parent; text: modelData; color: root.rose; font.family: root.uiFont; font.pixelSize: 11 }
                        Rectangle { visible: root.activeWorkspace === modelData; anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: 2; color: root.hot }
                        MouseArea { id: workspaceMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.run("hyprctl dispatch 'hl.dsp.focus({ workspace = " + modelData + " })'") }
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent; width: root.barWidth; height: 48; color: clockMouse.containsMouse ? root.surfaceRaised : "transparent"
                Column {
                    anchors.centerIn: parent; spacing: -1
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(root.now, "HH"); color: root.amber; font.family: root.uiFont; font.bold: true; font.pixelSize: 12 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(root.now, "mm"); color: root.rose; font.family: root.uiFont; font.pixelSize: 11 }
                }
                MouseArea { id: clockMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggle("calendarOpen") }
            }
            Column {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
                spacing: 1
                Repeater { model: SystemTray.items
                    delegate: MouseArea {
                        id: trayButton
                        required property var modelData
                        width: root.barWidth; height: 28; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        function openNativeMenu() {
                            if (!modelData.hasMenu) return;
                            let point = trayButton.mapToItem(null, trayButton.width, 0);
                            modelData.display(bar, point.x, point.y);
                        }
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) {
                                if (modelData.onlyMenu) trayButton.openNativeMenu();
                                else modelData.activate();
                            } else if (mouse.button === Qt.RightButton) {
                                trayButton.openNativeMenu();
                            }
                        }
                        IconImage { anchors.centerIn: parent; width: 16; height: 16; source: modelData.icon }
                    }
                }
                Item { visible: SystemTray.items.values.length > 0; width: root.barWidth; height: 7
                    Rectangle { width: 20; height: 1; color: root.outline; anchors.centerIn: parent }
                }
                EmberButton { width: root.barWidth; height: 32; glyph: root.ethernetIcon(); glyphColor: root.ethernetState === "connected" ? root.rose : root.muted; iconSize: 15; chrome: false; compact: true; onPressed: root.toggle("networkOpen") }
                EmberButton { width: root.barWidth; height: 32; glyph: "󰂯"; glyphColor: root.bluetooth === "Bluetooth on" ? root.rose : root.muted; iconSize: 14; chrome: false; compact: true; onPressed: root.toggle("bluetoothOpen") }
                EmberButton { width: root.barWidth; height: 32; glyph: root.volumeIcon(); glyphColor: root.rose; iconSize: 14; chrome: false; compact: true; onPressed: root.toggle("audioOpen") }
                EmberButton { width: root.barWidth; height: 32; glyph: root.dnd ? "󰂛" : "󰂚"; label: root.notificationHistory.length > 0 ? root.notificationHistory.length : ""; glyphColor: root.muted; iconSize: 14; chrome: false; compact: true; onPressed: root.toggle("notificationsOpen") }
                EmberButton { width: root.barWidth; height: 32; glyph: "󰐥"; glyphColor: root.hot; iconSize: 14; chrome: false; compact: true; onPressed: root.toggle("powerOpen") }
            }
        }
    }

    PanelWindow {
        id: focusTitleOverlay
        // Keep the click-through surface mapped. Mapping/unmapping a layer
        // makes Hyprland refocus the window under the cursor, even on another
        // monitor; fade only the text so fullscreen apps retain focus.
        visible: true
        screen: bar.screen
        anchors { top: true; left: true }
        margins { left: root.barWidth + 4; top: 4 }
        implicitWidth: Math.min(900, screen ? screen.width - root.barWidth - 14 : 900)
        implicitHeight: 44
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ember-focused-window"

        Column {
            id: focusTitleText
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            opacity: root.focusTitleVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.focusTitleVisible ? 150 : 300 } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.ink
                shadowOpacity: 1
                shadowBlur: 0.35
                shadowVerticalOffset: 1
                blurMax: 6
            }
            Text {
                width: parent.width
                text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title || "Untitled window" : "Desktop"
                textFormat: Text.PlainText
                style: Text.Outline
                styleColor: root.ink
                color: root.rose
                font.family: root.uiFont
                font.pixelSize: 18
                font.bold: true
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }
    }

    PanelWindow {
        id: notificationOverlay
        visible: true
        screen: bar.screen
        anchors { bottom: true; left: true }
        margins { left: root.barWidth + root.panelGap; bottom: 20 }
        implicitWidth: Math.min(620, screen ? screen.width - root.barWidth - root.panelGap - 20 : 620)
        // Resizing a mapped layer also triggers compositor refocusing. Keep
        // its transparent bounds fixed while the notification stack changes.
        implicitHeight: Math.min(800, screen ? screen.height - 40 : 800)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        // An empty input region makes even the text itself click-through.
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ember-notification-popups"

        Column {
            id: popupStack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
            spacing: 24
            Repeater {
                model: notificationPopups
                delegate: Item {
                    id: popup
                    required property int notificationId
                    required property string appLabel
                    required property string headline
                    required property string message
                    width: popupStack.width
                    implicitHeight: popupText.implicitHeight
                    opacity: 0

                    Column {
                        id: popupText
                        width: parent.width
                        spacing: 6
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: root.ink
                            shadowOpacity: 1
                            shadowBlur: 0.35
                            shadowVerticalOffset: 1
                            blurMax: 6
                        }
                        Text {
                            width: parent.width
                            text: popup.appLabel.toUpperCase()
                            textFormat: Text.PlainText
                            style: Text.Outline
                            styleColor: root.ink
                            color: root.hot
                            font.family: root.uiFont
                            font.pixelSize: 14
                            font.bold: true
                            font.letterSpacing: 1
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: popup.headline
                            textFormat: Text.PlainText
                            style: Text.Outline
                            styleColor: root.ink
                            color: root.rose
                            font.family: root.uiFont
                            font.pixelSize: 21
                            font.bold: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: popup.message
                            textFormat: Text.PlainText
                            style: Text.Outline
                            styleColor: root.ink
                            color: root.statusText
                            font.family: root.uiFont
                            font.pixelSize: 20
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                    SequentialAnimation {
                        running: true
                        NumberAnimation { target: popup; property: "opacity"; from: 0; to: 1; duration: 180 }
                        PauseAnimation { duration: root.notificationPopupDuration }
                        NumberAnimation { target: popup; property: "opacity"; to: 0; duration: root.notificationPopupFade }
                        ScriptAction { script: root.removeNotificationPopup(popup.notificationId) }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: launcher
        visible: root.launcherOpen
        screen: bar.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        focusable: true
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: { root.launcherOpen = false; root.launcherQuery = "" } }
        Rectangle {
            id: launcherCard
            // The card keeps the size/placement of the compact (search + top
            // entries) card, centered on screen; overflow results extend
            // downward from it and scroll, stopping short of the screen edge.
            // Card height and list height derive from one shared listHeight so
            // the layout never has leftover space to smear into gaps.
            readonly property int baseHeight: 58 + launcherTopCount * 40
            readonly property int topY: Math.max(0, (launcher.screen.height - baseHeight) / 2)
            readonly property int listHeight: launcherRest.length === 0 ? 0
                : Math.min(launcherRest.length * 40, Math.max(0, launcher.screen.height - 48 - topY - baseHeight - 23))
            width: 460
            height: baseHeight + (listHeight > 0 ? 23 + listHeight : 0)
            anchors.horizontalCenter: parent.horizontalCenter
            y: topY
            radius: 5
            color: "#f00e0207"
            border.color: root.outline
            border.width: 1
            ColumnLayout { anchors.fill: parent; anchors.margins: 10; spacing: 4
                TextInput {
                    id: launcherInput
                    Layout.fillWidth: true; Layout.preferredHeight: 32
                    focus: root.launcherOpen
                    color: root.rose; font.family: root.uiFont; font.pixelSize: 16
                    clip: true
                    text: root.launcherQuery
                    onTextChanged: { root.launcherQuery = text; root.launcherIndex = 0 }
                    Keys.onEscapePressed: { root.launcherOpen = false; root.launcherQuery = "" }
                    Keys.onDownPressed: root.launcherIndex = Math.min(root.launcherApps.length - 1, root.launcherIndex + 1)
                    Keys.onUpPressed: root.launcherIndex = Math.max(0, root.launcherIndex - 1)
                    Keys.onReturnPressed: { if (root.launcherApps.length > 0) root.launchApp(root.launcherApps[root.launcherIndex]) }
                    Text { visible: !launcherInput.text; anchors.verticalCenter: parent.verticalCenter; text: "Search applications…"; color: root.muted; font.family: root.uiFont; font.pixelSize: 16 }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.hot }
                }
                Repeater { model: root.launcherTop
                    delegate: LauncherEntry { app: modelData; entryIndex: index }
                }
                Item { visible: launcherRest.length > 0; Layout.fillWidth: true; Layout.preferredHeight: 17; Layout.maximumHeight: 17
                    Rectangle { width: 24; height: 1; color: root.outline; anchors.centerIn: parent }
                }
                ListView {
                    id: launcherList
                    Layout.fillWidth: true
                    Layout.preferredHeight: launcherCard.listHeight
                    Layout.maximumHeight: launcherCard.listHeight
                    Layout.alignment: Qt.AlignTop
                    model: root.launcherRest
                    currentIndex: Math.max(0, root.launcherIndex - root.launcherTopCount)
                    clip: true; spacing: 0
                    interactive: false
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    snapMode: ListView.SnapToItem
                    delegate: LauncherEntry { app: modelData; entryIndex: index + root.launcherTopCount }
                }
            }
        }
    }

    PanelWindow {
        visible: root.controlOpen; screen: bar.screen; anchors { top: true; left: true }
        margins { left: root.panelGap } exclusiveZone: 0; focusable: false; implicitWidth: 360; implicitHeight: 400; color: "transparent"
        Rectangle { anchors.fill: parent; radius: 8; color: "#f018040a"; border.color: root.outline; border.width: 1
            ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 14
                Text { text: "CONTROL CENTRE"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 13 }
                Text { text: Qt.formatDateTime(root.now, "dddd, d MMMM"); color: root.rose; font.family: root.uiFont; font.pixelSize: 20 }
                Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }
                Text { text: "󰕾  " + root.volume; color: root.rose; font.family: root.iconFont; font.pixelSize: 17 }
                RowLayout { Layout.fillWidth: true; EmberButton { glyph: "−"; onPressed: root.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") } EmberButton { glyph: "󰕾"; label: "Audio settings"; Layout.fillWidth: true; onPressed: root.launch("pavucontrol") } EmberButton { glyph: "+"; onPressed: root.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") } }
                Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }
                Text { text: root.ethernetIcon() + "  " + root.ethernetConnection; color: root.rose; font.family: root.iconFont; font.pixelSize: 17 }
                EmberButton { glyph: "󰈀"; label: "Wired network settings"; Layout.fillWidth: true; onPressed: root.launch("nm-connection-editor") }
                EmberButton { glyph: "󰂯"; label: root.bluetooth; Layout.fillWidth: true; onPressed: root.launch("blueman-manager") }
                Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }
                Item { Layout.fillHeight: true }
                EmberButton { glyph: root.dnd ? "󰂛" : "󰂚"; label: root.dnd ? "Do not disturb: on" : "Do not disturb: off"; active: root.dnd; Layout.fillWidth: true; onPressed: root.dnd = !root.dnd }
            }
        }
    }

    // Disabled for the compact status panels: a full-screen layer shell surface
    // can sit above their controls under Hyprland and swallow pointer input.
    PanelWindow {
        visible: false
        screen: bar.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        focusable: false
        color: "transparent"
        MouseArea { anchors { fill: parent; leftMargin: root.barWidth } onClicked: root.closePanels() }
    }

    PanelWindow {
        // Unpinned, the surface covers the screen so an outside click closes it.
        // Pinned, it shrinks to the panel and claims an exclusive zone, which
        // moves the scrolling layout's left edge to the panel's right edge.
        visible: root.notificationsOpen; screen: bar.screen; anchors { top: true; bottom: true; left: true; right: !root.notificationsPinned }
        implicitWidth: root.hyprGap + root.notificationPanelWidth
        exclusiveZone: root.notificationsPinned ? implicitWidth : 0; focusable: false; color: "transparent"
        MouseArea { anchors.fill: parent; enabled: !root.notificationsPinned; onClicked: root.notificationsOpen = false }
        Rectangle { anchors { top: parent.top; bottom: parent.bottom; left: parent.left; leftMargin: root.hyprGap } width: root.notificationPanelWidth; z: 1; radius: 4; color: "#f00e0207"; border.width: 0
            ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 10
                RowLayout { Layout.fillWidth: true
                    Text { text: "NOTIFICATIONS"; color: root.hot; font.bold: true; font.family: root.uiFont; font.pixelSize: 13; Layout.fillWidth: true }
                    EmberButton { glyph: root.notificationsPinned ? "󰐃" : "󰐄"; glyphColor: root.notificationsPinned ? root.hot : root.rose; active: root.notificationsPinned; onPressed: root.notificationsPinned = !root.notificationsPinned }
                    EmberButton { glyph: "󰎟"; label: "Clear"; onPressed: { let all = root.notificationHistory; for (let i = 0; i < all.length; i++) all[i].dismiss() } }
                }
                RowLayout { Layout.fillWidth: true
                    Text { text: "Do Not Disturb"; color: root.rose; font.family: root.uiFont; font.pixelSize: 12; Layout.fillWidth: true }
                    Switch { checked: root.dnd; onToggled: root.dnd = checked }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }
                ListView {
                    id: notificationList
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 7
                    // Newest first; the server tracks notifications in arrival order.
                    model: [...root.notificationHistory].reverse()
                    delegate: Rectangle {
                        required property var modelData
                        width: notificationList.width; implicitHeight: notificationBody.implicitHeight + 20; radius: 4
                        color: root.surfaceRaised; border.color: "#5e0e22"
                        RowLayout { id: notificationBody; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 } spacing: 9
                            IconImage { source: Quickshell.iconPath(modelData.appIcon || modelData.desktopEntry); width: 28; height: 28 }
                            ColumnLayout { Layout.fillWidth: true; spacing: 3
                                RowLayout { Layout.fillWidth: true; spacing: 8
                                    Text { text: modelData.appName; color: root.muted; font.family: root.uiFont; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { text: root.notificationTimestamp(root.notificationTimes[modelData.id]); color: root.statusText; font.family: root.uiFont; font.pixelSize: 9; Layout.alignment: Qt.AlignTop }
                                }
                                Text { text: modelData.summary; color: root.rose; font.family: root.uiFont; font.bold: true; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.Wrap }
                                Text { visible: modelData.body.length > 0; text: modelData.body; color: root.muted; font.family: root.uiFont; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText }
                            }
                            EmberButton { glyph: "󰅖"; compact: true; onPressed: modelData.dismiss() }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: notificationList.count === 0; text: "Nothing to see here"; color: root.muted; font.family: root.uiFont; font.pixelSize: 13 }
                }
            }
        }
    }

    PanelWindow {
        visible: root.audioOpen; screen: bar.screen; anchors { top: true; bottom: true; left: true }
        margins { left: root.panelGap } exclusiveZone: 0; focusable: false; implicitWidth: 360; color: "transparent"
        Rectangle { anchors.fill: parent; radius: 0; color: "#f00e0207"; border.color: "transparent"
            Flickable { anchors.fill: parent; anchors.margins: 14; clip: true; contentWidth: width; contentHeight: audioContent.height
                Column {
                    id: audioContent
                    width: parent.width
                    spacing: 7
                    Text { width: parent.width; height: 16; text: "AUDIO"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 12 }
                    Text { width: parent.width; height: 20; text: root.audioMuted ? "Muted" : "Volume  " + root.volume; color: root.rose; font.family: root.uiFont; font.pixelSize: 15 }
                    Slider { width: parent.width; height: 18; from: 0; to: 100; value: root.volumePercent; onMoved: root.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(value) + "%") }
                    EmberToggle { label: "Mute output"; detail: root.audioMuted ? "Audio is muted" : "Audio is live"; checked: root.audioMuted; onToggled: function(value) { root.audioMuted = value; root.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") } }
                    Rectangle { width: parent.width; height: 1; color: root.outline }
                    Text { width: parent.width; height: 20; text: root.inputMuted ? "Microphone muted" : "Microphone  " + root.inputVolume; color: root.rose; font.family: root.uiFont; font.pixelSize: 15 }
                    Slider { width: parent.width; height: 18; from: 0; to: 100; value: Number(root.inputVolume.replace("%", "")) || 0; onMoved: root.run("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + Math.round(value) + "%") }
                    EmberToggle { label: "Mute microphone"; detail: root.inputMuted ? "Microphone is muted" : "Microphone is live"; checked: root.inputMuted; onToggled: function(value) { root.inputMuted = value; root.run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") } }
                    Rectangle { width: parent.width; height: 1; color: root.outline }
                    Text { width: parent.width; height: 14; text: "OUTPUT DEVICE"; color: root.muted; font.family: root.uiFont; font.pixelSize: 10; font.bold: true }
                    Repeater { model: root.audioOutputs
                        delegate: EmberChoice {
                            required property var modelData
                            label: root.shortAudioName(modelData.name)
                            detail: modelData.active ? "Selected output" : "Select output"
                            selected: modelData.active
                            onChosen: root.run("wpctl set-default " + modelData.id)
                        }
                    }
                    Text { width: parent.width; height: 14; text: "MICROPHONE DEVICE"; color: root.muted; font.family: root.uiFont; font.pixelSize: 10; font.bold: true }
                    Repeater { model: root.audioInputs
                        delegate: EmberChoice {
                            required property var modelData
                            label: root.shortAudioName(modelData.name)
                            detail: modelData.active ? "Selected microphone" : "Select microphone"
                            selected: modelData.active
                            onChosen: root.run("wpctl set-default " + modelData.id)
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        visible: root.networkOpen; screen: bar.screen; anchors { top: true; left: true }
        margins { left: root.panelGap } exclusiveZone: 0; focusable: false; implicitWidth: 360; implicitHeight: 286; color: "transparent"
        Rectangle { anchors.fill: parent; radius: 0; color: "#f00e0207"; border.color: "transparent"
            ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 8
                Text { text: "NETWORK"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 12 }
                Text { text: root.ethernetState === "connected" ? root.ethernetConnection : "Ethernet disconnected"; color: root.rose; font.family: root.uiFont; font.pixelSize: 16 }
                EmberButton { glyph: "󰈀"; label: "Wired network settings"; Layout.fillWidth: true; onPressed: root.launch("nm-connection-editor") }
                Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }
                RowLayout { Layout.fillWidth: true
                    Text { text: "ETHERNET  " + root.lanInterface; color: root.muted; font.family: root.uiFont; font.pixelSize: 11; Layout.fillWidth: true }
                    Text { id: lanAddressText; text: root.lanAddress; color: lanAddressMouse.containsMouse ? root.hot : root.rose; font.family: root.uiFont; font.pixelSize: 11; font.underline: lanAddressMouse.containsMouse
                        MouseArea { id: lanAddressMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.copyToClipboard(root.lanAddress) }
                    }
                }
                RowLayout { Layout.fillWidth: true
                    Text { text: "Gateway"; color: root.muted; font.family: root.uiFont; font.pixelSize: 11; Layout.fillWidth: true }
                    Text { id: gatewayText; text: root.gateway; color: gatewayMouse.containsMouse ? root.hot : root.rose; font.family: root.uiFont; font.pixelSize: 11; font.underline: gatewayMouse.containsMouse
                        MouseArea { id: gatewayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.copyToClipboard(root.gateway) }
                    }
                }
                EmberToggle { label: "Private Internet Access"; detail: root.vpnState + (root.vpnRegion !== "--" ? " · " + root.vpnRegion : ""); checked: root.vpnState === "Connected"; onToggled: root.run(root.vpnState === "Connected" ? "piactl disconnect" : "piactl connect") }
                RowLayout { Layout.fillWidth: true
                    Text { text: "VPN address"; color: root.muted; font.family: root.uiFont; font.pixelSize: 11; Layout.fillWidth: true }
                    Text { id: vpnAddressText; text: root.vpnAddress; color: vpnAddressMouse.containsMouse ? root.hot : root.rose; font.family: root.uiFont; font.pixelSize: 11; font.underline: vpnAddressMouse.containsMouse
                        MouseArea { id: vpnAddressMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.copyToClipboard(root.vpnAddress) }
                    }
                }
                RowLayout { Layout.fillWidth: true
                    Text { text: "Latency  1.1.1.1"; color: root.muted; font.family: root.uiFont; font.pixelSize: 11; Layout.fillWidth: true }
                    Text { text: root.pingLatency; color: root.amber; font.family: root.uiFont; font.pixelSize: 11 }
                }
            }
        }
    }

    PanelWindow {
        visible: root.bluetoothOpen; screen: bar.screen; anchors { top: true; left: true }
        margins { left: root.panelGap } exclusiveZone: 0; focusable: false; implicitWidth: 286; implicitHeight: 232; color: "transparent"
        Rectangle { anchors.fill: parent; radius: 0; color: "#f00e0207"; border.color: "transparent"
            ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 8
                Text { text: "BLUETOOTH"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 12 }
                Text { text: root.bluetooth; color: root.rose; font.family: root.uiFont; font.pixelSize: 15 }
                EmberToggle { label: "Bluetooth radio"; detail: root.bluetooth === "Bluetooth on" ? "Ready to connect devices" : "Turn on to connect devices"; checked: root.bluetooth === "Bluetooth on"; onToggled: root.run(root.bluetooth === "Bluetooth on" ? "bluetoothctl power off" : "rfkill unblock bluetooth && bluetoothctl power on") }
                Text { text: "DEVICES"; color: root.muted; font.family: root.uiFont; font.pixelSize: 10; font.bold: true }
                Repeater { model: root.bluetoothDevices
                    delegate: EmberToggle {
                        required property var modelData
                        label: modelData.name
                        detail: modelData.connected ? "Connected · click to disconnect" : modelData.paired ? "Paired · click to connect" : "Nearby · click to pair"
                        checked: modelData.connected
                        onToggled: root.run(modelData.connected ? "bluetoothctl disconnect " + modelData.address : modelData.paired ? "bluetoothctl connect " + modelData.address : "bluetoothctl pair " + modelData.address + " && bluetoothctl trust " + modelData.address + " && bluetoothctl connect " + modelData.address)
                    }
                }
                Text { visible: root.bluetoothDevices.length === 0; text: root.bluetoothScanning ? "Looking for nearby devices…" : "No devices found"; color: root.muted; font.family: root.uiFont; font.pixelSize: 11 }
                EmberButton { glyph: "󰑐"; label: root.bluetoothScanning ? "Scanning…" : "Scan for devices"; Layout.fillWidth: true; enabled: !root.bluetoothScanning && root.bluetooth === "Bluetooth on"; onPressed: bluetoothScanRunner.running = true }
            }
        }
    }

    PanelWindow {
        visible: root.calendarOpen; screen: bar.screen; anchors { top: true; left: true }
        margins { left: root.panelGap } exclusiveZone: 0; focusable: false; implicitWidth: 260; implicitHeight: 160; color: "transparent"
        Rectangle { anchors.fill: parent; radius: 4; color: "#f00e0207"; border.color: "transparent"
            Column { anchors.fill: parent; anchors.margins: 12; spacing: 8
                Item { width: parent.width; height: 14
                    Row { anchors.centerIn: parent; spacing: 6
                        Text { text: Qt.formatDateTime(root.now, "MMMM").toUpperCase(); color: root.rose; font.family: root.uiFont; font.bold: true; font.pixelSize: 12 }
                        Text { text: Qt.formatDateTime(root.now, "yyyy"); color: root.muted; font.family: root.uiFont; font.bold: true; font.pixelSize: 12 }
                    }
                }
                Row { width: parent.width; height: 36; spacing: 9
                    Item { width: 56; height: parent.height }
                    Text { width: 38; height: parent.height; text: Qt.formatDateTime(root.now, "d"); color: root.rose; font.family: root.uiFont; font.pixelSize: 28; font.bold: true; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                    Column { height: parent.height; spacing: 2
                        Text { text: Qt.formatDateTime(root.now, "dddd"); color: root.muted; font.family: root.uiFont; font.pixelSize: 14 }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: root.outline }
                Row { width: 154; x: (parent.width - width) / 2; height: 10
                    Repeater { model: ["M", "T", "W", "T", "F", "S", "S"]
                        delegate: Text { required property string modelData; width: 22; text: modelData; color: root.muted; font.family: root.uiFont; font.pixelSize: 9; horizontalAlignment: Text.AlignHCenter }
                    }
                }
                Grid { width: 154; x: (parent.width - width) / 2; columns: 7; rowSpacing: 2
                    Repeater { model: 42
                        delegate: Item {
                            required property int index
                            readonly property int day: index - root.firstWeekday(root.now) + 1
                            visible: day > 0 && day <= root.daysInMonth(root.now)
                            width: 22; height: 7
                            Rectangle {
                                anchors.centerIn: parent; width: parent.day === root.now.getDate() ? 7 : 5; height: width; radius: width / 2
                                color: parent.day < root.now.getDate() ? "#9c5b6d" : (parent.day === root.now.getDate() ? root.hot : "#35101b")
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        visible: root.mediaOpen; screen: bar.screen; anchors { top: true; left: true }
        margins { left: root.panelGap } exclusiveZone: 0; focusable: false; implicitWidth: 390; implicitHeight: 255; color: "transparent"
        Rectangle { anchors.fill: parent; radius: 8; color: "#f018040a"; border.color: root.outline
            ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 14
                Text { text: "NOW PLAYING"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 13 }
                Text { text: root.nowPlaying; color: root.rose; font.family: root.uiFont; font.pixelSize: 17; wrapMode: Text.Wrap; Layout.fillWidth: true; maximumLineCount: 2; elide: Text.ElideRight }
                Text { text: root.nowPlaying === "Nothing playing" ? "Start any MPRIS-aware player to populate this card." : "Media controls use your active player."; color: root.muted; font.family: root.uiFont; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
                Item { Layout.fillHeight: true }
                RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: 18
                    EmberButton { glyph: "󰒮"; onPressed: root.run("playerctl previous") }
                    EmberButton { glyph: "󰐊"; label: "Play / pause"; glyphColor: root.hot; onPressed: root.run("playerctl play-pause") }
                    EmberButton { glyph: "󰒭"; onPressed: root.run("playerctl next") }
                }
            }
        }
    }

    PanelWindow {
        visible: root.powerOpen; screen: bar.screen; anchors { top: true; left: true }
        margins { left: root.panelGap } exclusiveZone: 0; focusable: false; implicitWidth: 300; implicitHeight: 250; color: "transparent"
        Rectangle { anchors.fill: parent; radius: 8; color: "#f018040a"; border.color: root.outline
            ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 8
                Text { text: "SESSION"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 13 }
                EmberButton { glyph: "󰤄"; label: "Lock"; Layout.fillWidth: true; onPressed: root.launch("hyprlock") }
                EmberButton { glyph: "󰜉"; label: "Log out"; Layout.fillWidth: true; onPressed: root.run("hyprctl dispatch 'hl.dsp.exit()'") }
                EmberButton { glyph: "󰑓"; label: "Reboot"; Layout.fillWidth: true; onPressed: root.run("systemctl reboot") }
                EmberButton { glyph: "󰐥"; label: "Power off"; Layout.fillWidth: true; glyphColor: root.hot; onPressed: root.run("systemctl poweroff") }
            }
        }
    }
}
