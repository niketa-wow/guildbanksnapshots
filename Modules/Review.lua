local addonName = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceSerializer = LibStub("AceSerializer-3.0")
local AceGUI = LibStub("AceGUI-3.0", true)

------------------------------------------------------------

local gsub, tonumber = string.gsub, tonumber
local pairs, tinsert = pairs, table.insert
local GameTooltip = GameTooltip
local GetCoinTextureString = GetCoinTextureString

local ReviewFrame

--*------------------------------------------------------------------------

local function GetGuildList()
    local list = {}
    local sort = {}

    for guildID, v in pairs(addon.db.global.guilds, function(a, b) return a < b end) do
        list[guildID] = addon:GetGuildDisplayName(guildID)
        tinsert(sort, guildID)
    end

    return list, sort
end

------------------------------------------------------------

local function GetTabList()
    local list = {}
    local sort = {}

    for i = 1, addon.db.global.guilds[ReviewFrame:GetSelected()].numTabs do
        tinsert(list, {text = L["Tab"].." "..i, value = "tab"..i})
        tinsert(sort, "tab"..i)
    end

    tinsert(list, {text = L["Money"], value = "moneyTab"})
    tinsert(sort, "moneyTab")

    return list, sort
end

------------------------------------------------------------

local function GetTabName(guildID, tabID)
    if tabID == "moneyTab" then
        return L["Money"]
    elseif guildID and tabID then
        tabID = tonumber((gsub(tabID, "^tab", "")))
        return string.format("%s (%s %d)", addon.db.global.guilds[guildID].tabs[tabID].name, L["Tab"], tabID)
    end
end

--*------------------------------------------------------------------------

local function guildList_OnValueChanged(_, _, selectedGuild)
    ReviewFrame:SetSelectedGuild(selectedGuild)
end

------------------------------------------------------------

local function OnHyperlinkEnter(self, transaction)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetHyperlink(addon:GetTransactionInfo(transaction).itemLink)
    GameTooltip:Show()
end


------------------------------------------------------------

local function Tooltip_OnLeave()
    GameTooltip:ClearLines()
    GameTooltip:Hide()
end

------------------------------------------------------------

local function snapshot_OnClick(self)
    ReviewFrame:SetSelectedSnap(self:GetUserData("snapID"))
end

------------------------------------------------------------

local function tabGroup_OnGroupSelected(self, _, selectedTab)
    ReviewFrame:GetUserData("children").tabTitle:SetText(GetTabName(ReviewFrame:GetSelected(), selectedTab))
    ReviewFrame:SetSelectedTab(selectedTab)
    ReviewFrame:DoLayout()
end

--*------------------------------------------------------------------------

local methods = {
    ClearSelectedSnap = function(self)
        ReviewFrame:GetUserData("children").reviewPanel:ReleaseChildren()
    end,

    ------------------------------------------------------------

    GetSelected = function(self)
        return self:GetUserData("selectedGuild"), self:GetUserData("selectedSnap"), self:GetUserData("selectedTab")
    end,

    ------------------------------------------------------------

    Load = function(self)
        self:Show()
        local children = self:GetUserData("children")
        local guildList = GetGuildList()
        children.guildList:SetList(guildList)
        children.guildList:SetDisabled(addon.tcount(guildList) == 0)
        local selectedGuild = self:GetUserData("selectedGuild") or addon.db.global.settings.defaultGuild
        if selectedGuild then
            children.guildList:SetValue(selectedGuild)
            self:SetSelectedGuild(selectedGuild)
        end
    end,

    ------------------------------------------------------------

    LoadSnapshotList = function(self, selectedGuild)
        local snapshotList = self:GetUserData("children").snapshotList
        snapshotList:ReleaseChildren()
        for snapID, _ in addon.pairs(addon.db.global.guilds[selectedGuild].scans, function(a, b) return b < a end) do
            local snapshot = AceGUI:Create("Button")
            snapshot:SetFullWidth(true)
            snapshot:SetText(date(addon.db.global.settings.dateFormat, snapID))
            snapshot:SetUserData("snapID", snapID)
            snapshotList:AddChild(snapshot)

            snapshot:SetCallback("OnClick", snapshot_OnClick)
        end
    end,

    ------------------------------------------------------------

    LoadTransactions = function(self)
        local selectedGuild, selectedSnapshot, selectedTab = self:GetSelected()
        local tabPanel = ReviewFrame:GetUserData("children").tabPanel
        tabPanel:ReleaseChildren()

        if not selectedTab then return end

        if selectedTab ~= "moneyTab" then
            local tabID = tonumber(strmatch(selectedTab, "^tab(%d+)$"))
            for _, transaction in addon.pairs(addon.db.global.guilds[selectedGuild].scans[selectedSnapshot].tabs[tabID].transactions, function(a, b) return b < a end) do
                local label = AceGUI:Create("Label")
                label:SetFullWidth(true)
                label:SetFontObject(GameFontHighlight)
                label:SetText(addon:GetTransactionLabel(transaction))
                tabPanel:AddChild(label)

                label.frame:EnableMouse(true)
                label.frame:SetHyperlinksEnabled(true)
                label.frame:SetScript("OnHyperlinkClick", ChatFrame_OnHyperlinkShow)
                label.frame:SetScript("OnHyperlinkEnter", function(frame) OnHyperlinkEnter(frame, transaction) end)
                label.frame:SetScript("OnHyperlinkLeave", Tooltip_OnLeave)
            end
        else
            for _, transaction in addon.pairs(addon.db.global.guilds[selectedGuild].scans[selectedSnapshot].moneyTransactions, function(a, b) return b < a end) do
                local label = AceGUI:Create("Label")
                label:SetFullWidth(true)
                label:SetFontObject(GameFontHighlight)
                label:SetText(addon:GetMoneyTransactionLabel(transaction))
                tabPanel:AddChild(label)
            end
        end
    end,

    ------------------------------------------------------------

    SetSelectedGuild = function(self, selectedGuild)
        ReviewFrame:SetUserData("selectedGuild", selectedGuild)
        ReviewFrame:LoadSnapshotList(selectedGuild)
        ReviewFrame:SetTitle("Guild Bank Snapshots"..(selectedGuild and (" - "..addon:GetGuildDisplayName(selectedGuild)) or ""))
        self:ClearSelectedSnap()
    end,

    ------------------------------------------------------------

    SetSelectedSnap = function(self, selectedSnap)
        self:SetUserData("selectedSnap", selectedSnap)
        addon:LoadReviewPanel()

        self:GetUserData("children").tabGroup:SelectTab(self:GetUserData("selectedTab") or "tab1")
    end,

    ------------------------------------------------------------

    SetSelectedTab = function(self, selectedTab)
        self:SetUserData("selectedTab", selectedTab)
        self:LoadTransactions()
    end,
}

