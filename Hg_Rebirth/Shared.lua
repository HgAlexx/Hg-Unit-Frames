local _, ns = ...
local max = math.max
local min = math.min
local media = "Interface\\AddOns\\Hg_Rebirth\\Media\\"
ns.media = media
ns.colors = {
    red = { 0.75, 0, 0 }, orange = { 0.75, 0.375, 0 }, yellow = { 0.75, 0.75, 0 },
    green = { 0, 0.75, 0 }, cyan = { 0, 0.75, 0.75 }, blue = { 0, 0.3, 0.75 },
    purple = { 0.525, 0.15, 0.75 }, white = { 0.75, 0.75, 0.75 },
    grey = { 0.5, 0.5, 0.5 }, gold = { 1, 0.7, 0 }, brightGreen = { 0, 1, 0 },
}
ns.rgbRange = { rgb = true }

ns.backdrop = {
    bgFile = media .. "Black.tga", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function ns.RefreshAnimation(owner)
    if not owner.animationFrame then return end
    local callback = owner.animationActive() and owner.animationUpdate or nil
    if owner.animationFrame:GetScript("OnUpdate") ~= callback then
        owner.animationFrame:SetScript("OnUpdate", callback)
    end
end

function ns.SetAnimationUpdate(owner, frame, tick, active)
    owner.animationFrame = frame
    owner.animationActive = active
    owner.animationUpdate = function(_, elapsed)
        tick(elapsed)
        ns.RefreshAnimation(owner)
    end
    ns.RefreshAnimation(owner)
end

function ns.TexturePath()
    local index = ns.modules.Core.db.texture
    if index == 0 then return "Interface\\TargetingFrame\\UI-StatusBar" end
    return media .. "StatusBar" .. index .. ".tga"
end

function ns.Box(parent, width, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetBackdrop(ns.backdrop)
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    return frame
end

function ns.Label(parent, font)
    return parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
end

function ns.HostName(host, name)
    host.currentName = name
    local bar = host.castBar
    if bar and bar.replacing then host.name:SetText(bar.spellName)
    else host.name:SetText(name) end
end

function ns.CastHostChanged(host)
    local castModule = ns.modules.CastBar
    if castModule and castModule.started then castModule:HostChanged(host) end
end

function ns.ClearCastHost(host)
    local castModule = ns.modules.CastBar
    if castModule and host.castBar then castModule:Clear(host.castBar) end
end

function ns.Icon(parent, path, width, height, point, relative, relativePoint, x, y)
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetSize(width, height)
    icon:SetTexture(path)
    icon:SetPoint(point, relative, relativePoint, x, y)
    return icon
end

function ns.ThreatIcon(parent, point, x)
    local icon = ns.Icon(parent, "Interface\\Buttons\\WHITE8X8", 10, 10,
        point, parent, point, x, 0)
    local mask = parent:CreateMaskTexture(nil, "OVERLAY")
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    icon:SetVertexColor(1, 0, 0)
    return icon
end

function ns.UpdateRaidMarker(owner, texture, unit)
    local index = GetRaidTargetIndex(unit)
    if ns.IsSecret(index) then
        if texture.SetSpriteSheetCell then
            texture:SetSpriteSheetCell(index, 4, 4)
            texture:Show()
        else
            texture:Hide()
            owner:Notice("marker", "Restricted raid marker requires the sprite-sheet texture API.")
        end
    else
        local shown = type(index) == "number" and index >= 1 and index <= 8
        texture:SetShown(shown)
        if shown then SetRaidTargetIconTexture(texture, index) end
    end
end

function ns.UnitRoot(name, unit, width)
    local frame = CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
    frame:SetSize(width, 24)
    frame:SetFrameStrata("LOW")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetAttribute("unit", unit)
    return frame
end

function ns.UnitVisibility(frame, state, condition)
    local preview = ns.positioning and condition ~= "hide"
    local driver = preview and condition:gsub("(%[@[^%]]+,exists%] show)", "[nocombat] show; %1") or condition
    RegisterStateDriver(frame, state, driver)
    if ns.positioning and not InCombatLockdown() then
        if preview then frame:SetAlpha(1) end
        local hidden = not preview or (IsInRaid() and condition:find("[group:raid] hide", 1, true))
            or (C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle())
        frame:SetShown(not hidden)
    end
end

-- Class token for icon display: players, or NPC group members such as dungeon
-- followers (matched against party/raid tokens, which expose follower classes).
function ns.ClassIconToken(unit, isPlayer, token)
    local readable = not ns.IsSecret(token) and token ~= nil
    if readable and not ns.IsSecret(isPlayer) and isPlayer then return token end
    local raid = IsInRaid()
    local prefix, count = raid and "raid" or "party", raid and 40 or 4
    for index = 1, count do
        local member = prefix .. index
        local exists = UnitExists(member)
        if not ns.IsSecret(exists) and exists then
            local same = UnitIsUnit(unit, member)
            if not ns.IsSecret(same) and same then
                if readable then return token end
                local _, memberToken = UnitClass(member)
                if not ns.IsSecret(memberToken) then return memberToken end
                return nil
            end
        end
    end
    local inParty = UnitInParty(unit)
    if readable and not ns.IsSecret(inParty) and inParty then return token end
end

function ns.LayoutUnitName(entry, showIcon, reservePVP)
    entry.name:ClearAllPoints()
    entry.name:SetPoint("LEFT", entry.nameBox, "LEFT", showIcon and 22 or 7, 0)
    entry.name:SetSize(entry.nameBox:GetWidth() - (showIcon and 28 or 12)
        - (reservePVP and 16 or 0), 14)
end

function ns.PreviewUnit(entry, title, settings)
    local preview = ns.positioning and not InCombatLockdown()
    ns.ShowAuraPreviews(entry, preview)
    if entry.previewResource then entry.previewResource:SetShown(preview) end
    for _, border in ipairs(entry.previewBorders or {}) do border:Hide() end
    if not preview then return false end
    entry.cleared, entry.pvpTimerInitialized = nil, nil
    ns.ClearCastHost(entry)
    if entry.name then entry.name:SetText(ns.L[title]); entry.name:SetTextColor(1, 1, 0) end
    entry.currentName = ns.L[title]
    if entry.level then entry.level:SetText("80") end
    for _, key in ipairs({ "classText", "guildText", "classificationText", "key", "combo", "pvpTime" }) do
        if entry[key] then entry[key]:SetText("") end
    end
    for _, key in ipairs({ "marker", "dead", "disconnected", "threat", "pvp", "leader",
        "master", "quest", "activity", "feedback", "elite", "nameMeter" }) do
        if entry[key] then entry[key]:Hide() end
    end
    local bars = entry.bars or { health = entry.health, power = entry.power, pet = entry.petHealth, xp = entry.xp }
    local core = ns.modules.Core.db
    for key, bar in pairs(bars) do
        local health = key == "health" or key == "pet"
        local value = health and 75 or 60
        local r, g, b = 0.5, 0.5, 1
        if health then r, g, b = core.colorHealth and 0.5 or 0, core.colorHealth and 1 or 0.8, 0 end
        bar.frame:SetMinMaxValues(0, 100)
        bar.frame:SetValue(ns.modules.Core.db.invertBars and 100 - value or value)
        bar.frame:SetStatusBarColor(r, g, b)
        bar.background:SetVertexColor(r, g, b, 0.25)
        for _, textKey in ipairs({ "text", "value", "percent", "compact", "right" }) do
            if bar[textKey] then bar[textKey]:SetText("") end
        end
        local db = settings or entry.db
        local text = bar.text or bar.percent
        if text then text:SetText(health and "75%" or "60/100") end
        if db and db.healer and (health or db.manaDeficit) then
            if bar.right then bar.right:SetText(health and "-25" or "-40")
            elseif bar.value then bar.value:SetText(health and "-25" or "-40") end
        end
        if db and bar.value then
            if db.healer then
                bar.percent:SetText(db.barValues and (health and "75/100" or "60/100") or "")
            elseif db.compact then
                bar.percent:SetText(health and "75/100" or "60/100")
            else
                bar.value:SetText(health and "75/100" or "60/100")
                bar.percent:SetText(health and "75%" or "60%")
            end
        elseif db and bar.right then
            if db.style == "classic" then
                bar.right:SetText("")
                bar.text:SetText(health and "75/100 | 75%" or "60/100")
            elseif db.healer then
                bar.text:SetText(db.healerValues ~= false and (health and "75/100" or "60/100") or "")
            elseif db.compact then
                bar.text:SetText(health and "75/100" or "60/100")
            else
                bar.right:SetText(health and "75/100" or "60/100")
                bar.text:SetText(health and "75%" or "60%")
            end
        elseif db and health and (db.numericHealth or db.friendlyHealth) then
            if text then text:SetText("75/100") end
        end
        if db and db.style ~= "classic" and db.compact and db.compactPercent then
            local percentText = bar.compact or bar.percent
            if percentText then percentText:SetText(health and "75%" or "60%") end
        end
    end
    for _, key in ipairs({ "buffWrapper", "debuffWrapper", "buffContainer", "debuffContainer" }) do
        if entry[key] then entry[key]:Hide() end
    end
    for _, key in ipairs({ "buffs", "debuffs" }) do
        if entry[key] then entry[key].wrapper:Hide() end
    end
    if entry.portrait then
        entry.portrait:SetTexture("Interface\\Icons\\INV_Misc_Head_Human_01")
    end
    if entry.model then entry.model:SetUnit("player") end
    local db = settings or entry.db or {}
    if entry.portrait and entry.model then
        entry.portrait:SetShown(not db.portrait3D)
        entry.model:SetShown(db.portrait3D == true)
    end
    local className, class = UnitClass("player")
    local classColor = not ns.IsSecret(class) and RAID_CLASS_COLORS[class]
    if db.className and entry.name and classColor then
        entry.name:SetTextColor(classColor.r, classColor.g, classColor.b)
    end
    if entry.classText then entry.classText:SetText(className) end
    if entry.guildText then entry.guildText:SetText(ns.title) end
    if entry.classification then entry.classification:SetText(db.numericThreat and "75%" or ns.L["Elite"]) end
    if entry.classIcon then
        local coords = not ns.IsSecret(class) and CLASS_ICON_TCOORDS[class]
        if coords then entry.classIcon:SetTexCoord(unpack(coords)) end
        if db.classIcon ~= nil then entry.classIcon:SetShown(db.classIcon) end
    end
    if entry.pvp then
        entry.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
        entry.pvp:SetShown(db.pvpIcon == true)
    end
    if entry.classIcon and entry.name and db.classIcon ~= nil then
        ns.LayoutUnitName(entry, entry.classIcon:IsShown(), db.pvpIcon == true)
    end
    if entry.pvpTime then entry.pvpTime:SetText(db.pvpTimer and "4:59" or "") end
    if entry.key then entry.key:SetText(db.showKeys and tostring((entry.index or 1) + 1) or "") end
    if entry.combo and db.comboPoints then entry.combo:SetText("3") end
    if entry.nameMeter and db.nameMeter then
        entry.nameMeter:SetMinMaxValues(0, 5); entry.nameMeter:SetValue(3); entry.nameMeter:Show()
    end
    if entry.elite then entry.elite:SetTexture(ns.media .. "Elite.tga"); entry.elite:SetShown(db.eliteGraphic == true) end
    if entry.marker then
        SetRaidTargetIconTexture(entry.marker, 1)
        entry.marker:Show()
    end
    if entry.threat then
        entry.threat:SetShown(core.threat)
    end
    if entry.role then entry.role:SetTexCoord(unpack(ns.RoleCoordinates.DAMAGER)); entry.role:Show() end
    if entry.leader then entry.leader:Show() end
    if entry.master then entry.master:Show() end
    if entry.activity then entry.activity:SetTexCoord(0.5, 1, 0, 0.5); entry.activity:Show() end
    if entry.happiness then entry.happiness:SetTexCoord(0, 0.1875, 0, 0.359375) end
    if entry.feedback then
        entry.feedbackAge = nil
        entry.feedback:SetText("-125")
        entry.feedback:SetAlpha(1)
        entry.feedback:SetTextColor(1, 0, 0)
        entry.feedback:SetShown(db.portrait and db.combatText or false)
    end
    local borderContainers = entry.borderContainers or entry.borders
    if core.colorDebuffs and borderContainers then
        if not entry.previewBorders then
            entry.previewBorders = {}
            for _, container in ipairs(borderContainers) do
                local parent = container:GetParent()
                local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
                border:SetAllPoints(parent)
                border:SetFrameLevel(parent:GetFrameLevel() + 1)
                border:EnableMouse(false)
                border:SetBackdrop(ns.backdrop)
                border:SetBackdropColor(0, 0, 0, 0)
                border:SetBackdropBorderColor(0.2, 0.6, 1, 1)
                entry.previewBorders[#entry.previewBorders + 1] = border
            end
        end
        for _, border in ipairs(entry.previewBorders) do border:Show() end
    end
    if entry.Preview then entry:Preview() end
    local castModule = ns.modules.CastBar
    if castModule and entry.castBar then castModule:Preview(entry.castBar) end
    return true
end

function ns.SetPositioning(enabled)
    if enabled and InCombatLockdown() then ns.Warn("Cannot position frames during combat."); return false end
    ns.positioning = enabled
    if ns.RefreshPreviewInspector then ns.RefreshPreviewInspector() end
    if not enabled and ns.HidePreviewInspector then ns.HidePreviewInspector() end
    for _, id in ipairs(ns.order) do
        local module = ns.modules[id]
        if not enabled and module.frame and module.db.opacity then
            local entries = module.units or module.members or { module.entry or module, module.target }
            for _, entry in ipairs(entries) do
                entry.frame:SetAlpha(module.db.opacity)
                for _, border in ipairs(entry.previewBorders or {}) do border:Hide() end
                if entry.previewResource then entry.previewResource:Hide() end
            end
        end
        if module.frame and module.UpdateAll then module:UpdateAll() end
    end
    ns.Refresh()
    return true
end

function ns.AlignRight(owner, hostId, entries)
    if InCombatLockdown() then ns.Warn(ns.L["Cannot align frames during combat."]); return false end
    local host = ns.modules[hostId]
    if not owner.frame or not host or not host.frame or host.unavailable
        or (host.db and host.db.visibility == "hidden") then
        ns.Warn(ns.L["Alignment requires the corresponding custom host to be enabled and initialized."])
        return false
    end
    local function finite(value)
        return not ns.IsSecret(value) and type(value) == "number"
            and value == value and value ~= math.huge and value ~= -math.huge
    end
    local height, uiScale = UIParent:GetHeight(), UIParent:GetEffectiveScale()
    if not finite(height) or not finite(uiScale) or uiScale <= 0 then
        ns.Warn(ns.L["Frame alignment geometry unavailable."]); return false
    end
    local positions = {}
    for index, entry in ipairs(entries) do
        local relative = entry.index and host.members and host.members[entry.index] or host
        local right, top, relativeScale, topScale
        if relative and relative.stats and relative.nameBox then
            right, top = relative.stats:GetRight(), relative.nameBox:GetTop()
            relativeScale, topScale = relative.stats:GetEffectiveScale(), relative.nameBox:GetEffectiveScale()
        end
        local scale = entry.frame:GetEffectiveScale()
        if not finite(right) or not finite(top) or not finite(relativeScale) or relativeScale <= 0
            or not finite(topScale) or topScale <= 0 or not finite(scale) or scale <= 0 then
            ns.Warn(ns.L["Frame alignment geometry unavailable."]); return false
        end
        local offset = 2 * uiScale
        if entry.alignToBackground then
            offset = -ns.backdrop.insets.right * relativeScale
        end
        positions[index] = { x = (right * relativeScale + offset) / scale,
            y = (top * topScale - height * uiScale) / scale }
        if not finite(positions[index].x) or not finite(positions[index].y) then
            ns.Warn(ns.L["Frame alignment geometry unavailable."]); return false
        end
    end
    for index, entry in ipairs(entries) do
        owner.db[entry.xKey or "x"], owner.db[entry.yKey or "y"] = positions[index].x, positions[index].y
    end
    owner:Refresh()
    return true
end

function ns.SavePosition(owner, frame, xKey, yKey)
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = frame:GetLeft(), frame:GetTop() - UIParent:GetHeight() / scale
    owner.db[xKey], owner.db[yKey] = x, y
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    if ns.ApplySticky then ns.ApplySticky() end
end

function ns.UnitOverlay(owner, parent, root, unit, xKey, yKey)
    local button = CreateFrame("Button", nil, parent, "SecureUnitButtonTemplate")
    button:SetAllPoints(parent)
    button:SetFrameLevel(parent:GetFrameLevel() + 5)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:RegisterForDrag("LeftButton")
    button:SetAttribute("unit", unit)
    button:SetAttribute("*type1", "target")
    button:SetAttribute("*type2", "togglemenu")
    button:SetScript("OnDragStart", function()
        if not InCombatLockdown() and (ns.positioning or not owner.db.locked) then
            root:StartMoving()
            ns.BeginStickyDrag(owner, root, xKey or "x", yKey or "y")
        end
    end)
    button:SetScript("OnDragStop", function()
        ns.EndStickyDrag()
        if InCombatLockdown() then return end
        root:StopMovingOrSizing()
        ns.SavePosition(owner, root, xKey or "x", yKey or "y")
    end)
    owner.buttons[#owner.buttons + 1] = button
    return button
end

function ns.UnitBar(parent, width)
    local frame = CreateFrame("StatusBar", nil, parent)
    frame:SetSize(width, 10)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local text = ns.Label(frame)
    text:SetPoint("TOP", 0, 1)
    text:SetTextColor(1, 1, 1)
    return { frame = frame, background = background, text = text }
end

function ns.UnitNameColor(unit)
    local controlled, visible = UnitPlayerControlled(unit), UnitIsVisible(unit)
    if ns.IsSecret(controlled) or ns.IsSecret(visible) then return end
    if not controlled then
        local tapped = UnitIsTapDenied(unit)
        if ns.IsSecret(tapped) then return end
        if tapped then return 0.5, 0.5, 0.5 end
        if visible then
            local reaction = UnitReaction(unit, "player")
            if ns.IsSecret(reaction) then return end
            local color = reaction and FACTION_BAR_COLORS[reaction]
            if color then return color.r, color.g, color.b end
            return 0.5, 0.5, 1
        end
    end
    local hostile, attackable = UnitCanAttack(unit, "player"), UnitCanAttack("player", unit)
    if ns.IsSecret(hostile) or ns.IsSecret(attackable) then return end
    if attackable then
        if hostile then return 1, 0, 0 end
        return 1, 1, 0
    end
    if not hostile then
        local flagged, sanctuary = UnitIsPVP(unit), UnitIsPVPSanctuary(unit)
        local playerSanctuary = UnitIsPVPSanctuary("player")
        if ns.IsSecret(flagged) or ns.IsSecret(sanctuary) or ns.IsSecret(playerSanctuary) then return end
        if flagged and not sanctuary and not playerSanctuary then return 0, 1, 0 end
    end
    return 0.5, 0.5, 1
end

function ns.Percent(unit, powerType, health)
    local percent
    if health and UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        percent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    elseif not health and UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
        percent = UnitPowerPercent(unit, powerType, false, CurveConstants.ScaleTo100)
    end
    if ns.IsSecret(percent) then return percent end
    if percent ~= nil then return math.floor(percent + 0.5) end
    local value, maximum
    if health then value, maximum = UnitHealth(unit), UnitHealthMax(unit)
    else value, maximum = UnitPower(unit, powerType), UnitPowerMax(unit, powerType) end
    if ns.IsSecret(value) or ns.IsSecret(maximum) then return nil end
    return maximum > 0 and math.floor(value / maximum * 100 + 0.5) or 0
end

function ns.Missing(unit, powerType, health)
    if health and UnitHealthMissing then return UnitHealthMissing(unit) end
    if not health and UnitPowerMissing then return UnitPowerMissing(unit, powerType) end
    local value, maximum
    if health then value, maximum = UnitHealth(unit), UnitHealthMax(unit)
    else value, maximum = UnitPower(unit, powerType), UnitPowerMax(unit, powerType) end
    if ns.IsSecret(value) or ns.IsSecret(maximum) then return nil end
    return math.max(0, maximum - value)
end

function ns.CreateHealthCurve()
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitHealthPercent then
        local curve = C_CurveUtil.CreateColorCurve()
        curve:AddPoint(0, CreateColor(1, 0, 0))
        curve:AddPoint(0.5, CreateColor(1, 1, 0))
        curve:AddPoint(1, CreateColor(0, 1, 0))
        return curve
    end
end

function ns.UpdateUnitBar(owner, entry, unit, powerType, health, zero)
    if ns.IsSecret(powerType) then
        powerType = nil
        owner:Notice("powerType", "Restricted power type: displaying the unit's current resource without type-specific coloring.")
    end
    local value, maximum
    if health then value, maximum = UnitHealth(unit), UnitHealthMax(unit)
    else value, maximum = UnitPower(unit, powerType), UnitPowerMax(unit, powerType) end
    local core = ns.modules.Core.db
    local missing
    if zero then value, missing = 0, maximum
    else missing = ns.Missing(unit, powerType, health) end
    local shown = value
    if core.invertBars then
        if ns.IsSecret(missing) or missing ~= nil then shown = missing
        else owner:Notice("inverse", "Missing-value API unavailable: restricted bars cannot be inverted.") end
    end
    local readable = not ns.IsSecret(value) and not ns.IsSecret(maximum) and not ns.IsSecret(shown)
    local barMaximum = maximum
    if readable and maximum <= 0 then barMaximum, shown = 1, 0 end
    entry.frame:SetMinMaxValues(0, barMaximum)
    entry.frame:SetValue(shown)
    local r, g, b = 0, 0.8, 0
    if not health then
        local _, token = UnitPowerType(unit)
        local color
        if powerType == 0 then color = PowerBarColor.MANA
        elseif not ns.IsSecret(token) then color = PowerBarColor[token] end
        if color then r, g, b = color.r, color.g, color.b end
    elseif core.colorHealth then
        if zero then r, g = 1, 0
        elseif owner.healthCurve then
            local color = UnitHealthPercent(unit, true, owner.healthCurve)
            r, g, b = color:GetRGB()
        elseif readable then
            local fraction = maximum > 0 and math.max(0, math.min(1, value / maximum)) or 0
            r, g = math.min(1, 2 * (1 - fraction)), math.min(1, 2 * fraction)
        else owner:Notice("healthColor", "Health gradient unavailable for restricted health on this client.") end
    end
    entry.frame:SetStatusBarColor(r, g, b)
    entry.background:SetVertexColor(r, g, b, 0.25)
    local percent
    if zero then percent = 0
    else percent = ns.Percent(unit, powerType, health) end
    if not ns.IsSecret(percent) and percent == nil then
        owner:Notice("percent", "Percentage display API unavailable for restricted health or power.")
    end
    return value, maximum, missing, percent, readable
end

function ns.ShowCombatFeedback(owner, action, descriptor, amount, school)
    if ns.IsSecret(action) or ns.IsSecret(descriptor) or ns.IsSecret(amount) or ns.IsSecret(school) then
        owner:Notice("feedback", "Portrait combat feedback unavailable for restricted combat events.")
        return
    end
    local height, r, g, b = 30, 1, 1, 1
    local numeric = type(amount) == "number" and
        (action == "HEAL" or action == "ENERGIZE" or (action == "WOUND" and amount > 0))
    local outcome = action
    if action == "WOUND" then
        if numeric then
            if school ~= 1 then b = 0 end
        else
            local mitigated = descriptor == "ABSORB" or descriptor == "BLOCK" or descriptor == "RESIST"
            outcome = mitigated and descriptor or "MISS"
            if mitigated then height = height * 0.75 end
        end
    elseif action == "HEAL" then r, b = 0, 0
    elseif action == "ENERGIZE" then r, g, b = 0.41, 0.8, 0.94
    elseif action == "IMMUNE" then height = height * 0.5
    elseif action == "BLOCK" then height = height * 0.75 end
    if numeric then
        if descriptor == "CRITICAL" or descriptor == "CRUSHING" then height = height * 1.5
        elseif descriptor == "GLANCING" then height = height * 0.75 end
        owner.feedback:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(amount) or tostring(amount))
    else
        local labels = CombatFeedbackText or {}
        owner.feedback:SetText(labels[outcome] or _G[outcome] or outcome or "")
    end
    owner.feedback:SetTextHeight(height)
    owner.feedback:SetTextColor(r, g, b)
    owner.feedbackAge = 0
    owner.feedback:SetAlpha(0)
    owner.feedback:Show()
    ns.RefreshAnimation(owner)
end

function ns.TickCombatFeedback(owner, elapsed)
    if not owner.feedbackAge then return end
    owner.feedbackAge = owner.feedbackAge + elapsed
    local alpha = min(1, owner.feedbackAge / 0.2, (1.2 - owner.feedbackAge) / 0.3)
    owner.feedback:SetAlpha(max(0, alpha))
    if owner.feedbackAge >= 1.2 then owner.feedbackAge = nil; owner.feedback:Hide() end
end

ns.RoleCoordinates = {
    TANK = { 0, 19/64, 22/64, 41/64 },
    HEALER = { 20/64, 39/64, 1/64, 20/64 },
    DAMAGER = { 20/64, 39/64, 22/64, 41/64 },
}

ns.VitalsEventKinds = {
    UNIT_HEALTH = "health", UNIT_MAXHEALTH = "health",
    UNIT_POWER_UPDATE = "power", UNIT_POWER_FREQUENT = "power", UNIT_MAXPOWER = "power",
}

function ns.DetailedVitals(owner, unit, visibilityKey, zeroOnDeath, kind)
    if not UnitExists(unit) then return end
    local db = owner.db
    local powerType = UnitPowerType(unit)
    local dead, ghost, connected = UnitIsDead(unit), UnitIsGhost(unit), UnitIsConnected(unit)
    local zero = zeroOnDeath and not ns.IsSecret(dead) and not ns.IsSecret(ghost) and (dead or ghost)
    for index = kind == "power" and 2 or 1, kind == "health" and 1 or 2 do
        local health = index == 1
        local entry = health and owner.health or owner.power
        local value, maximum, missing, percent = ns.UpdateUnitBar(owner, entry, unit, powerType, health, zero)
        local single = not health and not ns.IsSecret(powerType)
            and (powerType == 1 or powerType == 2 or powerType == 6)
        entry.right:SetText(""); entry.percent:SetText("")
        entry.right:SetTextColor(1, 1, 1)
        if db.style == "classic" then
            if health and (ns.IsSecret(percent) or percent ~= nil) then
                entry.text:SetFormattedText("%.0f/%.0f | %.0f%%", value, maximum, percent)
            elseif single then entry.text:SetFormattedText("%.0f", value)
            else entry.text:SetFormattedText("%.0f/%.0f", value, maximum) end
        else
            if not db.compact and not db.healer and not entry.hover and (ns.IsSecret(percent) or percent ~= nil) then
                entry.text:SetFormattedText("%.0f%%", percent)
                if single then entry.right:SetFormattedText("%.0f", value)
                else entry.right:SetFormattedText("%.0f/%.0f", value, maximum) end
            else
                if single then entry.text:SetFormattedText("%.0f", value)
                else entry.text:SetFormattedText("%.0f/%.0f", value, maximum) end
            end
            if db.compact and db.compactPercent and (ns.IsSecret(percent) or percent ~= nil) then
                entry.percent:SetFormattedText("%.0f%%", percent)
            end
            if db.healer and (health or db.manaDeficit) and (ns.IsSecret(missing) or missing ~= nil) then
                entry.right:SetFormattedText("-%.0f", missing)
                if not health then entry.right:SetTextColor(0.5, 0.5, 0.5) end
            end
        end
        if not health then
            if not owner.applyPowerVisibility then
                owner.applyPowerVisibility = function()
                    local currentMaximum = UnitPowerMax(unit)
                    local shown = ns.IsSecret(currentMaximum) or currentMaximum > 0
                    if entry.frame:IsShown() ~= shown then entry.frame:SetShown(shown) end
                end
            end
            if not InCombatLockdown() or ns.pending[visibilityKey] ~= owner.applyPowerVisibility then
                ns.AfterCombat(visibilityKey, owner.applyPowerVisibility)
            end
        end
    end
    if ns.IsSecret(dead) or ns.IsSecret(ghost) or ns.IsSecret(connected) then
        owner:Notice("status", "Restricted " .. unit .. " status: unavailable indicators are hidden.")
    end
    owner.dead:SetShown(not ns.IsSecret(dead) and not ns.IsSecret(ghost) and (dead or ghost))
    if not ns.IsSecret(connected) and not connected then owner.health.text:SetText(PLAYER_OFFLINE or "Offline")
    elseif UnitIsFeignDeath then
        local feign = UnitIsFeignDeath(unit)
        if not ns.IsSecret(feign) and feign then owner.health.text:SetText(FEIGN_DEATH or "Feign Death")
        elseif ns.IsSecret(feign) then owner:Notice("status", "Restricted " .. unit .. " feign-death status.") end
    end
end

function ns.UpdateUnitPortrait(owner, unit)
    if not owner.db.portrait then return end
    local visible = UnitIsVisible(unit)
    local model = owner.db.portrait3D and not ns.IsSecret(visible) and visible
    owner.model:SetShown(model)
    owner.portrait:SetShown(not model)
    if model then owner.model:SetUnit(unit); owner.model:SetPortraitZoom(1)
    else SetPortraitTexture(owner.portrait, unit) end
end
