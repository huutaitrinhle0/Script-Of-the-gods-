--[=[
    OVERLORD — OF THE GODS
    Developer Edition / Safe Architecture

    Derived design target:
      - Guard
      - Forge
      - Auto Farm (scan / preview)
      - Cloud Storage (catalog + notes; no remote execution)
      - AI diagnostics
      - Arena creation / adjustment
      - Automated zone blueprint builder

    Safety architecture:
      * No executor fingerprinting
      * No anti-ban / detection bypass
      * No synthetic input helpers
      * No runtime source-loader / remote code execution
      * No generic remote-event or prompt automation
      * Game actions are routed only through an explicitly provided
        server-side developer API named ReplicatedStorage.OVX_DevAPI.
        Your server must enforce permissions.

    Image support:
      UI.Config.HeroImage accepts an uploaded Roblox asset id.
      Replace the placeholder with your own Creator asset.

    Animation support:
      TweenService is used for UI motion and visual effects.
]=]

local VERSION = "26.10.02-GODS"
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CONFIG = {
    Title = "OVERLORD",
    Subtitle = "OF THE GODS",
    HeroImage = "rbxassetid://0", -- Replace with your own Roblox image asset.
    Accent = Color3.fromRGB(184, 134, 255),
    Accent2 = Color3.fromRGB(76, 221, 255),
    Background = Color3.fromRGB(9, 10, 16),
    Panel = Color3.fromRGB(17, 18, 28),
    Panel2 = Color3.fromRGB(23, 24, 38),
    Text = Color3.fromRGB(244, 244, 250),
    Muted = Color3.fromRGB(161, 163, 178),
    Good = Color3.fromRGB(111, 235, 165),
    Warn = Color3.fromRGB(255, 196, 92),
    Bad = Color3.fromRGB(255, 105, 120),
}

local State = {
    SecurityMode = true,
    Telemetry = false,
    CloudExecution = false,
    DeveloperApi = false,
    CurrentTab = "Dashboard",
    SelectedEgg = "All",
    SelectedZone = "Citadel",
    SelectedLayout = "Cross",
    PreviewArena = nil,
    EffectsDisabled = false,
    FullBright = false,
}

local Connections = {}
local ScreenGui
local OriginalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
}

local function Track(connection)
    table.insert(Connections, connection)
    return connection
end

local function Tween(instance, duration, props, style, direction)
    local info = TweenInfo.new(
        duration or 0.25,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(instance, info, props)
    tween:Play()
    return tween
end

local function Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function Stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or CONFIG.Accent
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = parent
    return s
end

local function Padding(parent, amount)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, amount)
    p.PaddingBottom = UDim.new(0, amount)
    p.PaddingLeft = UDim.new(0, amount)
    p.PaddingRight = UDim.new(0, amount)
    p.Parent = parent
    return p
end

local function NewLabel(parent, text, size, font, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = text or ""
    label.Font = font or Enum.Font.Gotham
    label.TextSize = size or 14
    label.TextColor3 = color or CONFIG.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function NewButton(parent, text, height)
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundColor3 = CONFIG.Panel2
    button.Text = text
    button.TextColor3 = CONFIG.Text
    button.TextSize = 14
    button.Font = Enum.Font.GothamMedium
    button.Size = UDim2.new(1, 0, 0, height or 40)
    button.Parent = parent
    Corner(button, 9)
    Stroke(button, Color3.fromRGB(45, 46, 64), 1, 0.2)
    Track(button.MouseEnter:Connect(function()
        Tween(button, 0.15, {BackgroundColor3 = Color3.fromRGB(31, 32, 50)})
    end))
    Track(button.MouseLeave:Connect(function()
        Tween(button, 0.15, {BackgroundColor3 = CONFIG.Panel2})
    end))
    return button
end

local function NewToggle(parent, text, initial, callback)
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1, 0, 0, 42)
    holder.Parent = parent

    local label = NewLabel(holder, text, 13, Enum.Font.Gotham, CONFIG.Text)
    label.Size = UDim2.new(1, -70, 1, 0)

    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.Size = UDim2.fromOffset(46, 24)
    button.Position = UDim2.new(1, -46, 0.5, -12)
    button.Text = ""
    button.Parent = holder
    Corner(button, 12)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18, 18)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 3, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
    knob.Parent = button
    Corner(knob, 9)

    local enabled = initial == true
    local function render()
        Tween(button, 0.15, {
            BackgroundColor3 = enabled and CONFIG.Accent or Color3.fromRGB(50, 51, 65)
        })
        Tween(knob, 0.15, {
            Position = enabled and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        })
    end

    render()
    Track(button.MouseButton1Click:Connect(function()
        enabled = not enabled
        render()
        if callback then callback(enabled) end
    end))

    return {
        Set = function(value)
            enabled = value == true
            render()
            if callback then callback(enabled) end
        end,
        Get = function()
            return enabled
        end,
    }
end

