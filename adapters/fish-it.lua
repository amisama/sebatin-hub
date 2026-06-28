--[[
    ============================================
    ZetsuTrackStat — Fish It Adapter v1.0
    ============================================
    Data source: Replion.Client:WaitReplion("Data")
    Catalog:     ReplicatedStorage.Items (ModuleScript per item)

    Contract: return { gameName, collect(env) }
      env.GUI      — GUI.setLine/setStatus
      env.player   — LocalPlayer
      env.Http     — (unused, adapter only collects)
      env.CONFIG   — (unused)

    collect() returns:
      { stats, inventory, currency, progress, serverData }

    Fish inventory format (compressed arrays):
      inventory.fish = {
        {id, tier, weight, mutation, shiny},  -- per fish
        ...
      }
      inventory.catalog = { [id] = {name, tier, icon} }  -- sent once, backend caches
      inventory.equippedRod = {name, tier, icon} or nil
      inventory.fishCount, inventory.totalWeight
    ============================================
]]

-- ============================================
-- SERVICES
-- ============================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================
-- HELPERS
-- ============================================
local function tierName(t)
    if t == nil then return "Unknown" end
    if t <= 1 then return "Common"
    elseif t == 2 then return "Uncommon"
    elseif t == 3 then return "Rare"
    elseif t == 4 then return "Epic"
    elseif t == 5 then return "Legendary"
    elseif t == 6 then return "Mythic"
    elseif t == 7 then return "Exalted"
    elseif t == 8 then return "???"
    elseif t <= 90 then return "Event"
    elseif t <= 95 then return "Special"
    else return "Exotic"
    end
end

