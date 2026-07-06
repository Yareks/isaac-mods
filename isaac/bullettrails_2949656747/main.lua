local mod = RegisterMod("Bullet Trail Mod", 1)
local json = include("scripts.json")

local COLOR_RED = Color(0.9, 0.05, 0.05, 1)
local COLOR_GREEN = Color(0.05, 0.9, 0.05, 1)
local COLOR_BLUE = Color(0.05, 0.05, 0.9, 1)
local COLOR_WHITE = Color(1, 1, 1, 1)

-- defaults
local DEFAULT_LENGTH = 0.15
local DEFAULT_SCALE = "sync"
local DEFAULT_COLOR = "sync"
local DEFAULT_TRANSPARENCY = 0.75



-- BULLET_TRAILS_MCM_PLAYER_TEAR_PATCH
-- BULLET_TRAILS_VISUAL_ONLY_TEAR_FIX
-- Extra defaults added by patch.
-- Enemy projectile trails are enabled by default to preserve original behavior.
-- Player tear trails are disabled by default until enabled in Mod Config Menu.
local DEFAULT_ENEMY_PROJECTILE_TRAILS = true
local DEFAULT_PLAYER_TEAR_TRAILS = 0
-- 0 = Off
-- 1 = Player only
-- 2 = Player + familiars
-- 3 = All friendly tears
local ENEMY_PROJ_COLORS = include("enemyToColor")

local colors = {
    [1] = COLOR_RED,
    [2] = COLOR_GREEN,
    [3] = COLOR_BLUE,
    [4] = COLOR_WHITE,
    [5] = Color(255 / 255, 84 / 255, 215 / 255),
    [6] = "sync"
}

local lengths = {
    [1] = 0.25,
    [2] = 0.2,
    [3] = 0.15,
    [4] = 0.1,
    [5] = 0.05,
}

local scales = {
    [1] = 1.5,
    [2] = 2,
    [3] = 2.5,
    [4] = 3,
    [5] = 3.5,
    [6] = "sync"
}

local function rgbToColor(r, g, b)
    return Color(r / 255, g / 255, b / 255, 1)
end

local function getManualColor(entity, variant)
    if ENEMY_PROJ_COLORS[entity] then
        local result = ENEMY_PROJ_COLORS[entity][variant]
        if type(entity) == "function" then
            return result()
        else
            return result
        end
    end
end

local function allZero(t)
    for _, v in pairs(t) do
        if v ~= 0 then
            return false
        end
    end

    return true
end

local function allOne(t)
    for _, v in pairs(t) do
        if v ~= 1 then
            return false
        end
    end

    return true
end

local bulletTypeToColor = {
    [ProjectileVariant.PROJECTILE_NORMAL] = COLOR_RED,
    [ProjectileVariant.PROJECTILE_BONE] = COLOR_WHITE,
    [ProjectileVariant.PROJECTILE_FIRE] = rgbToColor(204, 133, 47),
    [ProjectileVariant.PROJECTILE_PUKE] = rgbToColor(41, 27, 9),
    [ProjectileVariant.PROJECTILE_TEAR] = rgbToColor(142, 245, 241),
    [ProjectileVariant.PROJECTILE_CORN] = rgbToColor(138, 112, 34),
    [ProjectileVariant.PROJECTILE_COIN] = rgbToColor(255, 207, 64),
    [ProjectileVariant.PROJECTILE_GRID] = COLOR_WHITE,
    [ProjectileVariant.PROJECTILE_ROCK] = rgbToColor(184, 184, 184),
    [ProjectileVariant.PROJECTILE_MEAT] = rgbToColor(191, 15, 15),
    [ProjectileVariant.PROJECTILE_FCUK] = COLOR_WHITE,
    [ProjectileVariant.PROJECTILE_WING] = rgbToColor(158, 158, 158)
}

mod.MenuSaveData = nil

