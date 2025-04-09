#include "CryptoManager.h"
#include <QDebug>
#include <QStandardPaths>
#include <QFileInfo>
#include <QDateTime>
#include <QCryptographicHash>

// OpenSSL headers
#include <openssl/aes.h>
#include <openssl/rsa.h>
#include <openssl/pem.h>
#include <openssl/err.h>
#include <openssl/rand.h>
#include <openssl/evp.h>

CryptoManager::CryptoManager(QObject *parent) : QObject(parent)
{
    // Initialize OpenSSL
    OpenSSL_add_all_algorithms();
    ERR_load_crypto_strings();

    // Create keys directory if it doesn't exist
    QDir dir;
    dir.mkpath(getKeysFolderPath());
}

bool CryptoManager::generateRSAKeyPair(const QString &name, const QString &password)
{
    // Check if key with this name already exists
    if (getKeyList().contains(name + ".key")) {
        emit operationComplete(false, "A key with this name already exists");
        return false;
    }

    // Generate RSA key pair
    RSA *rsa = RSA_new();
    BIGNUM *bn = BN_new();
    BN_set_word(bn, RSA_F4);

    if (RSA_generate_key_ex(rsa, 2048, bn, nullptr) != 1) {
        RSA_free(rsa);
        BN_free(bn);
        emit operationComplete(false, "Failed to generate RSA key pair");
        return false;
    }

    // Convert public key to PEM format
    BIO *pubBio = BIO_new(BIO_s_mem());
    PEM_write_bio_RSAPublicKey(pubBio, rsa);

    char *pubKeyPtr = nullptr;
    long pubKeySize = BIO_get_mem_data(pubBio, &pubKeyPtr);
    QByteArray publicKey = QByteArray(pubKeyPtr, pubKeySize);

    // Convert private key to PEM format and encrypt it
    BIO *privBio = BIO_new(BIO_s_mem());
    PEM_write_bio_RSAPrivateKey(privBio, rsa, EVP_aes_256_cbc(),
                                (unsigned char*)password.toUtf8().data(),
                                password.length(), nullptr, nullptr);

    char *privKeyPtr = nullptr;
    long privKeySize = BIO_get_mem_data(privBio, &privKeyPtr);
    QByteArray encryptedPrivateKey = QByteArray(privKeyPtr, privKeySize);

    // Save key pair
    bool result = saveKeyToFile(name, publicKey, encryptedPrivateKey);

    // Cleanup
    BIO_free(pubBio);
    BIO_free(privBio);
    RSA_free(rsa);
    BN_free(bn);

    if (result) {
        emit operationComplete(true, "RSA key pair generated and saved successfully");
    } else {
        emit operationComplete(false, "Failed to save RSA key pair");
    }

    return result;
}

bool CryptoManager::generateAESKey(const QString &name, const QString &password)
{
    // Check if key with this name already exists
    if (getKeyList().contains(name + ".aeskey")) {
        emit operationComplete(false, "A key with this name already exists");
        return false;
    }

    // Generate random salt
    QByteArray salt = generateRandomBytes(16);

    // Generate AES key from password and salt
    QByteArray aesKey = generateAESKey(password, salt);

    // Encrypt the AES key with password (for storage)
    QByteArray iv = generateRandomBytes(16);
    QByteArray encryptedKey = aesEncrypt(aesKey, generateAESKey(password, salt), iv);

    // Combine IV with encrypted key
    encryptedKey = iv + encryptedKey;

    // Save key
    bool result = saveAESKeyToFile(name, encryptedKey, salt);

    if (result) {
        emit operationComplete(true, "AES key generated and saved successfully");
    } else {
        emit operationComplete(false, "Failed to save AES key");
    }

    return result;
}

QStringList CryptoManager::getKeyList()
{
    QDir keysDir(getKeysFolderPath());
    QStringList filters;
    filters << "*.key" << "*.aeskey";
    return keysDir.entryList(filters, QDir::Files, QDir::Name);
}

