local RobotMediator = class('RobotMediator', framework.Mediator)
RobotMediator.NAME  = "RobotMediator"

local cjson         = require( "cjson" )
local proxyUtils    = requireProxy( "proxyUtils" )
local skillUtils    = requireProxy( "skillUtils" )

RobotMediator.TIMER_INTERVAL = 0.1

function RobotMediator:ctor()
    RobotMediator.super.ctor( self, self.NAME )

    self._items                 = {}
    self._cdingTime             = {}

    self._cdingTime[51]         = 0

    self._launchTime            = 0
    self._trainingTime          = 0

    self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT1] = 0 
    self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT2] = 0
    self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT3] = 0 
    self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT4] = 0

    self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT1] = 0 
    self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT2] = 0
    self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT3] = 0 
    self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT4] = 0

    self._cdingTime[global.MMO.SETTING_IDX_PK_PROTECT] = 0
    self._cdingTime[global.MMO.SETTING_IDX_BESIEGE_FLEE] = 0
    self._cdingTime[global.MMO.SETTING_IDX_RED_BESIEGE_FLEE] = 0
    self._cdingTime[global.MMO.SETTING_IDX_ENEMY_ATTACK] = 0

    self._waitUseItems = {}
    self._cdJulingTime = 0 
end

function RobotMediator:listNotificationInterests()
    local noticeTable = global.NoticeTable
    return
    {
        noticeTable.PlayerPropertyInited,
        noticeTable.Bag_Oper_Data,
        noticeTable.QuickUseItemRmv,
        noticeTable.AutoUseJulingItem_Add,
    }
end


function RobotMediator:handleNotification(notification)
    local noticeID = notification:getName()
    local notices  = global.NoticeTable
    local data     = notification:getBody()

    if notices.PlayerPropertyInited == noticeID then
        self:Init()

    elseif notices.Bag_Oper_Data == noticeID then
        self:OnBagOperData(data)

    elseif notices.QuickUseItemRmv == noticeID then
        self:OnQuickUseItemRmv(data)

    elseif notices.AutoUseJulingItem_Add == noticeID then
        self:OnAddUseJulingItem(data)
    end
end

function RobotMediator:OnBagOperData(data)
    if data.opera == global.MMO.Operator_Sub and data.operID and data.operID[1].item then
        proxyUtils.unpackDrugByIndex(data.operID[1].item.Index)
    elseif (data.opera == global.MMO.Operator_Add or data.opera == global.MMO.Operator_Change) and data.operID and data.operID[1].item then
        self:OnAddUseJulingItem(data.operID[1].item)
    end
end

function RobotMediator:OnQuickUseItemRmv(data)
    if data.itemData and proxyUtils.findBagCountByIndex(data.itemData.Index) <= 0 then
        proxyUtils.unpackDrugByIndex(data.itemData.Index, true)
    end
end

function RobotMediator:Init()
    local facade                = global.Facade
    local propertyProxy         = facade:retrieveProxy( global.ProxyTable.PlayerProperty )
    self._buffProxy             = facade:retrieveProxy( global.ProxyTable.Buff )
    self._skillProxy            = facade:retrieveProxy( global.ProxyTable.Skill )
    self._assistProxy           = facade:retrieveProxy( global.ProxyTable.AssistProxy )
    self._playerPropertyProxy   = facade:retrieveProxy( global.ProxyTable.PlayerProperty )
    self._mapProxy              = facade:retrieveProxy( global.ProxyTable.Map )
    self._equipProxy            = facade:retrieveProxy( global.ProxyTable.Equip )
    self._itemUseProxy          = facade:retrieveProxy( global.ProxyTable.ItemUseProxy )
    self._bagProxy              = facade:retrieveProxy( global.ProxyTable.Bag )
    self._autoProxy             = facade:retrieveProxy( global.ProxyTable.Auto )
    self._inputProxy            = facade:retrieveProxy( global.ProxyTable.PlayerInputProxy )
    self._itemConfigProxy       = facade:retrieveProxy( global.ProxyTable.ItemConfigProxy )
    self._role                  = global.gamePlayerController:GetMainPlayer()

    self:TimerBegan()

    -- 药品

    self._items[51]             = SL:GetMetaValue("GAME_DATA", "fixItemDrug")
