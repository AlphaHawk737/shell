import QtQuick
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.components.images
import qs.services

Item {
    id: root

    required property string folderName
    required property string previewPath
    required property bool isCurrent

    signal activated
    signal clicked

    implicitHeight: 64

    Keys.onReturnPressed: root.activated()
    Keys.onEnterPressed: root.activated()

    StateLayer {
        anchors.fill: parent
        radius: Tokens.rounding.medium
        onClicked: root.clicked()
    }

    Row {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        spacing: Tokens.spacing.medium

        StyledClippingRect {
            id: thumb

            anchors.verticalCenter: parent.verticalCenter
            color: Colours.tPalette.m3surfaceContainerHigh
            radius: Tokens.rounding.medium

            implicitWidth: parent.height - Tokens.padding.small * 2
            implicitHeight: implicitWidth

            CachingImage {
                id: img

                anchors.fill: parent
                path: root.previewPath
                sourceSize: Qt.size(thumb.implicitWidth * 2, thumb.implicitHeight * 2)
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            Elevation {
                anchors.fill: parent
                radius: Tokens.rounding.medium
                opacity: root.isCurrent ? 1 : 0
                level: 3

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.folderName.length ? root.folderName[0].toUpperCase() + root.folderName.slice(1) : root.folderName
            font: Tokens.font.body.large
            color: root.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        }
    }
}
