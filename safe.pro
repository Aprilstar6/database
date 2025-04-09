QT += quick
QT += quickcontrols2

# You can make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

CONFIG += c++17

SOURCES += \
        CryptoManager.cpp \
        Directoryhandler.cpp \
        main.cpp

RESOURCES += qml.qrc

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

HEADERS += \
    CryptoManager.h \
    Directoryhandler.h

# OpenSSL libraries
unix {
    CONFIG += link_pkgconfig
    PKGCONFIG += openssl
}

win32 {
    # Path to OpenSSL
    # Update these paths based on your OpenSSL installation
    OPENSSL_PATH = C:/OpenSSL-Win64

    INCLUDEPATH += $$OPENSSL_PATH/include
    LIBS += -L$$OPENSSL_PATH/lib -llibcrypto -llibssl
}

macx {
    # For macOS, typically installed via homebrew
    INCLUDEPATH += /usr/local/opt/openssl/include
    LIBS += -L/usr/local/opt/openssl/lib -lcrypto -lssl
}