------------------------------------------------------------

function addon:InitializeReviewFrame()
    ReviewFrame = AceGUI:Create("GBS3Frame")
    ReviewFrame:SetTitle("Guild Bank Snapshots")
    ReviewFrame:SetLayout("GBS3TopSidebarGroup")
    ReviewFrame:SetUserData("sidebarDenom", 4)
    ReviewFrame:SetUserData("children", {})
    addon.ReviewFrame = ReviewFrame

    for method, func in pairs(methods) do
        ReviewFrame[method] = func
    end

    local children = ReviewFrame:GetUserData("children")

    ------------------------------------------------------------

    local guildListContainer = AceGUI:Create("GBS3SimpleGroup")
    guildListContainer:SetFullWidth(true)
    guildListContainer:SetLayout("Flow")
    ReviewFrame:AddChild(guildListContainer)

    local guildList = AceGUI:Create("Dropdown")
    guildList:SetFullWidth(true)
    guildListContainer:AddChild(guildList)
    children.guildList = guildList

    guildList:SetCallback("OnValueChanged", guildList_OnValueChanged)

    ------------------------------------------------------------

    local snapshotListContainer = AceGUI:Create("GBS3InlineGroup")
    snapshotListContainer:SetLayout("Fill")
    ReviewFrame:AddChild(snapshotListContainer)

    local snapshotList = AceGUI:Create("ScrollFrame")
    snapshotList:SetLayout("List")
    snapshotListContainer:AddChild(snapshotList)
    children.snapshotList = snapshotList

    ------------------------------------------------------------

    local reviewPanel = AceGUI:Create("GBS3InlineGroup")
    reviewPanel:SetLayout("Flow")
    ReviewFrame:AddChild(reviewPanel)
    children.reviewPanel = reviewPanel
end

--*------------------------------------------------------------------------

function addon:LoadReviewPanel()
    local reviewPanel = ReviewFrame:GetUserData("children").reviewPanel
    local children = ReviewFrame:GetUserData("children")
    local selectedGuild, selectedSnapshot, selectedTab = ReviewFrame:GetSelected()
    local scan = self.db.global.guilds[selectedGuild].scans[selectedSnapshot]

    reviewPanel:ReleaseChildren()

    ------------------------------------------------------------

    local snapshot = AceGUI:Create("Label")
    snapshot:SetFullWidth(true)
    snapshot:SetColor(1, .82, 0, 1)
    snapshot:SetText(date(addon.db.global.settings.dateFormat, selectedSnapshot))
    reviewPanel:AddChild(snapshot)
    children.tabTitle = snapshot

    ------------------------------------------------------------

    local totalMoney = AceGUI:Create("Label")
    totalMoney:SetFullWidth(true)
    totalMoney:SetFontObject(GameFontNormal)
    totalMoney:SetText(GetCoinTextureString(scan.totalMoney))
    reviewPanel:AddChild(totalMoney)

    ------------------------------------------------------------

    local tabTitle = AceGUI:Create("Label")
    tabTitle:SetFullWidth(true)
    tabTitle:SetText(GetTabName(selectedGuild, selectedTab))
    reviewPanel:AddChild(tabTitle)
    children.tabTitle = tabTitle

    ------------------------------------------------------------

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(GetTabList())
    reviewPanel:AddChild(tabGroup)
    children.tabGroup = tabGroup

    tabGroup:SetCallback("OnGroupSelected", tabGroup_OnGroupSelected)

    ------------------------------------------------------------

    local tabPanel = AceGUI:Create("ScrollFrame")
    tabPanel:SetLayout("List")
    tabGroup:AddChild(tabPanel)
    children.tabPanel = tabPanel

    ------------------------------------------------------------

    ReviewFrame:LoadTransactions()
end