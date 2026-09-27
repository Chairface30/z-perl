-- ZPerl Big Debuffs Spell Database
-- Based on BigDebuffs by Jordon, adapted for ZPerl
-- Priority categories (higher = more important)

local addonName, addon = ...
addon.Spells = addon.Spells or {}

-- Spell type constants (used for priority calculation)
local BUFF_DEFENSIVE = "buffs_defensive"
local BUFF_OFFENSIVE = "buffs_offensive"
local BUFF_OTHER = "buffs_other"
local BUFF_SPEED = "buffs_speed_boost"
local INTERRUPT = "interrupts"
local CROWD_CONTROL = "cc"
local ROOT = "roots"
local IMMUNITY = "immunities"
local IMMUNITY_SPELL = "immunities_spells"
local DEBUFF_OFFENSIVE = "debuffs_offensive"

-- Default priority values (can be customized)
addon.DefaultPriorities = {
    [IMMUNITY] = 100,
    [IMMUNITY_SPELL] = 90,
    [CROWD_CONTROL] = 80,
    [INTERRUPT] = 75,
    [BUFF_DEFENSIVE] = 60,
    [BUFF_OFFENSIVE] = 50,
    [DEBUFF_OFFENSIVE] = 40,
    [BUFF_OTHER] = 30,
    [ROOT] = 25,
    [BUFF_SPEED] = 20,
}

-- Spells database
-- Format: [spellID] = { type = TYPE, duration = DURATION (for interrupts) }
-- or [spellID] = { parent = parentSpellID } for spell ranks

