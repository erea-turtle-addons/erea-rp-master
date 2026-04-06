-- ============================================================================
-- action-editor-npc-chat.lua - NPC Chat Editor Controller
-- ============================================================================
-- TEMPLATE: views/action-editor-npc-chat.xml
-- PURPOSE: Factory for NPC Chat method editor instances
-- INTERFACE:
--   EreaRpMasterNpcChatEditor.Create(parent, params, methodIndex) -> frame
--   frame:GetParams() -> { tag = string, cmdType = string, text = string }
--   frame:SetParams(params)
-- ============================================================================

EreaRpMasterNpcChatEditor = {}

local counter = 0
local dropdownCounter = 0

-- ============================================================================
-- Create - Create a new editor instance from virtual template
-- ============================================================================
-- @param parent: Parent frame to attach to
-- @param params: Parameter table with optional tag, cmdType, text fields
-- @param methodIndex: Index of this method in the methods array
-- @returns: editor frame with GetParams/SetParams methods
-- ============================================================================
function EreaRpMasterNpcChatEditor.Create(parent, params, methodIndex)
    counter = counter + 1
    local frame = CreateFrame("Frame", "EreaRpMasterNpcChatEditor" .. counter, parent, "EreaRpMasterNpcChatEditorTemplate")
    frame:SetWidth(parent:GetWidth() - 20)

    -- Set method title
    local title = _G[frame:GetName() .. "Title"]
    title:SetText("|cFFFFD700Method " .. methodIndex .. ":|r NPC Chat")

    -- Set label texts via Lua (WoW 1.12: <Text> in virtual templates is not applied)
    _G[frame:GetName() .. "TagLabel"]:SetText("NPC Tag (e.g. innkeeper, guard):")
    _G[frame:GetName() .. "CmdTypeLabel"]:SetText("Chat type:")
    _G[frame:GetName() .. "TextLabel"]:SetText("Text to speak:")
    _G[frame:GetName() .. "TextHint"]:SetText("|cFF888888(Use {player-name} for the triggering player's name)|r")

    -- Get child references
    local tagEdit  = _G[frame:GetName() .. "TagEdit"]
    local textEdit = _G[frame:GetName() .. "TextEdit"]

    -- Create chat type dropdown (UIDropDownMenuTemplate needs unique global name)
    dropdownCounter = dropdownCounter + 1
    local dropdownName = "EreaRpMasterNpcChatEditorCmdType" .. dropdownCounter
    local cmdTypeDropdown = CreateFrame("Frame", dropdownName, frame, "UIDropDownMenuTemplate")
    cmdTypeDropdown:SetPoint("TOPLEFT", -12, -98)
    UIDropDownMenu_SetWidth(120, cmdTypeDropdown)

    local cmdTypeOptions = {
        { value = "say",   label = "Say" },
        { value = "yell",  label = "Yell" },
        { value = "emote", label = "Emote" }
    }

    UIDropDownMenu_Initialize(cmdTypeDropdown, function()
        for i = 1, 3 do
            local info = {}
            info.text  = cmdTypeOptions[i].label
            info.value = cmdTypeOptions[i].value
            do
                local val = cmdTypeOptions[i].value
                local lbl = cmdTypeOptions[i].label
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(cmdTypeDropdown, val)
                    UIDropDownMenu_SetText(lbl, cmdTypeDropdown)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText("Select...", cmdTypeDropdown)

    function frame:GetParams()
        return {
            tag     = tagEdit:GetText() or "",
            cmdType = UIDropDownMenu_GetSelectedValue(cmdTypeDropdown) or "",
            text    = textEdit:GetText() or ""
        }
    end

    function frame:SetParams(p)
        if not p then return end

        if p.tag then
            tagEdit:SetText(p.tag)
        end

        if p.cmdType then
            UIDropDownMenu_SetSelectedValue(cmdTypeDropdown, p.cmdType)
            -- Find matching label
            for i = 1, 3 do
                if cmdTypeOptions[i].value == p.cmdType then
                    UIDropDownMenu_SetText(cmdTypeOptions[i].label, cmdTypeDropdown)
                    break
                end
            end
        end

        if p.text then
            textEdit:SetText(p.text)
        end
    end

    -- Pre-populate if params provided
    if params then
        frame:SetParams(params)
    end

    return frame
end
