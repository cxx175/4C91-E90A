#include <stdio.h>

#include <dlfcn.h>

#include <stdarg.h>

#include "hook.h"



// 定义原始函数类型

typedef void (*lua_pushlstring_t)(void* L, const char* s, size_t len);



// 保存原始函数指针

static lua_pushlstring_t original_lua_pushlstring = NULL;


const char* base_path = "/data/app/~~y_DDmiMf31fbbGk0Yjuzsw==/com.xf.lcby.mi-HaCuwRBOm9vsztiCD4E4bA==/lib/arm64/";

    

// Hook 后的 lua_pushlstring 函数

void hook_lua_pushlstring(void* L, const char* s, size_t len) {

    LOGI("Hook lua_pushlstring 被调用");

    LOGI("字符串长度: %zu", len);

    

    // 打印字符串内容（限制长度）

    char preview[101] = {0};

    strncpy(preview, s, len < 100 ? len : 100);

    LOGI("字符串内容: %s", preview);

    

    // 调用原始函数

    original_lua_pushlstring(L, s, len);

}



// 加载依赖库

int load_dependencies() {


    const char* deps[] = {

        "libyim.so",

        "libcocos2dlua.so",

        NULL

    };

    

    for (int i = 0; deps[i] != NULL; i++) {

        char full_path[256];

        snprintf(full_path, sizeof(full_path), "%s%s", base_path, deps[i]);

        

        void* handle = dlopen(full_path, RTLD_NOW | RTLD_GLOBAL);

        if (!handle) {

            LOGE("无法加载库 %s: %s", full_path, dlerror());

            return -1;

        }

        LOGI("成功加载库: %s", full_path);

    }

    return 0;

}



// Hook 所有需要的函数

int hook_all_functions() {

    char full_path[256];

    snprintf(full_path, sizeof(full_path), "%slibcocos2dlua.so", base_path);

    

    // Hook lua_pushlstring

    void* pushlstring_addr = find_symbol(full_path, "lua_pushlstring");

    if (pushlstring_addr) {

        original_lua_pushlstring = (lua_pushlstring_t)pushlstring_addr;

        HookInfo pushlstring_hook;

        if (hook_function(pushlstring_addr, (void*)hook_lua_pushlstring, &pushlstring_hook) != 0) {

            LOGE("Hook lua_pushlstring 失败");

            return -1;

        }

    }

    

    return 0;

}



int main() {

    // 加载依赖库

    if (load_dependencies() != 0) {

        LOGE("加载依赖库失败");

        return -1;

    }

    

    // Hook 所有函数

    if (hook_all_functions() != 0) {

        LOGE("Hook 函数失败");

        return -1;

    }

    

    LOGI("Hook 成功，等待 Lua 代码执行...");

    

    // 保持程序运行

    while (1) {

        sleep(1);

    }

    

    return 0;

} 