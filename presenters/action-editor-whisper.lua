-- ============================================================================
-- action-editor-whisper.lua - Whisper Player Editor Controller
-- ============================================================================
-- TEMPLATE: views/action-editor-whisper.xml
-- PURPOSE: Factory for Whisper Player method editor instances
-- INTERFACE:
--   EreaRpMasterWhisperEditor.Create(parent, params, methodIndex) -> frame
--   frame:GetParams() -> { text = string }
--   frame:SetParams(params)
-- ============================================================================

EreaRpMasterWhisperEditor = {}

local counter = 0

-- ============================================================================
-- Create - Create a new editor instance from virtual template
-- ============================================================================
-- @param parent: Parent frame to attach to
-- @param params: Parameter table with optional text field
-- @param methodIndex: Index of this method in the methods array
-- @returns: editor frame with GetParams/SetParams methods
-- ============================================================================
function EreaRpMasterWhisperEditor.Create(parent, params, methodIndex)
    counter = counter + 1
    local frame = CreateFrame("Frame", "EreaRpMasterWhisperEditor" .. counter, parent, "EreaRpMasterWhisperEditorTemplate")
    frame:SetWidth(parent:GetWidth() - 20)

    -- Set method title
    local title = _G[frame:GetName() .. "Title"]
    title:SetText("|cFFFFD700Method " .. methodIndex .. ":|r Whisper Player")

    -- Set label texts via Lua (WoW 1.12: <Text> in virtual templates is not applied)
    _G[frame:GetName() .. "TextLabel"]:SetText("Whisper text:")
    _G[frame:GetName() .. "TextHint"]:SetText("|cFF888888(Use {player-name} for the triggering player's name)|r")

    -- Get child references
    local textEdit = _G[frame:GetName() .. "TextEdit"]

    function frame:GetParams()
        return {
            text = textEdit:GetText() or ""
        }
    end

    function frame:SetParams(p)
        if p and p.text then
            textEdit:SetText(p.text)
        end
    end

    -- Pre-populate if params provided
    if params then
        frame:SetParams(params)
    end

    return frame
end
