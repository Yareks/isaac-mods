local mymod = RegisterMod("Dodge Assist", 1)

-- Настройки мода (будут сохраняться и настраиваться в Mod Config Menu)
local Settings = {
    PlayerEnabled = {true, true, true, true}, -- Для 1, 2, 3, 4 игроков
    DodgeProjectiles = true,
    DodgeEnemies = true,
    DodgeLasers = true,
    DodgeHazards = true,
    DodgeIntensity = 1.0, -- Множитель скорости уклонения
}

-- Внутреннее состояние уклонения для каждого игрока
local isDodging = {false, false, false, false}
local dodgeX = {0, 0, 0, 0}
local dodgeY = {0, 0, 0, 0}

-- Сохранение настроек
local json = require("json")
function mymod:SaveSettings()
    mymod:SaveData(json.encode(Settings))
end

function mymod:LoadSettings()
    if mymod:HasData() then
        local loaded = json.decode(mymod:LoadData())
        if loaded then
            for k, v in pairs(loaded) do
                if type(v) == "table" then
                    for subK, subV in pairs(v) do
                        Settings[k][subK] = subV
                    end
                else
                    Settings[k] = v
                end
            end
        end
    end
end

-- Основной цикл расчета опасностей (вызывается каждый кадр)
function mymod:OnUpdate()
    local game = Game()
    local room = game:GetLevel():GetCurrentRoom()
    local numPlayers = game:GetNumPlayers()
    local entities = Isaac.GetRoomEntities()

    -- Сбрасываем состояние уклонения перед расчетом опасности
    for i = 1, 4 do
        isDodging[i] = false
        dodgeX[i] = 0
        dodgeY[i] = 0
    end

    for pIdx = 0, numPlayers - 1 do
        local player = Isaac.GetPlayer(pIdx)
        local pNum = pIdx + 1

        if pNum <= 4 then
            local enabled = Settings.PlayerEnabled[pNum]
            
            -- Исключаем призраков в кооперативе
            if REPENTANCE and player:IsCoopGhost() then
                enabled = false
            end

            if enabled and not player:IsDead() and player.ControlsEnabled then
                local playerPos = player.Position
                local dodgeVec = Vector(0, 0)
                local dangerCount = 0

                -- 1. УКЛОНЕНИЕ ОТ СНАРЯДОВ (Слезы врагов)
                if Settings.DodgeProjectiles then
                    for _, ent in ipairs(entities) do
                        if ent.Type == EntityType.ENTITY_PROJECTILE and not ent:IsDead() then
                            local proj = ent:ToProjectile()
                            local dist = playerPos:Distance(proj.Position)
                            
                            -- Дистанция реакции зависит от скорости снаряда
                            local dangerDist = 65 + (proj.Velocity:Length() * 3.0)
                            if dist < dangerDist then
                                local toPlayer = playerPos - proj.Position
                                local projVel = proj.Velocity
                                
                                if projVel:Length() > 0.1 then
                                    -- Проверяем, летит ли снаряд в сторону игрока
                                    local dot = projVel:Normalized():Dot(toPlayer:Normalized())
                                    if dot > -0.3 then -- Летит к нам
                                        -- Вычисляем перпендикулярный вектор уклонения (уход с линии огня)
                                        local perp = Vector(-projVel.Y, projVel.X):Normalized()
                                        local side = toPlayer:Dot(perp) > 0 and 1 or -1
                                        local dodgeDir = perp * side
                                        
                                        local weight = (dangerDist - dist) / dangerDist
                                        dodgeVec = dodgeVec + dodgeDir * weight * 2.2
                                        dangerCount = dangerCount + 1
                                    end
                                else
                                    -- Статичный снаряд
                                    local weight = (dangerDist - dist) / dangerDist
                                    dodgeVec = dodgeVec + toPlayer:Normalized() * weight * 1.5
                                    dangerCount = dangerCount + 1
                                end
                            end
                        end
                    end
                end

                -- 2. УКЛОНЕНИЕ ОТ ВРАГОВ
                if Settings.DodgeEnemies then
                    for _, ent in ipairs(entities) do
                        if ent:IsVulnerableEnemy() and not ent:IsDead() and not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
                            local dist = playerPos:Distance(ent.Position)
                            local enemyRange = 60
                            
                            -- Быстро бегущие враги требуют большей дистанции реакции
                            if ent.Velocity:Length() > 4.5 then
                                enemyRange = 100
                            end

                            if dist < enemyRange then
                                local awayDir = (playerPos - ent.Position):Normalized()
                                local weight = (enemyRange - dist) / enemyRange
                                dodgeVec = dodgeVec + awayDir * weight * 1.6
                                dangerCount = dangerCount + 1
                            end
                        end
                    end
                end

                -- 3. УКЛОНЕНИЕ ОТ ЛАЗЕРОВ (Бримстоун и др.)
                if Settings.DodgeLasers then
                    for _, ent in ipairs(entities) do
                        if ent.Type == EntityType.ENTITY_LASER then
                            local laser = ent:ToLaser()
                            -- Проверяем, что лазер принадлежит врагу, а не игроку
                            if laser.Parent == nil or laser.Parent.Index ~= player.Index then
                                local startPoint = laser.Position
                                local endPoint = laser:GetEndPoint()
                                
                                -- Находим ближайшую точку на луче к игроку
                                local lineVec = endPoint - startPoint
                                local lineLen = lineVec:Length()
                                if lineLen > 0.1 then
                                    local lineUnit = lineVec:Normalized()
                                    local projLen = math.max(0, math.min(lineLen, (playerPos - startPoint):Dot(lineUnit)))
                                    local closestPoint = startPoint + lineUnit * projLen
                                    local dist = playerPos:Distance(closestPoint)
                                    
                                    if dist < 60 then
                                        local awayDir = (playerPos - closestPoint):Normalized()
                                        local weight = (60 - dist) / 60
                                        dodgeVec = dodgeVec + awayDir * weight * 2.5
                                        dangerCount = dangerCount + 1
                                    end
                                end
                            end
                        end
                    end
                end

                -- 4. УКЛОНЕНИЕ ОТ КАТАСТРОФ (Костры, шипы, красные какашки)
                if Settings.DodgeHazards then
                    -- Сетка комнаты (шипы, красные какашки)
                    local gridSize = room:GetGridSize()
                    for i = 0, gridSize - 1 do
                        local gridEntity = room:GetGridEntity(i)
                        if gridEntity then
                            local gType = gridEntity:GetType()
                            local isHazard = false
                            
                            if (gType == GridResourceType.GRID_SPIKES or gType == GridResourceType.GRID_SPIKES_ONOFF) and not player.CanFly then
                                isHazard = true
                            elseif gType == GridResourceType.GRID_POOP and gridEntity:GetVariant() == 1 and gridEntity.State < 4 then
                                isHazard = true -- Красная какашка целая
                            end

                            if isHazard then
                                local gPos = gridEntity.Position
                                local dist = playerPos:Distance(gPos)
                                if dist < 52 then
                                    local awayDir = (playerPos - gPos):Normalized()
                                    local weight = (52 - dist) / 52
                                    dodgeVec = dodgeVec + awayDir * weight * 1.8
                                    dangerCount = dangerCount + 1
                                end
                            end
                        end
                    end

                    -- Костры
                    for _, ent in ipairs(entities) do
                        if ent.Type == EntityType.ENTITY_FIREPLACE and ent.HitPoints > 0.1 then
                            local dist = playerPos:Distance(ent.Position)
                            if dist < 52 then
                                local awayDir = (playerPos - ent.Position):Normalized()
                                local weight = (52 - dist) / 52
                                dodgeVec = dodgeVec + awayDir * weight * 1.8
                                dangerCount = dangerCount + 1
                            end
                        end
                    end
                end

                -- Если вектор уклонения сформирован, активируем перехват
                if dangerCount > 0 and dodgeVec:Length() > 0.05 then
                    local finalDodge = dodgeVec:Normalized() * Settings.DodgeIntensity
                    isDodging[pNum] = true
                    
                    -- Записываем направление движения для перехвата ввода
                    dodgeX[pNum] = finalDodge.X
                    dodgeY[pNum] = finalDodge.Y
                end
            end
        end
    end
