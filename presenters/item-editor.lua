-- ============================================================================
-- item-editor.lua - EreaRpMasterItemEditorFrame Controller
-- ============================================================================
-- UI Structure: views/item-editor.xml
-- Frame: EreaRpMasterItemEditorFrame (defined in XML)
--
-- PURPOSE: Manages the item editor dialog — create/edit items, icon selection,
--          content editing with default/template columns.
--
-- METHODS:
--   EreaRpMasterItemEditorFrame:Initialize()            - Setup refs, handlers
--   EreaRpMasterItemEditorFrame:Open(item, onSaveCb)    - Open editor for item
--   EreaRpMasterItemEditorFrame:Close()                 - Hide and clear state
--   EreaRpMasterItemEditorFrame:Save()                  - Validate and persist
--   EreaRpMasterItemEditorFrame:ShowTab(index)          - Switch active tab
--   EreaRpMasterItemEditorFrame:ResetPositions()        - Reset window position to default
--
-- DEPENDENCIES:
--   - EreaRpMasterItemLibrary (services/item-library.lua)
--   - EreaRpMasterIconPickerFrame (presenters/icon-picker.lua)
--   - EreaRpMasterActionEditorFrame (presenters/action-editor.lua)
-- ============================================================================

-- ============================================================================
-- DeepCopyActions - Deep copy an actions array (local helper)
-- ============================================================================
local function DeepCopyActions(actions)
    local copy = {}
    if not actions then return copy end
    for i = 1, table.getn(actions) do -- Lua 5.0: no # operator
        local action = actions[i]
        local actionCopy = {
            id = action.id,
            label = action.label,
            sendStatus = action.sendStatus or false,
            methods = {},
            conditions = {}
        }
        if action.conditions then
            actionCopy.conditions.customTextEmpty = action.conditions.customTextEmpty
            actionCopy.conditions.counterGreaterThanZero = action.conditions.counterGreaterThanZero
        end
        if action.methods then
            for j = 1, table.getn(action.methods) do -- Lua 5.0: no # operator
                local method = action.methods[j]
                local methodCopy = { type = method.type, params = {} }
                if method.params then
                    for key, value in pairs(method.params) do
                        methodCopy.params[key] = value
                    end
                end
                table.insert(actionCopy.methods, methodCopy)
            end
        end
        table.insert(copy, actionCopy)
    end
    return copy
end

