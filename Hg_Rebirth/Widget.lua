local _, ns = ...
local panels = {}
local categoriesByKey = {}
local categoryOrder = {
    ["Common settings"] = 0,
    ["Player"] = 1, ["Player Aura"] = 1.5, ["Player Pet"] = 2,
    ["Target"] = 3, ["Target Aura"] = 3.5, ["Target Target"] = 4,
    ["Focus"] = 5, ["Focus Aura"] = 5.5, ["Focus Target"] = 6, ["Party"] = 7,
    ["Party Target"] = 8, ["Party Pet"] = 9, ["Cast bars"] = 10,
    ["Settings presets"] = -1,
}
local categoryRanks = {}
local stickyPanels = {
    ["Player"] = "Player", ["Player Pet"] = "PlayerPet", ["Target"] = "Target",
    ["Target Target"] = "TargetTarget", ["Focus"] = "Focus", ["Focus Target"] = "FocusTarget",
    ["Party"] = "Party", ["Party Target"] = "PartyTarget", ["Party Pet"] = "PartyPet",
}

function ns.OpenOptions()
    if InCombatLockdown() then
        ns.Warn(ns.L["Cannot open settings during combat."])
        return
    end
    local storage = ns.modules.Core.storage
    local key = storage.lastCategories and storage.lastCategories[ns.characterKey]
    local category = (type(key) == "string" and categoriesByKey[key]) or ns.category
    if category then Settings.OpenToCategory(category:GetID()) end
end

local function tooltip(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

StaticPopupDialogs.HG_REBIRTH_CONFIRM = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function(_, action) action() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
    preferredIndex = 3,
}

function ns.Confirm(message, callback)
    StaticPopup_Show("HG_REBIRTH_CONFIRM", message, nil, callback)
end