addon.Spells = {

    -- ============================================
    -- RACIALS
    -- ============================================
    [20600] = { type = BUFF_OFFENSIVE }, -- Perception
    [7744] = { type = BUFF_OFFENSIVE }, -- Will of the Forsaken
    [20549] = { type = CROWD_CONTROL }, -- War Stomp
    [20594] = { type = BUFF_OFFENSIVE }, -- Stoneform
    [20572] = { type = BUFF_OFFENSIVE }, -- Blood Fury

    -- ============================================
    -- ITEMS / CONSUMABLES
    -- ============================================
    [13099] = { type = ROOT }, -- Net-o-Matic
    [13119] = { type = ROOT }, -- Net-o-Matic
    [13120] = { type = ROOT }, -- Net-o-Matic
    [13138] = { type = ROOT }, -- Net-o-Matic
    [13139] = { type = ROOT }, -- Net-o-Matic
    [16566] = { type = ROOT }, -- Net-o-Matic
    [23723] = { type = BUFF_OFFENSIVE }, -- Mind Quickening Gem
    [30456] = { type = BUFF_DEFENSIVE }, -- Nigh-Invulnerability
    [30457] = { type = CROWD_CONTROL }, -- Complete Vulnerability
    [33961] = { type = IMMUNITY_SPELL }, -- Spell Reflection (Sethekk Initiate)
    [23451] = { type = BUFF_OFFENSIVE }, -- Battleground Speed buff
    [23493] = { type = BUFF_DEFENSIVE }, -- Battleground Heal buff
    [23505] = { type = BUFF_OFFENSIVE }, -- Battleground Damage buff
    [6615] = { type = BUFF_OFFENSIVE }, -- Free Action Potion
    [24364] = { type = BUFF_OFFENSIVE }, -- Living Action Potion
    [3169] = { type = IMMUNITY }, -- Limited Invulnerability Potion
    [16621] = { type = IMMUNITY }, -- Invulnerable Mail
    [1090] = { type = CROWD_CONTROL }, -- Magic Dust
    [13327] = { type = CROWD_CONTROL }, -- Reckless Charge
    [835] = { type = CROWD_CONTROL }, -- Tidal Charm
    [11359] = { type = BUFF_OFFENSIVE }, -- Restorative Potion
    [5024] = { type = BUFF_OFFENSIVE }, -- Skull of Impending Doom
    [2379] = { type = BUFF_SPEED }, -- Swiftness Potion
    [5134] = { type = CROWD_CONTROL }, -- Flash Bomb
    [23097] = { type = BUFF_DEFENSIVE }, -- Fire Reflector
    [23131] = { type = BUFF_DEFENSIVE }, -- Frost Reflector
    [23132] = { type = BUFF_DEFENSIVE }, -- Shadow Reflector
    [19769] = { type = CROWD_CONTROL }, -- Thorium Grenade
    [4068] = { type = CROWD_CONTROL }, -- Iron Grenade
    [23506] = { type = BUFF_DEFENSIVE }, -- Arena Grand Master trinket
    [29506] = { type = BUFF_DEFENSIVE }, -- Burrower's Shell trinket
    [12733] = { type = BUFF_OFFENSIVE }, -- Blacksmith trinket, Fear immunity
    [15753] = { type = CROWD_CONTROL }, -- Linken's Boomerang Stun
    [14530] = { type = BUFF_SPEED }, -- Nifty Stopwatch
    [13237] = { type = CROWD_CONTROL }, -- Goblin Mortar trinket
    [14253] = { type = BUFF_DEFENSIVE }, -- Black Husk Shield
    [9175] = { type = BUFF_SPEED }, -- Swift Boots
    [13141] = { type = BUFF_SPEED }, -- Gnomish Rocket Boots
    [8892] = { type = BUFF_SPEED }, -- Goblin Rocket Boots
    [9774] = { type = BUFF_SPEED }, -- Spider Belt & Ornate Mithril Boots
    [18798] = { type = CROWD_CONTROL }, -- Freezing Band
    [13494] = { type = BUFF_OFFENSIVE }, -- Manual Crowd Pummeler Haste buff

    -- ============================================
    -- INTERRUPTS (with lockout durations)
    -- ============================================
    [15752] = { type = INTERRUPT, duration = 10 }, -- Linken's Boomerang Disarm
    [19244] = { type = INTERRUPT, duration = 5 }, -- Spell Lock - Rank 1 (Warlock)
        [19647] = { parent = 19244, duration = 6 }, -- Spell Lock - Rank 2 (Warlock)
    [8042] = { type = INTERRUPT, duration = 2 }, -- Earth Shock (Shaman)
        [8044] = { parent = 8042 },
        [8045] = { parent = 8042 },
        [8046] = { parent = 8042 },
        [10412] = { parent = 8042 },
        [10413] = { parent = 8042 },
        [10414] = { parent = 8042 },
        [25454] = { parent = 8042 },
    [13491] = { type = INTERRUPT, duration = 5 }, -- Iron Knuckles
    [16979] = { type = INTERRUPT, duration = 4 }, -- Feral Charge (Druid)
    [2139] = { type = INTERRUPT, duration = 8 }, -- Counterspell (Mage)
    [1766] = { type = INTERRUPT, duration = 5 }, -- Kick (Rogue)
        [1767] = { parent = 1766 },
        [1768] = { parent = 1766 },
        [1769] = { parent = 1766 },
        [38768] = { parent = 1766 },
    [26679] = { type = INTERRUPT, duration = 3 }, -- Deadly Throw
    [6552] = { type = INTERRUPT, duration = 4 }, -- Pummel
        [6554] = { parent = 6552 },
    [72] = { type = INTERRUPT, duration = 6 }, -- Shield Bash
        [1671] = { parent = 72 },
        [1672] = { parent = 72 },
        [29704] = { parent = 72 },
    [22570] = { type = INTERRUPT, duration = 3 }, -- Maim
    [29443] = { type = INTERRUPT, duration = 10 }, -- Clutch of Foresight

    -- ============================================
    -- PRIEST
    -- ============================================
    [17] = { type = BUFF_DEFENSIVE }, -- Power Word: Shield
        [592] = { parent = 17 },
        [600] = { parent = 17 },
        [3747] = { parent = 17 },
        [6065] = { parent = 17 },
        [6066] = { parent = 17 },
        [10898] = { parent = 17 },
        [10899] = { parent = 17 },
        [10900] = { parent = 17 },
        [10901] = { parent = 17 },
        [25217] = { parent = 17 },
        [25218] = { parent = 17 },
    [605] = { type = CROWD_CONTROL }, -- Mind Control
        [10911] = { parent = 605 },
        [10912] = { parent = 605 },
    [8122] = { type = CROWD_CONTROL }, -- Psychic Scream
        [8124] = { parent = 8122 },
        [10888] = { parent = 8122 },
        [10890] = { parent = 8122 },
    [10060] = { type = BUFF_OFFENSIVE }, -- Power Infusion
    [15269] = { type = CROWD_CONTROL }, -- Blackout
    [15487] = { type = CROWD_CONTROL }, -- Silence
    [14892] = { type = BUFF_DEFENSIVE }, -- Inspiration
        [15362] = { parent = 14892 },
        [15363] = { parent = 14892 },
    [2651] = { type = BUFF_DEFENSIVE }, -- Elune's Grace
    [6346] = { type = BUFF_DEFENSIVE }, -- Fear Ward
    [9484] = { type = CROWD_CONTROL }, -- Shackle Undead
        [9485] = { parent = 9484 },
        [10955] = { parent = 9484 },
    [44041] = { type = ROOT }, -- Chastise
        [44043] = { parent = 44041 },
        [44044] = { parent = 44041 },
        [44045] = { parent = 44041 },
        [44046] = { parent = 44041 },
        [44047] = { parent = 44041 },
    [27827] = { type = IMMUNITY }, -- Spirit of Redemption
    [33206] = { type = BUFF_DEFENSIVE }, -- Pain Suppression

    -- ============================================
    -- WARLOCK
    -- ============================================
    [710] = { type = CROWD_CONTROL }, -- Banish
        [18647] = { parent = 710 },
    [6789] = { type = CROWD_CONTROL }, -- Death Coil
        [17925] = { parent = 6789 },
        [17926] = { parent = 6789 },
        [27223] = { parent = 6789 },
    [5484] = { type = CROWD_CONTROL }, -- Howl of Terror
        [17928] = { parent = 5484 },
    [5782] = { type = CROWD_CONTROL }, -- Fear
        [6213] = { parent = 5782 },
        [6215] = { parent = 5782 },
    [6358] = { type = CROWD_CONTROL }, -- Seduction (Succubus)
    [30283] = { type = CROWD_CONTROL }, -- Shadowfury
        [30413] = { parent = 30283 },
        [30414] = { parent = 30283 },
    [24259] = { type = CROWD_CONTROL }, -- Spell Lock Silence
    [18093] = { type = CROWD_CONTROL }, -- Pyroclasm
    [18223] = { type = ROOT }, -- Curse of Exhaustion
    [18118] = { type = DEBUFF_OFFENSIVE }, -- Aftermath
    [30108] = { type = DEBUFF_OFFENSIVE }, -- Unstable Affliction
        [30404] = { parent = 30108 },
        [30405] = { parent = 30108 },
    [34914] = { type = DEBUFF_OFFENSIVE }, -- Vampiric Touch (warning debuff)
    [18288] = { type = BUFF_OFFENSIVE }, -- Amplify Curse
    [18708] = { type = BUFF_OFFENSIVE }, -- Fel Domination
    [19028] = { type = BUFF_DEFENSIVE }, -- Soul Link

    -- ============================================
    -- HUNTER
    -- ============================================
    [19503] = { type = CROWD_CONTROL }, -- Scatter Shot
    [3355] = { type = CROWD_CONTROL }, -- Freezing Trap
        [14308] = { parent = 3355 },
        [14309] = { parent = 3355 },
    [19386] = { type = CROWD_CONTROL }, -- Wyvern Sting
        [24132] = { parent = 19386 },
        [24133] = { parent = 19386 },
        [27068] = { parent = 19386 },
    [24394] = { type = CROWD_CONTROL }, -- Intimidation
    [34490] = { type = CROWD_CONTROL }, -- Silencing Shot
    [19229] = { type = ROOT }, -- Wing Clip Root
    [19306] = { type = ROOT }, -- Counterattack Root
        [20909] = { parent = 19306 },
        [20910] = { parent = 19306 },
        [27067] = { parent = 19306 },
    [19185] = { type = ROOT }, -- Entrapment
    [25999] = { type = ROOT }, -- Boar Charge
    [3034] = { type = DEBUFF_OFFENSIVE }, -- Viper Sting
        [14279] = { parent = 3034 },
        [14280] = { parent = 3034 },
        [27018] = { parent = 3034 },
    [3045] = { type = BUFF_OFFENSIVE }, -- Rapid Fire
    [19263] = { type = BUFF_DEFENSIVE }, -- Deterrence
    [19574] = { type = BUFF_OFFENSIVE }, -- Bestial Wrath
    [34471] = { type = IMMUNITY_SPELL }, -- The Beast Within
    [5384] = { type = BUFF_DEFENSIVE }, -- Feign Death

    -- ============================================
    -- DRUID
    -- ============================================
    [33786] = { type = CROWD_CONTROL }, -- Cyclone
    [2637] = { type = CROWD_CONTROL }, -- Hibernate
        [18657] = { parent = 2637 },
        [18658] = { parent = 2637 },
    [9005] = { type = CROWD_CONTROL }, -- Pounce Stun
        [9823] = { parent = 9005 },
        [9827] = { parent = 9005 },
        [27006] = { parent = 9005 },
    [5211] = { type = CROWD_CONTROL }, -- Bash
        [6798] = { parent = 5211 },
        [8983] = { parent = 5211 },
    [16922] = { type = CROWD_CONTROL }, -- Starfire Stun
    [339] = { type = ROOT }, -- Entangling Roots
        [1062] = { parent = 339 },
        [5195] = { parent = 339 },
        [5196] = { parent = 339 },
        [9852] = { parent = 339 },
        [9853] = { parent = 339 },
        [26989] = { parent = 339 },
        [19970] = { parent = 339 }, -- Nature's Grasp Rank 6
        [19971] = { parent = 339 }, -- Nature's Grasp Rank 5
        [19972] = { parent = 339 }, -- Nature's Grasp Rank 4
        [19973] = { parent = 339 }, -- Nature's Grasp Rank 3
        [19974] = { parent = 339 }, -- Nature's Grasp Rank 2
        [19975] = { parent = 339 }, -- Nature's Grasp Rank 1
        [27010] = { parent = 339 },
    [19675] = { type = ROOT }, -- Feral Charge Effect
        [45334] = { parent = 19675 },
    [22812] = { type = BUFF_DEFENSIVE }, -- Barkskin
    [29166] = { type = BUFF_OFFENSIVE }, -- Innervate
    [1850] = { type = BUFF_SPEED }, -- Dash
        [9821] = { parent = 1850 },
    [16689] = { type = BUFF_DEFENSIVE }, -- Nature's Grasp Buff
        [16810] = { parent = 16689 },
        [16811] = { parent = 16689 },
        [16812] = { parent = 16689 },
        [16813] = { parent = 16689 },
        [17329] = { parent = 16689 },
    [17116] = { type = BUFF_OFFENSIVE }, -- Nature's Swiftness

    -- ============================================
    -- MAGE
    -- ============================================
    [118] = { type = CROWD_CONTROL }, -- Polymorph
        [12824] = { parent = 118 },
        [12825] = { parent = 118 },
        [12826] = { parent = 118 },
        [28270] = { parent = 118 },
        [28271] = { parent = 118 },
        [28272] = { parent = 118 },
    [18469] = { type = CROWD_CONTROL }, -- Improved Counterspell (Silence)
    [31661] = { type = CROWD_CONTROL }, -- Dragon's Breath
        [33041] = { parent = 31661 },
        [33042] = { parent = 31661 },
        [33043] = { parent = 31661 },
    [12355] = { type = CROWD_CONTROL }, -- Impact Stun
    [122] = { type = ROOT }, -- Frost Nova
        [865] = { parent = 122 },
        [6131] = { parent = 122 },
        [10230] = { parent = 122 },
        [27088] = { parent = 122 },
    [12494] = { type = ROOT }, -- Frostbite
    [33395] = { type = ROOT }, -- Freeze (Water Elemental)
    [45438] = { type = IMMUNITY }, -- Ice Block
    [12042] = { type = BUFF_OFFENSIVE }, -- Arcane Power
    [12043] = { type = BUFF_OFFENSIVE }, -- Presence of Mind
    [12472] = { type = BUFF_OFFENSIVE }, -- Icy Veins
    [12051] = { type = BUFF_OFFENSIVE }, -- Evocation
    [11426] = { type = BUFF_DEFENSIVE }, -- Ice Barrier
        [13031] = { parent = 11426 },
        [13032] = { parent = 11426 },
        [13033] = { parent = 11426 },
    [543] = { type = BUFF_DEFENSIVE }, -- Fire Ward
        [8457] = { parent = 543 },
        [8458] = { parent = 543 },
        [10223] = { parent = 543 },
        [10225] = { parent = 543 },
    [6143] = { type = BUFF_DEFENSIVE }, -- Frost Ward
        [8461] = { parent = 6143 },
        [8462] = { parent = 6143 },
        [10177] = { parent = 6143 },
        [28609] = { parent = 6143 },
    [1463] = { type = BUFF_DEFENSIVE }, -- Mana Shield
        [8494] = { parent = 1463 },
        [8495] = { parent = 1463 },
        [10191] = { parent = 1463 },
        [10192] = { parent = 1463 },
        [10193] = { parent = 1463 },

    -- ============================================
    -- ROGUE
    -- ============================================
    [2094] = { type = CROWD_CONTROL }, -- Blind
    [1833] = { type = CROWD_CONTROL }, -- Cheap Shot
    [408] = { type = CROWD_CONTROL }, -- Kidney Shot
        [8643] = { parent = 408 },
    [2070] = { type = CROWD_CONTROL }, -- Sap
        [6770] = { parent = 2070 },
        [11297] = { parent = 2070 },
    [1776] = { type = CROWD_CONTROL }, -- Gouge
        [1777] = { parent = 1776 },
        [8629] = { parent = 1776 },
        [11285] = { parent = 1776 },
        [11286] = { parent = 1776 },
        [38764] = { parent = 1776 },
    [18425] = { type = CROWD_CONTROL }, -- Improved Kick (Silence)
    [1330] = { type = CROWD_CONTROL }, -- Garrote Silence
    [3409] = { type = ROOT }, -- Crippling Poison
        [11201] = { parent = 3409 },
    [31224] = { type = IMMUNITY_SPELL }, -- Cloak of Shadows
    [5277] = { type = BUFF_DEFENSIVE }, -- Evasion
        [26669] = { parent = 5277 },
    [45182] = { type = BUFF_DEFENSIVE }, -- Cheating Death
    [14278] = { type = BUFF_DEFENSIVE }, -- Ghostly Strike
    [13750] = { type = BUFF_OFFENSIVE }, -- Adrenaline Rush
    [13877] = { type = BUFF_OFFENSIVE }, -- Blade Flurry
    [14177] = { type = BUFF_OFFENSIVE }, -- Cold Blood
    [2983] = { type = BUFF_SPEED }, -- Sprint
        [8696] = { parent = 2983 },
        [11305] = { parent = 2983 },

    -- ============================================
    -- WARRIOR
    -- ============================================
    [5246] = { type = CROWD_CONTROL }, -- Intimidating Shout
        [20511] = { parent = 5246 },
    [7922] = { type = CROWD_CONTROL }, -- Charge Stun
    [20253] = { type = CROWD_CONTROL }, -- Intercept Stun
        [20614] = { parent = 20253 },
        [20615] = { parent = 20253 },
        [25273] = { parent = 20253 },
        [25274] = { parent = 20253 },
    [12809] = { type = CROWD_CONTROL }, -- Concussion Blow
    [12798] = { type = CROWD_CONTROL }, -- Revenge Stun
    [5530] = { type = CROWD_CONTROL }, -- Mace Spec Stun (Warrior & Rogue)
    [18498] = { type = CROWD_CONTROL }, -- Improved Shield Bash (Silence)
    [23694] = { type = ROOT }, -- Improved Hamstring
    [23920] = { type = IMMUNITY_SPELL }, -- Spell Reflection
    [20230] = { type = IMMUNITY }, -- Retaliation
    [871] = { type = BUFF_DEFENSIVE }, -- Shield Wall
    [12976] = { type = BUFF_DEFENSIVE }, -- Last Stand
    [1719] = { type = BUFF_OFFENSIVE }, -- Recklessness
    [12292] = { type = BUFF_OFFENSIVE }, -- Death Wish
    [18499] = { type = BUFF_OFFENSIVE }, -- Berserker Rage
    [676] = { type = DEBUFF_OFFENSIVE }, -- Disarm
    [12294] = { type = DEBUFF_OFFENSIVE }, -- Mortal Strike
        [21551] = { parent = 12294 },
        [21552] = { parent = 12294 },
        [21553] = { parent = 12294 },
        [25248] = { parent = 12294 },
        [30330] = { parent = 12294 },

    -- ============================================
    -- PALADIN
    -- ============================================
    [853] = { type = CROWD_CONTROL }, -- Hammer of Justice
        [5588] = { parent = 853 },
        [5589] = { parent = 853 },
        [10308] = { parent = 853 },
    [20066] = { type = CROWD_CONTROL }, -- Repentance
    [10326] = { type = CROWD_CONTROL }, -- Turn Evil
        [2878] = { parent = 10326 },
    [642] = { type = IMMUNITY }, -- Divine Shield
        [1020] = { parent = 642 },
    [1022] = { type = IMMUNITY_SPELL }, -- Blessing of Protection
        [5599] = { parent = 1022 },
        [10278] = { parent = 1022 },
    [19752] = { type = IMMUNITY }, -- Divine Intervention
    [1044] = { type = BUFF_DEFENSIVE }, -- Blessing of Freedom
    [6940] = { type = BUFF_DEFENSIVE }, -- Blessing of Sacrifice
        [20729] = { parent = 6940 },
        [27147] = { parent = 6940 },
        [27148] = { parent = 6940 },
    [31821] = { type = BUFF_DEFENSIVE }, -- Aura Mastery
    [31842] = { type = BUFF_OFFENSIVE }, -- Divine Illumination
    [31884] = { type = BUFF_OFFENSIVE }, -- Avenging Wrath
    [20216] = { type = BUFF_OFFENSIVE }, -- Divine Favor

    -- ============================================
    -- SHAMAN
    -- ============================================
    [8056] = { type = ROOT }, -- Frost Shock (slowing effect treated as root for visibility)
        [8058] = { parent = 8056 },
        [10472] = { parent = 8056 },
        [10473] = { parent = 8056 },
        [25464] = { parent = 8056 },
    [39796] = { type = CROWD_CONTROL }, -- Stoneclaw Totem Stun
    [16166] = { type = BUFF_OFFENSIVE }, -- Elemental Mastery
    [16188] = { type = BUFF_OFFENSIVE }, -- Nature's Swiftness
    [30823] = { type = BUFF_DEFENSIVE }, -- Shamanistic Rage
    [2825] = { type = BUFF_OFFENSIVE }, -- Bloodlust
    [32182] = { type = BUFF_OFFENSIVE }, -- Heroism
    [8178] = { type = BUFF_DEFENSIVE }, -- Grounding Totem Effect
}
