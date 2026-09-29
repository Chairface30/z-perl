-- Z-Perl UnitFrames
-- Author: Chairface (originally Resike)
-- License: GNU GPL v3, 18 October 2014

-- Forever: these can come back secret; secret reads as nil (see ZPerl_Compat.lua)
local UnitCanAttack = XPerl_SafeUnitAPI(UnitCanAttack)
local UnitClass = XPerl_SafeUnitAPI(UnitClass)

local IsClassic = (WOW_PROJECT_ID >= WOW_PROJECT_CLASSIC or XPerl_IsForever)
local IsVanillaClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC or XPerl_IsForever)

local max = max
local pairs = pairs
local strfind = strfind
local tonumber = tonumber

local CreateFrame = CreateFrame
local GetDifficultyColor = GetDifficultyColor or GetQuestDifficultyColor
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local RegisterUnitWatch = RegisterUnitWatch
local UnitAffectingCombat = XPerl_SafeUnitAPI(UnitAffectingCombat)
local UnitAura = UnitAura
local UnitClassification = XPerl_SafeUnitAPI(UnitClassification)
local UnitExists = UnitExists
local UnitFactionGroup = XPerl_SafeUnitAPI(UnitFactionGroup)
local UnitGUID = UnitGUID
local UnitIsAFK = XPerl_SafeUnitAPI(UnitIsAFK)
local UnitIsConnected = XPerl_SafeTrueAPI(UnitIsConnected)
local UnitIsDead = XPerl_SafeUnitAPI(UnitIsDead)
local UnitIsDeadOrGhost = XPerl_SafeUnitAPI(UnitIsDeadOrGhost)
local UnitIsFriend = XPerl_SafeUnitAPI(UnitIsFriend)
local UnitIsGhost = XPerl_SafeUnitAPI(UnitIsGhost)
local UnitIsPVP = XPerl_SafeUnitAPI(UnitIsPVP)
local UnitIsPVPFreeForAll = XPerl_SafeUnitAPI(UnitIsPVPFreeForAll)
local UnitIsVisible = XPerl_SafeTrueAPI(UnitIsVisible)
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnregisterUnitWatch = UnregisterUnitWatch

local UIParent = UIParent

local feignDeath = GetSpellInfo(5384)

local conf
XPerl_RequestConfig(function(new)
	conf = new
	if XPerl_TargetTarget then
		XPerl_TargetTarget.conf = conf.targettarget
	end
	if XPerl_TargetTargetTarget then
		XPerl_TargetTargetTarget.conf = conf.targettargettarget
	end
	if XPerl_FocusTarget then
		XPerl_FocusTarget.conf = conf.focustarget
	end
	if XPerl_PetTarget then
		XPerl_PetTarget.conf = conf.pettarget
	end
end, "$Revision: 33d78e5ce33228a1cf8cb5f354abf0b5e577621f $")

local buffSetup