local function addControl(parent, refresh)
    local controls = parent.optionsPanel.optionRefreshes
    controls[#controls + 1] = refresh
end

function ns.Panel(title, subtitle, parentCategory, build)
    local key = title
    local rank = categoryOrder[title] or 100
    title = ns.L[title]
    local panel = CreateFrame("Frame")
    panel:Hide()
    panel.optionRefreshes = {}
    local heading = ns.Label(panel, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetTextHeight(22)
    heading:SetText(title)
    local description = ns.Label(panel, "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
    description:SetJustifyH("LEFT")
    description:SetTextColor(0.75, 0.75, 0.75)
    description:SetWordWrap(true)
    description:SetNonSpaceWrap(true)
    description:SetText(subtitle)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll.ScrollBar.scrollStep = 28
    scroll:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 1)
    scroll:SetScrollChild(content)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
    content.cursor = 0
    content.optionsPanel = panel
    function panel:BuildOptions()
        if not build then return end
        local initialize = build
        build = nil
        initialize(content)
        local module = ns.modules[stickyPanels[key]]
        if module and module.defaults.showTooltip ~= nil then ns.TooltipOptions(content, module) end
        if module and ns.StickyOptions then ns.StickyOptions(content, module) end
    end
    local category
    if parentCategory then
        category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, title)
        categoryRanks[category] = rank
        parentCategory:SetShouldSortAlphabetically(false)
        table.sort(parentCategory:GetSubcategories(), function(left, right)
            local leftRank, rightRank = categoryRanks[left] or 100, categoryRanks[right] or 100
            if leftRank == rightRank then return left:GetID() < right:GetID() end
            return leftRank < rightRank
        end)
    else
        category = Settings.RegisterCanvasLayoutCategory(panel, title)
        Settings.RegisterAddOnCategory(category)
    end
    categoriesByKey[key] = category
    local restoringScroll = false
    local restoringLayout = false
    local function restoreScroll()
        local storage = ns.modules.Core.storage
        local positions = storage.scrollPositions and storage.scrollPositions[ns.characterKey]
        local position = positions and positions[key] or 0
        local maximum = scroll:GetVerticalScrollRange()
        restoringScroll = true
        position = math.min(position, maximum)
        scroll.ScrollBar:SetValue(position)
        scroll:SetVerticalScroll(position)
        restoringScroll = false
    end
    scroll:HookScript("OnVerticalScroll", function(_, position)
        if restoringScroll or restoringLayout or not panel:IsShown() then return end
        local storage = ns.modules.Core.storage
        storage.scrollPositions = storage.scrollPositions or {}
        local positions = storage.scrollPositions[ns.characterKey] or {}
        storage.scrollPositions[ns.characterKey] = positions
        positions[key] = position
    end)
    scroll:HookScript("OnScrollRangeChanged", function()
        if panel:IsShown() then restoreScroll() end
    end)
    panel:SetScript("OnShow", function()
        restoringLayout = true
        panel:BuildOptions()
        local storage = ns.modules.Core.storage
        storage.lastCategories = storage.lastCategories or {}
        storage.lastCategories[ns.characterKey] = key
        ns.RefreshOptions(panel)
        panel:SetScript("OnUpdate", function()
            restoreScroll()
            restoringLayout = false
            panel:SetScript("OnUpdate", nil)
        end)
        restoreScroll()
    end)
    panels[#panels + 1] = panel
    return content, category
end

function ns.TooltipOptions(content, module)
    ns.Section(content, "Tooltip")
    ns.Check(content, module, "showTooltip", "Show unit tooltip")
    ns.SubOptions(content, function() return module.db.showTooltip end, function()
        ns.Select(content, "Tooltip anchor", function()
            return {
                { text = "Right of frame", value = "right" },
                { text = "WoW default", value = "default" },
            }
        end, function() return module.db.tooltipAnchor end,
            function(value) ns.Set(module, "tooltipAnchor", value) end)
    end)
end

local INDENT = 20
local DISABLED_COLOR = { 0.5, 0.5, 0.5 }

local function rememberTextColor(text)
    if not text or not text.SetTextColor then return end
    if not text.enabledColor then text.enabledColor = { text:GetTextColor() } end
end

local function setTextEnabled(text, enabled)
    if not text or not text.SetTextColor then return end
    rememberTextColor(text)
    local color = enabled and text.enabledColor or DISABLED_COLOR
    text:SetTextColor(color[1], color[2], color[3])
end

local function setWidgetEnabled(widget, enabled)
    if widget:GetObjectType() == "FontString" then setTextEnabled(widget, enabled); return end
    if widget.OnButtonStateChanged then
        if enabled then widget:Enable() else widget:Disable() end
        widget:OnButtonStateChanged()
        return
    end
    local label = widget.GetFontString and widget:GetFontString()
    rememberTextColor(label)
    rememberTextColor(widget.Text)
    rememberTextColor(widget.Low)
    rememberTextColor(widget.High)
    if enabled then widget:Enable() else widget:Disable() end
    setTextEnabled(label, enabled)
    setTextEnabled(widget.Text, enabled)
    setTextEnabled(widget.Low, enabled)
    setTextEnabled(widget.High, enabled)
end

local function conditionsMet(conditions)
    for _, condition in ipairs(conditions) do
        if not condition() then return false end
    end
    return true
end

local function place(parent, widget, height, structural)
    widget:SetPoint("TOPLEFT", parent, "TOPLEFT", (parent.indent or 0) * INDENT, -parent.cursor)
    parent.cursor = parent.cursor + height
    parent:SetHeight(parent.cursor + 16)
    local conditions = parent.conditions
    if not structural and conditions and #conditions > 0 then
        addControl(parent, function() setWidgetEnabled(widget, conditionsMet(conditions)) end)
    end
end

-- Controls built inside `build` are greyed out while `condition` returns false.
-- Nested calls combine conditions; `indented` places them under their parent setting.
local function dependent(parent, condition, build, indented)
    local previous = parent.conditions or {}
    local conditions = {}
    for index, value in ipairs(previous) do conditions[index] = value end
    conditions[#conditions + 1] = condition
    parent.conditions = conditions
    if indented then parent.indent = (parent.indent or 0) + 1 end
    build()
    if indented then parent.indent = parent.indent - 1 end
    parent.conditions = previous
end

function ns.SubOptions(parent, condition, build) dependent(parent, condition, build, true) end
function ns.DependentOptions(parent, condition, build) dependent(parent, condition, build, false) end

function ns.Section(parent, text)
    local label = ns.Label(parent, "GameFontNormalLarge")
    label:SetHeight(24)
    label:SetJustifyV("TOP")
    parent.cursor = parent.cursor + 10
    place(parent, label, 32, true)
    label:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -(parent.cursor - 32))
    label:SetJustifyH("LEFT")
    label:SetText(ns.L[text])
    return label
end

function ns.Check(parent, module, key, text, tip)
    module.settingLabels = module.settingLabels or {}
    module.settingLabels[key] = ns.L[text]
    return ns.Toggle(parent, text, function() return module.db[key] end,
        function(value) ns.Set(module, key, value) end, tip)
end

function ns.Toggle(parent, text, getValue, setValue, tip)
    local check = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    check:SetSize(24, 24)
    place(parent, check, 28)
    check.Text:SetText(ns.L[text])
    check.tip = tip
    check:SetScript("OnEnter", tooltip)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked())
    end)
    addControl(parent, function() check:SetChecked(getValue()) end)
    return check
end

function ns.TextInput(parent, text)
    local label = ns.Label(parent)
    place(parent, label, 20)
    label:SetText(ns.L[text])
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(280, 24)
    input:SetAutoFocus(false)
    input:SetMaxBytes(80)
    place(parent, input, 36)
    -- InputBoxTemplate's left border extends outside the edit box.
    input:SetPoint("TOPLEFT", parent, "TOPLEFT", (parent.indent or 0) * INDENT + 8, -(parent.cursor - 36))
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return input
end

