--[[
BALL KUN HUB • MAHANAKHON v4.0 (อ่านง่าย + สวิตช์เปิด/ปิด)
Client-side companion UI for PlaceId 104549080643413
Designed for Roblox Studio / an experience you own or are authorized to test.
This script does NOT invoke game remotes, bypass server checks, automate rewards,
or spoof job/race completion. Native game actions remain in the game's own UI.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local PLACE_ID = 104549080643413
-- ใส่ Roblox Image Asset ID ได้หากต้องการภาพพื้นหลัง (0 = ใช้พื้นหลังสีพื้น)
local BACKGROUND_ASSET_ID = 0
local BACKGROUND_IMAGE = BACKGROUND_ASSET_ID > 0 and ("rbxassetid://" .. BACKGROUND_ASSET_ID) or ""
if game.PlaceId ~= PLACE_ID then
    warn("[MAHANAKHON HUB] PlaceId mismatch. Expected:", PLACE_ID, "Got:", game.PlaceId)
end

local old = PlayerGui:FindFirstChild("MahanakhonHubV2")
if old then old:Destroy() end

local Theme = {
    bg = Color3.fromRGB(3, 12, 5),
    panel = Color3.fromRGB(5, 22, 10),
    panel2 = Color3.fromRGB(10, 42, 18),
    line = Color3.fromRGB(25, 210, 55),
    text = Color3.fromRGB(246, 249, 252),
    muted = Color3.fromRGB(195, 208, 222),
    accent = Color3.fromRGB(35, 255, 30),
    accent2 = Color3.fromRGB(0, 220, 150),
    danger = Color3.fromRGB(238, 86, 100),
    good = Color3.fromRGB(85, 205, 145),
}
local FONT = Enum.Font.Gotham
local State = {
    tab = "Overview",
    promptESP = false,
    vehicleESP = false,
    jobESP = false,
    miniStatus = true,
    scanBusy = false,
    highlights = {},
    waypoint = nil,
    lastScan = 0,
    autoNearest = false,
    nearestPart = nil,
    bgOn = true,
    boost = 1,
}
local Connections = {}

local function disconnectAll()
    for _, connection in ipairs(Connections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    table.clear(Connections)
end

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

-- Themed objects: a property value like "@accent" is bound to Theme.accent
-- and is recolored by applyTheme() when the user picks a new palette.
local Themed = {}
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        if type(v) == "string" and v:sub(1, 1) == "@" and Theme[v:sub(2)] then
            table.insert(Themed, {obj, k, v:sub(2)})
            obj[k] = Theme[v:sub(2)]
        else
            obj[k] = v
        end
    end
    obj.Parent = parent
    return obj
end

local function applyTheme()
    local alive = {}
    for _, e in ipairs(Themed) do
        local obj = e[1]
        if obj.Parent ~= nil then
            pcall(function() obj[e[2]] = Theme[e[3]] end)
            table.insert(alive, e)
        end
    end
    Themed = alive
end

local loadingGui = make("ScreenGui", {
    Name = "BallKunLoading",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
}, PlayerGui)
local loading = make("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(2, 8, 3),
    BorderSizePixel = 0,
}, loadingGui)
local loadingTitle = make("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43),
    Size = UDim2.new(0.9, 0, 0, 58), BackgroundTransparency = 1,
    Text = "BALL KUN HUB", TextColor3 = Color3.fromRGB(35,255,30),
    Font = Enum.Font.GothamBlack, TextSize = 34,
}, loading)
make("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
    Size = UDim2.new(0.9, 0, 0, 34), BackgroundTransparency = 1,
    Text = "รอก่อนไอสลัด", TextColor3 = Color3.fromRGB(245,245,245),
    Font = Enum.Font.GothamBold, TextSize = 20,
}, loading)

-- Build the main interface under xpcall so an initialization error is visible
-- instead of leaving the loading screen stuck forever.
local loadingDetail
local loadingBar = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.69),
    Size = UDim2.new(0.5, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(15, 45, 20),
    BorderSizePixel = 0,
}, loading)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, loadingBar)
local loadingFill = make("Frame", {
    Size = UDim2.fromScale(0.05, 1), BackgroundColor3 = Color3.fromRGB(35, 255, 30),
    BorderSizePixel = 0,
}, loadingBar)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, loadingFill)

-- Hard fallback: whatever happens, the overlay never stays longer than 20s.
task.delay(20, function()
    if loadingGui and loadingGui.Parent then loadingGui:Destroy() end
end)

task.delay(15, function()
    if loadingGui and loadingGui.Parent then
        warn("[BALL KUN HUB] Loading watchdog: UI did not finish within 15 seconds.")
        loadingTitle.Text = "BALL KUN HUB - TIMEOUT"
        if loadingDetail then
            loadingDetail.Text = "ระบบเริ่มต้นนานเกินไป กรุณาตรวจสอบ Output ใน Roblox Studio"
        end
        task.delay(8, function()
            if loadingGui and loadingGui.Parent then loadingGui:Destroy() end
        end)
    end
end)

loadingDetail = make("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.60),
    Size = UDim2.new(0.9, 0, 0, 54), BackgroundTransparency = 1,
    Text = "กำลังเริ่มต้นระบบ...", TextColor3 = Color3.fromRGB(180, 220, 180),
    Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true,
}, loading)

local buildOK, buildError = xpcall(function()
local gui = make("ScreenGui", {
    Name = "MahanakhonHubV2",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)
connect(gui.Destroying, disconnectAll)

local root = make("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(800, 540),
    BackgroundColor3 = "@bg",
    BorderSizePixel = 0,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 14)}, root)
