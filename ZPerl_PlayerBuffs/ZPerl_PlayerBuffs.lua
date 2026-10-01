-- X-Perl UnitFrames
-- Author: Chairface (originally Resike)
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

-- Forever: answers these can keep secret, made safe (see ZPerl_Compat.lua)
local UnitClass = XPerl_SafeUnitAPI(UnitClass)

local conf, pconf
XPerl_RequestConfig(function(new)
	conf = new
	pconf = new.player
end, "$Revision: 00a3cadfbbc8615840794db77581992f54190a2b $")

--local playerClass

--[===[@debug@
local function d(fmt, ...)
	fmt = fmt:gsub("(%%[sdqxf])", "|cFF60FF60%1|r")
	ChatFrame1:AddMessage("|cFFFF8080PlayerBuffs:|r "..format(fmt, ...), 0.8, 0.8, 0.8)
end
--@end-debug@]===]

local IsClassic = (WOW_PROJECT_ID >= WOW_PROJECT_CLASSIC or XPerl_IsForever)

-- Edit Mode (and UIParent frame management) re-Show()s BuffFrame/DebuffFrame after
-- a plain Hide(), leaving a visible frame with no UNIT_AURA events (stale icons stuck
-- at 0). Reparenting to a permanently hidden frame survives any re-Show.
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

-- Events are deliberately left registered so the frame stays current and can be
-- restored exactly, whatever events this client version uses.
local function HideBlizzardAuraFrame(frame)
	if (frame and frame:GetParent() ~= hiddenParent) then
		frame.xperlParent = frame:GetParent()
		frame:SetParent(hiddenParent)
	end
end

local function RestoreBlizzardAuraFrame(frame)
	if (frame and frame:GetParent() == hiddenParent) then
		frame:SetParent(frame.xperlParent or UIParent)
		frame:Show()
	end
end

-- setCommon
local function setCommon(self, filter, buffTemplate)
	self:SetAttribute("template", buffTemplate)
	self:SetAttribute("weaponTemplate", buffTemplate)
	self:SetAttribute("useparent-unit", true)

	self:SetAttribute("filter", filter)
	self:SetAttribute("separateOwn", 1)
	if (filter == "HELPFUL") then
		self:SetAttribute("includeWeapons", 1)
	end
	self:SetAttribute("point", pconf.buffs.above and "BOTTOMLEFT" or "TOPLEFT")
	if (pconf.buffs.wrap) then
		self:SetAttribute("wrapAfter", max(1, floor(XPerl_Player:GetWidth() / pconf.buffs.size)))	-- / XPerl_Player:GetEffectiveScale()
	else
		self:SetAttribute("wrapAfter", 0)
	end
	self:SetAttribute("maxWraps", pconf.buffs.rows)
	self:SetAttribute("xOffset", 32)	-- pconf.buffs.size)
	self:SetAttribute("yOffset", 0)
	self:SetAttribute("wrapXOffset", 0)
	self:SetAttribute("wrapYOffset", pconf.buffs.above and 32 or -32)

	self:SetAttribute("minWidth", 32)
	self:SetAttribute("minHeight", 32)

	self:SetAttribute("initial-width", pconf.buffs.size)
	self:SetAttribute("initial-height", pconf.buffs.size)
	-- Workaround: We can't set the initial-width/height (beacuse the api ignores this so far)
	-- So, we'll scale the parent frame so the effective size matches our setting

	if (filter == "HELPFUL" and pconf.buffs) then
		local needScale = pconf.buffs.size / 32
		self:SetScale(needScale)
	elseif (pconf.debuffs) then
		local needScale = pconf.debuffs.size / pconf.buffs.size
		self:SetScale(needScale)
	end
end

