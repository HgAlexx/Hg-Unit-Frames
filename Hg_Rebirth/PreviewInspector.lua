local _, ns = ...
local ipairs, pairs = ipairs, pairs
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown

local inspector = CreateFrame("Frame")
inspector:EnableMouse(false)
local moduleNames = {
    Core = "Core", PlayerPet = "Player Pet", PlayerAura = "Player Aura", TargetAura = "Target Aura",
    FocusAura = "Focus Aura",
    TargetTarget = "Target Target", FocusTarget = "Focus Target",
    PartyTarget = "Party Target", PartyPet = "Party Pet", CastBar = "Cast bars",
}

local elements = {
    name = { "Player name", "className", "groupInName", "classIcon", "pvpIcon" },
    level = { "Level", "showLevel", "matchLevelHeight", "showName" },
    classIcon = { "Class icon", "classIcon" },
    classText = { "Class", "classPanel", "showLevel" },
    guildText = { "Guild", "guild" },
    classification = { "Classification", "classificationPanel", "numericThreat" },
    portrait = { "Portrait", "portrait", "portrait3D" },
    model = { "Portrait", "portrait", "portrait3D" },
    feedback = { "Portrait combat text", "portrait", "combatText" },
    pvp = { "Show PvP icon", "pvpIcon" },
    pvpTime = { "Show PvP timer", "pvpTimer", "pvpIcon" },
    threat = { "Show threat indicator", "@threat" },
    marker = { "Raid target icon" }, role = { "Role" },
    leader = { "Leader" }, master = { "Master looter" },
    activity = { "Combat" }, happiness = { "Happiness", "showHappiness" },
    key = { "Show targeting keys", "showKeys" },
    combo = { "Combo points", "comboPoints" },
    elite = { "Elite", "eliteGraphic" },
    groupText = { "Show raid group number", "raidGroup" },
    ticker = { "Show five-second mana rule", "fiveSecondRule" },
    nameMeter = { "Show class resource frame", "classResource", "resourceColor", "resourceOnTop", "nameMeter" },
    essence = { "Show class resource frame", "classResource" },
    previewResource = { "Show class resource frame", "classResource" },
}
local barKeys = { "compact", "compactPercent", "shortBars", "healer", "manaDeficit",
    "barValues", "healerValues", "numericHealth", "friendlyHealth",
    "@texture", "@texturedBackground", "@colorHealth", "@invertBars" }
local auraKeys = { "buffCount", "debuffCount", "buffSize", "debuffSize",
    "buffLocation", "debuffLocation", "auraScale", "auraTimers",
    "auraBackgroundAlpha", "showAuraBackground", "invertAuras", "auraSpacingHorizontal",
    "auraSpacingVertical", "groupSpacingVertical", "buffs", "debuffs",
    "targetBuffs", "targetDebuffs", "portraitAuras", "castableBuffs",
    "curableDebuffs", "ownDebuffs" }
local buffKeys = { "enabled", "weaponBuff", "buffPerRow", "maxNumberOfRow",
    "anchorLocation", "scale", "spacingHorizontal", "spacingVertical",
    "groupSpacingVertical", "auraTimers", "cooldownScale", "durationText",
    "secondsMode", "castableBuffs", "curableDebuffs", "ownDebuffs", "showAuraBackground", "auraBackgroundAlpha" }
local labels = {
    scale = "Scale (%)", opacity = "Opacity (%)", locked = "Lock frame position",
    compact = "Compact mode", compactPercent = "Show percentages in compact mode",
    shortBars = "Short bars in compact mode", healer = "Healer mode: show health deficit",
    manaDeficit = "Show mana deficit in healer mode", barValues = "Always show values in healer mode",
    healerValues = "Always show values in healer mode", className = "Class-colored name",
    groupInName = "Show raid group in name (in raid)", raidGroup = "Show raid group number",
    showLevel = "Show class and level frame", matchLevelHeight = "Match class and level frame height to stats frame", showName = "Show pet name and level",
    classIcon = "Show class icon", classPanel = "Show class panel",
    guild = "Show guild", classificationPanel = "Show classification",
    numericThreat = "Show numeric threat", portrait = "Show portrait",
    portrait3D = "Use 3D portrait", combatText = "Portrait combat text",
    pvpIcon = "Show PvP icon", pvpTimer = "Show PvP timer", threat = "Show threat indicator",
    colorDebuffs = "Color frame borders by debuff type", texture = "Bar texture",
    texturedBackground = "Textured bar backgrounds", colorHealth = "Color health bars by health",
    invertBars = "Invert health and power bars", transparentBackground = "Transparent backgrounds",
    showKeys = "Show targeting keys", comboPoints = "Show combo points", eliteGraphic = "Show elite graphic",
    classResource = "Show class resource frame", resourceColor = "Class resource color",
    resourceOnTop = "Show class resource bar at top of name frame", nameMeter = "Show name-frame resource meter",
    fiveSecondRule = "Show five-second mana rule", progress = "Display",
    alternateMana = "Show alternate mana bar", showXP = "Show pet experience", showPets = "Show pet health bars",
    showHappiness = "Show pet happiness",
    buffCount = "Buff count", debuffCount = "Debuff count", buffSize = "Buff size", debuffSize = "Debuff size",
    buffLocation = "Buff location", debuffLocation = "Debuff location", auraScale = "Aura scale (%)",
    auraTimers = "Show aura native cooldown", auraBackgroundAlpha = "Aura background opacity (%)",
    showAuraBackground = "Show aura backgrounds",
    invertAuras = "Show auras above frame", auraSpacingHorizontal = "Horizontal spacing",
    auraSpacingVertical = "Vertical spacing", groupSpacingVertical = "Buff/debuff gap",
    portraitAuras = "Anchor auras to portrait", castableBuffs = "Only show castable buffs",
    curableDebuffs = "Only show curable debuffs", ownDebuffs = "Only show your debuffs",
    buffs = "Show buffs", debuffs = "Show debuffs", targetBuffs = "Show buffs", targetDebuffs = "Show debuffs",
    enabled = "Enabled", weaponBuff = "Show weapon enchants", buffPerRow = "Auras per row",
    maxNumberOfRow = "Maximum aura rows", anchorLocation = "Aura anchor",
    spacingHorizontal = "Horizontal spacing", spacingVertical = "Vertical spacing",
    cooldownScale = "Cooldown scale (%)", durationText = "Show original text timers", secondsMode = "Duration seconds",
    warningMode = "Warning mode", warningSize = "Warning size",
}

