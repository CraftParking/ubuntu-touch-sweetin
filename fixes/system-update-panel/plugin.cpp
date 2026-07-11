#include "plugin.h"

#include <QtQml>
#include "update.h"

void BackendPlugin::registerTypes(const char *uri)
{
    Q_ASSERT(uri == QLatin1String("Craftparking.SystemSettings.Update"));
    qmlRegisterType<Update>(uri, 1, 0, "CraftparkingUpdatePanel");
}

void BackendPlugin::initializeEngine(QQmlEngine *engine, const char *uri)
{
    QQmlExtensionPlugin::initializeEngine(engine, uri);
}