end

function RobotMediator:TimerBegan()
    if not self._timerID then
        local function callback(delta)
            self:Tick(delta)
        end
        self._timerID = Schedule(callback, self.TIMER_INTERVAL)
    end
end

function RobotMediator:TimerEnded()
    if self._timerID then
        UnSchedule(self._timerID)
        self._timerID = nil
    end
end

function RobotMediator:Tick(delta)
    -- 摆摊
    if false == CheckCanDoSomething(true) then
        return nil
    end

    -- check role
    self._role = global.gamePlayerController:GetMainPlayer()
    if self._role then
        -- 自动释放相关
        self:autoLaunch(delta)

        -- 自动练功
        self:autoTraining(delta)

        -- 自动使用修复神水
        self:autoUseFIXItem(delta)

        --hp保护
        self:autoHpProtect(delta)

        --mp保护
        self:autoMpProtect(delta)

        --红名保护 
        self:autoPkProtect(delta)

        -- 逃脱保护   
        self:autoBesiegeprotect(delta)

        --主动攻击敌人
        self:selectEnemy(delta)

        -- 自动使用聚灵珠
        self:AutoUseJuling(delta)
    end
end

function RobotMediator:selectEnemy(delta)
    if not self._mapProxy then
        return nil
    end
    if self._mapProxy:IsInSafeArea() then
        return nil
    end
    -- dead
    if self._role:IsDie() then
        return nil
    end
    local AutoProxy = global.Facade:retrieveProxy(global.ProxyTable.Auto)
    if not AutoProxy then
        return
    end
    if not AutoProxy:IsAFKState() and not AutoProxy:IsAutoFightState() then
        return false
    end
    local mainPlayer = global.gamePlayerController:GetMainPlayer()
    local mainPlayerID = global.gamePlayerController:GetMainPlayerID()
    if not mainPlayer or not mainPlayerID then
        return
    end

    self._cdingTime[global.MMO.SETTING_IDX_ENEMY_ATTACK] = self._cdingTime[global.MMO.SETTING_IDX_ENEMY_ATTACK] - delta

    local values = GET_SETTING(global.MMO.SETTING_IDX_ENEMY_ATTACK, true)--周围有敌人时主动攻击

    if self._cdingTime[global.MMO.SETTING_IDX_ENEMY_ATTACK] <= 0 and values[1] == 1 then
        local distance = tonumber(values[2]) or 8
        
        local PlayerInputProxy = global.Facade:retrieveProxy(global.ProxyTable.PlayerInputProxy)
        local targetID = PlayerInputProxy:GetTargetID()
        local targetActor = global.actorManager:GetActor(targetID)
        if targetActor and targetActor:IsPlayer() then
            return false
        end

        local playerVec, ncount = global.playerManager:GetPlayersInCurrViewField()
        local pMapX  = mainPlayer:GetMapX()
        local pMapY  = mainPlayer:GetMapY()

        for i = 1, ncount do
            local player = playerVec[i]
            if player and proxyUtils.checkLaunchTargetByID(player:GetID()) and not player:IsHumanoid() and math.abs(player:GetMapX() - pMapX) <= distance and math.abs(player:GetMapY() - pMapY) <= distance then
                PlayerInputProxy:SetTargetID(player:GetID())
                break
            end
        end

        self._cdingTime[global.MMO.SETTING_IDX_ENEMY_ATTACK] = 1
    end
end