-- XPerl_Player_Buffs_Position
function XPerl_Player_Buffs_Position(self)
	if (self.buffFrame and not InCombatLockdown()) then
		self.buffFrame:ClearAllPoints()
		self.debuffFrame:ClearAllPoints()

		if (pconf.buffs.above) then
			self.buffFrame:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 3, 0)
		else
			--[[if (self.runes and self.runes:IsShown() and ((self.runes.child and self.runes.child:IsShown()) or (self.runes.child2 and self.runes.child2:IsShown())) and pconf.dockRunes) then
				self.buffFrame:SetPoint("TOPLEFT", self.portraitFrame, "BOTTOMLEFT", 3, -28)
			elseif ((pconf.xpBar or pconf.repBar) and not pconf.extendPortrait) then
				local diff = self.statsFrame:GetBottom() - self.portraitFrame:GetBottom()
				self.buffFrame:SetPoint("TOPLEFT", self.portraitFrame, "BOTTOMLEFT", 3, diff - 5)
			else
				self.buffFrame:SetPoint("TOPLEFT", self.portraitFrame, "BOTTOMLEFT", 3, 0)
			end]]

			local _, playerClass = UnitClass("player")
			local extraBar

			if (playerClass == "DRUID" and (XPerl_Plain(UnitPowerType(self.partyid)) or 0) > 0 and not pconf.noDruidBar) or (playerClass == "SHAMAN" and not IsClassic and (GetSpecialization and GetSpecialization()) == 1 and GetShapeshiftForm() == 0 and not pconf.noDruidBar) or (playerClass == "PRIEST" and (XPerl_Plain(UnitPowerType(self.partyid)) or 0) > 0 and not pconf.noDruidBar) then
				extraBar = 1
			else
				extraBar = 0
			end

			local offset = ((extraBar + (pconf.repBar and 1 or 0) + (pconf.xpBar and 1 or 0)) * 13.5)

			if (self.runes and self.runes:IsShown() and ((self.runes.child and self.runes.child:IsShown()) or (self.runes.child2 and self.runes.child2:IsShown())) and pconf.dockRunes) then
				if pconf.extendPortrait then
					self.buffFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 5, 0 - 28)
				else
					self.buffFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 5, 0 - offset - 28)
				end
			else
				if pconf.extendPortrait then
					self.buffFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 5, 0)
				else
					self.buffFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 5, 0 - offset)
				end
			end
		end

		if (self.buffFrame.plainAuras) then
			-- Z-Perl's own buff code lays debuffs out after the buffs, so
			-- both lists share one frame (as on the target frame)
			self.debuffFrame:SetAllPoints(self.buffFrame)
		elseif (pconf.buffs.above) then
			self.debuffFrame:SetPoint("BOTTOMLEFT", self.buffFrame, "TOPLEFT", 0, 2)
		else
			self.debuffFrame:SetPoint("TOPLEFT", self.buffFrame, "BOTTOMLEFT", 0, -2)
		end

		XPerl_Unit_BuffPositions(self, self.buffFrame.buff, self.buffFrame.debuff, pconf.buffs.size, pconf.debuffs.size)
	end
end

-- ============================================================================
-- Without Blizzard's SecureAuraHeaderTemplate (WoW Forever) the player's
-- buffs are drawn by Z-Perl's own buff code, the one the target frame uses,
-- on plain frames that UNIT_AURA refreshes. Each buff is a secure button so
-- a right-click still cancels it.
-- ============================================================================

-- The client fires a secure button on the down click and the up click both,
-- so exactly one is registered, the one the action bar setting asks for.
local function PlainClick()
	local get = GetCVarBool or (C_CVar and C_CVar.GetCVarBool)
	local ok, useKeyDown = pcall(get, "ActionButtonUseKeyDown")
	if ok and useKeyDown then
		return "RightButtonDown"
	end
	return "RightButtonUp"
end

-- Cancelling by name survives the icons going stale in combat (auras can't
-- be re-read there); by index only where the client has no CancelSpellByName
local cancelByName = type(CancelSpellByName) == "function"

local function XPerl_Player_DrawPlainBuffs(self)
	local buffs = self.buffFrame
	if not (buffs and buffs.plainAuras and self.conf) then
		return
	end
	if not pconf.buffs.enable then
		buffs:Hide()
		self.debuffFrame:Hide()
		return
	end

	XPerl_Unit_UpdateBuffs(self)

	if InCombatLockdown() then
		return -- attributes and anchors wait for combat to end
	end

	-- tell each secure button which buff its right-click cancels
	for i = 1, 40 do
		local button = buffs.buff and buffs.buff[i]
		if not button then
			break
		end
		if button:IsShown() then
			local name = cancelByName and XPerl_UnitBuff(self.partyid, button:GetID(), button.filter)
			button:SetAttribute("spell", name or nil)
			button:SetAttribute("index", (not name) and button:GetID() or nil)
			button:SetAttribute("filter", (not name) and button.filter or nil)
		end
	end

	XPerl_Player_Buffs_Position(self)
end