local function loadModData()
    if not mod.MenuSaveData then
        if mod:HasData() then
            mod.MenuSaveData = json.decode(mod:LoadData())
        else
            mod.MenuSaveData = {}
        end
    end

    return mod.MenuSaveData
end

local function storeSaveData()
    mod:SaveData(json.encode(mod.MenuSaveData))
end



local function getSetting(saveData, key, defaultValue)
    if saveData[key] == nil then
        return defaultValue
    end

    return saveData[key]
end

local function setSetting(key, value)
    local saveData = loadModData()
    saveData[key] = value
    storeSaveData()
end

local function cloneColor(color)
    return Color(color.R, color.G, color.B, color.A, color.RO, color.GO, color.BO)
end

local function getBasicTrailSettings(entity)
    local saveData = loadModData()

    local length = saveData.TrailLength and lengths[saveData.TrailLength] or DEFAULT_LENGTH
    local scale = saveData.TrailScale and scales[saveData.TrailScale] or DEFAULT_SCALE
    local transparency = saveData.TrailTransparency or DEFAULT_TRANSPARENCY
    local color = saveData.TrailColor and colors[saveData.TrailColor] or DEFAULT_COLOR

    if scale == "sync" then
        local spriteScaleY = 1

        if entity.SpriteScale then
            spriteScaleY = entity.SpriteScale.Y
        end

        scale = (entity.Scale or 1) + spriteScaleY
    end

    if color == "sync" then
        color = Color.Lerp(Color(1, 1, 1, 1), entity:GetColor(), 1)
    else
        color = cloneColor(color)
    end

    color.A = transparency

    return length, scale, color
end

---@param tear EntityTear
local function isPlayerTearTrailAllowed(tear)
    local saveData = loadModData()
    local mode = getSetting(saveData, "PlayerTearTrails", DEFAULT_PLAYER_TEAR_TRAILS)

    if mode <= 0 then
        return false
    end

    local spawner = tear.SpawnerEntity

    if spawner then
        if spawner.Type == EntityType.ENTITY_PLAYER then
            return true
        end

        if mode >= 2 and spawner.Type == EntityType.ENTITY_FAMILIAR then
            return true
        end

        if mode >= 3 then
            if spawner:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) or spawner:HasEntityFlags(EntityFlag.FLAG_CHARM) then
                return true
            end
        end
    end

    if tear.SpawnerType == EntityType.ENTITY_PLAYER then
        return true
    end

    if mode >= 2 and tear.SpawnerType == EntityType.ENTITY_FAMILIAR then
        return true
    end

    if mode >= 3 and tear:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
        return true
    end

    return false
end

---@param parent EntityTear
local function getTearPositionOffset(parent, scale)
    local velocityOffset = Vector.Zero

    if parent.Velocity:Length() > 0 then
        velocityOffset = parent.Velocity:Normalized() * 2
    end

    return parent.PositionOffset + velocityOffset * scale
end

---@param parent EntityProjectile
local function getPositionOffset(parent, scale)
    local angle = parent.Velocity:Normalized() * 2
    local height = parent.FallingAccel * parent.FallingSpeed
    local offset = parent.PositionOffset + angle * scale + Vector(0, height / 2)
    return offset
end

--#region API CODE

_G.BulletTrails = mod
BulletTrails.TypeToColors = ENEMY_PROJ_COLORS
BulletTrails.EntityTrailBlacklist = {}

--- Get a Color object using RGB values.
---@param red number
---@param green number
---@param blue number
function mod:RGBToColor(red, green, blue)
    return Color(red / 255, green / 255, blue / 255, 1)
end

--- Assign a custom trail color to a projectile sender.
---@param entity integer
---@param variant integer
---@param color Color | function @A Color object or a function that returns a Color object. The function is provided the entity. Don't use Color.Default, it's mutable and may cause issues.
function mod:AddEntityTrailColor(entity, variant, color)
    assert(type(entity) == "number", "BulletTrails: AddEntityTrailColor: entity must be an integer")
    assert(type(variant) == "number", "BulletTrails: AddEntityTrailColor: variant must be an integer")
    assert(type(color) == "userdata" or type(color) == "function", "BulletTrails: AddEntityTrailColor: color must be a Color object or a function that returns a Color object")
    ENEMY_PROJ_COLORS[entity] = ENEMY_PROJ_COLORS[entity] or {}
    ENEMY_PROJ_COLORS[entity][variant] = color
