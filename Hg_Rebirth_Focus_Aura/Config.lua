local ns = Hg_Rebirth
local Buff = ns.modules.FocusAura

function Buff:BuildOptions(category)
    ns.BuildAuraOptions(self, category, "Focus Aura",
        "Focus buffs and debuffs anchored to Focus.", {
        { "enabled", "Show focus auras" }, { "durationText", "Show original text timers" },
        { "auraTimers", "Show aura native cooldown" },
        { "showAuraBackground", "Show aura backgrounds" },
        { "castableBuffs", "Only show castable buffs" }, { "curableDebuffs", "Only show curable debuffs" },
        { "ownDebuffs", "Only show own debuffs on hostile targets" },
    },
        "Reset Focus Aura settings", "Reset Focus Aura settings for this character?")
end

if ns.loggedIn then
    Buff:Start()
    if ns.category then Buff:BuildOptions(ns.category); ns.RefreshOptions() end
end