-- ZPerl_TargetTarget_OnLoad
function ZPerl_TargetTarget_OnLoad(self)
	self:RegisterForClicks("AnyUp")
	self:RegisterForDrag("LeftButton")
	XPerl_SetChildMembers(self)

	local events = {
		(IsClassic and not XPerl_IsForever) and "UNIT_HEALTH_FREQUENT" or "UNIT_HEALTH",
		"UNIT_POWER_FREQUENT",
		"UNIT_AURA",
		"UNIT_TARGET",
		"INCOMING_RESURRECT_CHANGED",
	}

	self.guid = 0

	-- Events
	self:RegisterEvent("RAID_TARGET_UPDATE")
	if (self == XPerl_TargetTarget) then
		self.parentid = "target"
		self.partyid = "targettarget"
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		for i, event in pairs(events) do
			pcall(self.RegisterUnitEvent, self, event, "target") -- skip any event this client lacks
		end
		XPerl_Register_Prediction(self, conf.targettarget, function(guid)
			if XPerl_SameGUID(guid, UnitGUID("targettarget")) then
				return "targettarget"
			end
		end, "target")
		self:SetScript("OnUpdate", XPerl_TargetTarget_OnUpdate)
	elseif (self == XPerl_FocusTarget) then
		self.parentid = "focus"
		self.partyid = "focustarget"
		if not IsVanillaClassic then
			self:RegisterEvent("PLAYER_FOCUS_CHANGED")
		end
		for i, event in pairs(events) do
			self:RegisterUnitEvent(event, "focus")
		end
		XPerl_Register_Prediction(self, conf.targettarget, function(guid)
			if XPerl_SameGUID(guid, UnitGUID("focustarget")) then
				return "focustarget"
			end
		end, "focus")
		self:SetScript("OnUpdate", XPerl_TargetTarget_OnUpdate)
	elseif (self == XPerl_PetTarget) then
		self.parentid = "pet"
		self.partyid = "pettarget"
		for i, event in pairs(events) do
			self:RegisterUnitEvent(event, "pet")
		end
		XPerl_Register_Prediction(self, conf.targettarget, function(guid)
			if XPerl_SameGUID(guid, UnitGUID("pettarget")) then
				return "pettarget"
			end
		end, "pet")
		self:SetScript("OnUpdate", XPerl_TargetTarget_OnUpdate)
	else
		self.parentid = "targettarget"
		self.partyid = "targettargettarget"
		for i, event in pairs(events) do
			pcall(self.RegisterUnitEvent, self, event, "target") -- skip any event this client lacks
		end
		XPerl_Register_Prediction(self, conf.targettarget, function(guid)
			if XPerl_SameGUID(guid, UnitGUID("targettargettarget")) then
				return "targettargettarget"
			end
		end, "targettarget")
		self:SetScript("OnUpdate", XPerl_TargetTargetTarget_OnUpdate)
	end

	XPerl_SecureUnitButton_OnLoad(self, self.partyid, XPerl_ShowGenericMenu)
	XPerl_SecureUnitButton_OnLoad(self.nameFrame, self.partyid, XPerl_ShowGenericMenu)

	--RegisterUnitWatch(self)

	local BuffOnUpdate, DebuffOnUpdate, BuffUpdateTooltip, DebuffUpdateTooltip
	BuffUpdateTooltip = XPerl_Unit_SetBuffTooltip
	DebuffUpdateTooltip = XPerl_Unit_SetDeBuffTooltip

	if buffSetup then
		self.buffSetup = buffSetup
	else
		self.buffSetup = {
			buffScripts = {
				OnEnter = XPerl_Unit_SetBuffTooltip,
				OnUpdate = BuffOnUpdate,
				OnLeave = XPerl_PlayerTipHide,
			},
			debuffScripts = {
				OnEnter = XPerl_Unit_SetDeBuffTooltip,
				OnUpdate = DebuffOnUpdate,
				OnLeave = XPerl_PlayerTipHide,
			},
			updateTooltipBuff = BuffUpdateTooltip,
			updateTooltipDebuff = DebuffUpdateTooltip,
			debuffParent = true,
			debuffSizeMod = 0.2,
			debuffAnchor1 = function(self, b)
				b:SetPoint("TOPLEFT", 0, 0)
			end,
		}
		self.buffSetup.buffAnchor1 = self.buffSetup.debuffAnchor1
		buffSetup = self.buffSetup
	end

	self.targetname = ""
	self.lastUpdate = 0

	--XPerl_InitFadeFrame(self)
	XPerl_RegisterHighlight(self.highlight, 2)
	XPerl_RegisterPerlFrames(self, {self.nameFrame, self.statsFrame, self.levelFrame})

	if XPerlDB then
		self.conf = XPerlDB[self.partyid]
	end

	XPerl_Highlight:Register(XPerl_TargetTarget_HighlightCallback, self)

	if self == XPerl_TargetTarget then
		XPerl_RegisterOptionChanger(XPerl_TargetTarget_Set_Bits, "TargetTarget")
	end

	if XPerl_TargetTarget and XPerl_FocusTarget and XPerl_PetTarget and XPerl_TargetTargetTarget then
		ZPerl_TargetTarget_OnLoad = nil
	end