-- ============================================================================
-- Initialize
-- ============================================================================
function EreaRpMasterItemEditorFrame:Initialize()
    local self = EreaRpMasterItemEditorFrame

    -- Store frame references
    self.titleBar = EreaRpMasterItemEditorFrameTitleBar
    self.closeButton = EreaRpMasterItemEditorFrameCloseButton
    self.iconButton = EreaRpMasterItemEditorFrameIconButton
    self.iconTexture = EreaRpMasterItemEditorFrameIconButtonIconTexture
    self.nameEditBox = EreaRpMasterItemEditorFrameNameEditBox
    self.tooltipEditBox = EreaRpMasterItemEditorFrameTooltipContainerEditBox
    self.handoutEditBox = EreaRpMasterItemEditorFrameHandoutEditBox
    self.counterEditBox = EreaRpMasterItemEditorFrameCounterEditBox
    self.initialCustomTextEditBox = EreaRpMasterItemEditorFrameInitialCustomTextEditBox
    self.defaultContentEditBox = EreaRpMasterItemEditorDefaultContentEditBox
    self.defaultContentScroll = EreaRpMasterItemEditorDefaultContentScroll
    self.templateContentEditBox = EreaRpMasterItemEditorTemplateContentEditBox
    self.templateContentScroll = EreaRpMasterItemEditorTemplateContentScroll
    self.copyRightButton = EreaRpMasterItemEditorFrameCopyRightButton
    self.copyLeftButton = EreaRpMasterItemEditorFrameCopyLeftButton
    self.saveButton = EreaRpMasterItemEditorFrameSaveButton
    self.cancelButton = EreaRpMasterItemEditorFrameCancelButton

    -- Recipe controls
    self.ingredient1Dropdown  = EreaRpMasterItemEditorFrameIngredient1Dropdown
    self.ingredient2Dropdown  = EreaRpMasterItemEditorFrameIngredient2Dropdown
    self.cinematicDropdown    = EreaRpMasterItemEditorFrameCinematicDropdown
    self.notifyGmCheckButton  = EreaRpMasterItemEditorFrameNotifyGmCheckButton
    self.clearRecipeButton    = EreaRpMasterItemEditorFrameClearRecipeButton

    -- Tab buttons and panels
    self.tab1Button = EreaRpMasterItemEditorFrameTab1
    self.tab2Button = EreaRpMasterItemEditorFrameTab2
    self.tab3Button = EreaRpMasterItemEditorFrameTab3
    self.definitionPanel = EreaRpMasterItemEditorFrameDefinitionPanel
    self.creationPanel   = EreaRpMasterItemEditorFrameCreationPanel
    self.actionsPanel    = EreaRpMasterItemEditorFrameActionsPanel

    -- State
    self.currentItem = nil
    self.onSaveCallback = nil
    self.currentIcon = ""
    self.currentActions = {}
    self.activeTab = 1

    -- Recipe state
    self.recipeIngredient1Guid = nil
    self.recipeIngredient2Guid = nil
    self.recipeCinematicKey    = nil

    -- Dragging
    self.titleBar:SetScript("OnMouseDown", function()
        EreaRpMasterItemEditorFrame:StartMoving()
    end)
    self.titleBar:SetScript("OnMouseUp", function()
        EreaRpMasterItemEditorFrame:StopMovingOrSizing()
    end)

    -- Close button
    self.closeButton:SetScript("OnClick", function()
        EreaRpMasterItemEditorFrame:Close()
    end)

    -- Cancel button
    self.cancelButton:SetScript("OnClick", function()
        EreaRpMasterItemEditorFrame:Close()
    end)

    -- Save button
    self.saveButton:SetScript("OnClick", function()
        EreaRpMasterItemEditorFrame:Save()
    end)

    -- Icon button → open picker
    self.iconButton:SetScript("OnClick", function()
        EreaRpMasterIconPickerFrame:Open(
            EreaRpMasterItemEditorFrame.currentIcon,
            function(iconPath)
                EreaRpMasterItemEditorFrame.currentIcon = iconPath
                EreaRpMasterItemEditorFrame.iconTexture:SetTexture(iconPath)
            end
        )
    end)

    -- Copy buttons (default <-> template)
    self.copyRightButton:SetScript("OnClick", function()
        local text = EreaRpMasterItemEditorFrame.defaultContentEditBox:GetText()
        EreaRpMasterItemEditorFrame.templateContentEditBox:SetText(text)
        EreaRpMasterItemEditorFrame.templateContentScroll:UpdateScrollChildRect()
    end)
    self.copyLeftButton:SetScript("OnClick", function()
        local text = EreaRpMasterItemEditorFrame.templateContentEditBox:GetText()
        EreaRpMasterItemEditorFrame.defaultContentEditBox:SetText(text)
        EreaRpMasterItemEditorFrame.defaultContentScroll:UpdateScrollChildRect()
    end)

    -- Recipe: Ingredient 1 dropdown
    UIDropDownMenu_SetWidth(200, self.ingredient1Dropdown)
    UIDropDownMenu_Initialize(self.ingredient1Dropdown, function()
        -- "None" option
        UIDropDownMenu_AddButton({
            text  = "(none)",
            value = nil,
            func  = function()
                EreaRpMasterItemEditorFrame.recipeIngredient1Guid = nil
                UIDropDownMenu_SetText("(none)", EreaRpMasterItemEditorFrameIngredient1Dropdown)
            end,
            notCheckable = 1
        })
        local items = EreaRpMasterDB and EreaRpMasterDB.itemLibrary or {}
        for i = 1, table.getn(items) do -- Lua 5.0: table.getn
            local item     = items[i]
            local itemGuid = item.guid
            local itemName = item.name
            UIDropDownMenu_AddButton({
                text  = itemName,
                value = itemGuid,
                func  = function()
                    EreaRpMasterItemEditorFrame.recipeIngredient1Guid = itemGuid
                    UIDropDownMenu_SetText(itemName, EreaRpMasterItemEditorFrameIngredient1Dropdown)
                end,
                notCheckable = 1
            })
        end
    end)

    -- Recipe: Ingredient 2 dropdown
    UIDropDownMenu_SetWidth(200, self.ingredient2Dropdown)
    UIDropDownMenu_Initialize(self.ingredient2Dropdown, function()
        UIDropDownMenu_AddButton({
            text  = "(none)",
            value = nil,
            func  = function()
                EreaRpMasterItemEditorFrame.recipeIngredient2Guid = nil
                UIDropDownMenu_SetText("(none)", EreaRpMasterItemEditorFrameIngredient2Dropdown)
            end,
            notCheckable = 1
        })
        local items = EreaRpMasterDB and EreaRpMasterDB.itemLibrary or {}
        for i = 1, table.getn(items) do -- Lua 5.0: table.getn
            local item     = items[i]
            local itemGuid = item.guid
            local itemName = item.name
            UIDropDownMenu_AddButton({
                text  = itemName,
                value = itemGuid,
                func  = function()
                    EreaRpMasterItemEditorFrame.recipeIngredient2Guid = itemGuid
                    UIDropDownMenu_SetText(itemName, EreaRpMasterItemEditorFrameIngredient2Dropdown)
                end,
                notCheckable = 1
            })
        end
    end)

    -- Recipe: Cinematic dropdown
    UIDropDownMenu_SetWidth(200, self.cinematicDropdown)
    UIDropDownMenu_Initialize(self.cinematicDropdown, function()
        UIDropDownMenu_AddButton({
            text  = "(none)",
            value = nil,
            func  = function()
                EreaRpMasterItemEditorFrame.recipeCinematicKey = nil
                UIDropDownMenu_SetText("(none)", EreaRpMasterItemEditorFrameCinematicDropdown)
            end,
            notCheckable = 1
        })
        local committedDb = EreaRpMasterDB and EreaRpMasterDB.committedDatabase
        local cinematics  = committedDb and committedDb.cinematicLibrary or {}
        for cinKey, cinematic in pairs(cinematics) do
            local ck   = cinKey
            local name = cinematic.speakerName ~= "" and cinematic.speakerName or ck
            UIDropDownMenu_AddButton({
                text  = name,
                value = ck,
                func  = function()
                    EreaRpMasterItemEditorFrame.recipeCinematicKey = ck
                    UIDropDownMenu_SetText(name, EreaRpMasterItemEditorFrameCinematicDropdown)
                end,
                notCheckable = 1
            })
        end
    end)

    -- Recipe: Notify GM checkbox label
    local notifyGmLabel = self.notifyGmCheckButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notifyGmLabel:SetPoint("LEFT", self.notifyGmCheckButton, "RIGHT", 2, 0)
    notifyGmLabel:SetText("Notify GM on combine")

    -- Recipe: Clear recipe button
    self.clearRecipeButton:SetScript("OnClick", function()
        EreaRpMasterItemEditorFrame:ClearRecipe()
    end)

    -- Embed action editor into item editor frame so it moves with it
    local ae = EreaRpMasterActionEditorFrame
    ae:SetParent(EreaRpMasterItemEditorFrame)
    ae:ClearAllPoints()
    ae:SetPoint("TOPLEFT", EreaRpMasterItemEditorFrame, "TOPLEFT", 15, -75)
    ae:SetPoint("BOTTOMRIGHT", EreaRpMasterItemEditorFrame, "BOTTOMRIGHT", -15, 55)
    ae:Hide()  -- hidden until Actions tab is selected

    -- Show default tab
    self:ShowTab(1)