make("UIStroke", {Color = "@line", Thickness = 1}, root)
local backgroundArt = make("ImageLabel", {
    Name = "BALLKUN_Background",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = BACKGROUND_IMAGE,
    ImageTransparency = 0.78,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 0,
}, root)
make("UICorner", {CornerRadius = UDim.new(0, 14)}, backgroundArt)
local scale = make("UIScale", {Scale = 1}, root)
local side, content, brand, subtitle, mini, showTab

local function updateScale()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local v = cam.ViewportSize
    if v.X < 650 then
        root.Size = UDim2.new(0.96, 0, 0.86, 0)
        scale.Scale = 1
        if side then side.Position = UDim2.fromOffset(8, 70); side.Size = UDim2.new(0, 126, 1, -80) end
        if content then content.Position = UDim2.fromOffset(142, 70); content.Size = UDim2.new(1, -150, 1, -80) end
        if brand then brand.TextSize = 15 end
        if subtitle then subtitle.TextSize = 11 end
    else
        root.Size = UDim2.fromOffset(800, 540)
        scale.Scale = math.clamp(math.min(v.X / 960, v.Y / 680), 0.72, 1) * (State.boost or 1)
        if side then side.Position = UDim2.fromOffset(12, 72); side.Size = UDim2.new(0, 178, 1, -86) end
        if content then content.Position = UDim2.fromOffset(202, 72); content.Size = UDim2.new(1, -214, 1, -86) end
        if brand then brand.TextSize = 19 end
        if subtitle then subtitle.TextSize = 12 end
    end
end
updateScale()
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    local cam = Workspace.CurrentCamera
    if cam then
        connect(cam:GetPropertyChangedSignal("ViewportSize"), updateScale)
    end
    updateScale()
end)
if Workspace.CurrentCamera then
    connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
end

local top = make("Frame", {
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundColor3 = "@panel",
    BorderSizePixel = 0,
}, root)
make("UICorner", {CornerRadius = UDim.new(0, 14)}, top)
make("Frame", {
    Position = UDim2.new(0, 0, 1, -14),
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundColor3 = "@panel",
    BorderSizePixel = 0,
}, top)

brand = make("TextLabel", {
    Position = UDim2.fromOffset(20, 6),
    Size = UDim2.fromOffset(360, 27),
    BackgroundTransparency = 1,
    Text = "BALL KUN  /  มหานคร",
    TextColor3 = "@text",
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    TextXAlignment = Enum.TextXAlignment.Left,
}, top)
subtitle = make("TextLabel", {
    Position = UDim2.fromOffset(21, 34),
    Size = UDim2.fromOffset(480, 18),
    BackgroundTransparency = 1,
    Text = "BALL KUN • MAHANAKHON  |  v4.1",
    TextColor3 = "@muted",
    Font = FONT,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
}, top)

local close = make("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.fromOffset(40, 38),
    BackgroundColor3 = Color3.fromRGB(150, 45, 60),
    Text = "×",
    TextColor3 = "@text",
    Font = Enum.Font.GothamBold,
    TextSize = 24,
    AutoButtonColor = true,
}, top)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, close)

side = make("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 72),
    Size = UDim2.new(0, 178, 1, -86),
    BackgroundColor3 = "@panel",
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    BorderSizePixel = 0,
}, root)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, side)
local sideLayout = make("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, side)
make("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    PaddingLeft = UDim.new(0, 9),
    PaddingRight = UDim.new(0, 9),
}, side)

content = make("Frame", {
    Position = UDim2.fromOffset(202, 72),
    Size = UDim2.new(1, -214, 1, -86),
    BackgroundTransparency = 1,
}, root)

local pageTitle = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundTransparency = 1,
    Text = "ภาพรวม",
    TextColor3 = "@text",
    Font = Enum.Font.GothamBold,
    TextSize = 23,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)
local pageDesc = make("TextLabel", {
    Position = UDim2.fromOffset(0, 33),
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
    Text = "สถานะเกมและเครื่องมือหลัก",
    TextColor3 = "@muted",
    Font = FONT,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)
local pageBody = make("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 64),
    Size = UDim2.new(1, 0, 1, -64),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = "@accent",
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, content)
make("UIListLayout", {
    Padding = UDim.new(0, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, pageBody)

local function clearPage()
    for _, child in ipairs(pageBody:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
end

local function card(title, desc, rightWidth)
    rightWidth = rightWidth or 0
    local f = make("Frame", {
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "@panel",
        BackgroundTransparency = 0.03,
        BorderSizePixel = 0,
    }, pageBody)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, f)
    make("UIStroke", {Color = "@line", Thickness = 1, Transparency = 0.4}, f)
    make("UISizeConstraint", {MinSize = Vector2.new(0, 70)}, f)
    local box = make("Frame", {
        Size = UDim2.new(1, rightWidth > 0 and -(rightWidth + 28) or 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, f)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
    }, box)
    make("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, box)
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = "@text",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    }, box)
    if desc and desc ~= "" then
        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = desc,
            TextColor3 = "@muted",
            Font = FONT,
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = 2,
        }, box)
    end
    return f
end

local function sectionLabel(text)
    return make("TextLabel", {
        Size = UDim2.new(1, -8, 0, 28),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = "@accent",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, pageBody)
end

local function button(parent, label, callback, width)
    local b = make("TextButton", {
        Size = UDim2.fromOffset(width or 120, 36),
        BackgroundColor3 = "@panel2",
        Text = label,
        TextColor3 = "@text",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        AutoButtonColor = true,
    }, parent)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, b)
    make("UIStroke", {Color = "@line", Thickness = 1}, b)
    connect(b.Activated, callback)
    return b
end

local function rowCard(title, desc, actionText, callback)
    local f = card(title, desc, 108)
    local b = button(f, actionText, callback, 108)
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, -14, 0.5, 0)
    return f, b
end

