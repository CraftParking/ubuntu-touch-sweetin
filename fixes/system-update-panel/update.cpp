#include "update.h"

#include <QDBusInterface>
#include <QDBusReply>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QDebug>

namespace {
const char *MANIFEST_URL =
    "https://raw.githubusercontent.com/CraftParking/ubuntu-touch-sweetin/master/latest.json";
const char *VERSION_FILE = "/etc/craftparking-version";
}

Update::Update(QObject *parent)
    : QObject(parent)
    , m_downloadHash(QCryptographicHash::Sha256)
{
}

Update::~Update()
{
}

QString Update::downloadPath()
{
    QString dir = QDir::homePath() + "/.cache/craftparking-update";
    QDir().mkpath(dir);
    return dir + "/update.zip";
}

QString Update::currentVersion() const
{
    QFile f(VERSION_FILE);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return QStringLiteral("unknown");
    return QString::fromUtf8(f.readAll()).trimmed();
}

void Update::checkForUpdate()
{
    if (m_checkReply != nullptr)
        return; // already in progress

    QNetworkRequest request{QUrl(QString::fromLatin1(MANIFEST_URL))};
    request.setRawHeader("User-Agent", "craftparking-update-panel");
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    m_checkReply = m_nam.get(request);
    connect(m_checkReply, &QNetworkReply::finished,
            this, &Update::onManifestReply);
}

void Update::onManifestReply()
{
    QNetworkReply *reply = m_checkReply;
    m_checkReply = nullptr;
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        emit checkFinished(false, QString(), QString(), QString(), 0,
                            reply->errorString());
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonObject root = doc.object();
    QString version = root.value("version").toString();
    QString zipUrl = root.value("zip_url").toString();
    QString sha256 = root.value("sha256").toString().toLower();
    qlonglong size = static_cast<qlonglong>(root.value("size").toDouble());

    if (version.isEmpty() || zipUrl.isEmpty() || sha256.isEmpty()) {
        emit checkFinished(false, QString(), QString(), QString(), 0,
                            QStringLiteral("latest.json is missing version/zip_url/sha256"));
        return;
    }

    bool available = (version != currentVersion());
    emit checkFinished(available, version, zipUrl, sha256, size, QString());
}

void Update::downloadUpdate(const QString &zipUrl, const QString &expectedSha256)
{
    if (m_downloadReply != nullptr)
        return; // already in progress

    m_downloadFile.setFileName(downloadPath());
    if (!m_downloadFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        emit downloadFinished(false, QStringLiteral("couldn't open local file for writing"));
        return;
    }
    m_downloadHash.reset();
    m_expectedSha256 = expectedSha256.toLower();

    QNetworkRequest request{QUrl(zipUrl)};
    request.setRawHeader("User-Agent", "craftparking-update-panel");
    // SourceForge (and most non-GitHub hosts we might point at) redirects
    // to whichever mirror is closest - Qt won't follow that automatically.
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    m_downloadReply = m_nam.get(request);
    connect(m_downloadReply, &QNetworkReply::readyRead,
            this, &Update::onDownloadReadyRead);
    connect(m_downloadReply, &QNetworkReply::downloadProgress,
            this, &Update::onDownloadProgressChanged);
    connect(m_downloadReply, &QNetworkReply::finished,
            this, &Update::onDownloadReply);
}

void Update::onDownloadReadyRead()
{
    QByteArray chunk = m_downloadReply->readAll();
    m_downloadHash.addData(chunk);
    m_downloadFile.write(chunk);
}

void Update::onDownloadProgressChanged(qint64 received, qint64 total)
{
    if (total <= 0)
        return;
    emit downloadProgress(static_cast<int>((received * 100) / total));
}

void Update::cancelDownload()
{
    if (m_downloadReply != nullptr)
        m_downloadReply->abort();
}

void Update::onDownloadReply()
{
    QNetworkReply *reply = m_downloadReply;
    m_downloadReply = nullptr;
    m_downloadFile.close();

    QNetworkReply::NetworkError error = reply->error();
    QString errorString = reply->errorString();
    reply->deleteLater();

    if (error != QNetworkReply::NoError) {
        QFile::remove(downloadPath());
        emit downloadFinished(false, errorString);
        return;
    }

    QString actualSha256 = QString::fromLatin1(m_downloadHash.result().toHex());
    if (actualSha256 != m_expectedSha256) {
        QFile::remove(downloadPath());
        emit downloadFinished(false,
            QStringLiteral("checksum mismatch - downloaded file was corrupted or incomplete"));
        return;
    }

    emit downloadFinished(true, QString());
}

bool Update::applyUpdate()
{
    QDBusInterface iface(
                "com.canonical.SystemImage",
                "/Service",
                "com.canonical.SystemImage",
                QDBusConnection::systemBus(),
                this);

    if (!iface.isValid()) {
        qWarning() << iface.interface() << "isn't valid";
        return false;
    }

    QDBusReply<void> reply = iface.call("CraftparkingApplyUpdate", downloadPath());
    if (!reply.isValid()) {
        qWarning() << reply.error().message();
        return false;
    }
    return true;
}