end

--- Blacklist the entity from having any projectile trails.
--- If no variant is provided, all variants of the entity will be blacklisted. (Overwriting any previous variant blacklist)
--- If no subType is provided, all subtypes of the variant of the entity will be blacklisted. (Overwriting any previous subtype blacklist)
---@param bool boolean
---@param entity integer
---@param variant integer?
---@param subType integer?
function mod:BlacklistEntity(bool, entity, variant, subType)

    assert(type(bool) == "boolean", "BulletTrails: BlacklistEntity: bool must be a boolean value")
    assert(type(entity) == "number", "BulletTrails: BlacklistEntity: entity must be an integer")
    assert(variant == nil or type(variant) == "number", "BulletTrails: BlacklistEntity: variant must be an integer or nil")
    assert(subType == nil or type(subType) == "number", "BulletTrails: BlacklistEntity: subType must be an integer or nil")

    if not BulletTrails.EntityTrailBlacklist[entity] then
        BulletTrails.EntityTrailBlacklist[entity] = {}
    end

    if not variant then
        BulletTrails.EntityTrailBlacklist[entity] = bool
    else
        if not BulletTrails.EntityTrailBlacklist[entity][variant] then
            BulletTrails.EntityTrailBlacklist[entity][variant] = {}
        end

        if not subType then
            BulletTrails.EntityTrailBlacklist[entity][variant] = bool
        else
            BulletTrails.EntityTrailBlacklist[entity][variant][subType] = bool
        end
    end
end

--- Check if an entity is blacklisted from having a projectile trail.
---@param entity integer
---@param variant integer?
---@param subType integer?
function mod:IsEntityBlacklisted(entity, variant, subType)

    assert(type(entity) == "number", "BulletTrails: IsEntityBlacklisted: entity must be an integer")
    assert(variant == nil or type(variant) == "number", "BulletTrails: IsEntityBlacklisted: variant must be an integer or nil")
    assert(subType == nil or type(subType) == "number", "BulletTrails: IsEntityBlacklisted: subType must be an integer or nil")

    if BulletTrails.EntityTrailBlacklist[entity] == nil then
        return false
    end

    if type(BulletTrails.EntityTrailBlacklist) == "table" then
        if BulletTrails.EntityTrailBlacklist[entity][variant] == nil then
            return false
        end

        if type(BulletTrails.EntityTrailBlacklist[entity][variant]) == "table"  then
            if type(BulletTrails.EntityTrailBlacklist[entity][variant]) == "table" then
                if not BulletTrails.EntityTrailBlacklist[entity][variant][subType] then
                    return false
                end

                return BulletTrails.EntityTrailBlacklist[entity][variant][subType]
            else
                return BulletTrails.EntityTrailBlacklist[entity][variant]
            end
        else
            return BulletTrails.EntityTrailBlacklist[entity][variant]
        end
    else
        return BulletTrails.EntityTrailBlacklist[entity]
    end
end

--#endregion

--#region MAIN CODE

---@param projectile EntityProjectile
function mod:NewProjectile(projectile)
    local saveData = loadModData()

    
    if getSetting(saveData, "EnemyProjectileTrails", DEFAULT_ENEMY_PROJECTILE_TRAILS) == false then
        return
    end