end

-- Перехват ввода: блокируем ручной ввод движения и подставляем вектор уклонения
function mymod:OnInputAction(entity, hook, action)
    if entity and entity.Type == EntityType.ENTITY_PLAYER then
        local player = entity:ToPlayer()
        local pNum = player:GetPlayerIndex() + 1

        if pNum <= 4 and isDodging[pNum] then
            -- Проверяем действия перемещения
            if action == ButtonAction.ACTION_LEFT then
                if hook == InputHook.GET_ACTION_VALUE then
                    return dodgeX[pNum] < 0 and math.abs(dodgeX[pNum]) or 0.0
                elseif hook == InputHook.IS_ACTION_PRESSED or hook == InputHook.IS_ACTION_TRIGGERED then
                    return dodgeX[pNum] < -0.1
                end
            elseif action == ButtonAction.ACTION_RIGHT then
                if hook == InputHook.GET_ACTION_VALUE then
                    return dodgeX[pNum] > 0 and math.abs(dodgeX[pNum]) or 0.0
                elseif hook == InputHook.IS_ACTION_PRESSED or hook == InputHook.IS_ACTION_TRIGGERED then
                    return dodgeX[pNum] > 0.1
                end
            elseif action == ButtonAction.ACTION_UP then
                if hook == InputHook.GET_ACTION_VALUE then
                    return dodgeY[pNum] < 0 and math.abs(dodgeY[pNum]) or 0.0
                elseif hook == InputHook.IS_ACTION_PRESSED or hook == InputHook.IS_ACTION_TRIGGERED then
                    return dodgeY[pNum] < -0.1
                end
            elseif action == ButtonAction.ACTION_DOWN then
                if hook == InputHook.GET_ACTION_VALUE then
                    return dodgeY[pNum] > 0 and math.abs(dodgeY[pNum]) or 0.0
                elseif hook == InputHook.IS_ACTION_PRESSED or hook == InputHook.IS_ACTION_TRIGGERED then
                    return dodgeY[pNum] > 0.1
                end
            end
        end
    end
