--[[
    ============================================
    GAME EXPLORER v2.0 (GUI Edition)
    ============================================
    Scan struktur data game Roblox dari client-side.
    Semua output tampil di GUI in-game (scrollable).
    
    Compatible: Codex, Delta, Fluxus, Synapse, dll
    ============================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- CONFIG
-- ============================================
local MAX_DEPTH = 5
local MAX_CHILDREN = 100
local SCAN_DELAY = 0

local IMPORTANT_KEYWORDS = {
    "coin","coins","gold","money","cash","gem","gems","diamond",
    "diamonds","ruby","rubies","beli","berry","berries","bounty",
    "token","tokens","currency","dollar","yen","pesos",
    "level","lvl","exp","xp","experience","stat","stats",
    "strength","str","defense","def","health","hp","stamina",
    "power","damage","dmg","speed","spd","rank",
    "melee","sword","gun","blox","fruit","haki",
    "inventory","backpack","item","items","weapon","weapons",
    "tool","tools","pet","pets","egg","eggs","swords",
    "accessory","accessories","fruits","ability",
    "quest","quests","mission","missions","achievement",
    "progress","stage","floor","area","island","sea",
    "world","zone","chapter",
    "leaderstats","playerstats","playerdata","data","save",
    "profile","info","status"
}

-- ============================================
-- GUI BUILDER
-- ============================================
local GUI = {}
local logLines = {}
local scrollFrame, listLayout

function GUI.create()
    -- Hapus GUI lama kalau ada
    local old = LocalPlayer.PlayerGui:FindFirstChild("ExplorerGui")
    if old then old:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ExplorerGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "Main"
    mainFrame.Size = UDim2.new(0.85, 0, 0.7, 0)
    mainFrame.Position = UDim2.new(0.075, 0, 0.15, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(80, 120, 255)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar

    -- Fix bottom corners of title bar
    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0, 10)
    titleFix.Position = UDim2.new(0, 0, 1, -10)
    titleFix.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    titleFix.BorderSizePixel = 0
    titleFix.Parent = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "GAME EXPLORER v2.0"
    titleLabel.TextColor3 = Color3.fromRGB(80, 180, 255)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    -- Status indicator (dot)
    GUI.statusDot = Instance.new("Frame")
    GUI.statusDot.Size = UDim2.new(0, 10, 0, 10)
    GUI.statusDot.Position = UDim2.new(1, -80, 0.5, -5)
    GUI.statusDot.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    GUI.statusDot.BorderSizePixel = 0
    GUI.statusDot.Parent = titleBar

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = GUI.statusDot

    GUI.statusLabel = Instance.new("TextLabel")
    GUI.statusLabel.Size = UDim2.new(0, 60, 1, 0)
    GUI.statusLabel.Position = UDim2.new(1, -65, 0, 0)
    GUI.statusLabel.BackgroundTransparency = 1
    GUI.statusLabel.Text = "READY"
    GUI.statusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    GUI.statusLabel.TextSize = 12
    GUI.statusLabel.Font = Enum.Font.GothamBold
    GUI.statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    GUI.statusLabel.Parent = titleBar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Scroll area
    scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "LogScroll"
    scrollFrame.Size = UDim2.new(1, -16, 1, -90)
    scrollFrame.Position = UDim2.new(0, 8, 0, 44)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.Parent = mainFrame

    listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = scrollFrame

    -- Bottom bar with buttons
    local bottomBar = Instance.new("Frame")
    bottomBar.Size = UDim2.new(1, 0, 0, 40)
    bottomBar.Position = UDim2.new(0, 0, 1, -40)
    bottomBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    bottomBar.BorderSizePixel = 0
    bottomBar.Parent = mainFrame

    local bottomCorner = Instance.new("UICorner")
    bottomCorner.CornerRadius = UDim.new(0, 10)
    bottomCorner.Parent = bottomBar

    local bottomFix = Instance.new("Frame")
    bottomFix.Size = UDim2.new(1, 0, 0, 10)
    bottomFix.Position = UDim2.new(0, 0, 0, 0)
    bottomFix.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    bottomFix.BorderSizePixel = 0
    bottomFix.Parent = bottomBar

    -- Copy All button
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0.45, 0, 0, 28)
    copyBtn.Position = UDim2.new(0.025, 0, 0.5, -14)
    copyBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 220)
    copyBtn.Text = "COPY ALL"
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyBtn.TextSize = 13
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.BorderSizePixel = 0
    copyBtn.Parent = bottomBar

    local copyBtnCorner = Instance.new("UICorner")
    copyBtnCorner.CornerRadius = UDim.new(0, 6)
    copyBtnCorner.Parent = copyBtn

    copyBtn.MouseButton1Click:Connect(function()
        local allText = table.concat(logLines, "\n")
        if setclipboard then
            setclipboard(allText)
            copyBtn.Text = "COPIED!"
            copyBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
            task.wait(1.5)
            copyBtn.Text = "COPY ALL"
            copyBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 220)
        elseif toclipboard then
            toclipboard(allText)
            copyBtn.Text = "COPIED!"
            copyBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
            task.wait(1.5)
            copyBtn.Text = "COPY ALL"
            copyBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 220)
        else
            copyBtn.Text = "NO CLIPBOARD"
            copyBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            task.wait(1.5)
            copyBtn.Text = "COPY ALL"
            copyBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 220)
        end
    end)

    -- Copy JSON button
    local jsonBtn = Instance.new("TextButton")
    jsonBtn.Size = UDim2.new(0.45, 0, 0, 28)
    jsonBtn.Position = UDim2.new(0.525, 0, 0.5, -14)
    jsonBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 220)
    jsonBtn.Text = "COPY JSON"
    jsonBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    jsonBtn.TextSize = 13
    jsonBtn.Font = Enum.Font.GothamBold
    jsonBtn.BorderSizePixel = 0
    jsonBtn.Parent = bottomBar

    local jsonBtnCorner = Instance.new("UICorner")
    jsonBtnCorner.CornerRadius = UDim.new(0, 6)
    jsonBtnCorner.Parent = jsonBtn

    jsonBtn.MouseButton1Click:Connect(function()
        -- Will be connected after scan
        if GUI.jsonData then
            local json = HttpService:JSONEncode(GUI.jsonData)
            if setclipboard then
                setclipboard(json)
            elseif toclipboard then
                toclipboard(json)
            end
            jsonBtn.Text = "COPIED!"
            jsonBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
            task.wait(1.5)
            jsonBtn.Text = "COPY JSON"
            jsonBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 220)
        end
    end)

    -- Make draggable
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    screenGui.Parent = LocalPlayer.PlayerGui
    return screenGui
