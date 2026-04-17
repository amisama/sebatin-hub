--[[
    ============================================
    SEBATIN HUB v3.0 — Roblox Stats Tracker
    ============================================
    Multi-game tracker dengan floating dot GUI.
    Auto-detect game via PlaceId, load adapter.
    
    Compatible: Codex, Delta, Fluxus, Synapse, dll
    ============================================
]]

-- ============================================
-- SERVICES
-- ============================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- CONFIG — dari _G.Config
-- ============================================
-- User set _G.Config sebelum loadstring:
--   _G.Config = { UserID="xxx", Note="Pc" }
--
-- discord_id gak perlu — otomatis dari database (Discord OAuth).
-- Atau langsung edit di bawah untuk testing manual.
-- ============================================
local userConfig = _G.Config or {}

local CONFIG = {
    -- Server URL (ganti ke VPS nanti)
    API_URL = userConfig.API_URL or "https://chicago-greatly-learning-inputs.trycloudflare.com/api",

    -- Auth
    USER_ID = userConfig.UserID or nil,
    NOTE = userConfig.Note or "Unknown",

    -- Tracker settings
    SEND_INTERVAL = userConfig.SEND_INTERVAL or 60,
    MAX_RETRIES = 3,
    RETRY_DELAY = 5,
    DEBUG = true,
}

-- ============================================
-- GUI — Floating Dot + Expandable Panel
-- ============================================
-- Dot kecil bulat yang bisa digeser-geser.
-- Tap/click dot = expand panel detail.
-- Warna dot = status (merah=brand, hijau=live, kuning=sending, merah=error).
-- ============================================
local GUI = {}
local guiLog = {}

-- Brand colors
local BRAND_RED = Color3.fromRGB(239, 68, 68)
local BRAND_DARK = Color3.fromRGB(15, 15, 20)
local COLOR_LIVE = Color3.fromRGB(60, 255, 120)
local COLOR_SEND = Color3.fromRGB(255, 200, 0)
local COLOR_ERR = Color3.fromRGB(255, 60, 60)
local COLOR_INIT = Color3.fromRGB(255, 200, 0)

function GUI.create()
    local old = LocalPlayer.PlayerGui:FindFirstChild("SebatInGui")
    if old then old:Destroy() end

    local UserInputService = game:GetService("UserInputService")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SebatInGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- ==========================================
    -- FLOATING DOT (draggable, always visible)
    -- ==========================================
    local dotSize = 36
    local dot = Instance.new("ImageButton")
    dot.Name = "FloatingDot"
    dot.Size = UDim2.new(0, dotSize, 0, dotSize)
    dot.Position = UDim2.new(1, -(dotSize + 12), 1, -(dotSize + 12))
    dot.BackgroundColor3 = BRAND_RED
    dot.BackgroundTransparency = 0.1
    dot.BorderSizePixel = 0
    dot.AutoButtonColor = false
    dot.Image = ""
    dot.Parent = screenGui

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    local dotStroke = Instance.new("UIStroke")
    dotStroke.Color = Color3.fromRGB(255, 255, 255)
    dotStroke.Thickness = 1.5
    dotStroke.Transparency = 0.7
    dotStroke.Parent = dot

    -- "S" letter inside dot (SebatIn)
    local dotLabel = Instance.new("TextLabel")
    dotLabel.Size = UDim2.new(1, 0, 1, 0)
    dotLabel.BackgroundTransparency = 1
    dotLabel.Text = "S"
    dotLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    dotLabel.TextSize = 16
    dotLabel.Font = Enum.Font.GothamBold
    dotLabel.Parent = dot

    -- Pulse animation on dot (subtle glow)
    local pulseRing = Instance.new("Frame")
    pulseRing.Name = "PulseRing"
    pulseRing.Size = UDim2.new(1, 8, 1, 8)
    pulseRing.Position = UDim2.new(0, -4, 0, -4)
    pulseRing.BackgroundTransparency = 1
    pulseRing.BorderSizePixel = 0
    pulseRing.Parent = dot
    Instance.new("UICorner", pulseRing).CornerRadius = UDim.new(1, 0)
    local pulseStroke = Instance.new("UIStroke")
    pulseStroke.Color = BRAND_RED
    pulseStroke.Thickness = 2
    pulseStroke.Transparency = 0.5
    pulseStroke.Parent = pulseRing

    -- Pulse tween
    local function startPulse()
        task.spawn(function()
            while dot and dot.Parent do
                local tweenOut = TweenService:Create(pulseStroke, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Transparency = 1})
                local tweenIn = TweenService:Create(pulseStroke, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Transparency = 0.5})
                tweenOut:Play()
                tweenOut.Completed:Wait()
                tweenIn:Play()
                tweenIn.Completed:Wait()
            end
        end)
    end
    startPulse()

    -- Dot dragging (touch + mouse)
    local dotDragging = false
    local dotDragStart, dotStartPos
    local dotMoved = false

    dot.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dotDragging = true
            dotDragStart = input.Position
            dotStartPos = dot.Position
            dotMoved = false
        end
    end)
    dot.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dotDragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dotDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dotDragStart
            if delta.Magnitude > 5 then dotMoved = true end
            dot.Position = UDim2.new(dotStartPos.X.Scale, dotStartPos.X.Offset + delta.X, dotStartPos.Y.Scale, dotStartPos.Y.Offset + delta.Y)
        end
    end)

    -- ==========================================
    -- EXPANDABLE PANEL (hidden by default)
    -- ==========================================
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 300, 0, 200)
    panel.Position = UDim2.new(1, -310, 1, -(dotSize + 12 + 210))
    panel.BackgroundColor3 = BRAND_DARK
    panel.BackgroundTransparency = 0.1
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Parent = screenGui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 10)
    panelCorner.Parent = panel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = BRAND_RED
    panelStroke.Thickness = 1
    panelStroke.Transparency = 0.5
    panelStroke.Parent = panel

    -- Panel title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 24)
    title.Position = UDim2.new(0, 8, 0, 6)
    title.BackgroundTransparency = 1
    title.RichText = true
    title.Text = '<font color="#ef4444">Sebat</font><font color="#ffffff">In</font> <font color="#888888">Hub v3.0</font>'
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    -- Status indicator in panel
    GUI.statusDot = Instance.new("Frame")
    GUI.statusDot.Size = UDim2.new(0, 8, 0, 8)
    GUI.statusDot.Position = UDim2.new(1, -50, 0, 14)
    GUI.statusDot.BackgroundColor3 = COLOR_INIT
    GUI.statusDot.BorderSizePixel = 0
    GUI.statusDot.Parent = panel
    Instance.new("UICorner", GUI.statusDot).CornerRadius = UDim.new(1, 0)

    GUI.statusLabel = Instance.new("TextLabel")
    GUI.statusLabel.Size = UDim2.new(0, 40, 0, 24)
    GUI.statusLabel.Position = UDim2.new(1, -40, 0, 6)
    GUI.statusLabel.BackgroundTransparency = 1
    GUI.statusLabel.Text = "INIT"
    GUI.statusLabel.TextColor3 = COLOR_INIT
    GUI.statusLabel.TextSize = 10
    GUI.statusLabel.Font = Enum.Font.GothamBold
    GUI.statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    GUI.statusLabel.Parent = panel

    -- Divider
    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -16, 0, 1)
    divider.Position = UDim2.new(0, 8, 0, 30)
    divider.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    divider.BorderSizePixel = 0
    divider.Parent = panel

    -- Stats display area (scrolling)
    GUI.statsFrame = Instance.new("ScrollingFrame")
    GUI.statsFrame.Size = UDim2.new(1, -12, 1, -36)
    GUI.statsFrame.Position = UDim2.new(0, 6, 0, 34)
    GUI.statsFrame.BackgroundTransparency = 1
    GUI.statsFrame.BorderSizePixel = 0
    GUI.statsFrame.ScrollBarThickness = 3
    GUI.statsFrame.ScrollBarImageColor3 = BRAND_RED
    GUI.statsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    GUI.statsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    GUI.statsFrame.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = GUI.statsFrame

    -- Panel dragging
    local panelDragging, panelDragStart, panelStartPos
    panel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            panelDragging = true
            panelDragStart = input.Position
            panelStartPos = panel.Position
        end
    end)
    panel.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            panelDragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if panelDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - panelDragStart
            panel.Position = UDim2.new(panelStartPos.X.Scale, panelStartPos.X.Offset + delta.X, panelStartPos.Y.Scale, panelStartPos.Y.Offset + delta.Y)
        end
    end)

    -- Toggle panel on dot click (not drag)
    dot.MouseButton1Click:Connect(function()
        if not dotMoved then
            panel.Visible = not panel.Visible
        end
    end)

    screenGui.Parent = LocalPlayer.PlayerGui
    GUI.dot = dot
    GUI.panel = panel
    GUI.pulseStroke = pulseStroke
    return screenGui
