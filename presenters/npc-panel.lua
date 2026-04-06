-- ============================================================================
-- npc-panel.lua - EreaRpMasterNpcPanelFrame Controller
-- ============================================================================
-- UI Structure: views/npc-panel.xml (v1.1.8)
-- Frame: EreaRpMasterNpcPanelFrame (defined in XML)
--
-- PURPOSE: Manages the NPCs tab: NPC list with live status, quick line
--          commands, chat history/relay, and event script management.
--
-- METHODS:
--   Initialize()          - Setup frame references, OnShow hook
--   RefreshList()         - Rebuild NPC rows from npc-library
--   GetOrCreateRow(i)     - Row pool factory (status dot + name + remove button)
--   SelectNpc(name)       - Set active NPC target, re-render list
--   SendQuickLine(type)   - Send a single say/yell/emote to selected NPC
--   InitEventDropdown()   - Setup event selector dropdown
--   CreateNewEvent()      - Create a new event
--   DeleteActiveEvent()   - Delete the active event
--   AddEventLine()        - Add a cue line to the active event
--   RemoveEventLine()     - Remove the selected cue line
--   ExecuteCueLine(i)     - Execute a single cue line
--   RefreshEventPanel()   - Rebuild cue line rows from active event
--   GetOrCreateCueRow(i)  - Row pool factory for cue line rows
--   AddHistory()          - Log outgoing command to history
--   AddRelayedChat()      - Log incoming NPC chat to history
-- ============================================================================

-- ============================================================================
-- IMPORTS
-- ============================================================================
local messaging = EreaRpLibraries:Messaging()
local Log = EreaRpLibraries:Logging("EreaRpMaster")

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local ROW_HEIGHT       = 26
local CUE_ROW_HEIGHT   = 26
local NPC_DD_WIDTH     = 100
local ACTION_DD_WIDTH  = 70

-- ============================================================================
-- STATE
-- ============================================================================
EreaRpMasterNpcPanelFrame.selectedNpc     = nil
EreaRpMasterNpcPanelFrame.rowFrames       = {}
EreaRpMasterNpcPanelFrame.cueRowFrames    = {}
EreaRpMasterNpcPanelFrame.selectedCueLine = nil
EreaRpMasterNpcPanelFrame.historyBuffer   = {}
EreaRpMasterNpcPanelFrame.tagPillFrames   = {}

local MAX_HISTORY_ENTRIES = 200

-- ============================================================================
-- Initialize()
-- ============================================================================
function EreaRpMasterNpcPanelFrame:Initialize()
    self.scrollFrame      = EreaRpMasterNpcPanelScrollFrame
    self.scrollChild      = EreaRpMasterNpcPanelScrollFrameScrollChild
    self.quickInput       = EreaRpMasterNpcPanelQuickLineInput
    self.statusText       = EreaRpMasterNpcPanelStatusText
    self.historyFrame     = EreaRpMasterNpcHistoryFrame
    self.eventScroll      = EreaRpMasterNpcEventScroll
    self.eventScrollChild = EreaRpMasterNpcEventScrollScrollChild

    -- Rebuild cue rows when scroll frame resizes
    self.eventScroll:SetScript("OnSizeChanged", function()
        EreaRpMasterNpcPanelFrame:RefreshEventPanel()
    end)

    self.eventSection     = EreaRpMasterNpcPanelFrameRightPanelEventSection
    self.eventDropdown    = EreaRpMasterNpcEventDropdown
    self.eventNameInput   = EreaRpMasterNpcEventNameInput
    self.rowFrames        = {}
    self.cueRowFrames     = {}
    self.tagPillFrames    = {}
    self.selectedNpc      = nil
    self.selectedCueLine  = nil

    -- Tag UI references
    self.tagPillContainer = EreaRpMasterNpcTagPillContainer
    self.tagDropdown      = EreaRpMasterNpcTagDropdown
    self.tagInput         = EreaRpMasterNpcTagInput

    self:SetScript("OnShow", function()
        EreaRpMasterNpcPanelFrame:RefreshList()
        EreaRpMasterNpcPanelFrame:RefreshEventPanel()
        EreaRpMasterNpcPanelFrame:RefreshTagPills()
        EreaRpMasterNpcPanelFrame:InitTagDropdown()
        -- Trigger a status request to get live NPC statuses
        EreaRpMasterPlayerMonitorFrame:SendStatusRequest()
    end)

    -- Initialize event dropdown
    self:InitEventDropdown()

    -- Initialize tag dropdown
    self:InitTagDropdown()

    Log("EreaRpMasterNpcPanelFrame initialized")