end

-- Регистрация коллбеков мода
mymod:AddCallback(ModCallbacks.MC_POST_UPDATE, mymod.OnUpdate)
mymod:AddCallback(ModCallbacks.MC_INPUT_ACTION, mymod.OnInputAction)
mymod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mymod.LoadSettings)
mymod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mymod.SaveSettings)

-- Интеграция с Mod Config Menu
local function SetupMCM()
    if not ModConfigMenu then return end

    local category = "Dodge Assist"
    
    -- Очистка старых настроек (на всякий случай)
    ModConfigMenu.RemoveCategory(category)

    -- Настройки игроков
    for pNum = 1, 4 do
        ModConfigMenu.AddSetting(category, "Players", {
            Type = ModConfigMenu.OptionType.BOOLEAN,
            CurrentSetting = function() return Settings.PlayerEnabled[pNum] end,
            Display = function() return "Player " .. pNum .. ": " .. (Settings.PlayerEnabled[pNum] and "Enabled" or "Disabled") end,
            OnChange = function(val)
                Settings.PlayerEnabled[pNum] = val
                mymod:SaveSettings()
            end,
            Info = {"Toggle Dodge Assist for Player " .. pNum}
        })
    end

    -- Настройки типов опасностей
    ModConfigMenu.AddSpace(category, "Hazards")
    
    ModConfigMenu.AddSetting(category, "Hazards", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return Settings.DodgeProjectiles end,
        Display = function() return "Dodge Projectiles: " .. (Settings.DodgeProjectiles and "ON" or "OFF") end,
        OnChange = function(val)
            Settings.DodgeProjectiles = val
            mymod:SaveSettings()
        end,
        Info = {"Dodge enemy tears and projectiles"}
    })

    ModConfigMenu.AddSetting(category, "Hazards", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return Settings.DodgeEnemies end,
        Display = function() return "Dodge Enemies: " .. (Settings.DodgeEnemies and "ON" or "OFF") end,
        OnChange = function(val)
            Settings.DodgeEnemies = val
            mymod:SaveSettings()
        end,
        Info = {"Dodge contact damage from enemies"}
    })

    ModConfigMenu.AddSetting(category, "Hazards", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return Settings.DodgeLasers end,
        Display = function() return "Dodge Lasers: " .. (Settings.DodgeLasers and "ON" or "OFF") end,
        OnChange = function(val)
            Settings.DodgeLasers = val
            mymod:SaveSettings()
        end,
        Info = {"Dodge Brimstone and other lasers"}
    })

    ModConfigMenu.AddSetting(category, "Hazards", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return Settings.DodgeHazards end,
        Display = function() return "Dodge Environment: " .. (Settings.DodgeHazards and "ON" or "OFF") end,
        OnChange = function(val)
            Settings.DodgeHazards = val
            mymod:SaveSettings()
        end,
        Info = {"Dodge fireplaces, spikes and red poop"}
    })

    -- Настройка интенсивности
    ModConfigMenu.AddSpace(category, "Intensity")
    ModConfigMenu.AddSetting(category, "Intensity", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return Settings.DodgeIntensity * 100 end,
        Minimum = 50,
        Maximum = 200,
        Steps = 10,
        Display = function() return "Dodge Speed: " .. math.floor(Settings.DodgeIntensity * 100) .. "%" end,
        OnChange = function(val)
            Settings.DodgeIntensity = val / 100
            mymod:SaveSettings()
        end,
        Info = {"Adjust the speed of automated dodge movements"}
    })
end

-- Инициализация меню при загрузке
mymod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
    SetupMCM()
end)