bool CryptoManager::deleteKey(const QString &keyName)
{
    QString keyPath;
    if (keyName.endsWith(".key") || keyName.endsWith(".aeskey")) {
        keyPath = getKeysFolderPath() + "/" + keyName;
    } else {
        // Check if RSA key exists
        QString rsaKeyPath = getKeysFolderPath() + "/" + keyName + ".key";
        QFile rsaFile(rsaKeyPath);

        // Check if AES key exists
        QString aesKeyPath = getKeysFolderPath() + "/" + keyName + ".aeskey";
        QFile aesFile(aesKeyPath);

        if (rsaFile.exists()) {
            keyPath = rsaKeyPath;
        } else if (aesFile.exists()) {
            keyPath = aesKeyPath;
        } else {
            emit operationComplete(false, "Key not found");
            return false;
        }
    }

    QFile file(keyPath);
    if (file.exists()) {
        bool success = file.remove();
        if (success) {
            emit operationComplete(true, "Key deleted successfully");
        } else {
            emit operationComplete(false, "Failed to delete key");
        }
        return success;
    }

    emit operationComplete(false, "Key not found");
    return false;
}

bool CryptoManager::exportKey(const QString &keyName, const QString &exportPath, const QString &password)
{
    bool isRSA = false;
    bool isAES = false;
    QByteArray publicKey, encryptedPrivateKey; // For RSA
    QByteArray encryptedKey, salt; // For AES

    // Determine key type and load it
    if (keyName.endsWith(".key")) {
        isRSA = true;
        if (!loadKeyFromFile(keyName, publicKey, encryptedPrivateKey)) {
            emit operationComplete(false, "Failed to load RSA key");
            return false;
        }
    } else if (keyName.endsWith(".aeskey")) {
        isAES = true;
        if (!loadAESKeyFromFile(keyName, encryptedKey, salt)) {
            emit operationComplete(false, "Failed to load AES key");
            return false;
        }
    } else {
        // Try to load as RSA first
        if (loadKeyFromFile(keyName, publicKey, encryptedPrivateKey)) {
            isRSA = true;
        }
        // If RSA failed, try AES
        else if (loadAESKeyFromFile(keyName, encryptedKey, salt)) {
            isAES = true;
        }
        else {
            emit operationComplete(false, "Failed to load key");
            return false;
        }
    }

    // Create export data structure
    QJsonObject exportData;
    exportData["name"] = keyName;

    if (isRSA) {
        exportData["key_type"] = "RSA";
        exportData["public_key"] = QString(publicKey.toBase64());
        exportData["private_key"] = QString(encryptedPrivateKey.toBase64());
    } else if (isAES) {
        exportData["key_type"] = "AES";
        exportData["encrypted_key"] = QString(encryptedKey.toBase64());
        exportData["salt"] = QString(salt.toBase64());
    }

    // Create JSON document
    QJsonDocument doc(exportData);
    QByteArray jsonData = doc.toJson();

    // Encrypt the JSON with password
    QByteArray exportSalt = generateRandomBytes(16);
    QByteArray key = generateAESKey(password, exportSalt);
    QByteArray iv = generateRandomBytes(16);
    QByteArray encryptedData = aesEncrypt(jsonData, key, iv);

    if (encryptedData.isEmpty()) {
        emit operationComplete(false, "Encryption failed");
        return false;
    }

    // Write to file
    QFile file(exportPath);
    if (!file.open(QIODevice::WriteOnly)) {
        emit operationComplete(false, "Failed to open export file");
        return false;
    }

    // Format: SALT(16) + IV(16) + ENCRYPTED_DATA
    file.write(exportSalt);
    file.write(iv);
    file.write(encryptedData);
    file.close();

    emit operationComplete(true, "Key exported successfully");
    return true;
}

