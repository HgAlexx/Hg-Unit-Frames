local _, ns = ...
local ipairs, pairs = ipairs, pairs
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown

local inspector = CreateFrame("Frame")
inspector:EnableMouse(false)
local elements = {
    "name", "level", "classIcon", "classText", "guildText", "classification",
    "portrait", "model", "feedback", "pvp", "pvpTime", "threat", "marker", "role",
    "leader", "master", "activity", "happiness", "key", "combo", "elite",
    "groupText", "ticker", "nameMeter", "essence", "previewResource",
    "nameBox", "stats", "levelBox", "classBox", "classificationBox",
    "guildBox", "portraitBox", "groupBox",
}

local function hide()
    if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:IsOwned(inspector) then
        GameTooltip:Hide()
    end
end

function ns.UpdatePreviewInspector()
    if not ns.positioning or InCombatLockdown() then hide(); return end
    if not GameTooltip or GameTooltip:IsForbidden() then return end
    local x, y = GetCursorPosition()
    local hovered = false
    local function pick(region)
        if hovered or not region or not region.IsVisible or not region:IsVisible() then return end
        local left, bottom, width, height = region:GetRect()
        local parent = region:GetParent()
        local scale = region.GetEffectiveScale and region:GetEffectiveScale()
            or (parent and parent:GetEffectiveScale())
        if ns.IsSecret(left) or ns.IsSecret(bottom) or ns.IsSecret(width)
            or ns.IsSecret(height) or ns.IsSecret(scale) then return end
        if not left or not bottom or not width or not height or not scale
            or width <= 0 or height <= 0 then return end
        hovered = x >= left * scale and x <= (left + width) * scale
            and y >= bottom * scale and y <= (bottom + height) * scale
    end
    local function auras(preview)
        if not preview or not preview:IsVisible() then return end
        pick(preview.background)
        pick(preview.buffBackground)
        pick(preview.debuffBackground)
        pick(preview)
        for _, icon in ipairs(preview.icons or {}) do
            pick(icon)
            pick(icon.count)
            pick(icon.duration)
        end
    end
    for _, id in ipairs(ns.order) do
        local owner = ns.modules[id]
        if owner.frame then
            local entries = owner.units or owner.members or { owner.entry or owner, owner.target }
            for _, entry in ipairs(entries) do
                pick(entry.frame)
                for _, key in ipairs(elements) do pick(entry[key]) end
                for _, bar in pairs(entry.bars or {
                    health = entry.health, power = entry.power, pet = entry.petHealth, xp = entry.xp,
                }) do
                    pick(bar.frame)
                    for _, field in ipairs({ "text", "value", "percent", "compact", "right", "rest" }) do
                        pick(bar[field])
                    end
                end
                for _, preview in ipairs(entry.auraPreviews or {}) do auras(preview) end
                for _, key in ipairs({ "buffs", "debuffs" }) do
                    local group = entry[key]
                    if group then auras(group.preview) end
                end
                for _, border in ipairs(entry.previewBorders or {}) do pick(border) end
            end
            if id == "PlayerAura" or id == "TargetAura" or id == "FocusAura" then
                auras(owner.preview)
            end
            if id == "TargetTarget" and owner.warningPreview then
                pick(owner.warningPreview.text)
            end
        end
        if id == "CastBar" and owner.bars then
            for _, bar in pairs(owner.bars) do
                pick(bar.frame)
                pick(bar.timer)
            end
        end
    end
    if not hovered then hide(); return end
    GameTooltip:SetOwner(inspector, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(ns.L["Middle-click to open settings"], 1, 1, 1)
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
