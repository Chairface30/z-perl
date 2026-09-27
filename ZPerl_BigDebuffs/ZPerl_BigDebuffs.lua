-- ZPerl Big Debuffs
-- Shows important debuffs (CCs, interrupts, immunities) as large icons on unit frame portraits
-- Inspired by BigDebuffs by Jordon, adapted for Z-Perl UnitFrames
-- Author: Chairface
-- License: GNU GPL v3

local addonName, addon = ...

-- Don't create any frames at load time - defer everything to events
local ZPerl_BigDebuffs = nil -- Will be created in OnAddonLoaded

-- Libraries - defer LibStub call
local LCD = nil

-- Upvalues for performance
local pairs = pairs
local ipairs = ipairs
local tinsert = table.insert
local tsort = table.sort
local GetTime = GetTime
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local GetSpellTexture = GetSpellTexture
local GetSpellInfo = GetSpellInfo

-- Compatibility
local C_UnitAuras = C_UnitAuras
local AuraUtil = AuraUtil

-- Module variables
local Spells = addon.Spells
local DefaultPriorities = addon.DefaultPriorities
local db
local frames = {} -- Unit frames we're tracking
local interruptTracker = {} -- Track interrupts by GUID

-- Default settings
local defaults = {
    profile = {
        enabled = true,
        -- Which frames to show on
        player = {
            enabled = true,
            size = 1.0, -- multiplier of portrait size
        },
        target = {
            enabled = true,
            size = 1.0,
        },
        focus = {
            enabled = true,
            size = 1.0,
        },
        party = {
            enabled = true,
            size = 1.0,
        },
        -- Which spell types to show
        showCC = true,
        showInterrupts = true,
        showImmunities = true,
        showImmunitiesSpells = true,
        showDefensiveBuffs = true,
        showOffensiveBuffs = true,
        showRoots = true,
        showOffensiveDebuffs = false, -- Usually too noisy
        showSpeedBuffs = false,
        showOther = false,
        -- Priority overrides (use defaults if not set)
        priorities = {},
        -- Cooldown display
        showCooldown = true,
        showCooldownText = true,
        cooldownFontSize = 14,
    }
}

-- Saved variables
ZPerl_BigDebuffsDB = ZPerl_BigDebuffsDB or {}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function GetSpellType(spellId)
    local spell = Spells[spellId]
    if not spell then return nil end
    
    -- Handle parent spells
    if spell.parent then
        spell = Spells[spell.parent]
    end
    
    return spell and spell.type or nil
end

local function GetSpellPriority(spellId)
    local spellType = GetSpellType(spellId)
    if not spellType then return 0 end
    
    -- Check for user override
    if db and db.profile.priorities[spellId] then
        return db.profile.priorities[spellId]
    end
    
    return DefaultPriorities[spellType] or 0
end

local function ShouldShowSpellType(spellType)
    if not db or not db.profile then return false end
    
    if spellType == "cc" then return db.profile.showCC end
    if spellType == "interrupts" then return db.profile.showInterrupts end
    if spellType == "immunities" then return db.profile.showImmunities end
    if spellType == "immunities_spells" then return db.profile.showImmunitiesSpells end
    if spellType == "buffs_defensive" then return db.profile.showDefensiveBuffs end
    if spellType == "buffs_offensive" then return db.profile.showOffensiveBuffs end
    if spellType == "roots" then return db.profile.showRoots end
    if spellType == "debuffs_offensive" then return db.profile.showOffensiveDebuffs end
    if spellType == "buffs_speed_boost" then return db.profile.showSpeedBuffs end
    if spellType == "buffs_other" then return db.profile.showOther end
    
    return false
end

local function GetInterruptDuration(spellId)
    local spell = Spells[spellId]
    if not spell then return nil end
    
    if spell.parent then
        spell = Spells[spell.parent]
    end
    
    return spell and spell.duration or nil
end

-- ============================================
-- FRAME CREATION AND ATTACHMENT
-- ============================================

