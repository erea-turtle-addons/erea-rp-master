-- ============================================================================
-- action-editor-side.lua - Side Editor (shared component)
-- ============================================================================
-- PURPOSE: Factory for left/right side editors used by Display Cinematic
--          and Merge Cinematic editors. Each side lets the user pick a type
--          (None/Portrait/Animation) with sub-fields for portrait unit or
--          animation selection, plus a live VideoPlayer preview.
--
-- VERTICAL LAYOUT (UIDropDownMenuTemplate frame height ≈ 44px):
--
--   yOffset - 5:   header label
--   yOffset - 20:  type dropdown   (frame: yOffset-20 to yOffset-64)
--   yOffset - 66:  sub-label       (2px gap below type dropdown frame)
--   yOffset - 81:  sub-dropdown    (frame: yOffset-81 to yOffset-125)
--                  [preview to the right of anim sub-dropdown]
--   yOffset - 132: loop label      (7px gap below sub-dropdown frame)
--   yOffset - 147: loop dropdown   (frame: yOffset-147 to yOffset-191)
--
--   Total height consumed: 200px
--
-- INTERFACE:
--   EreaRpMasterSideEditor.Create(parent, sideLabel, yOffset) -> side, height
--   side:GetType()          -> "none"|"portrait"|"animation"
--   side:GetPortraitUnit()  -> "player"|"target"
--   side:GetAnimationKey()  -> string
--   side:GetLoopMode()      -> "pingpong"|"cycle"
--   side:SetType(val)
--   side:SetPortraitUnit(val)
--   side:SetAnimationKey(val)
--   side:SetLoopMode(val)
--   side.Reposition(newXOffset, newColumnWidth)
-- ============================================================================

EreaRpMasterSideEditor = {}

local dropdownCounter = 0
local previewCounter = 0

