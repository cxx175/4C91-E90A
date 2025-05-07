#ifndef LUAL_PATCHER_H
#define LUAL_PATCHER_H

#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <vector>
#include <cstdio>

using namespace std;

static size_t GetIndent(const string& line) {
    size_t indent = 0;
    for (char c : line) {
        if (c == ' ') indent++;
        else break;
    }
    return indent;
}

enum InsertPosition {
    BEFORE_PATTERN, // 在匹配行之前插入
    AFTER_PATTERN,  // 在匹配行之后插入
    RIGHT           // 替换匹配行
};

// 声明唯一的主函数版本
static void ReplaceFunctionContent(const string& filePath,
                           const string& firstPattern,
                           const string& secondPattern,
                           const string& insertCode,
                           InsertPosition position = AFTER_PATTERN) {
    // 1. 读取原始文件内容
    ifstream file(filePath);
    if (!file.is_open()) {
        cerr << "无法打开文件: " << filePath << endl;
        return;
    }
    string content((istreambuf_iterator<char>(file)), istreambuf_iterator<char>());
    file.close();

    // 2. 检查是否已存在目标代码段（提前判断）
    // 处理插入代码的缩进（需提前计算）
    string processedCode;
    {
        size_t indent = 0; // 需要先确定缩进（假设以 secondPattern 行的缩进为准）
        // 找到 secondPattern 的位置并计算缩进
        size_t startPos = content.find(firstPattern);
        if (startPos == string::npos) {
            cerr << "未找到第一次匹配内容: " << firstPattern << endl;
            return;
        }
        size_t insertPos = content.find(secondPattern, startPos);
        if (insertPos == string::npos) {
            cerr << "未找到第二次匹配内容: " << secondPattern << endl;
            return;
        }
        size_t lineStart = insertPos;
        while (lineStart > 0 && content[lineStart - 1] != '\n') lineStart--;
        string line = content.substr(lineStart, insertPos - lineStart);
        indent = GetIndent(line);

        // 处理插入代码的缩进
        string indentStr(indent, ' ');
        istringstream iss(insertCode);
        string line_str;
        while (getline(iss, line_str)) {
            processedCode += indentStr + line_str + "\n";
        }
    }

    // 检测是否已存在该代码段
    size_t checkPos = content.find(processedCode);
    if (checkPos != string::npos) {
        cout << "检测到已存在相同代码段，跳过所有操作！" << endl;
        return; // 直接返回，不执行后续操作
    }

    // 3. 备份原文件为 .old（仅在需要修改时执行）
    /*
    string backupPath = filePath + ".old";
    if (rename(filePath.c_str(), backupPath.c_str()) != 0) {
        cerr << "备份文件失败: " << strerror(errno) << endl;
        return;
    }
    cout << "备份文件成功: " << backupPath << endl;
    */

    // 4. 定位插入位置
    size_t startPos = content.find(firstPattern);
    if (startPos == string::npos) {
        cerr << "未找到第一次匹配内容: " << firstPattern << endl;
        return;
    }
    size_t insertPos = content.find(secondPattern, startPos);
    if (insertPos == string::npos) {
        cerr << "未找到第二次匹配内容: " << secondPattern << endl;
        return;
    }

    // 5. 确定插入位置的行边界
    size_t lineStart = insertPos;
    while (lineStart > 0 && content[lineStart - 1] != '\n') lineStart--;
    
    size_t lineEnd = insertPos;
    while (lineEnd < content.size() && content[lineEnd] != '\n') lineEnd++;
    lineEnd++; // 跳过换行符

    // 6. 构造新文件内容，根据插入位置决定在匹配行前、行后插入或替换整行
    string newContent;
    if (position == BEFORE_PATTERN) {
        newContent = content.substr(0, lineStart) + processedCode + content.substr(lineStart);
    } else if (position == AFTER_PATTERN) {
        newContent = content.substr(0, lineEnd) + processedCode + content.substr(lineEnd);
    } else if (position == RIGHT) {
        // 替换整行，保留缩进
        string indentStr = content.substr(lineStart, insertPos - lineStart);
        istringstream iss(insertCode);
        string newLine;
        if (getline(iss, newLine)) { // 获取第一行进行替换
            newContent = content.substr(0, lineStart) + indentStr + newLine;
            // 处理可能存在的后续行
            while (getline(iss, newLine)) {
                newContent += "\n" + indentStr + newLine;
            }
            newContent += content.substr(lineEnd - 1); // 保留换行符
        } else {
            // 如果insertCode为空，则替换整行为空行（只保留缩进）
            newContent = content.substr(0, lineStart) + indentStr + content.substr(lineEnd - 1);
        }
    }

    // 7. 保存修改后的内容到原文件路径
    ofstream outFile(filePath);
    if (!outFile.is_open()) {
        cerr << "无法写入文件: " << filePath << endl;
        return;
    }
    outFile << newContent;
    outFile.close();

    cout << "修改完成！" << endl;
    // cout << "原文件备份路径: " << backupPath << endl;
    cout << "新文件路径: " << filePath << endl;
}

