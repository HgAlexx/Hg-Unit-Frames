local _, ns = ...
local iconSizes = setmetatable({}, { __mode = "k" })

function ns.ShowAuraPreviews(entry, shown)
    if not entry.auraPreviews then return end
    for _, preview in ipairs(entry.auraPreviews) do
        preview:SetShown(shown and preview.count > 0)
    end
end

function ns.LayoutAuraPreview(entry, anchor, count, size, columns, spacing, lineSpacing,
    point, x, y, scale, harmful, timers, relativeFrame, relativePoint)
    local show = ns.positioning and not InCombatLockdown()
    local preview = anchor.auraPreview
    if not preview then
        if not show or count == 0 then return end
        preview = CreateFrame("Frame", nil, entry.frame, "BackdropTemplate")
        preview.icons = {}
        anchor.auraPreview = preview
        entry.auraPreviews = entry.auraPreviews or {}
        entry.auraPreviews[#entry.auraPreviews + 1] = preview
    end
    preview.count = count
    preview:SetShown(show and count > 0)
    if not show then return end
    preview:SetScale(scale)
    preview:ClearAllPoints()
    preview:SetPoint(point, relativeFrame or anchor, relativePoint or point, x, y)
    preview:SetSize(math.max(1, math.min(count, columns) * (size + spacing) - spacing),
        math.max(1, math.ceil(count / columns) * (size + lineSpacing) - lineSpacing))
    local up = point == "BOTTOMLEFT"
    for index = 1, count do
        local icon = preview.icons[index]
        if not icon then
            icon = CreateFrame("Frame", nil, preview)
            ns.BindFrameOptions(icon)
            icon.texture = icon:CreateTexture(nil, "ARTWORK")
            icon.texture:SetAllPoints()
            icon.texture:SetTexture(harmful and "Interface\\Icons\\Spell_Shadow_ShadowWordPain"
                or "Interface\\Icons\\Spell_Holy_WordFortitude")
            icon.count = ns.Label(icon, "NumberFontNormalSmall")
            icon.count:SetPoint("BOTTOMRIGHT", -1, 0)
            icon.count:SetText("2")
            if harmful then
                icon.border = icon:CreateTexture(nil, "OVERLAY")
                icon.border:SetAllPoints()
                icon.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
                icon.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
                icon.border:SetVertexColor(1, 0, 0)
            end
            preview.icons[index] = icon
        end
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        icon:SetPoint(point, preview, point, ((index - 1) % columns) * (size + spacing),
            (up and 1 or -1) * math.floor((index - 1) / columns) * (size + lineSpacing))
        if timers then
            if not icon.cooldown then
                icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
                icon.cooldown:EnableMouse(false)
                icon.cooldown:SetAllPoints()
                icon.cooldown:SetReverse(true)
                icon.cooldown:SetHideCountdownNumbers(true)
            end
            icon.cooldown:Show()
            icon.cooldown:SetCooldown(GetTime() - 15, 60)
        elseif icon.cooldown then icon.cooldown:Hide() end
        icon:Show()
    end
    for index = count + 1, #preview.icons do preview.icons[index]:Hide() end
end

function ns.HasAuraAPI()
    return CustomAuraContainerGroupDefaultOptions ~= nil
        and Enum and Enum.CustomAuraButtonDispelTypeTextureStyle ~= nil
end

function ns.UnitAuraReaction(owner, unit)
    local friendly = UnitIsFriend("player", unit)
    if ns.IsSecret(friendly) then
        owner:Notice("auraReaction", "Restricted " .. unit .. " reaction: using unfiltered hostile-order aura layout.")
        return false, true
    end
    return friendly, false
end

function ns.AuraContainer(parent, unit, iconSize)
    local container = CreateFrame("AuraContainer", nil, parent,
        "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate")
    iconSizes[container] = iconSize or 24
    container:SetUnit(unit)
    return container
end

function ns.InitializeAuraButton(button, harmful, timers, countX, countY, size)
    button:SetSize(size or 24, size or 24)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    button:SetIcon(icon)
    local count = ns.Label(button, "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", countX or -1, countY or 0)
    button:SetApplicationCount(count)
    if harmful then
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        button:AddDispelTypeTexture(border, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
            showWhenHarmful = true, showWithoutDispelType = true,
        })
    end
    if timers then
        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        cooldown:SetReverse(true)
        cooldown:SetHideCountdownNumbers(true)
        button:SetDurationCooldown(cooldown)
    end