local function XPerl_Player_PlainBuffFrames(self)
	local buffs = CreateFrame("Frame", self:GetName().."buffFrame", self)
	buffs:SetSize(100, 50)
	buffs.plainAuras = true
	local debuffs = CreateFrame("Frame", self:GetName().."debuffFrame", self)
	debuffs:SetAllPoints(buffs)
	self.buffFrame, self.debuffFrame = buffs, debuffs

	self.buffSetup = {
		buffTemplate = "XPerl_Player_PlainBuffTemplate",
		rightClickable = true,
		onCreate = function(button)
			button:RegisterForClicks(PlainClick())
		end,
		buffScripts = {
			OnEnter = XPerl_Unit_SetBuffTooltip,
			OnLeave = XPerl_PlayerTipHide,
		},
		debuffScripts = {
			OnEnter = XPerl_Unit_SetDeBuffTooltip,
			OnLeave = XPerl_PlayerTipHide,
		},
		updateTooltipBuff = XPerl_Unit_SetBuffTooltip,
		updateTooltipDebuff = XPerl_Unit_SetDeBuffTooltip,
		debuffParent = true,
		debuffSizeMod = 0.2,
		buffAnchor1 = function(self, b)
			b:SetPoint("TOPLEFT", 0, 0)
		end,
	}
	self.buffSetup.debuffAnchor1 = self.buffSetup.buffAnchor1
	self.perlBuffs, self.perlDebuffs = 0, 0

	local events = CreateFrame("Frame")
	events:SetScript("OnEvent", function()
		XPerl_Player_DrawPlainBuffs(self)
	end)
	events:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("PLAYER_REGEN_ENABLED") -- auras are unreadable in combat: redraw after
end

-- Shows or hides the buff frames for the current settings, whichever kind they are
local function ApplyBuffFrames(self)
	local buffs, debuffs = self.buffFrame, self.debuffFrame
	if not buffs then
		return
	end

	if buffs.plainAuras then
		if self.conf then
			XPerl_SetBuffSize(self)
		end
		self.buffOptMix = nil
		XPerl_Player_DrawPlainBuffs(self)
		return
	end

	if pconf.buffs.enable then
		setCommon(buffs, "HELPFUL", "XPerl_Secure_BuffTemplate")
		buffs:Show()
	else
		buffs:Hide()
	end

	if pconf.buffs.enable and pconf.debuffs.enable then
		setCommon(debuffs, "HARMFUL", "XPerl_Secure_BuffTemplate")
		debuffs:Show()
	else
		debuffs:Hide()
	end
end

-- XPerl_Player_BuffSetup
function XPerl_Player_BuffSetup(self)
	if (not self) then
		return
	end

	if (InCombatLockdown()) then
		XPerl_OutOfCombatQueue[XPerl_Player_BuffSetup] = self
		return
	end

	if (not self.buffFrame) and not self.noAuraHeader then
		-- Built on Blizzard's SecureAuraHeaderTemplate, which some clients
		-- (WoW Forever) don't have. Without it Z-Perl draws the buffs itself.
		local ok, header = pcall(CreateFrame, "Frame", self:GetName().."buffFrame", self, "SecureAuraHeaderTemplate")
		if not ok then
			self.noAuraHeader = true
		else
			self.buffFrame = header
			self.debuffFrame = CreateFrame("Frame", self:GetName().."debuffFrame", self.buffFrame, "SecureAuraHeaderTemplate")
		end
	end
	if (not self.buffFrame) and self.noAuraHeader then
		XPerl_Player_PlainBuffFrames(self)
	end
	if (self.buffFrame) and not self.buffFrame.plainAuras and not self.buffFrame.BuffFrameUpdateTime then


		self.buffFrame:SetAttribute("frameStrata", "DIALOG")

		self.buffFrame.BuffFrameUpdateTime = 0
		self.buffFrame.BuffFrameFlashTime = 0
		self.buffFrame.BuffFrameFlashState = 1
		self.buffFrame.BuffAlphaValue = 1
		self.buffFrame:SetScript("OnUpdate", BuffFrame_OnUpdate)

		-- Not implemented.. yet.. maybe later
		--self.buffFrame.initialConfigFunction = function(self)
		--	d("initialConfigFunction(%s)", tostring(self))
		--	self:SetAttribute("useparent-unit", true)
		--end
		--self.debuffFrame.initialConfigFunction = self.buffFrame.initialConfigFunction
	end

	ApplyBuffFrames(self)

	XPerl_Player_Buffs_Position(self)

	if (not pconf.buffs.enable) then
		if (self.buffFrame) then
			self.buffFrame:Hide()
			self.debuffFrame:Hide()
		end
	end

	-- Blizzard's buffs go only when asked to (Hide Default Buffs). With that
	-- off, Blizzard's and Z-Perl's show at once.
	if (pconf.buffs.hideBlizzard) then
		HideBlizzardAuraFrame(BuffFrame)
		HideBlizzardAuraFrame(DebuffFrame)
		HideBlizzardAuraFrame(TemporaryEnchantFrame)
	else
		RestoreBlizzardAuraFrame(BuffFrame)
		RestoreBlizzardAuraFrame(DebuffFrame)
		RestoreBlizzardAuraFrame(TemporaryEnchantFrame)
	end