function RobotMediator:autoBesiegeprotect(delta)
    if not self._mapProxy then
        return nil
    end
    if self._mapProxy:IsInSafeArea() then
        return nil
    end
    -- dead
    if self._role:IsDie() then
        return nil
    end

    local mainPlayer = global.gamePlayerController:GetMainPlayer()
    local mainPlayerID = global.gamePlayerController:GetMainPlayerID()
    if not mainPlayer or not mainPlayerID then
        return
    end

    local AutoProxy = global.Facade:retrieveProxy(global.ProxyTable.Auto)
    if not AutoProxy then
        return
    end
    local isAFKState = AutoProxy:IsAFKState()
    if not isAFKState then
        return
    end
    self._cdingTime[global.MMO.SETTING_IDX_BESIEGE_FLEE] = self._cdingTime[global.MMO.SETTING_IDX_BESIEGE_FLEE] - delta
    -- 逃脱保护
    local values = GET_SETTING(global.MMO.SETTING_IDX_BESIEGE_FLEE, true)--周围有多少敌人时使用
    if self._cdingTime[global.MMO.SETTING_IDX_BESIEGE_FLEE] <= 0 and values[1] == 1 then
        local distance = values[2] or 0
        local count = values[3] or 99
        local index = tonumber(values[4])
        if proxyUtils.checkIsEnoughEnemyPlayer(mainPlayerID, count, distance) and index then
            local used = self:autoUseItem({ index })
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_BESIEGE_FLEE] = 5
            end
        end
    end


    self._cdingTime[global.MMO.SETTING_IDX_RED_BESIEGE_FLEE] = self._cdingTime[global.MMO.SETTING_IDX_RED_BESIEGE_FLEE] - delta
    local values = GET_SETTING(global.MMO.SETTING_IDX_RED_BESIEGE_FLEE, true)--周围有红名时使用
    if self._cdingTime[global.MMO.SETTING_IDX_RED_BESIEGE_FLEE] <= 0 and values[1] == 1 then
        local distance = values[2] or 0
        local count = values[3] or 99
        local index = tonumber(values[4])
        if proxyUtils.checkIsEnoughRedNameEnemy(mainPlayerID, count, distance) and index then
            local used    = self:autoUseItem({ index })
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_RED_BESIEGE_FLEE] = 5
            end
        end
    end
end

function RobotMediator:autoPkProtect(delta)
    if not self._mapProxy then
        return nil
    end
    -- dead
    if self._role:IsDie() then
        return nil
    end

    local mainPlayer = global.gamePlayerController:GetMainPlayer()
    if not mainPlayer then
        return
    end
    self._cdingTime[global.MMO.SETTING_IDX_PK_PROTECT] = self._cdingTime[global.MMO.SETTING_IDX_PK_PROTECT] - delta

    local PKLv = mainPlayer:GetPKLv() or 0

    -- pk保护
    local values = GET_SETTING(global.MMO.SETTING_IDX_PK_PROTECT, true)--红名时使用
    if self._cdingTime[global.MMO.SETTING_IDX_PK_PROTECT] <= 0 and values[1] == 1 then
        if PKLv == 2 then
            local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
            local protectData = GameSettingProxy:getRankData(global.MMO.SETTING_IDX_PK_PROTECT)
            local used        = self:autoUseItem(protectData.indexs)
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_PK_PROTECT] = (protectData.time or 1000) / 1000
            end
        end
    end
end

