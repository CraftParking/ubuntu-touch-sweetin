#include "update.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusVariant>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QDebug>

namespace {
const char *MANIFEST_URL =
    "https://raw.githubusercontent.com/CraftParking/ubuntu-touch-sweetin/master/latest.json";
const char *VERSION_FILE = "/etc/craftparking-version";
const char *SERVICE = "com.canonical.SystemImage";
const char *PATH = "/Service";
const char *IFACE = "com.canonical.SystemImage";
}

Update::Update(QObject *parent)
    : QObject(parent)
{
    QDBusConnection::systemBus().connect(
        SERVICE, PATH, IFACE, "CraftparkingDownloadProgress",
        this, SLOT(onDBusDownloadProgress(qlonglong, qlonglong)));
    QDBusConnection::systemBus().connect(
        SERVICE, PATH, IFACE, "CraftparkingDownloadFinished",
        this, SLOT(onDBusDownloadFinished(bool, QString)));
}

Update::~Update()
{
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

void Update::downloadUpdate(const QString &zipUrl, const QString &expectedSha256,
                             qlonglong expectedSize)
{
    QDBusInterface iface(SERVICE, PATH, IFACE, QDBusConnection::systemBus(), this);
    if (!iface.isValid()) {
        emit downloadFinished(false, QStringLiteral("system-image service isn't available"));
        return;
    }
    QDBusReply<bool> reply = iface.call(
        "CraftparkingStartDownload", zipUrl, expectedSha256, expectedSize);
    if (!reply.isValid()) {
        emit downloadFinished(false, reply.error().message());
        return;
    }
    if (!reply.value()) {
        // Already running (e.g. this page was reopened) - not an error,
        // the progress/finished signals we're already connected to will
        // keep reporting the existing download either way.
        queryDownloadStatus();
    }
}

void Update::cancelDownload()
{
    QDBusInterface iface(SERVICE, PATH, IFACE, QDBusConnection::systemBus(), this);
    iface.call("CraftparkingCancelDownload");
}

void Update::queryDownloadStatus()
{
    QDBusInterface iface(SERVICE, PATH, IFACE, QDBusConnection::systemBus(), this);
    QDBusReply<QVariantMap> reply = iface.call("CraftparkingDownloadStatus");
    if (!reply.isValid())
        return;
    QVariantMap status = reply.value();
    bool inProgress = status.value("in_progress").toBool();
    qlonglong received = status.value("received").toLongLong();
    qlonglong total = status.value("total").toLongLong();
    emit downloadStatus(inProgress, received, total);
    if (status.value("done").toBool()) {
        emit downloadFinished(status.value("success").toBool(),
                               status.value("error").toString());
    }
}

void Update::onDBusDownloadProgress(qlonglong received, qlonglong total)
{
    emit downloadProgress(received, total);
}

void Update::onDBusDownloadFinished(bool success, const QString &error)
{
    emit downloadFinished(success, error);
}

bool Update::applyUpdate()
{
    QDBusInterface iface(SERVICE, PATH, IFACE, QDBusConnection::systemBus(), this);

    if (!iface.isValid()) {
        qWarning() << iface.interface() << "isn't valid";
        return false;
    }

    QDBusReply<void> reply = iface.call("CraftparkingApplyUpdate");
    if (!reply.isValid()) {
        qWarning() << reply.error().message();
        return false;
    }
    return true;
}
