/*
 * CraftParking update panel backend.
 *
 * Checks a small latest.json manifest (committed straight to the
 * ubuntu-touch-sweetin repo, fetched via raw.githubusercontent.com) for a
 * newer build than /etc/craftparking-version - this part is a quick
 * one-shot fetch, done directly here.
 *
 * The actual download is NOT done here. It runs inside system-image-dbus
 * (root, bus-activated, persistent) via CraftparkingStartDownload - this
 * QML page's own object gets destroyed on back-navigation, and the whole
 * system-settings process gets its networking throttled when backgrounded,
 * either of which would kill an in-process download. This class is just a
 * thin D-Bus proxy: start/cancel the download, listen for its progress and
 * completion signals, and query current status on (re)open to resync with
 * a download that's still running from a previous visit to this page.
 */

#ifndef CRAFTPARKING_UPDATE_H
#define CRAFTPARKING_UPDATE_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>

class Update : public QObject
{
    Q_OBJECT

public:
    explicit Update(QObject *parent = 0);
    ~Update();

    Q_INVOKABLE QString currentVersion() const;
    Q_INVOKABLE void checkForUpdate();
    Q_INVOKABLE void downloadUpdate(const QString &zipUrl, const QString &expectedSha256,
                                     qlonglong expectedSize);
    Q_INVOKABLE void cancelDownload();
    Q_INVOKABLE void queryDownloadStatus();
    Q_INVOKABLE bool applyUpdate();

Q_SIGNALS:
    void checkFinished(bool available, const QString &latestVersion,
                        const QString &zipUrl, const QString &sha256,
                        qlonglong sizeBytes, const QString &error);
    void downloadProgress(qlonglong received, qlonglong total);
    void downloadFinished(bool success, const QString &error);
    void downloadStatus(bool inProgress, qlonglong received, qlonglong total);

private Q_SLOTS:
    void onManifestReply();
    void onDBusDownloadProgress(qlonglong received, qlonglong total);
    void onDBusDownloadFinished(bool success, const QString &error);

private:
    QNetworkAccessManager m_nam;
    QNetworkReply *m_checkReply = nullptr;
};

#endif // CRAFTPARKING_UPDATE_H
