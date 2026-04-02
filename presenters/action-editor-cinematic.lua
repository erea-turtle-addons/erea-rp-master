-- ============================================================================
-- action-editor-cinematic.lua - Cinematic Editor (shared component)
-- ============================================================================
-- PURPOSE: Reusable cinematic editing block used by both Display Cinematic
--          and Merge Cinematic editors.
--
-- LAYOUT (3 stacked rows + helper row):
--
--   yOffset+0:    Row A — "Title:" label + Title EditBox (full width)
--   yOffset-32:   Row B — Left side editor | Right side editor (50/50 split)
--   yOffset-182:  Row C — "Text:" label
--   yOffset-200:  Row C — ScrollFrame + multiline EditBox with scrollbar (full width)
--   yOffset-330:  Row D — placeholder hint (gray)
--   yOffset-346:  Row D — "Script references (inferred):" + display
--
-- DEPENDENCIES: EreaRpMasterSideEditor (action-editor-side.lua)
--
-- INTERFACE:
--   EreaRpMasterCinematicComponent.Create(parent, yOffset) -> component, height
--   component:GetData()  -> { speakerName, messageTemplate, left/right fields }
--   component:SetData(data)
--   component:Clear()
--   component.GetScriptReferences() -> { scriptName, ... }
-- ============================================================================

EreaRpMasterCinematicComponent = {}

local componentCounter = 0  -- for unique ScrollFrame names

-- ============================================================================
-- HELPERS (module-local)
-- ============================================================================

local function GetScriptReferencesFromText(text)
    local scriptNames = {}
    if not text or text == "" then return scriptNames end

    -- Lua 5.0: manual parsing for {script:XXX} placeholders
    local i = 1
    while i <= string.len(text) do
        local start_script, end_script = string.find(text, "{script:", i, true)
        if start_script then
            local start_name = end_script + 1
            local end_name = string.find(text, "}", start_name, true)
            if end_name then
                local scriptName = string.sub(text, start_name, end_name - 1)
                table.insert(scriptNames, scriptName)
                i = end_name + 1
            else
                break
            end
        else
            break
        end
    end

    return scriptNames
end

