local RemoteProxy         = requireProxy( "remote/RemoteProxy" )
local PlayerPropertyProxy = class( "PlayerPropertyProxy", RemoteProxy )
PlayerPropertyProxy.NAME  = global.ProxyTable.PlayerProperty

local cjson = require( "cjson" )

function PlayerPropertyProxy:ctor()
    PlayerPropertyProxy.super.ctor( self )

    self._data          = {}
    self._attr          = {}
    self._isInited      = false
    self._isAlive       = true
    self._nameColor     = 255
    self._feature          =          -- 外观ID
    {
        clothID              = 0,
        weaponID             = 0,
        shieldID             = 0,
        wingsID              = 0,
        hairID               = 0,
        leftWeaponID         = 0,
    }
    self._internalData  = {}          -- 内功数据

    self._godMgicShowSetting = true --设置显示神魔
    self._superEquipShowSetting = true --设置时装显示
    --主角切页开关
    self._mainPlayerPageSwitch = {
        -- [SLDefine.PlayerPage.MAIN_PLAYER_LAYER_SUPER_EQUIP] = false --nil/true为开启；false为关闭   神装默认为关闭
    }
    self._mainLookPlayerPageSwitch = {
        [SLDefine.PlayerPage.MAIN_PLAYER_LAYER_EQUIP] = true,
        [SLDefine.PlayerPage.MAIN_PLAYER_LAYER_TITLE] = true,
        [SLDefine.PlayerPage.MAIN_PLAYER_LAYER_SUPER_EQUIP] = true,
    }

    self._lastAttr          = {}
    self._isRide            = 0

    self._not_run          = false   --是否禁跑
    self._canChangeMode    = {
        [global.MMO.HAM_ALL]  = true,
        [global.MMO.HAM_PEACE] = true,
        [global.MMO.HAM_DEAR]  = true,
        [global.MMO.HAM_MASTER] = true,
        [global.MMO.HAM_GROUP]  = true,
        [global.MMO.HAM_GUILD]  = true,
        [global.MMO.HAM_SHANE]  = true,
        [global.MMO.HAM_CAMP]   = false,
        [global.MMO.HAM_NATION] = true,
    }

    self._attr_not_hint = {} --不弹出属性飘字提示

    self._is_shabake_member = false --是否是沙巴克成员
    self._is_shabake_admin = false  --是否是沙巴克城主

    self._nationid = nil            -- 国家
    self._pointList  = nil          -- 解析后的经验配置数据

    self._extraComboBJRate = {}     -- 连击格子额外加暴击几率

    self:initLoadConfig()
end

function PlayerPropertyProxy:initLoadConfig()
    local attrNotHintArray = string.split(SL:GetMetaValue("GAME_DATA","attr_not_hint") or "","#")
    for i,v in ipairs( attrNotHintArray ) do
        local attid = tonumber( v )
        if attid then
            self._attr_not_hint[attid] = attid
        end
    end

    -- 解析经验配置
    if SL:GetMetaValue("GAME_DATA","EXPcoordinate") then
        self._pointList = {}
        local slicesP   = string.split(SL:GetMetaValue("GAME_DATA","EXPcoordinate"), "|")
        -- 下标： 1 移动端位置XY  2 PC端位置XY  3 颜色FColor#BColor  4 满足经验值出提示
        for i=1,4 do
            local pointXY   = string.split(slicesP[i] or "0#0","#")
            local X         = tonumber(pointXY[1]) or ( i == 3 and 255 or 0)
            local Y         = tonumber(pointXY[2]) or 0
            if i == 4 then
                self._pointList[i] = X
            else
                self._pointList[i] = {X = X, Y = Y}
            end
        end

        SL:SetMetaValue("GAME_DATA","pointList",self._pointList)
    end


end

-- 获取国家id
function PlayerPropertyProxy:GetNationID()
    if self._nationid and self._nationid > 0 then
        return self._nationid
    end
    return nil
end

--判断是否加入了国家
function PlayerPropertyProxy:IsJoinNation()
    local nationid = self:GetNationID()
    if nationid and nationid > 0 then
        return true
    end
    return false
end

function PlayerPropertyProxy:IsInited()
    return self._isInited
end

function PlayerPropertyProxy:SetInited()
    self._isInited = true
end

-- 角色是否活着
function PlayerPropertyProxy:IsAlive()
    return self._isAlive
end

function PlayerPropertyProxy:setAlive(alive)
    self._isAlive = alive

    if alive then
        global.Facade:sendNotification(global.NoticeTable.MainPlayerRevive)
        SLBridge:onLUAEvent(LUA_EVENT_MAIN_PLAYER_REVIVE)
        ssr.ssrBridge:OnMainPlayerRevive()
    else
        global.Facade:sendNotification(global.NoticeTable.MainPlayerDie)
        SLBridge:onLUAEvent(LUA_EVENT_MAIN_PLAYER_DIE)
        ssr.ssrBridge:OnMainPlayerDie()
    end
end

-- uid
function PlayerPropertyProxy:GetRoleUID()
    return global.gamePlayerController:GetMainPlayerID()
end


-- 等级
function PlayerPropertyProxy:GetRoleLevel()
    return self._data.level or 0
end
function PlayerPropertyProxy:SetRoleLevel(level)
    self._data.level = level
end
function PlayerPropertyProxy:GetLastLevel()
    return self._data.lastlevel
end
function PlayerPropertyProxy:SetLastLevel( level )
    self._data.lastlevel = level
end

-- 主角名字
function PlayerPropertyProxy:GetName()
    return self._data.name or ""
end
function PlayerPropertyProxy:SetName(name)
    self._data.name = name
end

-- 行会名字
function PlayerPropertyProxy:GetGuildName()
    return self._data.guildName
end
function PlayerPropertyProxy:SetGuildName(guildname)
    self._data.guildName = guildname
end


-- 职业
function PlayerPropertyProxy:GetRoleJob()
    return self._data.job or global.MMO.ACTOR_PLAYER_JOB_FIGHTER