end

-- ============================================================================
-- RefreshList() - Rebuild all NPC rows from the library
-- ============================================================================
function EreaRpMasterNpcPanelFrame:RefreshList()
    local npcs  = EreaRpMasterNpcLibrary:GetAllNpcs()
    local count = table.getn(npcs)

    -- Use left panel width minus border insets (6) and scrollbar (20)
    local panelWidth = EreaRpMasterNpcPanelFrameLeftPanel:GetWidth() or 200
    local childWidth = panelWidth - 30
    self.scrollChild:SetWidth(childWidth)

    -- Hide all pooled rows
    for i = 1, table.getn(self.rowFrames) do
        self.rowFrames[i]:Hide()
    end

    for i = 1, count do
        local entry = npcs[i]
        local row   = self:GetOrCreateRow(i)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        row:SetWidth(childWidth)
        row:SetHeight(ROW_HEIGHT)
        row.playerName = entry.name

        -- Tri-state status dot
        if entry.online and entry.hasNpcAddon then
            row.dot:SetVertexColor(0.2, 0.8, 0.2)   -- Green: online + NPC addon
        elseif entry.online then
            row.dot:SetVertexColor(1.0, 0.6, 0.0)   -- Orange: online, no NPC addon
        else
            row.dot:SetVertexColor(0.5, 0.5, 0.5)   -- Gray: offline
        end

        row.nameText:SetText(entry.name)

        -- Selection highlight
        if self.selectedNpc == entry.name then
            row:SetBackdropColor(0.2, 0.2, 0.4, 1)
            row:SetBackdropBorderColor(0.6, 0.6, 1.0, 1)
        else
            row:SetBackdropColor(0.08, 0.08, 0.1, 0.6)
            row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end

        row:Show()
    end

    -- Update scroll child height
    local totalHeight = count * ROW_HEIGHT
    if totalHeight < 1 then totalHeight = 1 end
    self.scrollChild:SetHeight(totalHeight)
    self.scrollFrame:UpdateScrollChildRect()

    -- Update status text with online count
    if self.statusText then
        local onlineCount = 0
        for i = 1, count do
            if npcs[i].online then onlineCount = onlineCount + 1 end
        end
        self.statusText:SetText(onlineCount .. "/" .. count .. " online")
    end
end

-- ============================================================================
-- GetOrCreateRow() - Return or create a reusable row frame
-- ============================================================================
function EreaRpMasterNpcPanelFrame:GetOrCreateRow(index)
    if self.rowFrames[index] then return self.rowFrames[index] end

    local frameName = "EreaRpMasterNpcPanelRow" .. index
    local row = CreateFrame("Button", frameName, self.scrollChild)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    row:SetBackdropColor(0.08, 0.08, 0.1, 0.6)
    row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Online dot
    local dot = row:CreateTexture(frameName .. "Dot", "ARTWORK")
    dot:SetWidth(8)
    dot:SetHeight(8)
    dot:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    dot:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.dot = dot

    -- Remove button (X)
    local removeBtn = CreateFrame("Button", frameName .. "Remove", row)
    removeBtn:SetWidth(16)
    removeBtn:SetHeight(16)
    removeBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    removeBtn:SetNormalTexture("Interface\\BUTTONS\\UI-GroupLoot-Pass-Up")
    removeBtn:SetHighlightTexture("Interface\\BUTTONS\\UI-GroupLoot-Pass-Highlight")
    removeBtn:SetScript("OnClick", function()
        local rowRef = this:GetParent()
        EreaRpMasterNpcLibrary:RemoveNpc(rowRef.playerName)
        if EreaRpMasterNpcPanelFrame.selectedNpc == rowRef.playerName then
            EreaRpMasterNpcPanelFrame.selectedNpc = nil
        end
        EreaRpMasterNpcPanelFrame:RefreshList()
    end)
    row.removeBtn = removeBtn

    -- Name text
    local nameText = row:CreateFontString(frameName .. "Name", "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", dot, "RIGHT", 5, 0)
    nameText:SetPoint("RIGHT", removeBtn, "LEFT", -2, 0)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    -- Row click selects this NPC
    row:SetScript("OnClick", function()
        local clickedRow = this
        EreaRpMasterNpcPanelFrame:SelectNpc(clickedRow.playerName)
    end)

    -- Hover effect + tooltip
    row:SetScript("OnEnter", function()
        if EreaRpMasterNpcPanelFrame.selectedNpc ~= this.playerName then
            this:SetBackdropColor(0.12, 0.12, 0.18, 0.8)
        end
        local npcEntry = EreaRpMasterNpcLibrary:GetNpc(this.playerName)
        if npcEntry then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            if npcEntry.online and npcEntry.hasNpcAddon then
                GameTooltip:AddLine("Online - NPC addon active", 0.2, 0.8, 0.2)
            elseif npcEntry.online then
                GameTooltip:AddLine("Online - NPC addon NOT active", 1, 0.6, 0)
            else
                GameTooltip:AddLine("Offline", 0.5, 0.5, 0.5)
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        if EreaRpMasterNpcPanelFrame.selectedNpc ~= this.playerName then
            this:SetBackdropColor(0.08, 0.08, 0.1, 0.6)
        end
        GameTooltip:Hide()
    end)

    self.rowFrames[index] = row
    return row
