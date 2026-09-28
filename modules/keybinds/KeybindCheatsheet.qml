// KeybindCheatsheet.qml
// Quickshell-native keybind cheatsheet overlay for Hyprland.
// Card-grid layout grouped by category, keycap-styled keys, and reactive
// arrow indicators (light up + optional sound) on real arrow-key presses.
// Colors pulled live from your Caelestia theme via qs.services Colours.
//
// PLACEMENT: modules/keybinds/KeybindCheatsheet.qml in your live Caelestia
// config. Requires `import qs.services` to resolve, same as your dashboard cards.
//
// TOGGLE: bind = $mainMod, slash, exec, quickshell ipc call keybinds toggle
//
// SOUND: dropped — QtMultimedia isn't installed on this system. Arrow keys
// still light up on press, just silently.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: root

    visible: false
    color: "transparent"
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrLayershell.OnDemand : WlrLayershell.None

    property var binds: []
    property string filterText: ""
    property real animProgress: 0
    property bool arrowSoundsEnabled: true
    property real arrowSoundVolume: 0.70

    // Konami sequence tracking is intentionally kept separate from the
    // eventual Easter egg. While the sequence is in progress, B/A are
    // consumed so they never appear in the search box.
    property var konamiSequence: ["up", "up", "down", "down", "left", "right", "left", "right", "b", "a"]
    property int konamiIndex: 0
    property bool konamiCapture: false

    function konamiInput(key) {
        const expected = konamiSequence[konamiIndex]

        if (key === expected) {
            konamiIndex++
            konamiCapture = konamiIndex > 0

            if (konamiIndex >= konamiSequence.length) {
                // Easter egg intentionally not implemented yet.
                konamiIndex = 0
                konamiCapture = false
            }
            return true
        }

        // Only suppress B/A while we are at the final two stages.
        // Other keys simply cancel the partial sequence.
        if (konamiCapture && (konamiIndex >= 8) && (key === "b" || key === "a")) {
            konamiIndex = 0
            konamiCapture = false
            return true
        }

        konamiIndex = 0
        konamiCapture = false
        return false
    }

    function playArrowSound(dir) {
        if (!arrowSoundsEnabled) return
        if (dir === "up") arrowUpSound.play()
        else if (dir === "down") arrowDownSound.play()
        else if (dir === "left") arrowLeftSound.play()
        else if (dir === "right") arrowRightSound.play()
    }


    property bool leftActive: false
    property bool rightActive: false
    property bool upActive: false
    property bool downActive: false

    readonly property var modNames: ({ 1: "SHIFT", 4: "CTRL", 8: "ALT", 64: "SUPER", 128: "MOD5" })
    readonly property var keyAliases: ({
        "_": "SPACE",
        "SPACE": "SPACE",
        "ESC": "ESC",
        "ESCAPE": "ESC",
        "RETURN": "ENTER",
        "KP_ENTER": "ENTER",
        "ENTER": "ENTER",
        "ALT_L": "ALT",
        "ALT_R": "ALT",
        "CTRL_L": "CTRL",
        "CTRL_R": "CTRL",
        "SHIFT_L": "SHIFT",
        "SHIFT_R": "SHIFT",
        "SUPER_L": "SUPER",
        "SUPER_R": "SUPER",
        "META_L": "SUPER",
        "META_R": "SUPER",
        "CAPS_LOCK": "CAPSLOCK",
        "CAPSLOCK": "CAPSLOCK",
        "NUM_LOCK": "NUMLOCK",
        "NUMLOCK": "NUMLOCK",
        "PAGEUP": "PAGE UP",
        "PAGEDOWN": "PAGE DOWN",
        "PAGE_UP": "PAGE UP",
        "PAGE_DOWN": "PAGE DOWN",
        "PRINT": "PRINT SCREEN",
        "BACKSPACE": "BACKSPACE",
        "TAB": "TAB",
        "DELETE": "DELETE",
        "INSERT": "INSERT",
        "HOME": "HOME",
        "END": "END",
        "MOUSE_DOWN": "MOUSE ↓",
        "MOUSE_UP": "MOUSE ↑",
        "MOUSE_LEFT": "MOUSE ←",
        "MOUSE_RIGHT": "MOUSE →",
        "MOUSE:272": "MOUSE LEFT",
        "MOUSE:273": "MOUSE RIGHT",
        "MOUSE:274": "MOUSE MIDDLE",
        "MOUSE:275": "MOUSE BACK",
        "MOUSE:276": "MOUSE FORWARD",
        "XF86MONBRIGHTNESSUP": "BRIGHTNESS +",
        "XF86MONBRIGHTNESSDOWN": "BRIGHTNESS −",
        "XF86AUDIOPLAY": "PLAY / PAUSE",
        "XF86AUDIOPAUSE": "PLAY / PAUSE",
        "XF86AUDIONEXT": "NEXT TRACK",
        "XF86AUDIOPREV": "PREVIOUS TRACK",
        "XF86AUDIOSTOP": "STOP",
        "XF86AUDIOMUTE": "MUTE",
        "XF86AUDIORAISEVOLUME": "VOLUME +",
        "XF86AUDIOLOWERVOLUME": "VOLUME −",
        "XF86AUDIOMICMUTE": "MIC MUTE"
    })

    // These are physical lock-key binds that are useful to Hyprland but noisy
    // in a user-facing cheatsheet. Keep the actual binds untouched.
    readonly property var hiddenKeys: ["CAPS_LOCK", "CAPSLOCK", "NUM_LOCK", "NUMLOCK"]
    readonly property var arrowGlyphs: ({ up: "↑", down: "↓", left: "←", right: "→" })
    readonly property var categoryOrder: ["Shell", "Workspaces", "Windows", "Apps", "Media & Audio", "Utilities", "System", "Other"]

    function normalizeKey(key) {
        let upper = (key || "").toUpperCase().trim()
        upper = upper.replace(/\\s+/g, "_")

        // Hyprland can expose wheel buttons as mouse_down / mouse_up.
        if (upper === "MOUSE:274" || upper === "MOUSE_DOWN") return "MOUSE ↓"
        if (upper === "MOUSE:275" || upper === "MOUSE_UP") return "MOUSE ↑"
        if (upper === "MOUSE:272") return "MOUSE LEFT"
        if (upper === "MOUSE:273") return "MOUSE RIGHT"
        if (upper === "MOUSE:276") return "MOUSE BACK"
        if (upper === "MOUSE:277") return "MOUSE FORWARD"

        return keyAliases[upper] || upper
    }

    function keyParts(b) {
        let parts = []

        // The modmask is the authoritative modifier information. Hyprland can
        // also return the physical modifier key in b.key (ALT_L, SUPER_L, ...).
        // Do not render that physical key a second time.
        for (const bit of [64, 4, 8, 1, 128]) {
            if (b.modmask & bit) parts.push(modNames[bit])
        }

        if (b.key && b.key.length) {
            const normalized = normalizeKey(b.key)
            const lower = normalized.toLowerCase()

            if (parts.indexOf(normalized) === -1)
                parts.push(arrowGlyphs[lower] || normalized)
        }

        return parts
    }

    function shouldHide(b) {
        const key = (b.key || "").toUpperCase()
        return hiddenKeys.indexOf(key) !== -1
    }

    function visibleBindCount() {
        return root.binds.filter(b => !root.shouldHide(b)).length
    }

    function labelOf(b) {
        const desc = b.description || ""
        const sep = desc.indexOf(" | ")
        if (sep > 0) return desc.substring(sep + 3)
        if (desc.length) return desc
        return b.dispatcher + " " + b.arg
    }

    function categorize(b) {
        const desc = b.description || ""
        const sep = desc.indexOf(" | ")
        if (sep > 0) return desc.substring(0, sep)

        const d = (b.dispatcher || "").toLowerCase()
        const a = (b.arg || "").toLowerCase()

        if (d.indexOf("workspace") !== -1) return "Workspaces"
        if (["killactive", "togglefloating", "fullscreen", "pseudo", "togglesplit",
             "movewindow", "resizeactive", "movefocus", "cyclenext", "swapwindow",
             "pin", "centerwindow", "togglegroup", "changegroupactive"].indexOf(d) !== -1)
            return "Window Management"
        if (d === "exec") {
            if (/grim|slurp|grimblast|screenshot/.test(a)) return "Screenshots"
            if (/playerctl|wpctl|pactl|brightnessctl|pamixer/.test(a)) return "Media & System"
            return "Launch Apps"
        }
        if (["exit", "reload", "reloadconfig"].indexOf(d) !== -1) return "System"
        return "Other"
    }

    function bindsInCategory(cat) {
        return root.binds.filter(b => {
            if (root.shouldHide(b)) return false
            if (root.categorize(b) !== cat) return false
            if (!root.filterText.length) return true
            const hay = (b.key + " " + b.dispatcher + " " + b.arg + " " + (b.description || "")).toLowerCase()
            return hay.includes(root.filterText)
        })
    }

    // Collapse binds that perform the same action into one card. This keeps
    // hardware-key aliases such as Play/Pause from creating duplicate cards.
    function groupedBindsInCategory(cat) {
        const source = root.bindsInCategory(cat)
        const groups = []
        const byAction = new Map()

        for (const b of source) {
            const id = (b.description || root.labelOf(b)) + "\u0000" + (b.dispatcher || "") + "\u0000" + (b.arg || "")
            let group = byAction.get(id)
            if (!group) {
                group = {
                    source: b,
                    binds: []
                }
                byAction.set(id, group)
                groups.push(group)
            }
            if (b.key && group.binds.indexOf(b) === -1)
                group.binds.push(b)
        }

        return groups
    }

    function groupKeyParts(group) {
        const parts = []
        for (const bind of group.binds) {
            const current = root.keyParts(bind)
            for (const part of current) {
                if (parts.indexOf(part) === -1) parts.push(part)
            }
        }
        return parts
    }

    readonly property var categories: {
        let present = new Set(root.binds.filter(b => !root.shouldHide(b)).map(b => root.categorize(b)))
        const known = root.categoryOrder.filter(c => present.has(c))
        const extra = Array.from(present).filter(c => root.categoryOrder.indexOf(c) === -1).sort()
        return known.concat(extra)
    }

    readonly property var visibleCategories: categories.filter(c => bindsInCategory(c).length > 0)

    readonly property var searchMatches: filterText.length ? binds.filter(b => {
        if (root.shouldHide(b)) return false
        const hay = (b.key + " " + b.dispatcher + " " + b.arg + " " + (b.description || "")).toLowerCase()
        return hay.includes(filterText)
    }) : []

    function refresh() { bindsProc.running = true }

    function flash(dir) {
        playArrowSound(dir)
        if (dir === "left") { leftActive = true; leftTimer.restart() }
        else if (dir === "right") { rightActive = true; rightTimer.restart() }
        else if (dir === "up") { upActive = true; upTimer.restart() }
        else if (dir === "down") { downActive = true; downTimer.restart() }
    }

    SoundEffect {
        id: arrowUpSound
        source: Qt.resolvedUrl("sounds/arrow_up.wav")
        volume: root.arrowSoundVolume
    }

    SoundEffect {
        id: arrowDownSound
        source: Qt.resolvedUrl("sounds/arrow_down.wav")
        volume: root.arrowSoundVolume
    }

    SoundEffect {
        id: arrowLeftSound
        source: Qt.resolvedUrl("sounds/arrow_left.wav")
        volume: root.arrowSoundVolume
    }

    SoundEffect {
        id: arrowRightSound
        source: Qt.resolvedUrl("sounds/arrow_right.wav")
        volume: root.arrowSoundVolume
    }

    Timer { id: leftTimer; interval: 220; onTriggered: root.leftActive = false }
    Timer { id: rightTimer; interval: 220; onTriggered: root.rightActive = false }
    Timer { id: upTimer; interval: 220; onTriggered: root.upActive = false }
    Timer { id: downTimer; interval: 220; onTriggered: root.downActive = false }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.binds = JSON.parse(text) }
                catch (e) { root.binds = [] }
            }
        }
    }

    IpcHandler {
        target: "keybinds"
        function toggle() {
            if (!root.visible) root.refresh()
            root.visible = !root.visible
        }
        function show() { root.refresh(); root.visible = true }
        function hide() { root.visible = false }
    }

    onVisibleChanged: animProgress = visible ? 1 : 0
    Behavior on animProgress { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: root.animProgress * 0.5
        MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 960)
        height: Math.min(parent.height * 0.82, 720)
        radius: 22
        color: Colours.tPalette.m3surfaceContainer
        border.color: Colours.palette.m3outlineVariant
        border.width: 1
        opacity: root.animProgress
        scale: 0.94 + 0.06 * root.animProgress

        // Receives keys before the TextInput so the eventual Konami code
        // does not pollute the search field with "b" / "a".
        Item {
            id: keyCapture
        Keys.onEscapePressed: { root.visible = false; event.accepted = true }
            anchors.fill: parent
            focus: root.visible
            z: 10

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                const k = event.key

                if (k === Qt.Key_Up) {
                    root.flash("up")
                    root.konamiInput("up")
                    event.accepted = true
                } else if (k === Qt.Key_Down) {
                    root.flash("down")
                    root.konamiInput("down")
                    event.accepted = true
                } else if (k === Qt.Key_Left) {
                    root.flash("left")
                    root.konamiInput("left")
                    event.accepted = true
                } else if (k === Qt.Key_Right) {
                    root.flash("right")
                    root.konamiInput("right")
                    event.accepted = true
                } else if (k === Qt.Key_B && root.konamiCapture && root.konamiIndex >= 8) {
                    root.konamiInput("b")
                    event.accepted = true
                } else if (k === Qt.Key_A && root.konamiCapture && root.konamiIndex >= 9) {
                    root.konamiInput("a")
                    event.accepted = true
                }
            }
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Hyprland keybinds"
                    color: Colours.palette.m3onSurface
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    spacing: 3
                    Repeater {
                        model: ["ALT", "/"]
                        delegate: Rectangle {
                            implicitWidth: t.implicitWidth + 16
                            implicitHeight: 24
                            radius: 6
                            color: Colours.tPalette.m3secondaryContainer
                            Text {
                                id: t
                                anchors.centerIn: parent
                                text: modelData
                                color: Colours.palette.m3onSecondaryContainer
                                font.family: "monospace"
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 8
                    Repeater {
                        model: ["left", "down", "up", "right"]
                        delegate: Rectangle {
                            id: arrowBtn
                            width: 38
                            height: 38
                            radius: 19
                            border.width: 1.5
                            property bool active: modelData === "left" ? root.leftActive
                                                 : modelData === "down" ? root.downActive
                                                 : modelData === "up" ? root.upActive
                                                 : root.rightActive
                            color: active ? Colours.palette.m3primary : Colours.palette.m3primaryContainer
                            opacity: active ? 1.0 : 0.42
                            scale: active ? 1.08 : 1.0
                            border.color: Colours.palette.m3primary
                            Behavior on color { ColorAnimation { duration: 90 } }
                            Behavior on opacity { NumberAnimation { duration: 90 } }
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutBack } }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -5
                                radius: 24
                                color: Colours.palette.m3primary
                                opacity: arrowBtn.active ? 0.16 : 0
                                z: -1
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.arrowGlyphs[modelData]
                                color: arrowBtn.active ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                font.pixelSize: arrowBtn.active ? 19 : 17
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            Text {
                text: root.filterText.length
                      ? (root.searchMatches.length + " matches")
                      : (root.visibleBindCount() + " binds across " + root.categories.length + " categories")
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 13
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 12
                color: Colours.tPalette.m3surfaceContainerHigh
                border.width: search.activeFocus ? 1.5 : 0
                border.color: Colours.palette.m3primary

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: Text.AlignVCenter
                    color: Colours.palette.m3onSurface
                    font.pixelSize: 14
                    focus: root.visible
                    clip: true
                    onTextChanged: root.filterText = text.toLowerCase()
                    Keys.onEscapePressed: root.visible = false
                    // Arrow keys are handled by the parent key-capture item
                    // so they can also participate in the Konami sequence.

                    Text {
                        text: "Filter across all categories…"
                        color: Colours.palette.m3onSurfaceVariant
                        visible: !search.text.length
                        font: search.font
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Flickable {
                id: keybindScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: sectionsCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                maximumFlickVelocity: 9000
                flickDeceleration: 10500

                // Handle the wheel explicitly. Flickable's normal wheel handling
                // is intentionally bypassed so the speed is deterministic.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    z: 100
                    hoverEnabled: true

                    property real wheelMultiplier: 4.0

                    onWheel: event => {
                        let delta = event.angleDelta.y
                        if (delta === 0)
                            delta = event.pixelDelta.y

                        // Mouse wheel: 120 units per notch -> 240 px per notch.
                        // Touchpad: use its pixel delta and amplify it.
                        const amount = event.angleDelta.y !== 0
                                      ? delta * wheelMultiplier / 2.0
                                      : delta * wheelMultiplier

                        const maxY = Math.max(
                            0,
                            keybindScroll.contentHeight - keybindScroll.height
                        )

                        keybindScroll.contentY = Math.max(
                            0,
                            Math.min(maxY, keybindScroll.contentY - amount)
                        )

                        event.accepted = true
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 3; color: Colours.palette.m3outline }
                }

                ColumnLayout {
                    id: sectionsCol
                    width: parent.width
                    spacing: 18

                    Repeater {
                        model: root.visibleCategories
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            property string cat: modelData
                            property var catBinds: root.groupedBindsInCategory(cat)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: cat
                                    color: Colours.palette.m3onSurface
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.18)
                                    border.width: 1
                                    border.color: Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.28)
                                    opacity: 0.62

                                    Text {
                                        anchors.centerIn: parent
                                        text: catBinds.length
                                        color: Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.62)
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 10

                                Repeater {
                                    model: catBinds
                                    delegate: Rectangle {
                                        width: 220
                                        implicitHeight: cardCol.implicitHeight + 24
                                        radius: 12
                                        color: Colours.tPalette.m3surfaceContainerHigh

                                        ColumnLayout {
                                            id: cardCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 8

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.labelOf(modelData.source)
                                                color: Colours.palette.m3onSurface
                                                font.pixelSize: 13
                                                wrapMode: Text.WordWrap
                                            }

                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 4

                                                Repeater {
                                                    model: root.groupKeyParts(modelData)
                                                    delegate: Rectangle {
                                                        implicitWidth: Math.max(26, kText.implicitWidth + 16)
                                                        implicitHeight: 26
                                                        radius: 6
                                                        color: Colours.tPalette.m3secondaryContainer
                                                        Text {
                                                            id: kText
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            color: Colours.palette.m3onSecondaryContainer
                                                            font.family: "monospace"
                                                            font.pixelSize: 11
                                                            font.weight: Font.Medium
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
