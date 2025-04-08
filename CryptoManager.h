#ifndef CRYPTOMANAGER_H
#define CRYPTOMANAGER_H

#include <QObject>
#include <QByteArray>
#include <QFile>
#include <QDir>
#include <QString>
#include <QStringList>
#include <QCryptographicHash>
#include <QRandomGenerator>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

class CryptoManager : public QObject
{
    Q_OBJECT
public:
    explicit CryptoManager(QObject *parent = nullptr);

    // Key management
    Q_INVOKABLE bool generateRSAKeyPair(const QString &name, const QString &password);
    Q_INVOKABLE QStringList getKeyList();
    Q_INVOKABLE bool deleteKey(const QString &keyName);
    Q_INVOKABLE bool exportKey(const QString &keyName, const QString &exportPath, const QString &password);
    Q_INVOKABLE bool importKey(const QString &importPath, const QString &password);

    // AES encryption/decryption
    Q_INVOKABLE bool encryptFileAES(const QString &inputFile, const QString &outputFile, const QString &password);
    Q_INVOKABLE bool decryptFileAES(const QString &inputFile, const QString &outputFile, const QString &password);

    // RSA encryption/decryption
    Q_INVOKABLE bool encryptFileRSA(const QString &inputFile, const QString &outputFile, const QString &keyName);
    Q_INVOKABLE bool decryptFileRSA(const QString &inputFile, const QString &outputFile, const QString &keyName, const QString &password);

    // Hybrid encryption (AES+RSA)
    Q_INVOKABLE bool encryptFileHybrid(const QString &inputFile, const QString &outputFile, const QString &keyName);
    Q_INVOKABLE bool decryptFileHybrid(const QString &inputFile, const QString &outputFile, const QString &keyName, const QString &password);

    // File operations
    Q_INVOKABLE void listFiles(const QString &directoryPath, const QStringList &suffixes);

signals:
    void fileNameSignal(const QString &name, const int &time);
    void operationComplete(bool success, const QString &message);
    void progressUpdate(int percentage);

private:
    // Private helper methods
    QByteArray generateAESKey(const QString &password, const QByteArray &salt);
    QByteArray generateRandomBytes(int length);
    bool saveKeyToFile(const QString &keyName, const QByteArray &publicKey, const QByteArray &encryptedPrivateKey);
    bool loadKeyFromFile(const QString &keyName, QByteArray &publicKey, QByteArray &encryptedPrivateKey);
    QString getKeysFolderPath();

    // Encryption helpers
    QByteArray aesEncrypt(const QByteArray &data, const QByteArray &key, const QByteArray &iv);
    QByteArray aesDecrypt(const QByteArray &data, const QByteArray &key, const QByteArray &iv);
    QByteArray rsaEncrypt(const QByteArray &data, const QByteArray &publicKey);
    QByteArray rsaDecrypt(const QByteArray &data, const QByteArray &privateKey);
};

#endif // CRYPTOMANAGER_H