function ns.Slider(parent, module, key, text, minimum, maximum, step, multiplier)
    module.settingLabels = module.settingLabels or {}
    module.settingLabels[key] = ns.L[text]
    text = ns.L[text]
    multiplier = multiplier or 1
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider.Text:ClearAllPoints()
    slider.Low:ClearAllPoints()
    slider.High:ClearAllPoints()
    slider.Text:SetPoint("BOTTOM", slider, "TOP", 0, 4)
    slider.Low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    slider.High:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    slider:SetSize(260, 16)
    parent.cursor = parent.cursor + 18
    place(parent, slider, 44)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(_, delta)
        if not slider:IsEnabled() then return end
        local value = slider:GetValue()
        if (delta > 0) then
            value = math.max(minimum, math.min(maximum, value + step))
        elseif (delta < 0) then
            value = math.max(minimum, math.min(maximum, value - step))
        else
            return
        end
        slider:SetValue(value)
    end)
    slider.Low:SetText(minimum)
    slider.High:SetText(maximum)
    local updating
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value / step + 0.5) * step
        slider.Text:SetText(text .. ": " .. value)
        if not updating then ns.Set(module, key, value / multiplier) end
    end)
    addControl(parent, function()
        updating = true
        slider:SetValue(module.db[key] * multiplier)
        slider.Text:SetText(text .. ": " .. math.floor(module.db[key] * multiplier / step + 0.5) * step)
        updating = false
    end)
    if key == "scale" or key == "targetScale" then
        local conditions = parent.conditions or {}
        addControl(parent, function()
            setWidgetEnabled(slider, conditionsMet(conditions)
                and not (ns.StickyScaleControlled and ns.StickyScaleControlled(module, key)))
        end)
    end
end

function ns.Button(parent, text, callback, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 260, 24)
    place(parent, button, 32)
    button:SetText(ns.L[text])
    local label = button:GetFontString()
    label:SetWordWrap(false)
    button:SetWidth(math.max(width or 260, math.ceil(label:GetStringWidth()) + 32))
    button:SetScript("OnClick", callback)
    return button
end

function ns.ColorPicker(parent, module, key, text)
    module.settingLabels = module.settingLabels or {}
    module.settingLabels[key] = ns.L[text]
    local label = ns.Label(parent)
    place(parent, label, 20)
    label:SetText(ns.L[text])
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetBackdrop(ns.backdrop)
    swatch:SetBackdropBorderColor(1, 1, 1, 1)
    swatch:SetSize(64, 24)
    place(parent, swatch, 32)
    swatch.color = swatch:CreateTexture(nil, "OVERLAY")
    swatch.color:SetPoint("TOPLEFT", 4, -4)
    swatch.color:SetPoint("BOTTOMRIGHT", -4, 4)
    swatch:SetScript("OnClick", function()
        local previous = ns.Copy(module.db[key])
        local function apply()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            ns.Set(module, key, { r, g, b })
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = previous[1], g = previous[2], b = previous[3], hasOpacity = false,
            extraInfo = swatch,
            swatchFunc = apply,
            cancelFunc = function() ns.Set(module, key, previous) end,
        })
    end)
    local reset = ns.Button(parent, "Reset color", function()
        if ColorPickerFrame:IsShown() and ColorPickerFrame:GetExtraInfo() == swatch then
            ColorPickerFrame:Hide()
        end
        ns.Set(module, key, ns.Copy(module.defaults[key]))
    end, 130)
    reset:ClearAllPoints()
    reset:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    parent.cursor = parent.cursor - 32
    parent:SetHeight(parent.cursor + 16)
    addControl(parent, function()
        local rgb = module.db[key]
        swatch.color:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
    end)
    return swatch, reset
end

function ns.BooleanButtons(parent, text, apply)
    local label = ns.Label(parent)
    place(parent, label, 20)
    label:SetText(ns.L[text])
    local on = ns.Button(parent, "Set on", function() apply(true) end, 110)
    local off = ns.Button(parent, "Set off", function() apply(false) end, 110)
    off:ClearAllPoints()
    off:SetPoint("LEFT", on, "RIGHT", 8, 0)
    parent.cursor = parent.cursor - 32
    parent:SetHeight(parent.cursor + 16)
end

function ns.Description(parent, text)
    local note = ns.Label(parent, "GameFontHighlightSmall")
    note:SetWidth(560)
    note:SetHeight(36)
    note:SetWordWrap(true)
    note:SetJustifyH("LEFT")
    note:SetText(ns.L[text])
    place(parent, note, 44)
    return note
end

