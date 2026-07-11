/*
 * CraftParking update panel backend.
 *
 * Checks a small latest.json manifest (committed straight to the
 * ubuntu-touch-sweetin repo, fetched via raw.githubusercontent.com) for a
 * newer build than /etc/craftparking-version. The manifest just points at
 * wherever the actual zip is hosted - GitHub Releases caps a single asset
 * at 2GB, too easy to blow past as this ROM grows, so the zip itself lives
 * on SourceForge instead. Downloads with on-the-fly sha256 verification,
 * then hands the verified file off to the CraftparkingApplyUpdate D-Bus
 * method (added to system-image-dbus) which moves it into TWRP's
 * recognized storage and reboots to flash it.
 */

#ifndef CRAFTPARKING_UPDATE_H
#define CRAFTPARKING_UPDATE_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QCryptographicHash>
#include <QFile>

class Update : public QObject
{
    Q_OBJECT

public:
    explicit Update(QObject *parent = 0);
    ~Update();

    Q_INVOKABLE QString currentVersion() const;
    Q_INVOKABLE void checkForUpdate();
    Q_INVOKABLE void downloadUpdate(const QString &zipUrl, const QString &expectedSha256);
    Q_INVOKABLE void cancelDownload();
    Q_INVOKABLE bool applyUpdate();

Q_SIGNALS:
    void checkFinished(bool available, const QString &latestVersion,
                        const QString &zipUrl, const QString &sha256,
                        qlonglong sizeBytes, const QString &error);
    void downloadProgress(int percent);
    void downloadFinished(bool success, const QString &error);

private Q_SLOTS:
    void onManifestReply();
    void onDownloadReadyRead();
    void onDownloadProgressChanged(qint64 received, qint64 total);
    void onDownloadReply();

private:
    QNetworkAccessManager m_nam;
    QNetworkReply *m_checkReply = nullptr;
    QNetworkReply *m_downloadReply = nullptr;

    QFile m_downloadFile;
    QCryptographicHash m_downloadHash;
    QString m_expectedSha256;

    static QString downloadPath();
};

#endif // CRAFTPARKING_UPDATE_H
