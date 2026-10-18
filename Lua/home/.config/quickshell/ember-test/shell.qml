//@ pragma UseQApplication

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import QtQuick.Layouts
import QtQml.Models
import QtQuick.Controls
import Qt.labs.settings
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Widgets

ShellRoot {
    id: root

    // Laptop configuration: run with `qs -c ember-test`.
    property bool controlOpen: false // retained only for compatibility during testing
    property bool audioOpen: false
    property bool networkOpen: false
    property bool bluetoothOpen: false
    property bool batteryOpen: false
    property bool notificationsOpen: false
    property bool notificationsPinned: false
    readonly property int notificationPanelWidth: 360
    readonly property int hyprGap: 4
    readonly property int barWidth: 0
    readonly property int panelGap: 16
    property alias dnd: notificationState.dnd
    property bool mediaOpen: false
    property bool calendarOpen: false
    property bool powerOpen: false
    property bool launcherOpen: false
    property string launcherQuery: ""
    property int launcherIndex: 0
    property string volume: "--"
    // EDIT ME: replace EDIT-ME-BATTERY / EDIT-ME-WIFI in polling commands below.
    property string battery: "--"
    property string network: "Offline"
    property int networkSignal: 0
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter !== null && btAdapter.enabled
    readonly property bool btConnected: Bluetooth.devices.values.some(d => d.connected)
    readonly property string bluetooth: btAdapter === null ? "No adapter" : btAdapter.state === BluetoothAdapterState.Blocked ? "Blocked" : btOn ? "Bluetooth on" : "Bluetooth off"
    readonly property var btPaired: Bluetooth.devices.values.filter(d => d.paired)
    readonly property var btNearby: Bluetooth.devices.values.filter(d => !d.paired && d.deviceName.length > 0)
    readonly property int btUnnamed: Bluetooth.devices.values.filter(d => !d.paired && d.deviceName.length === 0).length
    readonly property int btScanSeconds: 30
    property bool btScanning: false      // what the UI shows; set instantly on click
    property bool btPendingScan: false   // scan once the radio finishes powering on
    property bool btPendingEnable: false // power on once rfkill unblock lands
    property int btScanLeft: 0
    property var btWant: ({})   // address -> true while we're trying to connect
    property var btPrompt: null  // pending pairing request from bt-agent.py
    property var btFail: ({})   // address -> failure message, shown briefly
    function btSet(map, address, value) { let next = Object.assign({}, root[map]); if (value) next[address] = value; else delete next[address]; root[map] = next; }
    property string batteryStatus: "Unknown"
    property string batteryReserveTime: "Estimating…"
    property bool audioMuted: false
    property string inputVolume: "--"
    property bool inputMuted: false
    property bool wifiEnabled: false
    property bool wifiPowerSaveEnabled: false
    property string powerProfile: "balanced"
    property var audioOutputs: []
    property var audioInputs: []
    property string lanInterface: "--"
    property string lanAddress: "--"
    property string gateway: "--"
    property string vpnState: "Disconnected"
    property string vpnRegion: "--"
    property string vpnAddress: "--"
    property string pingLatency: "--"
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
    property int activeWorkspace: 1
    // EDIT ME: set a preferred output name, or use the first available screen.
    readonly property var primaryScreen: Quickshell.screens.find(s => s.name === "EDIT-ME") ?? Quickshell.screens[0]
    // Screen whose bar opened the current panel; panels follow it.
    property var panelScreen: primaryScreen
    property var launcherScreen: primaryScreen
    function workspaceIdsFor(monitorName) {
        // EDIT ME: optional output/workspace assignments matching hyprland.lua.
        // Existing workspaces are discovered dynamically when left unconfigured.
        let ids = monitorName === "EDIT-ME" ? [1, 2, 3, 4] : monitorName === "EDIT-ME-SECONDARY" ? [5, 6, 7, 8] : [];
        let existing = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (let i = 0; i < existing.length; i++) {
            let ws = existing[i];
            if (ws.id > 0 && ws.monitor && ws.monitor.name === monitorName && !ids.includes(ws.id)) ids.push(ws.id);
        }
        return ids.sort((a, b) => a - b);
    }
    function focusedScreen() { return Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? primaryScreen; }
    function openPanelFrom(screen, panelName) {
        // Same panel already open on another monitor: move it rather than close it.
        if (root[panelName] && panelScreen !== screen) { panelScreen = screen; return; }
        panelScreen = screen;
        toggle(panelName);
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
            }).slice(0, 6);
        }
        return apps.filter(app => (app.name + " " + app.genericName + " " + app.comment + " " + app.keywords.join(" ")).toLowerCase().includes(query))
                   .sort((a, b) => a.name.localeCompare(b.name)).slice(0, 6);
    }

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
    function wifiIcon() { return network === "Offline" ? "󰤭" : networkSignal < 30 ? "󰤟" : networkSignal < 60 ? "󰤢" : networkSignal < 80 ? "󰤥" : "󰤨" }
    function batteryIcon() { if (batteryStatus === "Charging") return "󰂄"; let p = Number(battery.replace("%", "")); return p < 15 ? "󰁺" : p < 35 ? "󰁼" : p < 60 ? "󰁾" : p < 85 ? "󰂀" : "󰁹" }
    readonly property bool anyPanelOpen: controlOpen || audioOpen || networkOpen || bluetoothOpen || batteryOpen || (notificationsOpen && !notificationsPinned) || mediaOpen || calendarOpen || powerOpen
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
    function closePanels() { controlOpen = false; audioOpen = false; networkOpen = false; bluetoothOpen = false; batteryOpen = false; notificationsOpen = notificationsPinned; mediaOpen = false; calendarOpen = false; powerOpen = false }
    function toggle(panelName) {
        let next = !root[panelName];
        closePanels();
        root[panelName] = next;
    }
    function btDeviceGlyph(icon) {
        if (icon.startsWith("audio-head")) return "󰋋";
        if (icon.startsWith("audio") || icon.includes("speaker")) return "󰓃";
        if (icon.includes("keyboard")) return "󰌌";
        if (icon.includes("mouse") || icon.includes("tablet")) return "󰍽";
        if (icon.includes("gaming")) return "󰊴";
        if (icon.includes("phone")) return "󰏲";
        if (icon.includes("computer")) return "󰟀";
        if (icon.includes("watch")) return "󰖉";
        return "󰂯";
    }
    function btSetPower(on) {
        if (!btAdapter) return;
        if (on && btAdapter.state === BluetoothAdapterState.Blocked) {
            btPendingEnable = true;
            run("rfkill unblock bluetooth");
        } else {
            btAdapter.enabled = on;
        }
        if (!on) btStopScan();
    }
    function btAgentMessage(message) {
        if (message.type === "ready") return;
        if (message.type === "cancel") { btPrompt = null; return; }
        btPrompt = message;
        bluetoothOpen = true;
    }
    function btAnswer(accept, value) {
        if (!btPrompt) return;
        if (btPrompt.id > 0) btAgent.write(btPrompt.id + (accept ? " yes" : " no") + (value ? " value " + value : "") + "\n");
        if (!accept) btSet("btWant", btPrompt.device.split("dev_")[1].replace(/_/g, ":"), false);
        btPrompt = null;
    }
    function btStartScan() {
        if (!btAdapter) return;
        btScanning = true;
        btScanLeft = btScanSeconds;
        btScanTimer.restart();
        if (!btOn) { btPendingScan = true; btSetPower(true); return; }
        btAdapter.discovering = true;
    }
    function btStopScan() {
        btScanning = false;
        btPendingScan = false;
        btScanTimer.stop();
        if (btAdapter && btAdapter.discovering) btAdapter.discovering = false;
    }
    onBluetoothOpenChanged: if (!bluetoothOpen && btScanning) btStopScan()
    onBatteryOpenChanged: {
        if (batteryOpen && !batteryReservePoll.running)
            batteryReservePoll.running = true;
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
        fileName: Quickshell.shellPath("launcher-history.ini")
        category: "ember-launcher"
        property var ids: []
    }

    Process {
        id: actionRunner
        onRunningChanged: if (!running) statusRefresh.restart()
    }
    Process { id: clipboardRunner }

    Process {
        id: statusPoll
        command: ["sh", "-c", "printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s' \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%d%%\", $2 * 100}')\" \"$(upower -i /org/freedesktop/UPower/devices/battery_EDIT-ME-BATTERY 2>/dev/null | awk '/percentage/ {print $2; exit}')\" \"$(cat /sys/class/power_supply/EDIT-ME-BATTERY/status 2>/dev/null)\" \"$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '$1==\"yes\" {print $2 \"|\" $3; exit}')\" \"\" \"$(playerctl metadata --format '{{artist}} — {{title}}' 2>/dev/null | head -1)\" \"$(hyprctl activewindow -j 2>/dev/null | sed -n 's/.*\\\"title\\\": \\\"\\([^\\\"]*\\\)\\\".*/\\1/p')\"" ]
        stdout: StdioCollector { id: statusOutput; onStreamFinished: {
            let lines = text.trim().split("\n");
            root.volume = lines[0] || "--";
            root.battery = lines[1] || "AC";
            root.batteryStatus = lines[2] || "Unknown";
            let wifi = (lines[3] || "").split("|");
            root.network = wifi[0] || "Offline";
            root.networkSignal = Number(wifi[1]) || 0;
            root.nowPlaying = lines[5] || "Nothing playing";
            root.focusedTitle = lines[6] || "Desktop";
        }}
        running: true
    }
    Process {
        id: quickStatePoll
        command: ["sh", "-c", "printf '%s\\n%s\\n%s\\n%s' \"$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q '\\[MUTED\\]' && echo yes || echo no)\" \"$(nmcli -t -f WIFI general status 2>/dev/null)\" \"$(powerprofilesctl get 2>/dev/null)\" \"$(iw dev EDIT-ME-WIFI get power_save 2>/dev/null | awk '/Power save:/ {print tolower($3); exit}')\"" ]
        stdout: StdioCollector { onStreamFinished: {
            let lines = text.trim().split("\n");
            root.audioMuted = lines[0] === "yes";
            root.wifiEnabled = lines[1] === "enabled";
            root.powerProfile = lines[2] || "balanced";
            root.wifiPowerSaveEnabled = lines[3] === "on";
        }}
        running: true
    }
    Process {
        id: batteryReservePoll
        command: ["sh", "-c", "upower -i /org/freedesktop/UPower/devices/battery_EDIT-ME-BATTERY 2>/dev/null | awk '$1==\"state:\" {state=$2} $1==\"energy:\" {energy=$2} $1==\"energy-full:\" {full=$2} $1==\"energy-rate:\" {rate=$2} END { if (state==\"discharging\" && rate>0 && full>0) { minutes=(energy-full*0.03)/rate*60; if (minutes<0) minutes=0; hours=int(minutes/60); mins=int(minutes-hours*60+0.5); if (mins==60) {hours++; mins=0} if (hours>0) printf \"%dh %02dm\\n\", hours, mins; else printf \"%d min\\n\", mins } else if (state==\"charging\") print \"Charging\"; else if (state==\"fully-charged\") print \"On AC\"; else print \"Estimating…\" }'" ]
        stdout: StdioCollector {
            onStreamFinished: root.batteryReserveTime = text.trim() || "Estimating…"
        }
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
        command: ["sh", "-c", "lan=$(ip route show default 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if($i==\"dev\") {print $(i+1); exit}}'); lanip=$(ip -4 -o addr show dev \"$lan\" scope global 2>/dev/null | awk '{print $4; exit}'); gw=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}'); vpnstate=$(piactl get connectionstate 2>/dev/null || echo Disconnected); vpnregion=$(piactl get region 2>/dev/null || echo --); vpnip=$(ip -4 -o addr show dev tun0 scope global 2>/dev/null | awk '{print $4; exit}'); latency=$(ping -n -c 1 -W 1 1.1.1.1 2>/dev/null | awk '/time=/ {match($0, /time=[0-9.]+/); value=substr($0, RSTART, RLENGTH); sub(\"time=\", \"\", value); print value \" ms\"; exit}'); printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n' \"$lan\" \"$lanip\" \"$gw\" \"$vpnstate\" \"$vpnregion\" \"$vpnip\" \"$latency\"" ]
        stdout: StdioCollector { onStreamFinished: {
            let lines = text.trim().split("\n");
            root.lanInterface = lines[0] || "--";
            root.lanAddress = lines[1] || "--";
            root.gateway = lines[2] || "--";
            root.vpnState = lines[3] || "Disconnected";
            root.vpnRegion = lines[4] || "--";
            root.vpnAddress = lines[5] || "--";
            root.pingLatency = lines[6] || "--";
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
            if (!audioDevicePoll.running) audioDevicePoll.running = true;
            if (!networkDetailsPoll.running) networkDetailsPoll.running = true;
        }
    }
    Timer {
        interval: 12000; running: true; repeat: true
        onTriggered: if (!networkDetailsPoll.running) networkDetailsPoll.running = true
    }
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: if (!batteryReservePoll.running) batteryReservePoll.running = true
    }
    // BlueZ needs an agent to confirm passkeys/PINs; without one most pairing
    // attempts fail with "Authentication Failed".
    Process {
        id: btAgent
        command: ["python3", "-I", Quickshell.shellPath("bt-agent.py")]
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: data => { try { root.btAgentMessage(JSON.parse(data)) } catch (e) { console.warn("bt-agent:", data) } } }
        stderr: SplitParser { onRead: data => console.warn("bt-agent:", data) }
        onExited: btAgentRestart.restart()
    }
    Timer { id: btAgentRestart; interval: 3000; onTriggered: btAgent.running = true }
    Timer {
        id: btScanTimer
        interval: 1000; repeat: true
        onTriggered: { root.btScanLeft--; if (root.btScanLeft <= 0) root.btStopScan() }
    }
    Connections {
        target: root.btAdapter
        function onStateChanged() {
            if (root.btPendingEnable && root.btAdapter.state === BluetoothAdapterState.Disabled) {
                root.btPendingEnable = false;
                root.btAdapter.enabled = true;
            }
        }
        function onEnabledChanged() {
            if (root.btAdapter.enabled && root.btPendingScan) {
                root.btPendingScan = false;
                root.btAdapter.discovering = true;
            }
            if (!root.btAdapter.enabled) root.btStopScan();
        }
        function onDiscoveringChanged() {
            // Something else (or BlueZ) ended discovery: keep the UI honest.
            if (!root.btAdapter.discovering && root.btScanning && !root.btPendingScan && root.btScanLeft < root.btScanSeconds - 2) root.btStopScan();
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { if (Hyprland.focusedWorkspace) root.activeWorkspace = Hyprland.focusedWorkspace.id }
        function onActiveToplevelChanged() { root.focusedTitle = Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "Desktop" }
    }
    IpcHandler {
        target: "ember"
        function notificationStatus(): string { return JSON.stringify({ dnd: root.dnd, history: root.notificationHistory.length, pinned: root.notificationsPinned }); }
        function toggleLauncher(): void {
            root.closePanels();
            if (!root.launcherOpen) root.launcherScreen = root.focusedScreen();
            root.launcherOpen = !root.launcherOpen;
            root.launcherQuery = "";
            root.launcherIndex = 0;
        }
        // e.g. `qs -c ember-test ipc call ember togglePanel bluetooth`
        function togglePanel(name: string): void { root.openPanelFrom(root.focusedScreen(), name + "Open"); }
        function bluetoothScan(): void { root.bluetoothOpen = true; root.btStartScan(); }
    }
    // Clicking anywhere outside the bar or an open panel clears the grab and
    // closes the panel. The bar is included so its buttons still switch panels.
    HyprlandFocusGrab {
        active: root.anyPanelOpen
        windows: bars.instances.concat([controlPanel, notificationsPanel, audioPanel, networkPanel, bluetoothPanel, batteryPanel, calendarPanel, mediaPanel, powerPanel])
        onCleared: root.closePanels()
    }
    ListModel { id: notificationPopups; onCountChanged: Qt.callLater(root.releaseTransients) }

    // Survives shell reloads (not a full Quickshell restart).
    PersistentProperties {
        id: notificationState
        reloadableId: "emberNotificationState"
        property bool dnd: false
        // JSON text: JS objects in a var do not carry across a reload.
        property string times: "{}"
        property string epoch: ""
        property string offlineClosures: "[]"
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
            else root.retainNotification(notification, Number(notification.hints["x-edge-kvm-posted-ms"]) || Date.now());
            // DND only suppresses presentation, including critical urgency for now.
            if (root.dnd || notification.hints["x-edge-kvm-replay"]) return;
            root.showNotificationPopup(notification);
            if (root.notificationSoundEnabled && !notification.hints["suppress-sound"] && !notificationChime.running)
                notificationChime.running = true;
        }
    }

    EdgeNotificationBridge {
        id: edgeNotificationBridge
        server: notificationServer
        state: notificationState
        timestamps: root.notificationTimes
        // Enable through edge-kvm settings, or provide the socket explicitly.
        socketPath: Quickshell.env("EDGE_KVM_NOTIFICATION_SOCKET") || ""
        onEntryClosed: id => {
            root.removeNotificationPopup(id);
            if (root.notificationTimes[id] === undefined) return;
            let times = Object.assign({}, root.notificationTimes);
            delete times[id];
            notificationState.times = JSON.stringify(times);
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

    // One watcher per BlueZ device, independent of the panel's rows, so a
    // pair -> trust -> connect sequence survives the row moving between lists.
    component BtWatcher: Item {
        id: watcher
        required property var modelData
        readonly property var dev: modelData
        readonly property bool wanted: root.btWant[dev.address] === true
        readonly property bool busy: dev.pairing || dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting
        function fail(message) { root.btSet("btWant", dev.address, false); root.btSet("btFail", dev.address, message); failClear.restart(); }
        Timer { id: failClear; interval: 5000; onTriggered: root.btSet("btFail", watcher.dev.address, false) }
        // A failed attempt drops straight back to Disconnected; wait a moment
        // so the short gap between pairing and connecting isn't flagged.
        Timer { id: failCheck; interval: 1500
            onTriggered: if (watcher.wanted && !watcher.dev.connected && !watcher.busy) watcher.fail(watcher.dev.paired ? "Couldn't connect — is it on and in range?" : "Pairing failed — put it in pairing mode")
        }
        Connections {
            target: watcher.dev
            function onPairedChanged() {
                if (watcher.dev.paired && root.btPrompt && root.btPrompt.device === watcher.dev.dbusPath) root.btPrompt = null;
                if (watcher.dev.paired && watcher.wanted) { watcher.dev.trusted = true; watcher.dev.connect(); }
            }
            function onPairingChanged() {
                if (watcher.dev.pairing) return;
                if (root.btPrompt && root.btPrompt.device === watcher.dev.dbusPath) root.btPrompt = null;
                if (watcher.wanted) failCheck.restart();
            }
            function onStateChanged() {
                if (watcher.dev.connected) root.btSet("btWant", watcher.dev.address, false);
                else if (watcher.dev.state === BluetoothDeviceState.Disconnected && watcher.wanted) failCheck.restart();
            }
        }
    }
    Instantiator { model: Bluetooth.devices; delegate: BtWatcher {} }

    component BtDeviceRow: Rectangle {
        id: row
        required property var modelData
        readonly property var dev: modelData
        readonly property bool wanted: root.btWant[dev.address] === true
        readonly property string failText: root.btFail[dev.address] || ""
        readonly property bool busy: dev.pairing || dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting || (wanted && !dev.connected)
        readonly property bool hovered: rowMouse.containsMouse || forgetButton.hovered
        width: parent ? parent.width : 0; height: 42; radius: 4
        color: dev.connected ? "#2b0c18" : hovered ? "#33091a" : root.surfaceRaised
        border.color: failText ? root.ember : busy ? root.amber : dev.connected ? root.hot : hovered ? root.outline : "#401020"
        Behavior on color { ColorAnimation { duration: 90 } }

        function activate() {
            root.btSet("btFail", dev.address, false);
            if (dev.pairing) { root.btSet("btWant", dev.address, false); dev.cancelPair(); return; }
            if (busy) return;
            if (dev.connected) { dev.disconnect(); return; }
            root.btSet("btWant", dev.address, true);
            if (dev.paired) dev.connect(); else dev.pair();
        }
        function statusText() {
            if (failText) return failText;
            if (dev.pairing) return "Pairing… click to cancel";
            if (dev.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
            if (busy) return "Connecting…";
            if (dev.connected) return "Connected" + (dev.batteryAvailable ? " · 󰁹 " + Math.round(dev.battery * 100) + "%" : "") + " · click to disconnect";
            return dev.paired ? "Click to connect" : "Click to pair & connect";
        }

        MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.activate() }
        RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
            Text { text: root.btDeviceGlyph(row.dev.icon); color: row.dev.connected ? root.hot : root.rose; font.family: root.iconFont; font.pixelSize: 17; Layout.preferredWidth: 18 }
            ColumnLayout { Layout.fillWidth: true; spacing: 1
                Text { text: row.dev.name; color: root.rose; font.family: root.uiFont; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: row.statusText(); color: row.failText ? root.hot : row.busy ? root.amber : root.muted; font.family: root.uiFont; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Text {
                visible: row.busy
                text: "󰑓"; color: root.amber; font.family: root.iconFont; font.pixelSize: 14
                RotationAnimator on rotation { running: row.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
            }
            EmberButton { id: forgetButton; visible: row.dev.paired && row.hovered && !row.busy; glyph: "󰆴"; glyphColor: root.muted; iconSize: 13; compact: true; onPressed: { root.btSet("btWant", row.dev.address, false); row.dev.forget() } }
        }
    }

    Variants {
        id: bars
        model: Quickshell.screens
        PanelWindow {
            id: bar
            required property var modelData
            readonly property var monitor: Hyprland.monitorFor(modelData)
            readonly property bool monitorFocused: Hyprland.focusedMonitor !== null && monitor !== null && Hyprland.focusedMonitor.name === monitor.name
            readonly property int monitorWorkspace: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
            function open(panelName) { root.openPanelFrom(bar.screen, panelName) }
            screen: modelData
            anchors { top: true; left: true; right: true }
            exclusiveZone: 24
            implicitHeight: 24
            color: root.ink
            Rectangle {
                anchors.fill: parent; radius: 0; color: root.ink
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.outline }
                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Repeater { model: root.workspaceIdsFor(bar.modelData.name)
                        delegate: Rectangle {
                            required property int modelData
                            width: 28; height: 24; radius: 0
                            color: bar.monitorWorkspace === modelData ? (bar.monitorFocused ? "#7a0c23" : "#3d0816") : (workspaceMouse.containsMouse ? root.surfaceRaised : "transparent")
                            Text { anchors.centerIn: parent; text: modelData; color: root.rose; font.family: root.uiFont; font.pixelSize: 11 }
                            Rectangle { visible: bar.monitorWorkspace === modelData && bar.monitorFocused; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 2; color: root.hot }
                            MouseArea { id: workspaceMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.closePanels(); root.run("hyprctl dispatch workspace " + modelData) } }
                        }
                    }
                    Rectangle { width: 1; height: 14; color: root.outline; anchors.verticalCenter: parent.verticalCenter }
                    Text { width: 340; anchors.verticalCenter: parent.verticalCenter; leftPadding: 8; text: bar.monitorFocused ? root.focusedTitle : (bar.monitor && bar.monitor.activeWorkspace && bar.monitor.activeWorkspace.toplevels.values.length > 0 ? bar.monitor.activeWorkspace.toplevels.values[0].title : "Desktop"); color: root.muted; font.family: root.uiFont; font.pixelSize: 11; elide: Text.ElideRight }
                }
                EmberButton { anchors.centerIn: parent; label: Qt.formatDateTime(root.now, "HH:mm"); glyphColor: root.amber; height: 24; onPressed: bar.open("calendarOpen") }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 0
                    Repeater { model: SystemTray.items
                        delegate: MouseArea {
                            id: trayButton
                            required property var modelData
                            width: 22; height: 24; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            function openNativeMenu() {
                                if (!modelData.hasMenu) return;
                                let point = trayButton.mapToItem(null, 0, trayButton.height);
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
                    Item { visible: SystemTray.items.values.length > 0; width: 9; height: 24
                        Rectangle { width: 1; height: 14; color: root.outline; anchors.centerIn: parent }
                    }
                    EmberButton { glyph: root.wifiIcon(); label: ""; glyphColor: root.network === "Offline" ? root.muted : root.rose; iconSize: 14; chrome: false; compact: true; height: 24; onPressed: bar.open("networkOpen") }
                    EmberButton { glyph: !root.btOn ? "󰂲" : root.btConnected ? "󰂱" : "󰂯"; label: ""; glyphColor: root.btScanning ? root.amber : root.btOn ? root.rose : root.muted; iconSize: 14; chrome: false; compact: true; height: 24; onPressed: bar.open("bluetoothOpen") }
                    EmberButton { glyph: root.volumeIcon(); label: root.volume; glyphColor: root.rose; labelColor: root.statusText; iconSize: 14; chrome: false; compact: true; height: 24; onPressed: bar.open("audioOpen") }
                    EmberButton { glyph: root.batteryIcon(); label: root.battery; glyphColor: root.batteryStatus === "Charging" ? root.amber : root.rose; labelColor: root.statusText; iconSize: 14; chrome: false; compact: true; height: 24; onPressed: bar.open("batteryOpen") }
                    EmberButton { glyph: root.dnd ? "󰂛" : "󰂚"; label: root.notificationHistory.length > 0 ? root.notificationHistory.length : ""; glyphColor: root.muted; iconSize: 14; chrome: false; compact: true; height: 24; onPressed: bar.open("notificationsOpen") }
                }
            }
        }
    }

    PanelWindow {
        id: launcher
        visible: root.launcherOpen
        screen: root.launcherScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        focusable: true
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: { root.launcherOpen = false; root.launcherQuery = "" } }
        Rectangle {
            id: launcherCard
            width: 460; height: 58 + Math.min(6, root.launcherApps.length) * 40
            anchors.centerIn: parent
            radius: 5
            color: "#f00e0207"
            border.color: root.outline
            border.width: 1
            MouseArea { anchors.fill: parent }
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
                    Keys.onDownPressed: { root.launcherIndex = Math.min(launcherList.count - 1, root.launcherIndex + 1); launcherList.currentIndex = root.launcherIndex }
                    Keys.onUpPressed: { root.launcherIndex = Math.max(0, root.launcherIndex - 1); launcherList.currentIndex = root.launcherIndex }
                    Keys.onReturnPressed: { if (launcherList.count > 0) root.launchApp(root.launcherApps[root.launcherIndex]) }
                    Text { visible: !launcherInput.text; anchors.verticalCenter: parent.verticalCenter; text: "Search applications…"; color: root.muted; font.family: root.uiFont; font.pixelSize: 16 }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.hot }
                }
                ListView {
                    id: launcherList
                    Layout.fillWidth: true; Layout.preferredHeight: Math.min(6, count) * 40
                    model: root.launcherApps
                    currentIndex: root.launcherIndex
                    clip: true; spacing: 0
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: launcherList.width; height: 40; radius: 2
                        color: root.launcherIndex === index ? root.surfaceRaised : (appMouse.containsMouse ? "#210c0610" : "transparent")
                        RowLayout { anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7; spacing: 8
                            IconImage { source: Quickshell.iconPath(modelData.icon); width: 22; height: 22 }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1
                                Text { text: modelData.name; color: root.rose; font.family: root.uiFont; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: modelData.genericName || modelData.comment; color: root.muted; font.family: root.uiFont; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                        MouseArea { id: appMouse; anchors.fill: parent; hoverEnabled: true; onEntered: root.launcherIndex = index; onClicked: root.launchApp(modelData) }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: controlPanel
        visible: root.controlOpen; screen: root.panelScreen; anchors { top: true; right: true }
        margins { top: 0; right: 8 } exclusiveZone: 0; focusable: true; implicitWidth: 360; implicitHeight: 440; color: "transparent"
        Shortcut { sequence: "Escape"; onActivated: root.closePanels() }
        Rectangle { anchors.fill: parent; radius: 8; color: "#f018040a"; border.color: root.outline; border.width: 1
            ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 14
                Text { text: "CONTROL CENTRE"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 13 }
                Text { text: Qt.formatDateTime(root.now, "dddd, d MMMM"); color: root.rose; font.family: root.uiFont; font.pixelSize: 20 }
                Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }
                Text { text: "󰕾  " + root.volume; color: root.rose; font.family: root.iconFont; font.pixelSize: 17 }
                RowLayout { Layout.fillWidth: true; EmberButton { glyph: "−"; onPressed: root.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") } EmberButton { glyph: "󰕾"; label: "Audio settings"; Layout.fillWidth: true; onPressed: root.launch("pavucontrol") } EmberButton { glyph: "+"; onPressed: root.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") } }
                Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }
                Text { text: "󰍹  " + root.network; color: root.rose; font.family: root.iconFont; font.pixelSize: 17 }
                EmberButton { glyph: "󰤨"; label: "Network settings"; Layout.fillWidth: true; onPressed: root.launch("nm-connection-editor") }
                EmberButton { glyph: "󰂯"; label: root.bluetooth; Layout.fillWidth: true; onPressed: root.launch("blueman-manager") }
                Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }
                Text { text: "󰁹  Battery " + root.battery; color: root.amber; font.family: root.uiFont; font.pixelSize: 14 }
                Item { Layout.fillHeight: true }
                EmberButton { glyph: root.dnd ? "󰂛" : "󰂚"; label: root.dnd ? "Do not disturb: on" : "Do not disturb: off"; active: root.dnd; Layout.fillWidth: true; onPressed: root.dnd = !root.dnd }
            }
        }
    }

    PanelWindow {
        id: notificationOverlay
        visible: true
        screen: root.panelScreen
        anchors { bottom: true; right: true }
        margins { right: root.panelGap; bottom: 20 }
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
        id: notificationsPanel
        // Unpinned, the surface covers the screen so an outside click closes it.
        // Pinned, it shrinks to the panel and claims an exclusive zone, which
        // moves the scrolling layout's right edge to the panel's left edge.
        visible: root.notificationsOpen; screen: root.panelScreen; anchors { top: true; bottom: true; left: !root.notificationsPinned; right: true }
        implicitWidth: root.hyprGap + root.notificationPanelWidth
        exclusiveZone: root.notificationsPinned ? implicitWidth : 0; focusable: false; color: "transparent"
        MouseArea { anchors.fill: parent; enabled: !root.notificationsPinned; onClicked: root.notificationsOpen = false }
        Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right; rightMargin: root.hyprGap } width: root.notificationPanelWidth; z: 1; radius: 4; color: "#f00e0207"; border.width: 0
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
                                    Text { text: edgeNotificationBridge.appLabel(modelData); textFormat: Text.PlainText; color: root.muted; font.family: root.uiFont; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { text: root.notificationTimestamp(root.notificationTimes[modelData.id]); color: root.statusText; font.family: root.uiFont; font.pixelSize: 9; Layout.alignment: Qt.AlignTop }
                                }
                                Text { text: modelData.summary; textFormat: Text.PlainText; color: root.rose; font.family: root.uiFont; font.bold: true; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.Wrap }
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
        id: audioPanel
        visible: root.audioOpen; screen: root.panelScreen; anchors { top: true; bottom: true; right: true }
        margins { top: 0 } exclusiveZone: 0; focusable: true; implicitWidth: 360; color: "transparent"
        Shortcut { sequence: "Escape"; onActivated: root.closePanels() }
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
        id: networkPanel
        visible: root.networkOpen; screen: root.panelScreen; anchors { top: true; right: true }
        margins { top: 0 } exclusiveZone: 0; focusable: true; implicitWidth: 360; implicitHeight: 318; color: "transparent"
        Shortcut { sequence: "Escape"; onActivated: root.closePanels() }
        Rectangle { anchors.fill: parent; radius: 0; color: "#f00e0207"; border.color: "transparent"
            ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 8
                Text { text: "NETWORK"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 12 }
                Text { text: root.network === "Offline" ? "No Wi-Fi connection" : root.network; color: root.rose; font.family: root.uiFont; font.pixelSize: 16 }
                EmberToggle { label: "Wi-Fi radio"; detail: root.wifiEnabled ? "Wireless enabled" : "Wireless disabled"; checked: root.wifiEnabled; onToggled: root.run(root.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on") }
                Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }
                RowLayout { Layout.fillWidth: true
                    Text { text: "LAN  " + root.lanInterface; color: root.muted; font.family: root.uiFont; font.pixelSize: 11; Layout.fillWidth: true }
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
        id: bluetoothPanel
        visible: root.bluetoothOpen; screen: root.panelScreen; anchors { top: true; right: true }
        margins { top: 0 } exclusiveZone: 0; focusable: true; implicitWidth: 320; implicitHeight: btContent.implicitHeight + 28; color: "transparent"
        Shortcut { sequence: "Escape"; onActivated: root.closePanels() }
        Rectangle { anchors.fill: parent; radius: 0; color: "#f00e0207"; border.color: "transparent"
            ColumnLayout { id: btContent; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 } spacing: 8
                RowLayout { Layout.fillWidth: true
                    Text { text: "BLUETOOTH"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 12; Layout.fillWidth: true }
                    Text { text: root.btAdapter ? root.btAdapter.name : ""; color: root.muted; font.family: root.uiFont; font.pixelSize: 10 }
                }
                EmberToggle {
                    label: "Bluetooth radio"
                    detail: root.btAdapter === null ? "No adapter found" : root.btAdapter.state === BluetoothAdapterState.Enabling || root.btPendingEnable ? "Turning on…" : root.btAdapter.state === BluetoothAdapterState.Disabling ? "Turning off…" : root.btAdapter.state === BluetoothAdapterState.Blocked ? "Blocked by rfkill — click to unblock" : root.btOn ? "On" : "Off"
                    checked: root.btOn || root.btPendingEnable
                    onToggled: function(value) { root.btSetPower(value) }
                }

                // Scan button: flips state on click, then shows a live countdown.
                Rectangle {
                    id: scanButton
                    Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 4
                    enabled: root.btAdapter !== null
                    color: root.btScanning ? "#2b0c18" : scanMouse.containsMouse ? "#33091a" : root.surfaceRaised
                    border.color: root.btScanning ? root.amber : scanMouse.containsMouse ? root.outline : "#401020"
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Text {
                            text: root.btScanning ? "󰑓" : "󰂰"; color: root.btScanning ? root.amber : root.rose; font.family: root.iconFont; font.pixelSize: 15
                            RotationAnimator on rotation { running: root.btScanning; from: 0; to: 360; duration: 1100; loops: Animation.Infinite }
                            onTextChanged: if (!root.btScanning) rotation = 0
                        }
                        Text { Layout.fillWidth: true; text: !root.btScanning ? "Scan for devices" : root.btPendingScan ? "Turning on Bluetooth…" : "Scanning… " + root.btScanLeft + "s"; color: root.rose; font.family: root.uiFont; font.pixelSize: 12 }
                        Text { text: root.btScanning ? "Stop" : ""; color: root.muted; font.family: root.uiFont; font.pixelSize: 10 }
                    }
                    Rectangle {
                        visible: root.btScanning
                        anchors { left: parent.left; bottom: parent.bottom; margins: 1 }
                        height: 2; color: root.amber
                        width: (parent.width - 2) * root.btScanLeft / root.btScanSeconds
                        Behavior on width { NumberAnimation { duration: 1000 } }
                    }
                    MouseArea { id: scanMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.btScanning ? root.btStopScan() : root.btStartScan() }
                }

                Rectangle {
                    id: pairPrompt
                    readonly property var req: root.btPrompt
                    readonly property bool needsInput: req !== null && (req.type === "pin" || req.type === "passkey")
                    visible: req !== null
                    Layout.fillWidth: true; Layout.preferredHeight: promptColumn.implicitHeight + 24
                    radius: 4; color: "#2b0c18"; border.color: root.hot; border.width: 1
                    onNeedsInputChanged: if (needsInput) { pinInput.text = ""; pinInput.forceActiveFocus() }
                    ColumnLayout { id: promptColumn; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 } spacing: 8
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: !pairPrompt.req ? "" : pairPrompt.req.type === "confirm" ? "Pair with " + pairPrompt.req.name + "?"
                                : pairPrompt.req.type === "authorize" ? "Allow " + pairPrompt.req.name + " to pair?"
                                : pairPrompt.req.type === "display" ? "Type this code on " + pairPrompt.req.name + ", then press Enter"
                                : "Enter the " + (pairPrompt.req.type === "pin" ? "PIN" : "passkey") + " for " + pairPrompt.req.name
                            color: root.rose; font.family: root.uiFont; font.pixelSize: 12; font.bold: true
                        }
                        Text {
                            visible: pairPrompt.req !== null && pairPrompt.req.passkey !== undefined
                            Layout.alignment: Qt.AlignHCenter
                            text: pairPrompt.req && pairPrompt.req.passkey ? pairPrompt.req.passkey.replace(/(\d{3})(\d{3})/, "$1 $2") : ""
                            color: root.amber; font.family: root.uiFont; font.pixelSize: 26; font.bold: true; font.letterSpacing: 2
                        }
                        Text {
                            visible: pairPrompt.req !== null && pairPrompt.req.type === "confirm"
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                            text: "Check the same code is shown on the device."
                            color: root.muted; font.family: root.uiFont; font.pixelSize: 10
                        }
                        Rectangle {
                            visible: pairPrompt.needsInput
                            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 3; color: root.ink; border.color: root.outline
                            TextInput {
                                id: pinInput
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; verticalAlignment: TextInput.AlignVCenter
                                color: root.rose; font.family: root.uiFont; font.pixelSize: 14; clip: true
                                inputMethodHints: pairPrompt.req && pairPrompt.req.type === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
                                Keys.onReturnPressed: if (text) root.btAnswer(true, text)
                                Keys.onEnterPressed: if (text) root.btAnswer(true, text)
                            }
                        }
                        RowLayout { Layout.fillWidth: true; spacing: 6
                            Item { Layout.fillWidth: true }
                            EmberButton { label: pairPrompt.req && pairPrompt.req.type === "display" ? "Dismiss" : "Cancel"; onPressed: root.btAnswer(false) }
                            EmberButton {
                                visible: pairPrompt.req !== null && pairPrompt.req.type !== "display"
                                glyph: "󰄬"; label: "Pair"; glyphColor: root.hot; active: true
                                onPressed: root.btAnswer(true, pairPrompt.needsInput ? pinInput.text : "")
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(deviceColumn.implicitHeight, 380)
                    contentWidth: width; contentHeight: deviceColumn.implicitHeight
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: deviceColumn
                        width: parent.width; spacing: 5
                        Text { visible: root.btPaired.length > 0; width: parent.width; height: 18; verticalAlignment: Text.AlignBottom; text: "MY DEVICES"; color: root.muted; font.family: root.uiFont; font.pixelSize: 10; font.bold: true }
                        Repeater { model: root.btPaired; delegate: BtDeviceRow {} }
                        Text { visible: root.btScanning || root.btNearby.length > 0; width: parent.width; height: 22; verticalAlignment: Text.AlignBottom; text: "NEARBY" + (root.btNearby.length > 0 ? "  " + root.btNearby.length : ""); color: root.muted; font.family: root.uiFont; font.pixelSize: 10; font.bold: true }
                        Repeater { model: root.btNearby; delegate: BtDeviceRow {} }
                        Text {
                            id: btSearchingText
                            visible: root.btScanning && root.btNearby.length === 0
                            width: parent.width; wrapMode: Text.Wrap
                            text: "Looking for devices… put yours in pairing mode."
                            color: root.amber; font.family: root.uiFont; font.pixelSize: 11
                            SequentialAnimation on opacity { running: btSearchingText.visible; loops: Animation.Infinite
                                NumberAnimation { from: 1; to: 0.35; duration: 700 } NumberAnimation { from: 0.35; to: 1; duration: 700 } }
                        }
                        Text { visible: root.btUnnamed > 0 && root.btScanning; width: parent.width; text: root.btUnnamed + " unnamed device" + (root.btUnnamed === 1 ? "" : "s") + " hidden"; color: root.muted; font.family: root.uiFont; font.pixelSize: 10 }
                        Text { visible: !root.btScanning && root.btPaired.length === 0 && root.btNearby.length === 0; width: parent.width; wrapMode: Text.Wrap; text: "No devices yet. Scan to find something to pair."; color: root.muted; font.family: root.uiFont; font.pixelSize: 11 }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: batteryPanel
        visible: root.batteryOpen; screen: root.panelScreen; anchors { top: true; right: true }
        margins { top: 0 } exclusiveZone: 0; focusable: true; implicitWidth: 286; implicitHeight: 206; color: "transparent"
        Shortcut { sequence: "Escape"; onActivated: root.closePanels() }
        Rectangle { anchors.fill: parent; radius: 0; color: "#f00e0207"; border.color: "transparent"
            ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 8
                Text { text: "BATTERY"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 12 }
                Text { text: root.battery + "  ·  " + root.batteryStatus; color: root.amber; font.family: root.uiFont; font.pixelSize: 16 }
                RowLayout { Layout.fillWidth: true; spacing: 7
                    Text { text: root.batteryReserveTime; color: root.rose; font.family: root.uiFont; font.bold: true; font.pixelSize: 13 }
                    Text { visible: root.batteryStatus === "Discharging"; text: "until 3%"; color: root.muted; font.family: root.uiFont; font.pixelSize: 11 }
                    Item { Layout.fillWidth: true }
                }
                Text { text: "System profile: " + root.powerProfile; color: root.muted; font.family: root.uiFont; font.pixelSize: 11 }
                EmberToggle {
                    label: "Wi-Fi power saving"
                    detail: root.wifiPowerSaveEnabled ? "Enabled for SKYCCKD1" : "Disabled for SKYCCKD1"
                    checked: root.wifiPowerSaveEnabled
                    onToggled: function(value) {
                        root.wifiPowerSaveEnabled = value;
                        root.run(value
                            ? "nmcli connection modify SKYCCKD1 802-11-wireless.powersave 3 && nmcli connection down SKYCCKD1 && nmcli connection up SKYCCKD1"
                            : "nmcli connection modify SKYCCKD1 802-11-wireless.powersave 2 && nmcli connection down SKYCCKD1 && nmcli connection up SKYCCKD1");
                    }
                }
                RowLayout { Layout.fillWidth: true; spacing: 4
                    EmberButton { label: "Saver"; active: root.powerProfile === "power-saver"; Layout.fillWidth: true; onPressed: if (root.powerProfile !== "power-saver") root.run("powerprofilesctl set power-saver") }
                    EmberButton { label: "Balanced"; active: root.powerProfile === "balanced"; Layout.fillWidth: true; onPressed: if (root.powerProfile !== "balanced") root.run("powerprofilesctl set balanced") }
                    EmberButton { label: "Performance"; active: root.powerProfile === "performance"; Layout.fillWidth: true; onPressed: if (root.powerProfile !== "performance") root.run("powerprofilesctl set performance") }
                }
            }
        }
    }

    PanelWindow {
        id: calendarPanel
        visible: root.calendarOpen; screen: root.panelScreen; anchors { top: true }
        margins { top: 0 } exclusiveZone: 0; focusable: true; implicitWidth: 260; implicitHeight: 160; color: "transparent"
        Shortcut { sequence: "Escape"; onActivated: root.closePanels() }
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
        id: mediaPanel
        visible: root.mediaOpen; screen: root.panelScreen; anchors { top: true; right: true }
        margins { top: 0; right: 8 } exclusiveZone: 0; focusable: true; implicitWidth: 390; implicitHeight: 255; color: "transparent"
        Shortcut { sequence: "Escape"; onActivated: root.closePanels() }
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
        id: powerPanel
        visible: root.powerOpen; screen: root.panelScreen; anchors { top: true; right: true }
        margins { top: 0; right: 8 } exclusiveZone: 0; focusable: true; implicitWidth: 300; implicitHeight: 250; color: "transparent"
        Shortcut { sequence: "Escape"; onActivated: root.closePanels() }
        Rectangle { anchors.fill: parent; radius: 8; color: "#f018040a"; border.color: root.outline
            ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 8
                Text { text: "SESSION"; color: root.hot; font.family: root.uiFont; font.bold: true; font.pixelSize: 13 }
                EmberButton { glyph: "󰤄"; label: "Lock"; Layout.fillWidth: true; onPressed: root.launch("hyprlock") }
                EmberButton { glyph: "󰜉"; label: "Log out"; Layout.fillWidth: true; onPressed: root.run("hyprctl dispatch exit") }
                EmberButton { glyph: "󰑓"; label: "Reboot"; Layout.fillWidth: true; onPressed: root.run("systemctl reboot") }
                EmberButton { glyph: "󰐥"; label: "Power off"; Layout.fillWidth: true; glyphColor: root.hot; onPressed: root.run("systemctl poweroff") }
            }
        }
    }
}