end

function ns.LayoutAuraIcons(container, keys, size, spacing, lineSpacing, maximumLineSize)
    -- Flow layout only positions restricted buttons; size them before assignment
    -- and scale their public container rather than touching assigned buttons.
    local baseSize = iconSizes[container]
    local scale = size / baseSize
    container:SetScale(scale)
    container:SetFlowLayoutMaximumLineSize(maximumLineSize and maximumLineSize / scale or math.huge)
    for _, key in ipairs(keys) do
        container:SetAuraGroupLayout(key, {
            elementWidth = baseSize, elementHeight = baseSize,
            elementSpacing = spacing / scale, lineSpacing = (lineSpacing or 0) / scale,
        })
    end
end

function ns.CreateChainedAuras(entry)
    entry.auraWrapper = CreateFrame("Frame", nil, entry.frame)
    entry.auraWrapper:SetFrameStrata("BACKGROUND")
    entry.auraWrapper:SetSize(104, 54)
    entry.auraWrapper:SetPoint("TOPLEFT", entry.stats, "BOTTOMLEFT", 3, 1)
    for _, harmful in ipairs({ false, true }) do
        local wrapper = CreateFrame("Frame", nil, entry.auraWrapper)
        wrapper:SetSize(104, 26)
        local container = ns.AuraContainer(wrapper, entry.unit, 12.5)
        container:AddAuraGroup("icons", harmful and "HARMFUL" or "HELPFUL", {
            maxFrameCount = 16,
            initializeFrame = function(button)
                ns.InitializeAuraButton(button, harmful, false, 2.5, 1, 12.5)
            end,
        })
        container:SetPoint("TOPLEFT")
        container:SetFlowLayoutAnchorPoint("TOPLEFT")
        container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
        entry[harmful and "debuffs" or "buffs"] = { wrapper = wrapper, container = container }
    end
    entry.buffWrapper, entry.debuffWrapper = entry.buffs.wrapper, entry.debuffs.wrapper
end

function ns.LayoutChainedAuras(entry, friendly, buffs, debuffs, spacing, lineSpacing, groupSpacing)
    local lineSize = 8 * 12.5 + 7 * spacing
    local width, height = math.max(1, lineSize + 0.5), math.max(1, 25 + lineSpacing)
    entry.auraWrapper:SetSize(width, height * 2 + groupSpacing + 1)
    for index = 1, 2 do
        local group = index == 1 and entry.buffs or entry.debuffs
        group.wrapper:SetSize(width, height)
        ns.LayoutAuraIcons(group.container, { "icons" }, 12.5, spacing, lineSpacing, math.max(1, lineSize))
    end
    local first, second = entry.debuffs, entry.buffs
    if friendly then first, second = entry.buffs, entry.debuffs end
    entry.buffs.wrapper:SetShown(buffs)
    entry.debuffs.wrapper:SetShown(debuffs)
    first.wrapper:ClearAllPoints()
    first.wrapper:SetPoint("TOPLEFT")
    second.wrapper:ClearAllPoints()
    local firstEnabled
    if first == entry.buffs then firstEnabled = buffs else firstEnabled = debuffs end
    if firstEnabled then second.wrapper:SetPoint("TOPLEFT", first.wrapper, "BOTTOMLEFT", 0, -groupSpacing)
    else second.wrapper:SetPoint("TOPLEFT") end
    first.container:ClearAllPoints()
    first.container:SetPoint("TOPLEFT", first.wrapper, "TOPLEFT")
    second.container:ClearAllPoints()
    if firstEnabled then
        second.container:SetPoint("TOPLEFT", first.container, "BOTTOMLEFT", 0, -groupSpacing)
    else
        second.container:SetPoint("TOPLEFT", second.wrapper, "TOPLEFT")
    end
    ns.LayoutAuraPreview(entry, entry.buffs.wrapper, buffs and 16 or 0,
        12.5, 8, spacing, lineSpacing, "TOPLEFT", 0, 0, 1, false, false)
    ns.LayoutAuraPreview(entry, entry.debuffs.wrapper, debuffs and 16 or 0,
        12.5, 8, spacing, lineSpacing, "TOPLEFT", 0, 0, 1, true, false)
end

