-- Z-Perl Compatibility Layer for TBC Classic Anniversary Edition
-- This file provides backward-compatible API wrappers for functions that have been
-- moved to namespaces (C_AddOns, C_UnitAuras, etc.) in the modern WoW client.

local addonName, ZPerl = ...
if not ZPerl then ZPerl = {} end
ZPerl.Compat = {}

-- Detect TBC Anniversary Edition (WOW_PROJECT_BURNING_CRUSADE_CLASSIC == 5, interface 20505+)
local isTBCAnniversary = (WOW_PROJECT_ID == 5)

-- WoW Forever (interface 16xxx) reports itself as the retail game in
-- WOW_PROJECT_ID, but it is a vanilla-era game: its spells, its level cap,
-- no focus frame. Every Z-Perl file that asks "is this Classic?" or "is this
-- vanilla?" also asks this, so Forever takes the Classic/vanilla paths.
XPerl_IsForever = (function()
    local ok, _, _, _, toc = pcall(GetBuildInfo)
    return ok and type(toc) == "number" and toc >= 16000 and toc < 17000 or false
end)()

-- WoW Forever keeps many unit answers secret, most of all in combat: AFK and
-- PvP flags, creature type, classification and more. Testing or comparing a
-- secret throws. XPerl_SafeUnitAPI(func) returns a version of func that gives
-- nil for each secret result, so it reads as "no" or unknown. Frame files use
-- it for their local copies of the globals; the globals themselves are never
-- replaced, so Blizzard's code is untouched.
do
    local issecret = issecretvalue
    -- Same number of results as the original call, secrets turned to nil.
    -- Up to four is the common case and needs no table; cast info returns
    -- about nine, which goes through one.
    local function Clean(...)
        local n = select("#", ...)
        if n == 0 then return end
        if n > 4 then
            local t = { ... }
            for i = 1, n do
                if issecret(t[i]) then t[i] = nil end
            end
            return unpack(t, 1, n)
        end
        local a, b, c, d = ...
        if issecret(a) then a = nil end
        if n == 1 then return a end
        if issecret(b) then b = nil end
        if n == 2 then return a, b end
        if issecret(c) then c = nil end
        if n == 3 then return a, b, c end
        if issecret(d) then d = nil end
        return a, b, c, d
    end
    function XPerl_SafeUnitAPI(func)
        if not (issecret and func) then return func end
        return function(...)
            return Clean(func(...))
        end
    end

    -- Cast info (UnitCastingInfo, UnitChannelInfo): all or nothing. Other
    -- units' casts arrive with the name, times and ID secret, and a cast with
    -- any part unreadable can't be drawn, so it reads as no cast at all.
    local function AnySecret(...)
        for i = 1, select("#", ...) do
            if issecret((select(i, ...))) then return true end
        end
        return false
    end
    local function Readable(...)
        if AnySecret(...) then return end
        return ...
    end
    function XPerl_SafeCastAPI(func)
        if not (issecret and func) then return func end
        return function(...)
            return Readable(func(...))
        end
    end

    -- Range checks (IsItemInRange, IsSpellInRange, CheckInteractDistance,
    -- UnitInRange): a secret answer reads as in range, so a frame the client
    -- won't give a distance for is never faded out as if it were far away.
    local function InRange(...)
        local n = select("#", ...)
        if n == 0 then return end
        local a, b = ...
        if issecret(a) then a = true end
        if n == 1 then return a end
        if issecret(b) then b = true end
        return a, b
    end
    function XPerl_SafeRangeAPI(func)
        if not (issecret and func) then return func end
        return function(...)
            return InRange(func(...))
        end
    end

    -- Yes/no questions where "don't know" should read as yes: is the unit
    -- connected, is it visible. Read as no, a secret answer would grey a
    -- group member out as Offline or hide them.
    XPerl_SafeTrueAPI = XPerl_SafeRangeAPI

    -- A value that is safe to compare, do sums with, join or use as a table
    -- key: the value itself, or nil when it is secret.
    function XPerl_Plain(value)
        if issecret and issecret(value) then return nil end
        return value
    end

    -- UnitName for bookkeeping (roster keys, "is this me", matching a saved
    -- name): name and realm, or nothing when either is secret. Never use it
    -- for what a frame shows; a secret name still displays as it is.
    function XPerl_PlainName(unit)
        local name, realm = UnitName(unit)
        if issecret and (issecret(name) or issecret(realm)) then return nil end
        return name, realm
    end
