#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <filesystem>
#include <zip.h>

bool extractAndroidManifest(const std::string& apkPath, const std::string& outputPath) {
    int err = 0;
    zip* apkArchive = zip_open(apkPath.c_str(), 0, &err);
    if (apkArchive == nullptr) {
        std::cerr << "无法打开APK文件: " << apkPath << " (错误码: " << err << ")" << std::endl;
        return false;
    }

    // 在ZIP文件中查找AndroidManifest.xml
    struct zip_stat st;
    zip_stat_init(&st);
    if (zip_stat(apkArchive, "AndroidManifest.xml", 0, &st) != 0) {
        std::cerr << "在APK中找不到AndroidManifest.xml" << std::endl;
        zip_close(apkArchive);
        return false;
    }

    // 打开文件
    zip_file* file = zip_fopen(apkArchive, "AndroidManifest.xml", 0);
    if (file == nullptr) {
        std::cerr << "无法打开AndroidManifest.xml" << std::endl;
        zip_close(apkArchive);
        return false;
    }

    // 读取文件内容
    std::vector<char> buffer(st.size);
    if (zip_fread(file, buffer.data(), st.size) != st.size) {
        std::cerr << "读取AndroidManifest.xml失败" << std::endl;
        zip_fclose(file);
        zip_close(apkArchive);
        return false;
    }

    // 关闭ZIP文件中的AndroidManifest.xml
    zip_fclose(file);
    zip_close(apkArchive);

    // 写入到输出文件
    std::ofstream outFile(outputPath, std::ios::binary);
    if (!outFile) {
        std::cerr << "无法创建输出文件: " << outputPath << std::endl;
        return false;
    }
    outFile.write(buffer.data(), buffer.size());
    outFile.close();

    std::cout << "AndroidManifest.xml已提取到: " << outputPath << std::endl;
    std::cout << "请注意: 提取的AndroidManifest.xml是二进制格式，需要使用额外工具进行解析" << std::endl;
    return true;
}

int main(int argc, char* argv[]) {
    std::string apkPath = "/storage/emulated/0/MT2/apks/皇城传说_4.6.6.apk";
    std::string outputPath = "/storage/emulated/0/MT2/apks/abase/AndroidManifest.xml";
    
    if (!extractAndroidManifest(apkPath, outputPath)) {
        return 1;
    }

    return 0;
} 