-- Slide switch: green + "เปิด" when on, grey + "ปิด" when off.
local function makeSwitch(parent, initial, onChange)
    local on = initial and true or false
    local OFF = Color3.fromRGB(80, 88, 100)
    local sw = make("TextButton", {
        Size = UDim2.fromOffset(80, 36),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Text = "", AutoButtonColor = false, BorderSizePixel = 0,
        BackgroundColor3 = OFF,
    }, parent)
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, sw)
    local label = make("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 14, Text = "",
    }, sw)
    local knob = make("Frame", {
        Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0,
    }, sw)
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)
    local function render(animate)
        sw.BackgroundColor3 = on and Theme.accent or OFF
        label.Text = on and "เปิด" or "ปิด"
        label.TextColor3 = on and Theme.bg or Color3.fromRGB(240, 243, 248)
        label.Position = on and UDim2.fromOffset(0, 0) or UDim2.fromOffset(40, 0)
        local goal = on and UDim2.new(1, -32, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)
        if animate then
            knob:TweenPosition(goal, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.12, true)
        else
            knob.Position = goal
        end
    end
    render(false)
    connect(sw.Activated, function()
        on = not on
        render(true)
        onChange(on)
    end)
    return sw
end

local function setStatus(text)
    subtitle.Text = "บอลคุง ไงหนู  •  " .. tostring(text)
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRootPart()
    local ch = getCharacter()
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function countDescendants(rootObj, predicate)
    local n = 0
    for _, obj in ipairs(rootObj:GetDescendants()) do
        if predicate(obj) then n += 1 end
    end
    return n
end

local function removeHighlights(prefix)
    for obj, h in pairs(State.highlights) do
        local matches = not prefix or (h and h.Name:sub(1, #prefix) == prefix)
        if matches then
            if h and h.Parent then
                h:Destroy()
            end
            State.highlights[obj] = nil
        end
    end
end

local function addHighlight(obj, name, color)
    if not obj or not obj.Parent or State.highlights[obj] then return end
    if obj:IsA("Attachment") then obj = obj.Parent end
    if not obj or not (obj:IsA("BasePart") or obj:IsA("Model")) then return end
    local h = Instance.new("Highlight")
    h.Name = name
    h.Adornee = obj
    h.FillColor = color
    h.OutlineColor = color
    h.FillTransparency = 0.78
    h.OutlineTransparency = 0.08
    h.DepthMode = Enum.HighlightDepthMode.Occluded
    h.Parent = gui
    State.highlights[obj] = h
end

local function clearWaypoint()
    if State.waypoint then State.waypoint:Destroy() State.waypoint = nil end
end

local function markWaypoint(part, label)
    clearWaypoint()
    if not part then return end
    local a = Instance.new("BillboardGui")
    a.Name = "LocalWaypoint"
    a.Size = UDim2.fromOffset(150, 36)
    a.StudsOffset = Vector3.new(0, 3, 0)
    a.AlwaysOnTop = true
    a.Adornee = part
    a.Parent = gui
    local t = make("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = "@bg",
        BackgroundTransparency = 0.12,
        Text = "◆  " .. label,
        TextColor3 = "@accent",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
    }, a)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, t)
    State.waypoint = a
end

local function scanWorld()
    if State.scanBusy then return nil end
    State.scanBusy = true
    local result = {prompts = {}, vehicles = {}, jobs = {}, landmarks = {}}
    local ok, err = pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                table.insert(result.prompts, obj)
                local p = obj.Parent
                local path = p and p:GetFullName() or ""
                local low = string.lower(path .. " " .. obj.Name)
                if string.find(low, "job") or string.find(low, "delivery") or string.find(low, "rider") then
                    table.insert(result.jobs, obj)
                end
            elseif obj:IsA("VehicleSeat") or obj:IsA("Seat") then
                local p = obj.Parent
                if p and (string.find(string.lower(p:GetFullName()), "vehicle") or string.find(string.lower(p.Name), "car") or string.find(string.lower(p.Name), "bike")) then
                    table.insert(result.vehicles, p)
                end
            end
        end
    end)
    State.scanBusy = false
    if not ok then warn("[MAHANAKHON HUB] scan error:", err) end
    State.lastScan = os.clock()
    return result
end

-- Cache prompts once, then maintain the cache as the map streams in/out.
-- This avoids a full Workspace:GetDescendants() scan every refresh.
local promptCache = {}
for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("ProximityPrompt") then
        table.insert(promptCache, obj)
    end
end
connect(Workspace.DescendantAdded, function(obj)
    if obj:IsA("ProximityPrompt") then
        table.insert(promptCache, obj)
    end
end)
connect(Workspace.DescendantRemoving, function(obj)
    if obj:IsA("ProximityPrompt") then
        for i = #promptCache, 1, -1 do
            if promptCache[i] == obj then
                table.remove(promptCache, i)
                break
            end
        end
    end
end)

local function nearestPrompt()
    local hrp = getRootPart()
    if not hrp then return nil end
    local best, bestDist
    for i = #promptCache, 1, -1 do
        local obj = promptCache[i]
        if not obj or not obj.Parent then
            table.remove(promptCache, i)
        elseif obj.Enabled then
            local part = obj.Parent
            if part and part:IsA("Attachment") then
                part = part.Parent
            end
            if part and part:IsA("BasePart") then
                local distance = (hrp.Position - part.Position).Magnitude
                if not bestDist or distance < bestDist then
                    best, bestDist = obj, distance
                end
            end
        end
    end
    return best, bestDist
end

local function makeToggle(parent, title, desc, initial, changed)
    local f = card(title, desc, 80)
    makeSwitch(f, initial, changed)
    return f
end

-- ===== Feature setters (shared by every page) =====
local function highlightWhere(prefix, color, finder)
    removeHighlights(prefix)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local target = finder(obj)
        if target then addHighlight(target, prefix, color) end
    end
end