if projectile.SpawnerEntity then
        if projectile.SpawnerEntity:HasEntityFlags(EntityFlag.FLAG_CHARM) or projectile.SpawnerEntity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
            return -- friendly enemies dont get trails, for visibility reasons
        end
    end

    if projectile.SpawnerEntity and BulletTrails:IsEntityBlacklisted(projectile.SpawnerType, projectile.SpawnerVariant, projectile.SpawnerEntity.SubType) then
        return
    end

    local length = saveData.TrailLength and lengths[saveData.TrailLength] or DEFAULT_LENGTH
    local scale = saveData.TrailScale and scales[saveData.TrailScale] or DEFAULT_SCALE
    local transparency = saveData.TrailTransparency or DEFAULT_TRANSPARENCY
    local color = saveData.TrailColor and colors[saveData.TrailColor] or DEFAULT_COLOR
    local shouldLoadDogmaTrail = color == "sync" and projectile.SpawnerType == EntityType.ENTITY_DOGMA

    if shouldLoadDogmaTrail then
        color = Color(1, 1, 1, 1)
    elseif color == "sync" then
        local bulletType = projectile.Variant
        local projectileColor = projectile:GetColor()
        local defaultColor = Color.Lerp(Color(1, 1, 1, 1), projectileColor, 1)
        local syncColor = getManualColor(projectile.SpawnerType, projectile.SpawnerVariant)
        if type(syncColor) == "function" then
            syncColor = syncColor(projectile.SpawnerEntity)
        end
        if REPENTOGON then
            -- Impossible to know if the tint or colorize values are set for non-rgon users.
            -- So just reserve this for rgon only.
            if bulletType == ProjectileVariant.PROJECTILE_NORMAL
            and not syncColor
            and not (allZero(defaultColor:GetColorize()) and allZero(defaultColor:GetOffset()) and allOne(defaultColor:GetTint())) then
                color = defaultColor
            else
                color = syncColor or bulletTypeToColor[bulletType] or defaultColor
            end
        else
            local deliriumColor = #Isaac.FindByType(EntityType.ENTITY_DELIRIUM) > 0 and Color(1, 1, 1, 1)
            color = deliriumColor or syncColor or bulletTypeToColor[bulletType] or defaultColor
        end
    end

    if scale == "sync" then
        scale = (projectile.Scale + projectile.SpriteScale.Y)
    end

    color.A = transparency

    local trail = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SPRITE_TRAIL, 0, projectile.Position + projectile.PositionOffset, Vector.Zero, projectile):ToEffect()
    trail:FollowParent(projectile)
    trail.Color = color
    trail.MinRadius = length
    trail.SpriteScale = Vector.One * scale

    if shouldLoadDogmaTrail then
        trail:GetSprite():Load("gfx/dogma_trail.anm2", true)
        trail:GetSprite():Play("Idle", true)
    end

    trail:Update()

    trail:GetData().B_BulletTrail = true
    trail:GetData().B_ParentProj = projectile
end

mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, mod.NewProjectile)



---@param tear EntityTear
function mod:NewTear(tear)
    if not isPlayerTearTrailAllowed(tear) then
        return
    end

    local length, scale, color = getBasicTrailSettings(tear)

    local trail = Isaac.Spawn(
        EntityType.ENTITY_EFFECT,
        EffectVariant.SPRITE_TRAIL,
        0,
        tear.Position + tear.PositionOffset,
        Vector.Zero,
        nil
    ):ToEffect()

    -- BULLET_TRAILS_VISUAL_ONLY_TEAR_FIX
    -- Do not FollowParent() and do not use the tear as spawner.
    -- The trail is visual-only and is moved manually in TrailUpdate.
    trail.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
    trail.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
    trail.CollisionDamage = 0
    trail.Velocity = Vector.Zero

    trail.Color = color
    trail.MinRadius = length
    trail.SpriteScale = Vector.One * scale
    trail:Update()

    trail:GetData().B_BulletTrail = true
    trail:GetData().B_ParentTear = tear
end

mod:AddCallback(ModCallbacks.MC_POST_TEAR_INIT, mod.NewTear)