end
function PlayerPropertyProxy:SetRoleJob(job)
    local lastJob = self:GetRoleJob()
    self._data.job = job
    if lastSex ~= sex then
        global.Facade:sendNotification(global.NoticeTable.PlayerJobChange, job)
    end
end
function PlayerPropertyProxy:GetRoleJobName()
    return GetJobName(self:GetRoleJob())
end


-- 性别
function PlayerPropertyProxy:GetRoleSex()
    return self._data.sex
end
function PlayerPropertyProxy:SetRoleSex(sex)
    local lastSex = self:GetRoleSex()
    self._data.sex = sex
    if lastSex ~= sex then
        global.Facade:sendNotification(global.NoticeTable.PlayerSexChange, sex)
    end
end


-- 转生
function PlayerPropertyProxy:GetRoleReinLv()
    return self._data.reinlv
end

function PlayerPropertyProxy:SetRoleReinLv(relevel)
    self._data.reinlv = relevel
end

function PlayerPropertyProxy:GetLastReinLevel()
    return self._data.lastReinlevel
end

function PlayerPropertyProxy:SetLastReinLevel(level)
    self._data.lastReinlevel = level
end


-- 外观
function PlayerPropertyProxy:GetFeature() 
    return self._feature
end

function PlayerPropertyProxy:SetFeature( feature ) 
    self._feature.clothID  = feature.clothID
    self._feature.weaponID = feature.weaponID
    self._feature.shieldID = feature.shieldID
    self._feature.wingsID  = feature.wingsID
    self._feature.hairID   = feature.hairID
    self._feature.leftWeaponID = feature.leftWeaponID
end


-- PK模式
function PlayerPropertyProxy:GetPKMode()
    return self._data.pkMode or global.MMO.HAM_ALL
end

function PlayerPropertyProxy:SetPKMode(pkmode)
    self._data.pkMode = pkmode
end

function PlayerPropertyProxy:IsShowCurMode( pkmode )
    return self._canChangeMode[pkmode]
end

function PlayerPropertyProxy:RequestChangePKMode(state)
    if not self._canChangeMode[state] then
        global.Facade:sendNotification(global.NoticeTable.SystemTips, GET_STRING( 30023010 ))
        return
    end
    LuaSendMsg( global.MsgType.MSG_CS_REQUEST_PK_STATE, state )
end

function PlayerPropertyProxy:handle_MSG_SC_PLAYER_PK_STATE( msg )
    local header    = msg:GetHeader()
    local pkMode    = header.recog
    local errorCode = header.param1

    if errorCode == -1 then
        global.Facade:sendNotification(global.NoticeTable.SystemTips, GET_STRING( 30023010 ))
        return
    end

    self:SetPKMode(pkMode)
    global.Facade:sendNotification(global.NoticeTable.PlayerPKModeChange, pkMode)

    ssr.ssrBridge:OnChangePKStateSuccess(pkMode)

    SLBridge:onLUAEvent(LUA_EVENT_PKMODECHANGE, pkMode)
end

--获取玩家状态的脚本的变量
function PlayerPropertyProxy:GetVariableInfo()
    return self._data.infoEx or ""
end

function PlayerPropertyProxy:SetVariableInfo(variable_info)
    self._data.infoEx = variable_info
end

function PlayerPropertyProxy:SetInternalData(data)
    local lastLv = self._internalData.level or 0
    self._internalData.force = data.InternalForce or 0              -- 内力值
    self._internalData.maxForce = data.MaxInternalForce or 0        -- 内力值上限
    self._internalData.exp = data.InternalEXP or 0                  -- 内功经验值
    self._internalData.maxExp = data.MaxInternalEXP or 0            -- 内功经验值上限
    self._internalData.level = data.InternalLevel or 0              -- 内功等级
    self._internalData.maxDZValue = data.MaxDZXYValue or 0          -- 最大斗转星移值
    if lastLv ~= self._internalData.level then
        global.Facade:sendNotification(global.NoticeTable.PlayerInternalLevelChange)
        SLBridge:onLUAEvent(LUA_EVENT_PLAYER_INTERNAL_LEVEL_CHANGE, {lastLevel = lastLv, curLevel = self._internalData.level})
    end
    if lastLv == 0 and self._internalData.level > lastLv then
        SLBridge:onLUAEvent(LUA_EVENT_PLAYER_LEARNED_INTERNAL)
    end
end

function PlayerPropertyProxy:GetInternalData()
    return self._internalData
end

function PlayerPropertyProxy:SetInternalExp(value, changed)
    self._internalData.exp = value
    SL:onLUAEvent(LUA_EVENT_PLAYER_INTERNAL_EXP_CHANGE, {changed = changed})
end

function PlayerPropertyProxy:SetIForceData(force, maxForce)
    if force then
        self._internalData.force = force
    end
    if maxForce then
        self._internalData.maxForce = maxForce
    end
    SL:onLUAEvent(LUA_EVENT_PLAYER_INTERNAL_FORCE_CHANGE)
end

-- hp
function PlayerPropertyProxy:GetRoleCurrHP()
    return self._data.curHP or 0
end

function PlayerPropertyProxy:GetRoleMaxHP()
    return self._data.maxHP or 1
end

function PlayerPropertyProxy:GetRoleHPPercent()
    return self:GetRoleCurrHP() / self:GetRoleMaxHP() * 100
end

-- mp
function PlayerPropertyProxy:GetRoleCurrMP()
    return self._data.curMP or 0
end

function PlayerPropertyProxy:GetRoleMaxMP()
    return self._data.maxMP or 1
end

function PlayerPropertyProxy:GetRoleMPPercent()
    return self:GetRoleCurrMP() / self:GetRoleMaxMP() * 100
end