local function setPromptESP(on)
    State.promptESP = on
    removeHighlights("PromptESP")
    if on then
        highlightWhere("PromptESP", Theme.accent, function(o)
            return o:IsA("ProximityPrompt") and o.Parent or nil
        end)
    end
end

local function setVehicleESP(on)
    State.vehicleESP = on
    removeHighlights("VehicleESP")
    if on then
        highlightWhere("VehicleESP", Theme.accent2, function(o)
            return o:IsA("VehicleSeat") and o or nil
        end)
    end
end

local function setJobESP(on)
    State.jobESP = on
    removeHighlights("JobESP")
    if on then
        highlightWhere("JobESP", Theme.good, function(o)
            if o:IsA("ProximityPrompt") then
                local path = string.lower(o:GetFullName())
                if string.find(path, "job") or string.find(path, "farm") or string.find(path, "delivery") or string.find(path, "cargo") then
                    return o.Parent
                end
            end
            return nil
        end)
    end
end

local function refreshNearest()
    local p = nearestPrompt()
    if not p then return end
    local part = p.Parent
    if part and part:IsA("Attachment") then part = part.Parent end
    if part and part:IsA("BasePart") and part ~= State.nearestPart then
        State.nearestPart = part
        markWaypoint(part, p.ActionText ~= "" and p.ActionText or p.Name)
    end
end

local function setAutoNearest(on)
    State.autoNearest = on
    State.nearestPart = nil
    if on then refreshNearest() else clearWaypoint() end
end

local function setMini(on)
    State.miniStatus = on
    if mini then mini.Visible = on end
end

local function setBackground(on)
    State.bgOn = on
    backgroundArt.Visible = on
end

local function setBoost(on)
    State.boost = on and 1.15 or 1
    updateScale()
end

local function setAllOff()
    setPromptESP(false)
    setVehicleESP(false)
    setJobESP(false)
    setAutoNearest(false)
    setMini(false)
    clearWaypoint()
end

local function switchPanel()
    sectionLabel("⚡ สวิตช์เปิด / ปิดฟังก์ชัน")
    makeToggle(pageBody, "✨ ไฮไลต์จุดกด", "ขอบเรืองบนจุดกดทุกจุดที่โหลดอยู่ในแผนที่", State.promptESP, setPromptESP)
    makeToggle(pageBody, "🏍️ ไฮไลต์เบาะรถ", "ขอบเรืองบนเบาะรถและมอเตอร์ไซค์", State.vehicleESP, setVehicleESP)
    makeToggle(pageBody, "🌾 ไฮไลต์จุดงาน / ฟาร์ม", "ขอบเรืองบนจุดงาน ส่งของ ฟาร์ม และสินค้า", State.jobESP, setJobESP)
    makeToggle(pageBody, "📍 หมุดจุดกดใกล้สุด (อัตโนมัติ)", "ปักหมุดจุดกดที่ใกล้ที่สุดและอัปเดตให้ทุก 2 วินาที", State.autoNearest, setAutoNearest)
    makeToggle(pageBody, "📊 แผงสถานะย่อ", "แสดงพลังชีวิต ความเร็ว และพิกัดที่มุมขวาบน", State.miniStatus, setMini)
    rowCard("⏻ ปิดทุกสวิตช์", "ปิดไฮไลต์และหมุดทั้งหมดในครั้งเดียว", "ปิดทั้งหมด", function()
        setAllOff()
        setStatus("ปิดทุกสวิตช์แล้ว")
        showTab(State.tab)
    end)
end

