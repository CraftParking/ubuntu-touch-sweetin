import QtQuick 2.12
import SystemSettings 1.0
import SystemSettings.ListItems 1.0 as SettingsListItems
import Ubuntu.Components.ListItems 1.3 as ListItem
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import Craftparking.SystemSettings.Update 1.0

ItemPage {
    id: root

    title: i18n.tr("Software Update")
    objectName: "craftparkingUpdatePage"
    flickable: scrollWidget

    property bool checking: false
    property bool updateAvailable: false
    property bool downloading: false
    property bool readyToInstall: false
    property int progressValue: 0
    property string statusText: i18n.tr("Installed version: %1").arg(backend.currentVersion())
    property string pendingVersion: ""
    property string pendingZipUrl: ""
    property string pendingSha256: ""
    property real pendingSize: 0

    function humanSize(bytes) {
        if (bytes <= 0)
            return ""
        var mb = bytes / (1024 * 1024)
        if (mb < 1024)
            return mb.toFixed(0) + " MB"
        return (mb / 1024).toFixed(2) + " GB"
    }

    CraftparkingUpdatePanel {
        id: backend

        onCheckFinished: {
            root.checking = false
            if (error !== "") {
                root.statusText = i18n.tr("Check failed: %1").arg(error)
                return
            }
            if (!available) {
                root.updateAvailable = false
                root.statusText = i18n.tr("You're up to date (%1)").arg(backend.currentVersion())
                return
            }
            root.updateAvailable = true
            root.pendingVersion = latestVersion
            root.pendingZipUrl = zipUrl
            root.pendingSha256 = sha256
            root.pendingSize = sizeBytes
            root.statusText = i18n.tr("Update available: %1").arg(latestVersion)
        }

        onDownloadProgress: root.progressValue = percent

        onDownloadFinished: {
            root.downloading = false
            if (success) {
                root.readyToInstall = true
                root.statusText = i18n.tr("Downloaded %1, ready to install").arg(root.pendingVersion)
            } else {
                root.readyToInstall = false
                root.statusText = i18n.tr("Download failed: %1").arg(error)
            }
        }
    }

    Component {
        id: confirmInstallDialog
        Dialog {
            id: dialog
            title: i18n.tr("Install update?")
            text: i18n.tr("The phone will reboot now and flash %1. Don't unplug power or remove the SIM/SD card until it finishes.").arg(root.pendingVersion)
            Button {
                text: i18n.tr("Install & Reboot")
                objectName: "craftparkingInstallAction"
                color: theme.palette.normal.negative
                onClicked: {
                    PopupUtils.close(dialog)
                    backend.applyUpdate()
                }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Flickable {
        id: scrollWidget
        anchors.fill: parent
        contentHeight: contentItem.childrenRect.height
        boundsBehavior: (contentHeight > root.height) ? Flickable.DragAndOvershootBounds : Flickable.StopAtBounds

        Column {
            anchors.left: parent.left
            anchors.right: parent.right

            ListItem.Caption {
                text: root.statusText
            }

            ActivityIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: root.checking || root.downloading
                visible: running
            }

            ProgressBar {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: units.gu(2)
                visible: root.downloading
                minimumValue: 0
                maximumValue: 100
                value: root.progressValue
            }

            SettingsListItems.StandardProgression {
                showDivider: false
                objectName: "craftparkingCheckForUpdates"
                text: i18n.tr("Check for Updates")
                enabled: !root.checking && !root.downloading
                onClicked: {
                    root.checking = true
                    root.updateAvailable = false
                    root.readyToInstall = false
                    root.statusText = i18n.tr("Checking...")
                    backend.checkForUpdate()
                }
            }

            SettingsListItems.StandardProgression {
                showDivider: false
                objectName: "craftparkingDownloadUpdate"
                visible: root.updateAvailable && !root.downloading && !root.readyToInstall
                text: root.pendingSize > 0
                      ? i18n.tr("Download Update (%1)").arg(root.humanSize(root.pendingSize))
                      : i18n.tr("Download Update")
                onClicked: {
                    root.downloading = true
                    root.progressValue = 0
                    root.statusText = i18n.tr("Downloading...")
                    backend.downloadUpdate(root.pendingZipUrl, root.pendingSha256)
                }
            }

            SettingsListItems.StandardProgression {
                showDivider: false
                objectName: "craftparkingInstallUpdate"
                visible: root.readyToInstall
                text: i18n.tr("Install & Reboot")
                onClicked: PopupUtils.open(confirmInstallDialog)
            }

            ListItem.Caption {
                visible: root.readyToInstall
                text: i18n.tr("The device will reboot into recovery and flash the update automatically. This can take several minutes.")
            }
        }
    }
}
