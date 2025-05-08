#ifndef MAIN_H


#define MAIN_H





#include <stdio.h>


#include <stdlib.h>


#include <string.h>


#include <unistd.h>


#include <dirent.h>


#include <sys/types.h>


#include <sys/stat.h>


#include "xxtea.h"


#include <iostream>


#include <vector>


#include <fcntl.h>





using namespace std;





#define MAX_PATH 512





// 全局变量声明


extern char packageName[256];


extern char gameName[256];


extern char path[256];


extern char key[50];


extern char sign[50];


extern char outputDir[256];


extern char dstLuaDir[256];


extern char srcAssets[256];


extern char dstAssets[256];


extern xxtea_long signLen;


extern int isSourceFile;





// 统计变量声明


extern int totalFiles;


extern int processedFiles;


extern int successFiles;


extern int failedFiles;





// 预分配内存的缓冲区


extern unsigned char* g_buffer;


extern size_t g_bufferSize;





// 函数声明


inline void ensureBufferSize(size_t requiredSize);


inline bool createDirectory(const char *dir);


inline void updateFileStats(bool success);


inline bool copyFile(const char* src, const char* dst);


inline bool copyDirectory(const char* srcDir, const char* dstDir);


inline void encryptFile(const char* src, const char* dst);


inline void encryptLuaFiles(const char* srcDir, const char* dstDir);





// 显示进度


inline void showProgress(const char* operation, int current, int total) {


    if (total > 0 && current % 10 == 0) {


        float progress = (float)current / total * 100;


        printf("\r[+] %s进度: %d/%d (%.1f%%)", operation, current, total, progress);


        fflush(stdout);


    }


}





// 更新文件统计


inline void updateFileStats(bool success) {


    processedFiles++;


    if (success) {


        successFiles++;


    } else {


        failedFiles++;


    }


    showProgress("处理文件", processedFiles, totalFiles);


}





// 计算文件总数


inline void countFiles(const char* dir) {


    DIR *dfd;


    struct dirent *dp;


    struct stat st;


    char name[MAX_PATH];





    if ((dfd = opendir(dir)) == NULL) {


        return;


    }





    while ((dp = readdir(dfd)) != NULL) {


        if (strcmp(dp->d_name, ".") == 0 || strcmp(dp->d_name, "..") == 0) {


            continue;


        }





        snprintf(name, sizeof(name), "%s/%s", dir, dp->d_name);


        if (stat(name, &st) == 0) {


            if (S_ISDIR(st.st_mode)) {


                countFiles(name);


            } else {


                totalFiles++;


            }


        }


    }





    closedir(dfd);


}





// 目录遍历


inline void dirwalk(char *dir, void (*func)(char *)) {


    char name[MAX_PATH];


    struct dirent *dp;


    DIR *dfd;





    if ((dfd = opendir(dir)) == NULL) {


        fprintf(stderr, "dirwalk: can't open %s\n", dir);


        return;


    }





    while ((dp = readdir(dfd)) != NULL) {


        if (strcmp(dp->d_name, ".") == 0 || strcmp(dp->d_name, "..") == 0) {


            continue;


        }





        if (strlen(dir) + strlen(dp->d_name) + 2 > sizeof(name)) {


            fprintf(stderr, "dirwalk : name %s %s too long\n", dir, dp->d_name);


        } else {


            sprintf(name, "%s/%s", dir, dp->d_name);


            (*func)(name);


        }


    }


    


    closedir(dfd);


}





// 确保缓冲区足够大


inline void ensureBufferSize(size_t requiredSize) {


    if (g_buffer == NULL || g_bufferSize < requiredSize) {


        if (g_buffer) {


            delete[] g_buffer;


        }


        g_bufferSize = requiredSize;


        g_buffer = new unsigned char[g_bufferSize];


    }


}





// 创建目录


inline bool createDirectory(const char *dir) {


    if (!dir || strlen(dir) == 0) {


        return false;


    }


    


    char tmp[MAX_PATH];


    char *p = NULL;


    


    snprintf(tmp, sizeof(tmp), "%s", dir);


    p = tmp;


    


    if (*p == '/') {


        p++;


    }


    


    while (*p != '\0') {


        if (*p == '/') {


            *p = '\0';


            if (access(tmp, F_OK) != 0) {


                if (mkdir(tmp, 0755) != 0) {


                    return false;


                }


            }


            *p = '/';


        }


        p++;


    }





    if (access(tmp, F_OK) != 0) {


        if (mkdir(tmp, 0755) != 0) {


            return false;


        }


    }


    


    return true;


}





// 获取文件名部分


inline char* getFileName(const char* path) {


    const char* lastSlash = strrchr(path, '/');


    if (lastSlash) {


        return (char*)lastSlash + 1;


    }


    return (char*)path;


}





// 处理目录