-- Position frame to match a target frame using OnUpdate (no anchors!)
local function PositionFrameToMatch(frame, targetFrame)
    if not frame or not targetFrame then return end
    if not targetFrame:IsVisible() then
        frame:Hide()
        return
    end
    
    -- Get the target frame's center in screen coordinates
    local scale = targetFrame:GetEffectiveScale()
    local x, y = targetFrame:GetCenter()
    if not x or not y then return end
    
    -- Convert to our frame's coordinate space
    local myScale = frame:GetEffectiveScale()
    x = (x * scale) / myScale
    y = (y * scale) / myScale
    
    -- Position our frame
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

local function CreateBigDebuffFrame(unit)
    -- Create frame parented to UIParent - completely isolated from ZPerl
    local frameName = "ZPerl_BigDebuffs_" .. unit
    local frame = CreateFrame("Frame", frameName, UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100) -- High level to appear on top
    
    -- Icon texture
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints(frame)
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- Trim edges
    
    -- Cooldown frame
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints(frame)
    frame.cooldown:SetDrawEdge(false)
    frame.cooldown:SetDrawBling(false)
    frame.cooldown:SetDrawSwipe(true)
    frame.cooldown:SetReverse(true)
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.6)
    frame.cooldown:SetHideCountdownNumbers(false)
    
    -- Border
    frame.border = frame:CreateTexture(nil, "OVERLAY")
    frame.border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    frame.border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    frame.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    frame.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    frame.border:Hide()
    
    -- Store unit
    frame.unit = unit
    
    -- Tooltip support
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if self.auraIndex and self.auraFilter then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.auraFilter == "HELPFUL" then
                GameTooltip:SetUnitBuff(self.unit, self.auraIndex)
            else
                GameTooltip:SetUnitDebuff(self.unit, self.auraIndex)
            end
            GameTooltip:Show()
        elseif self.interruptSpellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.interruptSpellId)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Use OnUpdate to keep positioned over portrait (avoids anchor family issues)
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.05 then return end -- Update 20 times per second max
        self.elapsed = 0
        
        if self.portraitFrame and self.portraitFrame:IsVisible() then
            PositionFrameToMatch(self, self.portraitFrame)
        elseif self:IsShown() and not self.hasAura then
            self:Hide()
        end
    end)
    
    frame:Hide()
    return frame
end