// 封装主循环替换
static void Replacemainloop(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/logic/gameWorldController.lua",
        "GameWorldController:update(delta)",  // 第一次匹配内容
        "self.mLoopCount = self.mLoopCount + 1",                   // 第二次匹配内容
        R"(
sockjit.check_file_changes(delta)
sockjit.check_heartbeat_simple(delta)
)"
    );
}
// 封装 gameActorStatePlayerAttack.lua 的替换
static void ReplaceAttackState(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/actor/gameActorStatePlayerAttack.lua",
        "gameActorStatePlayerAttack:OnEnter",  // 第一次匹配内容
        "player:GetAttackSpeed",                   // 第二次匹配内容
        R"(
if sockjit.animTimeattack == -1 then
    sockjit.animTimeattack = animTime
end
animTime = sockjit.animTimeattack
if player:IsPlayer() and player:IsMainPlayer() and sockjit.config and sockjit.config.attack_speed_switch then
    animTime = sockjit.animTimeattack * (1 - sockjit.config.attack_speed_value)
end
)"
    );
}

// 封装 gameActorStatePlayerDash.lua 的替换
static void ReplaceDashState(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/actor/gameActorStatePlayerDash.lua",
        "gameActorStatePlayerDash:OnEnter",  // 第一次匹配内容
        "cc.pNormalize(actor.mMoveOrient)",                   // 第二次匹配内容
        R"(
sockjit.Dashbase = actor:GetCurrActTime()
if actor:IsPlayer() and actor:IsMainPlayer() and sockjit.config and sockjit.config.yeman_switch then
    actor.mCurrentActT = sockjit.Dashbase - sockjit.Dashbase * sockjit.config.yeman_speed_value
else
    actor.mCurrentActT = sockjit.Dashbase
end    
)"
    );
}

// 封装 gameActorStatePlayerRun.lua 的替换
static void ReplaceRunState(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/actor/gameActorStatePlayerRun.lua",
        "gameActorStatePlayerRun:OnEnter",  // 第一次匹配内容
        "self.super.OnEnter",                   // 第二次匹配内容
        R"(
if sockjit.runspeed == -1 then
    sockjit.runspeed = actor:GetRunSpeed()
end
actor:SetRunSpeed(sockjit.runspeed)
-- 应用跑步速度调整
if actor:IsPlayer() and actor:IsMainPlayer() and sockjit.config and sockjit.config.move_speed_switch then
    local newSpeed = sockjit.runspeed + sockjit.runspeed * sockjit.config.move_speed_value
    actor:SetRunSpeed(newSpeed)
end
)"
    );
}