bool CryptoManager::importKey(const QString &importPath, const QString &password)
{
    QFile file(importPath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit operationComplete(false, "Failed to open import file");
        return false;
    }

    QByteArray fileData = file.readAll();
    file.close();

    if (fileData.size() < 32) { // At least salt + IV
        emit operationComplete(false, "Invalid key file format");
        return false;
    }

    // Extract salt, IV and encrypted data
    QByteArray salt = fileData.left(16);
    QByteArray iv = fileData.mid(16, 16);
    QByteArray encryptedData = fileData.mid(32);

    // Decrypt data
    QByteArray key = generateAESKey(password, salt);
    QByteArray decryptedData = aesDecrypt(encryptedData, key, iv);

    if (decryptedData.isEmpty()) {
        emit operationComplete(false, "Decryption failed. Wrong password?");
        return false;
    }

    // Parse JSON
    QJsonDocument doc = QJsonDocument::fromJson(decryptedData);
    if (doc.isNull() || !doc.isObject()) {
        emit operationComplete(false, "Invalid key file format");
        return false;
    }

    QJsonObject obj = doc.object();
    QString keyName = obj["name"].toString();
    QString keyType = obj["key_type"].toString();

    bool result = false;

    if (keyType == "RSA") {
        QByteArray publicKey = QByteArray::fromBase64(obj["public_key"].toString().toLatin1());
        QByteArray encryptedPrivateKey = QByteArray::fromBase64(obj["private_key"].toString().toLatin1());

        // Check if key name already exists
        if (getKeyList().contains(keyName + ".key")) {
            emit operationComplete(false, "A key with this name already exists");
            return false;
        }

        // Save the imported RSA key
        result = saveKeyToFile(keyName, publicKey, encryptedPrivateKey);
    }
    else if (keyType == "AES") {
        QByteArray encryptedKey = QByteArray::fromBase64(obj["encrypted_key"].toString().toLatin1());
        QByteArray saltData = QByteArray::fromBase64(obj["salt"].toString().toLatin1());

        // Check if key name already exists
        if (getKeyList().contains(keyName + ".aeskey")) {
            emit operationComplete(false, "A key with this name already exists");
            return false;
        }

        // Save the imported AES key
        result = saveAESKeyToFile(keyName, encryptedKey, saltData);
    }
    else {
        emit operationComplete(false, "Unknown key type");
        return false;
    }

    if (result) {
        emit operationComplete(true, "Key imported successfully");
    } else {
        emit operationComplete(false, "Failed to save imported key");
    }

    return result;
}

bool CryptoManager::encryptFileAES(const QString &inputFile, const QString &outputFile, const QString &password)
{
    QFile inFile(inputFile);
    if (!inFile.open(QIODevice::ReadOnly)) {
        emit operationComplete(false, "Failed to open input file");
        return false;
    }

    QByteArray fileData = inFile.readAll();
    inFile.close();

    // Generate salt and IV
    QByteArray salt = generateRandomBytes(16);
    QByteArray key = generateAESKey(password, salt);
    QByteArray iv = generateRandomBytes(16);

    // Encrypt the data
    QByteArray encryptedData = aesEncrypt(fileData, key, iv);

    if (encryptedData.isEmpty()) {
        emit operationComplete(false, "Encryption failed");
        return false;
    }

    // Write to output file
    QFile outFile(outputFile);
    if (!outFile.open(QIODevice::WriteOnly)) {
        emit operationComplete(false, "Failed to open output file");
        return false;
    }

    // Format: SALT(16) + IV(16) + ENCRYPTED_DATA
    outFile.write(salt);
    outFile.write(iv);
    outFile.write(encryptedData);
    outFile.close();

    emit operationComplete(true, "File encrypted successfully with AES");
    return true;
}