end

-- XPerl_TargetTarget_HighlightCallback
function XPerl_TargetTarget_HighlightCallback(self, updateGUID)
	local partyid = self.partyid
	if XPerl_SameGUID(UnitGUID(partyid), updateGUID) and UnitIsFriend("player", partyid) then
		XPerl_Highlight:SetHighlight(self, updateGUID)
	end
end

-------------------------
-- The Update Function --
-------------------------
local function XPerl_TargetTarget_UpdatePVP(self)
	local partyid = self.partyid
	local pvp = self.conf.pvpIcon and ((UnitIsPVPFreeForAll(partyid) and "FFA") or (UnitIsPVP(partyid) and (UnitFactionGroup(partyid) ~= "Neutral") and UnitFactionGroup(partyid)))
	if pvp then
		self.nameFrame.pvpIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..pvp)
		self.nameFrame.pvpIcon:Show()
	else
		self.nameFrame.pvpIcon:Hide()
	end
end

-- XPerl_TargetTarget_BuffPositions
local function XPerl_TargetTarget_BuffPositions(self)
	if (self.partyid and UnitCanAttack("player", self.partyid)) then
		XPerl_Unit_BuffPositions(self, self.buffFrame.debuff, self.buffFrame.buff, self.conf.debuffs.size, self.conf.buffs.size)
	else
		XPerl_Unit_BuffPositions(self, self.buffFrame.buff, self.buffFrame.debuff, self.conf.buffs.size, self.conf.debuffs.size)
	end
end

-- XPerl_TargetTarget_Buff_UpdateAll
local function XPerl_TargetTarget_Buff_UpdateAll(self)
	if self.conf.buffs.enable then
		self.buffFrame:Show()
	else
		self.buffFrame:Hide()
	end
	if self.conf.debuffs.enable then
		self.debuffFrame:Show()
	else
		self.debuffFrame:Hide()
	end
	if self.conf.buffs.enable or self.conf.debuffs.enable then
		--XPerl_Targets_BuffUpdate(self)
		XPerl_Unit_UpdateBuffs(self, nil, nil, self.conf.buffs.castable, self.conf.debuffs.curable)
		XPerl_TargetTarget_BuffPositions(self)
	end
end

-- XPerl_TargetTarget_RaidIconUpdate
local function XPerl_TargetTarget_RaidIconUpdate(self)
	local frameRaidIcon = self.nameFrame.raidIcon
	local frameNameFrame = self.nameFrame

	XPerl_Update_RaidIcon(frameRaidIcon, self.partyid)

	frameRaidIcon:ClearAllPoints()
	if conf.target.raidIconAlternate then
		frameRaidIcon:SetHeight(16)
		frameRaidIcon:SetWidth(16)
		frameRaidIcon:SetPoint("CENTER", frameNameFrame, "TOPRIGHT", -5, -4)
	else
		frameRaidIcon:SetHeight(32)
		frameRaidIcon:SetWidth(32)
		frameRaidIcon:SetPoint("CENTER", frameNameFrame, "CENTER", 0, 0)
	end
end