function ns.Select(parent, label, choices, getValue, setValue)
    local title = ns.Label(parent)
    place(parent, title, 20)
    title:SetText(ns.L[label])
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(280)
    place(parent, dropdown, 36)
    dropdown:SetupMenu(function(_, root)
        for _, choice in ipairs(choices()) do
            root:CreateRadio(choice.raw and choice.text or ns.L[choice.text], function() return getValue() == choice.value end,
                function() setValue(choice.value) end)
        end
    end)
    addControl(parent, function()
        dropdown:GenerateMenu()
        if dropdown.OnButtonStateChanged then dropdown:OnButtonStateChanged() end
    end)
    return dropdown
end

-- Count slider with the filter, size and location settings it controls indented beneath it.
function ns.AuraGroupOptions(parent, module, harmful, locations)
    local db = function() return module.db end
    if harmful then
        ns.Slider(parent, module, "debuffCount", "Debuff count", 0, 16, 1)
        ns.SubOptions(parent, function() return db().debuffCount > 0 end, function()
            ns.Check(parent, module, "curableDebuffs", "Only show curable debuffs")
            ns.Slider(parent, module, "debuffSize", "Debuff size", 1, 50, 1)
            ns.Select(parent, "Debuff location", locations, function() return db().debuffLocation end,
                function(value) ns.Set(module, "debuffLocation", value) end)
        end)
    else
        ns.Slider(parent, module, "buffCount", "Buff count", 0, 16, 1)
        ns.SubOptions(parent, function() return db().buffCount > 0 end, function()
            ns.Check(parent, module, "castableBuffs", "Only show castable buffs")
            ns.Slider(parent, module, "buffSize", "Buff size", 1, 50, 1)
            ns.Select(parent, "Buff location", locations, function() return db().buffLocation end,
                function(value) ns.Set(module, "buffLocation", value) end)
        end)
    end
end

function ns.HasAuraCount(module)
    return module.db.buffCount > 0 or module.db.debuffCount > 0
end

function ns.NudgeFrames(owner, dx, dy)
    if InCombatLockdown() then ns.Warn(ns.L["Cannot nudge frames during combat."]); return false end
    if not owner.frame or owner.unavailable then
        ns.Warn(ns.L["Frame positioning requires initialized custom frames."]); return false
    end
    local entries = { { frame = owner.frame, xKey = "x", yKey = "y" } }
    if owner.members and owner.members[1] and owner.members[1].xKey then
        entries = owner.members
    elseif owner.target then
        entries[2] = { frame = owner.target.frame, xKey = "targetX", yKey = "targetY" }
    end
    local function finite(value)
        return not ns.IsSecret(value) and type(value) == "number"
            and value == value and value ~= math.huge and value ~= -math.huge
    end
    local uiScale = UIParent:GetEffectiveScale()
    local positions = {}
    for index, entry in ipairs(entries) do
        local scale = entry.frame and entry.frame:GetEffectiveScale()
        local x, y = owner.db[entry.xKey], owner.db[entry.yKey]
        if not finite(uiScale) or uiScale <= 0 or not finite(scale) or scale <= 0
            or not finite(x) or not finite(y) then
            ns.Warn(ns.L["Frame positioning geometry unavailable."]); return false
        end
        positions[index] = { x = x + dx * uiScale / scale, y = y + dy * uiScale / scale }
        if not finite(positions[index].x) or not finite(positions[index].y) then
            ns.Warn(ns.L["Frame positioning geometry unavailable."]); return false
        end
    end
    for index, entry in ipairs(entries) do
        owner.db[entry.xKey], owner.db[entry.yKey] = positions[index].x, positions[index].y
    end
    owner:Refresh()
    return true
end

function ns.NudgeControls(parent, owner)
    local cursor, x = parent.cursor, 0
    for _, direction in ipairs({
        { "Nudge up 1 pixel", 0, 1, "^" }, { "Nudge down 1 pixel", 0, -1, "v" },
        { "Nudge left 1 pixel", -1, 0, "<" }, { "Nudge right 1 pixel", 1, 0, ">" },
    }) do
        parent.cursor = cursor
        local button = ns.Button(parent, direction[4],
            function() ns.NudgeFrames(owner, direction[2], direction[3]) end, 40)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -cursor)
        button.tip = ns.L[direction[1]]
        button:EnableMouseWheel(true)
        button:SetScript("OnMouseWheel", function(_, delta)
            if delta ~= 0 then ns.NudgeFrames(owner, direction[2] * delta, direction[3] * delta) end
        end)
        button:SetScript("OnEnter", tooltip)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        x = x + button:GetWidth() + 4
    end
end

function ns.RefreshOptions(panel)
    for _, candidate in ipairs(panels) do
        if (not panel or candidate == panel) and candidate:IsVisible() then
            for _, refresh in ipairs(candidate.optionRefreshes) do refresh() end
        end
    end
end
