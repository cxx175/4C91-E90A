#include "main.h"





// 全局变量定义




char gameName[256] = "器灵宝塔";


char key[50] = "34UFXMgtkz";


char sign[50] = "4meJnPyl";


char outputDir[256] = "/storage/emulated/0/MT2/apks/%s/assetsjm/mod_fgcq/stab/scripts/";


char dstLuaDir[256] = "/storage/emulated/0/MT2/apks/%s/assets/mod_fgcq/stab/scripts/";


char srcAssets[256] = "/storage/emulated/0/MT2/apks/abase/";


char dstAssets[256] = "/storage/emulated/0/MT2/apks/%s/";


xxtea_long signLen = 0;





// 统计变量定义


int totalFiles = 0;


int processedFiles = 0;


int successFiles = 0;


int failedFiles = 0;





// 预分配内存的缓冲区定义


unsigned char* g_buffer = NULL;


size_t g_bufferSize = 0;





int main(int argc, char *argv[])


{


    char fullOutputDir[MAX_PATH];


    char fullDstLuaDir[MAX_PATH];


    char fullDstAssets[MAX_PATH];





    snprintf(fullOutputDir, sizeof(fullOutputDir), outputDir, gameName);


    snprintf(fullDstLuaDir, sizeof(fullDstLuaDir), dstLuaDir, gameName);


    snprintf(fullDstAssets, sizeof(fullDstAssets), dstAssets, gameName);





    signLen = strlen(sign);


    


    printf("\n[+] 开始复制文件...\n");


    if (!copyDirectory(srcAssets, fullDstAssets)) {


        printf("[-] 错误：文件复制失败\n");


        return 1;


    }


    printf("[+] 文件复制完成！\n");





    printf("\n[+] 开始加密Lua文件...\n");


    printf("[+] 源目录: %s\n", fullOutputDir);


    printf("[+] 目标目录: %s\n", fullDstLuaDir);


    encryptLuaFiles(fullOutputDir, fullDstLuaDir);


    printf("\n[+] Lua文件加密完成！\n");


    printf("[+] 成功: %d 个文件\n", successFiles);


    printf("[+] 失败: %d 个文件\n", failedFiles);





    if (g_buffer) {


        delete[] g_buffer;


        g_buffer = NULL;


    }





    return 0;


}