bool CryptoManager::decryptFileAES(const QString &inputFile, const QString &outputFile, const QString &password)
{
    QFile inFile(inputFile);
    if (!inFile.open(QIODevice::ReadOnly)) {
        emit operationComplete(false, "Failed to open input file");
        return false;
    }

    QByteArray fileData = inFile.readAll();
    inFile.close();

    if (fileData.size() < 32) { // At least salt + IV
        emit operationComplete(false, "Invalid encrypted file format");
        return false;
    }

    // Extract salt, IV and encrypted data
    QByteArray salt = fileData.left(16);
    QByteArray iv = fileData.mid(16, 16);
    QByteArray encryptedData = fileData.mid(32);

    // Derive key from password
    QByteArray key = generateAESKey(password, salt);

    // Decrypt the data
    QByteArray decryptedData = aesDecrypt(encryptedData, key, iv);

    if (decryptedData.isEmpty()) {
        emit operationComplete(false, "Decryption failed. Wrong password?");
        return false;
    }

    // Write to output file
    QFile outFile(outputFile);
    if (!outFile.open(QIODevice::WriteOnly)) {
        emit operationComplete(false, "Failed to open output file");
        return false;
    }

    outFile.write(decryptedData);
    outFile.close();

    emit operationComplete(true, "File decrypted successfully with AES");
    return true;
}

bool CryptoManager::encryptFileRSA(const QString &inputFile, const QString &outputFile, const QString &keyName)
{
    // Load the public key
    QByteArray publicKey, dummy;
    if (!loadKeyFromFile(keyName, publicKey, dummy)) {
        emit operationComplete(false, "Failed to load public key");
        return false;
    }

    QFile inFile(inputFile);
    if (!inFile.open(QIODevice::ReadOnly)) {
        emit operationComplete(false, "Failed to open input file");
        return false;
    }

    QByteArray fileData = inFile.readAll();
    inFile.close();

    // RSA has size limitations, so this is only suitable for small files/messages
    if (fileData.size() > 245) { // RSA-2048 can encrypt at most 245 bytes
        emit operationComplete(false, "File too large for RSA encryption. Use hybrid encryption instead.");
        return false;
    }

    // Encrypt the data
    QByteArray encryptedData = rsaEncrypt(fileData, publicKey);

    if (encryptedData.isEmpty()) {
        emit operationComplete(false, "RSA encryption failed");
        return false;
    }

    // Write to output file
    QFile outFile(outputFile);
    if (!outFile.open(QIODevice::WriteOnly)) {
        emit operationComplete(false, "Failed to open output file");
        return false;
    }

    outFile.write(encryptedData);
    outFile.close();

    emit operationComplete(true, "File encrypted successfully with RSA");
    return true;
}

bool CryptoManager::decryptFileRSA(const QString &inputFile, const QString &outputFile, const QString &keyName, const QString &password)
{
    // Load the encrypted private key
    QByteArray dummy, encryptedPrivateKey;
    if (!loadKeyFromFile(keyName, dummy, encryptedPrivateKey)) {
        emit operationComplete(false, "Failed to load private key");
        return false;
    }

    // Decrypt the private key with password
    BIO *bio = BIO_new_mem_buf(encryptedPrivateKey.data(), encryptedPrivateKey.length());
    EVP_PKEY *pkey = nullptr;
    PEM_read_bio_PrivateKey(bio, &pkey, nullptr, (void*)password.toUtf8().data());
    BIO_free(bio);

    if (!pkey) {
        emit operationComplete(false, "Failed to decrypt private key. Wrong password?");
        return false;
    }

    // Get RSA key from EVP_PKEY
    RSA *rsa = EVP_PKEY_get1_RSA(pkey);
    if (!rsa) {
        EVP_PKEY_free(pkey);
        emit operationComplete(false, "Failed to get RSA key");
        return false;
    }

    // Convert RSA to PEM format
    BIO *privBio = BIO_new(BIO_s_mem());
    PEM_write_bio_RSAPrivateKey(privBio, rsa, nullptr, nullptr, 0, nullptr, nullptr);

    char *privKeyPtr = nullptr;
    long privKeySize = BIO_get_mem_data(privBio, &privKeyPtr);
    QByteArray privateKey = QByteArray(privKeyPtr, privKeySize);

    // Read encrypted file
    QFile inFile(inputFile);
    if (!inFile.open(QIODevice::ReadOnly)) {
        BIO_free(privBio);
        RSA_free(rsa);
        EVP_PKEY_free(pkey);
        emit operationComplete(false, "Failed to open input file");
        return false;
    }

    QByteArray encryptedData = inFile.readAll();
    inFile.close();

    // Decrypt the data
    QByteArray decryptedData = rsaDecrypt(encryptedData, privateKey);

    // Cleanup
    BIO_free(privBio);
    RSA_free(rsa);
    EVP_PKEY_free(pkey);

    if (decryptedData.isEmpty()) {
        emit operationComplete(false, "RSA decryption failed");
        return false;
    }

    // Write to output file
    QFile outFile(outputFile);
    if (!outFile.open(QIODevice::WriteOnly)) {
        emit operationComplete(false, "Failed to open output file");
        return false;
    }

    outFile.write(decryptedData);
    outFile.close();

    emit operationComplete(true, "File decrypted successfully with RSA");
    return true;
}

