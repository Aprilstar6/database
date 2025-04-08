#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include "Directoryhandler.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QGuiApplication app(argc, argv);

    // Set application info for data storage paths
    QCoreApplication::setOrganizationName("YourCompany");
    QCoreApplication::setOrganizationDomain("yourcompany.com");
    QCoreApplication::setApplicationName("SecureFileEncryption");

    QQmlApplicationEngine engine;

    // Set the offline storage path for database
    engine.setOfflineStoragePath("./");

    // Register the DirectoryHandler class with QML
    qmlRegisterType<DirectoryHandler>("com.directory", 1, 0, "DirectoryHandler");

    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
                         if (!obj && url == objUrl)
                             QCoreApplication::exit(-1);
                     }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
