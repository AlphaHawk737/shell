pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.containers
import qs.services
import qs.utils

Item {
    id: root

    required property var loader
    required property ShellScreen screen

    // Independent of the Wallpapers service, which is deliberately narrowed
    // to a single folder via shell.json's paths.wallpaperDir override. We
    // want every category folder, so scan the real root directly.
    readonly property string wallsRoot: Quickshell.env("CAELESTIA_WALLPAPERS_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers")

    // Groups scanned image entries by their top-level folder, picking one
    // representative image per folder. Recomputes only when the scan changes.
    readonly property var folders: {
        const groups = {};
        for (const w of scanner.entries) {
            const slash = w.relativePath.indexOf("/");
            if (slash === -1)
                continue; // skip loose files directly in the root
            const cat = w.relativePath.slice(0, slash);
            if (!groups[cat])
                groups[cat] = [];
            groups[cat].push(w);
        }
        return Object.keys(groups).sort().map(name => {
            const entries = groups[name];
            return {
                name: name,
                preview: entries[Math.floor(Math.random() * entries.length)].path
            };
        });
    }

    FileSystemModel {
        id: scanner

        path: root.wallsRoot
        recursive: true
        filter: FileSystemModel.Images
    }

    // Closing doesn't destroy immediately - it plays the exit animation
    // first (closeAnim), which only then sets loader.active = false.
    function closeSelf(): void {
        closeAnim.start();
    }

    function selectFolder(name: string): void {
        GlobalConfig.paths.wallpaperDir = `${root.wallsRoot}/${name}`;

        const screenState = ShellState.forScreen(root.screen);
        if (screenState)
            screenState.launcher = true;

        const components = ShellState.componentsFor(root.screen);
        // The SearchBar may not exist yet the instant the launcher opens,
        // so give it a tick before trying to find and fill it. Closing must
        // wait until AFTER this fires, or the timer gets destroyed with the
        // rest of this component before it ever runs. No filter text needed
        // now - wallpaperDir is already scoped to just this folder, so a
        // bare wallpaper-mode prefix shows everything in it.
        prefillTimer.targetText = `${GlobalConfig.launcher.actionPrefix}wallpaper `;
        prefillTimer.components = components;
        prefillTimer.start();
    }

    Timer {
        id: prefillTimer

        property var components
        property string targetText

        interval: 150
        onTriggered: {
            const bar = components?.find("launcherSearch");
            if (bar)
                bar.text = targetText;
            root.closeSelf();
        }
    }

    anchors.fill: parent
    focus: true

    Keys.onEscapePressed: root.closeSelf()

    Component.onCompleted: {
        list.forceActiveFocus();
        openAnim.start();
    }

    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            target: backdrop
            property: "opacity"
            to: 0.5
            duration: 250
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "opacity"
            to: 1
            duration: 250
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            to: 1
            duration: 250
            easing.type: Easing.OutBack
        }
    }

    ParallelAnimation {
        id: closeAnim

        NumberAnimation {
            target: backdrop
            property: "opacity"
            to: 0
            duration: 120
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "opacity"
            to: 0
            duration: 120
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            to: 0.9
            duration: 120
            easing.type: Easing.InCubic
        }

        onStopped: root.loader.active = false
    }

    // Dim backdrop, click outside to close
    Rectangle {
        id: backdrop

        anchors.fill: parent
        opacity: 0
        color: Colours.palette.m3shadow

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeSelf()
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: 460
        height: Math.min(root.screen.height * 0.8, header.implicitHeight + list.contentHeight + Tokens.padding.large * 3)
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer
        border.width: 2
        border.color: Colours.palette.m3primary
        clip: true
        opacity: 0
        scale: 0.9

        MouseArea {
            // Swallow clicks so the backdrop MouseArea behind doesn't close the panel
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: content

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.large

            Column {
                id: header

                width: parent.width
                spacing: Tokens.spacing.small

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Wallpaper Folder")
                    font: Tokens.font.title.large
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: list.currentItem && list.currentItem.folderName.length ? list.currentItem.folderName[0].toUpperCase() + list.currentItem.folderName.slice(1) : ""
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3primary
                }
            }

            ListView {
                id: list

                width: parent.width
                height: parent.height - header.height - parent.spacing
                clip: true
                spacing: Tokens.spacing.small
                keyNavigationEnabled: true
                keyNavigationWraps: true
                highlightMoveDuration: 120
                highlightFollowsCurrentItem: true
                focus: true
                currentIndex: 0

                model: root.folders

                highlight: Rectangle {
                    radius: Tokens.rounding.medium
                    color: Colours.palette.m3secondaryContainer
                }

                delegate: FolderItem {
                    required property var modelData
                    required property int index

                    width: list.width
                    folderName: modelData.name
                    previewPath: modelData.preview
                    isCurrent: ListView.isCurrentItem

                    onActivated: root.selectFolder(modelData.name)
                    onClicked: {
                        list.currentIndex = index;
                        root.selectFolder(modelData.name);
                    }
                }

                Keys.onReturnPressed: {
                    if (currentItem)
                        root.selectFolder(currentItem.folderName);
                }
                Keys.onEnterPressed: {
                    if (currentItem)
                        root.selectFolder(currentItem.folderName);
                }
                Keys.onEscapePressed: root.closeSelf()
            }
        }
    }
}