end

-- ============================================================================
-- ShowTab - Switch to the specified tab (1=Definition, 2=Creation, 3=Actions)
-- ============================================================================
function EreaRpMasterItemEditorFrame:ShowTab(index)
    local self = EreaRpMasterItemEditorFrame
    self.activeTab = index

    -- Show/hide panels
    if index == 1 then self.definitionPanel:Show() else self.definitionPanel:Hide() end
    if index == 2 then self.creationPanel:Show()   else self.creationPanel:Hide()   end

    -- Action editor is anchored directly to item editor frame; show/hide explicitly
    if index == 3 then
        EreaRpMasterActionEditorFrame:Show()
    else
        EreaRpMasterActionEditorFrame:Hide()
    end

    -- Tab visual state: active = gold border, dark bg; inactive = gray border, darker bg
    local function SetTabActive(btn)
        btn:SetBackdropColor(0.25, 0.25, 0.25, 1)
        btn:SetBackdropBorderColor(1, 0.82, 0, 1)
    end
    local function SetTabInactive(btn)
        btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
        btn:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end

    if index == 1 then SetTabActive(self.tab1Button) else SetTabInactive(self.tab1Button) end
    if index == 2 then SetTabActive(self.tab2Button) else SetTabInactive(self.tab2Button) end
    if index == 3 then SetTabActive(self.tab3Button) else SetTabInactive(self.tab3Button) end
end

