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

    // The download runs inside system-image-dbus, not this page - it keeps
    // going whether or not this page (or Settings itself) is even open.
    // Resync with whatever it's actually doing every time this page loads,
    // instead of assuming a blank/idle state.
    Component.onCompleted: backend.queryDownloadStatus()

    property bool checking: false
    property bool updateAvailable: false
    property bool downloading: false
    property bool readyToInstall: false
    property real receivedBytes: 0
    property real totalBytes: 0
    property real downloadSpeed: 0  // bytes/sec, smoothed
    property real lastProgressBytes: 0
    property real lastProgressTime: 0
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

    function humanSpeed(bytesPerSec) {
        if (bytesPerSec <= 0)
            return ""
        return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
    }

    function humanEta(seconds) {
        if (!isFinite(seconds) || seconds <= 0)
            return ""
        if (seconds < 60)
            return Math.ceil(seconds) + "s"
        var m = Math.floor(seconds / 60)
        if (m < 60)
            return m + "m " + Math.ceil(seconds % 60) + "s"
        return Math.floor(m / 60) + "h " + (m % 60) + "m"
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

        onDownloadProgress: {
            var now = Date.now()
            var dt = (now - root.lastProgressTime) / 1000
            if (root.lastProgressTime > 0 && dt > 0.2) {
                var instSpeed = (received - root.lastProgressBytes) / dt
                root.downloadSpeed = root.downloadSpeed > 0
                    ? (root.downloadSpeed * 0.7 + instSpeed * 0.3)
                    : instSpeed
                root.lastProgressBytes = received
                root.lastProgressTime = now
            } else if (root.lastProgressTime === 0) {
                root.lastProgressBytes = received
                root.lastProgressTime = now
            }
            root.receivedBytes = received
            root.totalBytes = total
        }

        onDownloadFinished: {
            root.downloading = false
            if (success) {
                root.readyToInstall = true
                root.statusText = i18n.tr("Downloaded %1, ready to install").arg(root.pendingVersion)
            } else if (error === "cancelled") {
                root.statusText = i18n.tr("Download cancelled")
            } else {
                root.readyToInstall = false
                root.statusText = i18n.tr("Download failed: %1").arg(error)
            }
        }

        onDownloadStatus: {
            if (!inProgress)
                return
            // A download from a previous visit to this page is still
            // running in the background service - pick up its progress
            // instead of showing a blank/idle UI.
            root.downloading = true
            root.receivedBytes = received
            root.totalBytes = total
            root.downloadSpeed = 0
            root.lastProgressBytes = received
            root.lastProgressTime = Date.now()
            root.statusText = i18n.tr("Downloading...")
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
                running: root.checking
                visible: running
            }

            ProgressBar {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: units.gu(2)
                visible: root.downloading
                minimumValue: 0
                maximumValue: root.totalBytes > 0 ? root.totalBytes : 1
                value: root.receivedBytes
                indeterminate: root.totalBytes <= 0
            }

            ListItem.Caption {
                visible: root.downloading
                text: {
                    var parts = []
                    parts.push(root.totalBytes > 0
                        ? i18n.tr("%1 of %2").arg(root.humanSize(root.receivedBytes)).arg(root.humanSize(root.totalBytes))
                        : root.humanSize(root.receivedBytes))
                    if (root.downloadSpeed > 0)
                        parts.push(root.humanSpeed(root.downloadSpeed))
                    if (root.totalBytes > 0 && root.downloadSpeed > 0) {
                        var eta = (root.totalBytes - root.receivedBytes) / root.downloadSpeed
                        parts.push(i18n.tr("%1 left").arg(root.humanEta(eta)))
                    }
                    return parts.join(" • ")
                }
            }

            SettingsListItems.StandardProgression {
                showDivider: false
                objectName: "craftparkingCancelDownload"
                visible: root.downloading
                text: i18n.tr("Cancel")
                onClicked: {
                    backend.cancelDownload()
                    root.downloading = false
                }
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
                    root.receivedBytes = 0
                    root.totalBytes = root.pendingSize
                    root.downloadSpeed = 0
                    root.lastProgressBytes = 0
                    root.lastProgressTime = 0
                    root.statusText = i18n.tr("Downloading...")
                    backend.downloadUpdate(root.pendingZipUrl, root.pendingSha256, root.pendingSize)
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