function RobotMediator:autoMpProtect(delta)
    if not self._mapProxy then
        return nil
    end
    -- dead
    if self._role:IsDie() then
        return nil
    end

    self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT1] = self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT1] - delta
    self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT2] = self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT2] - delta
    self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT3] = self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT3] - delta
    self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT4] = self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT4] - delta

    -- 自动吃药相关
    local mppercent     = self._playerPropertyProxy:GetRoleMPPercent()
    local maxMP         = self._playerPropertyProxy:GetRoleMaxMP()

    -- mp保护1
    if self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT1] <= 0 then
        local value     = GET_SETTING(global.MMO.SETTING_IDX_MP_PROTECT1, true)
        local enable    = value[1] == 1
        local percent   = value[2] or 50
        if enable and maxMP > 0 and mppercent <= percent then
            local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
            local protectData = GameSettingProxy:getRankData(global.MMO.SETTING_IDX_MP_PROTECT1)
            local used        = self:autoUseItem(protectData.indexs)
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT1] = (protectData.time or 1000) / 1000
            end
        end
    end

    -- mp保护2
    if self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT2] <= 0 then
        local value     = GET_SETTING(global.MMO.SETTING_IDX_MP_PROTECT2, true)
        local enable    = value[1] == 1
        local percent   = value[2] or 50
        if enable and maxMP > 0 and mppercent <= percent then
            local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
            local protectData = GameSettingProxy:getRankData(global.MMO.SETTING_IDX_MP_PROTECT2)
            local used        = self:autoUseItem(protectData.indexs)
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT2] = (protectData.time or 1000) / 1000
            end
        end
    end

    --mp保护3
    if self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT3] <= 0 then
        local value     = GET_SETTING(global.MMO.SETTING_IDX_MP_PROTECT3, true)
        local enable    = value[1] == 1
        local percent   = value[2] or 50
        if enable and maxMP > 0 and mppercent <= percent then
            local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
            local protectData = GameSettingProxy:getRankData(global.MMO.SETTING_IDX_MP_PROTECT3)
            local used        = self:autoUseItem(protectData.indexs)
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT3] = (protectData.time or 1000) / 1000
            end
        end
    end

    --mp保护4
    if self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT4] <= 0 then
        local value     = GET_SETTING(global.MMO.SETTING_IDX_MP_PROTECT4, true)
        local enable    = value[1] == 1
        local percent   = value[2] or 50
        if enable and maxMP > 0 and mppercent <= percent then
            local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
            local protectData = GameSettingProxy:getRankData(global.MMO.SETTING_IDX_MP_PROTECT4)
            local used        = self:autoUseItem(protectData.indexs)
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_MP_PROTECT4] = (protectData.time or 1000) / 1000
            end
        end
    end
end

function RobotMediator:autoHpProtect(delta)
    if not self._mapProxy then
        return nil
    end
    -- dead
    if self._role:IsDie() then
        return nil
    end

    self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT1] = self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT1] - delta
    self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT2] = self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT2] - delta
    self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT3] = self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT3] - delta
    self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT4] = self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT4] - delta

    -- 自动吃药相关
    local hppercent     = self._playerPropertyProxy:GetRoleHPPercent()
    local maxHP         = self._playerPropertyProxy:GetRoleMaxHP()

    -- hp保护1
    if self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT1] <= 0 then
        local value     = GET_SETTING(global.MMO.SETTING_IDX_HP_PROTECT1, true)
        local enable    = value[1] == 1
        local percent   = value[2] or 50
        if enable and maxHP > 0 and hppercent <= percent then
            local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
            local protectData = GameSettingProxy:getRankData(global.MMO.SETTING_IDX_HP_PROTECT1)
            local used        = self:autoUseItem(protectData.indexs, true)
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT1] = (200 or 1000) / 1000
            end
        end
    end

    -- hp保护2
    if self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT2] <= 0 then
        local value     = GET_SETTING(global.MMO.SETTING_IDX_HP_PROTECT2, true)
        local enable    = value[1] == 1
        local percent   = value[2] or 50
        if enable and maxHP > 0 and hppercent <= percent then
            local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
            local protectData = GameSettingProxy:getRankData(global.MMO.SETTING_IDX_HP_PROTECT2)
            local used        = self:autoUseItem(protectData.indexs, true)
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT2] = (protectData.time or 1000) / 1000
            end
        end
    end

    -- hp保护3
    if self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT3] <= 0 then
        local value     = GET_SETTING(global.MMO.SETTING_IDX_HP_PROTECT3, true)
        local enable    = value[1] == 1
        local percent   = value[2] or 50
        if enable and maxHP > 0 and hppercent <= percent then
            local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
            local protectData = GameSettingProxy:getRankData(global.MMO.SETTING_IDX_HP_PROTECT3)
            local used        = self:autoUseItem(protectData.indexs, true)
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT3] = (protectData.time or 1000) / 1000
            end
        end
    end

    -- hp保护4
    if self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT4] <= 0 then
        local value         = GET_SETTING(global.MMO.SETTING_IDX_HP_PROTECT4, true)
        local enable        = value[1] == 1
        local percent       = value[2] or 50
        if enable and maxHP > 0 and hppercent <= percent then
            local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
            local protectData = GameSettingProxy:getRankData(global.MMO.SETTING_IDX_HP_PROTECT4)
            local used        = self:autoUseItem(protectData.indexs, true)
            if used then
                self._cdingTime[global.MMO.SETTING_IDX_HP_PROTECT4] = (protectData.time or 1000) / 1000
            end
        end
    end