end

-- ============================================================================
-- SelectNpc() - Set the active NPC target
-- ============================================================================
function EreaRpMasterNpcPanelFrame:SelectNpc(playerName)
    self.selectedNpc = playerName
    self:RefreshList()
    self:RefreshHistory()
    self:RefreshTagPills()
    self:InitTagDropdown()
    Log("NpcPanel: selected " .. tostring(playerName))
end

-- ============================================================================
-- RefreshNpcStatus() - Trigger a status request to update NPC statuses
-- ============================================================================
function EreaRpMasterNpcPanelFrame:RefreshNpcStatus()
    EreaRpMasterPlayerMonitorFrame:SendStatusRequest()
    Log("NpcPanel: manual status refresh triggered")
end

-- ============================================================================
-- SendQuickLine() - Send a single say/yell/emote to the selected NPC
-- ============================================================================
function EreaRpMasterNpcPanelFrame:SendQuickLine(cmdType)
    if not self.selectedNpc or self.selectedNpc == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[RP Master]|r Select an NPC first.")
        return
    end
    local text = self.quickInput:GetText()
    if not text or text == "" then return end

    messaging.SendNpcCmdMessage(self.selectedNpc, cmdType, text)
    self:AddHistory(cmdType, text)
    self.quickInput:SetText("")
    Log("NpcPanel: sent " .. cmdType .. " to " .. self.selectedNpc)
end

-- ============================================================================
-- EVENT SCRIPT SYSTEM
-- ============================================================================

-- ----------------------------------------------------------------------------
-- InitEventDropdown() - Setup the event selector dropdown
-- ----------------------------------------------------------------------------
local NEW_EVENT_VALUE = "__new__"

function EreaRpMasterNpcPanelFrame:InitEventDropdown()
    local dd = self.eventDropdown
    UIDropDownMenu_SetWidth(120, dd)

    UIDropDownMenu_Initialize(dd, function()
        if not EreaRpMasterDB or not EreaRpMasterDB.events then return end

        -- Existing events
        for eventId, ev in pairs(EreaRpMasterDB.events) do
            local info = {}
            info.text  = ev.name or eventId
            info.value = eventId
            do
                local id   = eventId
                local name = ev.name or eventId
                info.func  = function()
                    UIDropDownMenu_SetSelectedValue(dd, id)
                    UIDropDownMenu_SetText(name, dd)
                    EreaRpMasterDB.activeEventId = id
                    EreaRpMasterNpcPanelFrame:RefreshEventPanel()
                end
            end
            UIDropDownMenu_AddButton(info)
        end

        -- Separator-style "-- New Event --" entry
        local newInfo = {}
        newInfo.text  = "-- New Event --"
        newInfo.value = NEW_EVENT_VALUE
        newInfo.func  = function()
            EreaRpMasterNpcPanelFrame:CreateNewEvent()
        end
        UIDropDownMenu_AddButton(newInfo)
    end)

    -- Restore active event
    local activeId = EreaRpMasterDB and EreaRpMasterDB.activeEventId
    if activeId and EreaRpMasterDB.events and EreaRpMasterDB.events[activeId] then
        local ev = EreaRpMasterDB.events[activeId]
        UIDropDownMenu_SetSelectedValue(dd, activeId)
        UIDropDownMenu_SetText(ev.name or activeId, dd)
    else
        UIDropDownMenu_SetText("-- New Event --", dd)
    end
end