-- ============================================================================
-- Create - Create type/portrait/animation dropdowns for one side
-- ============================================================================
-- @param parent:     Parent frame
-- @param sideLabel:  "Left" or "Right"
-- @param xOffset:    Horizontal offset within parent (column position)
-- @param yOffset:    Y offset within parent
-- @returns: sideEditor table, totalHeight consumed (200)
-- ============================================================================
function EreaRpMasterSideEditor.Create(parent, sideLabel, yOffset)
    local side = {}

    local cinematicAnims = EreaRpLibraries:CinematicAnimations()
    local videoPlayerLib = EreaRpLibraries:VideoPlayer()

    -- ── Create frames and fontstrings (no positions — set by Reposition below) ─

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetText("|cFFFFD700" .. sideLabel .. " side:|r")

    dropdownCounter = dropdownCounter + 1
    local typeDropdown = CreateFrame("Frame", "EreaRpMasterSideEditorType" .. dropdownCounter, parent, "UIDropDownMenuTemplate")

    dropdownCounter = dropdownCounter + 1
    local unitDropdown = CreateFrame("Frame", "EreaRpMasterSideEditorUnit" .. dropdownCounter, parent, "UIDropDownMenuTemplate")
    unitDropdown:Hide()

    local unitLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    unitLabel:SetText("Portrait unit:")
    unitLabel:Hide()

    dropdownCounter = dropdownCounter + 1
    local animDropdown = CreateFrame("Frame", "EreaRpMasterSideEditorAnim" .. dropdownCounter, parent, "UIDropDownMenuTemplate")
    animDropdown:Hide()

    local animLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    animLabel:SetText("Animation:")
    animLabel:Hide()

    dropdownCounter = dropdownCounter + 1
    local loopModeDropdown = CreateFrame("Frame", "EreaRpMasterSideEditorLoopMode" .. dropdownCounter, parent, "UIDropDownMenuTemplate")
    loopModeDropdown:Hide()

    local loopModeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    loopModeLabel:SetText("Loop:")
    loopModeLabel:Hide()

    previewCounter = previewCounter + 1
    local previewFrame = CreateFrame("Frame", "EreaRpMasterSideEditorPreview" .. previewCounter, parent)
    previewFrame:SetWidth(72)
    previewFrame:SetHeight(72)
    previewFrame:SetPoint("TOPRIGHT",  animDropdown,    "TOPRIGHT",  61, -3)
    previewFrame:Hide()

    local previewTexture = previewFrame:CreateTexture(nil, "ARTWORK")
    previewTexture:SetAllPoints(previewFrame)

    local previewPlayer = videoPlayerLib.New(previewTexture)

    -- ── Helpers ────────────────────────────────────────────────────────────────

    local function SetPreviewAnimation(animKey, loopMode)
        previewPlayer:Stop()
        if animKey and animKey ~= "" then
            previewPlayer:Play(animKey, loopMode)
            if previewPlayer:IsPlaying() then
                previewFrame:Show()
            else
                previewFrame:Hide()
            end
        else
            previewFrame:Hide()
        end
    end

    local function UpdateSubFields(selectedType)
        if selectedType == "portrait" then
            unitDropdown:Show()
            unitLabel:Show()
            animDropdown:Hide()
            animLabel:Hide()
            loopModeDropdown:Hide()
            loopModeLabel:Hide()
            previewFrame:Hide()
            previewPlayer:Stop()
        elseif selectedType == "animation" then
            unitDropdown:Hide()
            unitLabel:Hide()
            animDropdown:Show()
            animLabel:Show()
            loopModeDropdown:Show()
            loopModeLabel:Show()
            local currentAnim = UIDropDownMenu_GetSelectedValue(animDropdown) or ""
            local currentLoopMode = UIDropDownMenu_GetSelectedValue(loopModeDropdown) or "pingpong"
            SetPreviewAnimation(currentAnim, currentLoopMode)
        else
            unitDropdown:Hide()
            unitLabel:Hide()
            animDropdown:Hide()
            animLabel:Hide()
            loopModeDropdown:Hide()
            loopModeLabel:Hide()
            previewFrame:Hide()
            previewPlayer:Stop()
        end
    end

    -- ── Dropdown initialization ────────────────────────────────────────────────

    UIDropDownMenu_Initialize(typeDropdown, function()
        local types = {
            { text = "None",      value = "none" },
            { text = "Portrait",  value = "portrait" },
            { text = "Animation", value = "animation" }
        }
        for i = 1, table.getn(types) do -- Lua 5.0: table.getn
            local t = types[i]
            local info = {}
            info.text = t.text
            info.value = t.value
            do
                local val = t.value
                local txt = t.text
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(typeDropdown, val)
                    UIDropDownMenu_SetText(txt, typeDropdown)
                    UpdateSubFields(val)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(typeDropdown, "none")
    UIDropDownMenu_SetText("None", typeDropdown)

    UIDropDownMenu_Initialize(unitDropdown, function()
        local units = {
            { text = "Player (sender)",          value = "player" },
            { text = "Target (sender's target)", value = "target" }
        }
        for i = 1, table.getn(units) do -- Lua 5.0: table.getn
            local u = units[i]
            local info = {}
            info.text = u.text
            info.value = u.value
            do
                local val = u.value
                local txt = u.text
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(unitDropdown, val)
                    UIDropDownMenu_SetText(txt, unitDropdown)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(unitDropdown, "player")
    UIDropDownMenu_SetText("Player (sender)", unitDropdown)

    UIDropDownMenu_Initialize(animDropdown, function()
        local noneInfo = {}
        noneInfo.text = "(None)"
        noneInfo.value = ""
        noneInfo.func = function()
            UIDropDownMenu_SetSelectedValue(animDropdown, "")
            UIDropDownMenu_SetText("(None)", animDropdown)
            SetPreviewAnimation(nil)
        end
        UIDropDownMenu_AddButton(noneInfo)

        local animList = cinematicAnims.GetAnimationList()
        for i = 1, table.getn(animList) do -- Lua 5.0: table.getn
            local entry = animList[i]
            local info = {}
            info.text = entry.label
            info.value = entry.key
            do
                local selectedKey = entry.key
                local selectedLabel = entry.label
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(animDropdown, selectedKey)
                    UIDropDownMenu_SetText(selectedLabel, animDropdown)
                    local currentLoopMode = UIDropDownMenu_GetSelectedValue(loopModeDropdown) or "pingpong"
                    SetPreviewAnimation(selectedKey, currentLoopMode)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText("(None)", animDropdown)

    UIDropDownMenu_Initialize(loopModeDropdown, function()
        local modes = {
            { text = "Ping-Pong", value = "pingpong" },
            { text = "Cycle",     value = "cycle" }
        }
        for i = 1, table.getn(modes) do -- Lua 5.0: table.getn
            local m = modes[i]
            local info = {}
            info.text = m.text
            info.value = m.value
            do
                local val = m.value
                local txt = m.text
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(loopModeDropdown, val)
                    UIDropDownMenu_SetText(txt, loopModeDropdown)
                    local currentAnim = UIDropDownMenu_GetSelectedValue(animDropdown) or ""
                    SetPreviewAnimation(currentAnim, val)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(loopModeDropdown, "pingpong")
    UIDropDownMenu_SetText("Ping-Pong", loopModeDropdown)

    -- ── Getters / Setters ──────────────────────────────────────────────────────

    function side:GetType()
        return UIDropDownMenu_GetSelectedValue(typeDropdown) or "none"
    end

    function side:GetPortraitUnit()
        return UIDropDownMenu_GetSelectedValue(unitDropdown) or "player"
    end

    function side:GetAnimationKey()
        return UIDropDownMenu_GetSelectedValue(animDropdown) or ""
    end

    function side:GetLoopMode()
        return UIDropDownMenu_GetSelectedValue(loopModeDropdown) or "pingpong"
    end

    function side:SetType(val)
        UIDropDownMenu_SetSelectedValue(typeDropdown, val or "none")
        if val == "portrait" then
            UIDropDownMenu_SetText("Portrait", typeDropdown)
        elseif val == "animation" then
            UIDropDownMenu_SetText("Animation", typeDropdown)
        else
            UIDropDownMenu_SetText("None", typeDropdown)
        end
        UpdateSubFields(val or "none")
    end

    function side:SetPortraitUnit(val)
        UIDropDownMenu_SetSelectedValue(unitDropdown, val or "player")
        if val == "target" then
            UIDropDownMenu_SetText("Target (sender's target)", unitDropdown)
        else
            UIDropDownMenu_SetText("Player (sender)", unitDropdown)
        end
    end

    function side:SetAnimationKey(val)
        UIDropDownMenu_SetSelectedValue(animDropdown, val or "")
        if val and val ~= "" then
            UIDropDownMenu_SetText(val, animDropdown)
        else
            UIDropDownMenu_SetText("(None)", animDropdown)
        end
        if side:GetType() == "animation" then
            local currentLoopMode = UIDropDownMenu_GetSelectedValue(loopModeDropdown) or "pingpong"
            SetPreviewAnimation(val, currentLoopMode)
        end
    end

    function side:SetLoopMode(val)
        local mode = val or "pingpong"
        UIDropDownMenu_SetSelectedValue(loopModeDropdown, mode)
        if mode == "cycle" then
            UIDropDownMenu_SetText("Cycle", loopModeDropdown)
        else
            UIDropDownMenu_SetText("Ping-Pong", loopModeDropdown)
        end
        if side:GetType() == "animation" then
            local currentAnim = UIDropDownMenu_GetSelectedValue(animDropdown) or ""
            SetPreviewAnimation(currentAnim, mode)
        end
    end

    -- ── Reposition: single source of truth for all element positions ───────────
    -- Called on creation and whenever the parent frame is resized (via Reflow).
    --   typeDdWidth: fills the column (no preview beside type/unit dropdown)
    --   animDdWidth: leaves room for 36px preview + 5px gap + 32px frame padding
    function side.Reposition(newXOffset, newColumnWidth)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", newXOffset + 20, yOffset - 5)

        typeDropdown:ClearAllPoints()
        typeDropdown:SetPoint("TOPLEFT", newXOffset, yOffset - 20)

        unitLabel:ClearAllPoints()
        unitLabel:SetPoint("TOPLEFT", newXOffset + 20, yOffset - 56)

        unitDropdown:ClearAllPoints()
        unitDropdown:SetPoint("TOPLEFT", newXOffset, yOffset - 71)

        animLabel:ClearAllPoints()
        animLabel:SetPoint("TOPLEFT", newXOffset + 20, yOffset - 56)

        animDropdown:ClearAllPoints()
        animDropdown:SetPoint("TOPLEFT", newXOffset, yOffset - 71)

        loopModeLabel:ClearAllPoints()
        loopModeLabel:SetPoint("TOPLEFT", newXOffset + 20, yOffset - 106)

        loopModeDropdown:ClearAllPoints()
        loopModeDropdown:SetPoint("TOPLEFT", newXOffset, yOffset - 121)

        -- previewFrame is anchored to animDropdown:RIGHT — moves automatically.

        local typeDdWidth = math.max(80, (newColumnWidth or 160) - 32)
        local animDdWidth = math.max(60, (newColumnWidth or 160) - 112)
        UIDropDownMenu_SetWidth(typeDdWidth, typeDropdown)
        UIDropDownMenu_SetWidth(typeDdWidth, unitDropdown)
        UIDropDownMenu_SetWidth(animDdWidth, animDropdown)
        UIDropDownMenu_SetWidth(animDdWidth, loopModeDropdown)
    end

    return side, 153
end