end

-- Update dot color to reflect current status
function GUI.setDotColor(color)
    if GUI.dot then
        GUI.dot.BackgroundColor3 = color
    end
    if GUI.pulseStroke then
        GUI.pulseStroke.Color = color
    end
end

function GUI.setStatus(text, color)
    if GUI.statusLabel then
        GUI.statusLabel.Text = text
        GUI.statusLabel.TextColor3 = color
    end
    if GUI.statusDot then
        GUI.statusDot.BackgroundColor3 = color
    end
    -- Also update floating dot color
    GUI.setDotColor(color)
end

local lineOrder = 0
function GUI.setLine(key, text, color)
    color = color or Color3.fromRGB(200, 200, 200)

    if not GUI.statsFrame then return end

    -- Update existing or create new
    local existing = GUI.statsFrame:FindFirstChild("line_" .. key)
    if existing then
        existing.Text = text
        existing.TextColor3 = color
        return
    end

    lineOrder = lineOrder + 1
    local label = Instance.new("TextLabel")
    label.Name = "line_" .. key
    label.Size = UDim2.new(1, -4, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextSize = 11
    label.Font = Enum.Font.RobotoMono
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = lineOrder
    label.Parent = GUI.statsFrame
end

function GUI.clearLines()
    if not GUI.statsFrame then return end
    for _, child in ipairs(GUI.statsFrame:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    lineOrder = 0
end

-- ============================================
-- HTTP MODULE
-- ============================================
local Http = {}

function Http.post(endpoint, data)
    local url = CONFIG.API_URL .. endpoint
    local jsonData = HttpService:JSONEncode(data)

    -- Detect which HTTP function is available
    local httpFunc = nil
    local httpName = "none"
    if request then
        httpFunc = request; httpName = "request"
    elseif http_request then
        httpFunc = http_request; httpName = "http_request"
    elseif syn and syn.request then
        httpFunc = syn.request; httpName = "syn.request"
    elseif http and http.request then
        httpFunc = http.request; httpName = "http.request"
    elseif fluxus and fluxus.request then
        httpFunc = fluxus.request; httpName = "fluxus.request"
    end

    if not httpFunc then
        GUI.setLine("http_err", "ERROR: No HTTP function found!", COLOR_ERR)
        GUI.setLine("http_avail", "request=" .. tostring(request ~= nil) .. " http_request=" .. tostring(http_request ~= nil), Color3.fromRGB(255, 100, 100))
        return false, nil
    end

    GUI.setLine("http_func", "HTTP: " .. httpName, Color3.fromRGB(150, 150, 150))
    GUI.setLine("http_url", "URL: " .. url, Color3.fromRGB(150, 150, 150))

    local lastErr = ""
    for attempt = 1, CONFIG.MAX_RETRIES do
        GUI.setLine("http_attempt", "Attempt " .. attempt .. "/" .. CONFIG.MAX_RETRIES .. "...", COLOR_SEND)

        local success, response = pcall(function()
            return httpFunc({
                Url = url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-Tracker-Version"] = "3.0",
                },
                Body = jsonData,
            })
        end)

        if success and response then
            local code = response.StatusCode or response.status_code or 0
            GUI.setLine("http_code", "Response: " .. tostring(code), Color3.fromRGB(150, 150, 150))
            if code == 200 or code == 201 then
                return true, response
            else
                lastErr = "HTTP " .. tostring(code) .. ": " .. tostring(response.Body or response.body or "")
            end
        elseif not success then
            lastErr = tostring(response)
            GUI.setLine("http_pcall_err", "pcall error: " .. string.sub(lastErr, 1, 80), Color3.fromRGB(255, 80, 80))
        end

        if attempt < CONFIG.MAX_RETRIES then
            task.wait(CONFIG.RETRY_DELAY)
        end
    end

    GUI.setLine("http_final_err", "FAILED: " .. string.sub(lastErr, 1, 100), COLOR_ERR)
    return false, nil
end

-- ============================================
-- GAME DETECTOR
-- ============================================
local GameDetector = {}

GameDetector.GAME_MAP = {
    -- Sailor Piece (dari scan: PlaceId 77747658251236)
    [77747658251236] = "sailor_piece",

    -- Blox Fruits
    [2753915549] = "blox_fruits",

    -- Fish It!
    [16384073498] = "fish_it",

    -- Grow a Garden
    [126884695634066] = "grow_a_garden",

    -- King Legacy
    [4520749081] = "king_legacy",

    -- Adopt Me
    [920587237] = "adopt_me",

    -- Pet Simulator X
    [6284583030] = "pet_sim_x",
}

function GameDetector.detect()
    local placeId = game.PlaceId
    local gameName = GameDetector.GAME_MAP[placeId]

    if gameName then
        return gameName, placeId
    end

    -- Fallback
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(placeId)
    end)

    return nil, placeId