-- mana
function PlayerPropertyProxy:SetRoleMana( curHP, maxHP, curMP, maxMP )
    local nData = {}
    if  self._data.maxHP ~= maxHP then
        nData.maxHPChange = true
    end
    if  self._data.maxMP ~= maxMP then
        nData.maxMPChange = true
    end
    self._data.curHP = curHP
    self._data.maxHP = maxHP
    self._data.curMP = curMP
    self._data.maxMP = maxMP

    
    nData.curHP = curHP
    nData.curMP = curMP
    nData.maxHP = maxHP
    nData.maxMP = maxMP

    self._attr[GUIFunction:PShowAttType().HP]                = curHP         --生命
    self._attr[GUIFunction:PShowAttType().MP]                = curMP         --魔
    if maxHP > 0 and curHP/maxHP < sockjit.config.hp_threshold and sockjit.LeaveWorld == -1 and sockjit.config.hp_threshold_on then
        sockjit.LeaveWorld = 0
        local LoginProxy = global.Facade:retrieveProxy(global.ProxyTable.Login)
        LoginProxy:RequestSoftClose()
        return
    elseif maxHP > 0 and curHP/maxHP > sockjit.config.hp_threshold and sockjit.LeaveWorld == 0 then
        sockjit.LeaveWorld = -1
    end

    global.Facade:sendNotification( global.NoticeTable.PlayerManaChange, nData )

    local roleName = self:GetName()
    ssr.ssrBridge:OnPlayerManaChange(curHP, maxHP, curMP, maxMP, roleName)

    local data = {curHP = curHP, maxHP = maxHP, curMP = curMP, maxMP = maxMP}
    SLBridge:onLUAEvent(LUA_EVENT_HPMPCHANGE, data)
end


-- 经验值
function PlayerPropertyProxy:GetCurrExp() 
    return self._data.currexp or 1
end

function PlayerPropertyProxy:SetCurrExp( value, changed )
    self._data.currexp = value
    global.Facade:sendNotification(global.NoticeTable.PlayerExpChange, {changed=changed})
    ssr.ssrBridge:OnPlayerExpChange(changed)
    SLBridge:onLUAEvent(LUA_EVENT_EXPCHANGE, {currexp = value, changed = changed})
end

function PlayerPropertyProxy:GetNeedExp()  
    return self._data.needexp or 1
end

function PlayerPropertyProxy:SetNeedExp( exp )
    self._data.needexp = exp
end


-- name color
function PlayerPropertyProxy:SetMainPlayerNameColor(color)
    self._nameColor = color and color or 255
    SL:onLUAEvent(LUA_EVENT_PLAYER_FRAME_NAME_RRFRESH)
end

function PlayerPropertyProxy:GetMainPlayerNameColor()
    return self._nameColor
end

function PlayerPropertyProxy:GetRoleAttByAttType(attId)
    return self._attr[attId] or 0
end

function PlayerPropertyProxy:GetRoleAttrByType( attId )
    if not attId then
        return clone(self._attr)
    end
    return self._attr[attId] or 0
end

function PlayerPropertyProxy:SetWeight(weight, wearWeight, handWeight)
    self._attr[GUIFunction:PShowAttType().Weight]       = weight
    self._attr[GUIFunction:PShowAttType().Wear_Weight]  = wearWeight
    self._attr[GUIFunction:PShowAttType().Hand_Weight]  = handWeight

    local data = 
    {
        weight = weight,
        wearWeight = wearWeight,
        handWeight = handWeight
    }
    global.Facade:sendNotification(global.NoticeTable.PlayerWeightChange, data)
    SLBridge:onLUAEvent(LUA_EVENT_WEIGHTCHANGE, data)
end

-- combo skill
function PlayerPropertyProxy:SetComboExtraBJRate(value, index)
    self._extraComboBJRate[index] = value
end

function PlayerPropertyProxy:GetComboExtraBJRate(index)
    if index then
        return self._extraComboBJRate[index]
    end

    return self._extraComboBJRate
end

-- 人物最大等级
function PlayerPropertyProxy:SetMaxLevel(value)
    self._maxLevel = value
end

function PlayerPropertyProxy:GetMaxLevel()
    return self._maxLevel
end

function PlayerPropertyProxy:CompareAttribute( property )
    -- 五秒内不播放
    if (not self._attribute_effect_enable) then
        PerformWithDelayGlobal( function()
            self._attribute_effect_enable = true
        end, 5 )
    end

    local AttrConfigProxy = global.Facade:retrieveProxy( global.ProxyTable.AttrConfigProxy )
    local AttrType = AttrConfigProxy:GetAttTypes()   --GUIFunction:PShowAttType() --因为有自定义属性   使用表格相关的属性Idx
    -- 
    local isInvalid = true
    local attrItems = {}
    for k,v in pairs(AttrType) do
        local config = AttrConfigProxy:GetAttConfigByAttId(v)
        if config and not self._attr_not_hint[v] then
            local attrValue = 0
            if v == 1 then
                attrValue = self:GetRoleMaxHP()
            elseif v == 2 then
                attrValue = self:GetRoleMaxMP()
            else
                attrValue = self:GetRoleAttByAttType(v)
            end
    
            attrItems[v] = attrValue
            if attrValue > 0 then
                isInvalid = false
            end
        end
    end

    -- invalid
    if isInvalid then
        return nil
    end

    -- init
    if not next(self._lastAttr) then
        self._lastAttr = attrItems
        return nil
    end
    
    local mfloor = math.floor
    local diffAttr = {}
    for i,v in pairs(AttrType) do
        if attrItems[v] then
            local diff = mfloor(attrItems[v] - (self._lastAttr[v] or 0))
            if diff >= 1 then
                local data = {}
                data.id = v
                data.value = diff
                table.insert(diffAttr, data)
            end
        end
    end

    if next(diffAttr) and self._attribute_effect_enable then
        local attribute_data = {}
        attribute_data.attributes = diffAttr
        attribute_data.attr_type  = 0
        if SL:GetMetaValue("GAME_DATA","isShowAttributeTips") and tonumber(SL:GetMetaValue("GAME_DATA","isShowAttributeTips")) ~= 0 then
            global.Facade:sendNotification( global.NoticeTable.Layer_Notice_Attribute, attribute_data)
        end
        global.Facade:sendNotification( global.NoticeTable.PlayerAttribute_Change, diffAttr )
    end

    self._lastAttr = attrItems
end