end

function RobotMediator:autoUseItem(items, isHpProtect)
    if not self._mapProxy then
        return false
    end
    local ItemManagerProxy = global.Facade:retrieveProxy(global.ProxyTable.ItemManagerProxy)
    if not ItemManagerProxy then
        return false
    end

    for _, itemIndex in ipairs(items) do
        repeat
            local unpack = proxyUtils.unpackDrugByIndex(itemIndex)
            if unpack then
                return true
            end

            local item = proxyUtils.findItemByIndex(itemIndex)

            if item then
                --回城石和随机石
                if ItemManagerProxy:IsCityStone(item) or ItemManagerProxy:IsRandStone(item) then
                    if self._mapProxy:IsInSafeArea() then -- 安全区不使用
                        break
                    end
                    if isHpProtect then --  hp保护检查 复活
                        -- 复活戒指准备就绪，回城/随机保护不生效
                        if CHECK_SETTING(global.MMO.SETTING_IDX_REVIVE_PROTECT) == 1 and self._playerPropertyProxy:IsCanRevive() then
                            break
                        end
                    end
                end
                SL:RequestUseItem(item)
                return true
            end
        until true
    end
    return false
end


-------------------------------------------------------
-- 修复神水
function RobotMediator:autoUseFIXItem(delta)
    if not self._mapProxy then
        return nil
    end
    if self._role:IsDie() then
        return nil
    end

    local function isInvalidEquip(item)
        -- 祝福罐
        if item.StdMode == 96 then
            return true
        end
        -- 护身符
        if item.StdMode == 25 then
            return true
        end

        -- 气血石
        if item.StdMode == 7 and item.Shape == 1 then
            return true
        end
        -- 幻魔石
        if item.StdMode == 7 and item.Shape == 2 then
            return true
        end
        -- 魔血石
        if item.StdMode == 7 and item.Shape == 3 then
            return true
        end
    end

    -- cding
    self._cdingTime[51]    = self._cdingTime[51] - delta
    if self._cdingTime[51] <= 0 then
        if CHECK_SETTING(51) == 1 then
            -- 是否有损坏的装备
            local found             = false
            local equipData         = self._equipProxy:GetEquipData()
            local articleType       = self._itemConfigProxy:GetArticleType()
            local checkArticleType  = {[articleType.TYPE_FIX] = true }
            for _, equip in pairs(equipData) do
                if equip.Dura < 1000 and not isInvalidEquip(equip) then
                    if not self._itemConfigProxy:GetItemArticle(equip.Index, checkArticleType) then
                        local fixValue = equip.Bind or 0
                        found = not CheckBit(fixValue, 3) --是否已经修复过了
                        if found then 
                            break
                        end
                    end
                end
            end

            -- 是否有
            if found then
                local items         = self._items[51]
                local result        = self:autoUseItem(items)
                local cdtime        = self._mapProxy:GetEatItemSpeed() or 1000
                self._cdingTime[51] = cdtime / 1000
            end
        end
    end
end
-------------------------------------------------------