end

-- ============================================
-- ADAPTER REGISTRY
-- ============================================
local AdapterRegistry = {}
AdapterRegistry.adapters = {}

function AdapterRegistry.register(name, adapter)
    AdapterRegistry.adapters[name] = adapter
end

function AdapterRegistry.get(name)
    return AdapterRegistry.adapters[name]
end

-- ============================================
-- BASE ADAPTER
-- ============================================
local BaseAdapter = {}
BaseAdapter.__index = BaseAdapter

function BaseAdapter.new(gameName)
    local self = setmetatable({}, BaseAdapter)
    self.gameName = gameName
    return self
end

function BaseAdapter:getStats() return {} end
function BaseAdapter:getInventory(_serverData) return {} end
function BaseAdapter:getCurrency() return {} end
function BaseAdapter:getProgress() return {} end
function BaseAdapter:getServerData() return nil end

function BaseAdapter:collectAll()
    local data = {stats = {}, inventory = {}, currency = {}, progress = {}, serverData = nil}

    local steps = {
        {"inventory",  function() data.inventory = self:getInventory(nil) end},  -- fires RequestInventory first (triggers UpdateEquipped too)
        {"serverData", function() data.serverData = self:getServerData() end},   -- collects all RF data + catches UpdateEquipped
        {"stats",      function() data.stats = self:getStats() end},
        {"currency",   function() data.currency = self:getCurrency() end},
        {"progress",   function() data.progress = self:getProgress() end},
    }

    for i, step in ipairs(steps) do
        local stepName = step[1]
        local stepFn   = step[2]
        GUI.setLine("collect_step", "Collect [" .. i .. "/" .. #steps .. "] " .. stepName .. "...", Color3.fromRGB(255, 200, 0))
        local ok, err = pcall(stepFn)
        if not ok then
            GUI.setLine("collect_err_" .. stepName, "WARN: " .. stepName .. " failed: " .. string.sub(tostring(err), 1, 60), Color3.fromRGB(255, 150, 50))
        end
    end

    GUI.setLine("collect_step", "Collect done", COLOR_LIVE)
    return data
end

-- ============================================
-- SAILOR PIECE ADAPTER (ACCURATE - from scan)
-- ============================================
--[[
    Confirmed data paths from explorer scan:
    
    leaderstats/
      Bounty (IntValue) = 540007
    
    Data/
      Level (IntValue) = 13000
      Money (IntValue) = 220091798
      Gems (IntValue) = 40605
      Experience (IntValue) = 402710237
      StatPoints (IntValue) = 0
    
    Backpack/
      Combat (Tool)
    
    Character/
      Soul Reaper (Tool) - equipped
      Swordblessed (Accessory) - equipped
    
    Key RemoteFunctions:
      ReplicatedStorage.Remotes.GetPlayerData -> full player data
      ReplicatedStorage.Remotes.GetTotalStats -> stat totals
      ReplicatedStorage.Remotes.GetStorageData -> storage items
      ReplicatedStorage.RemoteFunctions.GetArtifactData -> artifacts
      ReplicatedStorage.RemoteEvents.GetPlayerStats -> player stats
]]

local SailorPieceAdapter = setmetatable({}, {__index = BaseAdapter})
SailorPieceAdapter.__index = SailorPieceAdapter

function SailorPieceAdapter.new()
    return setmetatable(BaseAdapter.new("sailor_piece"), SailorPieceAdapter)
end

function SailorPieceAdapter:getStats()
    local stats = {}

    -- Data folder (CONFIRMED: Player.Data.*)
    local dataFolder = LocalPlayer:FindFirstChild("Data")
    if dataFolder then
        for _, child in ipairs(dataFolder:GetChildren()) do
            if child:IsA("IntValue") or child:IsA("NumberValue") or child:IsA("StringValue") then
                stats[child.Name] = child.Value
            end
        end
    end

    -- leaderstats (CONFIRMED: leaderstats.Bounty)
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("IntValue") or child:IsA("NumberValue") then
                stats[child.Name] = child.Value
            end
        end
    end

    return stats
end

function SailorPieceAdapter:getCurrency()
    local currency = {}

    -- From Data folder (CONFIRMED paths)
    local dataFolder = LocalPlayer:FindFirstChild("Data")
    if dataFolder then
        local money = dataFolder:FindFirstChild("Money")
        local gems = dataFolder:FindFirstChild("Gems")
        if money then currency.Money = money.Value end
        if gems then currency.Gems = gems.Value end
    end

    -- From leaderstats (CONFIRMED)
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local bounty = leaderstats:FindFirstChild("Bounty")
        if bounty then currency.Bounty = bounty.Value end
    end

    return currency
end

function SailorPieceAdapter:getInventory(_serverData)
    local inventory = {}

    -- Load ItemImageConfig for real image IDs per item
    local imageConfig = nil
    pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        if modules then
            local cfg = modules:FindFirstChild("ItemImageConfig")
            if cfg and cfg:IsA("ModuleScript") then
                imageConfig = require(cfg)
            end
        end
    end)

    -- Helper: get real image for an item name
    local function getRealImage(itemName)
        if imageConfig and imageConfig.Images and type(imageConfig.Images) == "table" then
            local img = imageConfig.Images[itemName]
            if img and type(img) == "string" and img ~= "" and img ~= "rbxassetid://0" then
                return img
            end
        end
        return nil
    end

    -- 1. Fire RequestInventory and listen for UpdateInventory responses
    --    This is how the game sends inventory data: FireServer -> OnClientEvent
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotes then return end

        local reqInv = remotes:FindFirstChild("RequestInventory")
        local updateInv = remotes:FindFirstChild("UpdateInventory")
        if not reqInv or not updateInv then return end

        local received = {}
        local conn = updateInv.OnClientEvent:Connect(function(category, items)
            if type(category) == "string" and type(items) == "table" then
                received[category] = items
            end
        end)

        -- Fire request
        reqInv:FireServer()

        -- Wait up to 5 seconds for all categories to arrive
        -- Game sends: Items, Melee, Sword, Power, Accessories, Runes, Auras, Cosmetics
        local start = tick()
        while (tick() - start) < 5 do
            task.wait(0.3)
            -- Stop early if we got the main categories
            if received["Items"] and received["Sword"] and received["Accessories"] then
                task.wait(0.5) -- small extra wait for stragglers
                break
            end
        end

        conn:Disconnect()

        -- Process all received categories
        for category, items in pairs(received) do
            for _, item in ipairs(items) do
                if type(item) == "table" and item.name then
                    local entry = {
                        name = item.name,
                        type = category:lower(),
                        equipped = false,
                        count = item.quantity or 1,
                    }
                    -- Image: prefer ItemImageConfig (accurate), fallback to event image
                    local realImg = getRealImage(item.name)
                    if realImg then
                        entry.image = realImg
                    elseif item.image and item.image ~= "" and item.image ~= "rbxassetid://0" then
                        entry.image = item.image
                    end
                    -- Sword blessing level
                    if item.blessingLevel and item.blessingLevel > 0 then
                        entry.blessing = item.blessingLevel
                    end
                    -- Accessory enchant level
                    if item.enchantLevel and item.enchantLevel > 0 then
                        entry.enchant = item.enchantLevel
                    end
                    table.insert(inventory, entry)
                end
            end
        end
    end)

    -- 2. Character equipped items (tools + accessories currently worn)
    local character = LocalPlayer.Character
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") then
                local entry = {name = item.Name, type = "equipped_weapon", equipped = true}
                local img = getRealImage(item.Name)
                if img then entry.image = img end
                table.insert(inventory, entry)
            elseif item:IsA("Accessory") then
                local entry = {name = item.Name, type = "equipped_accessory", equipped = true}
                local img = getRealImage(item.Name)
                if img then entry.image = img end
                table.insert(inventory, entry)
            end
        end
    end

    -- 3. Title from BasicStatsCurrencyAndButtonsUI
    pcall(function()
        local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not PlayerGui then return end
        local statsUI = PlayerGui:FindFirstChild("BasicStatsCurrencyAndButtonsUI")
        if not statsUI then return end
        local mainFrame = statsUI:FindFirstChild("MainFrame")
        if not mainFrame then return end
        local levelInfo = mainFrame:FindFirstChild("LevelInfo")
        if not levelInfo then return end
        local titleLabel = levelInfo:FindFirstChild("Title")
        if titleLabel and titleLabel.Text and titleLabel.Text ~= "" then
            local title = titleLabel.Text:match("Title: (.+)") or titleLabel.Text
            table.insert(inventory, {name = title, type = "title", equipped = true})
        end
    end)

    return inventory