local function tableCount(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

-- ============================================
-- BUILD CATALOG from ReplicatedStorage.Items
-- id -> {name, tier, icon, type}
-- ============================================
local function buildCatalog()
    local catalog = {}
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    if not itemsFolder then return catalog end

    for _, subfolder in ipairs(itemsFolder:GetChildren()) do
        if subfolder:IsA("Folder") then
            for _, mod in ipairs(subfolder:GetDescendants()) do
                if mod:IsA("ModuleScript") then
                    local ok, d = pcall(require, mod)
                    if ok and type(d) == "table" then
                        local src = d.Data or d
                        local id = src.Id
                        if id then
                            catalog[id] = {
                                name = src.Name or mod.Name or "UNKNOWN",
                                tier = src.Tier,
                                icon = src.Icon,
                                itemType = src.Type or d.Type,
                            }
                        end
                    end
                end
            end
        end
    end

    return catalog
end

-- ============================================
-- MAIN COLLECT
-- ============================================
local function collect(env)
    local GUI = env.GUI
    local player = env.player

    local result = {
        stats = {},
        inventory = {},
        currency = {},
        progress = {},
        serverData = {},
    }

    -- 1. Load Replion
    GUI.setLine("fi_step", "[FI] Loading Replion...", Color3.fromRGB(255, 200, 0))

    local packages = ReplicatedStorage:FindFirstChild("Packages")
    local replionMod = packages and packages:FindFirstChild("Replion")
    if not replionMod then
        GUI.setLine("fi_step", "[FI] Replion module not found", Color3.fromRGB(255, 60, 60))
        return result
    end

    local ok, Replion = pcall(require, replionMod)
    if not ok or not Replion then
        GUI.setLine("fi_step", "[FI] Failed to require Replion", Color3.fromRGB(255, 60, 60))
        return result
    end

    local PD = Replion.Client:WaitReplion("Data")
    if not PD then
        GUI.setLine("fi_step", "[FI] WaitReplion('Data') failed", Color3.fromRGB(255, 60, 60))
        return result
    end

    GUI.setLine("fi_step", "[FI] Replion OK", Color3.fromRGB(100, 255, 100))

    local raw = PD.Data or {}
    local inv = nil
    local okInv, invResult = pcall(function() return PD:GetExpect("Inventory") end)
    if okInv then inv = invResult end

    -- 2. Build catalog (one-time per collect)
    GUI.setLine("fi_cat", "[FI] Building catalog...", Color3.fromRGB(255, 200, 0))
    local catalog = buildCatalog()
    GUI.setLine("fi_cat", "[FI] Catalog: " .. tableCount(catalog) .. " items", Color3.fromRGB(100, 255, 100))

    -- ========================================
    -- STATS (from raw player data)
    -- ========================================
    result.stats = {
        Level = raw.Level or 0,
        Experience = raw.XP or 0,
        TotalFishCaught = raw.TotalFishCaught or 0,
    }

    -- CaughtFishMastery -> total caught + species count
    local mastery = raw.CaughtFishMastery
    if mastery and type(mastery) == "table" then
        local totalCaught = 0
        local speciesCount = 0
        for _, data in pairs(mastery) do
            if type(data) == "table" and data.Count then
                totalCaught = totalCaught + (data.Count or 0)
                speciesCount = speciesCount + 1
            end
        end
        result.stats.TotalFishCaught = totalCaught
        result.stats.SpeciesCaught = speciesCount
    end

    -- leaderstats (Caught, Rarest Fish)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("ValueBase") then
                result.stats[child.Name] = child.Value
            end
        end
    end

    -- ========================================
    -- CURRENCY (Coins from raw data)
    -- ========================================
    result.currency = {
        Coins = raw.Coins or 0,
    }
    if raw.Gems then result.currency.Gems = raw.Gems end
    if raw.Tokens then result.currency.Tokens = raw.Tokens end

    -- ========================================
    -- INVENTORY: Fish (compressed arrays)
    -- ========================================
    local fishList = {}
    local totalWeight = 0
    local mutationCounts = {}
    local shinyCount = 0

    if inv and inv.Items then
        for _, item in ipairs(inv.Items) do
            if type(item) == "table" then
                local id = item.Id
                local meta = item.Metadata or {}
                local weight = meta.Weight or 0
                local isShiny = meta.Shiny == true
                local mutation = meta.VariantId -- nil if no mutation

                if weight > 0 then
                    local info = catalog[id]
                    local tier = info and info.tier or 0

                    -- Compressed: [id, tier, weight, mutation, shiny]
                    table.insert(fishList, {
                        id, tier, weight, mutation or "", isShiny and 1 or 0
                    })

                    totalWeight = totalWeight + weight
                    if mutation and mutation ~= "" then
                        mutationCounts[mutation] = (mutationCounts[mutation] or 0) + 1
                    end
                    if isShiny then shinyCount = shinyCount + 1 end
                end
            end
        end
    end

    -- Sort by weight descending (heaviest first)
    table.sort(fishList, function(a, b) return (a[3] or 0) > (b[3] or 0) end)

    -- ========================================
    -- INVENTORY: Equipped Rod
    -- ========================================
    local equippedUUIDs = {}
    local ei = raw.EquippedItems
    if ei then
        for _, uuid in ipairs(ei) do
            if type(uuid) == "string" and #uuid > 0 then
                equippedUUIDs[uuid] = true
            end
        end
    end

    local equippedRod = nil
    if inv and inv["Fishing Rods"] then
        for _, rod in ipairs(inv["Fishing Rods"]) do
            if type(rod) == "table" then
                local uuid = rod.UUID
                if uuid and equippedUUIDs[uuid] then
                    local info = catalog[rod.Id]
                    equippedRod = {
                        id = rod.Id,
                        name = info and info.name or ("ID:" .. tostring(rod.Id)),
                        tier = info and info.tier,
                        tierName = tierName(info and info.tier),
                        icon = info and info.icon,
                    }
                    break
                end
            end
        end
    end

    -- ========================================
    -- INVENTORY: Other categories (baits, charms, pets, etc.)
    -- ========================================
    local otherItems = {}
    local categoryNames = {"Baits", "Charms", "Pets", "Enchant Stones", "Items", "Emotes"}
    for _, catName in ipairs(categoryNames) do
        if inv and inv[catName] then
            for _, item in ipairs(inv[catName]) do
                if type(item) == "table" and item.Id then
                    local info = catalog[item.Id]
                    table.insert(otherItems, {
                        name = info and info.name or ("ID:" .. tostring(item.Id)),
                        type = catName,
                        category = string.lower(catName:gsub(" ", "_")),
                        tier = info and info.tier,
                        count = item.Count or item.Quantity or 1,
                    })
                end
            end
        end
    end

    -- Assemble inventory
    result.inventory = {
        fish = fishList,
        fishCount = #fishList,
        totalWeight = totalWeight,
        equippedRod = equippedRod,
        catalog = catalog,
        otherItems = otherItems,
    }

    -- ========================================
    -- PROGRESS
    -- ========================================
    result.progress = {
        Level = result.stats.Level,
        TotalFishCaught = result.stats.TotalFishCaught or 0,
        SpeciesCaught = result.stats.SpeciesCaught or 0,
        FishCount = #fishList,
        TotalWeight = totalWeight,
        ShinyCount = shinyCount,
        MutationSummary = mutationCounts,
    }

    if equippedRod then
        result.progress.EquippedRod = equippedRod.name
        result.progress.EquippedRodTier = equippedRod.tierName
    end

    -- ========================================
    -- SERVER DATA
    -- ========================================
    result.serverData = {
        jobId = game.JobId,
        placeId = game.PlaceId,
    }

    GUI.setLine("fi_step", "[FI] Done: " .. #fishList .. " fish, " .. tostring(math.floor(totalWeight)) .. " kg", Color3.fromRGB(100, 255, 100))

    return result
end

-- ============================================
-- RETURN ADAPTER TABLE
-- ============================================
return {
    gameName = "fish_it",
    collect = collect,
}