-- ----------------------------------------------------------------------------
-- GetActiveEvent() - Return the active event table or nil
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:GetActiveEvent()
    if not EreaRpMasterDB or not EreaRpMasterDB.events then return nil end
    local id = EreaRpMasterDB.activeEventId
    if not id then return nil end
    return EreaRpMasterDB.events[id]
end

-- ----------------------------------------------------------------------------
-- CreateNewEvent() - Create a blank new event and activate it
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:CreateNewEvent()
    if not EreaRpMasterDB then return end

    local eventId = "evt_" .. tostring(time()) .. "_" .. tostring(math.random(1000, 9999))
    EreaRpMasterDB.events[eventId] = {
        name  = "",
        lines = {}
    }
    EreaRpMasterDB.activeEventId = eventId

    self:RefreshEventPanel()
    -- Focus the name input so user can type immediately
    if self.eventNameInput then
        self.eventNameInput:SetFocus()
    end
    -- Update dropdown to show blank (unsaved)
    UIDropDownMenu_SetSelectedValue(self.eventDropdown, eventId)
    UIDropDownMenu_SetText("(unsaved)", self.eventDropdown)
    Log("NpcPanel: created new event " .. eventId)
end

-- ----------------------------------------------------------------------------
-- SaveActiveEvent() - Save event name from editbox and refresh dropdown
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:SaveActiveEvent()
    local ev = self:GetActiveEvent()
    if not ev then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[RP Master]|r No active event to save.")
        return
    end
    if not self.eventNameInput then return end

    local name = self.eventNameInput:GetText() or ""
    if name == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[RP Master]|r Enter an event name first.")
        return
    end
    ev.name = name

    -- Refresh dropdown to show updated name
    self:InitEventDropdown()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[RP Master]|r Event saved: " .. name)
    Log("NpcPanel: saved event " .. tostring(EreaRpMasterDB.activeEventId) .. " as \"" .. name .. "\"")
end

-- ----------------------------------------------------------------------------
-- DeleteActiveEvent() - Delete the currently active event
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:DeleteActiveEvent()
    if not EreaRpMasterDB or not EreaRpMasterDB.activeEventId then return end
    local id = EreaRpMasterDB.activeEventId
    EreaRpMasterDB.events[id] = nil
    EreaRpMasterDB.activeEventId = nil

    self:InitEventDropdown()
    self:RefreshEventPanel()
    Log("NpcPanel: deleted event " .. id)
end

-- ----------------------------------------------------------------------------
-- OnEventNameChanged() - Live-update event name (no auto-save to dropdown)
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:OnEventNameChanged()
    local ev = self:GetActiveEvent()
    if not ev or not self.eventNameInput then return end
    ev.name = self.eventNameInput:GetText() or ""
end

-- ----------------------------------------------------------------------------
-- AddEventLine() - Add a new cue line to the active event
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:AddEventLine()
    local ev = self:GetActiveEvent()
    if not ev then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[RP Master]|r Create or select an event first.")
        return
    end
    table.insert(ev.lines, { npc = "", action = "say", content = "" })
    self:RefreshEventPanel()
end

-- ----------------------------------------------------------------------------
-- RemoveEventLine() - Remove the selected cue line
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:RemoveEventLine()
    local ev = self:GetActiveEvent()
    if not ev or not self.selectedCueLine then return end
    if self.selectedCueLine > table.getn(ev.lines) then return end  -- Lua 5.0: no # operator
    table.remove(ev.lines, self.selectedCueLine)
    self.selectedCueLine = nil
    self:RefreshEventPanel()
end

-- ----------------------------------------------------------------------------
-- ExecuteCueLine() - Execute a single cue line
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:ExecuteCueLine(lineIndex)
    local ev = self:GetActiveEvent()
    if not ev then return end
    local line = ev.lines[lineIndex]
    if not line then return end

    local npcName = line.npc or ""
    local action  = line.action or "say"
    local content = line.content or ""

    if npcName == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[RP Master]|r No NPC set for line " .. lineIndex)
        return
    end

    messaging.SendNpcCmdMessage(npcName, action, content)
    self:AddHistoryForNpc(npcName, action, content)
    Log("NpcPanel: executed cue line " .. lineIndex .. " -> " .. npcName)
end

-- ----------------------------------------------------------------------------
-- AddHistoryForNpc() - Add history entry for a specific NPC (not selectedNpc)
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:AddHistoryForNpc(npcName, cmdType, text)
    if not self.historyFrame then return end
    local c = HISTORY_COLORS[cmdType] or { r = 0.7, g = 0.7, b = 0.7 }
    local line
    if cmdType == "emote" then
        line = npcName .. " " .. (text or "")
    elseif cmdType == "yell" then
        line = "[" .. npcName .. "] yells: " .. (text or "")
    else
        line = "[" .. npcName .. "] says: " .. (text or "")
    end
    self.historyFrame:AddMessage(line, c.r, c.g, c.b)
