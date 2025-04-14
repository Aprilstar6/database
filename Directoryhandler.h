#ifndef DIRECTORYHANDLER_H
#define DIRECTORYHANDLER_H

#include <QObject>
#include <QStringList>
#include "CryptoManager.h"

class DirectoryHandler : public QObject
{
    Q_OBJECT
public:
    explicit DirectoryHandler(QObject *parent = nullptr);

    // File handling
    Q_INVOKABLE void listFiles(const QString &directoryPath, const QStringList &suffixes);
    Q_INVOKABLE bool copyFile(const QString &sourceFile, const QString &destFile);
    Q_INVOKABLE bool deleteFile(const QString &filePath);
    Q_INVOKABLE bool clearTempFiles(const QString &directoryPath);

    // Legacy Encryption/Decryption (backward compatibility)
    Q_INVOKABLE void enCodeFile(const QString &filePath, const QString &outputPath, const QString &key);
    Q_INVOKABLE void deCodeFile(const QString &filePath, const QString &outputPath, const QString &key);

    // New AES Encryption/Decryption
    Q_INVOKABLE bool encryptFileAES(const QString &inputFile, const QString &outputFile, const QString &password);
    Q_INVOKABLE bool decryptFileAES(const QString &inputFile, const QString &outputFile, const QString &password);

    // RSA Encryption/Decryption
    Q_INVOKABLE bool encryptFileRSA(const QString &inputFile, const QString &outputFile, const QString &keyName);
    Q_INVOKABLE bool decryptFileRSA(const QString &inputFile, const QString &outputFile, const QString &keyName, const QString &password);

    // Hybrid encryption (AES+RSA)
    Q_INVOKABLE bool encryptFileHybrid(const QString &inputFile, const QString &outputFile, const QString &keyName);
    Q_INVOKABLE bool decryptFileHybrid(const QString &inputFile, const QString &outputFile, const QString &keyName, const QString &password);

    // Key Management functions
    Q_INVOKABLE bool generateRSAKeyPair(const QString &name, const QString &password);
    Q_INVOKABLE bool generateAESKey(const QString &name, const QString &password);
    Q_INVOKABLE QStringList getKeyList();
    Q_INVOKABLE bool deleteKey(const QString &keyName);
    Q_INVOKABLE bool exportKey(const QString &keyName, const QString &exportPath, const QString &password);
    Q_INVOKABLE bool importKey(const QString &importPath, const QString &password);

signals:
    void fileNameSignal(const QString &name, const int &time);
    void operationComplete(bool success, const QString &message);
    void progressUpdate(int percentage);

private:
    CryptoManager *cryptoManager;
};

#endif // DIRECTORYHANDLER_H