local moduleLabels = {
    Core = {
        colorDebuffs = "Color borders for dispellable debuffs", colorHealth = "Color health by remaining health",
        invertBars = "Show missing health and power in bars", transparentBackground = "Transparent frame backgrounds",
    },
    Target = {
        classPanel = "Show class or creature type", guild = "Show guild name",
        classificationPanel = "Show classification panel", comboPoints = "Show combo points or essence",
        eliteGraphic = "Show elite or rare graphic", nameMeter = "Show resource meter in name",
    },
    Focus = { classPanel = "Show class or creature type", classificationPanel = "Show classification panel" },
    PlayerPet = { scale = "Pet scale (%)" },
    Party = {
        showPets = "Show embedded party-pet health bars", showKeys = "Show party targeting key labels",
        portraitAuras = "Anchor above and below auras to portrait when shown",
    },
    TargetTarget = {
        buffs = "Show target-of-target buffs", debuffs = "Show target-of-target debuffs",
        targetBuffs = "Show target-of-target-of-target buffs", targetDebuffs = "Show target-of-target-of-target debuffs",
    },
    FocusTarget = {
        enabled = "Show focus target", buffs = "Show focus-target buffs", debuffs = "Show focus-target debuffs",
    },
    PartyTarget = { enabled = "Show party targets" },
    PartyPet = { enabled = "Show party pets" },
    PlayerAura = { enabled = "Show player auras" },
    TargetAura = { enabled = "Show target auras" },
    FocusAura = { enabled = "Show focus auras" },
    CastBar = { opacity = "Cast fill opacity (%)", castColor = "Cast color",
        channelColor = "Channel color", uninterruptibleColor = "Uninterruptible cast color" },
}
labels.ownDebuffs = "Only show own debuffs on hostile targets"

local function hide()
    if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:IsOwned(inspector) then
        GameTooltip:Hide()
    end
end