local function Clear(container)
    for _, child in ipairs(container:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function Notify(title, message, kind)
    local color = CONFIG.Accent
    if kind == "good" then color = CONFIG.Good end
    if kind == "warn" then color = CONFIG.Warn end
    if kind == "bad" then color = CONFIG.Bad end

    local toast = Instance.new("Frame")
    toast.AnchorPoint = Vector2.new(1, 1)
    toast.Position = UDim2.new(1, 380, 1, -24)
    toast.Size = UDim2.fromOffset(330, 74)
    toast.BackgroundColor3 = CONFIG.Panel2
    toast.Parent = ScreenGui
    Corner(toast, 12)
    Stroke(toast, color, 1, 0.15)

    local titleLabel = NewLabel(toast, title, 14, Enum.Font.GothamBold, CONFIG.Text)
    titleLabel.Position = UDim2.fromOffset(16, 9)
    titleLabel.Size = UDim2.new(1, -30, 0, 20)

    local body = NewLabel(toast, message, 12, Enum.Font.Gotham, CONFIG.Muted)
    body.Position = UDim2.fromOffset(16, 31)
    body.Size = UDim2.new(1, -30, 0, 32)
    body.TextWrapped = true

    Tween(toast, 0.32, {Position = UDim2.new(1, -20, 1, -24)})
    task.delay(3.0, function()
        if toast.Parent then
            Tween(toast, 0.25, {Position = UDim2.new(1, 380, 1, -24)})
            task.delay(0.27, function()
                if toast then toast:Destroy() end
            end)
        end
    end)
end

-- GUI root
local old = PlayerGui:FindFirstChild("OVX_OfTheGods")
if old then old:Destroy() end

ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OVX_OfTheGods"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Animated backdrop
local Backdrop = Instance.new("Frame")
Backdrop.Size = UDim2.fromScale(1, 1)
Backdrop.BackgroundColor3 = CONFIG.Background
Backdrop.BorderSizePixel = 0
Backdrop.Parent = ScreenGui

local glow = Instance.new("Frame")
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.fromScale(0.5, 0.15)
glow.Size = UDim2.fromScale(0.65, 0.36)
glow.BackgroundColor3 = CONFIG.Accent
glow.BackgroundTransparency = 0.93
glow.Parent = Backdrop
Corner(glow, 999)

local glow2 = Instance.new("Frame")
glow2.AnchorPoint = Vector2.new(0.5, 0.5)
glow2.Position = UDim2.fromScale(0.15, 0.85)
glow2.Size = UDim2.fromScale(0.32, 0.28)
glow2.BackgroundColor3 = CONFIG.Accent2
glow2.BackgroundTransparency = 0.95
glow2.Parent = Backdrop
Corner(glow2, 999)

Track(RunService.RenderStepped:Connect(function()
    local t = os.clock()
    glow.Rotation = (t * 3) % 360
    glow2.Rotation = (-t * 2) % 360
end))

-- Splash
local Splash = Instance.new("Frame")
Splash.Size = UDim2.fromScale(1, 1)
Splash.BackgroundColor3 = CONFIG.Background
Splash.BorderSizePixel = 0
Splash.ZIndex = 100
Splash.Parent = ScreenGui

local emblem = Instance.new("Frame")
emblem.AnchorPoint = Vector2.new(0.5, 0.5)
emblem.Position = UDim2.fromScale(0.5, 0.45)
emblem.Size = UDim2.fromOffset(140, 140)
emblem.BackgroundTransparency = 1
emblem.ZIndex = 101
emblem.Parent = Splash

local emblemRing = Instance.new("Frame")
emblemRing.Size = UDim2.fromScale(1, 1)
emblemRing.BackgroundTransparency = 1
emblemRing.ZIndex = 101
emblemRing.Parent = emblem
Corner(emblemRing, 999)
Stroke(emblemRing, CONFIG.Accent, 2, 0.05)

local emblemInner = Instance.new("Frame")
emblemInner.AnchorPoint = Vector2.new(0.5, 0.5)
emblemInner.Position = UDim2.fromScale(0.5, 0.5)
emblemInner.Size = UDim2.fromScale(0.68, 0.68)
emblemInner.BackgroundColor3 = CONFIG.Panel2
emblemInner.ZIndex = 102
emblemInner.Parent = emblem
Corner(emblemInner, 999)
Stroke(emblemInner, CONFIG.Accent2, 1, 0.25)

local emblemText = NewLabel(emblemInner, "Ω", 58, Enum.Font.GothamBlack, CONFIG.Text)
emblemText.Size = UDim2.fromScale(1, 1)
emblemText.TextXAlignment = Enum.TextXAlignment.Center
emblemText.ZIndex = 103

local splashTitle = NewLabel(Splash, CONFIG.Title, 24, Enum.Font.GothamBlack, CONFIG.Text)
splashTitle.AnchorPoint = Vector2.new(0.5, 0)
splashTitle.Position = UDim2.fromScale(0.5, 0.58)
splashTitle.Size = UDim2.fromOffset(260, 34)
splashTitle.TextXAlignment = Enum.TextXAlignment.Center
splashTitle.ZIndex = 101

local splashSub = NewLabel(Splash, CONFIG.Subtitle, 13, Enum.Font.GothamMedium, CONFIG.Accent)
splashSub.AnchorPoint = Vector2.new(0.5, 0)
splashSub.Position = UDim2.fromScale(0.5, 0.63)
splashSub.Size = UDim2.fromOffset(280, 24)
splashSub.TextXAlignment = Enum.TextXAlignment.Center
splashSub.ZIndex = 101

Tween(emblem, 0.8, {Rotation = 360})
Track(RunService.RenderStepped:Connect(function()
    if emblem and emblem.Parent then
        emblemRing.Rotation = (os.clock() * 22) % 360
        emblemText.TextTransparency = 0.08 + math.sin(os.clock() * 2.2) * 0.08
    end
end))

task.delay(1.2, function()
    Tween(Splash, 0.45, {BackgroundTransparency = 1})
    Tween(emblem, 0.4, {Size = UDim2.fromOffset(180, 180)})
    Tween(splashTitle, 0.4, {TextTransparency = 1})
    Tween(splashSub, 0.4, {TextTransparency = 1})
    task.delay(0.46, function()
        if Splash then Splash:Destroy() end
    end)
end)

-- Main window
local Window = Instance.new("Frame")
Window.AnchorPoint = Vector2.new(0.5, 0.5)
Window.Position = UDim2.fromScale(0.5, 0.53)
Window.Size = UDim2.new(0.91, 0, 0.84, 0)
Window.BackgroundColor3 = CONFIG.Panel
Window.BackgroundTransparency = 0.04
Window.BorderSizePixel = 0
Window.Parent = ScreenGui
Corner(Window, 18)
Stroke(Window, Color3.fromRGB(62, 63, 85), 1, 0.15)

-- Hero image / fallback
local Hero = Instance.new("ImageLabel")
Hero.Name = "HeroImage"
Hero.AnchorPoint = Vector2.new(1, 0)
Hero.Position = UDim2.new(1, -18, 0, 18)
Hero.Size = UDim2.fromOffset(190, 64)
Hero.BackgroundTransparency = 1
Hero.Image = CONFIG.HeroImage
Hero.ImageTransparency = 0.18
Hero.ScaleType = Enum.ScaleType.Crop
Hero.Parent = Window
Corner(Hero, 12)
Stroke(Hero, CONFIG.Accent, 1, 0.6)

local HeroFallback = NewLabel(Window, "⚡  Ω  ⚡", 22, Enum.Font.GothamBlack, CONFIG.Accent)
HeroFallback.AnchorPoint = Vector2.new(1, 0)
HeroFallback.Position = UDim2.new(1, -18, 0, 18)
HeroFallback.Size = UDim2.fromOffset(190, 64)
HeroFallback.TextXAlignment = Enum.TextXAlignment.Center
HeroFallback.BackgroundTransparency = 1
HeroFallback.Visible = CONFIG.HeroImage == "rbxassetid://0"

local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 84)
Top.BackgroundTransparency = 1
Top.Parent = Window