end

-- ----------------------------------------------------------------------------
-- RefreshEventPanel() - Rebuild cue line rows from the active event
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:RefreshEventPanel()
    local ev = self:GetActiveEvent()

    -- Sync event name EditBox
    if self.eventNameInput then
        if ev then
            self.eventNameInput:SetText(ev.name or "")
            self.eventNameInput:EnableMouse(true)
        else
            self.eventNameInput:SetText("")
            self.eventNameInput:EnableMouse(false)
        end
    end

    -- Hide all pooled cue rows
    for i = 1, table.getn(self.cueRowFrames) do  -- Lua 5.0: no # operator
        self.cueRowFrames[i]:Hide()
    end

    if not ev then
        if self.eventScrollChild then
            self.eventScrollChild:SetHeight(1)
            self.eventScroll:UpdateScrollChildRect()
        end
        return
    end

    local count = table.getn(ev.lines)  -- Lua 5.0: no # operator
    local childWidth = EreaRpMasterMainWindow:GetWidth() - 241 - 12 - 16
    if self.eventScrollChild then
        self.eventScrollChild:SetWidth(childWidth)
    end

    for i = 1, count do
        local lineData = ev.lines[i]
        local row = self:GetOrCreateCueRow(i)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.eventScrollChild, "TOPLEFT", 0, -((i - 1) * CUE_ROW_HEIGHT))
        row:SetWidth(childWidth)
        row:SetHeight(CUE_ROW_HEIGHT)
        row.lineIndex = i

        -- Update NPC dropdown text
        UIDropDownMenu_SetText(lineData.npc ~= "" and lineData.npc or "(NPC)", row.npcDropdown)

        -- Update action dropdown text
        local actionLabel = string.upper(string.sub(lineData.action, 1, 1)) .. string.sub(lineData.action, 2)
        UIDropDownMenu_SetText(actionLabel, row.actionDropdown)

        -- Update content editbox
        row.contentBox:SetText(lineData.content or "")

        -- Selection highlight
        if self.selectedCueLine == i then
            row:SetBackdropColor(0.15, 0.15, 0.3, 0.8)
        else
            row:SetBackdropColor(0.06, 0.06, 0.08, 0.6)
        end

        row:Show()
    end

    -- Update scroll child height
    local totalHeight = count * CUE_ROW_HEIGHT
    if totalHeight < 1 then totalHeight = 1 end
    if self.eventScrollChild then
        self.eventScrollChild:SetHeight(totalHeight)
        self.eventScroll:UpdateScrollChildRect()
    end
end