-- XPerl_TargetTarget_UpdateDisplay
function XPerl_TargetTarget_UpdateDisplay(self, force)
	-- Early return if not fully initialized
	if not self.conf then
		return
	end
	local partyid = self.partyid
	if not partyid then
		self.targethp = 0
		self.targethpmax = 0
		self.targetmanatype = 0
		self.targetmana = 0
		self.targetmanamax = 0
		self.afk = false
		self.guid = nil
		return
	end
	--[[if not UnitExists(partyid) then
		self.targethp = UnitIsGhost(partyid) and 1 or (UnitIsDead(partyid) and 0 or XPerl_Unit_GetHealth(self))
		self.targetmana = UnitPower(partyid)
		self.guid = UnitGUID(partyid)
		self.afk = UnitIsAFK(partyid)
	end]]
	if self.conf and self.conf.enable and UnitExists(self.parentid) and UnitIsConnected(partyid) then
		self.targetname = UnitName(partyid)
		if self.targetname then
			local t = GetTime()
			if not force and t < (self.lastUpdate + 0.3) then
				return
			end
			XPerl_Highlight:RemoveHighlight(self)
			self.lastUpdate = t

			XPerl_TargetTarget_UpdatePVP(self)

			-- Save these, so we know whether to update the frame later
			--self.targethp = UnitIsGhost(partyid) and 1 or (UnitIsDead(partyid) and 0 or XPerl_Unit_GetHealth(self))
			--self.targethpmax = UnitHealthMax(partyid)
			--self.targetmanatype = UnitPowerType(partyid)
			--self.targetmana = UnitPower(partyid)
			--self.targetmanamax = UnitPowerMax(partyid)
			--self.afk = UnitIsAFK(partyid) and conf.showAFK
			self.guid = UnitGUID(partyid)

			XPerl_SetUnitNameColor(self.nameFrame.text, partyid)

			if self.conf.level then
				local TargetTargetLevel = UnitLevel(partyid)
				-- A secret level still shows; it can't be compared, colored or
				-- have a "+" added.
				local plainLevel = XPerl_Plain(TargetTargetLevel)
				local color = plainLevel and GetDifficultyColor(plainLevel) or NORMAL_FONT_COLOR or {r = 1, g = 0.82, b = 0}

				self.levelFrame.text:Show()
				self.levelFrame.skull:Hide()
				if plainLevel == -1 then
					if UnitClassification(partyid) == "worldboss" then
						TargetTargetLevel = "Boss"
					else
						self.levelFrame.text:Hide()
						self.levelFrame.skull:Show()
					end
				elseif (plainLevel and strfind(UnitClassification(partyid) or "", "elite")) then
					TargetTargetLevel = TargetTargetLevel.."+"
					self.levelFrame:SetWidth(33)
				else
					self.levelFrame:SetWidth(27)
				end

				self.levelFrame.text:SetText(TargetTargetLevel)

				if plainLevel == -1 and TargetTargetLevel == "Boss" then
					self.levelFrame:SetWidth(self.levelFrame.text:GetStringWidth() + 6)
					color = {r = 1, g = 0, b = 0}
				end

				self.levelFrame.text:SetTextColor(color.r, color.g, color.b)
			end

			-- Set name - Must do after level as the NameFrame can change size just above here.
			local TargetTargetname = self.targetname
			self.nameFrame.text:SetText(TargetTargetname)

			-- Set health
			XPerl_Target_UpdateHealth(self)

			-- Set mana
			if not self.statsFrame.greyMana then
				XPerl_Target_SetManaType(self)
			end
			XPerl_Target_SetMana(self)

			XPerl_TargetTarget_RaidIconUpdate(self)

			--XPerl_TargetTarget_BuffPositions(self)		-- Moved to option set to save garbage production
			XPerl_TargetTarget_Buff_UpdateAll(self)

			XPerl_UpdateSpellRange(self, partyid)
			XPerl_Highlight:SetHighlight(self, UnitGUID(partyid))
			return
		end
	end

	self.targetname = ""
	XPerl_Highlight:RemoveHighlight(self)
end

-- XPerl_TargetTarget_Update_Control
local function XPerl_TargetTarget_Update_Control(self)
	local partyid = self.partyid
	if UnitIsVisible(partyid) and XPerl_UnitIsCharmed(partyid) then
		self.nameFrame.warningIcon:Show()
	else
		self.nameFrame.warningIcon:Hide()
	end
end