end

-- Safe copies for the unit menu below (Inspect and Trade entries).
local SafeUnitIsPlayer = XPerl_SafeUnitAPI(UnitIsPlayer)
local SafeUnitIsUnit = XPerl_SafeUnitAPI(UnitIsUnit)
local SafeCheckInteractDistance = XPerl_SafeRangeAPI(CheckInteractDistance)
local SafeUnitInParty = XPerl_SafeUnitAPI(UnitInParty)
local SafeUnitInRaid = XPerl_SafeUnitAPI(UnitInRaid)
local SafeUnitIsGroupLeader = XPerl_SafeUnitAPI(UnitIsGroupLeader)
local SafeUnitIsGroupAssistant = XPerl_SafeUnitAPI(UnitIsGroupAssistant)

-- Item functions: WoW Forever has them only in C_Item.
if not GetItemInfo and C_Item and C_Item.GetItemInfo then
    GetItemInfo = C_Item.GetItemInfo
end
-- MouseIsOver(frame) is gone from newer clients (WoW Forever among them);
-- a frame's own IsMouseOver does the same job.
function XPerl_MouseIsOver(frame)
    if not frame then return false end
    if MouseIsOver then return MouseIsOver(frame) end
    return frame.IsMouseOver and frame:IsMouseOver() or false
end

if not GetSpellTexture and C_Spell and C_Spell.GetSpellTexture then
    GetSpellTexture = C_Spell.GetSpellTexture
end
if not GetItemCount and C_Item and C_Item.GetItemCount then
    GetItemCount = C_Item.GetItemCount
end

-- The combat log: WoW Forever refuses COMBAT_LOG_EVENT_UNFILTERED to addons
-- (ADDON_ACTION_FORBIDDEN, which a pcall can't catch) -- registering it and
-- unregistering it alike -- so there it is never touched. What reads it
-- (HoT highlights, big debuffs, own-damage combat text) gets no combat log.
function XPerl_RegisterCombatLog(frame, on)
    if XPerl_IsForever then return end
    if on then
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end

-- A spell's name to key a table by, or "#spell<id>" when this client doesn't
-- have the spell: a nil table key is an error that stops the whole file, and
-- a placeholder simply never matches an aura.
function XPerl_SpellKey(spellID)
    local name = GetSpellInfo and GetSpellInfo(spellID)
    if name == nil and C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, spellID)
        if ok then name = n end
    end
    return name or ("#spell" .. tostring(spellID))
end

-- ============================================================================
-- UI API Compatibility
-- ============================================================================

-- GetMouseFocus - replaced by GetMouseFoci() in modern clients
if not GetMouseFocus then
    if GetMouseFoci then
        GetMouseFocus = function()
            local frames = GetMouseFoci()
            return frames and frames[1] or nil
        end
    else
        -- Fallback - return nil if neither function exists
        GetMouseFocus = function() return nil end
    end
end

-- GetLootMethod - removed in modern clients, provide stub
if not GetLootMethod then
    GetLootMethod = function()
        -- Returns: method, partyIndex, raidIndex
        -- In TBC Anniversary without master loot, just return "group"
        return "group", nil, nil
    end
end

-- ============================================================================
-- Addon Management API Compatibility
-- In modern clients, these functions moved to the C_AddOns namespace
-- ============================================================================

-- GetAddOnInfo
if not GetAddOnInfo then
    if C_AddOns and C_AddOns.GetAddOnInfo then
        GetAddOnInfo = function(name)
            local addonName, title, notes, loadable, reason, security = C_AddOns.GetAddOnInfo(name)
            -- Old API returned: name, title, notes, enabled, loadable, reason, security
            -- New API returns: name, title, notes, loadable, reason, security
            -- We need to infer 'enabled' from loadable/reason
            local enabled = loadable or (reason ~= "DISABLED")
            return addonName, title, notes, enabled, loadable, reason, security
        end
    end