---@param trail EntityEffect
function mod:TrailUpdate(trail)
    local data = trail:GetData()
    local saveData = loadModData()

    if data.B_ParentProj then
        -- handle position and removing
        local parent = data.B_ParentProj
        if parent:Exists() then
            trail.ParentOffset = getPositionOffset(parent, trail.SpriteScale.Y)
        else
            trail:Remove()
        end

        -- redo color stuff because color is now set properly
        local color = saveData.TrailColor and colors[saveData.TrailColor] or DEFAULT_COLOR
        local shouldBeDogmaTrail = color == "sync" and data.B_ParentProj.SpawnerType == EntityType.ENTITY_DOGMA
        local transparency = saveData.TrailTransparency or DEFAULT_TRANSPARENCY

        if shouldBeDogmaTrail then
            color = Color(1, 1, 1, 1)
        elseif color == "sync" and data.B_ParentProj.Type ~= EntityType.ENTITY_DOGMA then
            local bulletType = parent.Variant
            ---@type Color
            local projectileColor = parent:GetColor()
            local defaultColor = Color.Lerp(Color(1, 1, 1, 1), projectileColor, 1)

            if REPENTOGON then
                local syncColor = getManualColor(parent.SpawnerType, parent.SpawnerVariant)
                if type(syncColor) == "function" then
                    syncColor = syncColor(data.B_ParentProj.SpawnerEntity)
                end

                -- Impossible to know if the tint or colorize values are set for non-rgon users.
                -- So just reserve this for rgon only.
                if bulletType == ProjectileVariant.PROJECTILE_NORMAL
                and not syncColor
                and not (allZero(defaultColor:GetColorize()) and allZero(defaultColor:GetOffset()) and allOne(defaultColor:GetTint())) then
                    color = defaultColor
                else
                    color = syncColor or bulletTypeToColor[bulletType] or defaultColor
                end
            elseif defaultColor.RO ~= 0 or defaultColor.BO ~= 0 or defaultColor.GO ~= 0 then
                defaultColor:SetColorize(projectileColor.RO, projectileColor.GO, projectileColor.BO, 1)
                color = defaultColor
            else
                local syncColor = getManualColor(parent.SpawnerType, parent.SpawnerVariant)
                if type(syncColor) == "function" then
                    syncColor = syncColor(data.B_ParentProj.SpawnerEntity)
                end
                local deliriumColor = #Isaac.FindByType(EntityType.ENTITY_DELIRIUM) > 0 and Color(1, 1, 1, 1)
                color = deliriumColor or syncColor or bulletTypeToColor[bulletType] or defaultColor
            end
        end

        color.A = transparency

        trail.Color = color

        -- handle continuum

        if parent.ProjectileFlags & ProjectileFlags.CONTINUUM ~= 0 then
            -- check if position is out of the room, and stop the trail if it is

            -- it can be this far out of bounds before it stops
            local ROOM_OUT_OF_BOUNDS_LENIENCY = 50
            local room = Game():GetRoom()
            local pos = parent.Position + parent.PositionOffset
            local roomPos = room:GetTopLeftPos()

            local roomWidth = room:GetBottomRightPos().X - roomPos.X
            local roomHeight = room:GetBottomRightPos().Y - roomPos.Y

            local outsideLeft = pos.X < roomPos.X - ROOM_OUT_OF_BOUNDS_LENIENCY
            local outsideRight = pos.X > roomPos.X + roomWidth + ROOM_OUT_OF_BOUNDS_LENIENCY
            local outsideBottom = pos.Y < roomPos.Y - ROOM_OUT_OF_BOUNDS_LENIENCY
            local outsideTop = pos.Y > roomPos.Y + roomHeight + ROOM_OUT_OF_BOUNDS_LENIENCY
            if outsideLeft or outsideRight or outsideBottom or outsideTop then
                trail.MinRadius = 1
            else
                trail.MinRadius = saveData.TrailLength and lengths[saveData.TrailLength] or DEFAULT_LENGTH
            end
        end

        if parent.SpawnerType == EntityType.ENTITY_BUMBINO or parent.SpawnerType == EntityType.ENTITY_REAP_CREEP then
            if parent.Height < -300 then
                trail.MinRadius = 1
            else
                trail.MinRadius = saveData.TrailLength and lengths[saveData.TrailLength] or DEFAULT_LENGTH
            end
        end
    end

    if data.B_ParentTear then
        local parent = data.B_ParentTear

        if parent:Exists() then
            if not isPlayerTearTrailAllowed(parent) then
                trail:Remove()
                return
            end

            -- Visual-only follow: copy position manually instead of parenting the effect.
            trail.Position = parent.Position + parent.PositionOffset
            trail.ParentOffset = Vector.Zero
            trail.Velocity = Vector.Zero
            trail.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
            trail.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
            trail.CollisionDamage = 0

            local length, scale, color = getBasicTrailSettings(parent)

            trail.Color = color
            trail.MinRadius = length
            trail.SpriteScale = Vector.One * scale
        else
            trail:Remove()
        end
    end