-- XPerl_TargetTarget_Update_Combat
local function XPerl_TargetTarget_Update_Combat(self)
	-- Combat icon disabled for cleaner UI
	self.nameFrame.combatIcon:Hide()
end

-- XPerl_TargetTarget_OnUpdate
function XPerl_TargetTarget_OnUpdate(self, elapsed)
	-- A frame with no settings (the focus target on Forever) has nothing to draw
	if not self.conf then
		return
	end
	local partyid = self.partyid

	local newGuid = UnitGUID(partyid)
	local newHP = UnitIsGhost(partyid) and 1 or (UnitIsDead(partyid) and 0 or (XPerl_Unit_GetHealth and XPerl_Unit_GetHealth(self) or UnitHealth(partyid)))
	local newHPMax = UnitHealthMax(partyid)
	local newManaType = XPerl_Plain(UnitPowerType(partyid))
	local newMana = UnitPower(partyid)
	local newManaMax = UnitPowerMax(partyid)
	local newAFK = UnitIsAFK(partyid)

	if XPerl_Secret(newHP, newHPMax, newMana, newManaMax) then
		-- Forever: can't tell whether a secret value changed, so redraw on a timer
		if XPerl_SecretPoll(self, elapsed) or (conf.showAFK and newAFK ~= self.afk) or (newManaType ~= XPerl_Plain(self.targetmanatype)) then
			XPerl_Target_UpdateHealth(self)
			XPerl_Target_SetManaType(self)
			XPerl_Target_SetMana(self)
		end
	else
		if (conf.showAFK and newAFK ~= self.afk) or (newHP ~= self.targethp) or (newHPMax ~= self.targethpmax) then
			XPerl_Target_UpdateHealth(self)
		end

		if (newManaType ~= XPerl_Plain(self.targetmanatype)) then
			XPerl_Target_SetManaType(self)
			XPerl_Target_SetMana(self)
		end

		if (newMana ~= self.targetmana) or (newManaMax ~= self.targetmanamax) then
			XPerl_Target_SetMana(self)
		end
	end

	--[[if conf.showFD then
		local _, class = UnitClass(partyid)
		if class == "HUNTER" then
			local feigning = UnitBuff(partyid, feignDeath)
			if feigning ~= self.feigning then
				self.feigning = feigning
				XPerl_Target_UpdateHealth(self)
			end
		end
	end--]]

	if XPerl_GUIDDiffers(newGuid, self.guid, XPerl_GUIDPoll(self, elapsed)) then
		XPerl_TargetTarget_UpdateDisplay(self)
	else
		self.time = elapsed + (self.time or 0)
		if self.time >= 0.5 then
			XPerl_TargetTarget_Update_Combat(self)
			XPerl_TargetTarget_Update_Control(self)
			XPerl_TargetTarget_UpdatePVP(self)
			if self.conf.buffs.enable or self.conf.debuffs.enable then
				XPerl_Unit_UpdateBuffs(self, nil, nil, self.conf.buffs.castable, self.conf.debuffs.curable)
				XPerl_TargetTarget_BuffPositions(self)
			end
			--XPerl_TargetTarget_Buff_UpdateAll(self)
			XPerl_SetUnitNameColor(self.nameFrame.text, partyid)
			XPerl_UpdateSpellRange(self, partyid)
			--XPerl_Highlight:SetHighlight(self, UnitGUID(partyid))
			self.time = 0
		end
	end
end