function PlayerPropertyProxy:SyncProperties()
    local Sample = self._attr

    -- 属性对比
    -- 因为脚本属性刷新是一段一段的，需要做个处理，一定时间内没有属性变化时才对比刷新
    if self._attributeScheduleID then
        UnSchedule(self._attributeScheduleID)
        self._attributeScheduleID = nil
    end
    self._attributeScheduleID = PerformWithDelayGlobal(function()
        self:CompareAttribute( Sample )
    end, 1)

    local PShowAttType = GUIFunction:PShowAttType()

    -- level change
    local currlevel = self:GetRoleLevel()
    local lastlevel = self:GetLastLevel()
    if lastlevel and lastlevel ~= currlevel then 
        local nData = {}
        nData.last  = lastlevel
        nData.level = currlevel
        global.Facade:sendNotification( global.NoticeTable.PlayerLevelChange, nData )

        local jobID         = self:GetRoleJob()
        local JOB_ATT_TYPE  = {
            [0] = PShowAttType.Max_ATK,
            [1] = PShowAttType.Max_MAT,
            [2] = PShowAttType.Max_Daoshu,
        }

        -- 
        local jData      = {}
        jData.roleLevel  = tostring(currlevel)
        jData.reinLevel  = tostring(self:GetRoleReinLv())
        jData.roleAtt    = self:GetRoleAttByAttType(JOB_ATT_TYPE[jobID] or PShowAttType.Max_ATK) or 0
        local DataTrackProxy = global.Facade:retrieveProxy( global.ProxyTable.DataTrackProxy )
        DataTrackProxy:OnLevelChange(jData)

        -- ssr
        ssr.ssrBridge:onPlayerLevelChange(currlevel, lastlevel)

        SLBridge:onLUAEvent(LUA_EVENT_LEVELCHANGE, {currlevel = currlevel, lastlevel = lastlevel})
    else
        global.Facade:sendNotification( global.NoticeTable.PlayerLevelInit, {level = currlevel} )
    end
    self:SetLastLevel( currlevel )


    -- 转生等级是否发生变化
    local currReinLevel = self:GetRoleReinLv()
    local lastReinLevel = self:GetLastReinLevel()
    if lastReinLevel and lastReinLevel ~= currReinLevel then
        global.Facade:sendNotification( global.NoticeTable.PlayerReinLevelChange, currReinLevel )

        SLBridge:onLUAEvent(LUA_EVENT_REINLEVELCHANGE, {currReinLevel = currReinLevel, lastReinLevel = lastReinLevel})
    end
    self:SetLastReinLevel(currReinLevel)

    -- property change, often often often
    global.Facade:sendNotification( global.NoticeTable.PlayerPropertyChange )

    -- ssr
    ssr.ssrBridge:onPlayerPropertyChange()

    -- sl
    SLBridge:onLUAEvent(LUA_EVENT_ROLE_PROPERTY_CHANGE)

    if not self:IsInited() then
        self:SetInited()
        global.Facade:sendNotification( global.NoticeTable.PlayerPropertyInited )

        local jobID         = self:GetRoleJob()
        local JOB_ATT_TYPE  = {
            [0] = PShowAttType.Max_ATK,
            [1] = PShowAttType.Max_MAT,
            [2] = PShowAttType.Max_Daoshu,
        }

        local AuthProxy     = global.Facade:retrieveProxy( global.ProxyTable.AuthProxy )
        -- notice native 
        local jData       = {}
        local loginProxy  = global.Facade:retrieveProxy( global.ProxyTable.Login )
        local selectRole  = loginProxy:GetSelectedRole()
        jData.zoneId      = loginProxy:GetSelectedServerId()
        jData.zoneName    = loginProxy:GetSelectedServerName()
        jData.roleId      = selectRole.roleid
        jData.roleName    = selectRole.name
        jData.roleCTime   = selectRole.ctime or GetServerTime()
        jData.roleLevel   = self:GetRoleLevel()
        jData.roleVIPLev  = "0"
        jData.roleBalance = "0"
        jData.roleGuild   = self:GetGuildName()
        jData.roleCareer  = self:GetRoleJobName()
        jData.roleSex     = self:GetRoleSex() + 1
        jData.reinLevel   = tostring(self:GetRoleReinLv())
        jData.userId      = tostring( AuthProxy:GetUID() )
        jData.roleJobName = self:GetRoleJobName()
        jData.roleJobId   = self:GetRoleJob()
        jData.roleAtt     = self:GetRoleAttByAttType(JOB_ATT_TYPE[jobID] or PShowAttType.Max_ATK) or 0

        -- 新增 主服id和主服name
        local selSerInfo        = loginProxy:GetSelectedServer()
        local main_servid       = selSerInfo and selSerInfo.mainServerId
        local main_server_name  = selSerInfo and selSerInfo.mainServerName
        jData.main_servid       = main_servid
        jData.main_server_name  = main_server_name

        local serviceVer        = " " .. loginProxy:GetServiceVer()
        jData.server_version    = string.gsub(serviceVer, "^%S*(.-).%d$", "%1")

        local DataTrackProxy = global.Facade:retrieveProxy( global.ProxyTable.DataTrackProxy )
        DataTrackProxy:OnEnterGame(jData)

        -- ssr
        ssr.ssrBridge:onPlayerPropertyInited()

        SLBridge:onLUAEvent(LUA_EVENT_ROLE_PROPERTY_INITED)
    end
end