end

mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, mod.TrailUpdate, EffectVariant.SPRITE_TRAIL)

--#endregion


--#region MOD CONFIG MENU CODE

local function addMCMSetting(category, subcategory, setting)
    if not ModConfigMenu then
        return
    end

    local ok = pcall(function()
        ModConfigMenu.AddSetting(category, subcategory, setting)
    end)

    if not ok then
        pcall(function()
            ModConfigMenu.AddSetting(category, setting)
        end)
    end
end

local function initModConfigMenu()
    if not ModConfigMenu then
        return
    end

    local MCM = ModConfigMenu
    local category = "Bullet Trails"
    local subcategory = "Settings"

    pcall(function()
        MCM.RemoveCategory(category)
    end)

    pcall(function()
        MCM.UpdateCategory(category, {
            Info = "Bullet Trails settings"
        })
    end)

    addMCMSetting(category, subcategory, {
        Type = MCM.OptionType.BOOLEAN,

        CurrentSetting = function()
            return getSetting(loadModData(), "EnemyProjectileTrails", DEFAULT_ENEMY_PROJECTILE_TRAILS)
        end,

        Display = function()
            if getSetting(loadModData(), "EnemyProjectileTrails", DEFAULT_ENEMY_PROJECTILE_TRAILS) then
                return "Enemy projectile trails: On"
            else
                return "Enemy projectile trails: Off"
            end
        end,

        OnChange = function(currentBool)
            setSetting("EnemyProjectileTrails", currentBool)
        end,

        Info = {
            "Enable or disable trails for enemy projectiles."
        }
    })

    addMCMSetting(category, subcategory, {
        Type = MCM.OptionType.NUMBER,
        Minimum = 0,
        Maximum = 3,

        CurrentSetting = function()
            return getSetting(loadModData(), "PlayerTearTrails", DEFAULT_PLAYER_TEAR_TRAILS)
        end,

        Display = function()
            local mode = getSetting(loadModData(), "PlayerTearTrails", DEFAULT_PLAYER_TEAR_TRAILS)

            if mode == 1 then
                return "Player tear trails: Player only"
            elseif mode == 2 then
                return "Player tear trails: Player + familiars"
            elseif mode == 3 then
                return "Player tear trails: All friendly tears"
            else
                return "Player tear trails: Off"
            end
        end,

        OnChange = function(currentNum)
            setSetting("PlayerTearTrails", currentNum)
        end,

        Info = {
            "Enable trails for player tears.",
            "0 = Off",
            "1 = Player only",
            "2 = Player + familiars",
            "3 = All friendly tears"
        }
    })

    addMCMSetting(category, subcategory, {
        Type = MCM.OptionType.NUMBER,
        Minimum = 1,
        Maximum = 5,

        CurrentSetting = function()
            return loadModData().TrailLength or 3
        end,

        Display = function()
            local value = loadModData().TrailLength or 3
            local names = {
                [1] = "Very long",
                [2] = "Long",
                [3] = "Medium",
                [4] = "Short",
                [5] = "Very short"
            }

            return "Trail length: " .. names[value]
        end,

        OnChange = function(currentNum)
            setSetting("TrailLength", currentNum)
        end,

        Info = {
            "Changes trail length."
        }
    })

    addMCMSetting(category, subcategory, {
        Type = MCM.OptionType.NUMBER,
        Minimum = 1,
        Maximum = 6,

        CurrentSetting = function()
            return loadModData().TrailScale or 6
        end,

        Display = function()
            local value = loadModData().TrailScale or 6
            local names = {
                [1] = "Very small",
                [2] = "Small",
                [3] = "Medium",
                [4] = "Large",
                [5] = "Very large",
                [6] = "Sync with projectile/tear"
            }

            return "Trail size: " .. names[value]
        end,

        OnChange = function(currentNum)
            setSetting("TrailScale", currentNum)
        end,

        Info = {
            "Changes trail visual size."
        }
    })

    addMCMSetting(category, subcategory, {
        Type = MCM.OptionType.NUMBER,
        Minimum = 1,
        Maximum = 6,

        CurrentSetting = function()
            return loadModData().TrailColor or 6
        end,

        Display = function()
            local value = loadModData().TrailColor or 6
            local names = {
                [1] = "Red",
                [2] = "Green",
                [3] = "Blue",
                [4] = "White",
                [5] = "Pink",
                [6] = "Sync with projectile/tear"
            }

            return "Trail color: " .. names[value]
        end,

        OnChange = function(currentNum)
            setSetting("TrailColor", currentNum)
        end,

        Info = {
            "Changes trail color."
        }
    })

    addMCMSetting(category, subcategory, {
        Type = MCM.OptionType.NUMBER,
        Minimum = 5,
        Maximum = 100,

        CurrentSetting = function()
            return (loadModData().TrailTransparency or DEFAULT_TRANSPARENCY) * 100
        end,

        Display = function()
            local value = math.floor((loadModData().TrailTransparency or DEFAULT_TRANSPARENCY) * 100)
            return "Trail transparency: " .. value .. "%"
        end,

        OnChange = function(currentNum)
            setSetting("TrailTransparency", currentNum / 100)
        end,

        Info = {
            "Changes trail opacity.",
            "Lower values are more transparent."
        }
    })