bool CryptoManager::encryptFileHybrid(const QString &inputFile, const QString &outputFile, const QString &keyName)
{
    // Load the public key
    QByteArray publicKey, dummy;
    if (!loadKeyFromFile(keyName, publicKey, dummy)) {
        emit operationComplete(false, "Failed to load public key");
        return false;
    }

    QFile inFile(inputFile);
    if (!inFile.open(QIODevice::ReadOnly)) {
        emit operationComplete(false, "Failed to open input file");
        return false;
    }

    QByteArray fileData = inFile.readAll();
    inFile.close();

    // Generate a random AES key and IV
    QByteArray aesKey = generateRandomBytes(32); // 256 bit
    QByteArray iv = generateRandomBytes(16);

    // Encrypt the file data with AES
    QByteArray encryptedData = aesEncrypt(fileData, aesKey, iv);

    if (encryptedData.isEmpty()) {
        emit operationComplete(false, "AES encryption failed");
        return false;
    }

    // Encrypt the AES key with RSA
    QByteArray encryptedKey = rsaEncrypt(aesKey, publicKey);

    if (encryptedKey.isEmpty()) {
        emit operationComplete(false, "RSA encryption of AES key failed");
        return false;
    }

    // Write to output file
    QFile outFile(outputFile);
    if (!outFile.open(QIODevice::WriteOnly)) {
        emit operationComplete(false, "Failed to open output file");
        return false;
    }

    // Format: KEY_SIZE(4 bytes) + ENCRYPTED_KEY + IV(16) + ENCRYPTED_DATA
    QDataStream stream(&outFile);
    stream.setVersion(QDataStream::Qt_5_15);

    // Write the encrypted key size and the key itself
    stream << (qint32)encryptedKey.size();
    outFile.write(encryptedKey);

    // Write the IV and encrypted data
    outFile.write(iv);
    outFile.write(encryptedData);

    outFile.close();

    emit operationComplete(true, "File encrypted successfully with hybrid encryption (AES+RSA)");
    return true;
}

