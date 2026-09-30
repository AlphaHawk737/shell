import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    anchors.fill: parent
    color: "#111318"
    focus: true

    property int userIndex: 0
    property int sessionIndex: 0
    property bool loggingIn: false

    Component.onCompleted: {
        if (typeof userModel !== "undefined" && userModel.lastIndex >= 0)
            userIndex = userModel.lastIndex
        if (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
            sessionIndex = sessionModel.lastIndex
        password.forceActiveFocus()
    }

    function currentUser() {
        if (typeof userModel === "undefined" || userModel.count === 0)
            return sddm.lastUser || "User"
        var idx = Math.max(0, Math.min(userIndex, userModel.count - 1))
        var value = userModel.data(userModel.index(idx, 0), Qt.EditRole)
        return value ? value.toString() : (sddm.lastUser || "User")
    }

    function login() {
        if (loggingIn || password.text.length === 0)
            return
        loggingIn = true
        sddm.login(currentUser(), password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            loggingIn = false
            password.clear()
            password.forceActiveFocus()
            errorAnim.restart()
        }
        function onLoginSucceeded() {
            loggingIn = false
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: "#15171d"
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.38
    }

    Column {
        id: centerColumn
        anchors.centerIn: parent
        spacing: 22
        opacity: 0
        scale: 0.96

        Behavior on opacity {
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 650; easing.type: Easing.OutCubic }
        }

        Component.onCompleted: {
            opacity = 1
            scale = 1
        }

        Text {
            width: 420
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatTime(new Date(), "hh:mm")
            color: "#f2f2f2"
            font.pixelSize: 72
            font.weight: Font.Light
        }

        Text {
            width: 420
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(new Date(), "dddd, dd MMMM")
            color: "#b9bbc2"
            font.pixelSize: 18
        }

        Rectangle {
            width: 420
            height: 330
            radius: 28
            color: "#24272e"
            opacity: 0.94

            Column {
                anchors.centerIn: parent
                spacing: 18

                Rectangle {
                    width: 88
                    height: 88
                    radius: 44
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#3a3e48"

                    Text {
                        anchors.centerIn: parent
                        text: String(root.currentUser()).charAt(0).toUpperCase()
                        color: "#f2f2f2"
                        font.pixelSize: 38
                    }
                }

                Text {
                    width: 340
                    horizontalAlignment: Text.AlignHCenter
                    text: root.currentUser()
                    color: "#f2f2f2"
                    font.pixelSize: 21
                }

                TextField {
                    id: password
                    width: 320
                    height: 54
                    placeholderText: "Password"
                    echoMode: TextInput.Password
                    color: "#f2f2f2"
                    placeholderTextColor: "#8d9099"
                    horizontalAlignment: Text.AlignLeft
                    leftPadding: 18
                    rightPadding: 18
                    font.pixelSize: 16

                    background: Rectangle {
                        radius: 17
                        color: "#30343d"
                        border.width: password.activeFocus ? 2 : 1
                        border.color: password.activeFocus ? "#c7d5ff" : "#464b56"
                    }

                    Keys.onReturnPressed: root.login()
                }

                Rectangle {
                    width: 320
                    height: 52
                    radius: 17
                    color: loggingIn ? "#4b4f59" : "#c7d5ff"

                    Text {
                        anchors.centerIn: parent
                        text: loggingIn ? "Logging in..." : "Log in"
                        color: "#111318"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.loggingIn
                        onClicked: root.login()
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Repeater {
                model: [
                    { icon: "⏻", action: function() { sddm.powerOff() } },
                    { icon: "↻", action: function() { sddm.reboot() } }
                ]

                delegate: Rectangle {
                    width: 52
                    height: 52
                    radius: 26
                    color: "#24272e"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: "#dfe1e7"
                        font.pixelSize: 20
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: index === 0 ? sddm.powerOff() : sddm.reboot()
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: errorAnim
        PropertyAnimation { target: centerColumn; property: "x"; from: centerColumn.x; to: centerColumn.x - 10; duration: 60 }
        PropertyAnimation { target: centerColumn; property: "x"; from: centerColumn.x - 10; to: centerColumn.x + 10; duration: 60 }
        PropertyAnimation { target: centerColumn; property: "x"; from: centerColumn.x + 10; to: centerColumn.x; duration: 60 }
    }
}