-- ----------------------------------------------------------------------------
-- GetOrCreateCueRow() - Row pool factory for cue line rows
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:GetOrCreateCueRow(index)
    if self.cueRowFrames[index] then return self.cueRowFrames[index] end

    local frameName = "EreaRpMasterNpcCueRow" .. index
    local row = CreateFrame("Frame", frameName, self.eventScrollChild)
    row:SetHeight(CUE_ROW_HEIGHT)
    row:EnableMouse(true)
    row:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 16
    })
    row:SetBackdropColor(0.06, 0.06, 0.08, 0.6)
    row.lineIndex = index

    -- NPC dropdown
    local npcDd = CreateFrame("Frame", frameName .. "NpcDd", row, "UIDropDownMenuTemplate")
    npcDd:SetPoint("LEFT", row, "LEFT", -14, 0)
    UIDropDownMenu_SetWidth(NPC_DD_WIDTH, npcDd)
    do
        local idx = index
        UIDropDownMenu_Initialize(npcDd, function()
            local npcs = EreaRpMasterNpcLibrary:GetAllNpcs()
            for n = 1, table.getn(npcs) do  -- Lua 5.0: no # operator
                local info = {}
                info.text  = npcs[n].name
                info.value = npcs[n].name
                do
                    local npcName = npcs[n].name
                    info.func = function()
                        UIDropDownMenu_SetText(npcName, npcDd)
                        local ev = EreaRpMasterNpcPanelFrame:GetActiveEvent()
                        if ev and ev.lines[idx] then
                            ev.lines[idx].npc = npcName
                        end
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    row.npcDropdown = npcDd

    -- Action dropdown
    local actionDd = CreateFrame("Frame", frameName .. "ActionDd", row, "UIDropDownMenuTemplate")
    actionDd:SetPoint("LEFT", npcDd, "RIGHT", -30, 0)
    UIDropDownMenu_SetWidth(ACTION_DD_WIDTH, actionDd)
    do
        local idx = index
        UIDropDownMenu_Initialize(actionDd, function()
            local actions = { "say", "yell", "emote" }
            for a = 1, 3 do
                local info = {}
                local label = string.upper(string.sub(actions[a], 1, 1)) .. string.sub(actions[a], 2)
                info.text  = label
                info.value = actions[a]
                do
                    local act = actions[a]
                    local lbl = label
                    info.func = function()
                        UIDropDownMenu_SetText(lbl, actionDd)
                        local ev = EreaRpMasterNpcPanelFrame:GetActiveEvent()
                        if ev and ev.lines[idx] then
                            ev.lines[idx].action = act
                        end
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    row.actionDropdown = actionDd

    -- Content editbox
    local contentBox = CreateFrame("EditBox", frameName .. "Content", row)
    contentBox:SetHeight(20)
    contentBox:SetPoint("LEFT", actionDd, "RIGHT", -15, 2)
    contentBox:SetPoint("RIGHT", row, "RIGHT", -30, 2)
    contentBox:SetAutoFocus(false)
    contentBox:SetFontObject(ChatFontNormal)
    contentBox:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    contentBox:SetBackdropColor(0.1, 0.1, 0.1, 1)
    contentBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    contentBox:SetTextInsets(4, 4, 0, 0)
    contentBox:SetMaxLetters(255)
    do
        local idx = index
        contentBox:SetScript("OnTextChanged", function()
            local ev = EreaRpMasterNpcPanelFrame:GetActiveEvent()
            if ev and ev.lines[idx] then
                ev.lines[idx].content = this:GetText() or ""
            end
        end)
    end
    contentBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    row.contentBox = contentBox

    -- Execute button
    local execBtn = CreateFrame("Button", frameName .. "Exec", row, "UIPanelButtonTemplate")
    execBtn:SetWidth(22)
    execBtn:SetHeight(22)
    execBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    execBtn:SetText(">")
    do
        local idx = index
        execBtn:SetScript("OnClick", function()
            EreaRpMasterNpcPanelFrame:ExecuteCueLine(idx)
        end)
    end
    row.execBtn = execBtn

    -- Click to select row
    row:SetScript("OnMouseDown", function()
        EreaRpMasterNpcPanelFrame.selectedCueLine = this.lineIndex
        EreaRpMasterNpcPanelFrame:RefreshEventPanel()
    end)

    self.cueRowFrames[index] = row
    return row
end

-- ============================================================================
-- TAG MANAGEMENT SYSTEM
-- ============================================================================

local TAG_PILL_HEIGHT     = 20
local TAG_PILL_PADDING    = 4
local TAG_PILL_X_BTN_SIZE = 16

-- ----------------------------------------------------------------------------
-- InitTagDropdown() - Populate the tag dropdown with all known unique tags
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:InitTagDropdown()
    local dd = self.tagDropdown
    if not dd then return end
    UIDropDownMenu_SetWidth(120, dd)

    UIDropDownMenu_Initialize(dd, function()
        local allTags = EreaRpMasterNpcLibrary:GetAllUniqueTags()
        for i = 1, table.getn(allTags) do  -- Lua 5.0: no # operator
            local info = {}
            info.text  = allTags[i]
            info.value = allTags[i]
            do
                local tagVal = allTags[i]
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(dd, tagVal)
                    UIDropDownMenu_SetText(tagVal, dd)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    UIDropDownMenu_SetText("Select tag...", dd)
end

-- ----------------------------------------------------------------------------
-- AddTagFromInput() - Add a tag from editbox or dropdown selection
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:AddTagFromInput()
    if not self.selectedNpc then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[RP Master]|r Select an NPC first.")
        return
    end

    -- Prefer editbox text; fall back to dropdown selection
    local tag = ""
    if self.tagInput then
        tag = self.tagInput:GetText() or ""
    end
    if tag == "" then
        tag = UIDropDownMenu_GetSelectedValue(self.tagDropdown) or ""
    end
    if tag == "" then return end

    EreaRpMasterNpcLibrary:AddTag(self.selectedNpc, tag)

    -- Clear input and refresh
    if self.tagInput then
        self.tagInput:SetText("")
        self.tagInput:ClearFocus()
    end
    UIDropDownMenu_SetText("Select tag...", self.tagDropdown)

    self:RefreshTagPills()
    self:InitTagDropdown()
end

-- ----------------------------------------------------------------------------
-- RemoveTagFromNpc() - Remove a tag and refresh the UI
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:RemoveTagFromNpc(tag)
    if not self.selectedNpc then return end
    EreaRpMasterNpcLibrary:RemoveTag(self.selectedNpc, tag)
    self:RefreshTagPills()
    self:InitTagDropdown()
end

-- ----------------------------------------------------------------------------
-- RefreshTagPills() - Rebuild tag pill display for the selected NPC
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:RefreshTagPills()
    -- Hide all existing pills
    for i = 1, table.getn(self.tagPillFrames) do  -- Lua 5.0: no # operator
        self.tagPillFrames[i]:Hide()
    end

    local hasSelection = (self.selectedNpc ~= nil)

    -- Enable/disable tag controls based on selection
    if self.tagInput then
        self.tagInput:EnableMouse(hasSelection)
        if not hasSelection then self.tagInput:SetText("") end
    end
    if self.tagDropdown then
        -- UIDropDownMenu doesn't have native disable; use EnableMouse on the button
        local btn = getglobal(self.tagDropdown:GetName() .. "Button")
        if btn then btn:EnableMouse(hasSelection) end
    end
    local addBtn = EreaRpMasterNpcTagAddButton
    if addBtn then
        if hasSelection then addBtn:Enable() else addBtn:Disable() end
    end

    if not hasSelection then return end

    local tags = EreaRpMasterNpcLibrary:GetTags(self.selectedNpc)
    local container = self.tagPillContainer
    if not container then return end

    local containerWidth = container:GetWidth() or 170
    local xPos = 0
    local yPos = 0

    for i = 1, table.getn(tags) do  -- Lua 5.0: no # operator
        local pill = self:GetOrCreateTagPill(i)
        local tag = tags[i]

        pill.label:SetText(tag)
        -- Measure text width with fallback
        local textWidth = pill.label:GetStringWidth() or 30
        if textWidth < 10 then textWidth = 30 end
        local pillWidth = textWidth + TAG_PILL_X_BTN_SIZE + 12

        -- Wrap to next row if needed
        if xPos + pillWidth > containerWidth and xPos > 0 then
            xPos = 0
            yPos = yPos - (TAG_PILL_HEIGHT + TAG_PILL_PADDING)
        end

        pill:ClearAllPoints()
        pill:SetPoint("TOPLEFT", container, "TOPLEFT", xPos, yPos)
        pill:SetWidth(pillWidth)
        pill:SetHeight(TAG_PILL_HEIGHT)

        -- Bind the remove handler with a closure over the tag value
        do
            local tagVal = tag
            pill.removeBtn:SetScript("OnClick", function()
                EreaRpMasterNpcPanelFrame:RemoveTagFromNpc(tagVal)
            end)
        end

        pill:Show()
        xPos = xPos + pillWidth + TAG_PILL_PADDING
    end
end

-- ----------------------------------------------------------------------------
-- GetOrCreateTagPill() - Pool factory for tag pill buttons
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:GetOrCreateTagPill(index)
    if self.tagPillFrames[index] then return self.tagPillFrames[index] end

    local frameName = "EreaRpMasterNpcTagPill" .. index
    local pill = CreateFrame("Button", frameName, self.tagPillContainer)
    pill:SetHeight(TAG_PILL_HEIGHT)
    pill:EnableMouse(true)
    pill:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    pill:SetBackdropColor(0.15, 0.15, 0.25, 1)
    pill:SetBackdropBorderColor(0.5, 0.5, 0.7, 1)

    -- Tag text label
    local label = pill:CreateFontString(frameName .. "Label", "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", pill, "LEFT", 4, 0)
    label:SetPoint("RIGHT", pill, "RIGHT", -TAG_PILL_X_BTN_SIZE - 2, 0)
    label:SetJustifyH("LEFT")
    pill.label = label

    -- Remove button (X)
    local removeBtn = CreateFrame("Button", frameName .. "Remove", pill)
    removeBtn:SetWidth(TAG_PILL_X_BTN_SIZE)
    removeBtn:SetHeight(TAG_PILL_X_BTN_SIZE)
    removeBtn:SetPoint("RIGHT", pill, "RIGHT", -2, 0)
    removeBtn:SetNormalTexture("Interface\\BUTTONS\\UI-GroupLoot-Pass-Up")
    removeBtn:SetHighlightTexture("Interface\\BUTTONS\\UI-GroupLoot-Pass-Highlight")
    pill.removeBtn = removeBtn

    self.tagPillFrames[index] = pill
    return pill
end

-- ============================================================================
-- HISTORY SYSTEM (filtered by selected NPC)
-- ============================================================================
local HISTORY_COLORS = {
    say   = { r = 1,   g = 1,   b = 1   },
    yell  = { r = 1,   g = 0.2, b = 0.2 },
    emote = { r = 1,   g = 0.5, b = 0.25 },
}

local RELAY_COLORS = {
    SAY   = { r = 0.6, g = 0.6, b = 0.6 },
    YELL  = { r = 0.7, g = 0.15, b = 0.15 },
    EMOTE = { r = 0.7, g = 0.35, b = 0.15 },
}

-- ----------------------------------------------------------------------------
-- BufferHistoryEntry() - Store an entry and display if it matches selection
-- ----------------------------------------------------------------------------
local function BufferHistoryEntry(self, npcName, text, r, g, b)
    table.insert(self.historyBuffer, {
        npc  = npcName,
        text = text,
        r = r, g = g, b = b
    })
    -- Trim buffer to max size
    while table.getn(self.historyBuffer) > MAX_HISTORY_ENTRIES do  -- Lua 5.0: no # operator
        table.remove(self.historyBuffer, 1)
    end
    -- Display only if matching selected NPC
    if self.historyFrame and self.selectedNpc == npcName then
        self.historyFrame:AddMessage(text, r, g, b)
    end
end

-- ----------------------------------------------------------------------------
-- FormatOutgoing() - Format an outgoing command line
-- ----------------------------------------------------------------------------
local function FormatOutgoing(npcName, cmdType, text)
    if cmdType == "emote" then
        return npcName .. " " .. (text or "")
    elseif cmdType == "yell" then
        return "[" .. npcName .. "] yells: " .. (text or "")
    else
        return "[" .. npcName .. "] says: " .. (text or "")
    end
end

-- ----------------------------------------------------------------------------
-- RefreshHistory() - Rebuild history display for the selected NPC
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:RefreshHistory()
    if not self.historyFrame then return end
    self.historyFrame:Clear()
    local selected = self.selectedNpc
    if not selected then return end
    for i = 1, table.getn(self.historyBuffer) do  -- Lua 5.0: no # operator
        local entry = self.historyBuffer[i]
        if entry.npc == selected then
            self.historyFrame:AddMessage(entry.text, entry.r, entry.g, entry.b)
        end
    end
end

-- ----------------------------------------------------------------------------
-- AddHistory() - Log outgoing command for the selected NPC
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:AddHistory(cmdType, text)
    local npc = self.selectedNpc or "Unknown"
    local c = HISTORY_COLORS[cmdType] or { r = 0.7, g = 0.7, b = 0.7 }
    local line = FormatOutgoing(npc, cmdType, text)
    BufferHistoryEntry(self, npc, line, c.r, c.g, c.b)
end

-- ----------------------------------------------------------------------------
-- AddHistoryForNpc() - Log outgoing command for a specific NPC (cue lines)
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:AddHistoryForNpc(npcName, cmdType, text)
    local c = HISTORY_COLORS[cmdType] or { r = 0.7, g = 0.7, b = 0.7 }
    local line = FormatOutgoing(npcName, cmdType, text)
    BufferHistoryEntry(self, npcName, line, c.r, c.g, c.b)
end

-- ----------------------------------------------------------------------------
-- AddRelayedChat() - Log incoming chat relayed from an NPC character
-- ----------------------------------------------------------------------------
function EreaRpMasterNpcPanelFrame:AddRelayedChat(npcName, chatType, speakerName, messageText)
    -- Skip when the NPC hears its own voice (already logged as outgoing)
    if npcName == speakerName then return end

    local c = RELAY_COLORS[chatType] or { r = 0.5, g = 0.5, b = 0.5 }
    local line
    if chatType == "EMOTE" then
        line = speakerName .. " " .. (messageText or "")
    elseif chatType == "YELL" then
        line = "[" .. speakerName .. "] yells: " .. (messageText or "")
    else
        line = "[" .. speakerName .. "] says: " .. (messageText or "")
    end
    BufferHistoryEntry(self, npcName, line, c.r, c.g, c.b)
end