bool CryptoManager::decryptFileHybrid(const QString &inputFile, const QString &outputFile, const QString &keyName, const QString &password)
{
    // Load the encrypted private key
    QByteArray dummy, encryptedPrivateKey;
    if (!loadKeyFromFile(keyName, dummy, encryptedPrivateKey)) {
        emit operationComplete(false, "Failed to load private key");
        return false;
    }

    // Decrypt the private key with password
    BIO *bio = BIO_new_mem_buf(encryptedPrivateKey.data(), encryptedPrivateKey.length());
    EVP_PKEY *pkey = nullptr;
    PEM_read_bio_PrivateKey(bio, &pkey, nullptr, (void*)password.toUtf8().data());
    BIO_free(bio);

    if (!pkey) {
        emit operationComplete(false, "Failed to decrypt private key. Wrong password?");
        return false;
    }

    // Get RSA key from EVP_PKEY
    RSA *rsa = EVP_PKEY_get1_RSA(pkey);
    if (!rsa) {
        EVP_PKEY_free(pkey);
        emit operationComplete(false, "Failed to get RSA key");
        return false;
    }

    // Convert RSA to PEM format
    BIO *privBio = BIO_new(BIO_s_mem());
    PEM_write_bio_RSAPrivateKey(privBio, rsa, nullptr, nullptr, 0, nullptr, nullptr);

    char *privKeyPtr = nullptr;
    long privKeySize = BIO_get_mem_data(privBio, &privKeyPtr);
    QByteArray privateKey = QByteArray(privKeyPtr, privKeySize);

    // Open the encrypted file
    QFile inFile(inputFile);
    if (!inFile.open(QIODevice::ReadOnly)) {
        BIO_free(privBio);
        RSA_free(rsa);
        EVP_PKEY_free(pkey);
        emit operationComplete(false, "Failed to open input file");
        return false;
    }

    // Read the encrypted key size
    QDataStream stream(&inFile);
    stream.setVersion(QDataStream::Qt_5_15);

    qint32 keySize;
    stream >> keySize;

    if (keySize <= 0 || keySize > 1024) { // Sanity check
        inFile.close();
        BIO_free(privBio);
        RSA_free(rsa);
        EVP_PKEY_free(pkey);
        emit operationComplete(false, "Invalid file format");
        return false;
    }

    // Read the encrypted key
    QByteArray encryptedKey = inFile.read(keySize);
    if (encryptedKey.size() != keySize) {
        inFile.close();
        BIO_free(privBio);
        RSA_free(rsa);
        EVP_PKEY_free(pkey);
        emit operationComplete(false, "Failed to read encrypted key");
        return false;
    }

    // Read the IV
    QByteArray iv = inFile.read(16);
    if (iv.size() != 16) {
        inFile.close();
        BIO_free(privBio);
        RSA_free(rsa);
        EVP_PKEY_free(pkey);
        emit operationComplete(false, "Failed to read IV");
        return false;
    }

    // Read the encrypted data
    QByteArray encryptedData = inFile.readAll();
    inFile.close();

    // Decrypt the AES key with RSA
    QByteArray aesKey = rsaDecrypt(encryptedKey, privateKey);

    // Cleanup RSA resources
    BIO_free(privBio);
    RSA_free(rsa);
    EVP_PKEY_free(pkey);

    if (aesKey.isEmpty()) {
        emit operationComplete(false, "Failed to decrypt AES key");
        return false;
    }

    // Decrypt the data with AES
    QByteArray decryptedData = aesDecrypt(encryptedData, aesKey, iv);

    if (decryptedData.isEmpty()) {
        emit operationComplete(false, "AES decryption failed");
        return false;
    }

    // Write to output file
    QFile outFile(outputFile);
    if (!outFile.open(QIODevice::WriteOnly)) {
        emit operationComplete(false, "Failed to open output file");
        return false;
    }

    outFile.write(decryptedData);
    outFile.close();

    emit operationComplete(true, "File decrypted successfully with hybrid encryption (AES+RSA)");
    return true;
}

void CryptoManager::listFiles(const QString &directoryPath, const QStringList &suffixes)
{
    QDir dir(directoryPath);
    QStringList files = dir.entryList(QDir::Files | QDir::NoDotAndDotDot);

    foreach (const QString &file, files) {
        for (const QString &suffix : suffixes) {
            if (file.endsWith(suffix, Qt::CaseInsensitive)) {
                QFileInfo fileInfo(dir.filePath(file));
                emit fileNameSignal(file, fileInfo.lastModified().toSecsSinceEpoch());
                break;
            }
        }
    }
}

// Private helper methods