end

-- GetAddOnMetadata
if not GetAddOnMetadata then
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        GetAddOnMetadata = C_AddOns.GetAddOnMetadata
    end
end

-- EnableAddOn
if not EnableAddOn then
    if C_AddOns and C_AddOns.EnableAddOn then
        EnableAddOn = function(name, character)
            C_AddOns.EnableAddOn(name, character)
        end
    end
end

-- DisableAddOn
if not DisableAddOn then
    if C_AddOns and C_AddOns.DisableAddOn then
        DisableAddOn = function(name, character)
            C_AddOns.DisableAddOn(name, character)
        end
    end
end

-- LoadAddOn
if not LoadAddOn then
    if C_AddOns and C_AddOns.LoadAddOn then
        LoadAddOn = function(name)
            local loaded, reason = C_AddOns.LoadAddOn(name)
            return loaded, reason
        end
    end
end

-- IsAddOnLoaded
if not IsAddOnLoaded then
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        IsAddOnLoaded = C_AddOns.IsAddOnLoaded
    end
end

-- GetNumAddOns
if not GetNumAddOns then
    if C_AddOns and C_AddOns.GetNumAddOns then
        GetNumAddOns = C_AddOns.GetNumAddOns
    end
end

-- ============================================================================
-- UnitAura API Compatibility
-- In Dragonflight+, UnitAura was replaced by C_UnitAuras.GetAuraDataByIndex
-- TBC Anniversary may still have UnitAura, but we provide a fallback
-- ============================================================================

-- Provide UnitAura wrapper if needed
-- WoW Forever refuses every aura read from addon code while in combat
-- ("Auras cannot be accessed when secret while tainted"): the read is made
-- inside a pcall and a refusal reads as no aura, never an error.
-- XPerl_AurasLocked(unit) tells the buff code to keep what it last showed.
function XPerl_AurasLocked(unit)
    return false
end
if not UnitAura and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    function XPerl_AurasLocked(unit)
        return not pcall(C_UnitAuras.GetAuraDataByIndex, unit or "player", 1, "HELPFUL")
    end
    -- One field of the aura, under either of its names; nil when secret. The
    -- buff code compares, adds up and looks up what it gets from here, so
    -- nothing secret may leave.
    local issecret = issecretvalue
    local function Field(data, key, otherKey)
        local value = data[key]
        if issecret and issecret(value) then return nil end
        if value == nil and otherKey then
            value = data[otherKey]
            if issecret and issecret(value) then return nil end
        end
        return value
    end
    local function AuraFields(unit, index, filter)
        local data = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        if issecret and issecret(data) then return nil end
        if type(data) ~= "table" then return nil end
        local name = Field(data, "name")
        if name == nil then return nil end -- an aura with no readable name is no aura
        return name,
               Field(data, "icon"),
               Field(data, "applications", "count") or 0,
               Field(data, "dispelName", "debuffType"),
               Field(data, "duration"),
               Field(data, "expirationTime"),
               Field(data, "sourceUnit", "source"),
               Field(data, "isStealable"),
               Field(data, "nameplateShowPersonal"),
               Field(data, "spellId"),
               Field(data, "canApplyAura"),
               Field(data, "isBossAura", "isBossDebuff"),
               Field(data, "isFromPlayerOrPlayerPet", "castByPlayer"),
               Field(data, "nameplateShowAll"),
               Field(data, "timeMod")
    end
    local function Read(ok, ...)
        if ok then return ... end
        return nil
    end
    UnitAura = function(unit, indexOrName, filter)
        if type(indexOrName) == "number" then
            return Read(pcall(AuraFields, unit, indexOrName, filter))
        end
        return nil
    end
    
    UnitBuff = function(unit, indexOrName, filter)
        local finalFilter = filter or "HELPFUL"
        if filter and not filter:find("HELPFUL") and not filter:find("HARMFUL") then
            finalFilter = "HELPFUL " .. filter
        elseif not filter then
            finalFilter = "HELPFUL"
        end
        return UnitAura(unit, indexOrName, finalFilter)
    end
    
    UnitDebuff = function(unit, indexOrName, filter)
        local finalFilter = filter or "HARMFUL"
        if filter and not filter:find("HELPFUL") and not filter:find("HARMFUL") then
            finalFilter = "HARMFUL " .. filter
        elseif not filter then
            finalFilter = "HARMFUL"
        end
        return UnitAura(unit, indexOrName, finalFilter)
    end