end

function GUI.setStatus(text, color)
    if GUI.statusLabel then
        GUI.statusLabel.Text = text
        GUI.statusLabel.TextColor3 = color
    end
    if GUI.statusDot then
        GUI.statusDot.BackgroundColor3 = color
    end
end

local lineOrder = 0
function GUI.log(text, color)
    color = color or Color3.fromRGB(200, 200, 200)
    table.insert(logLines, text)
    lineOrder = lineOrder + 1

    if not scrollFrame then return end

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextSize = 11
    label.Font = Enum.Font.RobotoMono
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.LayoutOrder = lineOrder
    label.RichText = false
    label.Parent = scrollFrame

    -- Auto-scroll to bottom
    task.defer(function()
        if scrollFrame and scrollFrame.Parent then
            scrollFrame.CanvasPosition = Vector2.new(0, scrollFrame.AbsoluteCanvasSize.Y)
        end
    end)
end

function GUI.logHeader(text)
    GUI.log("")
    GUI.log("=== " .. text .. " ===", Color3.fromRGB(80, 180, 255))
end

function GUI.logImportant(text)
    GUI.log(">> " .. text, Color3.fromRGB(255, 220, 50))
end

function GUI.logFound(text)
    GUI.log("  + " .. text, Color3.fromRGB(100, 255, 100))
end

function GUI.logNormal(text)
    GUI.log("  - " .. text, Color3.fromRGB(160, 160, 170))
end

function GUI.logError(text)
    GUI.log("[!] " .. text, Color3.fromRGB(255, 80, 80))
end

-- ============================================
-- UTILITIES
-- ============================================
local results = {}
local scannedPaths = {}

local function containsKeyword(name)
    local lower = string.lower(name)
    for _, keyword in ipairs(IMPORTANT_KEYWORDS) do
        if string.find(lower, keyword) then
            return true, keyword
        end
    end
    return false, nil
end

local function getValuePreview(obj)
    local success, result = pcall(function()
        if obj:IsA("IntValue") or obj:IsA("NumberValue") then
            return tostring(obj.Value)
        elseif obj:IsA("StringValue") then
            local val = obj.Value
            if #val > 50 then val = string.sub(val, 1, 50) .. "..." end
            return '"' .. val .. '"'
        elseif obj:IsA("BoolValue") then
            return tostring(obj.Value)
        elseif obj:IsA("ObjectValue") then
            if obj.Value then return "-> " .. obj.Value:GetFullName() end
            return "nil"
        end
        return nil
    end)
    if success then return result end
    return nil