QByteArray CryptoManager::generateAESKey(const QString &password, const QByteArray &salt)
{
    // PBKDF2 implementation for key derivation
    QByteArray passwordData = password.toUtf8();

    unsigned char key[32]; // 256 bit key

    // Use OpenSSL's PKCS5_PBKDF2_HMAC with SHA-256
    PKCS5_PBKDF2_HMAC(
        passwordData.constData(),
        passwordData.length(),
        (const unsigned char*)salt.constData(),
        salt.length(),
        10000, // iterations
        EVP_sha256(),
        32, // key length
        key
        );

    return QByteArray(reinterpret_cast<char*>(key), 32);
}

QByteArray CryptoManager::generateRandomBytes(int length)
{
    QByteArray bytes;
    bytes.resize(length);

    // Use OpenSSL's RAND_bytes for true cryptographic randomness
    RAND_bytes((unsigned char*)bytes.data(), length);

    return bytes;
}

bool CryptoManager::saveKeyToFile(const QString &keyName, const QByteArray &publicKey, const QByteArray &encryptedPrivateKey)
{
    QJsonObject keyData;
    keyData["key_type"] = "RSA";
    keyData["public_key"] = QString(publicKey.toBase64());
    keyData["private_key"] = QString(encryptedPrivateKey.toBase64());

    QJsonDocument doc(keyData);
    QByteArray jsonData = doc.toJson();

    QFile file(getKeysFolderPath() + "/" + keyName + ".key");
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }

    file.write(jsonData);
    file.close();

    return true;
}

bool CryptoManager::saveAESKeyToFile(const QString &keyName, const QByteArray &encryptedKey, const QByteArray &salt)
{
    QJsonObject keyData;
    keyData["key_type"] = "AES";
    keyData["encrypted_key"] = QString(encryptedKey.toBase64());
    keyData["salt"] = QString(salt.toBase64());

    QJsonDocument doc(keyData);
    QByteArray jsonData = doc.toJson();

    QFile file(getKeysFolderPath() + "/" + keyName + ".aeskey");
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }

    file.write(jsonData);
    file.close();

    return true;
}

bool CryptoManager::loadKeyFromFile(const QString &keyName, QByteArray &publicKey, QByteArray &encryptedPrivateKey)
{
    QString fileName = keyName;
    if (!fileName.endsWith(".key")) {
        fileName += ".key";
    }

    QFile file(getKeysFolderPath() + "/" + fileName);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }

    QByteArray jsonData = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(jsonData);
    if (doc.isNull() || !doc.isObject()) {
        return false;
    }

    QJsonObject obj = doc.object();

    // Check key type
    QString keyType = obj["key_type"].toString();
    if (keyType != "RSA" && !keyType.isEmpty()) {
        return false;
    }

    publicKey = QByteArray::fromBase64(obj["public_key"].toString().toLatin1());
    encryptedPrivateKey = QByteArray::fromBase64(obj["private_key"].toString().toLatin1());

    return true;
}

bool CryptoManager::loadAESKeyFromFile(const QString &keyName, QByteArray &encryptedKey, QByteArray &salt)
{
    QString fileName = keyName;
    if (!fileName.endsWith(".aeskey")) {
        fileName += ".aeskey";
    }

    QFile file(getKeysFolderPath() + "/" + fileName);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }

    QByteArray jsonData = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(jsonData);
    if (doc.isNull() || !doc.isObject()) {
        return false;
    }

    QJsonObject obj = doc.object();

    // Check key type
    QString keyType = obj["key_type"].toString();
    if (keyType != "AES") {
        return false;
    }

    encryptedKey = QByteArray::fromBase64(obj["encrypted_key"].toString().toLatin1());
    salt = QByteArray::fromBase64(obj["salt"].toString().toLatin1());

    return true;
}

QString CryptoManager::getKeysFolderPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/keys";
}