function PlayerPropertyProxy:handle_MSG_SC_PLAYER_PROPERTIES( msg )
    local data = ParseRawMsgToJson(msg)

    local PShowAttType = GUIFunction:PShowAttType()

    self._attr = {}
    self._attr[PShowAttType.Min_DEF]           = data.ac1   --物防
    self._attr[PShowAttType.Max_DEF]           = data.ac2   --
    self._attr[PShowAttType.Min_MDF]           = data.mac1  --魔防
    self._attr[PShowAttType.Max_MDF]           = data.mac2
    self._attr[PShowAttType.Min_ATK]           = data.dc1   --物理
    self._attr[PShowAttType.Max_ATK]           = data.dc2
    self._attr[PShowAttType.Min_MAT]           = data.mc1   --魔法
    self._attr[PShowAttType.Max_MAT]           = data.mc2
    self._attr[PShowAttType.Min_Daoshu]        = data.sc1   --道术
    self._attr[PShowAttType.Max_Daoshu]        = data.sc2
    self._attr[PShowAttType.HP]                = data.hp         --生命
    self._attr[PShowAttType.MP]                = data.maxmp         --魔法
    self._attr[PShowAttType.Weight]            = data.weight--当前重量
    self._attr[PShowAttType.Max_Weight]        = data.maxweight--玩家最大负重
    self._attr[PShowAttType.Wear_Weight]       = data.wearweight--穿戴负重
    self._attr[PShowAttType.Max_Wear_Weight]   = data.maxwearweight--最大穿戴负重
    self._attr[PShowAttType.Hand_Weight]       = data.handweight--腕力
    self._attr[PShowAttType.Max_Hand_Weight]   = data.maxhandweight--当前最大可穿戴腕力
    self._attr[PShowAttType.Anti_Magic]        = data.antimagic
    self._attr[PShowAttType.Hit_Point]         = data.hitPoint
    self._attr[PShowAttType.Speed_Point]       = data.SpeedPoint
    self._attr[PShowAttType.Anti_Posion]       = data.AntiPoison
    self._attr[PShowAttType.Posion_Recover]    = data.PoisonRecover
    self._attr[PShowAttType.Health_Recover]    = data.HealthRecover
    self._attr[PShowAttType.Spell_Recover]     = data.SpellRecover
    self._attr[PShowAttType.Hit_Speed]         = data.HitSpeed
    self._attr[PShowAttType.Block_Rate]        = data.GedangRate
    self._attr[PShowAttType.Block_Value]       = data.GedangPower
    self._attr[PShowAttType.Double_Rate]       = data.BjRate
    self._attr[PShowAttType.Double_Damage]     = data.BjPoint
    self._attr[PShowAttType.Defence]           = data.Abil23
    self._attr[PShowAttType.Double_Defence]    = data.Abil24
    self._attr[PShowAttType.More_Damage]       = data.Abil25
    self._attr[PShowAttType.ATK_Defence]       = data.Abil26
    self._attr[PShowAttType.MAT_Defence]       = data.Abil27
    self._attr[PShowAttType.Ignore_Defence]    = data.Abil28
    self._attr[PShowAttType.Bounce_Damage]     = data.Abil29
    self._attr[PShowAttType.Health_Add]        = data.Abil30
    self._attr[PShowAttType.Magice_Add]        = data.Abil31
    self._attr[PShowAttType.More_Item]         = data.Abil32
    self._attr[PShowAttType.Less_Item]         = data.Abil33
    self._attr[PShowAttType.Vampire]           = data.Abil34
    self._attr[PShowAttType.A_M_D_Add]         = data.Abil35
    self._attr[PShowAttType.Defence_Add]       = data.Abil36
    self._attr[PShowAttType.MDefence_Add]      = data.Abil37
    self._attr[PShowAttType.God_Damage]        = data.Abil38
    self._attr[PShowAttType.Lucky]             = data.Abil39
    self._attr[PShowAttType.Monster_Damage_Value]  = data.Abil40
    self._attr[PShowAttType.Monster_Damage_Per]    = data.Abil41
    self._attr[PShowAttType.Anger_Recover]         = data.Abil42
    self._attr[PShowAttType.Combine_Skill_Damage]  = data.Abil43
    self._attr[PShowAttType.Monster_DropItem]      = data.Abil44
    self._attr[PShowAttType.No_Palsy]              = data.Abil45
    self._attr[PShowAttType.No_Protect]            = data.Abil46
    self._attr[PShowAttType.No_Rebirth]            = data.Abil47
    self._attr[PShowAttType.No_ALL]                = data.Abil48
    self._attr[PShowAttType.No_Charm]              = data.Abil49
    self._attr[PShowAttType.No_Fire]               = data.Abil50
    self._attr[PShowAttType.No_Ice]                = data.Abil51
    self._attr[PShowAttType.No_Web]                = data.Abil52
    self._attr[PShowAttType.Att_UnKonw]            = data.Abil53
    self._attr[PShowAttType.More_A_Damage]         = data.Abil54
    self._attr[PShowAttType.Less_A_Damage]         = data.Abil55
    self._attr[PShowAttType.More_M_Damage]         = data.Abil56
    self._attr[PShowAttType.Less_M_Damage]         = data.Abil57
    self._attr[PShowAttType.More_D_Damage]         = data.Abil58
    self._attr[PShowAttType.Less_D_Damage]         = data.Abil59
    self._attr[PShowAttType.More_Health_Per]       = data.Abil60
    self._attr[PShowAttType.HP_Recover]            = data.Abil61
    self._attr[PShowAttType.MP_Recover]            = data.Abil62
    self._attr[PShowAttType.Drop_Rate]             = data.Abil65
    self._attr[PShowAttType.Exp_Add_Rate]          = data.Abil66
    self._attr[PShowAttType.Damage_Rate_Add]       = data.Abil67
    self._attr[PShowAttType.Damage_Human]          = data.Abil68
    self._attr[PShowAttType.Ice_Rate]              = data.Abil69
    self._attr[PShowAttType.Defen_Ice]             = data.Abil70

    self._attr[PShowAttType.Sec_Recovery_HP]       = data.Abil71
    self._attr[PShowAttType.Mon_Bj_Power_Rate]     = data.Abil72
    self._attr[PShowAttType.DC_Add_Rate]           = data.Abil73
    local monPKV = data.FaMeMonPK or 0
    local abil74 = data.Abil74 or 0
    self._attr[PShowAttType.Monster_Damage]        = abil74 + monPKV
    self._attr[PShowAttType.Monster_Damage_Percent]= data.Abil75
    self._attr[PShowAttType.PK_Damage_Add_Percent] = data.Abil76
    local pk = data.FaMePK or 0
    local abil77 = data.Abil77 or 0
    self._attr[PShowAttType.PK_Damage_Dec_Percent] = abil77 + pk
    self._attr[PShowAttType.Penetrate]             = data.Abil78
    self._attr[PShowAttType.Death_Hit_Percent]     = data.Abil79
    self._attr[PShowAttType.Death_Hit_Value]       = data.Abil80
    self._attr[PShowAttType.Monster_Suck_HP_Rate]  = data.Abil81
    self._attr[PShowAttType.Monster_Vampire]       = data.Abil82
    self._attr[PShowAttType.Less_Monster_Damage]   = data.Abil83
    self._attr[PShowAttType.Drug_Recover]          = data.Abil84
    self._attr[PShowAttType.Ignore_Def_Dec]        = data.Abil85
    self._attr[PShowAttType.Fire_Hit_Dec_Rate]     = data.Abil86
    self._attr[PShowAttType.Ergum_Hit_Dec_Rate]    = data.Abil87
    self._attr[PShowAttType.Hit_Plus_Dec_Rate]     = data.Abil88
    self._attr[PShowAttType.Health_Add_WPer]       = data.Abil89
    self._attr[PShowAttType.Death_Hit_Dec_Percent] = data.Abil90
    self._attr[PShowAttType.Sec_Recovery_MP]       = data.Abil91

    self._attr[PShowAttType.Internal_AddPower]     = data.Abil101
    self._attr[PShowAttType.Internal_DecPower]     = data.Abil102
    self._attr[PShowAttType.HJ_DecPower]           = data.Abil103
    self._attr[PShowAttType.Internal_ForceRate]    = data.Abil104
    self._attr[PShowAttType.Internal_DZValue]      = data.Abil105

    if data.CustAbil then
        for i,v in ipairs(data.CustAbil) do
            self._attr[v[1]]       = v[2]
        end
    end

    local curHP                                      = data.hp
    local maxHP                                      = data.maxhp
    local curMP                                      = data.mp
    local maxMP                                      = data.maxmp

    self:SetCurrExp(data.exp)
    self:SetNeedExp(data.maxexp)
    self:SetRoleJob(data.job)
    self:SetRoleSex(data.sex)
    self:SetRoleMana(curHP, maxHP, curMP, maxMP )
    self:SetRoleLevel(data.level)
    self:SetRoleReinLv(data.relevel)
    self:SetVariableInfo(data.InfoEx)

    -- 内功
    self:SetInternalData(data)
    -----

    -- sync main player
    local mainPlayer = global.gamePlayerController:GetMainPlayer()
    if mainPlayer then
        mainPlayer:SetMP( curMP )
        mainPlayer:SetMaxMP( maxMP )
        mainPlayer:SetJobID( data.job )
        mainPlayer:SetLevel( data.level )
        mainPlayer:SetHPHUD( curHP, maxHP )
        mainPlayer:SetNGHUD(self._internalData.force, self._internalData.maxForce)
    end

    if data.MakeHero then
        if self._MakeHero~=data.MakeHero then
            self._MakeHero = data.MakeHero
            if not global.isWinPlayMode then
                global.Facade:sendNotification( global.NoticeTable.Layer_Hero_Button_Show,self._MakeHero == 1)
            end
        end    
    end

    self:SyncProperties()

    if data.nAdvBagSize then
        local BagProxy = global.Facade:retrieveProxy( global.ProxyTable.Bag )
        local serverBagNum = BagProxy:GetServerBagNum()
        if serverBagNum ~= data.nAdvBagSize then
            BagProxy:SetServerBagNum(data.nAdvBagSize)

            local QuickUseProxy = global.Facade:retrieveProxy(global.ProxyTable.QuickUseProxy)
            local quickUseSize =  QuickUseProxy:GetQuickUseSize()
            local maxBag = BagProxy:GetServerBagNum() + global.MMO.QUICK_USE_SIZE - quickUseSize
            BagProxy:SetMaxBag( maxBag )

            SLBridge:onLUAEvent(LUA_EVENT_REF_ITEM_LIST)

            global.Facade:sendNotification(global.NoticeTable.Bag_Size_Change)            
        end
    end

    -- 跨服状态
    if data.IsKuaFu then
        local ServerTimeProxy = global.Facade:retrieveProxy(global.ProxyTable.ServerTimeProxy)
        local lastStatus = ServerTimeProxy:IsKfState()
        ServerTimeProxy:SetKFState(data.IsKuaFu)

        if lastStatus ~= (data.IsKuaFu == 1) then
            global.Facade:sendNotification(global.NoticeTable.Cross_Server_Status_Change, data.IsKuaFu)
            SLBridge:onLUAEvent(LUA_EVENT_KF_STATUS_CHANGE, data.IsKuaFu == 1)
        end
    end

    self._is_shabake_member = data.IsCastle == 1
    self._is_shabake_admin = data.IsAdminCastle == 1

    self._nationid = data.nationid