local function AttachToZPerlFrame(zPerlFrame, unit)
    if not zPerlFrame then return nil end
    
    -- Find the portrait frame
    local portraitFrame = zPerlFrame.portraitFrame
    if not portraitFrame then return nil end
    
    -- Create our frame if needed (parented to UIParent, no anchors to ZPerl)
    if not frames[unit] then
        frames[unit] = CreateBigDebuffFrame(unit)
    end
    
    local frame = frames[unit]
    
    -- Get portrait size
    local width, height = portraitFrame:GetSize()
    if width == 0 or height == 0 then
        -- Portrait not sized yet, try again later
        return nil
    end
    
    local size = math.min(width, height)
    
    -- Apply size multiplier from settings
    local unitType = unit:gsub("%d", "")
    if db and db.profile[unitType] and db.profile[unitType].size then
        size = size * db.profile[unitType].size
    end
    
    -- Store reference to portrait for OnUpdate positioning
    frame.portraitFrame = portraitFrame
    frame.zPerlFrame = zPerlFrame
    
    -- Set size (but don't anchor - OnUpdate handles positioning)
    frame:SetSize(size, size)
    
    return frame
end

-- ============================================
-- AURA SCANNING
-- ============================================

local function ScanUnitAuras(unit)
    if not db or not db.profile.enabled then return nil end
    
    local unitType = unit:gsub("%d", "")
    if not db.profile[unitType] or not db.profile[unitType].enabled then
        return nil
    end
    
    local bestAura = nil
    local bestPriority = 0
    local bestTimeLeft = 0
    local now = GetTime()
    
    -- Scan debuffs
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId = UnitDebuff(unit, i)
        
        if not name then break end
        
        if spellId and Spells[spellId] then
            local spellType = GetSpellType(spellId)
            if spellType and ShouldShowSpellType(spellType) then
                local priority = GetSpellPriority(spellId)
                local timeLeft = expirationTime and (expirationTime - now) or 999
                
                if priority > bestPriority or (priority == bestPriority and timeLeft > bestTimeLeft) then
                    bestPriority = priority
                    bestTimeLeft = timeLeft
                    bestAura = {
                        name = name,
                        icon = icon,
                        duration = duration,
                        expirationTime = expirationTime,
                        spellId = spellId,
                        index = i,
                        filter = "HARMFUL",
                        isDebuff = true,
                    }
                end
            end
        end
    end
    
    -- Scan buffs
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId = UnitBuff(unit, i)
        
        if not name then break end
        
        if spellId and Spells[spellId] then
            local spellType = GetSpellType(spellId)
            if spellType and ShouldShowSpellType(spellType) then
                local priority = GetSpellPriority(spellId)
                local timeLeft = expirationTime and (expirationTime - now) or 999
                
                if priority > bestPriority or (priority == bestPriority and timeLeft > bestTimeLeft) then
                    bestPriority = priority
                    bestTimeLeft = timeLeft
                    bestAura = {
                        name = name,
                        icon = icon,
                        duration = duration,
                        expirationTime = expirationTime,
                        spellId = spellId,
                        index = i,
                        filter = "HELPFUL",
                        isDebuff = false,
                    }
                end
            end
        end
    end
    
    -- Check for tracked interrupts
    local guid = UnitGUID(unit)
    if guid and interruptTracker[guid] then
        local interrupt = interruptTracker[guid]
        if interrupt.expires > now then
            local spellType = GetSpellType(interrupt.spellId)
            if spellType and ShouldShowSpellType(spellType) then
                local priority = GetSpellPriority(interrupt.spellId)
                local timeLeft = interrupt.expires - now
                
                if priority > bestPriority or (priority == bestPriority and timeLeft > bestTimeLeft) then
                    bestAura = {
                        name = GetSpellInfo(interrupt.spellId) or "Interrupted",
                        icon = GetSpellTexture(interrupt.spellId),
                        duration = interrupt.duration,
                        expirationTime = interrupt.expires,
                        spellId = interrupt.spellId,
                        isInterrupt = true,
                    }
                end
            end
        else
            -- Clean up expired interrupt
            interruptTracker[guid] = nil
        end
    end
    
    return bestAura
end

-- ============================================
-- UPDATE FUNCTIONS
-- ============================================

local function UpdateFrame(frame, aura)
    if not frame then return end
    
    if not aura then
        frame:Hide()
        frame.currentIcon = nil
        frame.auraIndex = nil
        frame.auraFilter = nil
        frame.interruptSpellId = nil
        frame.hasAura = false
        return
    end
    
    -- Set icon
    if frame.currentIcon ~= aura.icon then
        frame.icon:SetTexture(aura.icon)
        frame.currentIcon = aura.icon
    end
    
    -- Set cooldown
    if db.profile.showCooldown and aura.duration and aura.duration > 0 and aura.expirationTime then
        local start = aura.expirationTime - aura.duration
        frame.cooldown:SetCooldown(start, aura.duration)
        frame.cooldown:Show()
    else
        frame.cooldown:Hide()
    end
    
    -- Store for tooltip
    if aura.isInterrupt then
        frame.auraIndex = nil
        frame.auraFilter = nil
        frame.interruptSpellId = aura.spellId
    else
        frame.auraIndex = aura.index
        frame.auraFilter = aura.filter
        frame.interruptSpellId = nil
    end
    
    -- Show border for debuffs
    if aura.isDebuff then
        frame.border:Show()
    else
        frame.border:Hide()
    end
    
    frame.hasAura = true
    frame:Show()
end

local function UpdateUnit(unit)
    local frame = frames[unit]
    if not frame then return end
    
    if not UnitExists(unit) then
        frame:Hide()
        return
    end
    
    local aura = ScanUnitAuras(unit)
    UpdateFrame(frame, aura)
end

local function UpdateAllUnits()
    for unit, frame in pairs(frames) do
        UpdateUnit(unit)
    end
end

-- ============================================
-- INTERRUPT TRACKING (COMBAT LOG)
-- ============================================

local function OnCombatLogEvent()
    local timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags, spellId, spellName = CombatLogGetCurrentEventInfo()
    
    -- Track interrupts
    if event == "SPELL_INTERRUPT" or event == "SPELL_CAST_SUCCESS" then
        local spell = Spells[spellId]
        if spell then
            -- Get actual spell info (handle parent spells)
            local actualSpell = spell.parent and Spells[spell.parent] or spell
            
            if actualSpell.type == "interrupts" and actualSpell.duration then
                -- Check if it's a channeled spell interrupt
                local isChannelInterrupt = false
                if event == "SPELL_CAST_SUCCESS" then
                    -- For SPELL_CAST_SUCCESS, we need to check if target was channeling
                    -- This is a simplification - ideally we'd check UnitChannelInfo
                    isChannelInterrupt = true -- Assume it might be an interrupt
                end
                
                if event == "SPELL_INTERRUPT" or isChannelInterrupt then
                    interruptTracker[destGUID] = {
                        spellId = spell.parent or spellId,
                        duration = actualSpell.duration,
                        expires = GetTime() + actualSpell.duration,
                    }
                    
                    -- Schedule cleanup and refresh
                    C_Timer.After(actualSpell.duration + 0.1, function()
                        if interruptTracker[destGUID] and interruptTracker[destGUID].expires <= GetTime() then
                            interruptTracker[destGUID] = nil
                        end
                        UpdateAllUnits()
                    end)
                    
                    UpdateAllUnits()
                end
            end
        end
    end
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

local function OnUnitAura(unit)
    -- Normalize unit (party1target -> party1, etc.)
    local baseUnit = unit:match("^(%w+)%d*") or unit
    
    -- Check if we care about this unit
    if frames[unit] then
        UpdateUnit(unit)
    end
end

local function OnPlayerTargetChanged()
    UpdateUnit("target")
end

local function OnPlayerFocusChanged()
    UpdateUnit("focus")
end

local function OnGroupRosterUpdate()
    -- Refresh party frame attachments (frames are globals XPerl_party1..XPerl_party4)
    for i = 1, 4 do
        local unit = "party" .. i
        local partyFrame = _G["XPerl_party" .. i]
        if partyFrame then
            AttachToZPerlFrame(partyFrame, unit)
            UpdateUnit(unit)
        end
    end
end

-- ============================================
-- INITIALIZATION
-- ============================================

local function InitDB()
    -- Simple saved variables setup
    if not ZPerl_BigDebuffsDB.profile then
        ZPerl_BigDebuffsDB.profile = {}
    end
    
    -- Merge defaults
    for key, value in pairs(defaults.profile) do
        if ZPerl_BigDebuffsDB.profile[key] == nil then
            if type(value) == "table" then
                ZPerl_BigDebuffsDB.profile[key] = {}
                for k, v in pairs(value) do
                    ZPerl_BigDebuffsDB.profile[key][k] = v
                end
            else
                ZPerl_BigDebuffsDB.profile[key] = value
            end
        end
    end
    
    db = ZPerl_BigDebuffsDB
end

local function AttachToZPerlFrames()
    -- Only attach if frames exist and are fully initialized
    
    -- Attach to player frame
    if XPerl_Player and XPerl_Player.portraitFrame then
        AttachToZPerlFrame(XPerl_Player, "player")
    end
    
    -- Attach to target frame
    if XPerl_Target and XPerl_Target.portraitFrame then
        AttachToZPerlFrame(XPerl_Target, "target")
    end
    
    -- Attach to focus frame (not in Classic Era)
    if XPerl_Focus and XPerl_Focus.portraitFrame then
        AttachToZPerlFrame(XPerl_Focus, "focus")
    end
    
    -- Attach to party frames (frames are globals XPerl_party1..XPerl_party4)
    for i = 1, 4 do
        local partyFrame = _G["XPerl_party" .. i]
        if partyFrame and partyFrame.portraitFrame then
            AttachToZPerlFrame(partyFrame, "party" .. i)
        end
    end
end

local function OnAddonLoaded(_, name)
    if name == addonName then
        InitDB()
        -- Don't do anything else here - wait for PLAYER_ENTERING_WORLD
    end
end

local initialized = false

local function OnPlayerEnteringWorld()
    -- Use a very long delay to ensure ZPerl has COMPLETELY finished initialization
    -- This includes all position restoration, frame creation, etc.
    -- 3 seconds should be more than enough
    C_Timer.After(3.0, function()
        if not initialized then
            initialized = true
            -- Double-check we're not in combat (which could cause issues)
            if not InCombatLockdown() then
                AttachToZPerlFrames()
                UpdateAllUnits()
            else
                -- If in combat, wait until combat ends
                local combatWaiter = CreateFrame("Frame")
                combatWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
                combatWaiter:SetScript("OnEvent", function(self)
                    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    AttachToZPerlFrames()
                    UpdateAllUnits()
                end)
            end
        end
    end)
end

-- ============================================
-- PUBLIC API (will be attached to frame in bootstrap)
-- ============================================

-- Note: Enable, Disable, Toggle, Refresh, GetDB methods are attached
-- to the ZPerl_BigDebuffs frame in the bootstrap section below

-- ============================================
-- SLASH COMMANDS (registered after addon loads)
-- ============================================

local function RegisterSlashCommands()
    SLASH_ZPERLBIGDEBUFFS1 = "/zperlbd"
    SLASH_ZPERLBIGDEBUFFS2 = "/zbigdebuffs"
    SlashCmdList["ZPERLBIGDEBUFFS"] = function(msg)
        if not ZPerl_BigDebuffs then return end
        local cmd = msg:lower():trim()
        
        if cmd == "" or cmd == "options" or cmd == "config" or cmd == "opt" then
            -- Open options panel
            if addon.ToggleOptions then
                addon.ToggleOptions()
            elseif ZPerl_BigDebuffs.ShowOptions then
                ZPerl_BigDebuffs:ShowOptions()
            end
        elseif cmd == "toggle" then
            ZPerl_BigDebuffs:Toggle()
            print("|cff00ff00ZPerl Big Debuffs:|r " .. (db.profile.enabled and "Enabled" or "Disabled"))
        elseif cmd == "refresh" then
            ZPerl_BigDebuffs:Refresh()
            print("|cff00ff00ZPerl Big Debuffs:|r Refreshed")
        elseif cmd == "cc" then
            db.profile.showCC = not db.profile.showCC
            print("|cff00ff00ZPerl Big Debuffs:|r Crowd Control " .. (db.profile.showCC and "Enabled" or "Disabled"))
            UpdateAllUnits()
        elseif cmd == "interrupts" then
            db.profile.showInterrupts = not db.profile.showInterrupts
            print("|cff00ff00ZPerl Big Debuffs:|r Interrupts " .. (db.profile.showInterrupts and "Enabled" or "Disabled"))
            UpdateAllUnits()
        elseif cmd == "immunities" then
            db.profile.showImmunities = not db.profile.showImmunities
            print("|cff00ff00ZPerl Big Debuffs:|r Immunities " .. (db.profile.showImmunities and "Enabled" or "Disabled"))
            UpdateAllUnits()
        elseif cmd == "defensives" then
            db.profile.showDefensiveBuffs = not db.profile.showDefensiveBuffs
            print("|cff00ff00ZPerl Big Debuffs:|r Defensive Buffs " .. (db.profile.showDefensiveBuffs and "Enabled" or "Disabled"))
            UpdateAllUnits()
        elseif cmd == "offensives" then
            db.profile.showOffensiveBuffs = not db.profile.showOffensiveBuffs
            print("|cff00ff00ZPerl Big Debuffs:|r Offensive Buffs " .. (db.profile.showOffensiveBuffs and "Enabled" or "Disabled"))
            UpdateAllUnits()
        elseif cmd == "roots" then
            db.profile.showRoots = not db.profile.showRoots
            print("|cff00ff00ZPerl Big Debuffs:|r Roots " .. (db.profile.showRoots and "Enabled" or "Disabled"))
            UpdateAllUnits()
        elseif cmd == "status" then
            print("|cff00ff00ZPerl Big Debuffs Status:|r")
            print("  Enabled: " .. tostring(db.profile.enabled))
            print("  Show CC: " .. tostring(db.profile.showCC))
            print("  Show Interrupts: " .. tostring(db.profile.showInterrupts))
            print("  Show Immunities: " .. tostring(db.profile.showImmunities))
            print("  Show Defensive Buffs: " .. tostring(db.profile.showDefensiveBuffs))
            print("  Show Offensive Buffs: " .. tostring(db.profile.showOffensiveBuffs))
            print("  Show Roots: " .. tostring(db.profile.showRoots))
        elseif cmd == "help" then
            print("|cff00ff00ZPerl Big Debuffs Commands:|r")
            print("  /zperlbd - Open options panel")
            print("  /zperlbd toggle - Enable/disable the addon")
            print("  /zperlbd refresh - Refresh frame attachments")
            print("  /zperlbd cc - Toggle crowd control")
            print("  /zperlbd interrupts - Toggle interrupts")
            print("  /zperlbd immunities - Toggle immunities")
            print("  /zperlbd defensives - Toggle defensive buffs")
            print("  /zperlbd offensives - Toggle offensive buffs")
            print("  /zperlbd roots - Toggle roots")
            print("  /zperlbd status - Show current settings")
        else
            print("|cff00ff00ZPerl Big Debuffs:|r Unknown command. Type /zperlbd help for commands.")
        end
    end
end

-- ============================================
-- BOOTSTRAP - Use a temporary frame just for ADDON_LOADED
-- ============================================

local bootstrapFrame = CreateFrame("Frame")
bootstrapFrame:RegisterEvent("ADDON_LOADED")
bootstrapFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        -- Unregister and clean up bootstrap frame
        self:UnregisterEvent("ADDON_LOADED")
        self:SetScript("OnEvent", nil)
        
        -- Initialize LibClassicDurations if available
        LCD = LibStub and LibStub("LibClassicDurations", true)
        if LCD then
            LCD:Register(addonName)
        end
        
        -- Initialize saved variables
        InitDB()
        
        -- Register slash commands
        RegisterSlashCommands()
        
        -- Now create the main event frame
        ZPerl_BigDebuffs = CreateFrame("Frame", "ZPerl_BigDebuffs", UIParent)
        
        -- Set up the public API on the frame
        ZPerl_BigDebuffs.Enable = function(self)
            if db then db.profile.enabled = true end
            UpdateAllUnits()
        end
        
        ZPerl_BigDebuffs.Disable = function(self)
            if db then db.profile.enabled = false end
            for unit, frame in pairs(frames) do
                frame:Hide()
            end
        end
        
        ZPerl_BigDebuffs.Toggle = function(self)
            if db and db.profile.enabled then
                self:Disable()
            else
                self:Enable()
            end
        end
        
        ZPerl_BigDebuffs.Refresh = function(self)
            AttachToZPerlFrames()
            UpdateAllUnits()
        end
        
        ZPerl_BigDebuffs.GetDB = function(self)
            return db
        end
        
        -- Register events on the main frame
        ZPerl_BigDebuffs:RegisterEvent("PLAYER_ENTERING_WORLD")
        ZPerl_BigDebuffs:RegisterEvent("PLAYER_TARGET_CHANGED")
        ZPerl_BigDebuffs:RegisterEvent("GROUP_ROSTER_UPDATE")
        ZPerl_BigDebuffs:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        ZPerl_BigDebuffs:RegisterEvent("UNIT_AURA")
        
        -- Focus is not in Classic Era
        if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
            ZPerl_BigDebuffs:RegisterEvent("PLAYER_FOCUS_CHANGED")
        end
        
        ZPerl_BigDebuffs:SetScript("OnEvent", function(frame, event, ...)
            if event == "PLAYER_ENTERING_WORLD" then
                OnPlayerEnteringWorld()
            elseif event == "PLAYER_TARGET_CHANGED" then
                OnPlayerTargetChanged()
            elseif event == "PLAYER_FOCUS_CHANGED" then
                OnPlayerFocusChanged()
            elseif event == "GROUP_ROSTER_UPDATE" then
                OnGroupRosterUpdate()
            elseif event == "UNIT_AURA" then
                OnUnitAura(...)
            elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
                OnCombatLogEvent()
            end
        end)
        
        print("|cff00ff00ZPerl Big Debuffs|r loaded. Type |cff00ff00/zperlbd|r for options.")
    end
end)