local brand = NewLabel(Top, CONFIG.Title, 18, Enum.Font.GothamBlack, CONFIG.Text)
brand.Position = UDim2.fromOffset(22, 14)
brand.Size = UDim2.fromOffset(220, 26)

local sub = NewLabel(Top, "OF THE GODS  •  " .. VERSION, 10, Enum.Font.GothamMedium, CONFIG.Accent)
sub.Position = UDim2.fromOffset(23, 41)
sub.Size = UDim2.fromOffset(320, 18)

local statusPill = Instance.new("Frame")
statusPill.Position = UDim2.fromOffset(22, 61)
statusPill.Size = UDim2.fromOffset(142, 18)
statusPill.BackgroundColor3 = Color3.fromRGB(22, 45, 37)
statusPill.Parent = Top
Corner(statusPill, 9)
local status = NewLabel(statusPill, "●  SECURE LOCAL MODE", 9, Enum.Font.GothamBold, CONFIG.Good)
status.Size = UDim2.fromScale(1, 1)
status.TextXAlignment = Enum.TextXAlignment.Center

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Position = UDim2.fromOffset(16, 96)
Sidebar.Size = UDim2.new(0, 180, 1, -112)
Sidebar.BackgroundColor3 = Color3.fromRGB(13, 14, 22)
Sidebar.Parent = Window
Corner(Sidebar, 14)
Stroke(Sidebar, Color3.fromRGB(46, 47, 66), 1, 0.25)
Padding(Sidebar, 10)

local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0, 7)
SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
SideLayout.Parent = Sidebar

local Content = Instance.new("Frame")
Content.Position = UDim2.new(0, 210, 0, 96)
Content.Size = UDim2.new(1, -226, 1, -112)
Content.BackgroundTransparency = 1
Content.Parent = Window

local PageScroller = Instance.new("ScrollingFrame")
PageScroller.Size = UDim2.fromScale(1, 1)
PageScroller.BackgroundTransparency = 1
PageScroller.BorderSizePixel = 0
PageScroller.ScrollBarThickness = 4
PageScroller.ScrollBarImageColor3 = CONFIG.Accent
PageScroller.CanvasSize = UDim2.new()
PageScroller.Parent = Content
Padding(PageScroller, 2)

