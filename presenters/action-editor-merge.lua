-- ============================================================================
-- action-editor-merge.lua - Merge Cinematic Editor Controller
-- ============================================================================
-- TEMPLATE: views/action-editor-merge.xml
-- PURPOSE: Factory for Merge Cinematic method editor instances
-- DEPENDENCIES: EreaRpMasterCinematicComponent (action-editor-cinematic.lua)
-- INTERFACE:
--   EreaRpMasterMergeEditor.Create(parent, params, methodIndex) -> frame
--   frame:GetParams() -> { mergeGroup = string }
--   frame:SetParams(params)
--   frame:SaveToLibrary()
-- ============================================================================

EreaRpMasterMergeEditor = {}

local counter = 0
local dropdownCounter = 0

-- ============================================================================
-- Create - Create a new Merge Cinematic editor instance
-- ============================================================================
function EreaRpMasterMergeEditor.Create(parent, params, methodIndex)
    counter = counter + 1
    local frame = CreateFrame("Frame", "EreaRpMasterMergeEditor" .. counter, parent, "EreaRpMasterMergeEditorTemplate")
    frame:SetWidth(parent:GetWidth() - 20)

    -- Set method title and static labels
    local title = _G[frame:GetName() .. "Title"]
    title:SetText("|cFFFFD700Method " .. methodIndex .. ":|r Merge Cinematic")
    _G[frame:GetName() .. "IdLabel"]:SetText("Group ID:")
    _G[frame:GetName() .. "AmountLabel"]:SetText("Invocation threshold:")

    -- Get XML child references
    local idEdit = _G[frame:GetName() .. "IdEdit"]
    local amountEdit = _G[frame:GetName() .. "AmountEdit"]
    amountEdit:SetText("2")
    amountEdit:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    -- ---- Create group selection dropdown dynamically ----

    dropdownCounter = dropdownCounter + 1
    local groupDropdownName = "EreaRpMasterMergeEditorGroup" .. dropdownCounter
    local groupDropdown = CreateFrame("Frame", groupDropdownName, frame, "UIDropDownMenuTemplate")
    groupDropdown:SetPoint("TOPLEFT", -12, -24)
    UIDropDownMenu_SetWidth(270, groupDropdown)  -- bounded left of text column (~355px)
    _G[groupDropdownName .. "Text"]:SetJustifyH("LEFT")

    -- ---- Embed the shared cinematic component ----

    local cinematicTop = -80
    local cinematic, cinematicHeight = EreaRpMasterCinematicComponent.Create(frame, cinematicTop)

    -- Initial column layout based on current frame width, then reflow on resize
    cinematic.Reflow(frame:GetWidth())
    frame:SetScript("OnSizeChanged", function()
        cinematic.Reflow(this:GetWidth()) -- Lua 5.0: this
    end)

    -- Adjust total frame height
    frame:SetHeight(math.abs(cinematicTop) + cinematicHeight + 20)

    -- ---- Helper functions ----

    local function LoadMergeGroup(groupId)
        if not EreaRpMasterDB or not EreaRpMasterDB.mergeLibrary then return end
        local entry = EreaRpMasterDB.mergeLibrary[groupId]
        if not entry then return end

        idEdit:SetText(groupId)
        idEdit:EnableKeyboard(false)  -- Cannot change ID of existing group
        amountEdit:SetText(tostring(entry.amount or 2))

        -- Load cinematic data (speaker, dialogue, sides)
        cinematic:SetData(entry)
    end

    local function ClearForm()
        idEdit:SetText("")
        idEdit:EnableKeyboard(true)
        amountEdit:SetText("2")
        cinematic:Clear()
    end

    -- ---- Initialize group selection dropdown ----

    UIDropDownMenu_Initialize(groupDropdown, function()
        -- "(New) Create new merge group"
        local newInfo = {}
        newInfo.text = "(New) Create new merge group"
        newInfo.value = "_NEW_"
        newInfo.func = function()
            UIDropDownMenu_SetSelectedValue(groupDropdown, "_NEW_")
            UIDropDownMenu_SetText("(New) Create new merge group", groupDropdown)
            ClearForm()
        end
        UIDropDownMenu_AddButton(newInfo)

        -- Existing merge groups
        if EreaRpMasterDB and EreaRpMasterDB.mergeLibrary then
            for groupId, entry in pairs(EreaRpMasterDB.mergeLibrary) do
                local info = {}
                info.text = groupId
                info.value = groupId
                do
                    local gid = groupId
                    info.func = function()
                        UIDropDownMenu_SetSelectedValue(groupDropdown, gid)
                        UIDropDownMenu_SetText(gid, groupDropdown)
                        LoadMergeGroup(gid)
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
    UIDropDownMenu_SetText("Select merge group...", groupDropdown)

    -- ---- Helper to build save data from cinematic + merge fields ----

    local function BuildSaveData()
        local data = cinematic:GetData()
        data.amount = tonumber(amountEdit:GetText()) or 2

        -- Build script references
        local scriptRefs = cinematic.GetScriptReferences()
        local scriptRefsStr = ""
        if table.getn(scriptRefs) > 0 then -- Lua 5.0: table.getn
            scriptRefsStr = table.concat(scriptRefs, ",")
        end
        data.scriptReferences = scriptRefsStr

        return data
    end

    -- ---- Public interface ----

    function frame:GetParams()
        return {
            mergeGroup = idEdit:GetText() or ""
        }
    end

    function frame:SetParams(p)
        if p and p.mergeGroup and p.mergeGroup ~= "" then
            UIDropDownMenu_SetSelectedValue(groupDropdown, p.mergeGroup)
            UIDropDownMenu_SetText(p.mergeGroup, groupDropdown)
            LoadMergeGroup(p.mergeGroup)
        end
    end

    function frame:GetPreviewData()
        return cinematic:GetData()
    end

    function frame:SaveToLibrary()
        -- Called during SaveCurrentAction to persist changes
        local groupId = idEdit:GetText() or ""
        if groupId == "" or groupId == "_NEW_" then return end

        local data = BuildSaveData()
        if data.speakerName == "" and data.messageTemplate == "" then return end

        if not EreaRpMasterDB.mergeLibrary then
            EreaRpMasterDB.mergeLibrary = {}
        end
        EreaRpMasterDB.mergeLibrary[groupId] = data
    end

    -- Pre-populate if params provided
    if params then
        frame:SetParams(params)
    end

    return frame
end
