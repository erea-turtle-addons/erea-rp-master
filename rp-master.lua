-- ============================================================================
-- rp-master.lua - Main Entry Point for RPMaster Addon
-- ============================================================================
-- PURPOSE: Initialize addon, coordinate all subsystems, handle events
--
-- RESPONSIBILITIES:
--   - Initialize SavedVariables (RPMasterDB, RPMasterDebugLog)
--   - Register addon message prefix
--   - Set up VARIABLES_LOADED and PLAYER_ENTERING_WORLD events
--   - Initialize frame handlers (dragging, resizing)
--   - Initialize event handler (CHAT_MSG_ADDON)
--   - Initialize modules (create tabs, restore state)
--   - Register slash commands (/rpm, /rpm log, /rpm clearlog)
--   - Provide debug log viewer
--
-- DEPENDENCIES:
--   - RPMasterFrame (from views/main-frame.xml)
--   - RPMasterEventHandler (from services/event-handler.lua)
--   - Main frame functions (from presenters/main-frame.lua)
--   - Messaging module (from turtle-rp-common)
--
-- LOAD ORDER:
--   1. XML views loaded (defines RPMasterFrame)
--   2. Common modules loaded (RequireMessaging, RequireLogging, etc.)
--   3. Services loaded (RPMasterEventHandler)
--   4. Presenters loaded (main-frame functions)
--   5. THIS FILE loaded (initializes everything)
--   6. Feature modules loaded (ItemLibrary, Monitor, etc.)
--   7. VARIABLES_LOADED event → Initialize database
--   8. PLAYER_ENTERING_WORLD → Initialize modules and tabs
-- ============================================================================

-- ============================================================================
-- IMPORTS
-- ============================================================================
local messaging = EreaRpLibraries:Messaging()
local Log = EreaRpLibraries:Logging("RPMaster")

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local ADDON_NAME = "RPMaster"
-- Version info from version.lua (loaded first in .toc)
local ADDON_VERSION = (RP_VERSION_TAG and RP_VERSION_TAG ~= "0.0.0") and RP_VERSION_TAG or (RP_BUILD_TIME or "unknown")

-- ============================================================================
-- STARTUP MESSAGE
-- ============================================================================
DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[RP Master] Version: " .. ADDON_VERSION)
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[RP Master] Commands: /rpm, /rpm log")

Log("[RP Master] Version: " .. ADDON_VERSION)
Log("[RP Master] Commands: /rpm, /rpm log")

-- ============================================================================
-- INITIALIZE SAVEDVARIABLES
-- ============================================================================
RPMasterDebugLog = RPMasterDebugLog or {}

-- ============================================================================
-- REGISTER ADDON MESSAGE PREFIX
-- ============================================================================
-- NOTE: RegisterAddonMessagePrefix doesn't exist in WoW 1.12
-- In Vanilla, addon messages work without explicit prefix registration
-- This function was added in later expansions (TBC+)
-- Log("Addon message prefix: " .. messaging.ADDON_PREFIX)

-- ============================================================================
-- DEBUG LOG VIEWER
-- ============================================================================
-- Create debug log viewer frame
local logFrame = CreateFrame("Frame", "RPMasterLogFrame", UIParent)
logFrame:SetWidth(600)
logFrame:SetHeight(400)
logFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
logFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
logFrame:SetBackdropColor(0, 0, 0, 1)
logFrame:SetMovable(true)
logFrame:EnableMouse(true)
logFrame:SetFrameStrata("DIALOG")
logFrame:Hide()

local logTitle = logFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
logTitle:SetPoint("TOP", 0, -15)
logTitle:SetText("RPMaster Debug Log")

-- Draggable title bar
local logTitleBar = CreateFrame("Frame", nil, logFrame)
logTitleBar:SetPoint("TOPLEFT", 10, -10)
logTitleBar:SetPoint("TOPRIGHT", -30, -10)
logTitleBar:SetHeight(30)
logTitleBar:EnableMouse(true)
logTitleBar:RegisterForDrag("LeftButton")
logTitleBar:SetScript("OnDragStart", function() logFrame:StartMoving() end)
logTitleBar:SetScript("OnDragStop", function() logFrame:StopMovingOrSizing() end)

local logCloseBtn = CreateFrame("Button", nil, logFrame, "UIPanelCloseButton")
logCloseBtn:SetPoint("TOPRIGHT", -5, -5)

-- Scrollable log area with EditBox
local logScrollFrame = CreateFrame("ScrollFrame", "RPMasterLogScrollFrame", logFrame, "UIPanelScrollFrameTemplate")
logScrollFrame:SetPoint("TOPLEFT", 20, -50)
logScrollFrame:SetPoint("BOTTOMRIGHT", -40, 50)

local logEditBox = CreateFrame("EditBox", nil, logScrollFrame)
logEditBox:SetWidth(520)
logEditBox:SetHeight(1)
logEditBox:SetMultiLine(true)
logEditBox:SetAutoFocus(false)
logEditBox:SetFontObject(GameFontNormalSmall)
logEditBox:SetTextColor(1, 1, 1, 1)
logEditBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)