inline void processDirectory(char *name) {


    char outputPath[MAX_PATH];


    


    if (isSourceFile) {


        snprintf(outputPath, sizeof(outputPath), "%s", outputDir);


    } else {


        snprintf(outputPath, sizeof(outputPath), "%s%s", outputDir, name + strlen(path));


    }


    


    createDirectory(outputPath);


    printf("[+] Created directory structure: %s\n", outputPath);


}





// 获取文件的父目录


inline char* getParentDir(const char* path) {


    static char parent[MAX_PATH];


    strcpy(parent, path);


    


    const char* lastSlash = strrchr(parent, '/');


    if (lastSlash) {


        *lastSlash = '\0';


        return parent;


    }


    


    strcpy(parent, ".");


    return parent;


}





// 解密文件


inline void decrypt(char *name) {


    struct stat st;


    if (stat(name, &st) != 0) {


        updateFileStats(false);


        return;


    }


    


    if (S_ISDIR(st.st_mode)) {


        processDirectory(name);


        dirwalk(name, decrypt);


        return;


    }


    


    FILE *fp, *outFp;


    char outputPath[MAX_PATH];


    char fullOutputDir[MAX_PATH];





    snprintf(fullOutputDir, sizeof(fullOutputDir), outputDir, gameName);





    fp = fopen(name, "rb");


    if (fp == NULL) {


        updateFileStats(false);


        return;


    }





    fseek(fp, 0L, SEEK_END);


    long len = ftell(fp);


    fseek(fp, 0L, SEEK_SET);





    if (len <= signLen) {


        fclose(fp);


        updateFileStats(false);


        return;


    }





    ensureBufferSize(len);


    if (fread(g_buffer, sizeof(unsigned char), len, fp) != len) {


        fclose(fp);


        updateFileStats(false);


        return;


    }


    fclose(fp);





    if (memcmp(g_buffer, sign, signLen) != 0) {


        updateFileStats(false);


        return;


    }





    xxtea_long ret_length = 0;


    xxtea_long keyLen = strlen(key);


    unsigned char *result = xxtea_decrypt(g_buffer + signLen, (xxtea_long)len - signLen, (unsigned char *)key, keyLen, &ret_length);





    if (result == NULL || ret_length == 0) {


        updateFileStats(false);


        return;


    }





    if (isSourceFile) {


        snprintf(outputPath, sizeof(outputPath), "%s/%s", fullOutputDir, getFileName(name));


    } else {


        const char* basePath = "/mod_fgcq/stab/scripts/";


        const char* pos = strstr(name, basePath);


        if (pos) {


            pos += strlen(basePath);


            snprintf(outputPath, sizeof(outputPath), "%s/%s", fullOutputDir, pos);


        } else {


            snprintf(outputPath, sizeof(outputPath), "%s/%s", fullOutputDir, getFileName(name));


        }


    }





    const char* lastSlash = strrchr(outputPath, '/');


    if (lastSlash) {


        *lastSlash = '\0';


        createDirectory(outputPath);


        *lastSlash = '/';


    }





    outFp = fopen(outputPath, "wb");


    if (outFp == NULL) {


        free(result);


        updateFileStats(false);


        return;


    }


    


    size_t written = fwrite(result, 1, ret_length, outFp);


    fclose(outFp);





    if (written != ret_length) {


        free(result);


        updateFileStats(false);


        return;


    }





    free(result);


    updateFileStats(true);


}





// 打印文件信息并处理


inline void print_file_info(char *name) {


    struct stat stbuf;





    if (stat(name, &stbuf) == -1) {


        fprintf(stderr, "file size: open %s failed\n", name);


        return;


    }





    if ((stbuf.st_mode & S_IFMT) == S_IFDIR) {


        dirwalk(name, print_file_info);


    } else {


        decrypt(name);


    }


}





// 复制文件


inline bool copyFile(const char* src, const char* dst) {


    FILE *srcFile, *dstFile;


    char buffer[4096];


    size_t bytesRead;





    srcFile = fopen(src, "rb");


    if (srcFile == NULL) {


        printf("[-] 无法打开源文件: %s\n", src);


        return false;


    }





    char parentDir[MAX_PATH];


    strcpy(parentDir, dst);


    const char* lastSlash = strrchr(parentDir, '/');


    if (lastSlash) {


        *lastSlash = '\0';


        if (!createDirectory(parentDir)) {


            fclose(srcFile);


            return false;


        }


    }





    dstFile = fopen(dst, "wb");


    if (dstFile == NULL) {


        printf("[-] 无法创建目标文件: %s\n", dst);


        fclose(srcFile);


        return false;


    }





    while ((bytesRead = fread(buffer, 1, sizeof(buffer), srcFile)) > 0) {


        if (fwrite(buffer, 1, bytesRead, dstFile) != bytesRead) {


            fclose(srcFile);


            fclose(dstFile);


            return false;


        }


    }





    fclose(srcFile);


    fclose(dstFile);


    printf("[+] 复制文件成功: %s -> %s\n", src, dst);


    return true;


}





// 复制目录