end

local function addResult(category, path, className, value, keyword)
    table.insert(results, {
        category = category,
        path = path,
        className = className,
        value = value,
        keyword = keyword
    })
end

-- ============================================
-- SCANNER
-- ============================================
local function scanObject(obj, depth, category)
    if depth > MAX_DEPTH then return end

    local fullName = obj:GetFullName()
    if scannedPaths[fullName] then return end
    scannedPaths[fullName] = true

    local success, children = pcall(function() return obj:GetChildren() end)
    if not success then return end

    local count = 0
    for _, child in ipairs(children) do
        if count >= MAX_CHILDREN then break end
        count = count + 1

        local name = child.Name
        local isImportant, keyword = containsKeyword(name)
        local value = getValuePreview(child)

        if isImportant then
            local display = child:GetFullName() .. " [" .. child.ClassName .. "]"
            if value then display = display .. " = " .. value end
            GUI.logFound(display .. "  (keyword: " .. keyword .. ")")
            addResult(category, child:GetFullName(), child.ClassName, value, keyword)
        end

        if isImportant or depth < 3 then
            scanObject(child, depth + 1, category)
        end

        if SCAN_DELAY > 0 then task.wait(SCAN_DELAY) end
    end
end

-- ============================================
-- SCAN FUNCTIONS
-- ============================================
local function scanLeaderstats()
    GUI.logHeader("LEADERSTATS")
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            local value = getValuePreview(stat)
            local display = stat.Name .. " (" .. stat.ClassName .. ")"
            if value then display = display .. " = " .. value end
            GUI.logImportant(display)
            addResult("leaderstats", stat:GetFullName(), stat.ClassName, value, "leaderstats")
        end
    else
        GUI.logNormal("leaderstats not found")
    end
end

