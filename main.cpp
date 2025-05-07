#include "main.h"
#include "luareplace.h"
#include <string>

// 全局变量定义

//测试
char packageName[256] = "com.tencent.tmgp.qlbt.cly";
char gameName[256] = "器灵宝塔";
char path[256] = "/data/user/0/%s/files/mod_fgcq/stab/scripts/";
char key[50] = "34UFXMgtkz";
char sign[50] = "4meJnPyl";
char outputDir[256] = "/storage/emulated/0/MT2/apks/%s/assetsjm/mod_fgcq/stab/scripts/";
char dstLuaDir[256] = "/storage/emulated/0/MT2/apks/%s/assets/mod_fgcq/stab/scripts/";
char srcAssets[256] = "/storage/emulated/0/MT2/apks/abase/";
char dstAssets[256] = "/storage/emulated/0/MT2/apks/%s/";
xxtea_long signLen = 0;
int isSourceFile = 0;

// 统计变量定义
int totalFiles = 0;
int processedFiles = 0;
int successFiles = 0;
int failedFiles = 0;

// 预分配内存的缓冲区定义
unsigned char* g_buffer = NULL;
size_t g_bufferSize = 0;

// 替换Lua文件内容函数
int replaced() {
    // 使用全局变量gameName，并转换为std::string类型
    std::string gameNameStr(gameName);
    // 替换主循环相关代码
    Replacemainloop(gameNameStr);
    // 替换野蛮锁定相关代码
    ReplaceYemanLock(gameNameStr);
    // 替换攻击状态相关代码
    ReplaceAttackState(gameNameStr);
    // 替换冲刺状态相关代码
    ReplaceDashState(gameNameStr);
    // 替换奔跑状态相关代码
    ReplaceRunState(gameNameStr);
    // 替换技能状态相关代码
    ReplaceSkillState(gameNameStr);
    // 替换行走状态相关代码
    ReplaceWalkState(gameNameStr);
    // 替换技能公共CD相关代码
    ReplaceSkillProxy_CD(gameNameStr);
    // 替换自动拾取相关代码
    ReplacedropItemController(gameNameStr);

/////////////////////////////////////////////////////////////////////////


    // 替换自动HP保护相关代码
    ReplaceAutoHpProtect(gameNameStr);
    // 替换低血小退相关代码
    ReplacePlayerPropertyProxy(gameNameStr);
    // 十步一杀锁定 
    ReplaceSBYSLock(gameNameStr);
    return 0;
}
int main(int argc, char *argv[])
{
    // 初始化路径
    char fullPath[MAX_PATH];
    char fullOutputDir[MAX_PATH];
    char fullDstLuaDir[MAX_PATH];
    char fullDstAssets[MAX_PATH];

    // 构建完整路径
    snprintf(fullPath, sizeof(fullPath), path, packageName);
    snprintf(fullOutputDir, sizeof(fullOutputDir), outputDir, gameName);
    snprintf(fullDstLuaDir, sizeof(fullDstLuaDir), dstLuaDir, gameName);
    snprintf(fullDstAssets, sizeof(fullDstAssets), dstAssets, gameName);

    // 初始化签名长度
    signLen = strlen(sign);
    
    // 检查源路径类型
    struct stat st;
    if (stat(fullPath, &st) != 0) {
        printf("[-] 错误：无法访问源路径 %s\n", fullPath);
        return 1;
    }
    isSourceFile = !S_ISDIR(st.st_mode);
    
    // 清理输出目录路径
    int len = strlen(fullOutputDir);
    if (len > 0 && fullOutputDir[len-1] == '/') {
        fullOutputDir[len-1] = '\0';
    }
    
    // 打印初始信息
    printf("[+] 源路径: %s (%s)\n", fullPath, isSourceFile ? "文件" : "目录");
    printf("[+] 解密密钥: %s\n", key);
    printf("[+] 签名: %s\n", sign);
    printf("[+] 签名长度: %ld\n", signLen);
    printf("[+] 输出目录: %s\n", fullOutputDir);

    // 创建输出目录
    if (!createDirectory(fullOutputDir)) {
        printf("[-] 错误：无法创建输出目录 %s\n", fullOutputDir);
        return 1;
    }

    // 计算文件总数
    if (!isSourceFile) {
        printf("[+] 正在计算文件总数...\n");
        countFiles(fullPath);
        printf("\n[+] 共发现 %d 个文件需要处理\n", totalFiles);
    } else {
        totalFiles = 1;
    }

    // 解密Lua文件
    printf("\n[+] 开始解密Lua文件...\n");
    if (isSourceFile) {
        decrypt(fullPath);
    } else {
        print_file_info(fullPath);
    }

    // 打印解密结果
    printf("\n[+] 解密完成！\n");
    printf("[+] 成功: %d 个文件\n", successFiles);
    printf("[+] 失败: %d 个文件\n", failedFiles);

    // 调用replaced函数进行Lua文件替换
    printf("\n[+] 开始替换Lua文件内容...\n");
    replaced();
    printf("[+] Lua文件内容替换完成！\n");

    // 复制文件
    printf("\n[+] 开始复制文件...\n");
    if (!copyDirectory(srcAssets, fullDstAssets)) {
        printf("[-] 错误：文件复制失败\n");
        return 1;
    }
    printf("[+] 文件复制完成！\n");

    // 加密Lua文件
    printf("\n[+] 开始加密Lua文件...\n");
    printf("[+] 源目录: %s\n", fullOutputDir);
    printf("[+] 目标目录: %s\n", fullDstLuaDir);
    encryptLuaFiles(fullOutputDir, fullDstLuaDir);
    printf("\n[+] Lua文件加密完成！\n");
    printf("[+] 成功: %d 个文件\n", successFiles);
    printf("[+] 失败: %d 个文件\n", failedFiles);

    // 清理资源
    if (g_buffer) {
        delete[] g_buffer;
        g_buffer = NULL;
    }

    return 0;
}