local function renderOverview()
    clearPage()
    local avatarCard = make("Frame", {
        Size = UDim2.new(1, -8, 0, 160),
        BackgroundColor3 = "@panel",
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
    }, pageBody)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, avatarCard)
    make("UIStroke", {Color = "@accent", Thickness = 1}, avatarCard)
    make("TextLabel", {
        Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 22),
        BackgroundTransparency = 1, Text = "👤 ตัวละครผู้เล่น 3 มิติ",
        TextColor3 = "@text", Font = Enum.Font.GothamBold, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, avatarCard)
    local viewport = make("ViewportFrame", {
        Position = UDim2.new(0.5, -53, 0, 38), Size = UDim2.fromOffset(106, 114),
        BackgroundColor3 = "@panel2", BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
    }, avatarCard)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, viewport)
    local avatar = getCharacter()
    if avatar then
        -- Character models may be non-Archivable; clone defensively so a preview
        -- failure never aborts the entire UI initialization.
        local wasArchivable = avatar.Archivable
        avatar.Archivable = true
        local cloneOK, clone = pcall(function() return avatar:Clone() end)
        avatar.Archivable = wasArchivable
        if cloneOK and clone then
            for _, item in ipairs(clone:GetDescendants()) do
                if item:IsA("Script") or item:IsA("LocalScript") then item:Destroy() end
            end
            local world = Instance.new("WorldModel")
            world.Parent = viewport
            clone.Parent = world
            local rootPart = clone:FindFirstChild("HumanoidRootPart")
            if rootPart then
                clone:PivotTo(CFrame.new(0, 0, 0))
                local cam = Instance.new("Camera")
                cam.CFrame = CFrame.new(Vector3.new(0, 2.2, 6), Vector3.new(0, 1.5, 0))
                cam.Parent = viewport
                viewport.CurrentCamera = cam
            else
                clone:Destroy()
            end
        else
            warn("[BALL KUN HUB] Avatar preview skipped:", tostring(clone))
            make("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Text = "ไม่สามารถแสดงตัวละครตัวอย่างได้", TextColor3 = "@muted",
                Font = FONT, TextSize = 10, TextWrapped = true,
            }, viewport)
        end
    end
    local ch = getCharacter()
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local hrp = getRootPart()
    local pos = hrp and hrp.Position
    card("👤 สถานะผู้เล่น", string.format(
        "ผู้เล่น: %s   |   พลังชีวิต: %s   |   ความเร็ว: %s\nพิกัด: %s",
        LocalPlayer.Name,
        hum and math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) or "N/A",
        hum and math.floor(hum.WalkSpeed) or "N/A",
        pos and string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z) or "N/A"
    ))
    switchPanel()
    sectionLabel("🛠️ เครื่องมือ")
    rowCard("🔎 สำรวจโลก", "ตรวจหาจุดกด งาน และเบาะยานพาหนะที่มองเห็นได้", "สแกน", function()
        local r = scanWorld()
        if r then
            setStatus(string.format("สแกนแล้ว: จุดกด %d / เบาะรถ %d", #r.prompts, #r.vehicles))
            renderOverview()
        end
    end)
    rowCard("📍 จุดกดที่ใกล้ที่สุด", "ปักหมุดจุดกดที่อยู่ใกล้ที่สุด โดยไม่กดใช้งานแทนผู้เล่น", "ปักหมุด", function()
        local p, d = nearestPrompt()
        if p then
            local part = p.Parent
            if part and part:IsA("Attachment") then part = part.Parent end
            if part and part:IsA("BasePart") then markWaypoint(part, p.ActionText ~= "" and p.ActionText or p.Name) end
            setStatus("จุดกดใกล้สุดห่าง " .. math.floor(d or 0) .. " studs")
        else
            setStatus("ไม่พบจุดกด")
        end
    end)
    rowCard("🧹 ล้างหมุด", "ลบหมุดที่สร้างไว้บนหน้าจอ", "ล้าง", function()
        clearWaypoint()
        setStatus("ล้างหมุดแล้ว")
    end)
    card("🧩 ระบบที่ตรวจพบ", "ตรวจพบหมวดงานส่งของ งานทั่วไป แข่งขัน โรงรถ แต่งรถ ECU ดูแลรถ สินค้า ลูกสูบ ป้าย หมวก ไดโน แผนที่ ภารกิจ และรางวัล ฮับนี้อ่านข้อมูลที่เครื่องมองเห็นเท่านั้น")
end

local function renderJobs()
    clearPage()
    card("📦 งานและส่งของ", "ไฟล์สำรวจเกมพบระบบส่งของและงานต่าง ๆ การเริ่ม รับ หรือส่งงานให้ดำเนินการผ่านหน้าจอเกมตามปกติ")
    rowCard("📱 แอปส่งของ", "ตรวจหาแอปส่งของจากหน้าจอโทรศัพท์ในเกม", "ค้นหาแอป", function()
        local phone = PlayerGui:FindFirstChild("Phone")
        local app = phone and phone:FindFirstChild("Dock", true)
        local delivery = app and app:FindFirstChild("delivery", true)
        if delivery and delivery:IsA("GuiButton") then
            setStatus("พบแอปส่งของ - กดในโทรศัพท์ได้เลย")
        else
            setStatus("กรุณาเปิดโทรศัพท์ในเกมก่อน")
        end
    end)
    rowCard("📦 ตู้รับงาน", "ค้นหาและปักหมุดตำแหน่งตู้รับงานเมื่อโหลดเข้ามาแล้ว", "ค้นหาตู้", function()
        local root = Workspace:FindFirstChild("Map")
        local locker = root and root:FindFirstChild("JobLockers", true)
        local prompt = locker and locker:FindFirstChild("LockerPrompt", true)
        local part = prompt and prompt.Parent
        if part and part:IsA("Attachment") then part = part.Parent end
        if part and part:IsA("BasePart") then
            markWaypoint(part, "ตู้รับงาน")
            setStatus("พบตู้รับงาน")
        else
            setStatus("ตู้ยังไม่โหลดในแผนที่")
        end
    end)
    rowCard("📋 สถานะงานส่งของ", "อ่านข้อมูลสถานะงานที่เครื่องมองเห็นได้", "รีเฟรช", function()
        local found = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "DeliveryState" or obj.Name == "DeliveryJob" or obj.Name == "DeliveryArrived" then
                table.insert(found, obj:GetFullName() .. " = " .. tostring(obj.Value or obj:GetAttribute("Value") or "present"))
            end
        end
        setStatus(#found > 0 and ("พบข้อมูลสถานะ " .. #found .. " รายการ") or "ไม่พบข้อมูลสถานะในเครื่อง")
        if #found > 0 then print("[MAHANAKHON HUB] Delivery state:\n" .. table.concat(found, "\n")) end
    end)
    card("🛡️ ข้อจำกัดการทำงาน", "ไม่สร้างยอดงานปลอม ไม่เรียกคำสั่งเซิร์ฟเวอร์ และไม่กดรับรางวัลอัตโนมัติ")
end

local function renderVehicles()
    clearPage()
    card("🏍️ ระบบยานพาหนะ", "พบระบบรถยนต์ PCX160 โรงรถ ร้านแต่งรถ ECU ดูแลรถ รายละเอียดรถ และไดโน การเปลี่ยนค่าที่บันทึกกับเซิร์ฟเวอร์ให้ใช้เมนูในเกม")
    makeToggle(pageBody, "💡 ไฮไลต์เบาะรถ", "ไฮไลต์เบาะรถที่มองเห็นได้บนหน้าจอ", State.vehicleESP, setVehicleESP)
    rowCard("🚘 หน้าต่างโรงรถ", "ตรวจสอบว่าหน้าต่างโรงรถของเกมเปิดอยู่หรือไม่", "ตรวจสอบ", function()
        local g = PlayerGui:FindFirstChild("GarageWindow")
        setStatus(g and "พบหน้าต่างโรงรถ" or "กรุณาเปิดโรงรถในเกมก่อน")
    end)
    rowCard("🧽 หน้าต่างดูแลรถ", "ตรวจสอบหน้าต่างดูแลรถของเกม", "ตรวจสอบ", function()
        local v = PlayerGui:FindFirstChild("VehicleCare")
        setStatus(v and "พบหน้าต่างดูแลรถ" or "ยังไม่ได้เปิดหน้าต่างดูแลรถ")
    end)
    rowCard("🧹 ล้างไฮไลต์รถ", "ลบไฮไลต์ที่สร้างไว้บนหน้าจอ", "ล้าง", function()
        setVehicleESP(false)
        setStatus("ล้างไฮไลต์รถแล้ว")
        showTab(State.tab)
    end)
end

local function renderRace()
    clearPage()
    card("🏁 แข่งขันและสนาม", "พบระบบแข่งขัน ตัวนับถอยหลัง และคิวดวล การเข้าร่วมและผลการแข่งขันยังควบคุมโดยระบบเกม")
    rowCard("🔎 ตรวจหน้าต่างแข่ง", "ตรวจหาหน้าต่างการแข่งขันที่มองเห็นได้", "สแกน", function()
        local hits = {}
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            local n = string.lower(obj.Name)
            if string.find(n, "race") or string.find(n, "countdown") or string.find(n, "duel") then
                table.insert(hits, obj:GetFullName())
            end
        end
        setStatus(#hits > 0 and ("พบหน้าต่างแข่ง " .. #hits .. " รายการ") or "ยังไม่เปิดหน้าต่างแข่ง")
        for _, v in ipairs(hits) do print("[RACE UI]", v) end
    end)
    rowCard("📍 ตำแหน่งผู้เล่น", "แสดงตำแหน่งปัจจุบันในคอนโซล", "บันทึก", function()
        local p = getRootPart()
        if p then print("[MAHANAKHON HUB] Position:", p.Position) setStatus("บันทึกพิกัดแล้ว") else setStatus("ตัวละครยังไม่พร้อม") end
    end)
end

local function renderFarm()
    clearPage()
    card("🌾 ฟาร์มและสินค้า", "พบระบบตรวจฟาร์ม เก็บสินค้า ลูกสูบ และโฟลเดอร์ที่เกี่ยวข้อง หน้านี้ใช้ค้นหาและปักหมุดข้อมูลที่มองเห็นได้เท่านั้น")
    makeToggle(pageBody, "🌾 ไฮไลต์จุดงาน / ฟาร์ม", "ไฮไลต์จุดกดที่เกี่ยวข้องกับงาน ฟาร์ม ส่งของ หรือสินค้า", State.jobESP, setJobESP)
    rowCard("📦 สแกนสินค้า", "ค้นหาโมเดลและจุดกดที่เกี่ยวข้องกับสินค้า", "สแกน", function()
        local n = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local s = string.lower(obj.Name .. " " .. obj:GetFullName())
            if string.find(s, "cargo") or string.find(s, "piston") then
                n += 1
            end
        end
        setStatus("พบสินค้า / ลูกสูบ " .. n .. " รายการ")
    end)
    rowCard("🧹 ล้างหมุดฟาร์ม", "ลบไฮไลต์งานและฟาร์ม", "ล้าง", function()
        setJobESP(false)
        setStatus("ล้างหมุดฟาร์มแล้ว")
        showTab(State.tab)
    end)
end

local function renderMap()
    clearPage()
    card("🗺️ แผนที่อัจฉริยะ", "แผนที่ใช้ Workspace/Map และอาจโหลดวัตถุบางส่วนเมื่อเข้าใกล้พื้นที่เท่านั้น")
    makeToggle(pageBody, "✨ ไฮไลต์จุดกด", "ไฮไลต์จุดกดทั้งหมดที่โหลดอยู่ในขณะนี้", State.promptESP, setPromptESP)
    makeToggle(pageBody, "📍 หมุดจุดกดใกล้สุด (อัตโนมัติ)", "ปักหมุดจุดกดที่ใกล้ที่สุดและอัปเดตทุก 2 วินาที", State.autoNearest, setAutoNearest)
    rowCard("🗺️ สแกนแผนที่", "นับจุดกด เบาะรถ และวัตถุในแผนที่ที่โหลดอยู่", "สแกน", function()
        local r = scanWorld()
        if r then
            local map = Workspace:FindFirstChild("Map")
            local descendants = map and #map:GetDescendants() or 0
            setStatus(string.format("แผนที่ %d วัตถุ / จุดกด %d / เบาะรถ %d", descendants, #r.prompts, #r.vehicles))
        end
    end)
    rowCard("🧹 ล้างหมุดแผนที่", "ลบไฮไลต์จุดกดและหมุดนำทาง", "ล้าง", function()
        setPromptESP(false)
        setAutoNearest(false)
        clearWaypoint()
        setStatus("ล้างหมุดแผนที่แล้ว")
        showTab(State.tab)
    end)
end

local navButtons = {}

local function renderTools()
    clearPage()
    card("🧰 เครื่องมือในเครื่อง", "เครื่องมือด้านล่างทำงานเฉพาะหน้าจอผู้เล่น ไม่แก้ไขค่าการเล่นที่เซิร์ฟเวอร์ควบคุม")
    sectionLabel("🎨 การแสดงผล")
    makeToggle(pageBody, "🖼️ ภาพพื้นหลัง", "เปิดภาพพื้นหลังของหน้าต่าง ปิดไว้ตัวหนังสือจะชัดขึ้น", State.bgOn, setBackground)
    makeToggle(pageBody, "🔍 ขยาย UI 15%", "ทำให้หน้าต่างและตัวหนังสือใหญ่ขึ้น (เฉพาะหน้าจอใหญ่)", State.boost > 1, setBoost)
    sectionLabel("🛠️ เครื่องมือ")
    rowCard("👤 รีเฟรชตัวละคร", "อ่านข้อมูลตัวละครและพลังชีวิตอีกครั้ง", "รีเฟรช", function()
        local ch = getCharacter()
        local h = ch and ch:FindFirstChildOfClass("Humanoid")
        setStatus(h and ("พลังชีวิต " .. math.floor(h.Health)) or "ตัวละครยังไม่พร้อม")
    end)
    rowCard("🧹 ล้างข้อมูลชั่วคราว", "ลบหมุดและไฮไลต์ทั้งหมดที่ฮับนี้สร้างไว้", "ล้างทั้งหมด", function()
        setAllOff()
        removeHighlights()
        setStatus("ล้างหมุดทั้งหมดแล้ว")
        showTab(State.tab)
    end)
    rowCard("⏻ ปิดฮับ", "ยกเลิกการเชื่อมต่อและปิดหน้าต่างฮับ", "ปิดฮับ", function()
        for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
        removeHighlights()
        clearWaypoint()
        gui:Destroy()
    end)
end

local function renderSettings()
    clearPage()
    card("⚙️ ตั้งค่าหน้าตา", "เลือกสีหลักของ UI ได้ทันที และลากแถบด้านบนเพื่อย้ายตำแหน่งหน้าต่าง")
    local themeCard = card("🌈 สีธีม", "เลือกสีที่ต้องการ")
    local palettes = {
        {"เขียวนีออน", {bg=Color3.fromRGB(3,12,5),   panel=Color3.fromRGB(5,22,10),  panel2=Color3.fromRGB(10,42,18), line=Color3.fromRGB(25,210,55),  accent=Color3.fromRGB(35,255,30),  accent2=Color3.fromRGB(0,220,150)}},
        {"ฟ้าน้ำทะเล", {bg=Color3.fromRGB(3,8,14),   panel=Color3.fromRGB(6,18,30),  panel2=Color3.fromRGB(10,36,58), line=Color3.fromRGB(0,170,230),  accent=Color3.fromRGB(0,210,255),  accent2=Color3.fromRGB(40,120,255)}},
        {"ม่วง",       {bg=Color3.fromRGB(8,4,14),   panel=Color3.fromRGB(18,9,30),  panel2=Color3.fromRGB(36,18,60), line=Color3.fromRGB(150,70,230), accent=Color3.fromRGB(180,80,255), accent2=Color3.fromRGB(100,70,220)}},
        {"แดง",        {bg=Color3.fromRGB(14,4,5),   panel=Color3.fromRGB(28,8,10),  panel2=Color3.fromRGB(56,14,18), line=Color3.fromRGB(230,55,65),  accent=Color3.fromRGB(255,65,75),  accent2=Color3.fromRGB(255,130,30)}},
        {"ทอง",        {bg=Color3.fromRGB(14,10,3),  panel=Color3.fromRGB(28,20,6),  panel2=Color3.fromRGB(56,40,10), line=Color3.fromRGB(230,165,25), accent=Color3.fromRGB(255,190,35), accent2=Color3.fromRGB(255,115,20)}},
    }
    for i, palette in ipairs(palettes) do
        local b = button(themeCard, palette[1], function()
            for k, v in pairs(palette[2]) do Theme[k] = v end
            applyTheme()
            showTab(State.tab)
            setStatus("เปลี่ยนสีธีมแล้ว")
        end, 100)
        b.Position = UDim2.fromOffset(14 + ((i-1)%3)*108, 64 + math.floor((i-1)/3)*44)
        b.BackgroundColor3 = palette[2].accent
        b.TextColor3 = Color3.fromRGB(8, 12, 8)
    end
    themeCard.AutomaticSize = Enum.AutomaticSize.None
    themeCard.Size = UDim2.new(1, -8, 0, 156)
    rowCard("รีเซ็ตหน้าต่าง", "ย้ายหน้าต่างกลับมากึ่งกลางหน้าจอ", "จัดกลาง", function()
        root.Position = UDim2.fromScale(0.5, 0.5)
        setStatus("จัดหน้าต่างกลางจอแล้ว")
    end)
    rowCard("👁️ ซ่อน / แสดง UI", "กด RightControl เพื่อซ่อนหรือแสดงหน้าต่าง", "เข้าใจแล้ว", function()
        setStatus("กด RightControl เพื่อซ่อน/แสดง")
    end)
    card("👑 เกี่ยวกับฮับ", "BALL KUN HUB • MAHANAKHON v3.0  |  PlaceId 104549080643413\nClient-side companion. No remote invocation or server-side bypass.")
end

local pages = {
    Overview = {renderOverview, "Live player status and quick tools"},
    Jobs = {renderJobs, "Delivery, work and job discovery"},
    Vehicles = {renderVehicles, "Garage, bike, car and tuning"},
    Race = {renderRace, "Race interface and track utilities"},
    Farm = {renderFarm, "Farm checks, cargo and piston discovery"},
    Map = {renderMap, "Adaptive map and local markers"},
    Tools = {renderTools, "Local utilities and cleanup"},
    Settings = {renderSettings, "Interface and hub settings"},
}
local tabThai = {
    Overview = "🏠 ภาพรวม", Jobs = "📦 งาน / ส่งของ", Vehicles = "🏍️ รถและแต่งรถ",
    Race = "🏁 แข่งขัน", Farm = "🌾 ฟาร์ม", Map = "🗺️ แผนที่",
    Tools = "🧰 เครื่องมือ", Settings = "⚙️ ตั้งค่า"
}
local descThai = {
    Overview = "สถานะผู้เล่นและเครื่องมือหลัก",
    Jobs = "ระบบงานและการส่งของ",
    Vehicles = "โรงรถ รถยนต์ มอเตอร์ไซค์ และการแต่งรถ",
    Race = "ข้อมูลการแข่งขันและสนาม",
    Farm = "ตรวจสอบฟาร์ม สินค้า และจุดทำงาน",
    Map = "แผนที่และจุดที่ตรวจพบ",
    Tools = "เครื่องมือใช้งานเฉพาะเครื่อง",
    Settings = "ปรับแต่งหน้าตาและการใช้งาน"
}
function showTab(name)
    if not pages[name] then return end
    State.tab = name
    pageTitle.Text = tabThai[name] or name
    pageDesc.Text = descThai[name] or pages[name][2]
    for n, b in pairs(navButtons) do
        b.BackgroundColor3 = n == name and Theme.accent or Theme.panel2
        b.TextColor3 = n == name and Theme.bg or Theme.text
    end
    local ok, err = xpcall(pages[name][1], function(e)
        return debug.traceback(tostring(e), 2)
    end)
    if not ok then
        warn("[BALL KUN HUB] Tab render failed (" .. tostring(name) .. "):\n" .. tostring(err))
        clearPage()
        card("⚠️ โหลดหมวดหมู่ไม่สำเร็จ", "หมวดนี้เกิดข้อผิดพลาด แต่หน้าหลักยังใช้งานได้ กรุณาตรวจ Output ใน Roblox Studio")
        setStatus("พบข้อผิดพลาดในหมวด " .. tostring(name))
    end
end

local tabNames = {"Overview", "Jobs", "Vehicles", "Race", "Farm", "Map", "Tools", "Settings"}
for i, name in ipairs(tabNames) do
    local b = make("TextButton", {
        Name = name,
        Size = UDim2.new(1, -2, 0, 44),
        BackgroundColor3 = "@panel2",
        Text = tabThai[name] or name,
        TextColor3 = "@text",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = true,
        LayoutOrder = i,
    }, side)
    make("UICorner", {CornerRadius = UDim.new(0, 7)}, b)
    make("UIPadding", {PaddingLeft = UDim.new(0, 12)}, b)
    navButtons[name] = b
    connect(b.Activated, function() showTab(name) end)
end

mini = make("Frame", {
    Name = "MiniStatus",
    Position = UDim2.new(1, -276, 0, 14),
    Size = UDim2.fromOffset(262, 66),
    BackgroundColor3 = "@panel",
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Visible = State.miniStatus,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 9)}, mini)
make("UIStroke", {Color = "@line", Thickness = 1}, mini)
local miniText = make("TextLabel", {
    Position = UDim2.fromOffset(10, 7),
    Size = UDim2.new(1, -20, 1, -14),
    BackgroundTransparency = 1,
    Text = "BALL KUN HUB  •  พร้อมใช้งาน",
    TextColor3 = "@accent",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, mini)

-- Drag window from top bar.
local dragging, dragStart, startPos
connect(top.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = root.Position
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

connect(UserInputService.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightControl then
        root.Visible = not root.Visible
    end
end)
connect(close.Activated, function() root.Visible = false end)

-- Floating open/close button (mobile has no RightControl key)
local fab = make("TextButton", {
    Name = "ToggleHub",
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.fromOffset(48, 48),
    BackgroundColor3 = "@panel",
    Text = "BK",
    TextColor3 = "@accent",
    Font = Enum.Font.GothamBlack,
    TextSize = 16,
    ZIndex = 50,
}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, fab)
make("UIStroke", {Color = "@accent", Thickness = 1.5}, fab)
connect(fab.Activated, function() root.Visible = not root.Visible end)

-- Lightweight status refresh; no repeated Workspace scans.
local tickAccum = 0
connect(RunService.Heartbeat, function(dt)
    tickAccum += dt
    if tickAccum < 0.5 then return end
    tickAccum = 0
    local ch = getCharacter()
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local hrp = getRootPart()
    if hum and hrp then
        miniText.Text = string.format("BALL KUN HUB  •  พร้อมใช้งาน\nHP %d/%d  |  เร็ว %d\nพิกัด %.0f, %.0f, %.0f",
            math.floor(hum.Health), math.floor(hum.MaxHealth), math.floor(hum.WalkSpeed),
            hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
    else
        miniText.Text = "กำลังรอตัวละคร..."
    end
end)

local nearAccum = 0
connect(RunService.Heartbeat, function(dt)
    if not State.autoNearest then return end
    nearAccum += dt
    if nearAccum < 2 then return end
    nearAccum = 0
    refreshNearest()
end)

connect(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    setStatus("ตัวละครพร้อมแล้ว")
end)

showTab("Overview")
setStatus("พร้อมใช้งาน")
-- Reveal the main UI immediately after its shell is built; do not leave the
-- loading overlay covering a usable interface while optional content loads.
print("[BALL KUN HUB] Loaded v4.1 for PlaceId", PLACE_ID)

-- Finish the loading overlay (short progress animation, then remove).
-- Wrapped so an animation error can never keep the overlay on screen.
task.spawn(function()
    pcall(function()
        loadingDetail.Text = "พร้อมแล้ว"
        loadingFill:TweenSize(UDim2.fromScale(1, 1), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.9, true)
        task.wait(1.0)
    end)
    if loadingGui and loadingGui.Parent then loadingGui:Destroy() end
end)

-- Background image loading is intentionally asset-ID only.
-- This keeps the LocalScript compatible with Roblox Studio and avoids executor APIs.

end, function(err)
    return debug.traceback(tostring(err), 2)
end)

if not buildOK then
    warn("[BALL KUN HUB] UI initialization failed:\n" .. tostring(buildError))
    loadingTitle.Text = "BALL KUN HUB - ERROR"
    loadingTitle.TextColor3 = Color3.fromRGB(255, 90, 90)
    loadingDetail.Text = "เกิดข้อผิดพลาดตอนสร้าง UI\nดูรายละเอียดใน Output ของ Roblox Studio"
    loadingDetail.TextColor3 = Color3.fromRGB(255, 170, 170)
    task.delay(12, function()
        if loadingGui and loadingGui.Parent then loadingGui:Destroy() end
    end)
end