end

function SailorPieceAdapter:getServerData()
    -- Collect ALL detailed data via FireServer + RemoteFunction listeners.
    -- Pattern: fire request -> listen OnClientEvent -> collect response.
    -- RemoteFunctions: use task.spawn with timeout to avoid hang.
    local serverData = {}
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")

    -- Helper: invoke RemoteFunction with timeout (task.spawn based)
    local function invokeWithTimeout(rf, timeout)
        timeout = timeout or 5
        local result = nil
        local done = false
        task.spawn(function()
            local ok, data = pcall(function() return rf:InvokeServer() end)
            if ok then result = data end
            done = true
        end)
        local s = tick()
        while not done and (tick() - s) < timeout do task.wait(0.2) end
        return result
    end

    -- Helper: listen for a single OnClientEvent response
    local function listenOnce(event, timeout)
        timeout = timeout or 5
        local result = nil
        local conn
        conn = event.OnClientEvent:Connect(function(...)
            result = {...}
            conn:Disconnect()
        end)
        local s = tick()
        while not result and (tick() - s) < timeout do task.wait(0.2) end
        if result == nil then pcall(function() conn:Disconnect() end) end
        return result
    end

    -- 1. GetPlayerStats (RemoteFunction in RemoteEvents)
    pcall(function()
        if not remoteEvents then return end
        local rf = remoteEvents:FindFirstChild("GetPlayerStats")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                serverData.playerStats = {
                    level = data.Level,
                    experience = data.Experience,
                    totalXP = data.TotalXP,
                    maxHealth = data.MaxHealth,
                    statPoints = data.StatPoints,
                    rank = data.Rank,
                    trait = data.Trait,
                    xpRequired = data.xpRequired,
                    stats = data.Stats, -- {Sword, Defense, Melee, Power}
                    currency = data.Currency, -- {Money, Bounty, Gems}
                    runeProgression = data.RuneProgression,
                    equippedRace = data.Inventory and data.Inventory.Equipped and data.Inventory.Equipped.Race or nil,
                    equippedClan = data.Inventory and data.Inventory.Equipped and data.Inventory.Equipped.Clan or nil,
                }
            end
        end
    end)

    -- 2. Equipped items (listen for UpdateEquipped after RequestInventory - already fired by getInventory)
    pcall(function()
        if not remotes then return end
        local ev = remotes:FindFirstChild("UpdateEquipped")
        if ev and ev:IsA("RemoteEvent") then
            local data = listenOnce(ev, 3)
            if data and data[1] and type(data[1]) == "table" then
                serverData.equipped = data[1]
            end
        end
    end)

    -- 3. GetAscendData (RemoteFunction in RemoteEvents)
    pcall(function()
        if not remoteEvents then return end
        local rf = remoteEvents:FindFirstChild("GetAscendData")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                serverData.ascend = {
                    level = data.level,
                    maxAscend = data.maxAscend,
                    rankName = data.rankName,
                    nextRankName = data.nextRankName,
                    isMaxed = data.isMaxed,
                    allMet = data.allMet,
                    totalRewards = data.totalRewards,
                    nextRewards = data.nextRewards,
                    requirements = data.requirements,
                }
            end
        end
    end)

    -- 4. TraitGetData (RemoteFunction in RemoteEvents)
    pcall(function()
        if not remoteEvents then return end
        local rf = remoteEvents:FindFirstChild("TraitGetData")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                serverData.trait = {
                    current = data.Trait,
                    pity = data.Pity,
                    maxPity = data.MaxPity,
                    mythicPity = data.MythicPity,
                    maxMythicPity = data.MaxMythicPity,
                    secretPity = data.SecretPity,
                    maxSecretPity = data.MaxSecretPity,
                    rerollCount = data.RerollCount,
                    hasUnlockedSecretBar = data.HasUnlockedSecretBar,
                }
            end
        end
    end)

    -- 5. GetSkillTreeData (RemoteFunction in RemoteEvents)
    pcall(function()
        if not remoteEvents then return end
        local rf = remoteEvents:FindFirstChild("GetSkillTreeData")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                serverData.skillTree = {
                    unlocked = data.Unlocked,
                    skillPoints = data.SkillPoints,
                    totalNPCKills = data.TotalNPCKills,
                    nodes = data.Nodes,
                }
            end
        end
    end)

    -- 6. PowerGetData (RemoteFunction in RemoteEvents)
    pcall(function()
        if not remoteEvents then return end
        local rf = remoteEvents:FindFirstChild("PowerGetData")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                serverData.power = {
                    unlocked = data.Unlocked,
                    pity = data.Pity,
                    maxPity = data.MaxPity,
                    rollCount = data.RollCount,
                    current = data.Current, -- {Name, Rarity, RolledBuffs}
                }
            end
        end
    end)

    -- 7. SpecPassiveGetData (RemoteFunction in RemoteEvents)
    pcall(function()
        if not remoteEvents then return end
        local rf = remoteEvents:FindFirstChild("SpecPassiveGetData")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                serverData.specPassive = {
                    unlocked = data.Unlocked,
                    pity = data.Pity,
                    maxPity = data.MaxPity,
                    rollCount = data.RollCount,
                    passives = data.Passives,
                }
            end
        end
    end)

    -- 8. GetArtifactStats (RemoteFunction in RemoteFunctions)
    pcall(function()
        if not remoteFunctions then return end
        local rf = remoteFunctions:FindFirstChild("GetArtifactStats")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                serverData.artifactStats = {
                    stats = data.stats,
                    equippedSets = data.equippedSets,
                }
            end
        end
    end)

    -- 9. GetArtifactMilestoneData (RemoteFunction in RemoteFunctions)
    pcall(function()
        if not remoteFunctions then return end
        local rf = remoteFunctions:FindFirstChild("GetArtifactMilestoneData")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                serverData.artifactMilestone = {
                    level = data.Level,
                    maxLevel = data.MaxLevel,
                    currentXP = data.CurrentXP,
                    xpNeeded = data.XPNeeded,
                    totalXP = data.TotalXP,
                    uniqueArtifactsCollected = data.UniqueArtifactsCollected,
                    rarityChances = data.RarityChances,
                }
            end
        end
    end)

    -- 10. GetArtifactData - just summary (inventory count, dust, equipped)
    pcall(function()
        if not remoteFunctions then return end
        local rf = remoteFunctions:FindFirstChild("GetArtifactData")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                local invCount = 0
                if data.Inventory then
                    for _ in pairs(data.Inventory) do invCount = invCount + 1 end
                end
                local equippedCount = 0
                if data.Equipped then
                    for _ in pairs(data.Equipped) do equippedCount = equippedCount + 1 end
                end
                serverData.artifact = {
                    unlocked = data.Unlocked,
                    dust = data.Dust,
                    totalInBag = invCount,
                    equippedCount = equippedCount,
                    equippedSlots = data.Equipped,
                    autoDelete = data.AutoDelete,
                }
            end
        end
    end)

    -- 11. Title from GUI
    pcall(function()
        local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not PlayerGui then return end
        local statsUI = PlayerGui:FindFirstChild("BasicStatsCurrencyAndButtonsUI")
        if not statsUI then return end
        local mf = statsUI:FindFirstChild("MainFrame")
        if not mf then return end
        local li = mf:FindFirstChild("LevelInfo")
        if not li then return end
        local tl = li:FindFirstChild("Title")
        if tl and tl.Text and tl.Text ~= "" then
            serverData.title = tl.Text:match("Title: (.+)") or tl.Text
        end
    end)

    if next(serverData) then return serverData end
    return nil