inline bool copyDirectory(const char* srcDir, const char* dstDir) {


    DIR *dir;


    struct dirent *entry;


    struct stat st;


    char srcPath[MAX_PATH], dstPath[MAX_PATH];





    if ((dir = opendir(srcDir)) == NULL) {


        printf("[-] Cannot open source directory: %s\n", srcDir);


        return false;


    }





    if (!createDirectory(dstDir)) {


        closedir(dir);


        return false;


    }





    while ((entry = readdir(dir)) != NULL) {


        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {


            continue;


        }





        snprintf(srcPath, sizeof(srcPath), "%s/%s", srcDir, entry->d_name);


        snprintf(dstPath, sizeof(dstPath), "%s/%s", dstDir, entry->d_name);





        if (stat(srcPath, &st) != 0) {


            continue;


        }





        if (S_ISDIR(st.st_mode)) {


            if (!copyDirectory(srcPath, dstPath)) {


                closedir(dir);


                return false;


            }


        } else {


            copyFile(srcPath, dstPath);


        }


    }





    closedir(dir);


    return true;


}





// 加密文件


inline void encryptFile(const char* src, const char* dst) {


    FILE *srcFile, *dstFile;


    unsigned char *encrypted;


    xxtea_long dataLen, encryptedLen;





    srcFile = fopen(src, "rb");


    if (srcFile == NULL) {


        updateFileStats(false);


        return;


    }





    fseek(srcFile, 0L, SEEK_END);


    dataLen = ftell(srcFile);


    fseek(srcFile, 0L, SEEK_SET);





    ensureBufferSize(dataLen);


    if (fread(g_buffer, sizeof(unsigned char), dataLen, srcFile) != dataLen) {


        fclose(srcFile);


        updateFileStats(false);


        return;


    }


    fclose(srcFile);





    char parentDir[MAX_PATH];


    strcpy(parentDir, dst);


    const char* lastSlash = strrchr(parentDir, '/');


    if (lastSlash) {


        *lastSlash = '\0';


        createDirectory(parentDir);


    }





    xxtea_long keyLen = strlen(key);


    encrypted = xxtea_encrypt(g_buffer, dataLen, (unsigned char *)key, keyLen, &encryptedLen);





    if (encrypted == NULL || encryptedLen == 0) {


        updateFileStats(false);


        return;


    }





    dstFile = fopen(dst, "wb");


    if (dstFile == NULL) {


        free(encrypted);


        updateFileStats(false);


        return;


    }





    fwrite(sign, 1, signLen, dstFile);


    fwrite(encrypted, 1, encryptedLen, dstFile);


    fclose(dstFile);





    free(encrypted);


    updateFileStats(true);


}





// 加密Lua文件


inline void encryptLuaFiles(const char* srcDir, const char* dstDir) {


    DIR *dir;


    struct dirent *entry;


    struct stat st;


    char srcPath[MAX_PATH], dstPath[MAX_PATH];





    if ((dir = opendir(srcDir)) == NULL) {


        return;


    }





    createDirectory(dstDir);





    totalFiles = 0;


    processedFiles = 0;


    successFiles = 0;


    failedFiles = 0;





    vector<string> dirStack;


    dirStack.push_back(srcDir);


    vector<string> dstStack;


    dstStack.push_back(dstDir);





    while (!dirStack.empty()) {


        string currentDir = dirStack.back();


        string currentDstDir = dstStack.back();


        dirStack.pop_back();


        dstStack.pop_back();





        DIR *currentDirPtr = opendir(currentDir.c_str());


        if (currentDirPtr == NULL) continue;





        while ((entry = readdir(currentDirPtr)) != NULL) {


            if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {


                continue;


            }





            snprintf(srcPath, sizeof(srcPath), "%s/%s", currentDir.c_str(), entry->d_name);


            


            string relativePath = currentDir.substr(strlen(srcDir));


            if (!relativePath.empty() && relativePath[0] == '/') {


                relativePath = relativePath.substr(1);


            }


            


            if (!relativePath.empty()) {


                snprintf(dstPath, sizeof(dstPath), "%s/%s/%s", dstDir, relativePath.c_str(), entry->d_name);


            } else {


                snprintf(dstPath, sizeof(dstPath), "%s/%s", dstDir, entry->d_name);


            }





            const char* lastSlash = strrchr(dstPath, '/');


            if (lastSlash) {


                *lastSlash = '\0';


                createDirectory(dstPath);


                *lastSlash = '/';


            }





            if (stat(srcPath, &st) != 0) continue;





            if (S_ISDIR(st.st_mode)) {


                dirStack.push_back(srcPath);


                dstStack.push_back(dstPath);


            } else {


                int len = strlen(entry->d_name);


                if (len > 4 && strcmp(entry->d_name + len - 4, ".lua") == 0) {


                    totalFiles++;


                    encryptFile(srcPath, dstPath);


                }


            }


        }





        closedir(currentDirPtr);


    }


}





#endif 