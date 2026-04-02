-- ============================================================================
-- action-editor-create.lua - Create Object Editor Controller
-- ============================================================================
-- TEMPLATE: views/action-editor-create.xml
-- PURPOSE: Factory for Create Object method editor instances
-- INTERFACE:
--   EreaRpMasterCreateEditor.Create(parent, params, methodIndex) -> frame
--   frame:GetParams() -> { objectGuid, customText, customNumber }
--   frame:SetParams(params)
-- ============================================================================

EreaRpMasterCreateEditor = {}

local counter = 0

-- Counter for unique dropdown names (WoW 1.12 requires global names)
local dropdownCounter = 0

-- ============================================================================
-- Create - Create a new editor instance from virtual template
-- ============================================================================
-- @param parent: Parent frame to attach to
-- @param params: Parameter table with optional objectGuid, customText, customNumber
-- @param methodIndex: Index of this method in the methods array
-- @returns: editor frame with GetParams/SetParams methods
-- ============================================================================
function EreaRpMasterCreateEditor.Create(parent, params, methodIndex)
    counter = counter + 1
    local frame = CreateFrame("Frame", "EreaRpMasterCreateEditor" .. counter, parent, "EreaRpMasterCreateEditorTemplate")
    frame:SetWidth(parent:GetWidth() - 20)

    -- Set method title
    local title = _G[frame:GetName() .. "Title"]
    title:SetText("|cFFFFD700Method " .. methodIndex .. ":|r Create Object")

    -- Set label texts via Lua (WoW 1.12: <Text> in virtual templates is not applied)
    _G[frame:GetName() .. "ObjectLabel"]:SetText("Object to create:")
    _G[frame:GetName() .. "CustomTextLabel"]:SetText("Custom text for new object:")
    _G[frame:GetName() .. "CustomTextHint"]:SetText("|cFF888888(Use {custom-text} to copy source item's text)|r")
    _G[frame:GetName() .. "AdditionalTextLabel"]:SetText("Additional text for new object:")
    _G[frame:GetName() .. "AdditionalTextHint"]:SetText("|cFF888888(Use {additional-text} to copy source item's additional text)|r")
    _G[frame:GetName() .. "CustomNumberLabel"]:SetText("Counter for new object:")
    _G[frame:GetName() .. "CustomNumberHint"]:SetText("|cFF888888(Use {item-counter} to copy source item's counter)|r")

    -- Get child references
    local customTextEdit = _G[frame:GetName() .. "CustomTextEdit"]
    local additionalTextEdit = _G[frame:GetName() .. "AdditionalTextEdit"]
    local customNumberEdit = _G[frame:GetName() .. "CustomNumberEdit"]

    -- Initialize object dropdown (UIDropDownMenuTemplate needs unique global name)
    -- Positioned at y=-52 so its visual texture (extends 24px above anchor) clears the label at y=-30
    dropdownCounter = dropdownCounter + 1
    local dropdownName = "EreaRpMasterCreateEditorDropdown" .. dropdownCounter
    local objectDropdown = CreateFrame("Frame", dropdownName, frame, "UIDropDownMenuTemplate")
    objectDropdown:SetPoint("TOPLEFT", -12, -52)
    UIDropDownMenu_SetWidth(320, objectDropdown)

    UIDropDownMenu_Initialize(objectDropdown, function()
        if EreaRpMasterDB and EreaRpMasterDB.itemLibrary then
            for id, obj in pairs(EreaRpMasterDB.itemLibrary) do
                local info = {}
                info.text = obj.name
                info.value = obj.guid
                info.tooltipTitle = obj.name
                info.tooltipText = "GUID: " .. obj.guid
                do
                    local selectedGuid = obj.guid
                    local selectedName = obj.name
                    info.func = function()
                        UIDropDownMenu_SetSelectedValue(objectDropdown, selectedGuid)
                        UIDropDownMenu_SetText(selectedName, objectDropdown)
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
    UIDropDownMenu_SetText("Select object...", objectDropdown)

    function frame:GetParams()
        return {
            objectGuid = UIDropDownMenu_GetSelectedValue(objectDropdown) or "",
            customText = customTextEdit:GetText() or "",
            additionalText = additionalTextEdit:GetText() or "",
            customNumber = customNumberEdit:GetText() or ""
        }
    end

    function frame:SetParams(p)
        if not p then return end

        -- Set object GUID
        if p.objectGuid then
            UIDropDownMenu_SetSelectedValue(objectDropdown, p.objectGuid)
            if EreaRpMasterDB and EreaRpMasterDB.itemLibrary then
                for id, obj in pairs(EreaRpMasterDB.itemLibrary) do
                    if obj.guid == p.objectGuid then
                        UIDropDownMenu_SetText(obj.name, objectDropdown)
                        break
                    end
                end
            end
        end

        -- Set custom text
        if p.customText then
            customTextEdit:SetText(p.customText)
        end

        -- Set additional text
        additionalTextEdit:SetText(p.additionalText or "")

        -- Set custom number
        if p.customNumber then
            customNumberEdit:SetText(tostring(p.customNumber))
        end
    end

    -- Pre-populate if params provided
    if params then
        frame:SetParams(params)
    end

    return frame
end