QByteArray CryptoManager::aesEncrypt(const QByteArray &data, const QByteArray &key, const QByteArray &iv)
{
    // Padding is handled internally by EVP
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        return QByteArray();
    }

    if (EVP_EncryptInit_ex(ctx, EVP_aes_256_cbc(), nullptr,
                           (const unsigned char*)key.constData(),
                           (const unsigned char*)iv.constData()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return QByteArray();
    }

    // Prepare output buffer (slightly larger than input for padding)
    QByteArray output;
    output.resize(data.size() + AES_BLOCK_SIZE);

    int outlen1 = 0;
    if (EVP_EncryptUpdate(ctx, (unsigned char*)output.data(), &outlen1,
                          (const unsigned char*)data.constData(), data.size()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return QByteArray();
    }

    int outlen2 = 0;
    if (EVP_EncryptFinal_ex(ctx, (unsigned char*)output.data() + outlen1, &outlen2) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return QByteArray();
    }

    // Resize to actual encrypted size
    output.resize(outlen1 + outlen2);

    EVP_CIPHER_CTX_free(ctx);
    return output;
}

QByteArray CryptoManager::aesDecrypt(const QByteArray &data, const QByteArray &key, const QByteArray &iv)
{
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        return QByteArray();
    }

    if (EVP_DecryptInit_ex(ctx, EVP_aes_256_cbc(), nullptr,
                           (const unsigned char*)key.constData(),
                           (const unsigned char*)iv.constData()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return QByteArray();
    }

    // Prepare output buffer (same size as input, decrypted data will be smaller due to padding)
    QByteArray output;
    output.resize(data.size());

    int outlen1 = 0;
    if (EVP_DecryptUpdate(ctx, (unsigned char*)output.data(), &outlen1,
                          (const unsigned char*)data.constData(), data.size()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return QByteArray();
    }

    int outlen2 = 0;
    if (EVP_DecryptFinal_ex(ctx, (unsigned char*)output.data() + outlen1, &outlen2) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return QByteArray();
    }

    // Resize to actual decrypted size
    output.resize(outlen1 + outlen2);

    EVP_CIPHER_CTX_free(ctx);
    return output;
}

QByteArray CryptoManager::rsaEncrypt(const QByteArray &data, const QByteArray &publicKey)
{
    BIO *keyBio = BIO_new_mem_buf(publicKey.data(), publicKey.length());
    RSA *rsa = nullptr;

    PEM_read_bio_RSAPublicKey(keyBio, &rsa, nullptr, nullptr);
    BIO_free(keyBio);

    if (!rsa) {
        return QByteArray();
    }

    // Determine output size
    int keySize = RSA_size(rsa);
    QByteArray result;
    result.resize(keySize);

    // Encrypt with public key
    int outlen = RSA_public_encrypt(data.length(),
                                    (const unsigned char*)data.constData(),
                                    (unsigned char*)result.data(),
                                    rsa,
                                    RSA_PKCS1_PADDING);

    RSA_free(rsa);

    if (outlen == -1) {
        return QByteArray();
    }

    // Resize to actual size
    result.resize(outlen);
    return result;
}

QByteArray CryptoManager::rsaDecrypt(const QByteArray &data, const QByteArray &privateKey)
{
    BIO *keyBio = BIO_new_mem_buf(privateKey.data(), privateKey.length());
    RSA *rsa = nullptr;

    PEM_read_bio_RSAPrivateKey(keyBio, &rsa, nullptr, nullptr);
    BIO_free(keyBio);

    if (!rsa) {
        return QByteArray();
    }

    // Determine output size
    int keySize = RSA_size(rsa);
    QByteArray result;
    result.resize(keySize);

    // Decrypt with private key
    int outlen = RSA_private_decrypt(data.length(),
                                     (const unsigned char*)data.constData(),
                                     (unsigned char*)result.data(),
                                     rsa,
                                     RSA_PKCS1_PADDING);

    RSA_free(rsa);

    if (outlen == -1) {
        return QByteArray();
    }

    // Resize to actual size
    result.resize(outlen);
    return result;
}