local corners = {
    { "TOPLEFT", 0.5078125, 0.6171875 }, { "TOPRIGHT", 0.6328125, 0.7421875 },
    { "BOTTOMLEFT", 0.7578125, 0.8671875 }, { "BOTTOMRIGHT", 0.8828125, 0.9921875 },
}

local function borderPieces(parent, edgeFile, edgeSize)
    local pieces = {}
    local function texture()
        local region = parent:CreateTexture(nil, "OVERLAY")
        region:SetTexture(edgeFile)
        pieces[#pieces + 1] = region
        return region
    end
    for _, data in ipairs(corners) do
        local region = texture()
        region:SetSize(edgeSize, edgeSize)
        region:SetPoint(data[1], parent, data[1])
        region:SetTexCoord(data[2], data[3], 0.0625, 0.9375)
    end
    local top = texture()
    top:SetPoint("TOPLEFT", pieces[1], "TOPRIGHT")
    top:SetPoint("BOTTOMRIGHT", pieces[2], "BOTTOMLEFT")
    top:SetTexCoord(0.2578125, 0.9375, 0.3671875, 0.9375, 0.2578125, 0.0625, 0.3671875, 0.0625)
    local bottom = texture()
    bottom:SetPoint("TOPLEFT", pieces[3], "TOPRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", pieces[4], "BOTTOMLEFT")
    bottom:SetTexCoord(0.3828125, 0.9375, 0.4921875, 0.9375, 0.3828125, 0.0625, 0.4921875, 0.0625)
    local left = texture()
    left:SetPoint("TOPLEFT", pieces[1], "BOTTOMLEFT")
    left:SetPoint("BOTTOMRIGHT", pieces[3], "TOPRIGHT")
    left:SetTexCoord(0.0078125, 0.1171875, 0.0625, 0.9375)
    local right = texture()
    right:SetPoint("TOPLEFT", pieces[2], "BOTTOMLEFT")
    right:SetPoint("BOTTOMRIGHT", pieces[4], "TOPRIGHT")
    right:SetTexCoord(0.1328125, 0.2421875, 0.0625, 0.9375)
    return pieces
end

local function decorateAuraPanel(frame, backdrop)
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetTexture(backdrop.bgFile)
    fill:SetVertexColor(0, 0, 0, 1)
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", backdrop.insets.left, -backdrop.insets.top)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -backdrop.insets.right, backdrop.insets.bottom)
    for _, edge in ipairs(borderPieces(frame, backdrop.edgeFile, backdrop.edgeSize)) do
        edge:SetVertexColor(0.5, 0.5, 0.5, 1)
    end
end

function ns.AuraPanel(parent, backdrop)
    local frame = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
    frame:SetFrameLevel(math.max(0, parent:GetFrameLevel() - 1))
    frame:EnableMouse(false)
    decorateAuraPanel(frame, backdrop)
    return frame
end

function ns.AuraBackground(wrapper, container, backdrop, unit, harmful)
    -- Anchor propagation handles secret dimensions; no size callbacks or reads.
    local frame = CreateFrame("AuraContainer", nil, wrapper,
        "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate")
    frame:SetUnit(unit)
    frame:SetFrameLevel(math.max(0, container:GetFrameLevel() - 2))
    frame:SetPoint("TOPLEFT", container, "TOPLEFT", -5, 5)
    frame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 5, -5)
    frame:AddAuraSlot("background", harmful and "HARMFUL" or "HELPFUL", {
        initializeFrame = function(button)
            button:EnableMouse(false)
            button:SetAllPoints(frame)
            decorateAuraPanel(button, backdrop)
        end,
    })
    frame:SetEnabled(true)
    return { frame = frame, backdrop = backdrop }
end

function ns.SetAuraBackgroundAlpha(background, alpha)
    background.frame:SetAlpha(alpha)
end

function ns.AuraBorder(parent, unit)
    local container = ns.AuraContainer(parent, unit)
    container:SetAllPoints(parent)
    container:AddAuraSlot("dispel", "HARMFUL|RAID", {
        initializeFrame = function(button)
            button:EnableMouse(false)
            button:SetAllPoints(parent)
            local pieces = borderPieces(button, ns.backdrop.edgeFile, ns.backdrop.edgeSize)
            for _, region in ipairs(pieces) do
                button:AddDispelTypeTexture(region, {
                    style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                    showWhenHarmful = true,
                })
            end
        end,
    })
    return container
end
