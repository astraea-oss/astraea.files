import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#090105"

    property string timeText: ""
    property string dateText: ""
    property color textPrimary: "#fff1f7"
    property color textMuted: "#d48ca2"
    property color accentPink: "#ff3f9e"
    property color accentSoft: "#d48ca2"
    property string displayFont: icelandFont.name ? icelandFont.name : "Iceland"
    property string uiFont: "Noto Sans"
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string loginUser: userModel.lastUser ? userModel.lastUser : "tera"

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    TextConstants { id: textConstants }

    FontLoader {
        id: icelandFont
        source: Qt.resolvedUrl("fonts/Iceland-Regular.ttf")
    }

    function refreshClock() {
        var now = new Date()
        timeText = Qt.formatDateTime(now, "HH:mm")
        dateText = Qt.formatDateTime(now, "dddd") + "  " + Qt.formatDateTime(now, "MMMM d")
    }

    function tryLogin() {
        messageText.text = ""
        sddm.login(loginUser, password.text, sessionIndex)
    }

    Component.onCompleted: {
        refreshClock()
        password.forceActiveFocus()
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            messageText.color = accentSoft
            messageText.text = textConstants.loginSucceeded
        }

        function onLoginFailed() {
            password.text = ""
            password.forceActiveFocus()
            messageText.color = "#ff6b8f"
            messageText.text = textConstants.loginFailed
        }

        function onInformationMessage(message) {
            messageText.color = "#ffb8cf"
            messageText.text = message
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: refreshClock()
    }

    Image {
        id: background
        anchors.fill: parent
        source: Qt.resolvedUrl(config.background || "background.jpg")
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#66000000"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#bb050005" }
            GradientStop { position: 0.34; color: "#44050005" }
            GradientStop { position: 0.70; color: "#55050005" }
            GradientStop { position: 1.00; color: "#dd050005" }
        }
    }

    Column {
        id: clockBlock
        anchors.left: parent.left
        anchors.leftMargin: Math.max(36, parent.width * 0.055)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(46, parent.height * 0.085)
        spacing: 2

        Text {
            text: root.timeText
            color: root.textPrimary
            font.family: root.displayFont
            font.pixelSize: Math.max(86, Math.min(138, root.width * 0.078))
        }

        Text {
            text: root.dateText
            color: root.textMuted
            font.family: root.displayFont
            font.pixelSize: Math.max(24, Math.min(38, root.width * 0.021))
        }

        Rectangle {
            width: Math.max(170, clockBlock.width * 0.72)
            height: 2
            color: root.accentPink
            opacity: 0.8
        }
    }

    Item {
        id: loginArea
        width: Math.min(260, root.width - 48)
        height: loginColumn.implicitHeight
        anchors.right: parent.right
        anchors.rightMargin: root.width < 900 ? 28 : Math.max(96, root.width * 0.095)
        anchors.verticalCenter: parent.verticalCenter

        Column {
            id: loginColumn
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 16

            Text {
                width: parent.width
                text: root.loginUser
                color: root.textPrimary
                font.family: root.displayFont
                font.pixelSize: 42
                elide: Text.ElideRight
            }

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "Password"
                    color: root.textMuted
                    font.family: root.uiFont
                    font.pixelSize: 12
                    opacity: 0.86
                }

                Rectangle {
                    width: parent.width
                    height: 38
                    color: "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enter password"
                        color: "#88d48ca2"
                        font.family: root.uiFont
                        font.pixelSize: 14
                        visible: password.text.length === 0 && !password.activeFocus
                    }

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.leftMargin: 0
                        anchors.rightMargin: 0
                        color: root.textPrimary
                        selectionColor: root.accentPink
                        selectedTextColor: "#090105"
                        clip: true
                        echoMode: TextInput.Password
                        passwordCharacter: "*"
                        font.family: root.uiFont
                        font.pixelSize: 15
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        KeyNavigation.tab: loginButton

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.tryLogin()
                                event.accepted = true
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: password.activeFocus ? 2 : 1
                        color: password.activeFocus ? "#aaf0a7bf" : "#55d81f53"
                    }
                }
            }

            Text {
                id: messageText
                width: parent.width
                height: 16
                text: ""
                color: "#ffb8cf"
                font.family: root.uiFont
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Item {
                id: loginButton
                width: 120
                height: 34
                KeyNavigation.backtab: password
                KeyNavigation.tab: rebootButton

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: textConstants.login
                    color: loginMouse.containsMouse || loginButton.activeFocus ? root.textPrimary : root.textMuted
                    font.family: root.uiFont
                    font.pixelSize: 14
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: loginMouse.containsMouse || loginButton.activeFocus ? root.accentPink : "#55d81f53"
                }

                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tryLogin()
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.tryLogin()
                        event.accepted = true
                    }
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: root.width < 900 ? 24 : Math.max(64, root.width * 0.07)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(28, root.height * 0.05)
        spacing: 10

        Rectangle {
            id: rebootButton
            width: 92
            height: 36
            radius: 4
            color: rebootMouse.containsMouse || activeFocus ? "#553a0814" : "#33140208"
            border.color: rebootMouse.containsMouse || activeFocus ? root.accentSoft : "#55d81f53"
            border.width: 1
            KeyNavigation.backtab: loginButton
            KeyNavigation.tab: powerButton

            Text {
                anchors.centerIn: parent
                text: "Restart"
                color: root.textPrimary
                font.family: root.uiFont
                font.pixelSize: 12
            }

            MouseArea {
                id: rebootMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.reboot()
            }
        }

        Rectangle {
            id: powerButton
            width: 92
            height: 36
            radius: 4
            color: powerMouse.containsMouse || activeFocus ? "#553a0814" : "#33140208"
            border.color: powerMouse.containsMouse || activeFocus ? root.accentSoft : "#55d81f53"
            border.width: 1
            KeyNavigation.backtab: rebootButton
            KeyNavigation.tab: password

            Text {
                anchors.centerIn: parent
                text: "Power"
                color: root.textPrimary
                font.family: root.uiFont
                font.pixelSize: 12
            }

            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.powerOff()
            }
        }
    }
}
