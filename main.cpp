#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include "Directoryhandler.h"
#include <QDir>
#include <QDebug>

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

    // 确保当前工作目录正确
    QDir::setCurrent(QCoreApplication::applicationDirPath());
    qDebug() << "应用程序工作目录:" << QDir::currentPath();

    QQmlApplicationEngine engine;

    // Set the offline storage path for database
    engine.setOfflineStoragePath("./");

    // Register the DirectoryHandler class with QML
    qmlRegisterType<DirectoryHandler>("com.directory", 1, 0, "DirectoryHandler");
    qDebug() << "已注册DirectoryHandler到QML引擎";

    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
                         if (!obj && url == objUrl) {
                             qDebug() << "加载主界面失败!";
                             QCoreApplication::exit(-1);
                         } else {
                             qDebug() << "成功加载主界面";
                         }
                     }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