end

-- IsItemInRange: WoW Forever has no global of that name. C_Item's is used if
-- the client has one; where there is none the answer is nil ("can't tell") and
-- the range finder falls back to its distance checks.
if not IsItemInRange then
    local itemInRange = C_Item and C_Item.IsItemInRange
    IsItemInRange = function(item, unit)
        if type(itemInRange) ~= "function" then return nil end
        local ok, inRange = pcall(itemInRange, item, unit)
        if not ok then return nil end
        return inRange
    end
end

-- GetSpellLink: in C_Spell on newer clients. With neither, there is no link.
if not GetSpellLink then
    local spellLink = C_Spell and C_Spell.GetSpellLink
    GetSpellLink = function(spell)
        if type(spellLink) ~= "function" then return nil end
        local ok, link = pcall(spellLink, spell)
        if ok then return link end
        return nil
    end
end

-- InviteUnit: in C_PartyInfo on newer clients.
if not InviteUnit and C_PartyInfo and C_PartyInfo.InviteUnit then
    InviteUnit = C_PartyInfo.InviteUnit
end

-- IsSpellInRange: newer clients (WoW Forever) have only C_Spell.IsSpellInRange,
-- which answers true/false/nil where the old one answered 1/0/nil.
if not IsSpellInRange and C_Spell and C_Spell.IsSpellInRange then
    IsSpellInRange = function(spell, unit)
        local ok, inRange = pcall(C_Spell.IsSpellInRange, spell, unit)
        if not ok then return nil end
        -- A secret answer is handed on as it is: it can't be tested here, and
        -- XPerl_SafeRangeAPI reads it as in range.
        if issecretvalue and issecretvalue(inRange) then return inRange end
        if inRange == nil then return nil end
        return inRange and 1 or 0
    end
end

-- ============================================================================
-- GetSpellInfo Compatibility
-- In 11.0+, GetSpellInfo was replaced by C_Spell.GetSpellInfo (returns a table)
-- TBC Anniversary should still have the old GetSpellInfo
-- ============================================================================

if not GetSpellInfo and C_Spell and C_Spell.GetSpellInfo then
    GetSpellInfo = function(spellID)
        local info = C_Spell.GetSpellInfo(spellID)
        if info then
            return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID
        end
        return nil
    end
end

-- ============================================================================
-- Backdrop Compatibility
-- Modern clients require BackdropTemplateMixin
-- ============================================================================

-- Ensure BackdropTemplateMixin exists
if not BackdropTemplateMixin then
    BackdropTemplateMixin = {}
    function BackdropTemplateMixin:OnBackdropLoaded()
        if self.backdropInfo then
            self:SetBackdrop(self.backdropInfo)
        end
    end
    function BackdropTemplateMixin:OnBackdropSizeChanged() end
end

-- ============================================================================
-- Other Utility Functions
-- ============================================================================

-- GetNumSpellTabs (may have been changed)
if not GetNumSpellTabs and C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    GetNumSpellTabs = C_SpellBook.GetNumSpellBookSkillLines
end

-- GetSpellBookItemInfo compatibility, under Z-Perl's own name. Defining the
-- global broke other addons that check whether it exists and then expect the
-- client's own version.
if GetSpellBookItemInfo then
    XPerl_GetSpellBookItemInfo = GetSpellBookItemInfo
elseif C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
    XPerl_GetSpellBookItemInfo = function(index, bookType)
        local info = C_SpellBook.GetSpellBookItemInfo(index, bookType)
        if info then
            return info.itemType, info.spellID
        end
        return nil
    end