function ns.UpdatePreviewInspector()
    if not ns.positioning or InCombatLockdown() then hide(); return end
    if not GameTooltip or GameTooltip:IsForbidden() then return end
    local x, y = GetCursorPosition()
    local best, area
    local function pick(region, owner, title, keys)
        if not region or not region.IsVisible or not region:IsVisible() then return end
        local left, bottom, width, height = region:GetRect()
        local parent = region:GetParent()
        local scale = region.GetEffectiveScale and region:GetEffectiveScale()
            or (parent and parent:GetEffectiveScale())
        if ns.IsSecret(left) or ns.IsSecret(bottom) or ns.IsSecret(width)
            or ns.IsSecret(height) or ns.IsSecret(scale) then return end
        if not left or not bottom or not width or not height or not scale
            or width <= 0 or height <= 0 then return end
        if x < left * scale or x > (left + width) * scale
            or y < bottom * scale or y > (bottom + height) * scale then return end
        local size = width * height * scale * scale
        if not area or size <= area then
            best, area = { region = region, owner = owner, title = title, keys = keys }, size
        end
    end
    local function auras(preview, owner, keys)
        if not preview or not preview:IsVisible() then return end
        pick(preview.background, owner, "Auras", keys)
        pick(preview.buffBackground, owner, "Auras", keys)
        pick(preview.debuffBackground, owner, "Auras", keys)
        pick(preview, owner, "Auras", keys)
        for _, icon in ipairs(preview.icons or {}) do
            pick(icon, owner, "Auras", keys)
            pick(icon.count, owner, "Auras", keys)
            pick(icon.duration, owner, "Show original text timers", keys)
        end
    end
    for _, id in ipairs(ns.order) do
        local owner = ns.modules[id]
        if owner.frame then
            local entries = owner.units or owner.members or { owner.entry or owner, owner.target }
            for _, entry in ipairs(entries) do
                pick(entry.frame, owner, "Layout", { "scale", "opacity", "locked", "@transparentBackground" })
                for _, key in ipairs({ "nameBox", "stats", "levelBox", "classBox",
                    "classificationBox", "guildBox", "portraitBox", "groupBox" }) do
                    pick(entry[key], owner, "Layout", { "scale", "opacity", "compact",
                        "portrait", "classPanel", "classificationPanel", "guild",
                        "raidGroup", "@transparentBackground" })
                end
                for key, info in pairs(elements) do pick(entry[key], owner, info[1], info) end
                for key, bar in pairs(entry.bars or {
                    health = entry.health, power = entry.power, pet = entry.petHealth, xp = entry.xp,
                }) do
                    local keys = barKeys
                    if key == "progress" then keys = { "progress", "compact", "shortBars" }
                    elseif key == "mana" then keys = { "alternateMana", unpack(barKeys) }
                    elseif key == "xp" then keys = { "showXP" }
                    elseif key == "pet" then keys = { "showPets", unpack(barKeys) } end
                    local title = key == "health" and "Health" or key == "progress" and "Progress bar"
                        or key == "xp" and "Experience" or key == "pet" and "Pet" or "Power"
                    pick(bar.frame, owner, title, keys)
                    for _, field in ipairs({ "text", "value", "percent", "compact", "right", "rest" }) do
                        pick(bar[field], owner, title, keys)
                    end
                end
                for _, preview in ipairs(entry.auraPreviews or {}) do auras(preview, owner, auraKeys) end
                for _, key in ipairs({ "buffs", "debuffs" }) do
                    local group = entry[key]
                    if group then auras(group.preview, owner, auraKeys) end
                end
                for _, border in ipairs(entry.previewBorders or {}) do
                    pick(border, owner, "Layout", { "@colorDebuffs" })
                end
                local bar = entry.castBar
                local castModule = ns.modules.CastBar
                if bar and bar.preview and castModule.db[bar.group .. "ReplaceName"] then
                    pick(entry.name, castModule, "CastBar", { bar.group .. "Enabled",
                        bar.group .. "ReplaceName" })
                end
            end
            if id == "PlayerAura" or id == "TargetAura" or id == "FocusAura" then
                auras(owner.preview, owner, buffKeys)
            end
            if id == "TargetTarget" and owner.warningPreview then
                pick(owner.warningPreview.text, owner, "Warnings", { "warningMode", "warningSize" })
            end
        end
        if id == "CastBar" and owner.bars then
            for _, bar in pairs(owner.bars) do
                local group = bar.group
                local keys = { group .. "Enabled", group .. "Timer", group .. "LeftTimer",
                    group .. "ReplaceName", "opacity", "castColor", "channelColor", "uninterruptibleColor" }
                pick(bar.frame, owner, "CastBar", keys)
                pick(bar.timer, owner, "CastBar", keys)
            end
        end
    end
    if not best then hide(); return end
    GameTooltip:SetOwner(inspector, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(ns.L["Preview settings"] .. " - " .. ns.L[best.title], 1, 0.82, 0)
    local added = {}
    local function setting(owner, key)
        if not owner or not owner.db or owner.db[key] == nil then return end
        local id
        for name, module in pairs(ns.modules) do
            if module == owner then id = name; break end
        end
        local label = (owner.settingLabels or {})[key]
        if not label then
            local castLabel = key:match("Enabled$") and "Enable embedded cast bar"
                or key:match("LeftTimer$") and "Place cast timer on the left"
                or key:match("Timer$") and "Display cast timer"
                or key:match("ReplaceName$") and "Replace unit name with spell name"
            label = ns.L[(moduleLabels[id] and moduleLabels[id][key]) or labels[key] or castLabel or key]
        end
        local name = moduleNames[id] or id
        local text = ns.L[name] .. ": " .. label
        if not added[text] then GameTooltip:AddLine(text, 1, 1, 1, true); added[text] = true end
    end
    for _, key in ipairs(best.keys) do
        if key:sub(1, 1) == "@" then setting(ns.modules.Core, key:sub(2))
        else setting(best.owner, key) end
    end
    setting(best.owner, "scale")
    GameTooltip:AddLine(ns.L["Preview samples do not simulate live conditions."], 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

local function update(_, elapsed)
    if not ns.positioning then return end
    inspector.elapsed = (inspector.elapsed or 0) + elapsed
    if inspector.elapsed < 0.1 then return end
    inspector.elapsed = 0
    ns.UpdatePreviewInspector()
end
function ns.RefreshPreviewInspector()
    inspector.elapsed = 0
    inspector:SetScript("OnUpdate", ns.positioning and update or nil)
end
ns.HidePreviewInspector = hide