end

function SailorPieceAdapter:getProgress()
    local progress = {}

    -- Level & exp from Data (CONFIRMED - local, no yield)
    local dataFolder = LocalPlayer:FindFirstChild("Data")
    if dataFolder then
        local level = dataFolder:FindFirstChild("Level")
        local exp = dataFolder:FindFirstChild("Experience")
        local statPoints = dataFolder:FindFirstChild("StatPoints")
        if level then progress.Level = level.Value end
        if exp then progress.Experience = exp.Value end
        if statPoints then progress.StatPoints = statPoints.Value end
    end

    -- Scan ALL player children for extra data folders (safe, local only)
    -- This catches any hidden Value folders the game adds (Race, Clan, Fruit, etc.)
    local scannedFolders = {Data = true, leaderstats = true} -- already scanned above/in getStats
    for _, child in ipairs(LocalPlayer:GetChildren()) do
        if child:IsA("Folder") and not scannedFolders[child.Name] then
            for _, val in ipairs(child:GetChildren()) do
                if val:IsA("IntValue") or val:IsA("NumberValue") or val:IsA("StringValue") or val:IsA("BoolValue") then
                    progress[child.Name .. "_" .. val.Name] = val.Value
                end
            end
        end
    end

    -- Character humanoid stats (health, walkspeed)
    pcall(function()
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                progress.MaxHealth = humanoid.MaxHealth
                progress.WalkSpeed = humanoid.WalkSpeed
                progress.JumpPower = humanoid.JumpPower
            end
        end
    end)

    return progress
end

AdapterRegistry.register("sailor_piece", SailorPieceAdapter)

-- ============================================
-- BLOX FRUITS ADAPTER (from explorer scan)
-- ============================================
--[[
    Confirmed data paths (from explorer + remote tester):
    
    LOCAL (always work):
      leaderstats/ → Bounty/Honor
      Data/ → Level, Exp, Beli, DevilFruit, FruitCap, StatRefunds, SeaEventsCleared
      Data/Stats/ → Melee, Sword, Gun, Defense, Demon Fruit (Level + Exp each)
      Data/Stars/ → Gun, Sword, Melee, Blox Fruit
    
    REMOTE (confirmed work):
      Remotes.GetPlayerStats → Fighting Styles, Swords, Guns unlocked, Money, Fragments, Bounty, Accessories, Fish
      Remotes.SubclassNetwork.GetPlayerData → Equipped subclass, purchased list
      Modules.Net.RF/GetCraftPlayerData → Craft items, materials (Leather, Angel Wings, etc), Dragon Quest
      Modules.Net.RF/GetAllItemValues → Mastery per item, quantities, combat data
    
    BROKEN (skipped):
      Remotes.GetPlayerProfileData → error (needs player ID arg)
      Modules.Net.RF/ReadPlayerData → returns nil
      Modules.Net.RF/InventoryBackendService → assertion failed (needs arg)
]]

local BloxFruitsAdapter = setmetatable({}, {__index = BaseAdapter})
BloxFruitsAdapter.__index = BloxFruitsAdapter

function BloxFruitsAdapter.new()
    return setmetatable(BaseAdapter.new("blox_fruits"), BloxFruitsAdapter)
end