-------------------------------------------------------
-- 自动释放
function RobotMediator:autoLaunch(delta)
    self._launchTime = self._launchTime + delta
    if self._launchTime <= 1 then
        return false
    end
    self._launchTime = 0


    local skillID, destPos = skillUtils.findRobotLaunchSkill()
    if not skillID then
        return nil
    end

    local inputProxy        = global.Facade:retrieveProxy(global.ProxyTable.PlayerInputProxy)
    local skillID           = skillID
    local destPos           = destPos
    local priority          = global.MMO.LAUNCH_PRIORITY_ROBOT
    local launchType        = global.MMO.LAUNCH_TYPE_AUTO
    local launchData        = {skillID = skillID, destPos = destPos, priority = priority, launchType = launchType}
    global.Facade:sendNotification(global.NoticeTable.InputLaunch, launchData)
end

-------------------------------------------------------
-- 自动练功
function RobotMediator:autoTraining(delta)
    local value = GET_SETTING(38, true)
    if not value[1] or value[1] == 0 then
        return false
    end

    local skillID           = tonumber(value[1])
    local delay             = value[2] or 3
    self._trainingTime      = self._trainingTime + delta
    if self._trainingTime >= delay and skillID ~= -1 then
        self._trainingTime = 0

        if self._skillProxy:CheckAbleToLaunch(skillID) ~= 1 then
            return nil
        end
        if self._assistProxy:checkIsBusy() then
            return nil
        end
        if self._inputProxy:GetTargetID() then
            local target        = global.actorManager:GetActor(self._inputProxy:GetTargetID())
            if target and not target:IsMonster() then
                return nil
            end
        end
    
        local skillID           = skillID
        local destPos           = self._inputProxy:getMainPlayerFaceDest()
        local priority          = global.MMO.LAUNCH_PRIORITY_ROBOT
        local launchType        = global.MMO.LAUNCH_TYPE_AUTO
        local launchData        = {skillID = skillID, destPos = destPos, priority = priority, launchType = launchType}
        global.Facade:sendNotification(global.NoticeTable.InputLaunch, launchData)
    end
end

-------------------------------------------------------
-- 自动使用聚灵珠
function RobotMediator:OnAddUseJulingItem(item)
    if not item or not next(item) then
        return
    end

    local AutoProxy = global.Facade:retrieveProxy(global.ProxyTable.Auto)
    local isAuto = AutoProxy:IsAutoUseJuling()
    if not isAuto then
        return
    end

    local ItemManagerProxy = global.Facade:retrieveProxy(global.ProxyTable.ItemManagerProxy)
    local ItemUseProxy = global.Facade:retrieveProxy(global.ProxyTable.ItemUseProxy)
    if item.StdMode == 49 and item.Dura >= item.DuraMax then
        local itemData = ItemManagerProxy:GetItemDataByMakeIndex(item.MakeIndex)
        if itemData then
            table.insert(self._waitUseItems, item.MakeIndex)
        end
    end

end

function RobotMediator:AutoUseJuling(delta)
    self._cdJulingTime = self._cdJulingTime - delta
    if self._cdJulingTime <= 0 then
        local AutoProxy = global.Facade:retrieveProxy(global.ProxyTable.Auto)
        local isAuto = AutoProxy:IsAutoUseJuling()
        if not isAuto then
            self._waitUseItems = {}
            return
        end

        local ItemManagerProxy = global.Facade:retrieveProxy(global.ProxyTable.ItemManagerProxy)
        local ItemUseProxy = global.Facade:retrieveProxy(global.ProxyTable.ItemUseProxy)

        if self._waitUseItems and next(self._waitUseItems) then
            for i, makeIndex in ipairs(self._waitUseItems) do
                local item = ItemManagerProxy:GetItemDataByMakeIndex(makeIndex)
                if not item then
                    table.remove(self._waitUseItems, i)
                end
                if item and item.StdMode == 49 and item.Dura >= item.DuraMax then
                    ItemUseProxy:UseItem(item)
                    local cdTime = self._mapProxy:GetEatItemSpeed() and (self._mapProxy:GetEatItemSpeed() + 150) or 1000
                    self._cdJulingTime = cdTime / 1000
                    table.remove(self._waitUseItems, i)
                    return
                end
            end
        end
        
    end
end


return RobotMediator