-- XPerl_TargetTargetTarget_OnUpdate
function XPerl_TargetTargetTarget_OnUpdate(self, elapsed)
	-- A frame with no settings (the focus target on Forever) has nothing to draw
	if not self.conf then
		return
	end
	local partyid = self.partyid

	local newGuid = UnitGUID(partyid)
	local newHP = UnitIsGhost(partyid) and 1 or (UnitIsDead(partyid) and 0 or (XPerl_Unit_GetHealth and XPerl_Unit_GetHealth(self) or UnitHealth(partyid)))
	local newManaType = XPerl_Plain(UnitPowerType(partyid))
	local newMana = UnitPower(partyid)
	local newAFK = UnitIsAFK(partyid)

	if XPerl_Secret(newHP, newMana) then
		-- Forever: can't tell whether a secret value changed, so redraw on a timer
		if XPerl_SecretPoll(self, elapsed) or (conf.showAFK and newAFK ~= self.afk) or (newManaType ~= XPerl_Plain(self.targetmanatype)) then
			XPerl_Target_UpdateHealth(self)
			XPerl_Target_SetManaType(self)
			XPerl_Target_SetMana(self)
		end
	else
		if (conf.showAFK and newAFK ~= self.afk) or (newHP ~= self.targethp) then
			XPerl_Target_UpdateHealth(self)
		end

		if (newManaType ~= XPerl_Plain(self.targetmanatype)) then
			XPerl_Target_SetManaType(self)
			XPerl_Target_SetMana(self)
		end

		if (newMana ~= self.targetmana) then
			XPerl_Target_SetMana(self)
		end
	end

	--[[if conf.showFD then
		local _, class = UnitClass(partyid)
		if class == "HUNTER" then
			local feigning = UnitBuff(partyid, feignDeath)
			if feigning ~= self.feigning then
				self.feigning = feigning
				XPerl_Target_UpdateHealth(self)
			end
		end
	end--]]

	if XPerl_GUIDDiffers(newGuid, self.guid, XPerl_GUIDPoll(self, elapsed)) then
		XPerl_TargetTarget_UpdateDisplay(self)
	else
		self.time = elapsed + (self.time or 0)
		if self.time >= 0.5 then
			XPerl_TargetTarget_Update_Combat(self)
			XPerl_TargetTarget_Update_Control(self)
			XPerl_TargetTarget_UpdatePVP(self)
			if self.conf.buffs.enable or self.conf.debuffs.enable then
				XPerl_Unit_UpdateBuffs(self, nil, nil, self.conf.buffs.castable, self.conf.debuffs.curable)
				XPerl_TargetTarget_BuffPositions(self)
			end
			--XPerl_TargetTarget_Buff_UpdateAll(self)
			XPerl_SetUnitNameColor(self.nameFrame.text, partyid)
			XPerl_UpdateSpellRange(self, partyid)
			--XPerl_Highlight:SetHighlight(self, UnitGUID(partyid))
			self.time = 0
		end
	end

	--[[if self == XPerl_TargetTargetTarget and newGuid ~= self.guid then
		XPerl_NoFadeBars(true)
		XPerl_TargetTarget_UpdateDisplay(self, true)
		XPerl_NoFadeBars()
		return
	end]]

	--XPerl_TargetTarget_OnUpdate(self, elapsed)
end

-------------------
-- Event Handler --
-------------------
function XPerl_TargetTarget_OnEvent(self, event, unitID, ...)
	if event == "RAID_TARGET_UPDATE" then
		XPerl_TargetTarget_RaidIconUpdate(self)
	elseif event == "PLAYER_TARGET_CHANGED" then
		XPerl_TargetTarget_UpdateDisplay(self, true)
	elseif event == "PLAYER_FOCUS_CHANGED" then
		XPerl_TargetTarget_UpdateDisplay(self, true)
	elseif event == "INCOMING_RESURRECT_CHANGED" then
		XPerl_Target_UpdateResurrectionStatus(self)
	elseif strfind(event, "^UNIT_") then
		if (unitID == "target") and (self == XPerl_TargetTarget or self == XPerl_TargetTargetTarget) then
			XPerl_NoFadeBars(true)
			XPerl_TargetTarget_UpdateDisplay(self, true)
			if XPerl_FocusTarget and XPerl_FocusTarget:IsShown() then
				XPerl_TargetTarget_UpdateDisplay(XPerl_FocusTarget, true)
			end
			XPerl_NoFadeBars()
		elseif unitID == "focus" and self == XPerl_FocusTarget then
			XPerl_NoFadeBars(true)
			XPerl_TargetTarget_UpdateDisplay(self, true)
			XPerl_NoFadeBars()
		elseif unitID == "pet" and self == XPerl_PetTarget then
			XPerl_NoFadeBars(true)
			XPerl_TargetTarget_UpdateDisplay(self, true)
			if XPerl_FocusTarget and XPerl_FocusTarget:IsShown() then
				XPerl_TargetTarget_UpdateDisplay(XPerl_FocusTarget, true)
			end
			XPerl_NoFadeBars()
		end
	end