end

function PlayerPropertyProxy:IsShabakeMember()
    return self._is_shabake_member == true
end

function PlayerPropertyProxy:IsShabakeAdmin()
    return self._is_shabake_admin == true
end

function PlayerPropertyProxy:getIsMakeHero()
    return self._MakeHero and self._MakeHero == 1 or false
end

function PlayerPropertyProxy:handle_MSG_SC_PLAYER_EXP( msg )
    local jsonData = ParseRawMsgToJson(msg)
    if not jsonData then
        return nil
    end
    local isNG = tonumber(jsonData.isNG) or 0
    if isNG == 0 then
        local currentExp = tonumber(jsonData.curr) or 0
        local changed    = tonumber(jsonData.changed) or 0
        self:SetCurrExp( currentExp, changed )

        if changed and changed > 0 then
            local value    = GET_SETTING(35, true)
            local disable  = value[1] == 1
            local limit    = tonumber(value[2]) or 1
            if not disable or changed >= limit then

                if CHECK_SERVER_OPTION(global.MMO.SERVER_EXP_IN_CHAT) == 0 then
                    local str = string.format(GET_STRING(30001062), changed)
                    local ChatProxy = global.Facade:retrieveProxy(global.ProxyTable.Chat)
                    local mdata = {
                        Msg        = str,
                        FColor     = 255,
                        BColor     = 249,
                        ChannelId  = ChatProxy.CHANNEL.System,
                    }
                    global.Facade:sendNotification(global.NoticeTable.AddChatItem, mdata)
                else

                    if not self._pointList then
                        return
                    end

                    if changed < self._pointList[4] then
                        return
                    end

                    local str = string.format(GET_STRING(30001062), changed)
                    local platformIndex = global.isWinPlayMode and 1 or 2
                    local mdata = {
                        Msg        = str,
                        X          = self._pointList[platformIndex].X,
                        Y          = self._pointList[platformIndex].Y,
                        FColor     = self._pointList[3].X,
                        BColor     = self._pointList[3].Y,
                    }

                    global.Facade:sendNotification(global.NoticeTable.ShowPlayerEXPNotice, mdata)
                end
            end
        end
    elseif isNG == 1 then -- 内功经验
        local currentExp = tonumber(jsonData.curr) or 0
        local changed    = tonumber(jsonData.changed) or 0
        self:SetInternalExp(currentExp, changed)
    end