end

local function XPerl_Player_Buffs_Set_Bits(self)
	if (InCombatLockdown()) then
		XPerl_OutOfCombatQueue[XPerl_Player_Buffs_Set_Bits] = self
		return
	end

	--local _, class = UnitClass("player")
	--playerClass = class

	XPerl_Player_BuffSetup(self)

	-- The secure header is placed by the state driver; the plain frames are
	-- placed from Lua (XPerl_Player_Buffs_Position) and given no frame ref
	if self.buffFrame and not self.buffFrame.plainAuras then
		self.state:SetFrameRef("ZPerlPlayerBuffs", self.buffFrame)
	end
	self.state:SetAttribute("buffsAbove", pconf.buffs.above)

	ApplyBuffFrames(self)

	XPerl_Player_Buffs_Position(self)
end

-- AuraButton_OnUpdate
local function AuraButton_OnUpdate(self, elapsed)
	if (not self.endTime) then
		self:SetAlpha(1)
		self:SetScript("OnUpdate", nil)
		return
	end
	local index = self:GetID()
	local timeLeft = self.endTime - GetTime()
	if (timeLeft < _G.BUFF_WARNING_TIME) then
		self:SetAlpha(XPerl_Player.buffFrame.BuffAlphaValue)
	else
		self:SetAlpha(1)
	end
end

local function DoEnchant(self, slotID, hasEnchant, expire, charges)
	if (hasEnchant) then
		-- Fix to check to see if the player is a shaman and sets the fullDuration to 30 minutes. Shaman weapon enchants are only 30 minutes.
		--[[if (playerClass == "SHAMAN") then
			if ((expire / 1000) > 30 * 60) then
				self.fullDuration = 60 * 60
			else
				self.fullDuration = 30 * 60
			end
		end]]
		if (not self.fullDuration) then
			self.fullDuration = expire / 1000  -- expire is in milliseconds
			-- Shaman weapon enchants (Windfury, etc.) are 30 minutes
			if (self.fullDuration > 30 * 60) then
				self.fullDuration = 60 * 60  -- 1 hour for long buffs
			elseif (self.fullDuration > 10 * 60) then
				self.fullDuration = 30 * 60  -- 30 minutes for shaman enchants
			end
		end

		--self:Show()

		local textureName = GetInventoryItemTexture("player", slotID) -- Weapon Icon
		self.icon:SetTexture(textureName)
		self:SetAlpha(1)
		self.border:Hide()  -- Hide border for weapon enchants

		-- Handle cooldowns
		if (self.cooldown and expire and conf.buffs.cooldown and pconf.buffs.cooldown) then
			local timeEnd = GetTime() + (expire / 1000)
			local timeStart = timeEnd - self.fullDuration --(30 * 60)
			XPerl_CooldownFrame_SetTimer(self.cooldown, timeStart, self.fullDuration, 1)

			if (pconf.buffs.flash) then
				self.endTime = timeEnd
				self:SetScript("OnUpdate", AuraButton_OnUpdate)
			else
				self.endTime = nil
			end
		else
			self.cooldown:Hide()
			self.endTime = nil
		end
	else
		self.fullDuration = nil
		if not InCombatLockdown() then
			self:Hide()
		end
	end
end

--local function setupButton(self)
--end

function XPerl_PlayerBuffs_Show(self)
	self:RegisterEvent("UNIT_AURA")
	--self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	XPerl_PlayerBuffs_Update(self)
end

function XPerl_PlayerBuffs_Hide(self)
	self:UnregisterEvent("UNIT_AURA")
	--self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
	XPerl_PlayerBuffs_Update(self)
end

