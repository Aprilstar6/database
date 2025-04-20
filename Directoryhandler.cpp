#include "Directoryhandler.h"
#include <QDir>
#include <QFileInfo>
#include <QDateTime>
#include <QDebug>

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

    // 检查文件是否为空
    fseek(inFile, 0, SEEK_END);
    long fileSize = ftell(inFile);
    rewind(inFile);
    
    if (fileSize == 0) {
        // 如果是空文件，则创建一个特殊标记
        FILE* outFile = fopen(outputFile, "wb");
        if (!outFile) {
            perror("Failed to open output file");
            fclose(inFile);
            exit(EXIT_FAILURE);
        }
        
        // 写入一个特殊标记，表示这是一个加密后的空文件
        const char emptyFileMarker[] = "EMPTY_FILE_MARKER";
        fwrite(emptyFileMarker, sizeof(char), strlen(emptyFileMarker), outFile);
        
        fclose(inFile);
        fclose(outFile);
        return;
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
    FILE* inFile = fopen(inputFile, "rb");
    if (!inFile) {
        perror("Failed to open input file");
        exit(EXIT_FAILURE);
    }
    
    // 检查文件是否为加密的空文件
    char buffer[17] = {0}; // 足够存储"EMPTY_FILE_MARKER"和结束符
    size_t bytesRead = fread(buffer, 1, 16, inFile);
    buffer[bytesRead] = '\0';
    
    if (strcmp(buffer, "EMPTY_FILE_MARKER") == 0) {
        // 如果是加密的空文件，则创建一个空的输出文件
        fclose(inFile);
        FILE* outFile = fopen(outputFile, "wb");
        if (!outFile) {
            perror("Failed to open output file");
            exit(EXIT_FAILURE);
        }
        fclose(outFile);
        return;
    }
    
    // 对于非空文件，重置文件指针并进行正常解密
    rewind(inFile);
    
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
        int decryptedCh = ch ^ key[keyIndex];
        fputc(decryptedCh, outFile);
        keyIndex = (keyIndex + 1) % keyLen;  // Cycle through the key
    }

    fclose(inFile);
    fclose(outFile);
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
    
    // 输出调试信息
    qDebug() << "复制文件 - 原始源路径:" << sourceFile;
    qDebug() << "复制文件 - 目标路径:" << destFile;

    // 判断系统平台，适当处理文件路径
#ifdef Q_OS_WIN
    // Windows需要去掉最前面的斜杠
    if (cleanedSource.startsWith("/")) {
        cleanedSource = cleanedSource.mid(1);
    }
#else
    // Linux平台处理
    // 确保路径开头有斜杠
    if (!cleanedSource.startsWith("/") && !cleanedSource.startsWith("./") && !cleanedSource.startsWith("../")) {
        cleanedSource = "/" + cleanedSource;
    }
    
    // 处理可能的双斜杠问题
    while (cleanedSource.contains("//")) {
        cleanedSource = cleanedSource.replace("//", "/");
    }
#endif

    // 输出调试信息
    qDebug() << "复制文件 - 处理后源路径:" << cleanedSource;

    QFile source(cleanedSource);
    QFile dest(destFile);

    // 确保源文件存在
    if (!source.exists()) {
        qDebug() << "文件不存在:" << cleanedSource;
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

    // 打开源文件用于读取
    if (!source.open(QIODevice::ReadOnly)) {
        emit operationComplete(false, "无法打开源文件: " + source.errorString());
        return false;
    }

    // 打开目标文件用于写入
    if (!dest.open(QIODevice::WriteOnly)) {
        source.close();
        emit operationComplete(false, "无法打开目标文件: " + dest.errorString());
        return false;
    }

    // 复制文件内容
    QByteArray data = source.readAll();
    qint64 bytesWritten = dest.write(data);
    
    // 关闭文件
    source.close();
    dest.close();

    if (bytesWritten != data.size()) {
        emit operationComplete(false, "文件写入不完整: " + dest.errorString());
        return false;
    }

    emit operationComplete(true, "文件复制成功");
    return true;
}