end

-- XPerl_TargetTarget_Update
function XPerl_TargetTarget_Update(self)
	local offset = -3
	if self.conf.buffs.enable then
		if UnitExists("targettarget") then
			if XPerl_UnitBuff("targettarget", 1) then
				if (offset == -3) then
					offset = 0
				end
				offset = offset + 20
				if UnitAura("targettarget", 9, "HELPFUL") then
					offset = offset + 20
				end
			end
			if XPerl_UnitDebuff("targettarget", 1) then
				if (offset == -3) then
					offset = 0
				end
				offset = offset + 24
			end
		end
	end
end

-- EnableDisable
local function EnableDisable(self)
	if self.conf.enable then
		if not self.virtual then
			RegisterUnitWatch(self)
		end
	else
		UnregisterUnitWatch(self)
		self:Hide()
	end
end

-- XPerl_TargetTarget_SetWidth
function XPerl_TargetTarget_SetWidth(self)

	self.conf.size.width = max(0, self.conf.size.width or 0)
	local bonus = self.conf.size.width

	if self.conf.percent then
		if (not InCombatLockdown()) then
			self:SetWidth(160 + bonus)
			self.nameFrame:SetWidth(160 + bonus)
			self.statsFrame:SetWidth(160 + bonus)
		end
		self.statsFrame.healthBar.percent:Show()
		self.statsFrame.manaBar.percent:Show()
	else
		if (not InCombatLockdown()) then
			self:SetWidth(128 + bonus)
			self.nameFrame:SetWidth(128 + bonus)
			self.statsFrame:SetWidth(128 + bonus)
		end
		self.statsFrame.healthBar.percent:Hide()
		self.statsFrame.manaBar.percent:Hide()
	end

	self.conf.scale = self.conf.scale or 0.8
	if (not InCombatLockdown()) then
		self:SetScale(self.conf.scale)
	end

	XPerl_SavePosition(self, true)

	XPerl_StatsFrameSetup(self)
end

-- Set
local function Set(self)
	if self.conf.level then
		self.levelFrame:Show()
		self.levelFrame:SetWidth(27)
	else
		self.levelFrame:Hide()
	end

	if self.conf.mana then
		self.statsFrame.manaBar:Show()
		self.statsFrame:SetHeight(40)
	else
		self.statsFrame.manaBar:Hide()
		self.statsFrame:SetHeight(30)
	end

	if self.conf.values then
		self.statsFrame.healthBar.text:Show()
		self.statsFrame.manaBar.text:Show()
	else
		self.statsFrame.healthBar.text:Hide()
		self.statsFrame.manaBar.text:Hide()
	end

	self.buffFrame:ClearAllPoints()
	if self.conf.buffs.above then
		self.buffFrame:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 2, 0)
	else
		self.buffFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 2, 0)
	end
	self.buffOptMix = nil
	self.conf.buffs.size = tonumber(self.conf.buffs.size) or 20

	XPerl_SetBuffSize(self)

	XPerl_TargetTarget_SetWidth(self)

	XPerl_ProtectedCall(EnableDisable, self)

	if self:IsShown() then
		XPerl_TargetTarget_UpdateDisplay(self, true)
	end
end