function BloxFruitsAdapter:getStats()
    local stats = {}

    -- Data folder (CONFIRMED)
    local dataFolder = LocalPlayer:FindFirstChild("Data")
    if dataFolder then
        local fields = {"Level", "Exp", "Beli", "DevilFruit", "FruitCap", "StatRefunds", "SeaEventsCleared"}
        for _, name in ipairs(fields) do
            local child = dataFolder:FindFirstChild(name)
            if child and (child:IsA("IntValue") or child:IsA("NumberValue") or child:IsA("StringValue")) then
                stats[name] = child.Value
            end
        end

        -- Mastery stats (CONFIRMED: Data.Stats.{Category}.Level/Exp)
        local statsFolder = dataFolder:FindFirstChild("Stats")
        if statsFolder then
            for _, cat in ipairs({"Melee", "Sword", "Gun", "Defense", "Demon Fruit"}) do
                local catFolder = statsFolder:FindFirstChild(cat)
                if catFolder then
                    local lvl = catFolder:FindFirstChild("Level")
                    local xp = catFolder:FindFirstChild("Exp")
                    if lvl then stats[cat .. "_Level"] = lvl.Value end
                    if xp then stats[cat .. "_Exp"] = xp.Value end
                end
            end
        end

        -- Stars (CONFIRMED: Data.Stars.*)
        local starsFolder = dataFolder:FindFirstChild("Stars")
        if starsFolder then
            for _, child in ipairs(starsFolder:GetChildren()) do
                if child:IsA("IntValue") then
                    stats["Stars_" .. child.Name] = child.Value
                end
            end
        end
    end

    -- leaderstats (CONFIRMED: Bounty/Honor)
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("IntValue") or child:IsA("NumberValue") then
                stats[child.Name] = child.Value
            end
        end
    end

    return stats
end

function BloxFruitsAdapter:getCurrency()
    local currency = {}

    local dataFolder = LocalPlayer:FindFirstChild("Data")
    if dataFolder then
        local beli = dataFolder:FindFirstChild("Beli")
        if beli then currency.Beli = beli.Value end
    end

    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("IntValue") then
                currency[child.Name] = child.Value
            end
        end
    end

    return currency
end

function BloxFruitsAdapter:getInventory()
    local inventory = {}

    -- Backpack tools
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(inventory, {name = item.Name, type = "tool", equipped = false})
            end
        end
    end

    -- Character equipped
    local character = LocalPlayer.Character
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(inventory, {name = item.Name, type = "equipped_weapon", equipped = true})
            elseif item:IsA("Accessory") then
                table.insert(inventory, {name = item.Name, type = "equipped_accessory", equipped = true})
            end
        end
    end

    -- Devil Fruit as inventory item
    local dataFolder = LocalPlayer:FindFirstChild("Data")
    if dataFolder then
        local df = dataFolder:FindFirstChild("DevilFruit")
        if df and df.Value and df.Value ~= "" then
            table.insert(inventory, {name = df.Value, type = "devil_fruit", equipped = true})
        end
    end

    return inventory
end

function BloxFruitsAdapter:getProgress()
    local progress = {}

    local dataFolder = LocalPlayer:FindFirstChild("Data")
    if dataFolder then
        local level = dataFolder:FindFirstChild("Level")
        local exp = dataFolder:FindFirstChild("Exp")
        if level then progress.Level = level.Value end
        if exp then progress.Experience = exp.Value end
    end

    pcall(function()
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                progress.MaxHealth = humanoid.MaxHealth
                progress.WalkSpeed = humanoid.WalkSpeed
            end
        end
    end)

    return progress
end

function BloxFruitsAdapter:getServerData()
    local serverData = {}
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")

    -- Helper: invoke RemoteFunction with timeout
    local function invokeWithTimeout(rf, timeout)
        timeout = timeout or 5
        local result = nil
        local done = false
        task.spawn(function()
            local ok, data = pcall(function() return rf:InvokeServer() end)
            if ok then result = data end
            done = true
        end)
        local s = tick()
        while not done and (tick() - s) < timeout do task.wait(0.2) end
        return result
    end

    -- 1. GetPlayerStats (CONFIRMED WORK — returns array of stat objects)
    -- {StatId, DisplayName, Progression, MaxProgression}
    -- Fighting Styles, Swords, Guns unlocked, Races, Fish, Money, Fragments, Bounty, Accessories
    pcall(function()
        if not remotes then return end
        local rf = remotes:FindFirstChild("GetPlayerStats")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                -- Convert array to named map for easier dashboard display
                local statsMap = {}
                for _, stat in ipairs(data) do
                    if stat.DisplayName then
                        statsMap[stat.DisplayName] = {
                            value = stat.Progression,
                            max = stat.MaxProgression,
                        }
                    end
                end
                serverData.playerStats = statsMap
            end
        end
    end)

    -- 2. GetFruitData (CONFIRMED WORK — all fruit info, 11KB)
    -- Skipping: too large, not useful per-snapshot. Fruit name already in Data.DevilFruit.

    -- 3. SubclassNetwork.GetPlayerData (CONFIRMED WORK — race/subclass)
    -- {Equipped: "", Purchased: []}
    pcall(function()
        if not remotes then return end
        local subNet = remotes:FindFirstChild("SubclassNetwork")
        if subNet then
            local rf = subNet:FindFirstChild("GetPlayerData")
            if rf and rf:IsA("RemoteFunction") then
                local data = invokeWithTimeout(rf, 5)
                if data and type(data) == "table" then
                    serverData.subclass = data
                end
            end
        end
    end)

    -- 4. GetCraftPlayerData (CONFIRMED WORK — craft items, materials, dragon quest)
    pcall(function()
        local netFolder = ReplicatedStorage:FindFirstChild("Modules")
        if not netFolder then return end
        netFolder = netFolder:FindFirstChild("Net")
        if not netFolder then return end
        local rf = netFolder:FindFirstChild("RF/GetCraftPlayerData")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                serverData.craftData = data
            end
        end
    end)

    -- 5. GetAllItemValues (CONFIRMED WORK — mastery, quantities, combat data per item)
    pcall(function()
        local netFolder = ReplicatedStorage:FindFirstChild("Modules")
        if not netFolder then return end
        netFolder = netFolder:FindFirstChild("Net")
        if not netFolder then return end
        local rf = netFolder:FindFirstChild("RF/GetAllItemValues")
        if rf and rf:IsA("RemoteFunction") then
            local data = invokeWithTimeout(rf, 5)
            if data and type(data) == "table" then
                serverData.itemValues = data
            end
        end
    end)

    -- SKIPPED (broken):
    -- GetPlayerProfileData — errors: "table index is nil" (needs player ID arg)
    -- ReadPlayerData — returns nil
    -- InventoryBackendService — assertion failed (needs arg)

    if next(serverData) then return serverData end
    return nil
end

AdapterRegistry.register("blox_fruits", BloxFruitsAdapter)

-- ============================================
-- FISH IT ADAPTER (stub — needs game scan)
-- ============================================
local FishItAdapter = setmetatable({}, {__index = BaseAdapter})
FishItAdapter.__index = FishItAdapter

