import QtQuick 2.12
import Ubuntu.Components 1.3

Rectangle {
    id: root
    anchors.fill: parent
    color: "black"

    property string iconSource: ""
    property string iconFallback: ""
    property string message: ""
    property string subMessage: ""

    signal countdownFinished()

    Column {
        anchors.centerIn: parent
        spacing: units.gu(3)
        width: parent.width * 0.8

        Image {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(10)
            height: width
            fillMode: Image.PreserveAspectFit
            source: root.iconSource
            onStatusChanged: {
                if (status === Image.Error && source != root.iconFallback) {
                    source = root.iconFallback;
                }
            }
        }

        ActivityIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "white"
            font.pixelSize: units.gu(3)
            font.bold: true
            text: root.message
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "white"
            font.pixelSize: units.gu(2)
            text: root.subMessage
        }
    }

    // fires shutdown/reboot almost immediately, just enough delay to paint this screen first
    Timer {
        interval: 300
        running: true
        onTriggered: root.countdownFinished()
    }
}