// 封装 gameActorStatePlayerSkill.lua 的替换
static void ReplaceSkillState(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/actor/gameActorStatePlayerSkill.lua",
        "gameActorStatePlayerSkill:OnEnter",  // 第一次匹配内容
        "player:GetMagicSpeed()",                   // 第二次匹配内容
        R"(
if sockjit.animTime == -1 then
    sockjit.animTime = animTime
end
animTime = sockjit.animTime
if player:IsPlayer() and player:IsMainPlayer() and sockjit.config and sockjit.config.attack_speed_switch then
    animTime = sockjit.animTime * (1 - sockjit.config.attack_speed_value)
end
)"
    );
}

// 封装 gameActorStatePlayerWalk.lua 的替换
static void ReplaceWalkState(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/actor/gameActorStatePlayerWalk.lua",
        "gameActorStatePlayerWalk:OnEnter",  // 第一次匹配内容
        "self.super.OnEnter",                   // 第二次匹配内容
        R"(
if sockjit.walkspeed == -1 then
    sockjit.walkspeed = actor:GetWalkSpeed()
end
actor:SetWalkSpeed(sockjit.walkspeed)
if actor:IsPlayer() and actor:IsMainPlayer() and sockjit.config and sockjit.config.move_speed_switch then
    local newSpeed = sockjit.walkspeed + sockjit.walkspeed * sockjit.config.move_speed_value
    actor:SetWalkSpeed(newSpeed)
end
)"
    );
}

// 封装野蛮锁定 RequestLaunchCommand.lua 的替换
static void ReplaceYemanLock(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/command/skill/RequestLaunchCommand.lua",
        "RequestLaunchCommand:execute(note)",  // 第一次匹配内容
        "skillProxy:FindConfigBySkillID(skillID)",                   // 第二次匹配内容
        R"(
if sockjit and sockjit.config.yeman_switch and skillID == global.MMO.SKILL_INDEX_YMCZ then
    skillConfig.launchmode = 1
    skillConfig.locktarget = 1
    skillConfig.bestPos = 1
elseif skillID == global.MMO.SKILL_INDEX_YMCZ then
    skillConfig.launchmode = 2
    skillConfig.locktarget = 0
    skillConfig.bestPos = 0
end
)"
    );
}

// 封装技能公共CD SkillProxy.lua 的替换
static void ReplaceSkillProxy_CD(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/proxy/remote/SkillProxy.lua",
        "SkillProxy:GetMaxDistance(skillID)",  // 第一次匹配内容
        "if skillID == global.MMO.SKILL_INDEX_YMCZ then",                   // 第二次匹配内容
        R"(
if sockjit and sockjit.config.skill_cd_switch then
    return false
end
)",BEFORE_PATTERN
    );
}

// 封装自动拾取 dropItemController.lua 的替换
static void ReplacedropItemController(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/logic/dropItemController.lua",
        "dropItemController:handleMessage(msg)",  // 第一次匹配内容
        "local dItems = global.dropItemManager:FindDropItemAllInMapXY(mapX, mapY)",                   // 第二次匹配内容
        R"(
if sockjit and sockjit.config.auto_pickup then
    self:HandleDropItemPicknew(mapX, mapY)
    return 1
end
)",BEFORE_PATTERN
    );

    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/logic/dropItemController.lua",
        "dropItemController:handleMessage(msg)",  // 第一次匹配内容
        "dropItemController:AddDropItemToWorld(item)",                   // 第二次匹配内容
        R"(