-- Helper: check if a frame has a saved position in the position table
local function HasSavedPosition(frame)
	if not frame or not XPerl_GetSavePositionTable then return false end
	local posTable = XPerl_GetSavePositionTable()
	if not posTable then return false end
	local name = frame:GetName()
	if not name then return false end
	local pos = posTable[name]
	return pos and pos.left and pos.top
end

-- Helper: restore a frame's saved position, returns true if successful
local function RestoreSavedPosition(frame)
	if not frame or not XPerl_RestorePosition then return false end
	if HasSavedPosition(frame) then
		XPerl_RestorePosition(frame)
		return true
	end
	return false
end

-- Helper function to safely set anchor point with fallback
local function SafeSetPoint(frame, point, relativeTo, relativePoint, offsetX, offsetY)
	if not frame then return false end

	-- First, fully detach the frame to break any existing anchor chains
	pcall(function()
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end)

	-- Now try to set the requested anchor
	local success = pcall(function()
		frame:ClearAllPoints()
		frame:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
	end)

	-- If it failed, just leave it centered on UIParent (already set above)
	return success
end

-- XPerl_TargetTarget_Set_Bits
function XPerl_TargetTarget_Set_Bits()
	if not XPerl_TargetTarget then
		return
	end

	-- FIRST: Detach all dependent frames to break any anchor chains
	-- This prevents "anchor family connection" errors
	local dependentFrames = {XPerl_FocusTarget, XPerl_TargetTargetTarget, XPerl_PetTarget}
	for _, frame in ipairs(dependentFrames) do
		if frame then
			pcall(function()
				frame:ClearAllPoints()
				frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			end)
		end
	end

	-- NOW: Create and position frames
	-- For each dependent frame, restore its saved position if one exists,
	-- otherwise fall back to the default anchor relative to its parent frame.
	if conf.targettargettarget.enable then
		if not XPerl_TargetTargetTarget then
			local ttt = CreateFrame("Button", "XPerl_TargetTargetTarget", UIParent, "ZPerl_TargetTarget_Template")
		end
		if XPerl_TargetTargetTarget and XPerl_TargetTarget then
			if not RestoreSavedPosition(XPerl_TargetTargetTarget) then
				SafeSetPoint(XPerl_TargetTargetTarget, "TOPLEFT", XPerl_TargetTarget, "TOPRIGHT", 5, 0)
			end
		end
	end

	if conf.focustarget.enable then
		if not XPerl_FocusTarget then
			local ttt = CreateFrame("Button", "XPerl_FocusTarget", UIParent, "ZPerl_TargetTarget_Template")
		end
		if XPerl_FocusTarget then
			if not RestoreSavedPosition(XPerl_FocusTarget) then
				if XPerl_Focus then
					SafeSetPoint(XPerl_FocusTarget, "TOPLEFT", XPerl_Focus, "TOPRIGHT", 5, 0)
				else
					SafeSetPoint(XPerl_FocusTarget, "CENTER", UIParent, "CENTER", 0, 0)
				end
			end
		end
	end

	if conf.pettarget.enable and XPerl_Player_Pet then
		if not XPerl_PetTarget then
			local pt = CreateFrame("Button", "XPerl_PetTarget", XPerl_Player_Pet, "ZPerl_TargetTarget_Template")
		end
		if XPerl_PetTarget then
			if not RestoreSavedPosition(XPerl_PetTarget) then
				SafeSetPoint(XPerl_PetTarget, "TOPLEFT", XPerl_Player_Pet, "TOPRIGHT", 5, 0)
			end
		end
		if (not InCombatLockdown()) then
			XPerl_PetTarget:Show()
		end
	end

	Set(XPerl_TargetTarget)
	if XPerl_TargetTargetTarget then
		Set(XPerl_TargetTargetTarget)
	end
	if XPerl_FocusTarget then
		Set(XPerl_FocusTarget)
	end
	if XPerl_PetTarget then
		Set(XPerl_PetTarget)
	end
end