end

initModConfigMenu()

--#endregion

--#region DSS MENU CODE

--#region MENU PROVIDER

-- This variable and all functions contained within it are required for DSS to run.
local menuProvider = {}

function menuProvider.SaveSaveData()
    storeSaveData()
end

function menuProvider.GetPaletteSetting()
    return loadModData().MenuPalette
end

function menuProvider.SavePaletteSetting(var)
    loadModData().MenuPalette = var
end

function menuProvider.GetHudOffsetSetting()
    if not REPENTANCE then
        return loadModData().HudOffset
    else
        return Options.HUDOffset * 10
    end
end

function menuProvider.SaveHudOffsetSetting(var)
    if not REPENTANCE then
        loadModData().HudOffset = var
    end
end

function menuProvider.GetGamepadToggleSetting()
    return loadModData().GamepadToggle
end

function menuProvider.SaveGamepadToggleSetting(var)
    loadModData().GamepadToggle = var
end

function menuProvider.GetMenuKeybindSetting()
    return loadModData().MenuKeybind
end

function menuProvider.SaveMenuKeybindSetting(var)
    loadModData().MenuKeybind = var
end

function menuProvider.GetMenuHintSetting()
    return loadModData().MenuHint
end

function menuProvider.SaveMenuHintSetting(var)
    loadModData().MenuHint = var
end

function menuProvider.GetMenuBuzzerSetting()
    return loadModData().MenuBuzzer
end

function menuProvider.SaveMenuBuzzerSetting(var)
    loadModData().MenuBuzzer = var
end

function menuProvider.GetMenusNotified()
    return loadModData().MenusNotified
end

function menuProvider.SaveMenusNotified(var)
    loadModData().MenusNotified = var
end