end

-- ============================================================================
-- SetGradientAlpha Compatibility
-- SetGradientAlpha was replaced with SetGradient in newer clients
-- ============================================================================

-- Check if texture:SetGradientAlpha exists
local testTexture = UIParent:CreateTexture()
local hasSetGradientAlpha = testTexture.SetGradientAlpha ~= nil
testTexture:Hide()
testTexture = nil

if not hasSetGradientAlpha then
    -- Provide a compatibility wrapper
    local TextureMT = getmetatable(UIParent:CreateTexture()).__index
    if TextureMT and not TextureMT.SetGradientAlpha then
        TextureMT.SetGradientAlpha = function(self, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
            -- New API uses SetGradient with a different signature
            if self.SetGradient then
                self:SetGradient(orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
            end
        end
    end
end

-- ============================================================================
-- GetSpecialization Compatibility
-- TBC Classic Anniversary uses a different talent system
-- In TBC, we determine "spec" by which talent tree has the most points
-- ============================================================================

if isTBCAnniversary then
    -- In TBC Anniversary, GetSpecialization may return the primary talent tree
    -- based on where most points are spent (1, 2, or 3)
    -- If it doesn't exist or returns nil, we need to calculate it
    local originalGetSpecialization = GetSpecialization
    GetSpecialization = function()
        -- First try the native function
        if originalGetSpecialization then
            local success, spec = pcall(originalGetSpecialization)
            if success and spec and spec > 0 then
                return spec
            end
        end
        
        -- Calculate from talent points
        if GetNumTalentTabs and GetNumTalentTabs() > 0 then
            local maxPoints = 0
            local maxTree = 1
            for tab = 1, GetNumTalentTabs() do
                local _, _, pointsSpent = GetTalentTabInfo(tab)
                -- TBC Anniversary: pointsSpent may be a string, convert to number
                local points = tonumber(pointsSpent) or 0
                if points > maxPoints then
                    maxPoints = points
                    maxTree = tab
                end
            end
            if maxPoints > 0 then
                return maxTree
            end
        end
        
        return nil
    end
    
    -- GetSpecializationInfoByID may not exist in TBC Anniversary
    if not GetSpecializationInfoByID then
        GetSpecializationInfoByID = function(specID)
            -- Return basic info - this is used for inspecting other players
            -- In TBC this information isn't really available the same way
            return nil, nil, nil, nil, nil
        end
    end
end

-- ============================================================================
-- Deferred Function Stubs
-- These provide safe no-op stubs for XPerl functions that might be called
-- before ZPerl.lua has fully loaded. They will be overwritten when the
-- actual functions are defined.
-- ============================================================================

-- Create safe stub functions that do nothing if called before real functions load
local function CreateSafeStub(funcName)
    if _G[funcName] == nil then
        _G[funcName] = function(...) end  -- Accept any args, do nothing
    end
end

-- List of functions that might be called before they're defined
local deferredFunctions = {
    "XPerl_SetExpectedHealth",
    "XPerl_SetExpectedAbsorbs",
    "XPerl_Unit_UpdatePortrait",
    "XPerl_Unit_UpdateLevel",
    "XPerl_Unit_GetHealth",
    "XPerl_Unit_ThreatStatus",
    "XPerl_Unit_UpdateBuffs",
    "XPerl_Unit_BuffPositions",
    "XPerl_Unit_UpdateReadyState",
    "XPerl_SetManaBarType",
    "XPerl_ColourHealthBar",
    "XPerl_SetHealthBar",
    "XPerl_NoFadeBars",
    "XPerl_UpdateSpellRange",
    "ZPerl_Unit_OnEnter",
    "ZPerl_Unit_OnLeave",
    "XPerl_FrameFlash",
    "XPerl_FrameFlashStop",
    "XPerl_FrameIsFlashing",
    "XPerl_ProtectedCall",
    "XPerl_RegisterScalableFrame",
    "XPerl_GetBarTexture",
    "XPerl_StatsFrame_Setup",
    "XPerl_RegisterHighlight",
    "XPerl_RegisterPerlFrames",
    "XPerl_RegisterOptionChanger",
    "XPerl_SecureUnitButton_OnLoad",
    "XPerl_RegisterClickCastFrame",
    "XPerl_Register_Prediction",
    "XPerl_SwitchAnchor",
    "XPerl_Update_RaidIcon",
    "XPerl_SetBuffSize",
    "XPerl_Check_Channels_OnLoad",
    "XPerl_RegisterSMBarTextures",
    "XPerl_SetChildMembers",
    "XPerl_PlayerTipHide",
}

-- Create stubs immediately - these will be overwritten when ZPerl.lua loads
for _, funcName in ipairs(deferredFunctions) do
    CreateSafeStub(funcName)
end

-- Verify stubs were created (debug check, can be removed)
-- for _, funcName in ipairs(deferredFunctions) do
--     if _G[funcName] == nil then
--         print("ZPerl_Compat: Failed to create stub for " .. funcName)
--     end
-- end

-- ============================================================================
-- Missing Menu Function - Custom Implementation to Avoid Taint
-- ============================================================================

-- XPerl_ShowGenericMenu - Custom unit menu that avoids Blizzard taint issues
if not XPerl_ShowGenericMenu then
    function XPerl_ShowGenericMenu(self)
        -- Don't show menus during combat lockdown
        if InCombatLockdown() then 
            print("|cFFD00000Z-Perl|r: Cannot open menu during combat")
            return 
        end
        
        local unit = self.unit or (self:GetParent() and self:GetParent().unit)
        if not unit or not UnitExists(unit) then return end
        
        local unitName = UnitName(unit) or unit
        
        -- Create dropdown if it doesn't exist
        if not ZPerl_UnitDropDown then
            ZPerl_UnitDropDown = MSA_DropDownMenu_Create("ZPerl_UnitDropDown", UIParent)
            ZPerl_UnitDropDown.displayMode = "MENU"
        end
        
        -- Store current unit for menu functions
        ZPerl_UnitDropDown.unit = unit
        ZPerl_UnitDropDown.name = unitName
        
        MSA_DropDownMenu_Initialize(ZPerl_UnitDropDown, function(self, level)
            local unit = self.unit
            local name = self.name
            if not unit then return end
            level = level or 1

            -- Level 2: raid target icon submenu
            if level == 2 then
                if MSA_DROPDOWNMENU_MENU_VALUE == "RAID_TARGET" then
                    for i = 8, 1, -1 do
                        local info = MSA_DropDownMenu_CreateInfo()
                        info.text = _G["RAID_TARGET_" .. i]
                        info.icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i
                        info.notCheckable = true
                        info.func = function() SetRaidTarget(unit, i) end
                        MSA_DropDownMenu_AddButton(info, level)
                    end
                    local info = MSA_DropDownMenu_CreateInfo()
                    info.text = RAID_TARGET_NONE
                    info.notCheckable = true
                    info.func = function() SetRaidTarget(unit, 0) end
                    MSA_DropDownMenu_AddButton(info, level)
                end
                return
            end

            local info = MSA_DropDownMenu_CreateInfo()
            
            -- Header
            info.text = name
            info.isTitle = true
            info.notCheckable = true
            MSA_DropDownMenu_AddButton(info, level)
            
            -- Target
            info = MSA_DropDownMenu_CreateInfo()
            info.text = TARGET
            info.notCheckable = true
            info.func = function() TargetUnit(unit) end
            MSA_DropDownMenu_AddButton(info, level)
            
            -- Set Focus
            info = MSA_DropDownMenu_CreateInfo()
            info.text = SET_FOCUS
            info.notCheckable = true
            info.func = function() FocusUnit(unit) end
            MSA_DropDownMenu_AddButton(info, level)
            
            -- Clear Focus (if this unit is focus)
            if SafeUnitIsUnit(unit, "focus") then
                info = MSA_DropDownMenu_CreateInfo()
                info.text = CLEAR_FOCUS
                info.notCheckable = true
                info.func = function() ClearFocus() end
                MSA_DropDownMenu_AddButton(info, level)
            end
            
            -- Inspect (if player and in range)
            if SafeUnitIsPlayer(unit) and SafeCheckInteractDistance(unit, 1) and not SafeUnitIsUnit(unit, "player") then
                info = MSA_DropDownMenu_CreateInfo()
                info.text = INSPECT
                info.notCheckable = true
                info.func = function() InspectUnit(unit) end
                MSA_DropDownMenu_AddButton(info, level)
            end
            
            -- Trade (if player and in range)
            if SafeUnitIsPlayer(unit) and SafeCheckInteractDistance(unit, 2) and not SafeUnitIsUnit(unit, "player") then
                info = MSA_DropDownMenu_CreateInfo()
                info.text = TRADE
                info.notCheckable = true
                info.func = function() InitiateTrade(unit) end
                MSA_DropDownMenu_AddButton(info, level)
            end
            
            -- Follow (if player)
            if SafeUnitIsPlayer(unit) and not SafeUnitIsUnit(unit, "player") then
                info = MSA_DropDownMenu_CreateInfo()
                info.text = FOLLOW
                info.notCheckable = true
                info.func = function() FollowUnit(unit) end
                MSA_DropDownMenu_AddButton(info, level)
            end
            
            -- Whisper (if player)
            -- (a secret name can't be written into the chat box)
            if SafeUnitIsPlayer(unit) and not SafeUnitIsUnit(unit, "player") and XPerl_Plain(name) then
                info = MSA_DropDownMenu_CreateInfo()
                info.text = WHISPER
                info.notCheckable = true
                info.func = function() 
                    ChatFrame_OpenChat("/w " .. name .. " ", DEFAULT_CHAT_FRAME)
                end
                MSA_DropDownMenu_AddButton(info, level)
            end
            
            -- Invite (if player and not in group)
            if InviteUnit and XPerl_Plain(name) and SafeUnitIsPlayer(unit) and not SafeUnitIsUnit(unit, "player") and not SafeUnitInParty(unit) and not SafeUnitInRaid(unit) then
                info = MSA_DropDownMenu_CreateInfo()
                info.text = PARTY_INVITE
                info.notCheckable = true
                info.func = function() InviteUnit(name) end
                MSA_DropDownMenu_AddButton(info, level)
            end
            
            -- Raid target icons (if can mark)
            if (SafeUnitIsGroupLeader("player") or SafeUnitIsGroupAssistant("player") or not IsInGroup()) and UnitExists(unit) then
                info = MSA_DropDownMenu_CreateInfo()
                info.text = RAID_TARGET_ICON
                info.notCheckable = true
                info.hasArrow = true
                info.value = "RAID_TARGET"
                MSA_DropDownMenu_AddButton(info, level)
            end
            
            -- Cancel
            info = MSA_DropDownMenu_CreateInfo()
            info.text = CANCEL
            info.notCheckable = true
            MSA_DropDownMenu_AddButton(info, level)
            
        end, "MENU")
        
        -- Show the dropdown at cursor
        MSA_ToggleDropDownMenu(1, nil, ZPerl_UnitDropDown, "cursor", 0, 0)
    end
end

-- ============================================================================
-- Export compatibility info
-- ============================================================================

ZPerl.Compat.isTBCAnniversary = isTBCAnniversary
ZPerl.Compat.Version = "1.0.0"

-- ============================================================================
-- TBC Anniversary Tips (one-time display)
-- ============================================================================
if isTBCAnniversary then
    local tipFrame = CreateFrame("Frame")
    tipFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    tipFrame:SetScript("OnEvent", function(self, event)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        -- Only show tip once per session
        if not ZPerl.shownFocusTip then
            ZPerl.shownFocusTip = true
            C_Timer.After(5, function()
                print("|cFFD00000Z-Perl|r TBC Anniversary: |cFFFFFF00Shift+Left-Click|r on unit frames to set focus. Type |cFFFFFF00/zperl help|r for more.")
            end)
        end
    end)
end

-- Print compatibility layer loaded message (can be commented out for release)
-- print("|cFF00FF00ZPerl Compatibility Layer|r loaded for TBC Anniversary Edition")
