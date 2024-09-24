local build = select(4, GetBuildInfo())
local wotlk = build == 30300 or false
if wotlk then

-- Define spell and glyph IDs
local spellIDs = {
    -- Offensive Abilities
    ShieldSlam = 23922,
    Revenge = 6572,
    Devastate = 20243,
    HeroicStrike = 78,
    Shockwave = 46968,
    ConcussionBlow = 12809,
    Rend = 47465,
    ThunderClap = 47502,
    -- Defensive Abilities
    ShieldWall = 871,
    LastStand = 12975,
    EnragedRegeneration = 55694,
    ShieldBlock = 2565,
    SpellReflection = 23920,
    Disarm = 676,
    -- Utility Abilities
    Bloodrage = 2687,
    Attack = 6603,
    -- Buffs
    Enrage = 57516,
    -- Debuffs
    SunderArmor = 7386,
}

-- List of dangerous spells for Spell Reflection
local dangerousSpells = {
    -- Mage
    [42833] = true, -- Fireball
    [42842] = true, -- Frostbolt
    [42891] = true, -- Pyroblast
    [12826] = true, -- Polymorph
    -- Warlock
    [47809] = true, -- Shadow Bolt
    [59172] = true, -- Chaos Bolt
    [47843] = true, -- Unstable Affliction
    [6215] = true,  -- Fear
    -- Priest
    [48127] = true, -- Mind Blast
    [10890] = true, -- Psychic Scream
    -- Shaman
    [49271] = true, -- Chain Lightning
    [60043] = true, -- Lava Burst
    [59159] = true, -- Hex
    -- Druid
    [48465] = true, -- Starfire
    [48461] = true, -- Wrath
    [33786] = true, -- Cyclone
}

-- List of dangerous buffs for Disarm
local dangerousBuffs = {
    -- Paladin
    [31884] = true, -- Avenging Wrath
    -- Rogue
    [51690] = true, -- Killing Spree
    [13750] = true, -- Adrenaline Rush
    -- Warrior
    [1719] = true,  -- Recklessness
    -- Death Knight
    [49016] = true, -- Unholy Frenzy
    [49028] = true, -- Dancing Rune Weapon
    -- Hunter
    [3045] = true,  -- Rapid Fire
    -- Warlock
    [47241] = true, -- Metamorphosis
}

-- List of melee classes
local meleeClasses = {
    ["WARRIOR"] = true,
    ["ROGUE"] = true,
    ["DEATHKNIGHT"] = true,
    ["PALADIN"] = true,
    ["DRUID"] = true, -- Feral form
    ["SHAMAN"] = true, -- Enhancement
}

-- Abilities in order of priority
local abilities = {
    "pause",
    "cache",
    "auto_attack",
    -- Defensive abilities have higher priority
    "disarm",
    "shield_wall",
    "last_stand",
    "enraged_regeneration",
    "shield_block",
    "spell_reflection",
    -- Offensive abilities
    "shield_slam",
    "revenge",
    "devastate",
    "heroic_strike",
    "shockwave",
    "concussion_blow",
    "rend",
    "thunder_clap",
    -- Utility
    "bloodrage",
}

-- Configuration settings
local enables = {
    ["Rend"] = true,
    ["HeroicStrike"] = true,
    ["UseDefensives"] = true,
    ["UseSpellReflection"] = true,
    ["UseDisarm"] = true,
}

local values = {
    ["HeroicStrike"] = 50, -- Use Heroic Strike when rage is above this value
}

-- Helper functions
local function ValidSpell(spellID, target)
    target = target or "target"
    return ni.spell.available(spellID) and ni.spell.valid(spellID, target)
end

local function GetPlayerRage()
    return ni.player.powerraw("rage")
end

local function IsTargetAttackable()
    return ni.unit.exists("target") and ni.unit.canattack("player", "target") and not ni.unit.unitisdead("target")
end

local function IsUnderHeavyBurst()
    -- Check if the target has any dangerous burst buffs
    for buffID in pairs(dangerousBuffs) do
        if ni.unit.buff("target", buffID) then
            return true
        end
    end
    return false
end

-- Ability functions
local abilitiesFunctions = {}

