pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components.containers
import qs.components.misc
import qs.services

Scope {
    LazyLoader {
        id: root

        Variants {
            model: Screens.screens

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "drawers"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                FolderPicker {
                    loader: root
                    screen: win.modelData
                }
            }
        }
    }

    IpcHandler {
        function open(): void {
            root.activeAsync = true;
        }

        function close(): void {
            root.active = false;
        }

        function toggle(): void {
            if (root.active)
                root.active = false;
            else
                root.activeAsync = true;
        }

        target: "wallpaperFolders"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "wallpaperFolders"
        description: "Toggle wallpaper folder picker"
        onPressed: {
            if (root.active)
                root.active = false;
            else
                root.activeAsync = true;
        }
    }
}