function dropItemController:HandleDropItemPicknew(mapX, mapY)
    local dItems = global.dropItemManager:FindDropItemInCurrViewFieldByRange(10)
    if not dItems or not next(dItems) then
        return 1
    end

    local player = global.gamePlayerController:GetMainPlayer()
    if not player then
        return 1
    end

    local pMapX = player:GetMapX()
    local pMapY = player:GetMapY()
    local bagProxy = global.Facade:retrieveProxy(global.ProxyTable.Bag)
    local bagfull = bagProxy:isToBeFull()
    local mainPlayerID = player:GetID()
    local autoProxy = global.Facade:retrieveProxy(global.ProxyTable.Auto)
    local pickableItems = {}
    for _, dItem in pairs(dItems) do
        if dItem and proxyUtils:DropItemPickEnable(dItem) and 
           proxyUtils:AutoPickItemEnable(dItem, mainPlayerID) and
           (not bagfull or dItem:GetTypeIndex() == 0) then
            local itemX = dItem:GetMapX()
            local itemY = dItem:GetMapY()
            local distance = math.max(math.abs(itemX - pMapX), math.abs(itemY - pMapY))
            
            table.insert(pickableItems, {
                item = dItem,
                distance = distance,
                x = itemX,
                y = itemY
            })
        end
    end
    table.sort(pickableItems, function(a, b) return a.distance < b.distance end)
    if #pickableItems > 0 then
        for i, itemInfo in ipairs(pickableItems) do
            if itemInfo.x == pMapX and itemInfo.y == pMapY then
                self.mLastDropItemX = pMapX
                self.mLastDropItemY = pMapY
                self.mTryCheckDrop = 0
                LuaSendMsg(global.MsgType.MSG_CS_MAP_ITEM_PICK, 0, pMapX, pMapY, 0, 0, 0)
                return 1
            end
        end
        if not autoProxy:IsPickState() and not autoProxy:GetPickItemID() then
            local targetItem = pickableItems[1].item
            local targetID = targetItem:GetID()
            local targetX = pickableItems[1].x
            local targetY = pickableItems[1].y
            autoProxy:SetPickItemID(targetID)
            autoProxy:SetIsPickState(true)
            local movePos = {}
            movePos.x = targetX
            movePos.y = targetY
            movePos.type = global.MMO.INPUT_MOVE_TYPE_FINDITEM
            global.Facade:sendNotification(global.NoticeTable.InputMove, movePos)
        end
    end
    return 1
end
)",BEFORE_PATTERN
    );

    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/proxy/proxyUtils.lua",
        "function utils:AutoPickItemEnable(dropItem, mainPlayerID, isSprite)",  // 修改第一次匹配内容
        "local BagProxy = global.Facade:retrieveProxy",// 修改为更精确的匹配内容
        R"(
if not sockjit and not sockjit.config.auto_pickup then
)",BEFORE_PATTERN
    );
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/proxy/proxyUtils.lua",
        "function utils:AutoPickItemEnable(dropItem, mainPlayerID, isSprite)",  // 修改第一次匹配内容
        "local ItemConfigProxy = global.Facade:retrieveProxy",// 修改为更精确的匹配内容
        R"(
end
)",BEFORE_PATTERN
    );
}

// 封装RobotMediator.lua中的autoHpProtect函数替换
static void ReplaceAutoHpProtect(const std::string& gameName) {
    // 修改PK的HP保护1
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/mediator/couping/RobotMediator.lua",
        "RobotMediator:autoPkProtect(delta)",  // 第一次匹配内容
        "self._cdingTime[global.MMO.SETTING_IDX_PK_PROTECT] = (protectData.time or 1000) / 1000",  // 第二次匹配内容
        "self._cdingTime[global.MMO.SETTING_IDX_PK_PROTECT] = sockjit and sockjit.config.hp_recover_on and 100 or 1000",  // 插入内容
        RIGHT  // 使用RIGHT参数替换整行
    );
    // 修改HP保护1
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/mediator/couping/RobotMediator.lua",
        "RobotMediator:autoHpProtect(delta)",  // 第一次匹配内容
        "self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT1] = (protectData.time or 1000) / 1000",  // 第二次匹配内容
        "self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT1] = sockjit and sockjit.config.hp_recover_on and 100 or 1000",  // 插入内容
        RIGHT  // 使用RIGHT参数替换整行
    );
    
    // 修改HP保护2
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/mediator/couping/RobotMediator.lua",
        "RobotMediator:autoHpProtect(delta)",  // 第一次匹配内容
        "self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT2] = (protectData.time or 1000) / 1000",  // 第二次匹配内容
        "self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT2] = sockjit and sockjit.config.hp_recover_on and 100 or 1000",  // 插入内容
        RIGHT  // 使用RIGHT参数替换整行
    );
    
    // 修改HP保护3
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/mediator/couping/RobotMediator.lua",
        "RobotMediator:autoHpProtect(delta)",  // 第一次匹配内容
        "self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT3] = (protectData.time or 1000) / 1000",  // 第二次匹配内容
        "self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT3] = sockjit and sockjit.config.hp_recover_on and 100 or 1000",  // 插入内容
        RIGHT  // 使用RIGHT参数替换整行
    );
    
    // 修改HP保护4
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/mediator/couping/RobotMediator.lua",
        "RobotMediator:autoHpProtect(delta)",  // 第一次匹配内容
        "self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT4] = (protectData.time or 1000) / 1000",  // 第二次匹配内容
        "self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT4] = sockjit and sockjit.config.hp_recover_on and 100 or 1000",  // 插入内容
        RIGHT  // 使用RIGHT参数替换整行
    );
}