function FishItAdapter.new()
    return setmetatable(BaseAdapter.new("fish_it"), FishItAdapter)
end

function FishItAdapter:getStats()
    local stats = {}
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("ValueBase") then
                stats[child.Name] = child.Value
            end
        end
    end
    return stats
end

function FishItAdapter:getCurrency()
    return self:getStats()
end

function FishItAdapter:getInventory()
    local inventory = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            table.insert(inventory, {name = item.Name, type = item.ClassName:lower(), equipped = false})
        end
    end
    return inventory
end

AdapterRegistry.register("fish_it", FishItAdapter)

-- ============================================
-- GROW A GARDEN ADAPTER (stub — needs game scan)
-- ============================================
local GrowAGardenAdapter = setmetatable({}, {__index = BaseAdapter})
GrowAGardenAdapter.__index = GrowAGardenAdapter

function GrowAGardenAdapter.new()
    return setmetatable(BaseAdapter.new("grow_a_garden"), GrowAGardenAdapter)
end

function GrowAGardenAdapter:getStats()
    local stats = {}
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("ValueBase") then
                stats[child.Name] = child.Value
            end
        end
    end
    return stats
end

function GrowAGardenAdapter:getCurrency()
    return self:getStats()
end

function GrowAGardenAdapter:getInventory()
    local inventory = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            table.insert(inventory, {name = item.Name, type = item.ClassName:lower(), equipped = false})
        end
    end
    return inventory
end

AdapterRegistry.register("grow_a_garden", GrowAGardenAdapter)

-- ============================================
-- GENERIC ADAPTER (fallback)
-- ============================================
local GenericAdapter = setmetatable({}, {__index = BaseAdapter})
GenericAdapter.__index = GenericAdapter

function GenericAdapter.new()
    return setmetatable(BaseAdapter.new("generic"), GenericAdapter)
end

function GenericAdapter:getStats()
    local stats = {}

    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, s in ipairs(leaderstats:GetChildren()) do
            if s:IsA("ValueBase") then stats["leaderstats." .. s.Name] = s.Value end
        end
    end

    local commonFolders = {"Stats", "Data", "PlayerStats", "PlayerData", "Values"}
    for _, folderName in ipairs(commonFolders) do
        local folder = LocalPlayer:FindFirstChild(folderName)
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("ValueBase") then
                    stats[folderName .. "." .. child.Name] = child.Value
                end
            end
        end
    end

    return stats
end

function GenericAdapter:getCurrency()
    return self:getStats()
end

function GenericAdapter:getInventory()
    local inventory = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            table.insert(inventory, {name = item.Name, type = item.ClassName, equipped = false})
        end
    end
    return inventory
end

AdapterRegistry.register("generic", GenericAdapter)