function menuProvider.GetMenusPoppedUp()
    return loadModData().MenusPoppedUp
end

function menuProvider.SaveMenusPoppedUp(var)
    loadModData().MenusPoppedUp = var
end

--#endregion

--#region MAIN MENU CODE

local DSSInitializerFunction = include("scripts.dssmenucore")
local dssModName = "Dead Sea Scrolls (Bullet Trails)"
local dssCoreVersion = 6
local dssMod = DSSInitializerFunction(dssModName, dssCoreVersion, menuProvider)

local directory = {}

directory.main = {
    title = "bullet trails",
    buttons = {
        {
            str = "resume game",
            action = "resume"
        },
        {
            str = "settings",
            dest = "settings"
        },
        {
            str = "menu settings",
            dest = "menuSettings",
            displayif = function()
                return not DeadSeaScrollsMenu.CanOpenGlobalMenu()
            end
        },
        dssMod.changelogsButton
    },
    tooltip = dssMod.menuOpenToolTip
}

directory.menuSettings = {
    title = "menu settings",
    buttons = {
        dssMod.gamepadToggleButton,
        dssMod.menuKeybindButton,
        dssMod.paletteButton,
        dssMod.menuHintButton,
        dssMod.menuBuzzerButton,
    },
    tooltip = {strset = {"dss settings"}}
}

directory.settings = {
    title = "settings",
    buttons = {
        {
            str = "trail length",
            choices = {
                "very short",
                "short",
                "medium",
                "long",
                "very long"
            },
            variable = "trailLengthOption",
            setting = 2,
            load = function ()
                return loadModData().TrailLength or 3
            end,

            store = function (var)
                loadModData().TrailLength = var
            end,

            tooltip = {strset = {
                "how long",
                "should",
                "the trail be?"
            }}
        },
        {
            str = "trail size",
            choices = {
                "very small",
                "small",
                "medium",
                "large",
                "very large",
                "sync with bullet"
            },
            variable = "trailScaleOption",
            setting = 2,
            load = function ()
                return loadModData().TrailScale or 6
            end,

            store = function (var)
                loadModData().TrailScale = var
            end,

            tooltip = {strset = {
                "how big",
                "should",
                "the trail be?"
            }}
        },
        {
            str = "trail color",
            choices = {
                "red",
                "green",
                "blue",
                "white",
                "pink",
                "sync with bullet"
            },
            variable = "trailColorOption",
            setting = 1,
            load = function ()
                return loadModData().TrailColor or 6
            end,

            store = function (var)
                loadModData().TrailColor = var
            end,

            tooltip = {strset = {
                "what color",
                "should the",
                "trail be?"
            }}
        },
        {
            str = "trail transparency",
            min = 5,
            max = 100,
            increment = 5,
            setting = 75,
            variable = "trailTransparencyOption",
            pref = "transparency: ",
            suffix = "%",

            load = function ()
                return loadModData().TrailTransparency and loadModData().TrailTransparency * 100 or 75
            end,

            store = function (var)
                loadModData().TrailTransparency = var / 100
            end,

            tooltip = {strset = {
                "how",
                "transparent",
                "should the",
                "trail be?"
            }}
        }
    }
}

--#endregion

--#region ADD DSS MENU TO GAME

local directoryKey = {
    Item = directory.main, -- This is the initial item of the menu, generally you want to set it to your main item
    Main = 'main', -- The main item of the menu is the item that gets opened first when opening your mod's menu.

    -- These are default state variables for the menu; they're important to have in here, but you don't need to change them at all.
    Idle = false,
    MaskAlpha = 1,
    Settings = {},
    SettingsChanged = false,
    Path = {},
}

DeadSeaScrollsMenu.AddMenu("Bullet Trails", {
    Run = dssMod.runMenu,
    Open = dssMod.openMenu,
    Close = dssMod.closeMenu,
    UseSubMenu = true,
    Directory = directory,
    DirectoryKey = directoryKey
})

--#endregion