local PageLayout = Instance.new("UIListLayout")
PageLayout.Padding = UDim.new(0, 10)
PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
PageLayout.Parent = PageScroller

local function Header(parent, title, description)
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1, 0, 0, 64)
    holder.Parent = parent
    local t = NewLabel(holder, title, 21, Enum.Font.GothamBlack, CONFIG.Text)
    t.Size = UDim2.new(1, 0, 0, 30)
    local d = NewLabel(holder, description, 11, Enum.Font.Gotham, CONFIG.Muted)
    d.Position = UDim2.fromOffset(0, 30)
    d.Size = UDim2.new(1, 0, 0, 30)
    d.TextWrapped = true
    return holder
end

local function Section(parent, title)
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(14, 15, 24)
    frame.Size = UDim2.new(1, 0, 0, 10)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Parent = parent
    Corner(frame, 12)
    Stroke(frame, Color3.fromRGB(43, 44, 62), 1, 0.35)
    Padding(frame, 12)
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame
    local head = NewLabel(frame, title, 13, Enum.Font.GothamBold, CONFIG.Accent)
    head.Size = UDim2.new(1, 0, 0, 22)
    return frame
end

local function Card(parent, text, value, accent)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 74)
    frame.BackgroundColor3 = CONFIG.Panel2
    frame.Parent = parent
    Corner(frame, 10)
    Stroke(frame, Color3.fromRGB(48, 49, 68), 1, 0.25)
    local v = NewLabel(frame, value, 24, Enum.Font.GothamBlack, accent or CONFIG.Text)
    v.Position = UDim2.fromOffset(14, 8)
    v.Size = UDim2.new(1, -28, 0, 32)
    local l = NewLabel(frame, text, 11, Enum.Font.Gotham, CONFIG.Muted)
    l.Position = UDim2.fromOffset(14, 43)
    l.Size = UDim2.new(1, -28, 0, 20)
    return frame
end

local function CreatePage(name, description)
    local page = Instance.new("Frame")
    page.Name = name
    page.BackgroundTransparency = 1
    page.Size = UDim2.new(1, 0, 0, 0)
    page.AutomaticSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = PageScroller
    Header(page, name, description)
    return page
end

local Pages = {}
Pages.Dashboard = CreatePage("Dashboard", "Throne room overview: secure, local, developer-oriented.")
Pages.Guard = CreatePage("🦖 Guard", "Guard tools are exposed through your own server-side developer API.")
Pages.Forge = CreatePage("🔨 Forge", "Crafting panel for game-owned developer/test actions.")
Pages.AutoFarm = CreatePage("🥚 Auto Farm", "Discovery + preview only. No synthetic input or generic prompt firing.")
Pages.Cloud = CreatePage("☁ Cloud Storage", "Store a script catalog and notes; remote code is never auto-executed.")
Pages.AI = CreatePage("🤖 AI", "Local diagnostics and guided review of your game/tool setup.")
Pages.Arena = CreatePage("🏜️🏞️ Arena", "Create and adjust arena layouts in a local, reversible preview.")
Pages.Build = CreatePage("🏠🏡 Zone Builder", "Generate reusable construction blueprints from templates and interest settings.")
Pages.Security = CreatePage("🔐 Security", "Privacy-first defaults for the toolkit and its cloud catalog.")
Pages.Settings = CreatePage("⚙ Settings", "Theme, image slot, animation and restore controls.")

-- Sidebar buttons
local TabMeta = {
    {"Dashboard", "◈  Dashboard"},
    {"Guard", "🦖  Guard"},
    {"Forge", "🔨  Forge"},
    {"AutoFarm", "🥚  Auto Farm"},
    {"Cloud", "☁  Cloud"},
    {"AI", "🤖  AI"},
    {"Arena", "🏜️  Arena"},
    {"Build", "🏠  Zone Builder"},
    {"Security", "🔐  Security"},
    {"Settings", "⚙  Settings"},
}

local TabButtons = {}
local function SelectTab(name)
    State.CurrentTab = name
    for key, btn in pairs(TabButtons) do
        local selected = key == name
        Tween(btn, 0.18, {
            BackgroundColor3 = selected and Color3.fromRGB(37, 31, 58) or Color3.fromRGB(13, 14, 22),
            TextColor3 = selected and CONFIG.Text or CONFIG.Muted,
        })
    end
    for key, page in pairs(Pages) do
        page.Visible = key == name
    end
    PageScroller.CanvasPosition = Vector2.new(0, 0)
end

for _, item in ipairs(TabMeta) do
    local key, label = item[1], item[2]
    local btn = NewButton(Sidebar, label, 36)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextColor3 = CONFIG.Muted
    btn.BackgroundColor3 = Color3.fromRGB(13, 14, 22)
    TabButtons[key] = btn
    Track(btn.MouseButton1Click:Connect(function()
        SelectTab(key)
    end))
end