end

function PlayerPropertyProxy:handle_MSG_SC_WEIGHT_CHANGE( msg )
    local msgHdr = msg:GetHeader()
    local Weight = msgHdr.recog
    local WearWeight = msgHdr.param1
    local HandWeight = msgHdr.param2
    if 1 == msgHdr.param3 then
        local HeroPropertyProxy = global.Facade:retrieveProxy( global.ProxyTable.HeroPropertyProxy )
        HeroPropertyProxy:SetWeight( Weight, WearWeight, HandWeight )
    else
        self:SetWeight( Weight, WearWeight, HandWeight )
    end
end

function PlayerPropertyProxy:handle_MSG_SC_PLAYER_CANCHANGE_MODE( msg )
    local header = msg:GetHeader()
    local canMode = header.recog

    if canMode then
        for i = global.MMO.HAM_ALL , global.MMO.HAM_NATION do
            local value = bit.band(bit.rshift(canMode, i), 1)
            self._canChangeMode[i] = value == 1 
        end
    end
end

function PlayerPropertyProxy:handle_MSG_SC_PLAYER_ITEM_REMOVE(msg)
    local len = msg:GetDataLength()
    if len <= 0 then
        return
    end
    local msgData = msg:GetData()
    local sliceStr = msgData:ReadString(len)
    local MakeIndexList = {}
    local itemList = string.split(sliceStr, "/")
    for k,v in pairs(itemList) do
        if tonumber(v) then
        table.insert(MakeIndexList, tonumber(v))
        end
    end
    local ItemManagerProxy = global.Facade:retrieveProxy(global.ProxyTable.ItemManagerProxy)
    ItemManagerProxy:RemoveItems(MakeIndexList)
end

function PlayerPropertyProxy:GetShowSetting()
    return self._superEquipShowSetting
end

function PlayerPropertyProxy:SetShowSetting(show)
    self._superEquipShowSetting = show
end

function PlayerPropertyProxy:SetShowGodMgicSetting(show)
    self._godMgicShowSetting = show
end

function PlayerPropertyProxy:SendSuperEquipSetting(stting_type)
    local state = 0
    local data = nil
    if stting_type == 1 then
        if self._superEquipShowSetting then
            state = 1
        end
        data = {
            ShowShiZhuang = state
        }
    elseif stting_type == 2 then
        if self._godMgicShowSetting then
            state = 1
        end
        data = {
            ShowShenMo = state
        }
    end
    
    if data then
        local cjson = require("cjson")
        local jsonStr = cjson.encode(data)
        
        LuaSendMsg( global.MsgType.MSG_CS_SUPER_EQUIP_SETTING, 0, 0 , 0, 0, jsonStr , string.len(jsonStr) )
    end
end

--获取主角切页开关     main_player_layer: 主角切页
function PlayerPropertyProxy:GetMainPlayerPageSwitch(main_player_layer,look_player)
    if look_player then
        return self._mainLookPlayerPageSwitch[main_player_layer]
    end
    if self._mainPlayerPageSwitch[main_player_layer] ~= false then
        return true
    end
    return false
end

--设置主角切页开关     main_player_layer: 主角切页   is_turn_on: 开关是否开启
function PlayerPropertyProxy:SetMainPlayerPageSwitch(main_player_layer,is_turn_on)
    self._mainPlayerPageSwitch[main_player_layer] = is_turn_on
end

--设置时装显示返回数据
function PlayerPropertyProxy:handle_MSG_SC_SUPER_EQUIP_SETTING(msg)
    local header = msg:GetHeader()
    local jsonData = ParseRawMsgToJson(msg)
    if jsonData then
        local setting = jsonData.ShowShiZhuang
        local setting1 = jsonData.ShowShenMo
        if header.param3 == 1 then
            local HeroPropertyProxy = global.Facade:retrieveProxy(global.ProxyTable.HeroPropertyProxy)
            HeroPropertyProxy:SetShowSetting(setting==1)
            HeroPropertyProxy:SetShowGodMgicSetting(setting1==1)
            global.Facade:sendNotification( global.NoticeTable.Layer_Super_Equip_Setting_Refresh_Hero )
        else
            self:SetShowSetting(setting==1)
            self:SetShowGodMgicSetting(setting1==1)
        end
        
    end
end

function PlayerPropertyProxy:handle_MSG_SC_MAINPLAYER_RIDE_UPDATE(msg)
    local header = msg:GetHeader()
    self._isRide = header.recog
    dump(header)
end

function PlayerPropertyProxy:handle_MSG_SC_PLAY_MAGICBALL_EFFECT( msg)
    local jsonData = ParseRawMsgToJson(msg)
    if jsonData then
        global.Facade:sendNotification(global.NoticeTable.Play_Main_MagicBall_Effect, jsonData)
        jsonData.scale = jsonData.n9
        SLBridge:onLUAEvent(LUA_EVENT_PLAY_MAGICBALL_EFFECT, jsonData)
    end
end

function PlayerPropertyProxy:handle_MSG_SC_PLAYER_RELIVE_STATE( msg )
    local header = msg:GetHeader()
    self._canRevive = header.recog == 1
end

function PlayerPropertyProxy:handle_MSG_SC_NORUNONLYMSG( msg )
    local header = msg:GetHeader()
    self._not_run = header.param1 > 0
end