logScrollFrame:SetScrollChild(logEditBox)

-- Clear button
local clearBtn = CreateFrame("Button", nil, logFrame, "UIPanelButtonTemplate")
clearBtn:SetWidth(80)
clearBtn:SetHeight(22)
clearBtn:SetPoint("BOTTOM", logFrame, "BOTTOM", 0, 15)
clearBtn:SetText("Clear Log")
clearBtn:SetScript("OnClick", function()
    RPMasterDebugLog = {}
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RPMaster]|r Debug log cleared")
    logFrame:Hide()
end)

-- RPM_ShowLog - Show debug log viewer
function RPM_ShowLog()
    if table.getn(RPMasterDebugLog) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[RPMaster]|r Debug log is empty")
        return
    end

    local logContent = table.concat(RPMasterDebugLog, "\n")
    logEditBox:SetText(logContent)
    logEditBox:HighlightText()

    -- Calculate height needed for all text
    local numLines = table.getn(RPMasterDebugLog)
    local lineHeight = 14
    local totalHeight = numLines * lineHeight + 20
    logEditBox:SetHeight(totalHeight)

    logFrame:Show()
    logEditBox:SetFocus()
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================
SLASH_RPMASTER1 = "/rpmaster"
SLASH_RPMASTER2 = "/rpm"
SlashCmdList["RPMASTER"] = function(msg)
    if msg == "log" then
        RPM_ShowLog()
        return
    end

    if msg == "clearlog" then
        RPMasterDebugLog = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RPMaster]|r Debug log cleared")
        return
    end

    RPM_ToggleMainFrame()
end

Log("Slash commands registered")

-- ============================================================================
-- EVENT HANDLER: VARIABLES_LOADED & PLAYER_ENTERING_WORLD
-- ============================================================================
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("VARIABLES_LOADED")
loadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local variablesLoaded = false

loadFrame:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" then
        Log("VARIABLES_LOADED event fired")

        -- Initialize RPMasterDB
        RPMasterDB = RPMasterDB or {
            itemLibrary = {},
            nextItemID = 1,
            preferences = {
                detachedTabs = {items = false, states = false, monitor = false},
                windowPositions = {main = nil, items = nil, states = nil, monitor = nil},
                activeTab = "items"
            }
        }

        -- Ensure preferences structure exists (backward compatibility)
        if not RPMasterDB.preferences then
            RPMasterDB.preferences = {
                detachedTabs = {items = false, states = false, monitor = false},
                windowPositions = {main = nil, items = nil, states = nil, monitor = nil},
                activeTab = "items"
            }
        end

        -- Ensure detachedTabs exists
        if not RPMasterDB.preferences.detachedTabs then
            RPMasterDB.preferences.detachedTabs = {items = false, states = false, monitor = false}
        end

        -- Ensure windowPositions exists
        if not RPMasterDB.preferences.windowPositions then
            RPMasterDB.preferences.windowPositions = {main = nil, items = nil, states = nil, monitor = nil}
        end

        Log("RPMasterDB initialized")

        -- Load saved main frame position
        if RPMasterDB.preferences.windowPositions.main then
            local pos = RPMasterDB.preferences.windowPositions.main
            RPMasterFrame:ClearAllPoints()
            RPMasterFrame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
            Log("Loaded saved window position")
        end

        -- Load saved window size if available
        if RPMasterDB.preferences.windowSize then
            local width, height = unpack(RPMasterDB.preferences.windowSize)
            RPMasterFrame:SetWidth(width)
            RPMasterFrame:SetHeight(height)
            Log("Loaded saved window size")
        end

        variablesLoaded = true
        self:UnregisterEvent("VARIABLES_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not variablesLoaded then
            return
        end

        Log("PLAYER_ENTERING_WORLD event fired")
        Log("[RP Master] Version: " .. ADDON_VERSION)
        Log("[RP Master] Commands: /rpm, /rpm log")

        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[RPMaster] Version: " .. ADDON_VERSION .. "|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[RPMaster]|r Commands: /rpm, /rpm log", 0, 1, 1)

        -- Initialize frame handlers (dragging, resizing)
        RPM_InitializeFrameHandlers()
        Log("Frame handlers initialized")

        -- Initialize event handler (CHAT_MSG_ADDON)
        RPMasterEventHandler:Initialize()
        Log("Event handler initialized")

        -- Initialize modules after short delay to ensure all files loaded
        loadFrame.timer = 0
        loadFrame:SetScript("OnUpdate", function(self, elapsed)
            self.timer = self.timer + elapsed
            if self.timer >= 0.5 then
                RPM_InitializeModules()
                self:SetScript("OnUpdate", nil)
                Log("Initialization complete")
            end
        end)

        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

Log("rp-master.lua loaded")