bool DirectoryHandler::deleteFile(const QString &filePath)
{
    // 清理路径，处理文件URL（如果有必要）
    QString cleanedPath = filePath;
    
    // 输出调试信息
    qDebug() << "删除文件 - 路径:" << filePath;

    // 判断系统平台，适当处理文件路径
#ifdef Q_OS_WIN
    // Windows需要去掉最前面的斜杠
    if (cleanedPath.startsWith("/")) {
        cleanedPath = cleanedPath.mid(1);
    }
#else
    // Linux平台处理
    // 确保路径开头有斜杠
    if (!cleanedPath.startsWith("/") && !cleanedPath.startsWith("./") && !cleanedPath.startsWith("../")) {
        cleanedPath = "/" + cleanedPath;
    }
    
    // 处理可能的双斜杠问题
    while (cleanedPath.contains("//")) {
        cleanedPath = cleanedPath.replace("//", "/");
    }
#endif

    // 输出调试信息
    qDebug() << "删除文件 - 处理后路径:" << cleanedPath;

    QFile file(cleanedPath);
    
    // 确保文件存在
    if (!file.exists()) {
        emit operationComplete(false, "文件不存在: " + cleanedPath);
        return false;
    }
    
    // 尝试删除文件
    if (!file.remove()) {
        emit operationComplete(false, "删除文件失败: " + file.errorString());
        return false;
    }
    
    emit operationComplete(true, "文件删除成功");
    return true;
}

// 在文件末尾添加clearTempFiles实现
bool DirectoryHandler::clearTempFiles(const QString &directoryPath)
{
    qDebug() << "正在清理目录中的所有临时文件:" << directoryPath;
    
    // 清理路径
    QString cleanedPath = directoryPath;
    
#ifdef Q_OS_WIN
    // Windows需要去掉最前面的斜杠
    if (cleanedPath.startsWith("/")) {
        cleanedPath = cleanedPath.mid(1);
    }
#else
    // Linux平台处理
    // 确保路径开头有斜杠
    if (!cleanedPath.startsWith("/") && !cleanedPath.startsWith("./") && !cleanedPath.startsWith("../")) {
        cleanedPath = "/" + cleanedPath;
    }
    
    // 处理可能的双斜杠问题
    while (cleanedPath.contains("//")) {
        cleanedPath = cleanedPath.replace("//", "/");
    }
#endif

    QDir dir(cleanedPath);
    if (!dir.exists()) {
        qDebug() << "目录不存在:" << cleanedPath;
        emit operationComplete(false, "目录不存在: " + cleanedPath);
        return false;
    }
    
    // 获取目录中的所有文件
    QStringList fileFilters;
    fileFilters << "*.txt" << "*.jpg" << "*.png" << "*.pdf" << "*.doc" << "*.docx" 
                << "*.xls" << "*.xlsx" << "*.aes" << "*.rsa" << "*.enc" << "*.xor";
                
    QFileInfoList fileList = dir.entryInfoList(fileFilters, QDir::Files | QDir::NoDotAndDotDot);
    
    // 没有找到匹配的文件
    if (fileList.isEmpty()) {
        qDebug() << "目录中没有找到需要清除的文件";
        emit operationComplete(true, "目录已清空 (没有匹配的文件)");
        return true;
    }
    
    int deleteCount = 0;
    int errorCount = 0;
    
    // 逐个删除文件
    foreach (QFileInfo fileInfo, fileList) {
        QString filePath = fileInfo.absoluteFilePath();
        qDebug() << "尝试删除文件:" << filePath;
        
        QFile file(filePath);
        if (file.remove()) {
            deleteCount++;
            qDebug() << "成功删除文件:" << filePath;
        } else {
            errorCount++;
            qDebug() << "删除文件失败:" << filePath << ":" << file.errorString();
        }
    }
    
    QString message = QString("已删除 %1 个文件").arg(deleteCount);
    if (errorCount > 0) {
        message += QString(", %1 个文件删除失败").arg(errorCount);
    }
    
    qDebug() << message;
    emit operationComplete(errorCount == 0, message);
    
    return (errorCount == 0);
}