-- Dashboard
local dashStats = Section(Pages.Dashboard, "DIVINE SYSTEM STATUS")
Card(dashStats, "UI animation", "ACTIVE", CONFIG.Good)
Card(dashStats, "Telemetry", "OFF", CONFIG.Good)
Card(dashStats, "Remote code", "BLOCKED", CONFIG.Good)
Card(dashStats, "Developer API", "CHECKING", CONFIG.Warn)

local dashModules = Section(Pages.Dashboard, "MODULES KEPT IN THIS BUILD")
local moduleText = NewLabel(dashModules,
    "🦖 Guard → các chức năng Guard\n" ..
    "🔨 Forge → các chức năng chế tạo\n" ..
    "🥚 Auto Farm → gom Egg/Selected by users (preview/scan)\n" ..
    "☁ Cloud → Cloud Storage / script catalog when requested\n" ..
    "🤖 AI → review + chẩn đoán lỗi\n" ..
    "🏜️🏞️ Arena → create + adjust areas\n" ..
    "🏠🏡 Zone Builder → automated design blueprints\n" ..
    "..............  ☞⁠￣⁠ᴥ⁠￣⁠☞  ..............",
    12, Enum.Font.Gotham, CONFIG.Text)
moduleText.Size = UDim2.new(1, 0, 0, 190)
moduleText.TextWrapped = true
moduleText.TextYAlignment = Enum.TextYAlignment.Top

local quick = Section(Pages.Dashboard, "QUICK ACTIONS")
local scan = NewButton(quick, "🔎  Scan developer API", 40)
local preview = NewButton(quick, "✨  Build sample arena preview", 40)
local clean = NewButton(quick, "🧹  Restore client presentation", 40)

-- Developer API adapter
local function GetDeveloperApi()
    if not State.DeveloperApi then return nil, "Developer API toggle is off." end
    if not workspace:GetAttribute("OVX_DeveloperMode") then
        return nil, "workspace.OVX_DeveloperMode is not enabled."
    end
    local api = ReplicatedStorage:FindFirstChild("OVX_DevAPI")
    if not api then
        return nil, "ReplicatedStorage.OVX_DevAPI not found."
    end
    if not api:IsA("RemoteFunction") then
        return nil, "OVX_DevAPI exists but is not a RemoteFunction."
    end
    return api
end

local function DevCall(action, payload)
    local api, err = GetDeveloperApi()
    if not api then
        Notify("Developer API", err, "warn")
        return nil, err
    end
    local ok, result = pcall(function()
        return api:InvokeServer(action, payload or {})
    end)
    if not ok then
        Notify("Developer API", "Server call failed; inspect your server handler.", "bad")
        return nil, result
    end
    return result
end

local function RefreshApiStatus()
    local api, err = GetDeveloperApi()
    if api then
        Notify("Developer API", "Connected to your game-owned API.", "good")
        status.Text = "●  DEV API READY"
        status.TextColor3 = CONFIG.Good
    else
        Notify("Developer API", err, "warn")
        status.Text = "●  SECURE LOCAL MODE"
        status.TextColor3 = CONFIG.Good
    end
end

Track(scan.MouseButton1Click:Connect(RefreshApiStatus))
Track(preview.MouseButton1Click:Connect(function()
    SelectTab("Arena")
    task.defer(function()
        local page = Pages.Arena
        if page then
            Notify("Arena", "Switched to local reversible preview mode.", "good")
        end
    end)
end))

-- Guard
local guard = Section(Pages.Guard, "GUARD CONTROL")
local guardInfo = NewLabel(guard, "These controls call named actions on OVX_DevAPI only. Your server decides what is allowed.", 11, Enum.Font.Gotham, CONFIG.Muted)
guardInfo.Size = UDim2.new(1, 0, 0, 34)
guardInfo.TextWrapped = true
for _, action in ipairs({"Guard:Start", "Guard:Stop", "Guard:Patrol"}) do
    local b = NewButton(guard, "🛡️  " .. action, 38)
    Track(b.MouseButton1Click:Connect(function()
        DevCall(action, {player = LocalPlayer.UserId})
    end))
end

-- Forge
local forge = Section(Pages.Forge, "FORGE WORKBENCH")
local forgeInfo = NewLabel(forge, "Safe request path: server-owned recipe validation, permissions and resource checks.", 11, Enum.Font.Gotham, CONFIG.Muted)
forgeInfo.Size = UDim2.new(1, 0, 0, 30)
forgeInfo.TextWrapped = true
local recipe = "StarterSword"
local recipeButtons = {"StarterSword", "HealthPotion", "CrystalKey", "DivineOre"}
for _, name in ipairs(recipeButtons) do
    local b = NewButton(forge, "🔨  " .. name, 38)
    Track(b.MouseButton1Click:Connect(function()
        recipe = name
        Notify("Forge selected", recipe, "good")
    end))
end
local craft = NewButton(forge, "⚒️  Request craft: " .. recipe, 42)
Track(craft.MouseButton1Click:Connect(function()
    DevCall("Forge:Craft", {recipe = recipe})
end))