-- ============================================================================
-- Create - Build the cinematic editing block within a parent frame
-- ============================================================================
-- @param parent:   Parent frame (method block frame)
-- @param yOffset:  Y position within parent where this block begins
-- @returns:        component table, totalHeight consumed
-- ============================================================================
function EreaRpMasterCinematicComponent.Create(parent, yOffset)
    local comp = {}

    -- ── Row A: Title (full width, single line) ─────────────────────────────────

    local titleLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleLabel:SetText("Title:")

    local titleBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    titleBox:SetHeight(22)
    titleBox:SetAutoFocus(false)
    titleBox:SetMaxLetters(100)
    titleBox:SetScript("OnEscapePressed", function() this:ClearFocus() end) -- Lua 5.0: this

    -- ── Row B: Left and Right side editors (50/50 split) ──────────────────────
    -- Created at yOffset-32 (8px gap after 22px editbox + 2px offset = 32).
    -- Reflow() will call Reposition() to split them correctly.

    local sidesYOffset = yOffset - 32
    local leftSide, leftHeight = EreaRpMasterSideEditor.Create(parent, "Left",  sidesYOffset)
    local rightSide            = EreaRpMasterSideEditor.Create(parent, "Right", sidesYOffset)

    -- ── Row C: Text label + scrollable EditBox (full width) ───────────────────
    -- Starts 10px below the bottom of the side editors (height=140).

    local textYOffset = sidesYOffset - leftHeight - 10  -- = yOffset - 32 - 140 - 10 = yOffset - 182

    local textLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, textYOffset)
    textLabel:SetText("Text:")

    -- Backdrop container (TOPLEFT→TOPRIGHT so it auto-scales with Reflow)
    local textContainer = CreateFrame("Frame", nil, parent)
    textContainer:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10,  textYOffset - 16)
    textContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, textYOffset - 16)
    textContainer:SetHeight(80)
    textContainer:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    textContainer:SetBackdropColor(0.1, 0.1, 0.1, 1)
    textContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- ScrollFrame with built-in scrollbar (UIPanelScrollFrameTemplate)
    componentCounter = componentCounter + 1
    local scrollFrameName = "EreaCinematicMsgScrollFrame" .. componentCounter
    local scrollFrame = CreateFrame("ScrollFrame", scrollFrameName, textContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     textContainer, "TOPLEFT",     4,  -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", textContainer, "BOTTOMRIGHT", -26,  4)

    -- EditBox is the scroll child: height=1 so it auto-grows with content
    local msgBox = CreateFrame("EditBox", nil, scrollFrame)
    msgBox:SetMultiLine(true)
    msgBox:SetAutoFocus(false)
    msgBox:SetWidth(200)    -- overridden in Reflow
    msgBox:SetHeight(1)     -- auto-grows
    msgBox:SetFontObject(ChatFontNormal)
    msgBox:SetTextInsets(3, 3, 3, 3)
    msgBox:SetMaxLetters(500)
    msgBox:SetScript("OnEscapePressed", function() this:ClearFocus() end) -- Lua 5.0: this
    msgBox:SetScript("OnCursorChanged", function()
        ScrollingEdit_OnCursorChanged(arg1, arg2, arg3, arg4) -- Lua 5.0: arg1..4
    end)
    scrollFrame:SetScrollChild(msgBox)

    -- ── Row D: Hint text + Script references display ───────────────────────────
    -- 8px below bottom of text container (textYOffset - 18 - 120 = textYOffset - 138).

    local hintYOffset = textYOffset - 98 - 8  -- = yOffset - 182 - 138 - 8 = yOffset - 328

    local hintLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, hintYOffset)
    hintLabel:SetText("|cFF888888(Use {playerName}, {customText} or {script:name} in Title & Text)|r")

    local scriptRefLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scriptRefLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, hintYOffset - 16)
    scriptRefLabel:SetText("Script references (inferred):")

    local scriptRefDisplay = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scriptRefDisplay:SetPoint("TOPLEFT",  parent, "TOPLEFT",  175, hintYOffset - 16)
    scriptRefDisplay:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, hintYOffset - 16)
    scriptRefDisplay:SetJustifyH("LEFT")
    scriptRefDisplay:SetTextColor(0.5, 0.8, 0.5)
    scriptRefDisplay:SetText("(No scripts found)")

    -- ── Script reference update helpers ────────────────────────────────────────

    local function GetScriptReferences()
        local scriptNames = {}

        local spkText = titleBox:GetText() or ""
        local spkRefs = GetScriptReferencesFromText(spkText)
        for i = 1, table.getn(spkRefs) do -- Lua 5.0: table.getn
            table.insert(scriptNames, spkRefs[i])
        end

        local msgText = msgBox:GetText() or ""
        local msgRefs = GetScriptReferencesFromText(msgText)
        for i = 1, table.getn(msgRefs) do -- Lua 5.0: table.getn
            table.insert(scriptNames, msgRefs[i])
        end

        -- Remove duplicates
        local uniqueNames = {}
        local seen = {}
        for i = 1, table.getn(scriptNames) do -- Lua 5.0: table.getn
            local name = scriptNames[i]
            if not seen[name] then
                table.insert(uniqueNames, name)
                seen[name] = true
            end
        end

        return uniqueNames
    end
    comp.GetScriptReferences = GetScriptReferences

    local function UpdateScriptReferences()
        local uniqueNames = GetScriptReferences()
        if table.getn(uniqueNames) > 0 then -- Lua 5.0: table.getn
            scriptRefDisplay:SetText(table.concat(uniqueNames, ", "))
        else
            scriptRefDisplay:SetText("(No scripts found)")
        end
    end

    -- Wire up real-time updates
    titleBox:SetScript("OnTextChanged", function() UpdateScriptReferences() end)
    msgBox:SetScript("OnTextChanged", function()
        scrollFrame:UpdateScrollChildRect()
        UpdateScriptReferences()
    end)

    -- ── Reflow: called on creation and on parent resize ────────────────────────
    -- Splits sides 50/50 and updates msgBox width to match the scroll area.

    function comp.Reflow(frameWidth)
        local halfWidth = math.floor((frameWidth - 6) / 2)
        if halfWidth < 80 then halfWidth = 80 end

        -- Title label + EditBox: full width
        titleLabel:ClearAllPoints()
        titleLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 7, yOffset - 10)

        titleBox:ClearAllPoints()
        titleBox:SetPoint("TOPLEFT",  parent, "TOPLEFT",  55, yOffset - 3)
        titleBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, yOffset - 3)

        -- Side editors: left occupies left half, right occupies right half
        leftSide.Reposition(-12,             halfWidth)
        rightSide.Reposition(halfWidth - 1,  halfWidth)

        -- msgBox width: container width minus scrollbar area (26) minus insets (6)
        local msgBoxWidth = math.max(50, frameWidth - 32)
        msgBox:SetWidth(msgBoxWidth)
    end

    -- ── Public interface ────────────────────────────────────────────────────────

    function comp:GetData()
        -- Build legacy animationKey from sides (for backwards compat with older saves)
        local legacyAnimKey = ""
        if rightSide:GetType() == "animation" then
            legacyAnimKey = rightSide:GetAnimationKey()
        elseif leftSide:GetType() == "animation" then
            legacyAnimKey = leftSide:GetAnimationKey()
        end

        return {
            speakerName     = titleBox:GetText() or "",
            messageTemplate = msgBox:GetText() or "",
            animationKey    = legacyAnimKey,
            leftType             = leftSide:GetType(),
            leftPortraitUnit     = leftSide:GetPortraitUnit(),
            leftAnimationKey     = leftSide:GetAnimationKey(),
            leftLoopMode         = leftSide:GetLoopMode(),
            rightType            = rightSide:GetType(),
            rightPortraitUnit    = rightSide:GetPortraitUnit(),
            rightAnimationKey    = rightSide:GetAnimationKey(),
            rightLoopMode        = rightSide:GetLoopMode()
        }
    end

    function comp:SetData(data)
        if not data then return end

        titleBox:SetText(data.speakerName or "")
        msgBox:SetText(data.messageTemplate or "")

        -- Load side configs (new fields) or fall back to legacy animationKey
        if data.leftType then
            leftSide:SetType(data.leftType)
            leftSide:SetPortraitUnit(data.leftPortraitUnit or "player")
            leftSide:SetAnimationKey(data.leftAnimationKey or "")
            leftSide:SetLoopMode(data.leftLoopMode or "pingpong")
            rightSide:SetType(data.rightType or "none")
            rightSide:SetPortraitUnit(data.rightPortraitUnit or "player")
            rightSide:SetAnimationKey(data.rightAnimationKey or "")
            rightSide:SetLoopMode(data.rightLoopMode or "pingpong")
        else
            -- Legacy: portrait on left, animation on right if animationKey exists
            leftSide:SetType("portrait")
            leftSide:SetPortraitUnit("player")
            local animKey = data.animationKey or ""
            if animKey ~= "" then
                rightSide:SetType("animation")
                rightSide:SetAnimationKey(animKey)
            else
                rightSide:SetType("none")
            end
        end

        UpdateScriptReferences()
    end

    function comp:Clear()
        titleBox:SetText("")
        msgBox:SetText("")
        leftSide:SetType("none")
        leftSide:SetLoopMode("pingpong")
        rightSide:SetType("none")
        rightSide:SetLoopMode("pingpong")
        scriptRefDisplay:SetText("(No scripts found)")
    end

    -- Total height: 32 (gap to Row B) + leftHeight + 10 (gap) + 16 (textLabel) + 80 (container)
    -- + 8 (gap to Row D) + 16 (hintLabel) + 16 (scriptRef) + 8 (bottom padding)
    local totalHeight = leftHeight + 186
    return comp, totalHeight
end