-- ============================================================================
-- ClearRecipe - Reset all recipe fields to empty state
-- ============================================================================
function EreaRpMasterItemEditorFrame:ClearRecipe()
    local self = EreaRpMasterItemEditorFrame
    self.recipeIngredient1Guid = nil
    self.recipeIngredient2Guid = nil
    self.recipeCinematicKey    = nil
    self.notifyGmCheckButton:SetChecked(false)
    UIDropDownMenu_SetText("(none)", self.ingredient1Dropdown)
    UIDropDownMenu_SetText("(none)", self.ingredient2Dropdown)
    UIDropDownMenu_SetText("(none)", self.cinematicDropdown)
end

-- ============================================================================
-- Reset Positions
-- ============================================================================
-- Reset item editor window position to default (center screen)
function EreaRpMasterItemEditorFrame:ResetPositions()
    -- Reset item editor window position
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

-- ============================================================================
-- Open - Show editor populated with item data (or defaults for new)
-- ============================================================================
function EreaRpMasterItemEditorFrame:Open(item, onSaveCallback)
    local self = EreaRpMasterItemEditorFrame

    self.currentItem = item
    self.onSaveCallback = onSaveCallback

    if item then
        -- Editing existing item
        self.currentIcon = item.icon or ""
        self.currentActions = DeepCopyActions(item.actions)
        self.nameEditBox:SetText(item.name or "")
        self.tooltipEditBox:SetText(item.tooltip or "")
        self.handoutEditBox:SetText(item.defaultHandoutText or "")
        self.counterEditBox:SetText(tostring(item.initialCounter or 0))
        self.initialCustomTextEditBox:SetText(item.initialCustomText or "")
        self.defaultContentEditBox:SetText(item.content or "")
        self.templateContentEditBox:SetText(item.contentTemplate or "")

        -- Populate recipe fields
        if item.recipe and item.recipe.ingredients and table.getn(item.recipe.ingredients) >= 2 then -- Lua 5.0: table.getn
            self.recipeIngredient1Guid = item.recipe.ingredients[1]
            self.recipeIngredient2Guid = item.recipe.ingredients[2]
            self.recipeCinematicKey    = item.recipe.cinematicKey ~= "" and item.recipe.cinematicKey or nil
            self.notifyGmCheckButton:SetChecked(item.recipe.notifyGm and true or false)

            -- Set dropdown display text from item library
            local itemLib = EreaRpMasterDB and EreaRpMasterDB.itemLibrary or {}
            local ing1Name = self.recipeIngredient1Guid
            local ing2Name = self.recipeIngredient2Guid
            for i = 1, table.getn(itemLib) do -- Lua 5.0: table.getn
                if itemLib[i].guid == self.recipeIngredient1Guid then ing1Name = itemLib[i].name end
                if itemLib[i].guid == self.recipeIngredient2Guid then ing2Name = itemLib[i].name end
            end
            UIDropDownMenu_SetText(ing1Name, self.ingredient1Dropdown)
            UIDropDownMenu_SetText(ing2Name, self.ingredient2Dropdown)

            -- Set cinematic dropdown text
            if self.recipeCinematicKey then
                local committedDb = EreaRpMasterDB and EreaRpMasterDB.committedDatabase
                local cin = committedDb and committedDb.cinematicLibrary and
                            committedDb.cinematicLibrary[self.recipeCinematicKey]
                local cinName = (cin and cin.speakerName ~= "" and cin.speakerName) or self.recipeCinematicKey
                UIDropDownMenu_SetText(cinName, self.cinematicDropdown)
            else
                UIDropDownMenu_SetText("(none)", self.cinematicDropdown)
            end
        else
            -- No recipe
            self.recipeIngredient1Guid = nil
            self.recipeIngredient2Guid = nil
            self.recipeCinematicKey    = nil
            self.notifyGmCheckButton:SetChecked(false)
            UIDropDownMenu_SetText("(none)", self.ingredient1Dropdown)
            UIDropDownMenu_SetText("(none)", self.ingredient2Dropdown)
            UIDropDownMenu_SetText("(none)", self.cinematicDropdown)
        end
    else
        -- New item — set defaults
        self.currentIcon = "Interface\\Icons\\INV_Misc_Note_01"
        self.currentActions = {}
        self.nameEditBox:SetText("")
        self.tooltipEditBox:SetText("")
        self.handoutEditBox:SetText("You found this item, check /rpplayer")
        self.counterEditBox:SetText("0")
        self.initialCustomTextEditBox:SetText("")
        self.defaultContentEditBox:SetText("")
        self.templateContentEditBox:SetText("")

        -- Clear recipe
        self.recipeIngredient1Guid = nil
        self.recipeIngredient2Guid = nil
        self.recipeCinematicKey    = nil
        self.notifyGmCheckButton:SetChecked(false)
        UIDropDownMenu_SetText("(none)", self.ingredient1Dropdown)
        UIDropDownMenu_SetText("(none)", self.ingredient2Dropdown)
        UIDropDownMenu_SetText("(none)", self.cinematicDropdown)
    end

    -- Update icon texture
    if self.currentIcon ~= "" then
        self.iconTexture:SetTexture(self.currentIcon)
    else
        self.iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Update scroll frames after populating content
    self.defaultContentScroll:UpdateScrollChildRect()
    self.templateContentScroll:UpdateScrollChildRect()

    -- Load actions into embedded action editor
    EreaRpMasterActionEditorFrame:Load(self.currentActions)

    -- Always open on Definition tab
    self:ShowTab(1)

    self:Show()
    self:Raise()