function XPerl_PlayerBuffs_OnEvent(self, event, ...)
	if (event == "UNIT_AURA") then
		local unit = ...
		if (unit == "player" or unit == "pet" or unit == "vehicle") then
			XPerl_PlayerBuffs_Update(self)
		end
	--[[elseif (event == "PLAYER_EQUIPMENT_CHANGED") then
		local slot, hasItem = ...
		if (slot == 16 or slot == 17) then
			XPerl_PlayerBuffs_Update(self)
		end]]
	end
end

function XPerl_PlayerBuffs_OnAttrChanged(self, attr, value)
	if (attr == "index" or attr == "filter" or attr == "target-slot") then
		XPerl_PlayerBuffs_Update(self)
	end
end

function XPerl_PlayerBuffs_OnEnter(self)
	if (conf.tooltip.enableBuffs and XPerl_TooltipModiferPressed(true)) then
		if (not conf.tooltip.hideInCombat or not InCombatLockdown()) then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, 0)

			local slot = self:GetAttribute("target-slot")
			if (slot) then
				GameTooltip:SetInventoryItem("player", slot)
			else
				local partyid = SecureButton_GetUnit(self:GetParent()) or "player"
				if (self:GetAttribute("filter") == "HELPFUL") then
					XPerl_TooltipSetUnitBuff(GameTooltip, partyid, self:GetID(), "HELPFUL")
				else
					XPerl_TooltipSetUnitDebuff(GameTooltip, partyid, self:GetID(), "HARMFUL")
				end
				self.UpdateTooltip = XPerl_PlayerBuffs_OnEnter
			end
		end
	end
end

function XPerl_PlayerBuffs_OnLeave(self)
	GameTooltip:Hide()
end

function XPerl_PlayerBuffs_Update(self)
	local slot = self:GetAttribute("target-slot")
	if (slot) then
		-- Weapon Enchant
		local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, offHandCharges, offHandEnchantId = GetWeaponEnchantInfo()
		if (slot == 16) then
			DoEnchant(self, 16, hasMainHandEnchant, mainHandExpiration, mainHandCharges)
		else
			DoEnchant(self, 17, hasOffHandEnchant, offHandExpiration, offHandCharges)
		end
	else
		-- Aura
		local index = self:GetAttribute("index")
		local filter = self:GetAttribute("filter")
		local unit = SecureButton_GetUnit(self:GetParent()) or "player"

		if (filter and unit) then
			local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge = UnitAura(unit, index, filter)
			self.filter = filter
			self:SetAlpha(1)

			if (name and filter == "HARMFUL") then
				self.border:Show()
				local borderColor = DebuffTypeColor[(debuffType or "none")]
				self.border:SetVertexColor(borderColor.r, borderColor.g, borderColor.b)
			else
				self.border:Hide()
			end

			self.icon:SetTexture(icon)
			if ((count or 0) > 1) then
				self.count:SetText(count)
				self.count:Show()
			else
				self.count:Hide()
			end

			-- Handle cooldowns
			if (self.cooldown and (duration or 0) ~= 0 and conf.buffs.cooldown and (unitCaster or conf.buffs.cooldownAny)) then
				local start = expirationTime - duration
				XPerl_CooldownFrame_SetTimer(self.cooldown, start, duration, 1, unitCaster)
				if (pconf.buffs.flash) then
					self.endTime = expirationTime
					self:SetScript("OnUpdate", AuraButton_OnUpdate)
				else
					self.endTime = nil
				end
			else
				self.cooldown:Hide()
				self.endTime = nil
			end
			-- TODO: Variable this
			self.cooldown:SetDrawEdge(false)
			self.cooldown:SetDrawBling(false)
			-- Blizzard Cooldown Text Support
			if not conf.buffs.blizzard then
				self.cooldown:SetHideCountdownNumbers(true)
			else
				self.cooldown:SetHideCountdownNumbers(false)
			end
			-- OmniCC Support
			if not conf.buffs.omnicc then
				self.cooldown.noCooldownCount = true
			else
				self.cooldown.noCooldownCount = nil
			end
		end
	end
end

function XPerl_PlayerBuffs_OnLoad(self)
	XPerl_SetChildMembers(self)
	-- Only register clicks outside of combat to avoid taint
	if not InCombatLockdown() then
		self:RegisterForClicks("RightButtonUp") -- The XML version doesn't work..
	end
	--XPerl_ProtectedCall(setupButton, self)
end


XPerl_RegisterOptionChanger(XPerl_Player_Buffs_Set_Bits, XPerl_Player)