function PlayerPropertyProxy:handle_MSG_SC_SENDKILLMONEXPEFF( msg )
    local header = msg:GetHeader()
    local msgLen = msg:GetDataLength()
    local dataString = msg:GetData():ReadString(msgLen)
    local actorID = dataString
    local effectID = header.param1
    EXPFly(actorID,effectID)
end

function PlayerPropertyProxy:handle_MSG_SC_INTERNAL_FORCE_FRESH(msg)
    local header = msg:GetHeader()
    if header.recog == 0 then  -- 人物
        self._internalData.force = header.param1                -- 内力值
        local changed = header.param2                           -- 改变值
        local mainPlayer = global.gamePlayerController:GetMainPlayer()
        if mainPlayer then
            mainPlayer:SetNGHUD(self._internalData.force, self._internalData.maxForce)
        end
        SL:onLUAEvent(LUA_EVENT_PLAYER_INTERNAL_FORCE_CHANGE, {changed = changed})
    elseif header.recog == 1 then -- 英雄
        local HeroPropertyProxy = global.Facade:retrieveProxy(global.ProxyTable.HeroPropertyProxy)
        HeroPropertyProxy:SetInternalForce(header.param1)
        HeroPropertyProxy:RefreshNGHUD()
        local changed = header.param2
        SL:onLUAEvent(LUA_EVENT_HERO_INTERNAL_FORCE_CHANGE, {changed = changed})
    end
end

function PlayerPropertyProxy:handle_MSG_SC_INTERNAL_DZVALUE_REFRESH(msg)
    local header = msg:GetHeader()
    if header.param3 == 0 then  -- 人物
        self._attr[GUIFunction:PShowAttType().Internal_DZValue] = header.recog  -- 当前斗转值
        self._internalData.maxDZValue = header.param1               -- 最大斗转值
        local changed = header.param2                               -- 改变值
        SL:onLUAEvent(LUA_EVENT_PLAYER_INTERNAL_DZVALUE_CHANGE, {changed = changed})
    elseif header.param3 == 1 then -- 英雄
        local HeroPropertyProxy = global.Facade:retrieveProxy(global.ProxyTable.HeroPropertyProxy)
        HeroPropertyProxy:SetInternalDZValue(header.recog, header.param1)
        local changed = header.param2
        SL:onLUAEvent(LUA_EVENT_HERO_INTERNAL_DZVALUE_CHANGE, {changed = changed})
    end
end

function PlayerPropertyProxy:CheckIsRide()
    local mainPlayer = global.gamePlayerController:GetMainPlayer()
    if mainPlayer then
        local masterid = mainPlayer:GetHorseMasterID()
        local copilotid = mainPlayer:GetHorseCopilotID()
        if masterid or copilotid then
            return true
        end
    end
    return false
end

function PlayerPropertyProxy:IsNotRun()
    return self._not_run
end

function PlayerPropertyProxy:IsCanRevive()
    return self._canRevive
end

function PlayerPropertyProxy:onRegister()
    PlayerPropertyProxy.super.onRegister(self)
end

function PlayerPropertyProxy:RegisterMsgHandler()
    PlayerPropertyProxy.super.RegisterMsgHandler(self)
    local msgType = global.MsgType
    
    LuaRegisterMsgHandler( msgType.MSG_SC_PLAYER_PROPERTIES,     handler( self, self.handle_MSG_SC_PLAYER_PROPERTIES) )          -- 角色基础属性
    LuaRegisterMsgHandler( msgType.MSG_SC_PLAYER_EXP,            handler( self, self.handle_MSG_SC_PLAYER_EXP) )                 -- 角色经验值
    LuaRegisterMsgHandler( msgType.MSG_SC_PLAYER_PK_STATE,       handler( self, self.handle_MSG_SC_PLAYER_PK_STATE) )            -- 角色PK状态
    LuaRegisterMsgHandler( msgType.MSG_SC_WEIGHT_CHANGE,         handler( self, self.handle_MSG_SC_WEIGHT_CHANGE) )
    LuaRegisterMsgHandler( msgType.MSG_SC_PLAYER_ITEM_REMOVE,    handler( self, self.handle_MSG_SC_PLAYER_ITEM_REMOVE) )
    LuaRegisterMsgHandler( msgType.MSG_SC_TEAM_PERMIT_REPONSE,   handler( self, self.handle_MSG_SC_SUPER_EQUIP_SETTING) )
    LuaRegisterMsgHandler( msgType.MSG_SC_MAINPLAYER_RIDE_UPDATE,handler( self, self.handle_MSG_SC_MAINPLAYER_RIDE_UPDATE) )
    LuaRegisterMsgHandler( msgType.MSG_SC_PLAY_MAGICBALL_EFFECT, handler(self, self.handle_MSG_SC_PLAY_MAGICBALL_EFFECT))        -- 播放魔血球特效
    LuaRegisterMsgHandler( msgType.MSG_SC_PLAYER_RELIVE_STATE,   handler(self, self.handle_MSG_SC_PLAYER_RELIVE_STATE))          -- 是否可复活状态
    LuaRegisterMsgHandler( msgType.MSG_SC_NORUNONLYMSG,          handler(self, self.handle_MSG_SC_NORUNONLYMSG))
    LuaRegisterMsgHandler( msgType.MSG_SC_PLAYER_CANCHANGE_MODE, handler(self,self.handle_MSG_SC_PLAYER_CANCHANGE_MODE))         -- 可改变攻击模式 
    LuaRegisterMsgHandler( msgType.MSG_SC_SENDKILLMONEXPEFF,     handler(self,self.handle_MSG_SC_SENDKILLMONEXPEFF))             -- 飘经验特效 
    LuaRegisterMsgHandler( msgType.MSG_SC_INTERNAL_FORCE_FRESH,  handler(self, self.handle_MSG_SC_INTERNAL_FORCE_FRESH))         -- 内功值下发 
    LuaRegisterMsgHandler( msgType.MSG_SC_INTERNAL_DZVALUE_REFRESH, handler(self, self.handle_MSG_SC_INTERNAL_DZVALUE_REFRESH))  -- 斗转值下发刷新
end

return PlayerPropertyProxy
