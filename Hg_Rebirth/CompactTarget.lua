local _, ns = ...

local function overlay(owner, parent, entry)
    local button = ns.UnitOverlay(owner, parent, entry.frame, entry.unit, entry.xKey, entry.yKey)
    button:SetScript("OnEnter", function()
        if GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetUnit(entry.unit)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if not GameTooltip:IsForbidden() then GameTooltip:Hide() end
    end)
    return button
end

function ns.CreateCompactTarget(owner, entry, name)
    entry.borders = {}
    entry.frame = ns.UnitRoot(name, entry.unit, 110)
    entry.nameBox = ns.Box(entry.frame, 110, 24)
    entry.nameBox:SetPoint("TOPLEFT")
    entry.nameButton = overlay(owner, entry.nameBox, entry)
    entry.name = ns.Label(entry.nameBox, "GameFontNormal")
    entry.name:SetPoint("LEFT", 8, 0); entry.name:SetSize(97, 14)
    entry.name:SetJustifyH("LEFT"); entry.name:SetNonSpaceWrap(false)
    entry.stats = ns.Box(entry.frame, 110, 42)
    entry.stats:SetPoint("TOPLEFT", entry.nameBox, "BOTTOMLEFT", 0, 2)
    entry.statsButton = overlay(owner, entry.stats, entry)
    local markerFrame = CreateFrame("Frame", nil, entry.frame)
    markerFrame:SetSize(110, 24); markerFrame:SetPoint("TOPLEFT"); markerFrame:SetFrameStrata("MEDIUM")
    entry.marker = ns.Icon(markerFrame, "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
        18, 18, "CENTER", entry.nameBox, "TOPRIGHT", -10, -10)
    entry.health, entry.power = ns.UnitBar(entry.stats, 90), ns.UnitBar(entry.stats, 90)
    entry.health.frame:SetPoint("TOP", entry.stats, "TOP", 0, -10)
    entry.power.frame:SetPoint("TOP", entry.health.frame, "BOTTOM", 0, -2)
    entry.power.text:ClearAllPoints(); entry.power.text:SetPoint("CENTER", 0, 0)
    for index = 1, 2 do
        local bar = index == 1 and entry.health or entry.power
        bar.text:SetTextHeight(11)
        bar.button = ns.UnitOverlay(owner, bar.frame, entry.frame, entry.unit, entry.xKey, entry.yKey)
        bar.button:SetScript("OnEnter", function() bar.hover = true; owner:UpdateMember(entry) end)
        bar.button:SetScript("OnLeave", function() bar.hover = false; owner:UpdateMember(entry) end)
    end
    if owner.borderAPI then
        for _, parent in ipairs({ entry.nameBox, entry.stats }) do
            entry.borders[#entry.borders + 1] = ns.AuraBorder(parent, entry.unit)
        end
    end
    entry.frame:SetScript("OnShow", function() owner:UpdateMember(entry) end)
    return entry
end

function ns.ResetCompactTarget(entry)
    if entry.cleared then return end
    entry.cleared = true
    entry.name:SetText(""); entry.marker:Hide()
    for index = 1, 2 do
        local bar = index == 1 and entry.health or entry.power
        bar.hover = false
        bar.text:SetText("")
        bar.frame:SetMinMaxValues(0, 1); bar.frame:SetValue(0)
    end
end

function ns.UpdateCompactTargetBorders(owner, entry, exists)
    if not owner.borderAPI then return end
    local friendly = exists and UnitIsFriend("player", entry.unit)
    if ns.IsSecret(friendly) then
        friendly = false
        owner:Notice("borderReaction", "Restricted " .. entry.unit .. " reaction: debuff-border coloring is disabled.")
    end
    local enabled = entry.enabled and exists == true and friendly == true and ns.modules.Core.db.colorDebuffs
    if entry.borderEnabled ~= enabled then
        entry.borderEnabled = enabled
        for _, border in ipairs(entry.borders) do border:SetEnabled(enabled) end
    end
end

function ns.LayoutCompactTarget(owner, entry)
    local db, core = owner.db, ns.modules.Core.db
    entry.enabled, entry.powerVisible = db.enabled, db.showPower
    entry.frame:SetScale(db.scale + 1 - UIParent:GetEffectiveScale()); entry.frame:SetAlpha(db.opacity)
    entry.frame:ClearAllPoints()
    entry.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db[entry.xKey], db[entry.yKey])
    local condition = "hide"
    if db.enabled then
        condition = "[petbattle] hide; " .. (not db.showInRaid and "[group:raid] hide; " or "")
            .. "[@" .. entry.unit .. ",exists] show; hide"
    end
    ns.UnitVisibility(entry.frame, "visibility", condition)
    entry.stats:SetHeight(not db.showPower and 30 or 42)
    entry.power.frame:SetShown(entry.powerVisible); entry.power.button:SetShown(entry.powerVisible)
    if not entry.powerVisible then
        entry.power.hover = false
        entry.power.text:SetText("")
    end
    for _, parent in ipairs({ entry.nameBox, entry.stats }) do
        parent:SetBackdropColor(0, 0, 0, core.transparentBackground and 0 or 1)
    end
    for index = 1, 2 do
        local bar = index == 1 and entry.health or entry.power
        bar.frame:SetStatusBarTexture(ns.TexturePath())
        bar.background:SetTexture(core.texturedBackground and ns.TexturePath()
            or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    end
end

function ns.UpdateCompactTarget(owner, entry, kind)
    if not entry.enabled then
        ns.ResetCompactTarget(entry); entry.guid = nil; ns.UpdateCompactTargetBorders(owner, entry, false); return
    end
    local exists = UnitExists(entry.unit)
    if ns.IsSecret(exists) then
        owner:Notice("existence", "Restricted " .. entry.unit .. " existence: secure visibility remains active; unavailable updates are paused.")
        exists = false
    end
    if not exists then
        ns.ResetCompactTarget(entry); entry.guid = nil; ns.UpdateCompactTargetBorders(owner, entry, false); return
    end
    local guid = UnitGUID(entry.unit)
    if ns.IsSecret(guid) then
        entry.guid = nil
    elseif entry.guid ~= guid then
        ns.ResetCompactTarget(entry); entry.guid = guid; kind = nil
        for _, border in ipairs(entry.borders) do border:UpdateAllAuras() end
    end
    entry.cleared = false
    if not kind then
        entry.name:SetText(UnitName(entry.unit))
        local r, g, b = ns.UnitNameColor(entry.unit)
        if owner.db.className then
            local player = UnitIsPlayer(entry.unit)
            local _, class = UnitClass(entry.unit)
            if not ns.IsSecret(player) and player and not ns.IsSecret(class) then
                local color = class and RAID_CLASS_COLORS[class]
                if color then r, g, b = color.r, color.g, color.b end
            elseif ns.IsSecret(player) or ns.IsSecret(class) then
                owner:Notice("className", "Restricted " .. entry.unit .. " class: using readable reaction colors or neutral name coloring.")
            end
        end
        if not r then
            r, g, b = 1, 1, 1
            owner:Notice("name", "Restricted " .. entry.unit .. " identity: name coloring is neutral.")
        end
        entry.name:SetTextColor(r, g, b)
    end
    local dead, ghost = UnitIsDead(entry.unit), UnitIsGhost(entry.unit)
    local zero = not ns.IsSecret(dead) and not ns.IsSecret(ghost) and (dead or ghost)
    local powerType = UnitPowerType(entry.unit)
    if kind ~= "power" then
        local value, maximum, _, percent = ns.UpdateUnitBar(owner, entry.health, entry.unit, powerType, true, zero)
        if entry.health.hover then entry.health.text:SetFormattedText("%.0f/%.0f", value, maximum)
        elseif ns.IsSecret(percent) or percent ~= nil then entry.health.text:SetFormattedText("%.0f%%", percent)
        else entry.health.text:SetText("") end
    end
    if entry.powerVisible and kind ~= "health" then
        local power, powerMaximum = ns.UpdateUnitBar(owner, entry.power, entry.unit, powerType, false, zero)
        entry.power.text:SetText("")
        if entry.power.hover then
            if not ns.IsSecret(powerType) and (powerType == 1 or powerType == 2 or powerType == 6) then
                entry.power.text:SetFormattedText("%.0f", power)
            else entry.power.text:SetFormattedText("%.0f/%.0f", power, powerMaximum) end
        end
        if not ns.IsSecret(powerMaximum) and powerMaximum == 0 then
            entry.power.frame:SetStatusBarColor(0, 0, 0, 0)
            entry.power.background:SetVertexColor(0, 0, 0, 0)
        end
    end
    if kind then return end
    ns.UpdateRaidMarker(owner, entry.marker, entry.unit)
    if ns.IsSecret(dead) or ns.IsSecret(ghost) then
        owner:Notice("status", "Restricted " .. entry.unit .. " status: unavailable indicators are hidden; death state is not inferred.")
    end
    ns.UpdateCompactTargetBorders(owner, entry, true)
end
