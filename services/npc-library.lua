-- ============================================================================
-- npc-library.lua - Persisted NPC Character Registry
-- ============================================================================
-- PURPOSE: Maintains the list of known NPC characters in EreaRpMasterDB.
--
-- DATA STRUCTURE (in EreaRpMasterDB.npcLibrary):
--   { [playerName] = { name, addedAt, lastSeen, online, hasNpcAddon } }
--
-- An NPC entry is created the first time a character responds to a
-- STATUS_REQUEST with "erea-rp-npc" in their extensions list. The entry
-- persists across sessions even when the character is offline.
-- ============================================================================

EreaRpMasterNpcLibrary = {}

local Log = EreaRpLibraries:Logging("EreaRpMaster")

-- ============================================================================
-- RegisterNpc() - Add or refresh an NPC entry
-- ============================================================================
-- Called when a STATUS_RESPONSE arrives with "erea-rp-npc" in extensions.
-- @param playerName: Character name
-- @param hasNpcAddon: Boolean, true if erea-rp-npc is loaded on the character
-- ============================================================================
function EreaRpMasterNpcLibrary:RegisterNpc(playerName, hasNpcAddon)
    if not playerName or playerName == "" then return end
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return end

    local entry = EreaRpMasterDB.npcLibrary[playerName]
    if not entry then
        EreaRpMasterDB.npcLibrary[playerName] = {
            name        = playerName,
            addedAt     = time(),
            lastSeen    = time(),
            online      = true,
            hasNpcAddon = hasNpcAddon or false,
            tags        = {}
        }
        Log("NpcLibrary: registered " .. playerName)
    else
        entry.lastSeen    = time()
        entry.online      = true
        entry.hasNpcAddon = hasNpcAddon or false
    end
end

-- ============================================================================
-- SetOffline() - Mark a single NPC as offline
-- ============================================================================
function EreaRpMasterNpcLibrary:SetOffline(playerName)
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return end
    local entry = EreaRpMasterDB.npcLibrary[playerName]
    if entry then
        entry.online      = false
        entry.hasNpcAddon = false
    end
end

-- ============================================================================
-- MarkOnlineWithoutAddon() - Mark a known NPC as online but addon not active
-- ============================================================================
function EreaRpMasterNpcLibrary:MarkOnlineWithoutAddon(playerName)
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return end
    local entry = EreaRpMasterDB.npcLibrary[playerName]
    if entry then
        entry.online      = true
        entry.hasNpcAddon = false
    end
end

-- ============================================================================
-- MarkAllOffline() - Mark every known NPC as offline
-- ============================================================================
-- Called at the start of each STATUS_REQUEST cycle so that NPCs who stop
-- responding are correctly shown as offline after the timeout.
-- ============================================================================
function EreaRpMasterNpcLibrary:MarkAllOffline()
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return end
    for _, entry in pairs(EreaRpMasterDB.npcLibrary) do
        entry.online      = false
        entry.hasNpcAddon = false
    end
end

-- ============================================================================
-- RemoveNpc() - Permanently delete an NPC entry
-- ============================================================================
function EreaRpMasterNpcLibrary:RemoveNpc(playerName)
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return end
    EreaRpMasterDB.npcLibrary[playerName] = nil
    Log("NpcLibrary: removed " .. tostring(playerName))
end

-- ============================================================================
-- GetAllNpcs() - Return a sorted array of all NPC entries
-- ============================================================================
-- @returns: array sorted alphabetically by name
-- ============================================================================
function EreaRpMasterNpcLibrary:GetAllNpcs()
    local result = {}
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return result end
    for _, entry in pairs(EreaRpMasterDB.npcLibrary) do
        table.insert(result, entry)
    end
    table.sort(result, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return result
end

-- ============================================================================
-- GetNpc() - Return a single NPC entry by name, or nil
-- ============================================================================
function EreaRpMasterNpcLibrary:GetNpc(playerName)
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return nil end
    return EreaRpMasterDB.npcLibrary[playerName]
end

-- ============================================================================
-- TAG MANAGEMENT
-- ============================================================================

-- ============================================================================
-- AddTag() - Add a tag to an NPC (normalized: lowercase, trimmed, no dupes)
-- ============================================================================
function EreaRpMasterNpcLibrary:AddTag(playerName, tag)
    if not playerName or playerName == "" then return end
    if not tag or tag == "" then return end
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return end

    local entry = EreaRpMasterDB.npcLibrary[playerName]
    if not entry then return end
    if not entry.tags then entry.tags = {} end

    local normalized = string.lower(string.gsub(tag, "^%s*(.-)%s*$", "%1"))
    if normalized == "" then return end

    -- Check for duplicates
    for i = 1, table.getn(entry.tags) do  -- Lua 5.0: no # operator
        if entry.tags[i] == normalized then return end
    end

    table.insert(entry.tags, normalized)
    Log("NpcLibrary: added tag \"" .. normalized .. "\" to " .. playerName)
end

-- ============================================================================
-- RemoveTag() - Remove a tag from an NPC
-- ============================================================================
function EreaRpMasterNpcLibrary:RemoveTag(playerName, tag)
    if not playerName or playerName == "" then return end
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return end

    local entry = EreaRpMasterDB.npcLibrary[playerName]
    if not entry or not entry.tags then return end

    for i = 1, table.getn(entry.tags) do  -- Lua 5.0: no # operator
        if entry.tags[i] == tag then
            table.remove(entry.tags, i)
            Log("NpcLibrary: removed tag \"" .. tag .. "\" from " .. playerName)
            return
        end
    end
end

-- ============================================================================
-- GetTags() - Return the tags array for an NPC, or empty table
-- ============================================================================
function EreaRpMasterNpcLibrary:GetTags(playerName)
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return {} end
    local entry = EreaRpMasterDB.npcLibrary[playerName]
    if not entry or not entry.tags then return {} end
    return entry.tags
end

-- ============================================================================
-- GetOnlineNpcsByTag() - Find online NPCs (with addon) matching a tag
-- ============================================================================
function EreaRpMasterNpcLibrary:GetOnlineNpcsByTag(tag)
    local result = {}
    if not tag or tag == "" then return result end
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return result end

    local normalized = string.lower(string.gsub(tag, "^%s*(.-)%s*$", "%1"))

    for _, entry in pairs(EreaRpMasterDB.npcLibrary) do
        if entry.online and entry.hasNpcAddon and entry.tags then
            for i = 1, table.getn(entry.tags) do  -- Lua 5.0: no # operator
                if entry.tags[i] == normalized then
                    table.insert(result, entry)
                    break
                end
            end
        end
    end

    return result
end

-- ============================================================================
-- GetAllUniqueTags() - Collect all unique tags across all NPCs, sorted
-- ============================================================================
function EreaRpMasterNpcLibrary:GetAllUniqueTags()
    local result = {}
    if not EreaRpMasterDB or not EreaRpMasterDB.npcLibrary then return result end

    local seen = {}
    for _, entry in pairs(EreaRpMasterDB.npcLibrary) do
        if entry.tags then
            for i = 1, table.getn(entry.tags) do  -- Lua 5.0: no # operator
                local t = entry.tags[i]
                if not seen[t] then
                    seen[t] = true
                    table.insert(result, t)
                end
            end
        end
    end
    table.sort(result)
    return result
end