local function scanPlayerChildren()
    GUI.logHeader("PLAYER CHILDREN")
    for _, child in ipairs(LocalPlayer:GetChildren()) do
        local isImportant, keyword = containsKeyword(child.Name)
        local childCount = 0
        pcall(function() childCount = #child:GetChildren() end)
        local info = child.Name .. " (" .. child.ClassName .. ") [" .. childCount .. " children]"

        if isImportant then
            GUI.logImportant(info .. "  (keyword: " .. keyword .. ")")
            addResult("player_child", child:GetFullName(), child.ClassName, nil, keyword)
            scanObject(child, 1, "player_data")
        else
            GUI.logNormal(info)
        end
    end
end

local function scanBackpack()
    GUI.logHeader("BACKPACK")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local items = backpack:GetChildren()
        if #items == 0 then
            GUI.logNormal("(empty)")
        else
            for _, tool in ipairs(items) do
                GUI.logFound(tool.Name .. " (" .. tool.ClassName .. ")")
                addResult("backpack", tool:GetFullName(), tool.ClassName, nil, "backpack")
            end
        end
    else
        GUI.logNormal("Backpack not found")
    end
end

local function scanCharacter()
    GUI.logHeader("CHARACTER (Equipped)")
    local character = LocalPlayer.Character
    if character then
        local found = false
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") or child:IsA("Accessory") then
                GUI.logFound(child.Name .. " (" .. child.ClassName .. ")")
                addResult("equipped", child:GetFullName(), child.ClassName, nil, "equipped")
                found = true
            end
        end
        if not found then GUI.logNormal("No tools/accessories equipped") end
    else
        GUI.logNormal("Character not loaded")
    end
end

local function scanReplicatedStorage()
    GUI.logHeader("REPLICATED STORAGE")
    GUI.logNormal("Scanning for important data...")
    scanObject(ReplicatedStorage, 0, "replicated_storage")
end

local function scanPlayerGui()
    GUI.logHeader("PLAYER GUI")
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, screenGui in ipairs(playerGui:GetChildren()) do
            if screenGui:IsA("ScreenGui") then
                local isImportant, keyword = containsKeyword(screenGui.Name)
                if isImportant then
                    GUI.logImportant("ScreenGui: " .. screenGui.Name .. "  (keyword: " .. keyword .. ")")
                    addResult("gui", screenGui:GetFullName(), "ScreenGui", nil, keyword)
                else
                    GUI.logNormal("ScreenGui: " .. screenGui.Name)
                end
            end
        end
    end
end

local function scanRemotes()
    GUI.logHeader("REMOTE EVENTS / FUNCTIONS")

    local function findRemotes(parent, depth)
        if depth > 3 then return end
        local success, children = pcall(function() return parent:GetChildren() end)
        if not success then return end

        for _, child in ipairs(children) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                local isImportant, keyword = containsKeyword(child.Name)
                if isImportant then
                    GUI.logFound(child.ClassName .. ": " .. child:GetFullName() .. "  (keyword: " .. keyword .. ")")
                    addResult("remote", child:GetFullName(), child.ClassName, nil, keyword)
                end
            end
            findRemotes(child, depth + 1)
        end
    end

    findRemotes(ReplicatedStorage, 0)

    local commonFolders = {"Remotes", "Events", "RemoteEvents", "Network", "Comm"}
    for _, folderName in ipairs(commonFolders) do
        local folder = ReplicatedStorage:FindFirstChild(folderName)
        if folder then
            GUI.logImportant("Remote folder found: " .. folderName)
            findRemotes(folder, 0)
        end
    end
end

-- ============================================
-- SUMMARY
-- ============================================
local function buildSummary()
    GUI.logHeader("SCAN SUMMARY")
    GUI.log("Total important paths found: " .. #results, Color3.fromRGB(100, 255, 100))

    local categories = {}
    for _, r in ipairs(results) do
        if not categories[r.category] then categories[r.category] = {} end
        table.insert(categories[r.category], r)
    end

    for cat, items in pairs(categories) do
        GUI.log("")
        GUI.log("--- " .. string.upper(cat) .. " (" .. #items .. ") ---", Color3.fromRGB(80, 180, 255))
        for _, item in ipairs(items) do
            local line = item.path .. " [" .. item.className .. "]"
            if item.value then line = line .. " = " .. item.value end
            GUI.logFound(line)
        end
    end

    -- Build JSON data for copy
    local gameInfo = {}
    pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        gameInfo.name = info.Name
    end)

    GUI.jsonData = {
        game = {
            name = gameInfo.name or "Unknown",
            placeId = game.PlaceId,
            gameId = game.GameId,
        },
        player = {
            username = LocalPlayer.Name,
            displayName = LocalPlayer.DisplayName,
            userId = LocalPlayer.UserId,
        },
        results = results,
        scannedAt = os.time(),
    }
end

-- ============================================
-- MAIN
-- ============================================
local function main()
    -- Create GUI first
    GUI.create()
    task.wait(0.3)

    -- Game info
    GUI.setStatus("SCANNING", Color3.fromRGB(255, 200, 0))

    GUI.logHeader("GAME INFO")
    GUI.log("Player: " .. LocalPlayer.Name .. " (" .. LocalPlayer.DisplayName .. ")", Color3.fromRGB(255, 255, 255))
    GUI.log("UserId: " .. tostring(LocalPlayer.UserId), Color3.fromRGB(255, 255, 255))
    GUI.log("PlaceId: " .. tostring(game.PlaceId), Color3.fromRGB(255, 255, 255))
    GUI.log("GameId: " .. tostring(game.GameId), Color3.fromRGB(255, 255, 255))

    pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        GUI.log("Game: " .. info.Name, Color3.fromRGB(80, 255, 180))
    end)

    task.wait(0.2)

    -- Run all scans
    local scans = {
        {"Leaderstats", scanLeaderstats},
        {"Player Children", scanPlayerChildren},
        {"Backpack", scanBackpack},
        {"Character", scanCharacter},
        {"ReplicatedStorage", scanReplicatedStorage},
        {"PlayerGui", scanPlayerGui},
        {"Remotes", scanRemotes},
    }

    for i, scan in ipairs(scans) do
        GUI.setStatus("SCAN " .. i .. "/" .. #scans, Color3.fromRGB(255, 200, 0))
        local success, err = pcall(scan[2])
        if not success then
            GUI.logError("Failed to scan " .. scan[1] .. ": " .. tostring(err))
        end
        task.wait(0.1) -- Small delay so GUI updates visually
    end

    -- Summary
    buildSummary()

    -- Done
    GUI.setStatus("DONE", Color3.fromRGB(0, 255, 100))
    GUI.log("")
    GUI.log("Scan complete! Use COPY ALL or COPY JSON below.", Color3.fromRGB(0, 255, 100))
    GUI.log("Kirim hasilnya untuk bikin tracker adapter.", Color3.fromRGB(180, 180, 180))
end

local success, err = pcall(main)
if not success then
    -- Fallback: kalau GUI gagal dibuat, print ke console
    print("[EXPLORER FATAL ERROR] " .. tostring(err))
    -- Coba bikin notifikasi sederhana
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Explorer Error",
            Text = tostring(err),
            Duration = 10,
        })
    end)
end