end

-- ============================================================================
-- Close - Hide and clear state
-- ============================================================================
function EreaRpMasterItemEditorFrame:Close()
    local self = EreaRpMasterItemEditorFrame

    EreaRpMasterActionEditorFrame:Hide()
    self:Hide()
    self.currentItem = nil
    self.onSaveCallback = nil
    self.currentIcon = ""
    self.currentActions = {}
    self.recipeIngredient1Guid = nil
    self.recipeIngredient2Guid = nil
    self.recipeCinematicKey    = nil
end

-- ============================================================================
-- Save - Validate, persist, invoke callback
-- ============================================================================
function EreaRpMasterItemEditorFrame:Save()
    local self = EreaRpMasterItemEditorFrame

    -- Flush action editor UI state before reading
    EreaRpMasterActionEditorFrame:SaveCurrentAction()
    self.currentActions = EreaRpMasterActionEditorFrame.actions

    local name = self.nameEditBox:GetText() or ""
    local tooltip = self.tooltipEditBox:GetText() or ""
    local handout = self.handoutEditBox:GetText() or ""
    local counterText = self.counterEditBox:GetText() or "0"
    local initialCustomText = self.initialCustomTextEditBox:GetText() or ""
    local content = self.defaultContentEditBox:GetText() or ""
    local contentTemplate = self.templateContentEditBox:GetText() or ""
    local icon = self.currentIcon or ""

    -- Validate: name required
    if name == "" then
        UIErrorsFrame:AddMessage("Item name is required.", 1, 0.3, 0.3)
        return
    end

    -- Validate: name length
    if string.len(name) > 50 then
        UIErrorsFrame:AddMessage("Item name must be 50 characters or fewer.", 1, 0.3, 0.3)
        return
    end

    -- Validate: tooltip length
    if string.len(tooltip) > 120 then
        UIErrorsFrame:AddMessage("Tooltip must be 120 characters or fewer (currently " .. string.len(tooltip) .. ").", 1, 0.3, 0.3)
        return
    end

    -- Validate: icon path
    if icon ~= "" and string.sub(icon, 1, 10) ~= "Interface\\" then
        UIErrorsFrame:AddMessage("Icon path must start with Interface\\.", 1, 0.3, 0.3)
        return
    end

    -- Coerce counter
    local counter = tonumber(counterText) or 0

    -- Build recipe table (only if both ingredients are set)
    local recipeData = nil
    if self.recipeIngredient1Guid and self.recipeIngredient2Guid then
        recipeData = {
            ingredients  = { self.recipeIngredient1Guid, self.recipeIngredient2Guid },
            cinematicKey = self.recipeCinematicKey or "",
            notifyGm     = self.notifyGmCheckButton:GetChecked() and true or false
        }
    end

    local data = {
        name = name,
        icon = icon,
        tooltip = tooltip,
        defaultHandoutText = handout,
        content = content,
        contentTemplate = contentTemplate,
        initialCounter = counter,
        initialCustomText = initialCustomText,
        actions = self.currentActions,
        recipe = recipeData
    }

    if self.currentItem then
        -- Update existing item
        EreaRpMasterItemLibrary:UpdateItem(self.currentItem.id, data)
    else
        -- Create new item
        EreaRpMasterItemLibrary:CreateItem(data)
    end

    -- Invoke callback
    local cb = self.onSaveCallback
    self:Close()
    if cb then
        cb()
    end
end
