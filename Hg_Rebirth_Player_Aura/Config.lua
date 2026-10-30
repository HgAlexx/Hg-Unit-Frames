local ns = Hg_Rebirth
local Buff = ns.modules.PlayerAura

function Buff:BuildOptions(category)
    ns.BuildAuraOptions(self, category, "Player Aura",
        "Player buffs, debuffs and weapon enchants. Anchored to Player when loaded; otherwise the native player frame.", {
        { "enabled", "Show player auras" }, { "showBlizzard", "Show native player auras" },
        { "weaponBuff", "Show weapon enchants" }, { "durationText", "Show original text timers" },
        { "auraTimers", "Show aura native cooldown" },
        { "showAuraBackground", "Show aura backgrounds" },
        { "castableBuffs", "Only show castable buffs" }, { "curableDebuffs", "Only show curable debuffs" },
    },
        "Reset Player Aura settings", "Reset Player Aura settings for this character?")
end

if ns.loggedIn then
    Buff:Start()
    if ns.category then Buff:BuildOptions(ns.category); ns.RefreshOptions() end
end