-- Pause function
abilitiesFunctions["pause"] = function()
    if not IsTargetAttackable() or ni.player.isdead() then
        return true
    end
end

-- Cache function to update settings
abilitiesFunctions["cache"] = function()
    -- Update configuration values
    enables["Rend"] = ni.GUI.GetValue("ProtWarriorPvP", "Rend")
    enables["HeroicStrike"] = ni.GUI.GetValue("ProtWarriorPvP", "HeroicStrike")
    enables["UseDefensives"] = ni.GUI.GetValue("ProtWarriorPvP", "UseDefensives")
    enables["UseSpellReflection"] = ni.GUI.GetValue("ProtWarriorPvP", "UseSpellReflection")
    enables["UseDisarm"] = ni.GUI.GetValue("ProtWarriorPvP", "UseDisarm")
    values["HeroicStrike"] = ni.GUI.GetValue("ProtWarriorPvP", "HeroicStrike")
end

-- Auto Attack function
abilitiesFunctions["auto_attack"] = function()
    if not IsCurrentSpell(spellIDs.Attack) then
        ni.spell.cast(spellIDs.Attack)
    end
end

-- Disarm function
abilitiesFunctions["disarm"] = function()
    if enables["UseDisarm"] and ValidSpell(spellIDs.Disarm, "target") then
        for buffID in pairs(dangerousBuffs) do
            if ni.unit.buff("target", buffID) then
                ni.spell.cast(spellIDs.Disarm, "target")
                return true
            end
        end
    end
end

-- Shield Wall function
abilitiesFunctions["shield_wall"] = function()
    if enables["UseDefensives"] and ValidSpell(spellIDs.ShieldWall) then
        if ni.player.hp() <= 30 or IsUnderHeavyBurst() then
            ni.spell.cast(spellIDs.ShieldWall)
            return true
        end
    end
end

-- Last Stand function
abilitiesFunctions["last_stand"] = function()
    if enables["UseDefensives"] and ValidSpell(spellIDs.LastStand) and ni.player.hp() <= 40 then
        ni.spell.cast(spellIDs.LastStand)
        return true
    end
end

-- Enraged Regeneration function
abilitiesFunctions["enraged_regeneration"] = function()
    if enables["UseDefensives"] and ValidSpell(spellIDs.EnragedRegeneration) and ni.player.hp() <= 50 then
        if not ni.player.buff(spellIDs.Enrage) and ValidSpell(spellIDs.Bloodrage) then
            ni.spell.cast(spellIDs.Bloodrage) -- Activate Enrage through Bloodrage
        end
        if ni.player.buff(spellIDs.Enrage) then
            ni.spell.cast(spellIDs.EnragedRegeneration)
            return true
        end
    end
end

-- Shield Block function
abilitiesFunctions["shield_block"] = function()
    if ValidSpell(spellIDs.ShieldBlock) then
        local class = select(2, UnitClass("target"))
        local isMelee = meleeClasses[class] or false

        if isMelee and ni.unit.inmelee("player", "target") then
            -- Defensive use against melee targets in close range
            ni.spell.cast(spellIDs.ShieldBlock)
            return true
        elseif ni.spell.cd(spellIDs.ShieldSlam) == 0 then
            -- Offensive use to increase Shield Slam damage
            ni.spell.cast(spellIDs.ShieldBlock)
            return true
        end
    end
end

-- Spell Reflection function
abilitiesFunctions["spell_reflection"] = function()
    if enables["UseSpellReflection"] and ValidSpell(spellIDs.SpellReflection) then
        if ni.unit.iscasting("target") then
            local spellName, _, _, _, endTime, _, _, spellID = ni.unit.castinginfo("target")
            local timeRemaining = (endTime / 1000) - GetTime()
            if dangerousSpells[spellID] and timeRemaining <= 0.5 and ni.player.los("target") then
                ni.spell.cast(spellIDs.SpellReflection)
                return true
            end
        end
    end
end

-- Shield Slam function
abilitiesFunctions["shield_slam"] = function()
    if ValidSpell(spellIDs.ShieldSlam, "target") then
        ni.spell.cast(spellIDs.ShieldSlam, "target")
        return true
    end
