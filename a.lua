--[[
    BLOX FRUITS — Remote Function Tester
    Test semua RemoteFunction yang ada di adapter.
    Output ke GUI + clipboard.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- GUI
local old = LocalPlayer.PlayerGui:FindFirstChild("BFTestGui")
if old then old:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BFTestGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0.85, 0, 0.75, 0)
mainFrame.Position = UDim2.new(0.075, 0, 0.125, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
title.BorderSizePixel = 0
title.Text = "BLOX FRUITS — Remote Tester"
title.TextColor3 = Color3.fromRGB(239, 68, 68)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -12, 1, -75)
scroll.Position = UDim2.new(0, 6, 0, 34)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(239, 68, 68)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 2)
layout.Parent = scroll

-- Copy button
local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0.9, 0, 0, 30)
copyBtn.Position = UDim2.new(0.05, 0, 1, -38)
copyBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
copyBtn.Text = "COPY ALL"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.TextSize = 13
copyBtn.Font = Enum.Font.GothamBold
copyBtn.BorderSizePixel = 0
copyBtn.Parent = mainFrame
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)

screenGui.Parent = LocalPlayer.PlayerGui

local logLines = {}
local lineOrder = 0

local function log(text, color)
    color = color or Color3.fromRGB(200, 200, 200)
    table.insert(logLines, text)
    lineOrder = lineOrder + 1
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
    label.Parent = scroll
    task.defer(function()
        if scroll and scroll.Parent then
            scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
        end
    end)
end

copyBtn.MouseButton1Click:Connect(function()
    local allText = table.concat(logLines, "\n")
    if setclipboard then
        setclipboard(allText)
        copyBtn.Text = "COPIED!"
        task.wait(1.5)
        copyBtn.Text = "COPY ALL"
    elseif toclipboard then
        toclipboard(allText)
        copyBtn.Text = "COPIED!"
        task.wait(1.5)
        copyBtn.Text = "COPY ALL"
    end
end)

-- Helper: invoke with timeout
local function invokeWithTimeout(rf, timeout, ...)
    timeout = timeout or 5
    local result = nil
    local err = nil
    local done = false
    local args = {...}
    task.spawn(function()
        local ok, data = pcall(function() return rf:InvokeServer(unpack(args)) end)
        if ok then
            result = data
        else
            err = data
        end
        done = true
    end)
    local s = tick()
    while not done and (tick() - s) < timeout do task.wait(0.2) end
    if not done then
        return nil, "TIMEOUT (" .. timeout .. "s)"
    end
    if err then
        return nil, tostring(err)
    end
    return result, nil
end

local function truncate(str, maxLen)
    maxLen = maxLen or 500
    if #str > maxLen then
        return string.sub(str, 1, maxLen) .. "... [TRUNCATED]"
    end
    return str
end

local function testRemote(name, path, timeout, ...)
    log("")
    log("=== TEST: " .. name .. " ===", Color3.fromRGB(80, 180, 255))
    log("Path: " .. path, Color3.fromRGB(150, 150, 150))

    -- Find the remote
    local parts = string.split(path, ".")
    local current = ReplicatedStorage
    for i = 2, #parts do
        current = current:FindFirstChild(parts[i])
        if not current then
            log("NOT FOUND at: " .. parts[i], Color3.fromRGB(255, 80, 80))
            return
        end
    end

    if not current:IsA("RemoteFunction") then
        log("NOT a RemoteFunction: " .. current.ClassName, Color3.fromRGB(255, 80, 80))
        return
    end

    log("Found! Invoking with " .. (timeout or 5) .. "s timeout...", Color3.fromRGB(255, 200, 0))

    local data, errMsg = invokeWithTimeout(current, timeout, ...)

    if errMsg then
        log("RESULT: FAILED — " .. errMsg, Color3.fromRGB(255, 80, 80))
        return
    end

    if data == nil then
        log("RESULT: nil (no data returned)", Color3.fromRGB(255, 150, 0))
        return
    end

    local dataType = type(data)
    log("RESULT: " .. dataType, Color3.fromRGB(60, 255, 120))

    if dataType == "table" then
        local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
        if ok then
            log("JSON (" .. #json .. " bytes):", Color3.fromRGB(150, 150, 150))
            log(truncate(json, 800), Color3.fromRGB(200, 200, 200))
        else
            -- Fallback: print keys
            log("Keys:", Color3.fromRGB(150, 150, 150))
            local count = 0
            for k, v in pairs(data) do
                count = count + 1
                if count > 30 then
                    log("  ... +" .. (count) .. " more keys", Color3.fromRGB(150, 150, 150))
                    break
                end
                local valStr = tostring(v)
                if type(v) == "table" then
                    local subCount = 0
                    for _ in pairs(v) do subCount = subCount + 1 end
                    valStr = "{table: " .. subCount .. " keys}"
                end
                log("  " .. tostring(k) .. " = " .. string.sub(valStr, 1, 100), Color3.fromRGB(200, 200, 200))
            end
        end
    else
        log("Value: " .. tostring(data), Color3.fromRGB(200, 200, 200))
    end
end

-- Run tests
log("Player: " .. LocalPlayer.Name, Color3.fromRGB(255, 255, 255))
log("PlaceId: " .. tostring(game.PlaceId), Color3.fromRGB(255, 255, 255))
log("")

-- 1. GetPlayerStats
testRemote(
    "GetPlayerStats",
    "ReplicatedStorage.Remotes.GetPlayerStats",
    5
)

task.wait(0.5)

-- 2. GetPlayerProfileData
testRemote(
    "GetPlayerProfileData",
    "ReplicatedStorage.Remotes.GetPlayerProfileData",
    5
)

task.wait(0.5)

-- 3. GetFruitData
testRemote(
    "GetFruitData",
    "ReplicatedStorage.Remotes.GetFruitData",
    5
)

task.wait(0.5)

-- 4. SubclassNetwork.GetPlayerData
testRemote(
    "SubclassNetwork.GetPlayerData",
    "ReplicatedStorage.Remotes.SubclassNetwork.GetPlayerData",
    5
)

task.wait(0.5)

-- 5. ReadPlayerData (Modules.Net)
testRemote(
    "ReadPlayerData",
    "ReplicatedStorage.Modules.Net.RF/ReadPlayerData",
    5
)

task.wait(0.5)

-- 6. GetCraftPlayerData
testRemote(
    "GetCraftPlayerData",
    "ReplicatedStorage.Modules.Net.RF/GetCraftPlayerData",
    5
)

task.wait(0.5)

-- 7. InventoryBackendService
testRemote(
    "InventoryBackendService",
    "ReplicatedStorage.Modules.Net.RF/InventoryBackendService",
    5
)

task.wait(0.5)

-- 8. GetAllItemValues
testRemote(
    "GetAllItemValues",
    "ReplicatedStorage.Modules.Net.RF/GetAllItemValues",
    5
)

log("")
log("=== ALL TESTS DONE ===", Color3.fromRGB(60, 255, 120))
log("Klik COPY ALL, paste hasilnya.", Color3.fromRGB(150, 150, 150))