-- ============================================
-- NUMBER FORMATTER
-- ============================================
local function formatNumber(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e9 then
        return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.1fK", n / 1e3)
    end
    return tostring(n)
end

-- ============================================
-- MAIN TRACKER
-- ============================================
local Tracker = {}

function Tracker.buildPayload(adapter, gameName, placeId)
    local gameData = adapter:collectAll()

    return {
        -- Auth (UserID in body, discord_id otomatis dari server)
        UserID = CONFIG.USER_ID,
        Note = CONFIG.NOTE,

        player = {
            username = LocalPlayer.Name,
            displayName = LocalPlayer.DisplayName,
            userId = LocalPlayer.UserId,
        },
        game = {
            name = gameName,
            placeId = placeId,
            gameId = game.GameId,
            jobId = game.JobId,
        },
        data = gameData,
        meta = {
            timestamp = os.time(),
            trackerVersion = "3.0",
            executorName = identifyexecutor and identifyexecutor() or "unknown",
        }
    }
end

function Tracker.updateGUI(payload)
    GUI.clearLines()

    local data = payload.data
    local order = 0

    -- Player info
    GUI.setLine("player", "Player: " .. payload.player.username, Color3.fromRGB(255, 255, 255))

    -- Game
    GUI.setLine("game", "Game: " .. payload.game.name, Color3.fromRGB(239, 68, 68))

    -- Separator
    GUI.setLine("sep1", "---", Color3.fromRGB(50, 50, 60))

    -- Stats (sorted display)
    if data.stats then
        local statOrder = {"Level", "Experience", "Money", "Gems", "Bounty", "StatPoints"}
        for _, key in ipairs(statOrder) do
            if data.stats[key] then
                GUI.setLine("stat_" .. key, key .. ": " .. formatNumber(data.stats[key]), Color3.fromRGB(100, 255, 100))
            end
        end
        -- Any remaining stats not in the ordered list
        for key, val in pairs(data.stats) do
            local found = false
            for _, k in ipairs(statOrder) do
                if k == key then found = true; break end
            end
            if not found then
                GUI.setLine("stat_" .. key, key .. ": " .. formatNumber(val), Color3.fromRGB(180, 180, 180))
            end
        end
    end

    -- Currency
    if data.currency then
        for key, val in pairs(data.currency) do
            -- Skip if already shown in stats
            if not data.stats or not data.stats[key] then
                GUI.setLine("cur_" .. key, key .. ": " .. formatNumber(val), Color3.fromRGB(255, 220, 80))
            end
        end
    end

    -- Inventory count
    if data.inventory then
        local toolCount = 0
        local accCount = 0
        local equippedNames = {}
        for _, item in ipairs(data.inventory) do
            if item.type == "tool" then toolCount = toolCount + 1
            elseif item.type == "accessory" then accCount = accCount + 1 end
            if item.equipped then table.insert(equippedNames, item.name) end
        end
        GUI.setLine("sep2", "---", Color3.fromRGB(50, 50, 60))
        GUI.setLine("inv_tools", "Tools: " .. toolCount, Color3.fromRGB(180, 140, 255))
        GUI.setLine("inv_acc", "Accessories: " .. accCount, Color3.fromRGB(180, 140, 255))
        if #equippedNames > 0 then
            GUI.setLine("inv_equipped", "Equipped: " .. table.concat(equippedNames, ", "), Color3.fromRGB(255, 180, 100))
        end
    end

    -- API status
    GUI.setLine("sep3", "---", Color3.fromRGB(50, 50, 60))
    GUI.setLine("api_status", "API: " .. CONFIG.API_URL, Color3.fromRGB(100, 100, 110))
    GUI.setLine("last_update", "Updated: " .. os.date("%H:%M:%S"), Color3.fromRGB(100, 100, 110))
end

function Tracker.sendOnce(adapter, gameName, placeId)
    local payload = Tracker.buildPayload(adapter, gameName, placeId)

    -- Update GUI with latest data
    Tracker.updateGUI(payload)

    -- Send to API
    GUI.setStatus("SEND", Color3.fromRGB(255, 200, 0))
    local success, response = Http.post("/track", payload)

    if success then
        GUI.setStatus("LIVE", COLOR_LIVE)
        GUI.setLine("api_result", "Last send: OK", COLOR_LIVE)
    else
        GUI.setStatus("FAIL", COLOR_ERR)
        GUI.setLine("api_result", "Last send: FAILED (retrying)", COLOR_ERR)
    end

    return success
end

function Tracker.startLoop(adapter, gameName, placeId)
    -- Send immediately
    Tracker.sendOnce(adapter, gameName, placeId)

    -- Loop
    local tick = 0
    while true do
        task.wait(1)
        tick = tick + 1

        if not LocalPlayer or not LocalPlayer.Parent then
            GUI.setStatus("LEFT", Color3.fromRGB(150, 150, 150))
            break
        end

        -- Countdown display
        local remaining = CONFIG.SEND_INTERVAL - tick
        if remaining > 0 then
            GUI.setLine("next_send", "Next send: " .. remaining .. "s", Color3.fromRGB(100, 100, 110))
        end

        if tick >= CONFIG.SEND_INTERVAL then
            tick = 0
            Tracker.sendOnce(adapter, gameName, placeId)
        end
    end
end

-- ============================================
-- ENTRY POINT
-- ============================================
local function main()
    -- Create GUI
    GUI.create()
    task.wait(0.3)

    GUI.setStatus("INIT", COLOR_INIT)
    GUI.setLine("init", "SebatIn Hub — Initializing...", Color3.fromRGB(200, 200, 200))

    -- Check UserID
    if not CONFIG.USER_ID or CONFIG.USER_ID == "" then
        GUI.setStatus("ERR", COLOR_ERR)
        GUI.setLine("err_uid_1", "ERROR: UserID tidak ditemukan!", COLOR_ERR)
        GUI.setLine("err_uid_2", "", Color3.fromRGB(200, 200, 200))
        GUI.setLine("err_uid_3", "Pastikan set _G.Config sebelum loadstring:", Color3.fromRGB(200, 200, 200))
        GUI.setLine("err_uid_4", '_G.Config={UserID="xxx",Note="Pc"}', Color3.fromRGB(239, 68, 68))
        GUI.setLine("err_uid_5", "", Color3.fromRGB(200, 200, 200))
        GUI.setLine("err_uid_6", "Ambil UserID di dashboard SebatIn Hub.", Color3.fromRGB(150, 150, 150))
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "SebatIn Hub",
                Text = "UserID tidak ditemukan! Set _G.Config dulu.",
                Duration = 15,
            })
        end)
        return
    end

    -- Detect game
    local gameName, placeId = GameDetector.detect()

    -- Get adapter
    local adapterClass = nil
    if gameName then
        adapterClass = AdapterRegistry.get(gameName)
    end

    if not adapterClass then
        adapterClass = AdapterRegistry.get("generic")
        gameName = gameName or "unknown"
    end

    local adapter = adapterClass.new()

    GUI.setLine("init", "Game: " .. gameName .. " | Adapter: " .. adapter.gameName, Color3.fromRGB(120, 200, 255))
    task.wait(0.5)

    -- Step 1: Test data collection
    GUI.setLine("step1", "[1] Collecting data...", Color3.fromRGB(255, 200, 0))
    task.wait(0.2)

    local collectOk, collectErr = pcall(function()
        local testData = adapter:collectAll()
        local statCount = 0
        if testData and testData.stats then
            for _ in pairs(testData.stats) do statCount = statCount + 1 end
        end
        GUI.setLine("step1", "[1] Data OK - " .. statCount .. " stats found", COLOR_LIVE)
    end)
    if not collectOk then
        GUI.setLine("step1", "[1] COLLECT ERROR: " .. string.sub(tostring(collectErr), 1, 100), Color3.fromRGB(255, 0, 0))
        GUI.setStatus("ERR", Color3.fromRGB(255, 0, 0))
        return
    end
    task.wait(0.2)

    -- Step 2: Test payload build
    GUI.setLine("step2", "[2] Building payload...", Color3.fromRGB(255, 200, 0))
    task.wait(0.2)

    local payload = nil
    local buildOk, buildErr = pcall(function()
        payload = Tracker.buildPayload(adapter, gameName, placeId)
        GUI.setLine("step2", "[2] Payload OK - player: " .. tostring(payload.player.username), COLOR_LIVE)
    end)
    if not buildOk then
        GUI.setLine("step2", "[2] BUILD ERROR: " .. string.sub(tostring(buildErr), 1, 100), Color3.fromRGB(255, 0, 0))
        GUI.setStatus("ERR", Color3.fromRGB(255, 0, 0))
        return
    end
    task.wait(0.2)

    -- Step 3: Test JSON encode
    GUI.setLine("step3", "[3] Encoding JSON...", Color3.fromRGB(255, 200, 0))
    task.wait(0.2)

    local jsonOk, jsonErr = pcall(function()
        local json = HttpService:JSONEncode(payload)
        GUI.setLine("step3", "[3] JSON OK - " .. #json .. " bytes", COLOR_LIVE)
    end)
    if not jsonOk then
        GUI.setLine("step3", "[3] JSON ERROR: " .. string.sub(tostring(jsonErr), 1, 100), Color3.fromRGB(255, 0, 0))
        GUI.setStatus("ERR", Color3.fromRGB(255, 0, 0))
        return
    end
    task.wait(0.2)

    -- Step 4: Test HTTP
    GUI.setLine("step4", "[4] Testing HTTP...", Color3.fromRGB(255, 200, 0))
    task.wait(0.2)

    local httpAvail = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    if httpAvail then
        GUI.setLine("step4", "[4] HTTP function available", COLOR_LIVE)
    else
        GUI.setLine("step4", "[4] NO HTTP FUNCTION!", Color3.fromRGB(255, 0, 0))
        GUI.setStatus("ERR", Color3.fromRGB(255, 0, 0))
        return
    end
    task.wait(0.3)

    -- All checks passed, start loop
    GUI.setLine("step5", "[5] Starting tracker loop...", COLOR_LIVE)
    task.wait(0.3)

    Tracker.startLoop(adapter, gameName, placeId)
end

local success, err = pcall(main)
if not success then
    -- Show error on GUI if it exists
    pcall(function()
        GUI.setStatus("CRASH", COLOR_ERR)
        GUI.setLine("crash_err", "CRASH: " .. string.sub(tostring(err), 1, 150), COLOR_ERR)
    end)
    -- Also show notification
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "SebatIn Hub Error",
            Text = tostring(err),
            Duration = 15,
        })
    end)
end