end

-- Revenge function
abilitiesFunctions["revenge"] = function()
    if ValidSpell(spellIDs.Revenge, "target") then
        ni.spell.cast(spellIDs.Revenge, "target")
        return true
    end
end

-- Devastate function
abilitiesFunctions["devastate"] = function()
    if ValidSpell(spellIDs.Devastate, "target") then
        local stacks = ni.unit.debuffstacks("target", spellIDs.SunderArmor, "player") or 0
        if stacks < 5 then
            ni.spell.cast(spellIDs.Devastate, "target")
            return true
        end
    end
end

-- Heroic Strike function
abilitiesFunctions["heroic_strike"] = function()
    local rage = GetPlayerRage()
    local hsCost = ni.spell.cost(spellIDs.HeroicStrike)
    local shieldSlamCost = ni.spell.cost(spellIDs.ShieldSlam)
    local revengeCost = ni.spell.cost(spellIDs.Revenge)

    if enables["HeroicStrike"] and rage >= values["HeroicStrike"] + hsCost then
        if (rage - hsCost) >= math.min(shieldSlamCost, revengeCost) then
            if not IsCurrentSpell(spellIDs.HeroicStrike) then
                ni.spell.cast(spellIDs.HeroicStrike)
            end
        end
    end
end

-- Shockwave function
abilitiesFunctions["shockwave"] = function()
    if ValidSpell(spellIDs.Shockwave) and ni.unit.enemiesinrange("player", 10) >= 2 then
        ni.spell.cast(spellIDs.Shockwave)
        return true
    end
end

-- Concussion Blow function
abilitiesFunctions["concussion_blow"] = function()
    if ValidSpell(spellIDs.ConcussionBlow, "target") then
        ni.spell.cast(spellIDs.ConcussionBlow, "target")
        return true
    end
end

-- Rend function
abilitiesFunctions["rend"] = function()
    if enables["Rend"] and ValidSpell(spellIDs.Rend, "target") and not ni.unit.debuff("target", spellIDs.Rend, "player") then
        local class = select(2, UnitClass("target"))
        if class == "ROGUE" or (class == "DRUID" and GetShapeshiftFormID("target") == CAT_FORM) then
            ni.spell.cast(spellIDs.Rend, "target")
            return true
        end
    end
end

-- Thunder Clap function
abilitiesFunctions["thunder_clap"] = function()
    if ValidSpell(spellIDs.ThunderClap) and ni.unit.enemiesinrange("player", 8) >= 2 then
        ni.spell.cast(spellIDs.ThunderClap)
        return true
    end
end

-- Bloodrage function
abilitiesFunctions["bloodrage"] = function()
    if ValidSpell(spellIDs.Bloodrage) and GetPlayerRage() < 20 then
        ni.spell.cast(spellIDs.Bloodrage)
        return true
    end
end

-- OnLoad function
local function OnLoad()
    ni.GUI.AddFrame("ProtWarriorPvP", {
        settingsfile = "prot_warrior_pvp.json",
        {type = "title", text = "Protection Warrior PvP"},
        {type = "separator"},
        {type = "entry", text = "Use Rend", enabled = enables["Rend"], key = "Rend"},
        {type = "entry", text = "Use Heroic Strike", enabled = enables["HeroicStrike"], key = "HeroicStrike"},
        {type = "entry", text = "Rage for Heroic Strike", value = values["HeroicStrike"], key = "HeroicStrike"},
        {type = "entry", text = "Use Defensive Abilities", enabled = enables["UseDefensives"], key = "UseDefensives"},
        {type = "entry", text = "Use Spell Reflection", enabled = enables["UseSpellReflection"], key = "UseSpellReflection"},
        {type = "entry", text = "Use Disarm", enabled = enables["UseDisarm"], key = "UseDisarm"},
    })
end

-- OnUnload function
local function OnUnload()
    ni.GUI.DestroyFrame("ProtWarriorPvP")
end

-- Start the rotation
ni.bootstrap.profile("Protection Warrior PvP", abilities, abilitiesFunctions, OnLoad, OnUnload)

else
    print("This profile is only compatible with WoW version 3.3.5a.")
end
