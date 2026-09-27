-- ZPerl Big Debuffs Options Panel
-- Integrates into ZPerl's options window as a new tab

local addonName, addon = ...

-- Will be initialized after main addon loads
local optionsPanel = nil
local db = nil
local tabButton = nil
local TAB_ID = 14 -- Our tab ID (after Camera which is 13)

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function CreateCheckbox(parent, name, label, tooltip, onClick)
    local cb = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    cb.Text:SetText(label)
    cb.tooltipText = tooltip
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if onClick then onClick(self, checked) end
    end)
    return cb
end

local function CreateSlider(parent, name, label, minVal, maxVal, step, onValueChanged)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(140)
    slider:SetHeight(17)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    
    _G[name .. "Text"]:SetText(label)
    _G[name .. "Low"]:SetText(string.format("%.1f", minVal))
    _G[name .. "High"]:SetText(string.format("%.1f", maxVal))
    
    -- Value display
    slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider.valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)
    
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10 -- Round to 1 decimal
        self.valueText:SetText(string.format("%.1f", value))
        if onValueChanged then onValueChanged(self, value) end
    end)
    
    return slider
end

local function CreateSectionHeader(parent, text, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", x, y)
    header:SetText("|cffffd700" .. text .. "|r")
    return header
end

local function CreateSubLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

-- ============================================
-- CREATE THE OPTIONS PANEL CONTENT
-- ============================================

local function CreateOptionsContent(parent)
    local content = CreateFrame("Frame", "ZPerl_BigDebuffs_OptionsContent", parent)
    content:SetAllPoints(parent)
    content:Hide()
    
    local yOffset = -15
    local leftCol = 15
    local rightCol = 220
    
    -- ============================================
    -- GENERAL SECTION
    -- ============================================
    CreateSectionHeader(content, "General Settings", leftCol, yOffset)
    yOffset = yOffset - 25
    
    content.enabledCB = CreateCheckbox(content, "ZPerlBD_Enabled", "Enable Big Debuffs", 
        "Enable or disable the Big Debuffs display",
        function(self, checked)
            if db then
                db.profile.enabled = checked
                if ZPerl_BigDebuffs then
                    if checked then ZPerl_BigDebuffs:Enable() else ZPerl_BigDebuffs:Disable() end
                end
            end
        end)
    content.enabledCB:SetPoint("TOPLEFT", leftCol, yOffset)
    yOffset = yOffset - 25
    
    content.cooldownCB = CreateCheckbox(content, "ZPerlBD_Cooldown", "Show Cooldown Swipe",
        "Show the cooldown animation on debuff icons",
        function(self, checked)
            if db then db.profile.showCooldown = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.cooldownCB:SetPoint("TOPLEFT", leftCol, yOffset)
    
    content.cooldownTextCB = CreateCheckbox(content, "ZPerlBD_CooldownText", "Show Cooldown Text",
        "Show the remaining time as text",
        function(self, checked)
            if db then db.profile.showCooldownText = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.cooldownTextCB:SetPoint("TOPLEFT", rightCol, yOffset)
    yOffset = yOffset - 35
    
    -- ============================================
    -- SPELL TYPES SECTION
    -- ============================================
    CreateSectionHeader(content, "Spell Types to Display", leftCol, yOffset)
    yOffset = yOffset - 25
    
    content.ccCB = CreateCheckbox(content, "ZPerlBD_CC", "Crowd Control",
        "Polymorph, Fear, Blind, etc.",
        function(self, checked)
            if db then db.profile.showCC = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.ccCB:SetPoint("TOPLEFT", leftCol, yOffset)
    
    content.interruptsCB = CreateCheckbox(content, "ZPerlBD_Interrupts", "Interrupts",
        "Kick, Counterspell, etc.",
        function(self, checked)
            if db then db.profile.showInterrupts = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.interruptsCB:SetPoint("TOPLEFT", rightCol, yOffset)
    yOffset = yOffset - 22
    
    content.immunitiesCB = CreateCheckbox(content, "ZPerlBD_Immunities", "Immunities",
        "Ice Block, Divine Shield, etc.",
        function(self, checked)
            if db then db.profile.showImmunities = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.immunitiesCB:SetPoint("TOPLEFT", leftCol, yOffset)
    
    content.immunitiesSpellsCB = CreateCheckbox(content, "ZPerlBD_ImmunitiesSpells", "Spell Immunities",
        "Cloak of Shadows, Grounding, etc.",
        function(self, checked)
            if db then db.profile.showImmunitiesSpells = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.immunitiesSpellsCB:SetPoint("TOPLEFT", rightCol, yOffset)
    yOffset = yOffset - 22
    
    content.defensivesCB = CreateCheckbox(content, "ZPerlBD_Defensives", "Defensive Buffs",
        "Pain Suppression, Shield Wall, etc.",
        function(self, checked)
            if db then db.profile.showDefensiveBuffs = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.defensivesCB:SetPoint("TOPLEFT", leftCol, yOffset)
    
    content.offensivesCB = CreateCheckbox(content, "ZPerlBD_Offensives", "Offensive Buffs",
        "Adrenaline Rush, Icy Veins, etc.",
        function(self, checked)
            if db then db.profile.showOffensiveBuffs = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.offensivesCB:SetPoint("TOPLEFT", rightCol, yOffset)
    yOffset = yOffset - 22
    
    content.rootsCB = CreateCheckbox(content, "ZPerlBD_Roots", "Roots",
        "Frost Nova, Entangling Roots, etc.",
        function(self, checked)
            if db then db.profile.showRoots = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.rootsCB:SetPoint("TOPLEFT", leftCol, yOffset)
    
    content.offDebuffsCB = CreateCheckbox(content, "ZPerlBD_OffDebuffs", "Offensive Debuffs",
        "Usually too noisy",
        function(self, checked)
            if db then db.profile.showOffensiveDebuffs = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.offDebuffsCB:SetPoint("TOPLEFT", rightCol, yOffset)
    yOffset = yOffset - 35
    
    -- ============================================
    -- FRAME SETTINGS SECTION
    -- ============================================
    CreateSectionHeader(content, "Frame Settings", leftCol, yOffset)
    yOffset = yOffset - 25
    
    -- Player Frame
    CreateSubLabel(content, "Player:", leftCol, yOffset)
    
    content.playerEnabledCB = CreateCheckbox(content, "ZPerlBD_PlayerEnabled", "Enabled", nil,
        function(self, checked)
            if db then db.profile.player.enabled = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.playerEnabledCB:SetPoint("TOPLEFT", leftCol + 50, yOffset + 3)
    
    content.playerSizeSlider = CreateSlider(content, "ZPerlBD_PlayerSize", "Size", 0.5, 2.0, 0.1,
        function(self, value)
            if db then db.profile.player.size = value; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.playerSizeSlider:SetPoint("TOPLEFT", leftCol + 160, yOffset - 2)
    yOffset = yOffset - 40
    
    -- Target Frame
    CreateSubLabel(content, "Target:", leftCol, yOffset)
    
    content.targetEnabledCB = CreateCheckbox(content, "ZPerlBD_TargetEnabled", "Enabled", nil,
        function(self, checked)
            if db then db.profile.target.enabled = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.targetEnabledCB:SetPoint("TOPLEFT", leftCol + 50, yOffset + 3)
    
    content.targetSizeSlider = CreateSlider(content, "ZPerlBD_TargetSize", "Size", 0.5, 2.0, 0.1,
        function(self, value)
            if db then db.profile.target.size = value; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.targetSizeSlider:SetPoint("TOPLEFT", leftCol + 160, yOffset - 2)
    yOffset = yOffset - 40
    
    -- Focus Frame
    CreateSubLabel(content, "Focus:", leftCol, yOffset)
    
    content.focusEnabledCB = CreateCheckbox(content, "ZPerlBD_FocusEnabled", "Enabled", nil,
        function(self, checked)
            if db then db.profile.focus.enabled = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.focusEnabledCB:SetPoint("TOPLEFT", leftCol + 50, yOffset + 3)
    
    content.focusSizeSlider = CreateSlider(content, "ZPerlBD_FocusSize", "Size", 0.5, 2.0, 0.1,
        function(self, value)
            if db then db.profile.focus.size = value; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.focusSizeSlider:SetPoint("TOPLEFT", leftCol + 160, yOffset - 2)
    yOffset = yOffset - 40
    
    -- Party Frames
    CreateSubLabel(content, "Party:", leftCol, yOffset)
    
    content.partyEnabledCB = CreateCheckbox(content, "ZPerlBD_PartyEnabled", "Enabled", nil,
        function(self, checked)
            if db then db.profile.party.enabled = checked; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.partyEnabledCB:SetPoint("TOPLEFT", leftCol + 50, yOffset + 3)
    
    content.partySizeSlider = CreateSlider(content, "ZPerlBD_PartySize", "Size", 0.5, 2.0, 0.1,
        function(self, value)
            if db then db.profile.party.size = value; if ZPerl_BigDebuffs then ZPerl_BigDebuffs:Refresh() end end
        end)
    content.partySizeSlider:SetPoint("TOPLEFT", leftCol + 160, yOffset - 2)
    
    -- Refresh all control values from database
    function content:RefreshValues()
        if not db or not db.profile then return end
        
        self.enabledCB:SetChecked(db.profile.enabled)
        self.cooldownCB:SetChecked(db.profile.showCooldown)
        self.cooldownTextCB:SetChecked(db.profile.showCooldownText)
        
        self.ccCB:SetChecked(db.profile.showCC)
        self.interruptsCB:SetChecked(db.profile.showInterrupts)
        self.immunitiesCB:SetChecked(db.profile.showImmunities)
        self.immunitiesSpellsCB:SetChecked(db.profile.showImmunitiesSpells)
        self.defensivesCB:SetChecked(db.profile.showDefensiveBuffs)
        self.offensivesCB:SetChecked(db.profile.showOffensiveBuffs)
        self.rootsCB:SetChecked(db.profile.showRoots)
        self.offDebuffsCB:SetChecked(db.profile.showOffensiveDebuffs)
        
        self.playerEnabledCB:SetChecked(db.profile.player.enabled)
        self.playerSizeSlider:SetValue(db.profile.player.size or 1.0)
        
        self.targetEnabledCB:SetChecked(db.profile.target.enabled)
        self.targetSizeSlider:SetValue(db.profile.target.size or 1.0)
        
        self.focusEnabledCB:SetChecked(db.profile.focus.enabled)
        self.focusSizeSlider:SetValue(db.profile.focus.size or 1.0)
        
        self.partyEnabledCB:SetChecked(db.profile.party.enabled)
        self.partySizeSlider:SetValue(db.profile.party.size or 1.0)
    end
    
    content:SetScript("OnShow", function(self)
        self:RefreshValues()
    end)
    
    return content
end

-- ============================================
-- CREATE TAB BUTTON
-- ============================================

local function CreateTabButton(parent, tabArea)
    -- Create a tab button similar to XPerlTabTemplate
    local tab = CreateFrame("Button", "XPerl_Options_Tab" .. TAB_ID, tabArea)
    tab:SetSize(80, 16)
    tab:SetID(TAB_ID)
    
    -- Create textures similar to other tabs
    tab.disabledLeft = tab:CreateTexture(tab:GetName() .. "DisabledLeft", "BACKGROUND")
    tab.disabledLeft:SetTexture("Interface\\Addons\\ZPerl_Options\\Images\\ZPerl_Tabs")
    tab.disabledLeft:SetPoint("TOPLEFT", 0, -1)
    tab.disabledLeft:SetPoint("BOTTOMRIGHT", tab, "BOTTOMLEFT", 8, 0)
    
    tab.disabledRight = tab:CreateTexture(tab:GetName() .. "DisabledRight", "BACKGROUND")
    tab.disabledRight:SetTexture("Interface\\Addons\\ZPerl_Options\\Images\\ZPerl_Tabs")
    tab.disabledRight:SetPoint("TOPRIGHT", 0, -1)
    tab.disabledRight:SetPoint("BOTTOMLEFT", tab, "BOTTOMRIGHT", -8, 0)
    
    tab.disabledMiddle = tab:CreateTexture(tab:GetName() .. "DisabledMiddle", "BACKGROUND")
    tab.disabledMiddle:SetTexture("Interface\\Addons\\ZPerl_Options\\Images\\ZPerl_Tabs")
    tab.disabledMiddle:SetPoint("TOPLEFT", tab.disabledLeft, "TOPRIGHT")
    tab.disabledMiddle:SetPoint("BOTTOMRIGHT", tab.disabledRight, "BOTTOMLEFT")
    
    tab.enabledLeft = tab:CreateTexture(tab:GetName() .. "EnabledLeft", "BACKGROUND")
    tab.enabledLeft:SetTexture("Interface\\Addons\\ZPerl_Options\\Images\\ZPerl_Tabs")
    tab.enabledLeft:SetPoint("TOPLEFT")
    tab.enabledLeft:SetPoint("BOTTOMRIGHT", tab, "BOTTOMLEFT", 8, 0)
    tab.enabledLeft:Hide()
    
    tab.enabledRight = tab:CreateTexture(tab:GetName() .. "EnabledRight", "BACKGROUND")
    tab.enabledRight:SetTexture("Interface\\Addons\\ZPerl_Options\\Images\\ZPerl_Tabs")
    tab.enabledRight:SetPoint("TOPRIGHT")
    tab.enabledRight:SetPoint("BOTTOMLEFT", tab, "BOTTOMRIGHT", -8, 0)
    tab.enabledRight:Hide()
    
    tab.enabledMiddle = tab:CreateTexture(tab:GetName() .. "EnabledMiddle", "BACKGROUND")
    tab.enabledMiddle:SetTexture("Interface\\Addons\\ZPerl_Options\\Images\\ZPerl_Tabs")
    tab.enabledMiddle:SetPoint("TOPLEFT", tab.enabledLeft, "TOPRIGHT")
    tab.enabledMiddle:SetPoint("BOTTOMRIGHT", tab.enabledRight, "BOTTOMLEFT")
    tab.enabledMiddle:Hide()
    
    -- Highlight texture
    tab.highlight = tab:CreateTexture(tab:GetName() .. "HighlightTexture", "HIGHLIGHT")
    tab.highlight:SetTexture("Interface\\AddOns\\ZPerl_Options\\Images\\ZPerl_Tabs")
    tab.highlight:SetBlendMode("ADD")
    tab.highlight:SetPoint("TOPLEFT", 3, -2)
    tab.highlight:SetPoint("BOTTOMRIGHT", -3, 2)
    
    -- Text
    tab.text = tab:CreateFontString(tab:GetName() .. "Text", "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("CENTER")
    tab.text:SetText("BigDebuffs")
    
    -- Size based on text
    tab:SetWidth(tab.text:GetStringWidth() + 20)
    
    -- Set tab colors (match ZPerl's color scheme)
    if XPerl_Options_SetTabColor then
        XPerl_Options_SetTabColor(tab, XPerlDB and XPerlDB.optionsColour)
    end
    
    -- Scripts
    tab:SetScript("OnClick", function(self)
        if self:GetParent().SelectTab then
            self:GetParent():SelectTab(TAB_ID)
        end
    end)
    
    tab:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 1, 1)
    end)
    
    tab:SetScript("OnLeave", function(self)
        self.text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end)
    
    return tab
end

-- ============================================
-- HOOK INTO ZPERL OPTIONS
-- ============================================

local function HookZPerlOptions()
    if not XPerl_Options then return false end
    
    -- Get the tab area
    local tabArea = XPerl_Options_Tab
    if not tabArea then
        -- Try to find it
        for i = 1, XPerl_Options:GetNumChildren() do
            local child = select(i, XPerl_Options:GetChildren())
            if child and child:GetName() and child:GetName():find("_Tab$") then
                tabArea = child
                break
            end
        end
    end
    
    if not tabArea then
        print("|cff00ff00ZPerl Big Debuffs:|r Could not find tab area")
        return false
    end
    
    -- Create our content panel in the options area
    local optionsArea = XPerl_Options_Area_Tabs
    if not optionsArea then
        print("|cff00ff00ZPerl Big Debuffs:|r Could not find options area")
        return false
    end
    
    optionsPanel = CreateOptionsContent(optionsArea)
    
    -- Create our tab button
    tabButton = CreateTabButton(XPerl_Options, tabArea)
    
    -- Position after the last tab (Tab13 - Camera)
    local lastTab = _G["XPerl_Options_Tab13"]
    if lastTab then
        tabButton:SetPoint("BOTTOMLEFT", lastTab, "BOTTOMRIGHT", -1, 0)
    else
        -- Fallback - find the last visible tab
        for i = 13, 1, -1 do
            local t = _G["XPerl_Options_Tab" .. i]
            if t and t:IsShown() then
                tabButton:SetPoint("BOTTOMLEFT", t, "BOTTOMRIGHT", -1, 0)
                break
            end
        end
    end
    
    tabButton:Show()
    
    -- Hook the SelectTab function
    local originalSelectTab = tabArea.SelectTab
    if originalSelectTab then
        tabArea.SelectTab = function(self, id)
            -- Hide our panel when selecting other tabs
            if optionsPanel then
                if id == TAB_ID then
                    -- Show our panel, hide others
                    optionsPanel:Show()
                    optionsPanel:RefreshValues()
                    
                    -- Hide other panels
                    if XPerl_Options_Global_Options then XPerl_Options_Global_Options:Hide() end
                    if XPerl_Options_Player then XPerl_Options_Player:Hide() end
                    if XPerl_Options_Party then XPerl_Options_Party:Hide() end
                    if XPerl_Options_Raid then XPerl_Options_Raid:Hide() end
                    
                    -- Update tab appearance
                    for i = 1, 13 do
                        local t = _G["XPerl_Options_Tab" .. i]
                        if t and XPerl_Options_EnableTab then
                            XPerl_Options_EnableTab(t, false)
                        end
                    end
                    if XPerl_Options_EnableTab then
                        XPerl_Options_EnableTab(tabButton, true)
                    end
                    
                    return
                else
                    optionsPanel:Hide()
                    if XPerl_Options_EnableTab then
                        XPerl_Options_EnableTab(tabButton, false)
                    end
                end
            end
            
            -- Call original
            if originalSelectTab then
                originalSelectTab(self, id)
            end
        end
    end
    
    -- Adjust options window width to fit our tab
    local currentWidth = XPerl_Options:GetWidth()
    local tabWidth = tabButton:GetWidth()
    XPerl_Options:SetWidth(currentWidth + tabWidth)
    if XPerl_OptionsAnchor then
        XPerl_OptionsAnchor:SetWidth(currentWidth + tabWidth)
    end
    
    return true
end

-- ============================================
-- STANDALONE OPTIONS (fallback)
-- ============================================

local standalonePanel = nil

local function CreateStandaloneOptions()
    -- Create standalone panel as fallback
    local panel = CreateFrame("Frame", "ZPerl_BigDebuffs_StandaloneOptions", UIParent, "BackdropTemplate")
    panel:SetSize(420, 450)
    panel:SetPoint("CENTER")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    panel:SetBackdropColor(0, 0, 0, 1)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("|cff00ff00Z-Perl|r Big Debuffs Options")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)
    
    -- Create content inside
    local content = CreateOptionsContent(panel)
    content:SetPoint("TOPLEFT", 10, -40)
    content:SetPoint("BOTTOMRIGHT", -10, 10)
    content:Show()
    
    panel.content = content
    
    panel:SetScript("OnShow", function(self)
        if self.content and self.content.RefreshValues then
            self.content:RefreshValues()
        end
    end)
    
    return panel
end

-- ============================================
-- INITIALIZATION
-- ============================================

local function InitOptions()
    -- Get database reference from main addon
    if ZPerl_BigDebuffs and ZPerl_BigDebuffs.GetDB then
        db = ZPerl_BigDebuffs:GetDB()
    end
    
    -- Try to hook into ZPerl options
    local hooked = false
    if XPerl_Options then
        hooked = HookZPerlOptions()
    end
    
    -- Create standalone as fallback
    standalonePanel = CreateStandaloneOptions()
    
    -- Add ShowOptions method to main addon
    if ZPerl_BigDebuffs then
        ZPerl_BigDebuffs.ShowOptions = function(self)
            if XPerl_Options and XPerl_Options:IsShown() and optionsPanel then
                -- Already in ZPerl options, switch to our tab
                local tabArea = XPerl_Options_Tab
                if tabArea and tabArea.SelectTab then
                    tabArea:SelectTab(TAB_ID)
                end
            elseif XPerl_Options and hooked then
                -- Open ZPerl options and go to our tab
                if XPerl_Toggle then
                    XPerl_Toggle()
                    C_Timer.After(0.1, function()
                        local tabArea = XPerl_Options_Tab
                        if tabArea and tabArea.SelectTab then
                            tabArea:SelectTab(TAB_ID)
                        end
                    end)
                end
            else
                -- Use standalone
                if standalonePanel then
                    standalonePanel:Show()
                end
            end
        end
    end
    
    if hooked then
        print("|cff00ff00ZPerl Big Debuffs:|r Options added to Z-Perl options (BigDebuffs tab)")
    end
end

-- Wait for everything to load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    -- Delay to ensure ZPerl options is fully loaded
    C_Timer.After(1.0, InitOptions)
end)

-- Export toggle function for slash command
addon.ToggleOptions = function()
    if ZPerl_BigDebuffs and ZPerl_BigDebuffs.ShowOptions then
        ZPerl_BigDebuffs:ShowOptions()
    elseif standalonePanel then
        if standalonePanel:IsShown() then
            standalonePanel:Hide()
        else
            standalonePanel:Show()
        end
    end
end
