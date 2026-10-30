local ns = Hg_Rebirth
local Buff = {
    savedVariable = "Hg_Rebirth_Player_Aura_Options",
    defaults = {
        enabled = false, showBlizzard = false, weaponBuff = true, scale = 0.7,
        offsetVertical = 0, offsetHorizontal = 0, spacingVertical = 1, spacingHorizontal = 1,
        groupSpacingVertical = 3,
        buffPerRow = 10, maxNumberOfRow = 4, anchorLocation = 1,
        auraTimers = false, cooldownScale = 0.7, durationText = true, secondsMode = 2,
        castableBuffs = false, curableDebuffs = false,
        showAuraBackground = false, auraBackgroundAlpha = 1,
    },
    ranges = {
        scale = { 0.1, 2 }, cooldownScale = { 0.1, 2 },
        offsetVertical = { -250, 250 }, offsetHorizontal = { -250, 250 },
        spacingVertical = { -100, 100 }, spacingHorizontal = { -100, 100 },
        groupSpacingVertical = { 0, 100 },
        auraBackgroundAlpha = { 0, 1 },
        buffPerRow = { 1, 40, integer = true }, maxNumberOfRow = { 1, 40, integer = true },
        anchorLocation = { 1, 4, integer = true }, secondsMode = { 0, 2, integer = true },
    },
    nativeState = {},
}
ns.InstallAuraEngine(Buff, "player", "PlayerAura")
ns.RegisterModule("PlayerAura", Buff)

function Buff:Notice(key, message)
    self.notices = self.notices or {}
    if self.notices[key] then return end
    self.notices[key] = true
    ns.Warn("Player Aura: " .. ns.L[message])
end

function Buff:UpdateNative(active)
    local player = ns.modules.Player
    local hostVisible = not player or not player.frame or not player.db.opacity or player.db.opacity > 0
    local suppress = active and hostVisible and self.frame:IsVisible() and not self.db.showBlizzard
    for _, name in ipairs({ "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" }) do
        local frame = _G[name]
        if frame then
            local hide = suppress and (name ~= "TemporaryEnchantFrame" or self.includesWeapons)
            local previous = self.nativeState[frame]
            if hide and not previous then
                self.nativeState[frame] = { alpha = frame:GetAlpha(), mouse = frame:IsMouseEnabled(),
                    parent = frame:GetParent() }
            elseif not hide and previous then
                frame:SetParent(previous.parent)
                frame:SetAlpha(previous.alpha)
                frame:EnableMouse(previous.mouse)
                self.nativeState[frame] = nil
            end
            if hide then
                if frame:GetParent() ~= self.hiddenNative then frame:SetParent(self.hiddenNative) end
                local alpha = frame:GetAlpha()
                if ns.IsSecret(alpha) or alpha ~= 0 then frame:SetAlpha(0) end
                local mouse = frame:IsMouseEnabled()
                if ns.IsSecret(mouse) or mouse then frame:EnableMouse(false) end
            end
        end
    end
end

function Buff:UpdateFilters()
    local entry = self.active
    entry.container:SetAuraGroupFilterString("buffs", self.db.castableBuffs and "HELPFUL|RAID" or "HELPFUL")
    entry.debuffContainer:SetAuraGroupFilterString("debuffs", self.db.curableDebuffs and "HARMFUL|RAID" or "HARMFUL")
end

function Buff:Layout()
    local db = self.db
    local player = ns.modules.Player
    local host = player and player.frame and not player.unavailable and player or nil
    self.layoutHost = host
    local parent = host and host.frame or UIParent
    self.frame:SetParent(parent)
    self.frame:SetScale(db.scale)
    local right, up = db.anchorLocation % 2 == 0, db.anchorLocation >= 3
    local point = up and (right and "BOTTOMRIGHT" or "BOTTOMLEFT") or (right and "TOPRIGHT" or "TOPLEFT")
    local target = host and (up and self:TopAnchor(host) or host.stats) or PlayerFrame
    if host and db.anchorLocation == 1 and host.db.showLevel then target = host.levelBox end
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, target, up and (right and "TOPRIGHT" or "TOPLEFT") or (right and "BOTTOMRIGHT" or "BOTTOMLEFT"),
        db.offsetHorizontal / db.scale, db.offsetVertical / db.scale)
    self:UpdateFormatter()
    local weapons = db.weaponBuff and AuraContainerItemEnchantmentSlot ~= nil
    self.includesWeapons = weapons
    if db.weaponBuff and not weapons then self:Notice("weaponAPI", "Weapon enchant aura API unavailable; native weapon enchants remain visible.") end
    local entry = self:Container(weapons)
    for _, other in pairs(self.containers) do
        if other ~= entry then
            other.container:SetEnabled(false); other.container:Hide()
            other.debuffContainer:SetEnabled(false); other.debuffContainer:Hide()
            other.buffBackground.frame:SetEnabled(false)
            other.debuffBackground.frame:SetEnabled(false)
        end
    end
    self.active = entry
    self:LayoutContainers(entry, point, right, up, weapons)
    self.frame:SetShown(db.enabled)
    self:Preview()
    self:UpdateNative(db.enabled)
end

function Buff:Start()
    if InCombatLockdown() then ns.AfterCombat("PlayerAuraStart", function() self:Start() end); return end
    if self.frame or self.unavailable then return end
    if not ns.HasAuraAPI() then
        self.unavailable = true
        self:Notice("auraAPI", "Mainline aura API unavailable; native Player auras retained.")
        return
    end
    self:InitializeFormatter()
    self.frame = CreateFrame("Frame", "Hg_Rebirth_PlayerAuraFrame", UIParent)
    self.frame:SetSize(1, 1)
    self.hiddenNative = CreateFrame("Frame", nil, UIParent)
    self.hiddenNative:Hide()
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TOTEM_UPDATE",
        "GROUP_ROSTER_UPDATE", "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "ADDON_LOADED" }) do
        self.events:RegisterEvent(event)
    end
    self.events:SetScript("OnEvent", function(_, event)
        local player = ns.modules.Player
        local host = player and player.frame and not player.unavailable and player or nil
        if InCombatLockdown() or event == "PLAYER_ENTERING_WORLD" or host ~= self.layoutHost then
            self:Refresh()
        else self:UpdateNative(self.db.enabled) end
    end)
    self:Layout()
end
