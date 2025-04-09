#include "Directoryhandler.h"
#include <QDir>
#include <QFileInfo>
#include <QDateTime>

// Legacy XOR encryption functions (kept for backward compatibility)
extern "C"
{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Legacy encryption function
void encryptFile(const char* inputFile, const char* outputFile, const char* key) {
    FILE* inFile = fopen(inputFile, "rb");
    if (!inFile) {
        perror("Failed to open input file");
        exit(EXIT_FAILURE);
    }

    FILE* outFile = fopen(outputFile, "wb");
    if (!outFile) {
        perror("Failed to open output file");
        fclose(inFile);
        exit(EXIT_FAILURE);
    }

    int keyLen = strlen(key);
    int keyIndex = 0;

    int ch;
    while ((ch = fgetc(inFile)) != EOF) {
        int encryptedCh = ch ^ key[keyIndex];
        fputc(encryptedCh, outFile);
        keyIndex = (keyIndex + 1) % keyLen;  // Cycle through the key
    }

    fclose(inFile);
    fclose(outFile);
}

// Legacy decryption function (XOR is symmetrical)
void decryptFile(const char* inputFile, const char* outputFile, const char* key) {
    encryptFile(inputFile, outputFile, key);
}
}

DirectoryHandler::DirectoryHandler(QObject *parent)
    : QObject{parent}
{
    // Create the crypto manager
    cryptoManager = new CryptoManager(this);

    // Connect signals
    connect(cryptoManager, &CryptoManager::fileNameSignal,
            this, &DirectoryHandler::fileNameSignal);
    connect(cryptoManager, &CryptoManager::operationComplete,
            this, &DirectoryHandler::operationComplete);
    connect(cryptoManager, &CryptoManager::progressUpdate,
            this, &DirectoryHandler::progressUpdate);
}

void DirectoryHandler::listFiles(const QString &directoryPath, const QStringList &suffixes)
{
    QDir dir(directoryPath);
    // Using QDir::Files filter to only include files, not directories
    // QDir::NoDotAndDotDot filter to exclude "." and ".." special entries
    QStringList files = dir.entryList(QDir::Files | QDir::NoDotAndDotDot);

    // Iterate through the files
    foreach (const QString &file, files) {
        for (const QString &suffix : suffixes) {
            if (file.endsWith(suffix, Qt::CaseInsensitive)) {
                QFileInfo fileInfo(dir.filePath(file));
                // Pass the file name and modification time
                emit this->fileNameSignal(file, fileInfo.lastModified().toSecsSinceEpoch());
                break;
            }
        }
    }
}

// Legacy XOR encryption (kept for backward compatibility)
void DirectoryHandler::enCodeFile(const QString &filePath, const QString &outputPath, const QString &key)
{
    encryptFile(filePath.toStdString().c_str(), outputPath.toStdString().c_str(), key.toStdString().c_str());
    emit operationComplete(true, "File encrypted with legacy XOR encryption");
}

// Legacy XOR decryption (kept for backward compatibility)
void DirectoryHandler::deCodeFile(const QString &filePath, const QString &outputPath, const QString &key)
{
    decryptFile(filePath.toStdString().c_str(), outputPath.toStdString().c_str(), key.toStdString().c_str());
    emit operationComplete(true, "File decrypted with legacy XOR decryption");
}

// New AES encryption
bool DirectoryHandler::encryptFileAES(const QString &inputFile, const QString &outputFile, const QString &password)
{
    return cryptoManager->encryptFileAES(inputFile, outputFile, password);
}

// New AES decryption
bool DirectoryHandler::decryptFileAES(const QString &inputFile, const QString &outputFile, const QString &password)
{
    return cryptoManager->decryptFileAES(inputFile, outputFile, password);
}

// RSA encryption
bool DirectoryHandler::encryptFileRSA(const QString &inputFile, const QString &outputFile, const QString &keyName)
{
    return cryptoManager->encryptFileRSA(inputFile, outputFile, keyName);
}

// RSA decryption
bool DirectoryHandler::decryptFileRSA(const QString &inputFile, const QString &outputFile, const QString &keyName, const QString &password)
{
    return cryptoManager->decryptFileRSA(inputFile, outputFile, keyName, password);
}

// Hybrid encryption (AES+RSA)
bool DirectoryHandler::encryptFileHybrid(const QString &inputFile, const QString &outputFile, const QString &keyName)
{
    return cryptoManager->encryptFileHybrid(inputFile, outputFile, keyName);
}

// Hybrid decryption (AES+RSA)
bool DirectoryHandler::decryptFileHybrid(const QString &inputFile, const QString &outputFile, const QString &keyName, const QString &password)
{
    return cryptoManager->decryptFileHybrid(inputFile, outputFile, keyName, password);
}

// Key Management functions
bool DirectoryHandler::generateRSAKeyPair(const QString &name, const QString &password)
{
    return cryptoManager->generateRSAKeyPair(name, password);
}

// New AES key generation function
bool DirectoryHandler::generateAESKey(const QString &name, const QString &password)
{
    return cryptoManager->generateAESKey(name, password);
}

QStringList DirectoryHandler::getKeyList()
{
    return cryptoManager->getKeyList();
}

bool DirectoryHandler::deleteKey(const QString &keyName)
{
    return cryptoManager->deleteKey(keyName);
}

bool DirectoryHandler::exportKey(const QString &keyName, const QString &exportPath, const QString &password)
{
    return cryptoManager->exportKey(keyName, exportPath, password);
}

bool DirectoryHandler::importKey(const QString &importPath, const QString &password)
{
    return cryptoManager->importKey(importPath, password);
}

// 将此方法添加到 DirectoryHandler.cpp 文件中：

bool DirectoryHandler::copyFile(const QString &sourceFile, const QString &destFile)
{
    // 清理路径，处理文件URL（如果有必要）
    QString cleanedSource = sourceFile;

    // 判断系统平台，适当处理文件路径
#ifdef Q_OS_WIN
    // Windows需要去掉最前面的斜杠
    if (cleanedSource.startsWith("/")) {
        cleanedSource = cleanedSource.mid(1);
    }
#endif

    QFile source(cleanedSource);
    QFile dest(destFile);

    // 确保源文件存在
    if (!source.exists()) {
        emit operationComplete(false, "源文件不存在: " + cleanedSource);
        return false;
    }

    // 如果目标文件已存在，先删除它
    if (dest.exists()) {
        if (!dest.remove()) {
            emit operationComplete(false, "无法覆盖目标文件");
            return false;
        }
    }

    // 复制文件
    if (!source.copy(destFile)) {
        emit operationComplete(false, "文件复制失败: " + source.errorString());
        return false;
    }

    emit operationComplete(true, "文件复制成功");
    return true;
}