-- Auto Farm (safe scan/preview)
local farm = Section(Pages.AutoFarm, "EGG / RESOURCE DISCOVERY")
local farmStatus = NewLabel(farm, "Scanning workspace objects…", 12, Enum.Font.GothamMedium, CONFIG.Text)
farmStatus.Size = UDim2.new(1, 0, 0, 24)
local farmList = NewLabel(farm, "", 11, Enum.Font.Gotham, CONFIG.Muted)
farmList.Size = UDim2.new(1, 0, 0, 90)
farmList.TextWrapped = true
farmList.TextYAlignment = Enum.TextYAlignment.Top
local selected = NewButton(farm, "🎯  Selected: All", 38)
local scanEggs = NewButton(farm, "🔎  Scan nearby Egg / Selected", 40)
Track(selected.MouseButton1Click:Connect(function()
    local options = {"All", "Egg", "Selected"}
    local current = table.find(options, State.SelectedEgg) or 1
    current = (current % #options) + 1
    State.SelectedEgg = options[current]
    selected.Text = "🎯  Selected: " .. State.SelectedEgg
end))
Track(scanEggs.MouseButton1Click:Connect(function()
    local names = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        local lower = string.lower(obj.Name)
        if string.find(lower, "egg", 1, true) or string.find(lower, "pickup", 1, true) or string.find(lower, "collect", 1, true) then
            table.insert(names, obj:GetFullName())
            if #names >= 12 then break end
        end
    end
    farmStatus.Text = "Found " .. tostring(#names) .. " matching objects."
    farmList.Text = (#names > 0 and table.concat(names, "\n") or "No matching objects found in current client view.")
    Notify("Auto Farm", "Discovery complete. No objects were activated.", "good")
end))
local farmPreview = NewButton(farm, "🧪  Request server preview (selected filter)", 40)
Track(farmPreview.MouseButton1Click:Connect(function()
    DevCall("AutoFarm:Preview", {filter = State.SelectedEgg})
end))

-- Cloud Storage
local cloud = Section(Pages.Cloud, "CLOUD STORAGE")
local cloudIntro = NewLabel(cloud, "Catalog storage is kept separate from execution. External code is displayed as metadata/text only; it is not runtime-executed.", 11, Enum.Font.Gotham, CONFIG.Muted)
cloudIntro.Size = UDim2.new(1, 0, 0, 44)
cloudIntro.TextWrapped = true

local CloudItems = {
    {Name = "Core Docs", Kind = "docs", Note = "Project notes and changelog."},
    {Name = "Arena Templates", Kind = "blueprints", Note = "Cross, Ring, Citadel and Ruins."},
    {Name = "Forge Recipes", Kind = "data", Note = "Server-validated recipe catalog."},
    {Name = "Requested Script Slots", Kind = "catalog", Note = "Store links/text for review — not execution."},
}
local cloudList = NewLabel(cloud, "", 12, Enum.Font.Gotham, CONFIG.Text)
cloudList.Size = UDim2.new(1, 0, 0, 120)
cloudList.TextWrapped = true
for _, item in ipairs(CloudItems) do
    local b = NewButton(cloud, "☁  " .. item.Name .. "  •  " .. item.Kind, 38)
    Track(b.MouseButton1Click:Connect(function()
        cloudList.Text = item.Name .. "\n" .. item.Note .. "\nMode: catalog-only / non-executing"
        Notify("Cloud Storage", item.Name .. " selected.", "good")
    end))
end

-- AI
local ai = Section(Pages.AI, "AI / DIAGNOSTICS")
local aiResult = NewLabel(ai, "Run Core Check to populate diagnostics.", 11, Enum.Font.Gotham, CONFIG.Muted)
aiResult.Size = UDim2.new(1, 0, 0, 140)
aiResult.TextWrapped = true
aiResult.TextYAlignment = Enum.TextYAlignment.Top
local coreCheck = NewButton(ai, "🧠  Core Check", 42)
local gameReview = NewButton(ai, "🧩  Review game integration", 42)
Track(coreCheck.MouseButton1Click:Connect(function()
    local report = {}
    table.insert(report, "Version: " .. VERSION)
    table.insert(report, "PlayerGui: " .. (PlayerGui and "OK" or "MISSING"))
    table.insert(report, "TweenService: OK")
    table.insert(report, "Telemetry: " .. (State.Telemetry and "ON" or "OFF"))
    table.insert(report, "Cloud execution: " .. (State.CloudExecution and "ON" or "OFF (recommended)"))
    table.insert(report, "Developer API: " .. (GetDeveloperApi() and "READY" or "NOT READY"))
    aiResult.Text = table.concat(report, "\n")
    Notify("AI", "Core diagnostic complete.", "good")
end))
Track(gameReview.MouseButton1Click:Connect(function()
    local checks = {
        "OVX_DeveloperMode attribute: " .. (workspace:GetAttribute("OVX_DeveloperMode") and "ON" or "OFF"),
        "OVX_DevAPI: " .. (ReplicatedStorage:FindFirstChild("OVX_DevAPI") and "FOUND" or "MISSING"),
        "HeroImage slot: " .. (CONFIG.HeroImage ~= "rbxassetid://0" and "CONFIGURED" or "PLACEHOLDER"),
    }
    aiResult.Text = table.concat(checks, "\n")
    Notify("AI", "Integration review complete.", "good")
end))

-- Arena
local arena = Section(Pages.Arena, "ARENA CREATOR")
local arenaStatus = NewLabel(arena, "Local preview only — nothing is persisted automatically.", 11, Enum.Font.Gotham, CONFIG.Muted)
arenaStatus.Size = UDim2.new(1, 0, 0, 25)
local zoneButton = NewButton(arena, "🏜️  Zone: Citadel", 38)
local layoutButton = NewButton(arena, "✚  Layout: Cross", 38)
local sizeButton = NewButton(arena, "📐  Size: 7", 38)
local createArena = NewButton(arena, "✨  Create / refresh preview", 42)
local clearArena = NewButton(arena, "🧹  Clear preview", 42)

local zoneOptions = {"Citadel", "Ruin", "Sanctuary", "Volcano"}
local layoutOptions = {"Cross", "Ring", "Grid", "Spiral"}
local arenaSize = 7

Track(zoneButton.MouseButton1Click:Connect(function()
    local i = table.find(zoneOptions, State.SelectedZone) or 1
    i = (i % #zoneOptions) + 1
    State.SelectedZone = zoneOptions[i]
    zoneButton.Text = "🏜️  Zone: " .. State.SelectedZone
end))
Track(layoutButton.MouseButton1Click:Connect(function()
    local i = table.find(layoutOptions, State.SelectedLayout) or 1
    i = (i % #layoutOptions) + 1
    State.SelectedLayout = layoutOptions[i]
    layoutButton.Text = "✚  Layout: " .. State.SelectedLayout
end))
Track(sizeButton.MouseButton1Click:Connect(function()
    arenaSize = arenaSize >= 13 and 7 or arenaSize + 2
    sizeButton.Text = "📐  Size: " .. arenaSize
end))

local function MakePart(name, cf, size, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Material = material or Enum.Material.SmoothPlastic
    p.Color = Color3.fromRGB(52, 50, 71)
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    return p
end

local function BuildPreview()
    if State.PreviewArena then State.PreviewArena:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "OVX_ArenaPreview"
    folder.Parent = workspace
    State.PreviewArena = folder

    local step = 10
    local center = MakePart("ArenaCenter", CFrame.new(0, 1, 0), Vector3.new(14, 2, 14), Enum.Material.Neon)
    center.Color = CONFIG.Accent
    center.Transparency = 0.35
    center.Parent = folder

    for x = -arenaSize, arenaSize do
        for z = -arenaSize, arenaSize do
            local include = false
            if State.SelectedLayout == "Cross" then
                include = x == 0 or z == 0
            elseif State.SelectedLayout == "Ring" then
                include = math.abs(math.abs(x) - math.abs(z)) <= 1 and math.max(math.abs(x), math.abs(z)) >= arenaSize - 1
            elseif State.SelectedLayout == "Grid" then
                include = (x % 2 == 0) or (z % 2 == 0)
            elseif State.SelectedLayout == "Spiral" then
                include = math.abs(x) + math.abs(z) <= math.max(1, math.floor(arenaSize * 0.9)) and ((x + z) % 2 == 0)
            end

            if include then
                local p = MakePart(
                    string.format("Tile_%d_%d", x, z),
                    CFrame.new(x * step, 0, z * step),
                    Vector3.new(8, 1, 8),
                    Enum.Material.Slate
                )
                p.Color = (x + z) % 2 == 0 and Color3.fromRGB(42, 44, 61) or Color3.fromRGB(27, 30, 46)
                p.Parent = folder
            end
        end
    end

    local banner = Instance.new("BillboardGui")
    banner.Name = "ArenaLabel"
    banner.Size = UDim2.fromOffset(260, 50)
    banner.StudsOffset = Vector3.new(0, 8, 0)
    banner.AlwaysOnTop = true
    banner.Parent = center
    local label = NewLabel(banner, "Ω  " .. State.SelectedZone .. "  •  " .. State.SelectedLayout, 14, Enum.Font.GothamBlack, CONFIG.Text)
    label.Size = UDim2.fromScale(1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Center
    Corner(label, 10)
    Stroke(label, CONFIG.Accent, 1, 0.2)
    label.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    label.BackgroundTransparency = 0.18

    arenaStatus.Text = "Preview generated: " .. State.SelectedZone .. " / " .. State.SelectedLayout .. " / size " .. arenaSize
    Notify("Arena", "Local preview generated.", "good")
end

Track(createArena.MouseButton1Click:Connect(BuildPreview))
Track(clearArena.MouseButton1Click:Connect(function()
    if State.PreviewArena then
        State.PreviewArena:Destroy()
        State.PreviewArena = nil
        arenaStatus.Text = "Preview cleared."
    end
end))

-- Zone Builder
local build = Section(Pages.Build, "AUTOMATED ZONE DESIGNER")
local buildInfo = NewLabel(build, "Generate a visual blueprint locally. Use the resulting recipe on your own server/editor pipeline.", 11, Enum.Font.Gotham, CONFIG.Muted)
buildInfo.Size = UDim2.new(1, 0, 0, 34)
buildInfo.TextWrapped = true
local interestButton = NewButton(build, "🎯  Interest: Balanced", 38)
local generateBlueprint = NewButton(build, "🏗️  Generate blueprint", 42)
local blueprintText = NewLabel(build, "", 11, Enum.Font.Code, CONFIG.Muted)
blueprintText.Size = UDim2.new(1, 0, 0, 140)
blueprintText.TextWrapped = true
blueprintText.TextYAlignment = Enum.TextYAlignment.Top

local interests = {"Balanced", "Combat", "Exploration", "Social", "Treasure"}
local currentInterest = 1
Track(interestButton.MouseButton1Click:Connect(function()
    currentInterest = (currentInterest % #interests) + 1
    interestButton.Text = "🎯  Interest: " .. interests[currentInterest]
end))
Track(generateBlueprint.MouseButton1Click:Connect(function()
    local interest = interests[currentInterest]
    local lines = {
        "ZONE_BLUEPRINT",
        "interest = " .. interest,
        "zone = " .. State.SelectedZone,
        "arena = " .. State.SelectedLayout,
        "modules = {spawn, core, reward, recovery, landmark}",
        "storage = local / manual publish",
        "persistence = server-owned",
    }
    blueprintText.Text = table.concat(lines, "\n")
    Notify("Zone Builder", "Blueprint generated locally.", "good")
end))

-- Security
local security = Section(Pages.Security, "PRIVACY / SECURITY MODE")
NewToggle(security, "Privacy & Security Mode", State.SecurityMode, function(v)
    State.SecurityMode = v
    State.Telemetry = not v
    State.CloudExecution = false
    Notify("Security", v and "Security mode enabled." or "Security mode disabled.", v and "good" or "warn")
end)
NewToggle(security, "Telemetry", false, function(v)
    State.Telemetry = v
    if v and State.SecurityMode then
        Notify("Security", "Telemetry is intentionally available as an explicit opt-in only.", "warn")
    end
end)
NewToggle(security, "Allow remote code execution", false, function(v)
    State.CloudExecution = false
    if v then
        Notify("Security", "Remote code execution stays disabled in this build.", "warn")
    end
end)
local securityNote = NewLabel(security,
    "This build intentionally keeps cloud storage as a catalog and disables anti-ban, executor concealment, synthetic input, generic remote automation, and external code execution.",
    11, Enum.Font.Gotham, CONFIG.Muted)
securityNote.Size = UDim2.new(1, 0, 0, 56)
securityNote.TextWrapped = true

-- Settings
local settings = Section(Pages.Settings, "PRESENTATION")
local compact = NewButton(settings, "🪟  Toggle compact window", 40)
local animate = NewButton(settings, "✨  Replay intro animation", 40)
local hero = NewButton(settings, "🖼️  Hero image slot: " .. CONFIG.HeroImage, 40)
local restore = NewButton(settings, "↩  Restore lighting / effects", 40)

Track(compact.MouseButton1Click:Connect(function()
    local current = Window.Size
    local compactSize = UDim2.new(0, 520, 0, 430)
    Window.Size = (current.X.Offset == 520) and UDim2.new(0.91, 0, 0.84, 0) or compactSize
end))
Track(animate.MouseButton1Click:Connect(function()
    emblem = nil
    Notify("Animation", "Main UI already uses looping tweens and transitions.", "good")
end))
Track(hero.MouseButton1Click:Connect(function()
    Notify("Hero image", "Replace CONFIG.HeroImage with your Roblox asset id (rbxassetid://...).", "warn")
end))
Track(restore.MouseButton1Click:Connect(function()
    Lighting.Brightness = OriginalLighting.Brightness
    Lighting.ClockTime = OriginalLighting.ClockTime
    Lighting.FogEnd = OriginalLighting.FogEnd
    Lighting.GlobalShadows = OriginalLighting.GlobalShadows
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
            obj.Enabled = true
        end
    end
    Notify("Restore", "Lighting and common visual effects restored.", "good")
end))

-- Minimal local presentation hotkey
Track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Window.Visible = not Window.Visible
    end
end))

-- Initial presentation + a small pulse on hero fallback.
Track(RunService.RenderStepped:Connect(function()
    if HeroFallback and HeroFallback.Parent then
        HeroFallback.TextTransparency = 0.08 + (math.sin(os.clock() * 1.8) + 1) * 0.06
    end
end))

SelectTab("Dashboard")
Notify("OVERLORD", "OF THE GODS is ready.", "good")

-- Cleanup if the GUI is removed.
ScreenGui.AncestryChanged:Connect(function(_, parent)
    if parent == nil then
        for _, connection in ipairs(Connections) do
            pcall(function() connection:Disconnect() end)
        end
        if State.PreviewArena then
            pcall(function() State.PreviewArena:Destroy() end)
        end
    end
end)