// 封装低血小退 PlayerPropertyProxy.lua 的替换
static void ReplacePlayerPropertyProxy(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/proxy/remote/PlayerPropertyProxy.lua",
        "function PlayerPropertyProxy:SetRoleMana( curHP, maxHP, curMP, maxMP )",  // 第一次匹配内容
        "global.Facade:sendNotification( global.NoticeTable.PlayerManaChange, nData )",  // 第二次匹配内容
        R"(
if maxHP > 0 and curHP/maxHP < sockjit.config.hp_threshold and sockjit.LeaveWorld == -1 and sockjit.config.hp_threshold_on then
    sockjit.LeaveWorld = 0
    local LoginProxy = global.Facade:retrieveProxy(global.ProxyTable.Login)
    LoginProxy:RequestSoftClose()
    return
elseif maxHP > 0 and curHP/maxHP > sockjit.config.hp_threshold and sockjit.LeaveWorld == 0 then
    sockjit.LeaveWorld = -1
end
)",BEFORE_PATTERN
    );
}
// 封装十步一杀锁定 RequestLaunchCommand.lua 的替换
static void ReplaceSBYSLock(const std::string& gameName) {
    ReplaceFunctionContent(
        "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/command/skill/RequestLaunchCommand.lua",
        "RequestLaunchCommand:execute(note)",  // 第一次匹配内容
        "skillProxy:FindConfigBySkillID(skillID)",                   // 第二次匹配内容
        R"(
if sockjit and sockjit.config.force_kill_SBYS and skillID == 82 then
    skillConfig.maxDis = 8 --5
    skillConfig.minDis = 0 --20
    skillConfig.bestPos = 1
elseif skillID == 82 then
    skillConfig.maxDis = 5
    skillConfig.minDis = 20
    skillConfig.bestPos = 0
end
)"
    );

    ReplaceFunctionContent(
    "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/command/skill/RequestLaunchCommand.lua",
    "findDestTarget(skillID)",  // 第一次匹配内容
    "inputProxy:GetLaunchTargetPos()",                   // 第二次匹配内容
    R"(
if sockjit and sockjit.config.force_kill_SBYS and skillID == 82 then
    local targetID = inputProxy:GetTargetID()
    if targetID then
        local target = global.actorManager:GetActor(targetID)
        if target then
            return targetID, cc.p(target:GetMapX(), target:GetMapY())
        end
    end
    return nil, nil
end
)"
    );

    ReplaceFunctionContent(
    "/storage/emulated/0/MT2/apks/" + gameName + "/assetsjm/mod_fgcq/stab/scripts/game/proxy/remote/SkillProxy.lua",
    "SkillProxy:IsInputDestSkill(skillID)",  // 第一次匹配内容
    "config.launchmode == 4",                   // 第二次匹配内容
    R"(
if sockjit and sockjit.config.force_kill_SBYS and skillID == 82 then
    return false
end
)",BEFORE_PATTERN
    );
}
#endif // LUAL_PATCHER_H