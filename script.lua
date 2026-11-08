--[[
    Scorpion.wtf | Visual Private — clean / monochrome menu
    Insert — показать / скрыть меню
]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")

local player = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

-- выгрузка предыдущей копии
if env.ScorpionUnload then
    pcall(env.ScorpionUnload)
    env.ScorpionUnload = nil
end

local GuiParent = CoreGui
if typeof(gethui) == "function" then
    local ok, hidden = pcall(gethui)
    if ok and hidden then GuiParent = hidden end
end

for _, root in ipairs({CoreGui, GuiParent}) do
    pcall(function()
        for _, name in ipairs({"ScorpionSkeet_UI", "ScorpionCrosshair", "ScorpionVignette", "ScorpionIntro", "ScorpionESP_Gui", "ScorpionHUD"}) do
            local old = root:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)
end

-- ============================================================
--  ТЕМА (белый + прозрачный)
-- ============================================================
local Theme = {
    Back    = Color3.fromRGB(8, 8, 8),
    Black   = Color3.fromRGB(0, 0, 0),
    White   = Color3.fromRGB(255, 255, 255),
    Text    = Color3.fromRGB(235, 235, 235),
    TextDim = Color3.fromRGB(140, 140, 140),
    Accent  = Color3.fromRGB(255, 255, 255),
    Font    = Enum.Font.SourceSansSemibold,
}

-- чёрно-белая дорожка времени: ночь тёмная, день светлый
local DayTrack = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(18, 18, 18)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 235)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(18, 18, 18)),
})

-- акцентный цвет меню (меняется в Settings)
local AccentPresets = {
    {"White",  Color3.fromRGB(255, 255, 255)},
    {"Ice",    Color3.fromRGB(150, 205, 255)},
    {"Mint",   Color3.fromRGB(140, 255, 200)},
    {"Violet", Color3.fromRGB(190, 150, 255)},
    {"Rose",   Color3.fromRGB(255, 150, 185)},
    {"Orange", Color3.fromRGB(255, 175, 95)},
}
local AccentNames = {}
for i, c in ipairs(AccentPresets) do AccentNames[i] = c[1] end
local Accent = Theme.White
local accentRenders = {}
local function ApplyAccent(i)
    Accent = (AccentPresets[i] or AccentPresets[1])[2]
    for _, fn in ipairs(accentRenders) do pcall(fn) end
end

-- ============================================================
--  ХЕЛПЕРЫ
-- ============================================================
local connections = {}
local function bind(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function new(class, props)
    local inst = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else inst[k] = v end
    end
    inst.Parent = parent
    return inst
end

local function stroke(parent, transparency, color)
    return new("UIStroke", {
        Color = color or Theme.White,
        Transparency = transparency or 0.85,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function line(parent, pos, size)
    return new("Frame", {
        Position = pos, Size = size, BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = parent,
    })
end

local function makeText(parent, str, size, color, align)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Text = str,
        TextSize = size or 14,
        TextColor3 = color or Theme.Text,
        Font = Theme.Font,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.85,
        Parent = parent,
    })
end

-- ============================================================
--  КОНФИГ
-- ============================================================
local CONFIG_FILE = "scorpion_config.json"

local defaults = {
    -- camera
    fov = 70, zoomFov = 30, zoomKey = "",
    stretch = false, stretchX = 100, stretchY = 75,
    -- crosshair
    crosshairEnabled = false, crosshairStyle = 1, cLength = 6, cThickness = 2, cGap = 4, cSpeed = 150,
    cColor = 1, cRainbow = false, cOutline = true, cAlpha = 0,
    -- world
    customTimeEnabled = false, timeOfDay = 14, autoCycle = false, cycleSpeed = 6,
    vignetteEnabled = false,
    -- fx
    trailEnabled = false, jumpRingEnabled = false,
    -- highlight (свой персонаж / оружие)
    hlEnabled = false, hlChar = true, hlWeapon = true, hlColor = 1, hlFill = 65, hlOutline = 0,
    hlPulse = false, hlPulseSpeed = 3,
    -- arms skin
    skinEnabled = false, skinStyle = 1, skinColor = 1, skinTransparency = 45, skinReflect = 20,
    -- esp
    espEnabled = false, espBox = true, espName = true, espHealth = true, espDistance = true,
    espColor = 1, espMaxDist = 1500,
    espSnaplines = false, espSnapOrigin = 1, espHeadDot = false,
    espWeapon = false, espRainbow = false, espArrows = false, arrowRadius = 200,
    chamsRainbow = false,
    espBoxStyle = 1, boxFill = false, boxFillAlpha = 85, espSkeleton = false, espLook = false,
    espHpText = false, visCheck = false, hitMarker = false, dmgNumbers = false,
    -- chams
    chamsEnabled = false, chamsThrough = true, chamsColor = 3, chamsFill = 50, chamsOutline = 0,
    -- hitbox
    hbEnabled = false, hbSize = 8, hbTransparency = 70, hbPart = 1,
    -- lighting
    fullbright = false, noFog = false, ambientEnabled = false, ambientColor = 1,
    -- color grading / bloom
    ccEnabled = false, ccBrightness = 0, ccContrast = 0, ccSaturation = 0, ccTint = 1,
    bloomEnabled = false, bloomIntensity = 40,
    -- hud
    hudEnabled = false, hudFps = true, hudPing = true,
    radarEnabled = false, radarSize = 150, radarRange = 200,
    sunRaysEnabled = false, sunRaysIntensity = 25, noBlur = false,
    fogEnabled = false, fogColor = 1, fogDist = 800,
    weatherEnabled = false, weatherKind = 1, weatherColor = 1, weatherRainbow = false,
    weatherDensity = 40, weatherSpeed = 100, weatherSize = 100, weatherWind = 0,
    atmEnabled = false, atmColor = 1, atmDecay = 1, atmDensity = 30, atmHaze = 0, atmGlare = 0,
    shiftEnabled = false, shiftTop = 1, shiftBottom = 1, shiftCycle = false,
    dofEnabled = false, dofFocus = 60, dofRadius = 20, dofFar = 60,
    auraEnabled = false, auraColor = 1, auraRainbow = false, auraDensity = 20, auraSize = 100,
    auraStyle = 1, auraColor2 = 3, auraSpeed = 100,
    hlRainbow = false, vigStrength = 65,
    trailStyle = 1, trailColor = 1, trailColor2 = 3, trailMode = 1, trailWidth = 100, trailLife = 100, trailAlpha = 30,
    ringEnabled = false, ringStyle = 1, ringColor = 1, ringRainbow = false, ringSize = 100,
    ringThick = 100, ringAlpha = 20, ringSpeed = 100, jumpColor = 1,
    jumpStyle = 1, jumpRainbow = false, jumpSize = 100, jumpDuration = 100, jumpThick = 100, jumpAlpha = 20,
    shotEnabled = false, shotSound = 1, shotVolume = 60, shotPitch = 100, shotRepeat = false,
    shotRate = 120, shotMute = false, shotNeedWeapon = true,
    -- menu
    uiScale = 100, menuKey = "Insert", menuAccent = 1, notify = true,
}

local cfg = {}
for k, v in pairs(defaults) do cfg[k] = v end

pcall(function()
    if isfile and readfile and isfile(CONFIG_FILE) then
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        for k, v in pairs(defaults) do
            if type(data[k]) == type(v) then cfg[k] = data[k] end
        end
    end
end)

local function SaveNow()
    pcall(function()
        if writefile then writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end
    end)
end

local saveQueued = false
local function QueueSave()
    if saveQueued then return end
    saveQueued = true
    task.delay(0.6, function()
        saveQueued = false
        SaveNow()
    end)
end

-- ============================================================
--  СОСТОЯНИЕ
-- ============================================================
Accent = (AccentPresets[cfg.menuAccent] or AccentPresets[1])[2]

local unloaded = false
local zoomActive = false
local Binding = false
local originalClock = Lighting.ClockTime
local originalFov = (workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView) or 70

local menuKey = Enum.KeyCode.Insert
do
    local ok, kc = pcall(function() return Enum.KeyCode[cfg.menuKey] end)
    if ok and kc then menuKey = kc end
end

local zoomKey
if cfg.zoomKey ~= "" then
    local ok, kc = pcall(function() return Enum.KeyCode[cfg.zoomKey] end)
    if ok then zoomKey = kc end
end

local timeSlider -- создаётся ниже, используется в рендер-цикле
local fovCur = cfg.fov -- текущее (сглаженное) значение FOV, которое мы сами держим

-- ============================================================
--  ПРИЦЕЛ
-- ============================================================
local ColorPresets = {
    {"White",  Color3.fromRGB(255, 255, 255)},
    {"Silver", Color3.fromRGB(190, 190, 196)},
    {"Ice",    Color3.fromRGB(170, 210, 255)},
    {"Mint",   Color3.fromRGB(160, 255, 215)},
    {"Rose",   Color3.fromRGB(255, 170, 195)},
    {"Black",  Color3.fromRGB(15, 15, 15)},
    {"Violet", Color3.fromRGB(190, 150, 255)},
    {"Orange", Color3.fromRGB(255, 175, 95)},
    {"Gold",   Color3.fromRGB(255, 215, 100)},
    {"Red",    Color3.fromRGB(255, 90, 90)},
    {"Blue",   Color3.fromRGB(90, 140, 255)},
    {"Green",  Color3.fromRGB(110, 255, 130)},
}
local ColorNames = {}
for i, c in ipairs(ColorPresets) do ColorNames[i] = c[1] end

local function rainbowColor()
    return Color3.fromHSV((os.clock() * 0.25) % 1, 0.85, 1)
end

local CrosshairGui = new("ScreenGui", {
    Name = "ScorpionCrosshair", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 990, Parent = GuiParent,
})
local updateCrosshair
do
local Cross = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(100, 100), BackgroundTransparency = 1, Visible = false, Parent = CrosshairGui,
})
local function crossPart(name)
    local f = new("Frame", {Name = name, BackgroundColor3 = Theme.White, BorderSizePixel = 0, Parent = Cross})
    stroke(f, 0.35, Theme.Black) -- тонкая чёрная обводка, чтобы было видно на светлом фоне
    return f
end
local cTop, cBottom, cLeft, cRight, cDot = crossPart("Top"), crossPart("Bottom"), crossPart("Left"), crossPart("Right"), crossPart("Dot")
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = cDot})

local cRing = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1,
    BorderSizePixel = 0, Visible = false, Parent = Cross,
})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = cRing})
local cRingStroke = new("UIStroke", {Thickness = 2, Color = Theme.White, Parent = cRing})


-- стили: 1 Cross, 2 Dot, 3 Spinning cross, 4 T-shape, 5 Circle, 6 Cross + dot, 7 X-cross, 8 Circle + dot, 9 Dynamic cross
local spin, dynGap = 0, 0
local crossParts = {cTop, cBottom, cLeft, cRight, cDot}

function updateCrosshair(dt)
    if not cfg.crosshairEnabled then
        Cross.Visible = false
        return
    end
    Cross.Visible = true

    local len, th, gap, style = cfg.cLength, cfg.cThickness, cfg.cGap, cfg.crosshairStyle
    local color = cfg.cRainbow and rainbowColor() or (ColorPresets[cfg.cColor] or ColorPresets[1])[2]
    local alpha = cfg.cAlpha / 100

    -- динамический разброс: прицел раскрывается при движении
    if style == 9 then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local speed = 0
        if hrp then
            local v = hrp.AssemblyLinearVelocity
            speed = Vector3.new(v.X, 0, v.Z).Magnitude
        end
        local target = math.clamp(speed / 3, 0, 16)
        dynGap += (target - dynGap) * math.clamp(dt * 10, 0, 1)
        gap = gap + dynGap
    end

    local showLines = style ~= 2 and style ~= 5 and style ~= 8
    local showDot = style == 2 or style == 6 or style == 8
    local showRing = style == 5 or style == 8

    cTop.Visible, cBottom.Visible, cLeft.Visible, cRight.Visible = showLines, showLines, showLines, showLines
    cDot.Visible = showDot
    cRing.Visible = showRing
    Cross.Rotation = 0

    if showLines then
        cTop.Size = UDim2.fromOffset(th, len)
        cTop.Position = UDim2.new(0.5, -th / 2, 0.5, -gap - len)
        cBottom.Size = UDim2.fromOffset(th, len)
        cBottom.Position = UDim2.new(0.5, -th / 2, 0.5, gap)
        cLeft.Size = UDim2.fromOffset(len, th)
        cLeft.Position = UDim2.new(0.5, -gap - len, 0.5, -th / 2)
        cRight.Size = UDim2.fromOffset(len, th)
        cRight.Position = UDim2.new(0.5, gap, 0.5, -th / 2)

        if style == 4 then
            cTop.Visible = false
        elseif style == 3 then
            spin = (spin + cfg.cSpeed * dt) % 360
            Cross.Rotation = spin
        elseif style == 7 then
            Cross.Rotation = 45
        end
    end

    if showDot then
        local d = (style == 2) and math.clamp(len, 2, 12) or math.clamp(th + 1, 2, 8)
        cDot.Size = UDim2.fromOffset(d, d)
        cDot.Position = UDim2.new(0.5, -d / 2, 0.5, -d / 2)
    end

    if showRing then
        local d = math.max((len + gap) * 2, 8)
        cRing.Size = UDim2.fromOffset(d, d)
        cRingStroke.Thickness = th
        cRingStroke.Color = color
        cRingStroke.Transparency = alpha
    end

    for _, part in ipairs(crossParts) do
        part.BackgroundColor3 = color
        part.BackgroundTransparency = alpha
        local st = part:FindFirstChildOfClass("UIStroke")
        if st then st.Enabled = cfg.cOutline end
    end
end
end

-- ============================================================
--  ЭФФЕКТЫ: трейл, виньетка, кольцо при приземлении
-- ============================================================
local trailObjects = {}
local TRAIL_STYLES = {"Classic", "Ribbon", "Thin line", "Neon long", "Comet", "Sparks"}

local function setTrail(on)
    for _, o in ipairs(trailObjects) do o:Destroy() end
    trailObjects = {}
    if not on then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local c1 = (ColorPresets[cfg.trailColor] or ColorPresets[1])[2]
    local c2 = (ColorPresets[cfg.trailColor2] or ColorPresets[1])[2]
    local colorSeq
    if cfg.trailMode == 3 then
        colorSeq = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
            ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 90)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 140)),
            ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
        })
    elseif cfg.trailMode == 2 then
        colorSeq = ColorSequence.new(c1, c2)
    else
        colorSeq = ColorSequence.new(c1)
    end

    local alpha = cfg.trailAlpha / 100
    local w = cfg.trailWidth / 100
    local life = cfg.trailLife / 100
    local style = cfg.trailStyle

    -- 6: искры из-под ног
    if style == 6 then
        local feet = new("Attachment", {Position = Vector3.new(0, -2.5, 0), Parent = hrp})
        new("ParticleEmitter", {
            Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = colorSeq, LockedToPart = false,
            Rate = 45, Lifetime = NumberRange.new(0.6 * life, 1.1 * life), Speed = NumberRange.new(0.5, 2.5),
            SpreadAngle = Vector2.new(180, 180), LightEmission = 0.8, LightInfluence = 0,
            Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
            Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5 * w), NumberSequenceKeypoint.new(1, 0)}),
            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(1, 1)}),
            Parent = feet,
        })
        trailObjects = {feet}
        return
    end

    -- span (ширина ленты), lifetime, свечение, сужение к хвосту, поворот к камере
    local cfgs = {
        {2.0, 0.4, 0.5, false, false}, -- Classic
        {3.2, 0.6, 0.3, false, false}, -- Ribbon
        {0.35, 0.9, 0.6, false, true}, -- Thin line
        {1.2, 1.4, 1.0, false, false}, -- Neon long
        {2.4, 0.8, 0.9, true, false},  -- Comet
    }
    local st = cfgs[style] or cfgs[1]
    local span = st[1] * w

    local a0 = new("Attachment", {Position = Vector3.new(0, span / 2, 0.5), Parent = hrp})
    local a1 = new("Attachment", {Position = Vector3.new(0, -span / 2, 0.5), Parent = hrp})
    local t = new("Trail", {
        Attachment0 = a0, Attachment1 = a1, Lifetime = st[2] * life, LightEmission = st[3], MinLength = 0.05,
        FaceCamera = st[5], Color = colorSeq,
        Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(1, 1)}),
        WidthScale = st[4] and NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
            or NumberSequence.new(1),
        Parent = hrp,
    })
    trailObjects = {a0, a1, t}
end

local vignetteGui
local function setVignette(on)
    if vignetteGui then
        vignetteGui:Destroy()
        vignetteGui = nil
    end
    if not on then return end

    vignetteGui = new("ScreenGui", {
        Name = "ScorpionVignette", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 998, Parent = GuiParent,
    })
    local edge = 1 - cfg.vigStrength / 100
    local seq = NumberSequence.new({
        NumberSequenceKeypoint.new(0, edge),
        NumberSequenceKeypoint.new(0.25, 1),
        NumberSequenceKeypoint.new(0.75, 1),
        NumberSequenceKeypoint.new(1, edge),
    })
    for _, rot in ipairs({0, 90}) do
        local f = new("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = vignetteGui,
        })
        new("UIGradient", {Rotation = rot, Transparency = seq, Parent = f})
    end
end

local function spawnJumpRing(char)
    if unloaded or not cfg.jumpRingEnabled then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end

    -- высота земли под персонажем
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {char}
    local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -20, 0), rp)
    local y
    if hit then
        y = hit.Position.Y + 0.06
    else
        local offset = (hum.RigType == Enum.HumanoidRigType.R6) and 3 or (hum.HipHeight + hrp.Size.Y / 2)
        y = hrp.Position.Y - offset + 0.06
    end
    local center = Vector3.new(hrp.Position.X, y, hrp.Position.Z)

    local style = cfg.jumpStyle
    local dur = 0.7 * cfg.jumpDuration / 100
    local maxD = 14 * cfg.jumpSize / 100
    local color = cfg.jumpRainbow and rainbowColor() or (ColorPresets[cfg.jumpColor] or ColorPresets[1])[2]
    local alpha = cfg.jumpAlpha / 100
    local thick = 14 * cfg.jumpThick / 100

    -- одна волна: часть на земле с SurfaceGui-кольцом, которое расширяется и растворяется
    local function burst(delay, mul, d, thickMul, filled)
        task.delay(delay, function()
            if unloaded then return end
            local part = new("Part", {
                Name = "ScorpionJumpRing", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
                CastShadow = false, Transparency = 1, Size = Vector3.new(0.5, 0.05, 0.5),
                CFrame = CFrame.new(center), Parent = workspace,
            })
            local gui = new("SurfaceGui", {
                Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
                CanvasSize = Vector2.new(256, 256), LightInfluence = 0, Adornee = part, Parent = part,
            })
            local fr = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = color, BackgroundTransparency = filled and math.min(alpha + 0.3, 0.9) or 1,
                BorderSizePixel = 0, Parent = gui,
            })
            new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fr})
            local st = new("UIStroke", {
                Color = color, Thickness = thick * thickMul, Transparency = alpha,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = fr,
            })
            local ti = TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local grow = TweenService:Create(part, ti, {Size = Vector3.new(maxD * mul, 0.05, maxD * mul)})
            TweenService:Create(st, ti, {Transparency = 1}):Play()
            if filled then TweenService:Create(fr, ti, {BackgroundTransparency = 1}):Play() end
            grow.Completed:Once(function() part:Destroy() end)
            grow:Play()
        end)
    end

    -- стили: 1 Ring, 2 Disc, 3 Double ring, 4 Shockwave
    if style == 1 then
        burst(0, 1, dur, 1, false)
    elseif style == 2 then
        burst(0, 1, dur, 0.6, true)
    elseif style == 3 then
        burst(0, 1, dur, 1, false)
        burst(0.12, 0.7, dur, 0.8, false)
    else
        burst(0, 1.5, dur * 0.55, 1.6, false)
    end
end

-- ============================================================
--  ПЕРСОНАЖ
-- ============================================================
local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum.StateChanged:Connect(function(_, state)
            if state == Enum.HumanoidStateType.Landed then spawnJumpRing(char) end
        end)
    end

    if cfg.trailEnabled and char:WaitForChild("HumanoidRootPart", 5) and not unloaded then
        setTrail(true)
    end
end

if player.Character then task.spawn(setupCharacter, player.Character) end
bind(player.CharacterAdded, function(char) task.spawn(setupCharacter, char) end)

if cfg.vignetteEnabled then setVignette(true) end

-- ============================================================
--  МОДЕЛИ: подсветка своего персонажа / оружия и скины рук
--  (клиентская визуализация только своих объектов)
-- ============================================================

local SkinStyles = {
    {"Glass",       Enum.Material.Glass},
    {"Ice",         Enum.Material.Ice},
    {"Force field", Enum.Material.ForceField},
    {"Neon",        Enum.Material.Neon},
    {"Plastic",     Enum.Material.SmoothPlastic},
}
local SkinNames = {}
for i, s in ipairs(SkinStyles) do SkinNames[i] = s[1] end

-- ---------- подсветка ----------
local highlights = {}
local pulseT = 0

local function getViewmodel()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    for _, child in ipairs(cam:GetChildren()) do
        if child:IsA("Model") then return child end
    end
    return nil
end

local function setHighlight(key, target)
    local hl = highlights[key]
    if not target then
        if hl then
            hl:Destroy()
            highlights[key] = nil
        end
        return
    end
    if hl and hl.Parent ~= target then
        hl:Destroy()
        hl = nil
    end
    if not hl then
        hl = new("Highlight", {
            Name = "ScorpionHL", Adornee = target, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = target,
        })
        highlights[key] = hl
    end
end

local function refreshHighlights()
    if not cfg.hlEnabled then
        for key, hl in pairs(highlights) do
            hl:Destroy()
            highlights[key] = nil
        end
        return
    end
    local char = player.Character
    setHighlight("char", cfg.hlChar and char or nil)
    setHighlight("tool", (cfg.hlWeapon and char) and char:FindFirstChildOfClass("Tool") or nil)
    setHighlight("vm", cfg.hlWeapon and getViewmodel() or nil)
end

local function applyHighlightLook()
    local color = cfg.hlRainbow and rainbowColor() or (ColorPresets[cfg.hlColor] or ColorPresets[1])[2]
    local fill = cfg.hlFill / 100
    if cfg.hlPulse then
        local k = (math.sin(pulseT * cfg.hlPulseSpeed) + 1) / 2
        fill = fill + (1 - fill) * 0.55 * k
    end
    local outline = cfg.hlOutline / 100
    for _, hl in pairs(highlights) do
        hl.FillColor = color
        hl.OutlineColor = color
        hl.FillTransparency = fill
        hl.OutlineTransparency = outline
    end
end

-- ---------- скины рук ----------
local skinStore = setmetatable({}, {__mode = "k"}) -- part -> оригинальные свойства
local ARM_WORDS = {"arm", "hand", "glove", "sleeve", "finger", "wrist", "elbow"}

local function isArmPart(p)
    if not p:IsA("BasePart") then return false end
    local n = p.Name:lower()
    if n:find("armor", 1, true) or n:find("handle", 1, true) or n:find("guard", 1, true) then return false end
    if p:FindFirstAncestorOfClass("Accessory") or p:FindFirstAncestorOfClass("Tool") then return false end
    for _, w in ipairs(ARM_WORDS) do
        if n:find(w, 1, true) then return true end
    end
    return false
end

local function collectArmParts()
    local list = {}
    local char = player.Character
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if isArmPart(d) then list[#list + 1] = d end
        end
    end
    local cam = workspace.CurrentCamera
    if cam then
        for _, d in ipairs(cam:GetDescendants()) do
            if isArmPart(d) then list[#list + 1] = d end
        end
    end
    return list
end

local function restoreSkins()
    for p, s in pairs(skinStore) do
        if p.Parent then
            p.Material = s.Material
            p.Transparency = s.Transparency
            p.Color = s.Color
            p.Reflectance = s.Reflectance
        end
        skinStore[p] = nil
    end
end

local function refreshSkins()
    if not cfg.skinEnabled then
        if next(skinStore) then restoreSkins() end
        return
    end
    local material = (SkinStyles[cfg.skinStyle] or SkinStyles[1])[2]
    local color = (ColorPresets[cfg.skinColor] or ColorPresets[1])[2]
    local transparency = cfg.skinTransparency / 100
    local reflectance = cfg.skinReflect / 100

    for _, p in ipairs(collectArmParts()) do
        local s = skinStore[p]
        if not s then
            -- уже невидимые части (хелперы вьюмодели) не трогаем, чтобы они не появились
            if p.Transparency < 0.95 then
                skinStore[p] = {
                    Material = p.Material, Transparency = p.Transparency, Color = p.Color, Reflectance = p.Reflectance,
                }
                s = skinStore[p]
            end
        end
        if s then
            if p.Material ~= material then p.Material = material end
            if p.Color ~= color then p.Color = color end
            if p.Transparency ~= transparency then p.Transparency = transparency end
            if p.Reflectance ~= reflectance then p.Reflectance = reflectance end
        end
    end
end

local modelTimer = 0
local function updateModels(dt)
    pulseT += dt
    modelTimer -= dt
    if modelTimer <= 0 then
        modelTimer = 0.25
        refreshHighlights()
        refreshSkins()
    end
    applyHighlightLook()
end

local function cleanupModels()
    for key, hl in pairs(highlights) do
        hl:Destroy()
        highlights[key] = nil
    end
    restoreSkins()
end

-- ============================================================
--  ESP / CHAMS / HITBOX (другие игроки)
-- ============================================================
local EspGui = new("ScreenGui", {
    Name = "ScorpionESP_Gui", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 500, Parent = GuiParent,
})

local targets = {}      -- plr -> {box, boxStroke, hpBack, hpFill, info, nameLbl, subLbl, hl}
local hbOriginals = setmetatable({}, {__mode = "k"})  -- part -> {Size, Transparency, CanCollide}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- виден ли игрок из камеры (без стен)
local function isVisible(cam, char)
    local part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not part then return false end
    local ignore = {char, cam}
    if player.Character then ignore[#ignore + 1] = player.Character end
    rayParams.FilterDescendantsInstances = ignore
    local origin = cam.CFrame.Position
    return workspace:Raycast(origin, part.Position - origin, rayParams) == nil
end

local R15_BONES = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local R6_BONES = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}
local MAX_BONES = 14

local lastHp = setmetatable({}, {__mode = "k"}) -- humanoid -> прошлое здоровье

local function removeTarget(plr)
    local t = targets[plr]
    if not t then return end
    for _, k in ipairs({"box", "hpBack", "hpLbl", "nameLbl", "subLbl", "snap", "head", "arrow", "look", "hl"}) do
        if t[k] then t[k]:Destroy() end
    end
    for _, f in ipairs(t.corners) do f:Destroy() end
    for _, f in ipairs(t.bones) do f:Destroy() end
    targets[plr] = nil
end

-- ESP рисуется обычными Frame в экранных координатах (не BillboardGui),
-- поэтому stretch камеры не ломает позиции и ничего не "плавает"
local function createTarget(plr)
    local t = {corners = {}, bones = {}}

    t.box = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.White, BackgroundTransparency = 1,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })
    t.boxStroke = new("UIStroke", {Thickness = 1.5, Color = Theme.White, Parent = t.box})

    for i = 1, 8 do
        t.corners[i] = new("Frame", {
            BackgroundColor3 = Theme.White, BorderSizePixel = 0, Visible = false, Parent = EspGui,
        })
    end

    t.hpBack = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.3,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })
    t.hpFill = new("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(80, 255, 120), BorderSizePixel = 0, Parent = t.hpBack,
    })
    t.hpLbl = makeText(EspGui, "", 11, Theme.White, Enum.TextXAlignment.Right)
    t.hpLbl.AnchorPoint = Vector2.new(1, 0.5)
    t.hpLbl.Size = UDim2.fromOffset(30, 12)
    t.hpLbl.TextStrokeTransparency = 0.4
    t.hpLbl.Visible = false

    t.nameLbl = makeText(EspGui, plr.DisplayName, 13, Theme.White, Enum.TextXAlignment.Center)
    t.nameLbl.AnchorPoint = Vector2.new(0.5, 1)
    t.nameLbl.Size = UDim2.fromOffset(200, 14)
    t.nameLbl.TextStrokeTransparency = 0.4
    t.nameLbl.Visible = false

    t.subLbl = makeText(EspGui, "", 12, Theme.TextDim, Enum.TextXAlignment.Center)
    t.subLbl.AnchorPoint = Vector2.new(0.5, 0)
    t.subLbl.Size = UDim2.fromOffset(200, 14)
    t.subLbl.TextStrokeTransparency = 0.4
    t.subLbl.Visible = false

    t.snap = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 1), BackgroundColor3 = Theme.White,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })

    t.look = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 2), BackgroundColor3 = Theme.White,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })

    for i = 1, MAX_BONES do
        t.bones[i] = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 1), BackgroundColor3 = Theme.White,
            BorderSizePixel = 0, Visible = false, Parent = EspGui,
        })
    end

    t.head = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Theme.White,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = t.head})

    t.arrow = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 3), BackgroundColor3 = Theme.White,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })

    t.hl = new("Highlight", {Name = "ScorpionChams", Enabled = false, Parent = EspGui})

    targets[plr] = t
    return t
end

local function restoreHitboxes()
    for part, o in pairs(hbOriginals) do
        if part.Parent then
            part.Size = o.Size
            part.Transparency = o.Transparency
            part.CanCollide = o.CanCollide
        end
        hbOriginals[part] = nil
    end
end

local function hideTarget(t)
    t.box.Visible = false
    t.hpBack.Visible = false
    t.hpLbl.Visible = false
    t.nameLbl.Visible = false
    t.subLbl.Visible = false
    t.snap.Visible = false
    t.head.Visible = false
    t.arrow.Visible = false
    t.look.Visible = false
    for _, f in ipairs(t.corners) do f.Visible = false end
    for _, f in ipairs(t.bones) do f.Visible = false end
end

local function rnd(v) return math.floor(v + 0.5) end

-- линия между двумя экранными точками
local function setLine(f, a, b, color, thick)
    local d = b - a
    f.Size = UDim2.fromOffset(rnd(d.Magnitude), thick or 1)
    f.Position = UDim2.fromOffset(rnd((a.X + b.X) / 2), rnd((a.Y + b.Y) / 2))
    f.Rotation = math.deg(math.atan2(d.Y, d.X))
    f.BackgroundColor3 = color
    f.Visible = true
end

local function hbApply(part, on)
    if not part then return end
    if on then
        if not hbOriginals[part] then
            hbOriginals[part] = {Size = part.Size, Transparency = part.Transparency, CanCollide = part.CanCollide}
        end
        local sz = cfg.hbSize
        local size = Vector3.new(sz, sz, sz)
        if part.Size ~= size then part.Size = size end
        part.Transparency = cfg.hbTransparency / 100
        part.CanCollide = false
    elseif hbOriginals[part] then
        local o = hbOriginals[part]
        part.Size = o.Size
        part.Transparency = o.Transparency
        part.CanCollide = o.CanCollide
        hbOriginals[part] = nil
    end
end

-- ---------- хитмаркер и цифры урона ----------
local hitMarker = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40),
    BackgroundTransparency = 1, Parent = EspGui,
})
local hitPieces = {}
for _, p in ipairs({{-7, -7, 45}, {7, -7, -45}, {-7, 7, -45}, {7, 7, 45}}) do
    hitPieces[#hitPieces + 1] = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, p[1], 0.5, p[2]), Size = UDim2.fromOffset(9, 2),
        Rotation = p[3], BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        Parent = hitMarker,
    })
end

local function flashHitMarker()
    for _, f in ipairs(hitPieces) do
        f.BackgroundColor3 = Accent
        f.BackgroundTransparency = 0
        TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 1,
        }):Play()
    end
end

local function spawnDamageNumber(x, y, amount)
    local k = math.clamp(amount / 60, 0, 1)
    local lbl = makeText(EspGui, "-" .. math.floor(amount + 0.5), 16, Color3.new(1, 1 - k * 0.6, 1 - k * 0.6), Enum.TextXAlignment.Center)
    lbl.Font = Enum.Font.GothamBold
    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
    lbl.Size = UDim2.fromOffset(80, 20)
    lbl.Position = UDim2.fromOffset(rnd(x), rnd(y))
    lbl.TextStrokeTransparency = 0.3
    TweenService:Create(lbl, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.fromOffset(rnd(x) + math.random(-12, 12), rnd(y) - 45),
        TextTransparency = 1, TextStrokeTransparency = 1,
    }):Play()
    task.delay(0.85, function() lbl:Destroy() end)
end

local function updateTargets()
    local cam = workspace.CurrentCamera
    if not cam then return end

    local espColor = cfg.espRainbow and rainbowColor() or (ColorPresets[cfg.espColor] or ColorPresets[1])[2]
    local chamsColor = cfg.chamsRainbow and rainbowColor() or (ColorPresets[cfg.chamsColor] or ColorPresets[1])[2]
    local camPos = cam.CFrame.Position
    local vs = cam.ViewportSize

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local alive = hum and hrp and hum.Health > 0

            local t = targets[plr] or createTarget(plr)

            -- цвет по видимости: зелёный — виден, красный — за стеной
            local espColor, chamsColor = espColor, chamsColor
            if cfg.visCheck and alive and (cfg.espEnabled or cfg.chamsEnabled) then
                local c = isVisible(cam, char) and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 90, 90)
                espColor, chamsColor = c, c
            end

            -- ESP
            local dist = alive and (hrp.Position - camPos).Magnitude or math.huge
            local showEsp = cfg.espEnabled and alive and dist <= cfg.espMaxDist
            local drawn = false
            local onScr = false

            if showEsp then
                local pos = hrp.Position
                local feetOffset = (hum.RigType == Enum.HumanoidRigType.R6) and 3 or (hum.HipHeight + 1)
                local top = cam:WorldToViewportPoint(pos + Vector3.new(0, 2.6, 0))
                local bot = cam:WorldToViewportPoint(pos - Vector3.new(0, feetOffset, 0))

                if top.Z > 0 and bot.Z > 0 then
                    drawn = true
                    local h = math.max(math.abs(bot.Y - top.Y), 4)
                    local w = h * 0.55
                    local cx = (top.X + bot.X) / 2
                    local cy = (top.Y + bot.Y) / 2
                    local topY = cy - h / 2
                    local botY = cy + h / 2
                    local x0 = cx - w / 2
                    onScr = cx >= 0 and cx <= vs.X and cy >= 0 and cy <= vs.Y

                    -- box (полный / уголки) + заливка
                    local cornerMode = cfg.espBoxStyle == 2
                    t.box.Visible = cfg.espBox or cfg.boxFill
                    t.box.Position = UDim2.fromOffset(rnd(cx), rnd(cy))
                    t.box.Size = UDim2.fromOffset(rnd(w), rnd(h))
                    t.boxStroke.Enabled = cfg.espBox and not cornerMode
                    t.boxStroke.Color = espColor
                    t.box.BackgroundColor3 = espColor
                    t.box.BackgroundTransparency = cfg.boxFill and (cfg.boxFillAlpha / 100) or 1

                    if cfg.espBox and cornerMode then
                        local L = math.max(math.min(w, h) * 0.28, 4)
                        local th = 2
                        local X0, Y0, X1, Y1 = x0, topY, x0 + w, botY
                        local spec = {
                            {X0, Y0, L, th}, {X0, Y0, th, L},
                            {X1 - L, Y0, L, th}, {X1 - th, Y0, th, L},
                            {X0, Y1 - th, L, th}, {X0, Y1 - L, th, L},
                            {X1 - L, Y1 - th, L, th}, {X1 - th, Y1 - L, th, L},
                        }
                        for i = 1, 8 do
                            local sp = spec[i]
                            local f = t.corners[i]
                            f.Position = UDim2.fromOffset(rnd(sp[1]), rnd(sp[2]))
                            f.Size = UDim2.fromOffset(rnd(sp[3]), rnd(sp[4]))
                            f.BackgroundColor3 = espColor
                            f.Visible = true
                        end
                    else
                        for _, f in ipairs(t.corners) do f.Visible = false end
                    end

                    -- health bar + число
                    t.hpBack.Visible = cfg.espHealth
                    t.hpLbl.Visible = cfg.espHealth and cfg.espHpText
                    if cfg.espHealth then
                        local a = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        t.hpBack.Position = UDim2.fromOffset(rnd(x0) - 3, rnd(cy))
                        t.hpBack.Size = UDim2.fromOffset(3, rnd(h))
                        t.hpFill.Size = UDim2.fromScale(1, a)
                        t.hpFill.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 255, 120), a)
                        if cfg.espHpText then
                            t.hpLbl.Text = tostring(math.floor(hum.Health + 0.5))
                            t.hpLbl.Position = UDim2.fromOffset(rnd(x0) - 8, rnd(botY - a * h))
                        end
                    end

                    -- name / distance / weapon
                    t.nameLbl.Visible = cfg.espName
                    if cfg.espName then
                        t.nameLbl.Text = plr.DisplayName
                        t.nameLbl.TextColor3 = espColor
                        t.nameLbl.Position = UDim2.fromOffset(rnd(cx), rnd(topY) - 3)
                    end
                    local sub = {}
                    if cfg.espDistance then sub[#sub + 1] = string.format("%d studs", dist) end
                    if cfg.espWeapon then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool then sub[#sub + 1] = tool.Name end
                    end
                    t.subLbl.Visible = #sub > 0
                    if #sub > 0 then
                        t.subLbl.Text = table.concat(sub, "  |  ")
                        t.subLbl.Position = UDim2.fromOffset(rnd(cx), rnd(botY) + 3)
                    end

                    -- snapline
                    t.snap.Visible = cfg.espSnaplines
                    if cfg.espSnaplines then
                        local oy = (cfg.espSnapOrigin == 3) and 0 or ((cfg.espSnapOrigin == 2) and vs.Y / 2 or vs.Y)
                        setLine(t.snap, Vector2.new(vs.X / 2, oy), Vector2.new(cx, botY), espColor, 1)
                    end

                    -- skeleton
                    if cfg.espSkeleton then
                        local list = (hum.RigType == Enum.HumanoidRigType.R6) and R6_BONES or R15_BONES
                        for i = 1, MAX_BONES do
                            local f = t.bones[i]
                            local pair = list[i]
                            local ok = false
                            if pair then
                                local pa, pb = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
                                if pa and pb then
                                    local va = cam:WorldToViewportPoint(pa.Position)
                                    local vb = cam:WorldToViewportPoint(pb.Position)
                                    if va.Z > 0 and vb.Z > 0 then
                                        setLine(f, Vector2.new(va.X, va.Y), Vector2.new(vb.X, vb.Y), espColor, 1)
                                        ok = true
                                    end
                                end
                            end
                            if not ok then f.Visible = false end
                        end
                    else
                        for _, f in ipairs(t.bones) do f.Visible = false end
                    end

                    -- head dot / куда смотрит игрок
                    local headPart = char:FindFirstChild("Head")
                    t.head.Visible = false
                    t.look.Visible = false
                    if headPart then
                        local hp = cam:WorldToViewportPoint(headPart.Position)
                        if cfg.espHeadDot and hp.Z > 0 then
                            t.head.Visible = true
                            t.head.Position = UDim2.fromOffset(rnd(hp.X), rnd(hp.Y))
                            t.head.BackgroundColor3 = espColor
                        end
                        if cfg.espLook and hp.Z > 0 then
                            local p1 = cam:WorldToViewportPoint(headPart.Position + headPart.CFrame.LookVector * 6)
                            if p1.Z > 0 then
                                setLine(t.look, Vector2.new(hp.X, hp.Y), Vector2.new(p1.X, p1.Y), espColor, 2)
                            end
                        end
                    end
                end
            end
            if not drawn then hideTarget(t) end

            -- стрелка, если игрок за экраном
            local arrowOn = false
            if showEsp and cfg.espArrows and not onScr then
                local rel = cam.CFrame:PointToObjectSpace(hrp.Position)
                local v = Vector2.new(rel.X, rel.Z)
                if v.Magnitude > 0.001 then
                    v = v.Unit
                    local r = cfg.arrowRadius
                    t.arrow.Position = UDim2.fromOffset(rnd(vs.X / 2 + v.X * r), rnd(vs.Y / 2 + v.Y * r))
                    t.arrow.Rotation = math.deg(math.atan2(v.Y, v.X))
                    t.arrow.BackgroundColor3 = espColor
                    arrowOn = true
                end
            end
            t.arrow.Visible = arrowOn

            -- Chams
            if cfg.chamsEnabled and alive then
                t.hl.Adornee = char
                t.hl.Enabled = true
                t.hl.DepthMode = cfg.chamsThrough and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
                t.hl.FillColor = chamsColor
                t.hl.OutlineColor = chamsColor
                t.hl.FillTransparency = cfg.chamsFill / 100
                t.hl.OutlineTransparency = cfg.chamsOutline / 100
            else
                t.hl.Enabled = false
            end

            -- хитмаркер / цифры урона (враг в прицеле потерял здоровье)
            if hum then
                local prev = lastHp[hum]
                lastHp[hum] = hum.Health
                if prev and hum.Health < prev and hrp and (cfg.hitMarker or cfg.dmgNumbers) then
                    local sp = cam:WorldToViewportPoint(hrp.Position)
                    if sp.Z > 0 and (Vector2.new(sp.X, sp.Y) - vs / 2).Magnitude < 220 then
                        if cfg.hitMarker then flashHitMarker() end
                        if cfg.dmgNumbers then spawnDamageNumber(sp.X, sp.Y - 40, prev - hum.Health) end
                    end
                end
            end

            -- Hitbox (1 = голова, 2 = тело, 3 = оба)
            local hbOn = cfg.hbEnabled and alive
            hbApply(hrp, hbOn and cfg.hbPart ~= 1)
            hbApply(char and char:FindFirstChild("Head"), hbOn and cfg.hbPart ~= 2)
        end
    end
end

local function cleanupTargets()
    for plr in pairs(targets) do removeTarget(plr) end
    restoreHitboxes()
    pcall(function() EspGui:Destroy() end)
end

bind(Players.PlayerRemoving, removeTarget)

-- ============================================================
--  ВИЗУАЛ: освещение, цветокоррекция, bloom, HUD
-- ============================================================
local Stats = game:GetService("Stats")

local TintPresets = {
    {"None", Color3.fromRGB(255, 255, 255)},
    {"Warm", Color3.fromRGB(255, 232, 205)},
    {"Cool", Color3.fromRGB(205, 225, 255)},
    {"Mint", Color3.fromRGB(205, 255, 232)},
    {"Rose", Color3.fromRGB(255, 210, 225)},
}
local TintNames = {}
for i, c in ipairs(TintPresets) do TintNames[i] = c[1] end

-- ---------- освещение: fullbright / без тумана / цвет ambient ----------
local lightOrig, atmOrig
local lightActive = false

local function setProp(obj, prop, v)
    if obj[prop] ~= v then obj[prop] = v end
end

local function updateLighting()
    local want = cfg.fullbright or cfg.noFog or cfg.ambientEnabled or cfg.fogEnabled
    if not want and not lightActive then return end

    if not lightOrig then
        lightOrig = {
            Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
            GlobalShadows = Lighting.GlobalShadows, FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd,
            FogColor = Lighting.FogColor,
        }
    end
    local atm = Lighting:FindFirstChildOfClass("Atmosphere")
    if atm and not atmOrig then atmOrig = {Density = atm.Density, Haze = atm.Haze} end

    local o = lightOrig
    local brightness, ambient, outdoor, shadows = o.Brightness, o.Ambient, o.OutdoorAmbient, o.GlobalShadows
    local fogStart, fogEnd = o.FogStart, o.FogEnd
    local fogColor = o.FogColor

    if want then
        if cfg.fullbright then
            brightness = 2
            ambient = Color3.fromRGB(190, 190, 190)
            outdoor = ambient
            shadows = false
        elseif cfg.ambientEnabled then
            local c = (ColorPresets[cfg.ambientColor] or ColorPresets[1])[2]
            ambient, outdoor = c, c
        end
        if cfg.noFog then
            fogStart, fogEnd = 1e6, 1e6
        elseif cfg.fogEnabled then
            fogStart, fogEnd = cfg.fogDist * 0.15, cfg.fogDist
            fogColor = (ColorPresets[cfg.fogColor] or ColorPresets[1])[2]
        end
    end

    setProp(Lighting, "Brightness", brightness)
    setProp(Lighting, "Ambient", ambient)
    setProp(Lighting, "OutdoorAmbient", outdoor)
    setProp(Lighting, "GlobalShadows", shadows)
    setProp(Lighting, "FogStart", fogStart)
    setProp(Lighting, "FogEnd", fogEnd)
    setProp(Lighting, "FogColor", fogColor)
    if atm and atmOrig then
        local clear = want and cfg.noFog
        setProp(atm, "Density", clear and 0 or atmOrig.Density)
        setProp(atm, "Haze", clear and 0 or atmOrig.Haze)
    end

    if want then
        lightActive = true
    else
        lightActive = false
        lightOrig, atmOrig = nil, nil
    end
end

-- ---------- цветокоррекция и bloom ----------
local ccEffect = new("ColorCorrectionEffect", {Name = "ScorpionCC", Enabled = false, Parent = Lighting})
local bloomEffect = new("BloomEffect", {
    Name = "ScorpionBloom", Enabled = false, Intensity = 0.4, Size = 24, Threshold = 0.8, Parent = Lighting,
})

local sunEffect = new("SunRaysEffect", {
    Name = "ScorpionSun", Enabled = false, Intensity = 0.25, Spread = 0.8, Parent = Lighting,
})

local function updatePost()
    ccEffect.Enabled = cfg.ccEnabled
    if cfg.ccEnabled then
        ccEffect.Brightness = cfg.ccBrightness / 100
        ccEffect.Contrast = cfg.ccContrast / 100
        ccEffect.Saturation = cfg.ccSaturation / 100
        ccEffect.TintColor = (TintPresets[cfg.ccTint] or TintPresets[1])[2]
    end
    bloomEffect.Enabled = cfg.bloomEnabled
    if cfg.bloomEnabled then bloomEffect.Intensity = cfg.bloomIntensity / 100 end
    sunEffect.Enabled = cfg.sunRaysEnabled
    if cfg.sunRaysEnabled then sunEffect.Intensity = cfg.sunRaysIntensity / 100 end
end

-- ---------- HUD: fps / ping ----------
local HudGui = new("ScreenGui", {
    Name = "ScorpionHUD", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 997, Parent = GuiParent,
})
local HudFrame = new("Frame", {
    Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
    BackgroundColor3 = Theme.Back, BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false, Parent = HudGui,
})
new("UICorner", {CornerRadius = UDim.new(0, 3), Parent = HudFrame})
stroke(HudFrame, 0.8)
new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = HudFrame})
local HudLabel = new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
    RichText = true, Font = Theme.Font, TextSize = 13, TextColor3 = Theme.White, Text = "", Parent = HudFrame,
})

local hudAcc, hudFrames = 0, 0
local function getPing()
    local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok and v then return math.floor(v) end
    local ok2, p = pcall(function() return player:GetNetworkPing() * 1000 end)
    return ok2 and math.floor(p) or 0
end

local function updateHud(dt)
    HudFrame.Visible = cfg.hudEnabled
    if not cfg.hudEnabled then return end
    hudAcc += dt
    hudFrames += 1
    if hudAcc >= 0.5 then
        local parts = {'<font color="#FFFFFF">scorpion</font><font color="#8A8A8A">.wtf</font>'}
        if cfg.hudFps then parts[#parts + 1] = math.floor(hudFrames / hudAcc + 0.5) .. " fps" end
        if cfg.hudPing then parts[#parts + 1] = getPing() .. " ms" end
        HudLabel.Text = table.concat(parts, "  |  ")
        hudAcc, hudFrames = 0, 0
    end
end

-- ---------- убрать блюр / вспышки игры ----------
local blurStore = setmetatable({}, {__mode = "k"})
local blurTimer = 0

local function scanBlur(parent)
    for _, o in ipairs(parent:GetChildren()) do
        if (o:IsA("BlurEffect") or o:IsA("DepthOfFieldEffect")) and o.Name:sub(1, 8) ~= "Scorpion" then
            if blurStore[o] == nil then blurStore[o] = o.Enabled end
            if o.Enabled then o.Enabled = false end
        end
    end
end

local function updateNoBlur(dt)
    blurTimer -= dt
    if blurTimer > 0 then return end
    blurTimer = 0.2
    if cfg.noBlur then
        scanBlur(Lighting)
        local cam = workspace.CurrentCamera
        if cam then scanBlur(cam) end
    elseif next(blurStore) then
        for o, en in pairs(blurStore) do
            if o.Parent then o.Enabled = en end
            blurStore[o] = nil
        end
    end
end

-- ---------- радар ----------
local RadarFrame = new("Frame", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(150, 150),
    BackgroundColor3 = Theme.Back, BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false,
    ClipsDescendants = true, Parent = HudGui,
})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = RadarFrame})
stroke(RadarFrame, 0.75)
line(RadarFrame, UDim2.new(0.5, 0, 0, 0), UDim2.new(0, 1, 1, 0))
line(RadarFrame, UDim2.new(0, 0, 0.5, 0), UDim2.new(1, 0, 0, 1))
local radarSelf = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, 5),
    BackgroundColor3 = Theme.White, BorderSizePixel = 0, Parent = RadarFrame,
})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = radarSelf})

local radarDots = {}
bind(Players.PlayerRemoving, function(plr)
    local d = radarDots[plr]
    if d then
        d:Destroy()
        radarDots[plr] = nil
    end
end)

local function updateRadar()
    RadarFrame.Visible = cfg.radarEnabled
    if not cfg.radarEnabled then return end

    local size = cfg.radarSize
    RadarFrame.Size = UDim2.fromOffset(size, size)

    local cam = workspace.CurrentCamera
    local myHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local look = cam and cam.CFrame.LookVector
    local f = look and Vector3.new(look.X, 0, look.Z)
    if not (myHrp and f and f.Magnitude > 0.001) then
        for _, d in pairs(radarDots) do d.Visible = false end
        return
    end
    f = f.Unit
    local right = Vector3.new(-f.Z, 0, f.X)
    local radius = size / 2 - 4

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local d = radarDots[plr]
            if not d then
                d = new("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5), BorderSizePixel = 0,
                    Visible = false, Parent = RadarFrame,
                })
                new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = d})
                radarDots[plr] = d
            end

            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local dx = hrp.Position - myHrp.Position
                local v = Vector2.new(dx:Dot(right), -dx:Dot(f)) / cfg.radarRange * radius
                if v.Magnitude > radius then v = v.Unit * radius end
                d.Position = UDim2.new(0.5, rnd(v.X), 0.5, rnd(v.Y))
                d.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
                d.Visible = true
            else
                d.Visible = false
            end
        end
    end
end

-- ---------- уведомления ----------
local ToastHolder = new("Frame", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(230, 220),
    BackgroundTransparency = 1, Parent = HudGui,
})
new("UIListLayout", {
    VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder, Parent = ToastHolder,
})
local toastId = 0

local function Notify(text)
    if not cfg.notify or unloaded then return end
    toastId += 1
    local f = new("Frame", {
        Size = UDim2.fromOffset(210, 22), BackgroundColor3 = Theme.Back, BackgroundTransparency = 1,
        BorderSizePixel = 0, LayoutOrder = toastId, Parent = ToastHolder,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 3), Parent = f})
    local st = stroke(f, 1)
    local bar = new("Frame", {Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = f})
    local lbl = makeText(f, text, 13, Theme.White)
    lbl.Position = UDim2.fromOffset(10, 0)
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.TextTransparency = 1
    lbl.TextStrokeTransparency = 1

    local tin = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(f, tin, {BackgroundTransparency = 0.25}):Play()
    TweenService:Create(st, tin, {Transparency = 0.8}):Play()
    TweenService:Create(bar, tin, {BackgroundTransparency = 0}):Play()
    TweenService:Create(lbl, tin, {TextTransparency = 0}):Play()

    task.delay(1.8, function()
        if unloaded then return end
        local tout = TweenInfo.new(0.25)
        TweenService:Create(f, tout, {BackgroundTransparency = 1}):Play()
        TweenService:Create(st, tout, {Transparency = 1}):Play()
        TweenService:Create(bar, tout, {BackgroundTransparency = 1}):Play()
        TweenService:Create(lbl, tout, {TextTransparency = 1}):Play()
        task.wait(0.3)
        f:Destroy()
    end)
end

-- ---------- погода (снег / дождь / сакура / угли / пыль) ----------
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local WeatherKinds = {"Snow", "Rain", "Sakura", "Embers", "Dust"}
local WeatherColorNames = {"Auto"}
for _, c in ipairs(ColorPresets) do WeatherColorNames[#WeatherColorNames + 1] = c[1] end
local WeatherAuto = {
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 200, 255), Color3.fromRGB(255, 170, 200),
    Color3.fromRGB(255, 140, 60), Color3.fromRGB(235, 235, 235),
}

local weatherPart, weatherEmitter, weatherSig

local function ensureWeather()
    if weatherPart and weatherPart.Parent then return end
    weatherPart = new("Part", {
        Name = "ScorpionWeather", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
        CastShadow = false, Transparency = 1, Size = Vector3.new(90, 1, 90), Parent = workspace,
    })
    weatherEmitter = new("ParticleEmitter", {Parent = weatherPart})
    weatherSig = nil
end

local function weatherColor()
    if cfg.weatherRainbow then return rainbowColor() end
    if cfg.weatherColor <= 1 then return WeatherAuto[cfg.weatherKind] or WeatherAuto[1] end
    return (ColorPresets[cfg.weatherColor - 1] or ColorPresets[1])[2]
end

local function fadeSeq(mid)
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, mid),
        NumberSequenceKeypoint.new(0.88, mid), NumberSequenceKeypoint.new(1, 1),
    })
end

local function configWeather()
    local e, k = weatherEmitter, cfg.weatherKind
    local sp, sz, wind, dens = cfg.weatherSpeed / 100, cfg.weatherSize / 100, cfg.weatherWind, cfg.weatherDensity

    e.Texture = SPARK
    e.LockedToPart = false
    e.Shape = Enum.ParticleEmitterShape.Box
    e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
    e.Orientation = Enum.ParticleOrientation.FacingCamera
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-30, 30)
    e.SpreadAngle = Vector2.new(0, 0)
    e.Drag = 0
    e.LightInfluence = 0
    e.LightEmission = 0.2
    e.EmissionDirection = Enum.NormalId.Bottom
    weatherPart.Size = Vector3.new(90, 1, 90)

    if k == 1 then -- снег
        e.Rate = dens * 5
        e.Lifetime = NumberRange.new(40 / (6 * sp), 40 / (4 * sp))
        e.Speed = NumberRange.new(4 * sp, 6 * sp)
        e.Size = NumberSequence.new(0.35 * sz)
        e.Transparency = fadeSeq(0.15)
        e.Acceleration = Vector3.new(wind, 0, wind * 0.3)
    elseif k == 2 then -- дождь
        e.Rate = dens * 12
        e.Lifetime = NumberRange.new(60 / (100 * sp))
        e.Speed = NumberRange.new(90 * sp, 110 * sp)
        e.Size = NumberSequence.new(0.5 * sz)
        e.Orientation = Enum.ParticleOrientation.VelocityParallel
        e.RotSpeed = NumberRange.new(0)
        e.LightEmission = 0.1
        e.Transparency = NumberSequence.new(0.45)
        e.Acceleration = Vector3.new(wind * 3, 0, wind)
    elseif k == 3 then -- сакура
        e.Rate = dens * 1.6
        e.Lifetime = NumberRange.new(9, 12)
        e.Speed = NumberRange.new(2 * sp, 4 * sp)
        e.Size = NumberSequence.new(0.6 * sz)
        e.RotSpeed = NumberRange.new(-90, 90)
        e.Transparency = fadeSeq(0.1)
        e.Acceleration = Vector3.new(wind, -0.4, wind * 0.6)
        e.SpreadAngle = Vector2.new(25, 25)
    elseif k == 4 then -- угли (летят вверх)
        e.Rate = dens * 1.8
        e.EmissionDirection = Enum.NormalId.Top
        e.Lifetime = NumberRange.new(4, 6)
        e.Speed = NumberRange.new(4 * sp, 8 * sp)
        e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5 * sz), NumberSequenceKeypoint.new(1, 0)})
        e.LightEmission = 1
        e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
        e.Acceleration = Vector3.new(wind, 2, wind * 0.3)
        e.SpreadAngle = Vector2.new(20, 20)
    else -- пыль в воздухе
        weatherPart.Size = Vector3.new(60, 30, 60)
        e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        e.Rate = dens * 1.5
        e.EmissionDirection = Enum.NormalId.Top
        e.Lifetime = NumberRange.new(8, 11)
        e.Speed = NumberRange.new(0.2 * sp, 0.8 * sp)
        e.Size = NumberSequence.new(0.14 * sz)
        e.LightEmission = 0.4
        e.Transparency = fadeSeq(0.55)
        e.Acceleration = Vector3.new(wind * 0.2, 0, 0)
        e.SpreadAngle = Vector2.new(180, 180)
    end
end

local function updateWeather()
    if not cfg.weatherEnabled then
        if weatherPart then
            weatherPart:Destroy()
            weatherPart, weatherEmitter, weatherSig = nil, nil, nil
        end
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    ensureWeather()

    local sig = table.concat({
        cfg.weatherKind, cfg.weatherDensity, cfg.weatherSpeed, cfg.weatherSize, cfg.weatherWind,
    }, "|")
    if sig ~= weatherSig then
        weatherSig = sig
        configWeather()
    end
    weatherEmitter.Enabled = true
    weatherEmitter.Color = ColorSequence.new(weatherColor())

    local pos = cam.CFrame.Position
    local k = cfg.weatherKind
    if k == 4 then
        weatherPart.CFrame = CFrame.new(pos + Vector3.new(0, -10, 0))
    elseif k == 5 then
        weatherPart.CFrame = CFrame.new(pos)
    else
        weatherPart.CFrame = CFrame.new(pos + Vector3.new(0, 38, 0))
    end
end

-- ---------- кастомная атмосфера и цветовой сдвиг неба ----------
local atmStore, atmCreated, shiftStore

local function updateAtmosphere(dt)
    local atm = Lighting:FindFirstChildOfClass("Atmosphere")

    if cfg.atmEnabled then
        if not atm then
            atm = new("Atmosphere", {Name = "ScorpionAtmosphere", Parent = Lighting})
            atmCreated = atm
        end
        if not atmStore then
            atmStore = {
                Color = atm.Color, Decay = atm.Decay, Density = atm.Density,
                Haze = atm.Haze, Glare = atm.Glare, Offset = atm.Offset, Target = atm,
            }
        end
        setProp(atm, "Color", (ColorPresets[cfg.atmColor] or ColorPresets[1])[2])
        setProp(atm, "Decay", (ColorPresets[cfg.atmDecay] or ColorPresets[1])[2])
        setProp(atm, "Glare", cfg.atmGlare / 10)
        if not cfg.noFog then
            setProp(atm, "Density", cfg.atmDensity / 100)
            setProp(atm, "Haze", cfg.atmHaze / 10)
        end
    elseif atmStore then
        local st = atmStore
        if st.Target and st.Target.Parent and st.Target ~= atmCreated then
            st.Target.Color, st.Target.Decay, st.Target.Density = st.Color, st.Decay, st.Density
            st.Target.Haze, st.Target.Glare, st.Target.Offset = st.Haze, st.Glare, st.Offset
        end
        if atmCreated then
            atmCreated:Destroy()
            atmCreated = nil
        end
        atmStore = nil
    end

    -- цветовой сдвиг неба / света
    if cfg.shiftEnabled then
        if not shiftStore then
            shiftStore = {Top = Lighting.ColorShift_Top, Bottom = Lighting.ColorShift_Bottom}
        end
        if cfg.shiftCycle then
            local h = (os.clock() * 0.06) % 1
            Lighting.ColorShift_Top = Color3.fromHSV(h, 0.55, 1)
            Lighting.ColorShift_Bottom = Color3.fromHSV((h + 0.5) % 1, 0.55, 1)
        else
            Lighting.ColorShift_Top = (ColorPresets[cfg.shiftTop] or ColorPresets[1])[2]
            Lighting.ColorShift_Bottom = (ColorPresets[cfg.shiftBottom] or ColorPresets[1])[2]
        end
    elseif shiftStore then
        Lighting.ColorShift_Top = shiftStore.Top
        Lighting.ColorShift_Bottom = shiftStore.Bottom
        shiftStore = nil
    end
end

-- ---------- кино-полосы и глубина резкости ----------
local dofEffect = new("DepthOfFieldEffect", {
    Name = "ScorpionDoF", Enabled = false, FarIntensity = 0.6, NearIntensity = 0,
    FocusDistance = 60, InFocusRadius = 20, Parent = Lighting,
})

local function updateCinematic()
    dofEffect.Enabled = cfg.dofEnabled
    if cfg.dofEnabled then
        dofEffect.FocusDistance = cfg.dofFocus
        dofEffect.InFocusRadius = cfg.dofRadius
        dofEffect.FarIntensity = cfg.dofFar / 100
    end
end

-- ---------- аура вокруг своего персонажа ----------
local updateAura, cleanupAura
do
    local kp = NumberSequenceKeypoint.new
    local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
    local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
    local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"
    local ARC = NumberSequence.new({kp(0, 0), kp(0.4, 0), kp(0.41, 1), kp(1, 1)})

    local objs, em, halo, orbs = {}, {}, {}, {}
    local builtHrp, builtStyle, lastSig
    local phase = 0

    local function clear()
        for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
        objs, em, halo, orbs = {}, {}, {}, {}
        builtHrp, builtStyle, lastSig = nil, nil, nil
    end
    cleanupAura = clear

    local function emitter(parent, props)
        props.Parent = parent
        local e = new("ParticleEmitter", props)
        objs[#objs + 1] = e
        return e
    end

    local function mkSpark(hrp)
        return emitter(hrp, {
            Texture = TEX_SPARK, LockedToPart = false, Lifetime = NumberRange.new(1, 1.8),
            SpreadAngle = Vector2.new(180, 180), LightEmission = 0.9, LightInfluence = 0,
            Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-80, 80), Acceleration = Vector3.new(0, 1.5, 0),
        })
    end

    -- кольцо-нимб: SurfaceGui с вращающейся дугой с двух сторон
    local function mkHalo()
        local part = new("Part", {
            Name = "ScorpionHalo", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
            CastShadow = false, Transparency = 1, Size = Vector3.new(3, 0.05, 3), Parent = workspace,
        })
        local strokes = {}
        for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom}) do
            local gui = new("SurfaceGui", {
                Face = face, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(256, 256),
                LightInfluence = 0, Adornee = part, Parent = part,
            })
            local fr = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui,
            })
            new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fr})
            local st = new("UIStroke", {Thickness = 12, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = fr})
            new("UIGradient", {Transparency = ARC, Parent = st})
            strokes[#strokes + 1] = st
        end
        objs[#objs + 1] = part
        return {part = part, strokes = strokes}
    end

    -- стили: 1 Sparkles, 2 Flame, 3 Halo, 4 Orbit
    local function build(hrp, style)
        clear()
        builtHrp, builtStyle = hrp, style
        if style == 1 then
            em.haze = emitter(hrp, {
                Texture = TEX_SMOKE, LockedToPart = false, Lifetime = NumberRange.new(1.4, 2.2),
                SpreadAngle = Vector2.new(180, 180), LightEmission = 1, LightInfluence = 0,
                Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20),
            })
            em.spark = mkSpark(hrp)
        elseif style == 2 then
            em.flame = emitter(hrp, {
                Texture = TEX_FIRE, LockedToPart = false, EmissionDirection = Enum.NormalId.Top,
                Lifetime = NumberRange.new(0.7, 1.1), SpreadAngle = Vector2.new(18, 18), LightEmission = 1,
                LightInfluence = 0, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
                Acceleration = Vector3.new(0, 3, 0),
            })
            em.spark = mkSpark(hrp)
        elseif style == 3 then
            halo[1], halo[2] = mkHalo(), mkHalo()
            em.spark = mkSpark(hrp)
        else
            for i = 1, 6 do
                local part = new("Part", {
                    Name = "ScorpionOrb", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Anchored = true,
                    CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
                    Size = Vector3.new(0.5, 0.5, 0.5), CFrame = hrp.CFrame, Parent = workspace,
                })
                local a0 = new("Attachment", {Position = Vector3.new(0, 0.25, 0), Parent = part})
                local a1 = new("Attachment", {Position = Vector3.new(0, -0.25, 0), Parent = part})
                local tr = new("Trail", {
                    Attachment0 = a0, Attachment1 = a1, Lifetime = 0.55, LightEmission = 1, MinLength = 0,
                    FaceCamera = true, Transparency = NumberSequence.new({kp(0, 0.1), kp(1, 1)}),
                    WidthScale = NumberSequence.new({kp(0, 1), kp(1, 0)}), Parent = part,
                })
                objs[#objs + 1] = part
                orbs[i] = {part = part, trail = tr}
            end
        end
    end

    local function apply(c1, c2)
        local s, d, sp = cfg.auraSize / 100, cfg.auraDensity, cfg.auraSpeed / 100
        local cs = ColorSequence.new(c1, c2)
        if em.haze then
            local e = em.haze
            e.Rate = 4 + d * 0.35
            e.Speed = NumberRange.new(0.2 * sp, 0.7 * sp)
            e.Size = NumberSequence.new({kp(0, 2.2 * s), kp(1, 4.2 * s)})
            e.Transparency = NumberSequence.new({kp(0, 1), kp(0.25, 0.86), kp(1, 1)})
            e.Color = ColorSequence.new(c1)
        end
        if em.flame then
            local e = em.flame
            e.Rate = d * 1.3
            e.Speed = NumberRange.new(3 * sp, 5 * sp)
            e.Size = NumberSequence.new({kp(0, 1.9 * s), kp(0.5, 1.2 * s), kp(1, 0.2 * s)})
            e.Transparency = NumberSequence.new({kp(0, 0.25), kp(0.6, 0.5), kp(1, 1)})
            e.Color = cs
        end
        if em.spark then
            local e = em.spark
            e.Rate = (builtStyle == 1) and d or d * 0.5
            e.Speed = NumberRange.new(1 * sp, 4 * sp)
            e.Size = NumberSequence.new({kp(0, 0.55 * s), kp(1, 0)})
            e.Transparency = NumberSequence.new({kp(0, 0.1), kp(1, 1)})
            e.Color = cs
        end
        for _, o in ipairs(orbs) do
            o.part.Color = c1
            o.trail.Color = cs
        end
        for k, h in ipairs(halo) do
            for _, st in ipairs(h.strokes) do st.Color = (k == 1) and c1 or c2 end
        end
    end

    function updateAura(dt)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (cfg.auraEnabled and hrp and hum and hum.Health > 0) then
            if builtHrp then clear() end
            return
        end

        local style = cfg.auraStyle
        if builtHrp ~= hrp or builtStyle ~= style then
            build(hrp, style)
            lastSig = nil
        end
        phase += dt * cfg.auraSpeed / 100

        local c1, c2
        if cfg.auraRainbow then
            c1 = rainbowColor()
            c2 = Color3.fromHSV((os.clock() * 0.25 + 0.35) % 1, 0.85, 1)
        else
            c1 = (ColorPresets[cfg.auraColor] or ColorPresets[1])[2]
            c2 = (ColorPresets[cfg.auraColor2] or ColorPresets[1])[2]
        end
        local sig = table.concat({cfg.auraDensity, cfg.auraSize, cfg.auraSpeed, cfg.auraColor, cfg.auraColor2}, "|")
        if cfg.auraRainbow or sig ~= lastSig then
            lastSig = sig
            apply(c1, c2)
        end

        local s = cfg.auraSize / 100
        if style == 3 then
            local head = char:FindFirstChild("Head")
            local base = (head and head.Position or (hrp.Position + Vector3.new(0, 2.5, 0))) + Vector3.new(0, 1.7, 0)
            local h1, h2 = halo[1], halo[2]
            if h1 then
                local d1 = 3.4 * s
                h1.part.Size = Vector3.new(d1, 0.05, d1)
                h1.part.CFrame = CFrame.new(base) * CFrame.Angles(math.sin(phase * 1.3) * 0.08, phase * 2, 0)
            end
            if h2 then
                local d2 = 2.2 * s
                h2.part.Size = Vector3.new(d2, 0.05, d2)
                h2.part.CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, -phase * 3, 0)
            end
        elseif style == 4 then
            local r = 3.2 * s
            local n = #orbs
            for i, o in ipairs(orbs) do
                local ang = phase * 2.2 + (i - 1) * (math.pi * 2 / n)
                local y = math.sin(phase * 1.4 + i * 1.1) * 1.7
                o.part.CFrame = CFrame.new(hrp.Position + Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r))
            end
        end
    end
end

-- ---------- кольцо под игроком ----------
local updateRing, cleanupRing
do
    local ringRay = RaycastParams.new()
    ringRay.FilterType = Enum.RaycastFilterType.Exclude
    ringRay.IgnoreWater = true

    local ringPart, ringFrame, ringStroke, ringGrad, ring2Frame, ring2Stroke
    local phase = 0
    local R_ARC = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0),
        NumberSequenceKeypoint.new(0.46, 1), NumberSequenceKeypoint.new(1, 1),
    })

    local function destroyRing()
        if ringPart then ringPart:Destroy() end
        ringPart, ringFrame, ringStroke, ringGrad, ring2Frame, ring2Stroke = nil, nil, nil, nil, nil, nil
    end
    cleanupRing = destroyRing

    local function buildRing()
        destroyRing()
        ringPart = new("Part", {
            Name = "ScorpionRing", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
            CastShadow = false, Transparency = 1, Size = Vector3.new(7, 0.05, 7), Parent = workspace,
        })
        local gui = new("SurfaceGui", {
            Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
            CanvasSize = Vector2.new(256, 256), LightInfluence = 0, Adornee = ringPart, Parent = ringPart,
        })
        ringFrame = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui,
        })
        new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ringFrame})
        ringStroke = new("UIStroke", {Thickness = 14, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ringFrame})
        ringGrad = new("UIGradient", {Enabled = false, Transparency = R_ARC, Parent = ringStroke})

        ring2Frame = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
            BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = gui,
        })
        new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ring2Frame})
        ring2Stroke = new("UIStroke", {Thickness = 10, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ring2Frame})
    end

    -- стили: 1 Static, 2 Pulse, 3 Ripple, 4 Spinning arc, 5 Double ring, 6 Disc
    function updateRing(dt)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (cfg.ringEnabled and hrp and hum and hum.Health > 0) then
            if ringPart then destroyRing() end
            return
        end
        if not ringPart or not ringPart.Parent then buildRing() end

        phase += dt * cfg.ringSpeed / 100
        local style = cfg.ringStyle

        -- высота земли под игроком
        ringRay.FilterDescendantsInstances = {char}
        local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -60, 0), ringRay)
        local y
        if hit then
            y = hit.Position.Y + 0.06
        else
            local off = (hum.RigType == Enum.HumanoidRigType.R6) and 3 or (hum.HipHeight + hrp.Size.Y / 2)
            y = hrp.Position.Y - off + 0.06
        end

        local scale, alpha = 1, cfg.ringAlpha / 100
        if style == 2 then
            local k = (math.sin(phase * 3) + 1) / 2
            scale = 0.75 + 0.25 * k
            alpha = math.min(alpha + 0.4 * (1 - k), 1)
        elseif style == 3 then
            local k = (phase * 0.8) % 1
            scale = 0.25 + 0.9 * k
            alpha = alpha + (1 - alpha) * k
        end

        local d = 7 * cfg.ringSize / 100 * scale
        ringPart.Size = Vector3.new(d, 0.05, d)
        ringPart.CFrame = CFrame.new(hrp.Position.X, y, hrp.Position.Z)

        local color = cfg.ringRainbow and rainbowColor() or (ColorPresets[cfg.ringColor] or ColorPresets[1])[2]
        local thick = 14 * cfg.ringThick / 100

        ringStroke.Color = color
        ringStroke.Thickness = thick
        ringStroke.Transparency = alpha
        ringGrad.Enabled = style == 4
        if style == 4 then ringGrad.Rotation = (phase * 180) % 360 end

        ringFrame.BackgroundColor3 = color
        ringFrame.BackgroundTransparency = (style == 6) and math.min(alpha + 0.55, 0.95) or 1

        ring2Frame.Visible = style == 5
        if style == 5 then
            ring2Stroke.Color = color
            ring2Stroke.Thickness = thick * 0.7
            ring2Stroke.Transparency = alpha
        end
    end
end

local function cleanupVisuals()
    if lightActive and lightOrig then
        for prop, v in pairs(lightOrig) do pcall(function() Lighting[prop] = v end) end
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm and atmOrig then
            atm.Density = atmOrig.Density
            atm.Haze = atmOrig.Haze
        end
    end
    lightActive = false
    pcall(function() ccEffect:Destroy() end)
    pcall(function() bloomEffect:Destroy() end)
    pcall(function() sunEffect:Destroy() end)
    -- погода, атмосфера, кольцо, аура
    cleanupRing()
    if weatherPart then
        weatherPart:Destroy()
        weatherPart, weatherEmitter = nil, nil
    end
    cleanupAura()
    cfg.atmEnabled, cfg.shiftEnabled = false, false
    pcall(function() updateAtmosphere(0) end)
    pcall(function() dofEffect:Destroy() end)
    for o, en in pairs(blurStore) do
        if o.Parent then o.Enabled = en end
        blurStore[o] = nil
    end
    pcall(function() HudGui:Destroy() end)
end

-- ============================================================
--  ГЛАВНЫЙ ЦИКЛ: FOV / зум / stretch / время суток / прицел
-- ============================================================
local RENDER_NAME = "ScorpionEngineOptimized"

RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 10, function(dt)
    -- время суток
    if cfg.customTimeEnabled then
        if cfg.autoCycle then
            cfg.timeOfDay = (cfg.timeOfDay + dt * cfg.cycleSpeed / 60) % 24
            if timeSlider then timeSlider.Set(cfg.timeOfDay, true) end
        end
        Lighting.ClockTime = cfg.timeOfDay
    end

    updateCrosshair(dt)
    updateModels(dt)
    updateLighting()
    updatePost()
    updateHud(dt)
    updateNoBlur(dt)
    updateRadar()
    updateWeather(dt)
    updateAtmosphere(dt)
    updateCinematic()
    updateAura(dt)
    updateRing(dt)
end)

-- FOV: применяется в самом конце кадра (после игровых скриптов) и не читает значение игры,
-- поэтому игра больше не перебивает его и картинка не дёргается
local RENDER_FOV = "ScorpionFovLast"
local lastStretched -- CFrame, который мы уже растянули (защита от накопления растяжения)
local fovConn
local fovApplying = false

local function hookFovCamera(cam)
    if fovConn then
        fovConn:Disconnect()
        fovConn = nil
    end
    if not cam then return end
    -- если игра меняет FOV посреди кадра, сразу возвращаем наше значение
    fovConn = cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
        if fovApplying or unloaded then return end
        if math.abs(cam.FieldOfView - fovCur) > 0.01 then
            fovApplying = true
            cam.FieldOfView = fovCur
            fovApplying = false
        end
    end)
end

hookFovCamera(workspace.CurrentCamera)
bind(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    hookFovCamera(workspace.CurrentCamera)
end)

RunService:BindToRenderStep(RENDER_FOV, Enum.RenderPriority.Last.Value, function(dt)
    local cam = workspace.CurrentCamera
    if not cam then return end

    local target = zoomActive and cfg.zoomFov or cfg.fov
    if math.abs(target - fovCur) < 0.05 then
        fovCur = target
    else
        fovCur = fovCur + (target - fovCur) * math.clamp(dt * 14, 0, 1)
    end

    if cam.FieldOfView ~= fovCur then
        fovApplying = true
        cam.FieldOfView = fovCur
        fovApplying = false
    end

    -- stretch: тоже в самом конце кадра, после любых игровых камер.
    -- Если камеру в этом кадре никто не менял, второй раз не растягиваем (иначе растяжение копится и ломается).
    if cfg.stretch then
        local cf = cam.CFrame
        if cf ~= lastStretched then
            cam.CFrame = CFrame.fromMatrix(
                cf.Position,
                cf.RightVector * (cfg.stretchX / 100),
                cf.UpVector * (cfg.stretchY / 100),
                -cf.LookVector
            )
            lastStretched = cam.CFrame
        end
    else
        lastStretched = nil
    end
end)

-- ESP считаем ПОСЛЕ stretch (приоритет выше), по финальной камере кадра
local RENDER_ESP = "ScorpionEspLast"
RunService:BindToRenderStep(RENDER_ESP, Enum.RenderPriority.Last.Value + 1, function()
    if unloaded then return end
    updateTargets()
end)

-- ============================================================
--  МЕНЮ: каркас
-- ============================================================
local ScreenGui = new("ScreenGui", {
    Name = "ScorpionSkeet_UI", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Enabled = false, Parent = GuiParent,
})

local MainFrame = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(660, 480), BackgroundColor3 = Theme.Back, BackgroundTransparency = 0.2,
    BorderSizePixel = 0, ClipsDescendants = true, Parent = ScreenGui,
})
new("UICorner", {CornerRadius = UDim.new(0, 4), Parent = MainFrame})
stroke(MainFrame, 0.8)
local MainScale = new("UIScale", {Scale = cfg.uiScale / 100, Parent = MainFrame})

-- шапка (за неё таскаем окно)
local DragBar = new("Frame", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = MainFrame})
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.5, 0, 1, 0),
    RichText = true, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    Text = '<font color="#FFFFFF">scorpion</font><font color="#8A8A8A">.wtf</font>', Parent = DragBar,
})
local verLbl = makeText(DragBar, "visual private", 13, Theme.TextDim, Enum.TextXAlignment.Right)
verLbl.Position = UDim2.new(0.5, 0, 0, 0)
verLbl.Size = UDim2.new(0.5, -14, 1, 0)
local hdrLine = new("Frame", {
    Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Accent,
    BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = MainFrame,
})
table.insert(accentRenders, function() hdrLine.BackgroundColor3 = Accent end)

-- футер
local Footer = new("Frame", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 20),
    BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = MainFrame,
})
line(Footer, UDim2.new(), UDim2.new(1, 0, 0, 1))
local ftL = makeText(Footer, menuKey.Name:upper() .. " — hide / show", 12, Theme.TextDim)
ftL.Position = UDim2.fromOffset(12, 0); ftL.Size = UDim2.new(0.5, 0, 1, 0)
local ftR = makeText(Footer, "scorpion.wtf", 12, Theme.White, Enum.TextXAlignment.Right)
ftR.Position = UDim2.new(0.5, 0, 0, 0); ftR.Size = UDim2.new(0.5, -12, 1, 0)

-- сайдбар (внутри ТОЛЬКО кнопки вкладок, иначе UIListLayout сдвигает их вниз)
local Sidebar = new("Frame", {
    Position = UDim2.fromOffset(0, 29), Size = UDim2.new(0, 110, 1, -49),
    BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = MainFrame,
})
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = Sidebar})
new("UIPadding", {PaddingTop = UDim.new(0, 8), Parent = Sidebar})
-- вертикальный разделитель вынесен из сайдбара
line(MainFrame, UDim2.fromOffset(110, 29), UDim2.new(0, 1, 1, -49))

local Content = new("Frame", {
    Position = UDim2.fromOffset(122, 38), Size = UDim2.new(1, -134, 1, -66), BackgroundTransparency = 1, Parent = MainFrame,
})

-- ============================================================
--  МЕНЮ: вкладки и группы
-- ============================================================
local Tabs, activeTab = {}, nil

local function SelectTab(tab)
    if activeTab == tab then return end
    if activeTab then
        activeTab.Page.Visible = false
        activeTab.Button.BackgroundTransparency = 1
        activeTab.Label.TextColor3 = Theme.TextDim
        activeTab.Bar.Visible = false
    end
    activeTab = tab
    tab.Page.Visible = true
    tab.Button.BackgroundTransparency = 0.94
    tab.Label.TextColor3 = Accent
    tab.Bar.Visible = true
end

local function newColumn(page, xScale, xOffset)
    local col = new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.White, ScrollBarImageTransparency = 0.6,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        Position = UDim2.new(xScale, xOffset, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), Parent = page,
    })
    new("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = col})
    new("UIPadding", {
        PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 7), Parent = col,
    })
    return col
end

local function CreateTab(name)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Theme.White, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = #Tabs + 1, Parent = Sidebar,
    })
    local bar = new("Frame", {
        Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Theme.White, BorderSizePixel = 0, Visible = false, Parent = btn,
    })
    local lbl = makeText(btn, name, 14, Theme.TextDim)
    lbl.Position = UDim2.fromOffset(16, 0)
    lbl.Size = UDim2.new(1, -16, 1, 0)

    local page = new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = Content})
    local tab = {
        Button = btn, Label = lbl, Bar = bar, Page = page,
        Left = newColumn(page, 0, 0), Right = newColumn(page, 0.5, 6),
    }
    table.insert(Tabs, tab)
    table.insert(accentRenders, function()
        bar.BackgroundColor3 = Accent
        if activeTab == tab then lbl.TextColor3 = Accent end
    end)

    btn.MouseButton1Click:Connect(function() SelectTab(tab) end)
    btn.MouseEnter:Connect(function() if activeTab ~= tab then lbl.TextColor3 = Theme.Text end end)
    btn.MouseLeave:Connect(function() if activeTab ~= tab then lbl.TextColor3 = Theme.TextDim end end)
    if #Tabs == 1 then SelectTab(tab) end
    return tab
end

-- группа: заголовок внутри блока + тонкая линия
local function CreateGroup(column, title)
    local box = new("Frame", {
        BackgroundColor3 = Theme.White, BackgroundTransparency = 0.96, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = column,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 3), Parent = box})
    stroke(box, 0.88)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = box,
    })
    new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = box})

    local hdr = makeText(box, string.upper(title), 12, Accent)
    hdr.Size = UDim2.new(1, 0, 0, 14)
    hdr.LayoutOrder = -2
    table.insert(accentRenders, function() hdr.TextColor3 = Accent end)
    local div = line(box, UDim2.new(), UDim2.new(1, 0, 0, 1))
    div.LayoutOrder = -1
    return box
end

-- ============================================================
--  МЕНЮ: контролы
-- ============================================================
local function CreateToggle(parent, text, default, callback)
    local state = default and true or false
    local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Parent = parent})
    local box = new("Frame", {
        Position = UDim2.new(0, 0, 0.5, -5), Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 2), Parent = box})
    stroke(box, 0.7)
    local lbl = makeText(row, text, 14, Theme.TextDim)
    lbl.Position = UDim2.fromOffset(18, 0)
    lbl.Size = UDim2.new(1, -18, 1, 0)
    local hit = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = row})

    local function render()
        box.BackgroundColor3 = state and Accent or Theme.Black
        box.BackgroundTransparency = state and 0 or 0.4
        lbl.TextColor3 = state and Accent or Theme.TextDim
    end
    hit.MouseButton1Click:Connect(function()
        state = not state
        render()
        if callback then callback(state) end
    end)
    table.insert(accentRenders, render)
    render()
    return {Frame = row, Set = function(v) state = v; render() end}
end

local function CreateSlider(parent, o)
    local step = o.Step or 1
    local fmt = o.Format or function(v) return tostring(v) end
    local value = o.Default

    local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = parent})
    local lbl = makeText(row, o.Text, 14, Theme.TextDim)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    local valueLbl = makeText(row, "", 13, Theme.White, Enum.TextXAlignment.Right)
    valueLbl.Size = UDim2.new(1, 0, 0, 14)

    local bar = new("Frame", {
        Position = UDim2.fromOffset(0, 19), Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 2), Parent = bar})
    stroke(bar, 0.78)

    local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Accent, BorderSizePixel = 0, Parent = bar})
    new("UICorner", {CornerRadius = UDim.new(0, 2), Parent = fill})

    local marker
    if o.Track then
        bar.BackgroundColor3 = Theme.White
        bar.BackgroundTransparency = 0
        new("UIGradient", {Color = o.Track, Parent = bar})
        fill.Visible = false
        marker = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(3, 12),
            BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = 2, Parent = bar,
        })
        stroke(marker, 0.2, Theme.Black)
    end

    local function snap(v)
        v = math.clamp(v, o.Min, o.Max)
        v = math.floor((v - o.Min) / step + 0.5) * step + o.Min
        return math.clamp(v, o.Min, o.Max)
    end
    local function render()
        local a = (value - o.Min) / (o.Max - o.Min)
        fill.Size = UDim2.fromScale(a, 1)
        if marker then marker.Position = UDim2.new(a, 0, 0.5, 0) end
        valueLbl.Text = fmt(value)
    end
    local function set(v, silent)
        value = snap(v)
        render()
        if not silent and o.Callback then o.Callback(value) end
    end

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        set(o.Min + (o.Max - o.Min) * a)
    end

    -- кликабельная зона чуть выше самой полоски
    local hit = new("TextButton", {
        Position = UDim2.fromOffset(0, -6), Size = UDim2.new(1, 0, 1, 12),
        BackgroundTransparency = 1, Text = "", ZIndex = 4, Parent = bar,
    })
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(i.Position.X)
        end
    end)
    bind(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromX(i.Position.X)
        end
    end)
    bind(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    value = snap(value)
    render()
    table.insert(accentRenders, function() fill.BackgroundColor3 = Accent end)
    return {Frame = row, Set = set}
end

local function CreateDropdown(parent, o)
    local selected = math.clamp(o.Default or 1, 1, #o.Options)

    local row = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
    })
    new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row})

    local lbl = makeText(row, o.Text, 14, Theme.TextDim)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.LayoutOrder = 1

    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.4,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = 2, Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 2), Parent = head})
    stroke(head, 0.78)
    local current = makeText(head, "", 13, Theme.White)
    current.Position = UDim2.fromOffset(8, 0)
    current.Size = UDim2.new(1, -26, 1, 0)
    local arrow = makeText(head, "+", 14, Theme.TextDim, Enum.TextXAlignment.Center)
    arrow.Position = UDim2.new(1, -20, 0, 0)
    arrow.Size = UDim2.fromOffset(16, 20)

    local list = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Black,
        BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false, LayoutOrder = 3, Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 2), Parent = list})
    stroke(list, 0.78)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = list})

    local buttons = {}
    local function render()
        current.Text = o.Options[selected]
        for i, b in ipairs(buttons) do
            b.TextColor3 = (i == selected) and Accent or Theme.TextDim
        end
    end

    for i, name in ipairs(o.Options) do
        local b = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, AutoButtonColor = false, Text = name,
            Font = Theme.Font, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = list,
        })
        new("UIPadding", {PaddingLeft = UDim.new(0, 8), Parent = b})
        buttons[i] = b
        b.MouseButton1Click:Connect(function()
            selected = i
            list.Visible = false
            arrow.Text = "+"
            render()
            if o.Callback then o.Callback(i, name) end
        end)
    end

    head.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        arrow.Text = list.Visible and "-" or "+"
    end)
    table.insert(accentRenders, render)
    render()
    return {Frame = row}
end

local function CreateButton(parent, text, callback)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.94,
        BorderSizePixel = 0, AutoButtonColor = false, Text = text, TextColor3 = Theme.White,
        Font = Theme.Font, TextSize = 14, Parent = parent,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 2), Parent = btn})
    stroke(btn, 0.75)
    btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.85 end)
    btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 0.94 end)
    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return btn
end

local function CreateKeybind(parent, text, default, onSet)
    local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Parent = parent})
    local lbl = makeText(row, text, 14, Theme.TextDim)
    lbl.Size = UDim2.new(1, -70, 1, 0)

    local keyBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(66, 18),
        BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.4, BorderSizePixel = 0, AutoButtonColor = false,
        Text = default and ("[" .. default.Name .. "]") or "[None]",
        TextColor3 = Theme.White, Font = Theme.Font, TextSize = 12, Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 2), Parent = keyBtn})
    stroke(keyBtn, 0.78)

    local listening = false
    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        Binding = true
        keyBtn.Text = "[...]"
    end)

    bind(UserInputService.InputBegan, function(i)
        if not listening or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        listening = false
        task.delay(0.1, function() Binding = false end)
        if i.KeyCode == Enum.KeyCode.Escape then
            keyBtn.Text = "[None]"
            onSet(nil)
        else
            keyBtn.Text = "[" .. i.KeyCode.Name .. "]"
            onSet(i.KeyCode)
        end
    end)
    return row
end

-- обёртки: контрол <-> cfg
local function CfgToggle(parent, text, key, extra)
    return CreateToggle(parent, text, cfg[key], function(v)
        cfg[key] = v
        if extra then extra(v) end
        Notify(text .. (v and "  on" or "  off"))
        QueueSave()
    end)
end

local function CfgSlider(parent, o, key)
    o.Default = cfg[key]
    local cb = o.Callback
    o.Callback = function(v)
        cfg[key] = v
        if cb then cb(v) end
        QueueSave()
    end
    return CreateSlider(parent, o)
end

local function CfgDropdown(parent, o, key)
    o.Default = cfg[key]
    local cb = o.Callback
    o.Callback = function(i, name)
        cfg[key] = i
        if cb then cb(i, name) end
        QueueSave()
    end
    return CreateDropdown(parent, o)
end

local function fmtTime(v)
    local h = math.floor(v)
    local m = math.floor((v - h) * 60 + 0.5)
    if m == 60 then
        h += 1
        m = 0
    end
    return string.format("%02d:%02d", h, m)
end
local function fmtPct(v) return v .. "%" end
local function fmtDeg(v) return v .. "°" end

-- ---------- звуки выстрелов ----------
local ShotNames = {}
local cleanupShot, previewShot
do
    -- встроенные звуки клиента Roblox (лежат в самой игре, внешние ассеты не нужны)
    local ShotSounds = {
        {"Ping",     "rbxasset://sounds/electronicpingshort.wav"},
        {"Snap",     "rbxasset://sounds/snap.mp3"},
        {"Click",    "rbxasset://sounds/clickfast.wav"},
        {"Bass",     "rbxasset://sounds/bass.wav"},
        {"Button",   "rbxasset://sounds/button.wav"},
        {"Splat",    "rbxasset://sounds/splat.wav"},
        {"Kerplunk", "rbxasset://sounds/kerplunk.wav"},
        {"Slash",    "rbxasset://sounds/swordslash.wav"},
        {"Random",   ""},
    }
    for i, v in ipairs(ShotSounds) do ShotNames[i] = v[1] end

    local SoundSvc = game:GetService("SoundService")
    local DEFAULT_CHAR_SOUNDS = {
        Running = true, Jumping = true, Climbing = true, GettingUp = true, FreeFalling = true,
        Landing = true, Splash = true, Swimming = true, Died = true,
    }
    local warned = false

    local function heldTool()
        local c = player.Character
        return c and c:FindFirstChildOfClass("Tool")
    end

    -- оружие в руках: Tool или вьюмодель в камере (кастомные системы оружия)
    local function weaponInHand()
        if not cfg.shotNeedWeapon then return true end
        return heldTool() ~= nil or getViewmodel() ~= nil
    end

    local function leftDown()
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    end

    local function playShot()
        local idx = cfg.shotSound
        if idx >= #ShotSounds then idx = math.random(1, #ShotSounds - 1) end
        local snd = new("Sound", {
            Name = "ScorpionShot", SoundId = ShotSounds[idx][2], Volume = cfg.shotVolume / 50,
            PlaybackSpeed = cfg.shotPitch / 100 * (1 + (math.random() - 0.5) * 0.08), Parent = SoundSvc,
        })
        snd:Play()
        task.delay(0.5, function()
            if not warned and snd.Parent and snd.TimeLength == 0 then
                warned = true
                Notify("shot sound failed to load: " .. ShotSounds[idx][1])
            end
        end)
        task.delay(4, function() snd:Destroy() end)
    end
    previewShot = playShot

    -- окно выстрела: пока оно открыто, оригинальные звуки оружия глушатся
    local windowEnd = 0
    local cache, cacheT = {}, 0
    local saved = {} -- Sound -> исходная громкость

    local function refreshCache()
        cache = {}
        local function add(root, skipDefault)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("Sound") and d.Name ~= "ScorpionShot"
                    and not (skipDefault and DEFAULT_CHAR_SOUNDS[d.Name]) then
                    cache[#cache + 1] = d
                end
            end
        end
        add(heldTool())
        add(player.Character, true)
        add(workspace.CurrentCamera)
        add(SoundSvc)
    end

    local holdId = 0
    bind(UserInputService.InputBegan, function(i)
        if unloaded or i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if MainFrame.Visible or UserInputService:GetFocusedTextBox() then return end
        if not weaponInHand() then return end

        windowEnd = os.clock() + 0.5
        cacheT = 0

        if cfg.shotEnabled then
            playShot()
            if cfg.shotRepeat then
                holdId += 1
                local my = holdId
                task.spawn(function()
                    while true do
                        task.wait(cfg.shotRate / 1000)
                        if my ~= holdId or unloaded or not cfg.shotEnabled or not cfg.shotRepeat
                            or not leftDown() or not weaponInHand() then
                            break
                        end
                        playShot()
                    end
                end)
            end
        end
    end)

    bind(RunService.Heartbeat, function(dt)
        if unloaded then return end
        local now = os.clock()

        if cfg.shotMute and not MainFrame.Visible and leftDown() and weaponInHand() then
            windowEnd = math.max(windowEnd, now + 0.35)
        end

        if cfg.shotMute and now < windowEnd then
            cacheT -= dt
            if cacheT <= 0 then
                cacheT = 0.5
                refreshCache()
            end
            for _, snd in ipairs(cache) do
                if snd.Parent and not snd.Looped then
                    if saved[snd] == nil then saved[snd] = snd.Volume end
                    if snd.Volume ~= 0 then snd.Volume = 0 end
                    if snd.Playing and snd.TimePosition < 0.3 then snd:Stop() end
                end
            end
        elseif next(saved) then
            for snd, v in pairs(saved) do
                if snd.Parent then snd.Volume = v end
                saved[snd] = nil
            end
        end
    end)

    -- новые звуки (клоны выстрелов), появившиеся во время окна
    bind(game.DescendantAdded, function(d)
        if not cfg.shotMute or os.clock() >= windowEnd then return end
        if d:IsA("Sound") and d.Name ~= "ScorpionShot" then
            d.Volume = 0
            d:GetPropertyChangedSignal("Volume"):Connect(function()
                if d.Volume ~= 0 then d.Volume = 0 end
            end)
        end
    end)

    function cleanupShot()
        holdId += 1
        windowEnd = 0
        for snd, v in pairs(saved) do
            if snd.Parent then snd.Volume = v end
            saved[snd] = nil
        end
    end
end

-- ============================================================
--  МЕНЮ: наполнение вкладок
-- ============================================================
local TabSet = {}
TabSet.Visuals = CreateTab("Visuals")
TabSet.Models = CreateTab("Models")
TabSet.ESP = CreateTab("ESP")
TabSet.Hitbox = CreateTab("Hitbox")
TabSet.World = CreateTab("World")
TabSet.Weather = CreateTab("Weather")
TabSet.Camera = CreateTab("Camera")
TabSet.FX = CreateTab("Effects")
TabSet.Sounds = CreateTab("Sounds")
TabSet.Settings = CreateTab("Settings")

-- Visuals
do
    local g = CreateGroup(TabSet.Visuals.Left, "Crosshair")
    CfgToggle(g, "Enable crosshair", "crosshairEnabled")
    CfgDropdown(g, {Text = "Style", Options = {"Cross", "Dot", "Spinning cross", "T-shape", "Circle", "Cross + dot", "X-cross", "Circle + dot", "Dynamic cross"}}, "crosshairStyle")
    CfgDropdown(g, {Text = "Color", Options = ColorNames}, "cColor")
    CfgToggle(g, "Rainbow color", "cRainbow")
    CfgToggle(g, "Outline", "cOutline")
    CfgSlider(g, {Text = "Transparency", Min = 0, Max = 90, Format = fmtPct}, "cAlpha")
    CfgSlider(g, {Text = "Length / size", Min = 2, Max = 30}, "cLength")
    CfgSlider(g, {Text = "Thickness", Min = 1, Max = 8}, "cThickness")
    CfgSlider(g, {Text = "Gap", Min = 0, Max = 20}, "cGap")
    CfgSlider(g, {Text = "Spin speed", Min = 0, Max = 400}, "cSpeed")

    local hud = CreateGroup(TabSet.Visuals.Right, "HUD")
    CfgToggle(hud, "Info bar", "hudEnabled")
    CfgToggle(hud, "Show FPS", "hudFps")
    CfgToggle(hud, "Show ping", "hudPing")

    local rd = CreateGroup(TabSet.Visuals.Right, "Radar")
    CfgToggle(rd, "Enable radar", "radarEnabled")
    CfgSlider(rd, {Text = "Size", Min = 100, Max = 260, Step = 10}, "radarSize")
    CfgSlider(rd, {Text = "Range (studs)", Min = 50, Max = 600, Step = 10}, "radarRange")

    local hf = CreateGroup(TabSet.Visuals.Right, "Hit feedback")
    CfgToggle(hf, "Hit marker", "hitMarker")
    CfgToggle(hf, "Damage numbers", "dmgNumbers")
end

-- ESP (ESP слева, Chams справа)
do
    local e = CreateGroup(TabSet.ESP.Left, "ESP")
    CfgToggle(e, "Enable ESP", "espEnabled")
    CfgToggle(e, "Box", "espBox")
    CfgDropdown(e, {Text = "Box style", Options = {"Full", "Corners"}}, "espBoxStyle")
    CfgToggle(e, "Box fill", "boxFill")
    CfgSlider(e, {Text = "Fill transparency", Min = 50, Max = 98, Format = fmtPct}, "boxFillAlpha")
    CfgToggle(e, "Name", "espName")
    CfgToggle(e, "Health bar", "espHealth")
    CfgToggle(e, "Distance", "espDistance")
    CfgToggle(e, "Weapon", "espWeapon")
    CfgDropdown(e, {Text = "Color", Options = ColorNames}, "espColor")
    CfgToggle(e, "Rainbow color", "espRainbow")
    CfgSlider(e, {Text = "Max distance", Min = 100, Max = 5000, Step = 50}, "espMaxDist")

    local c = CreateGroup(TabSet.ESP.Right, "Chams")
    CfgToggle(c, "Enable chams", "chamsEnabled")
    CfgToggle(c, "Through walls", "chamsThrough")
    CfgDropdown(c, {Text = "Color", Options = ColorNames}, "chamsColor")
    CfgToggle(c, "Rainbow color", "chamsRainbow")
    CfgSlider(c, {Text = "Fill transparency", Min = 0, Max = 100, Format = fmtPct}, "chamsFill")
    CfgSlider(c, {Text = "Outline transparency", Min = 0, Max = 100, Format = fmtPct}, "chamsOutline")

    local x = CreateGroup(TabSet.ESP.Right, "ESP extras")
    CfgToggle(x, "Snaplines", "espSnaplines")
    CfgDropdown(x, {Text = "Snapline origin", Options = {"Bottom", "Center", "Top"}}, "espSnapOrigin")
    CfgToggle(x, "Head dot", "espHeadDot")
    CfgToggle(x, "Skeleton", "espSkeleton")
    CfgToggle(x, "View direction", "espLook")
    CfgToggle(x, "Health number", "espHpText")
    CfgToggle(x, "Visible check (green / red)", "visCheck")
    CfgToggle(x, "Offscreen arrows", "espArrows")
    CfgSlider(x, {Text = "Arrow radius", Min = 80, Max = 400, Step = 5}, "arrowRadius")
end

-- Hitbox
do
    local h = CreateGroup(TabSet.Hitbox.Left, "Hitbox expander")
    CfgToggle(h, "Enable hitbox", "hbEnabled", function(v)
        if not v then restoreHitboxes() end
    end)
    CfgDropdown(h, {Text = "Hitbox part", Options = {"Head", "Body", "Head + Body"}}, "hbPart")
    CfgSlider(h, {Text = "Hitbox size", Min = 2, Max = 30}, "hbSize")
    CfgSlider(h, {Text = "Hitbox transparency", Min = 0, Max = 100, Format = fmtPct}, "hbTransparency")
end

-- World
do
    local g = CreateGroup(TabSet.World.Left, "Time of day")
    CfgToggle(g, "Custom time", "customTimeEnabled", function(v)
        if not v then Lighting.ClockTime = originalClock end
    end)
    timeSlider = CfgSlider(g, {
        Text = "Clock (0 - 24)", Min = 0, Max = 24, Step = 0.25, Format = fmtTime, Track = DayTrack,
    }, "timeOfDay")
    CfgToggle(g, "Auto day / night cycle", "autoCycle")
    CfgSlider(g, {Text = "Cycle speed (hours / min)", Min = 1, Max = 60}, "cycleSpeed")

    local cc = CreateGroup(TabSet.World.Left, "Color grading")
    CfgToggle(cc, "Enable color grading", "ccEnabled")
    CfgSlider(cc, {Text = "Brightness", Min = -50, Max = 50}, "ccBrightness")
    CfgSlider(cc, {Text = "Contrast", Min = -50, Max = 50}, "ccContrast")
    CfgSlider(cc, {Text = "Saturation", Min = -100, Max = 100}, "ccSaturation")
    CfgDropdown(cc, {Text = "Tint", Options = TintNames}, "ccTint")

    local a = CreateGroup(TabSet.World.Right, "Atmosphere")
    CfgToggle(a, "Screen vignette", "vignetteEnabled", setVignette)
    CfgSlider(a, {
        Text = "Vignette strength", Min = 10, Max = 100, Format = fmtPct,
        Callback = function() if cfg.vignetteEnabled then setVignette(true) end end,
    }, "vigStrength")
    CfgToggle(a, "Fullbright", "fullbright")
    CfgToggle(a, "Remove fog", "noFog")
    CfgToggle(a, "Ambient color override", "ambientEnabled")
    CfgDropdown(a, {Text = "Ambient color", Options = ColorNames}, "ambientColor")
    CfgToggle(a, "Remove blur / flash", "noBlur")
    CfgToggle(a, "Custom fog", "fogEnabled")
    CfgDropdown(a, {Text = "Fog color", Options = ColorNames}, "fogColor")
    CfgSlider(a, {Text = "Fog distance", Min = 100, Max = 3000, Step = 50}, "fogDist")

    local b = CreateGroup(TabSet.World.Right, "Bloom")
    CfgToggle(b, "Enable bloom", "bloomEnabled")
    CfgSlider(b, {Text = "Intensity", Min = 0, Max = 100, Format = fmtPct}, "bloomIntensity")
    CfgToggle(b, "Sun rays", "sunRaysEnabled")
    CfgSlider(b, {Text = "Sun rays intensity", Min = 0, Max = 100, Format = fmtPct}, "sunRaysIntensity")
end

-- Weather
do
    local w = CreateGroup(TabSet.Weather.Left, "Weather")
    CfgToggle(w, "Enable weather", "weatherEnabled")
    CfgDropdown(w, {Text = "Type", Options = WeatherKinds}, "weatherKind")
    CfgDropdown(w, {Text = "Color", Options = WeatherColorNames}, "weatherColor")
    CfgToggle(w, "Rainbow color", "weatherRainbow")
    CfgSlider(w, {Text = "Density", Min = 1, Max = 100}, "weatherDensity")
    CfgSlider(w, {Text = "Speed", Min = 30, Max = 300, Format = fmtPct}, "weatherSpeed")
    CfgSlider(w, {Text = "Particle size", Min = 30, Max = 300, Format = fmtPct}, "weatherSize")
    CfgSlider(w, {Text = "Wind", Min = -30, Max = 30}, "weatherWind")

    local a = CreateGroup(TabSet.Weather.Right, "Sky atmosphere")
    CfgToggle(a, "Custom atmosphere", "atmEnabled")
    CfgDropdown(a, {Text = "Air color", Options = ColorNames}, "atmColor")
    CfgDropdown(a, {Text = "Horizon color", Options = ColorNames}, "atmDecay")
    CfgSlider(a, {Text = "Density", Min = 0, Max = 100, Format = fmtPct}, "atmDensity")
    CfgSlider(a, {Text = "Haze", Min = 0, Max = 100, Format = fmtPct}, "atmHaze")
    CfgSlider(a, {Text = "Sun glare", Min = 0, Max = 100, Format = fmtPct}, "atmGlare")

    local sc = CreateGroup(TabSet.Weather.Right, "Sky color shift")
    CfgToggle(sc, "Enable color shift", "shiftEnabled")
    CfgToggle(sc, "Color cycle (rainbow)", "shiftCycle")
    CfgDropdown(sc, {Text = "Top color", Options = ColorNames}, "shiftTop")
    CfgDropdown(sc, {Text = "Bottom color", Options = ColorNames}, "shiftBottom")

    local ci = CreateGroup(TabSet.Weather.Left, "Depth of field")
    CfgToggle(ci, "Depth of field", "dofEnabled")
    CfgSlider(ci, {Text = "Focus distance", Min = 5, Max = 300, Step = 5}, "dofFocus")
    CfgSlider(ci, {Text = "In-focus radius", Min = 5, Max = 120, Step = 5}, "dofRadius")
    CfgSlider(ci, {Text = "Blur strength", Min = 0, Max = 100, Format = fmtPct}, "dofFar")
end

-- Camera
do
    local g = CreateGroup(TabSet.Camera.Left, "Field of view")
    CfgSlider(g, {Text = "Field of view", Min = 50, Max = 120, Format = fmtDeg}, "fov")
    CfgSlider(g, {Text = "Zoom FOV", Min = 20, Max = 60, Format = fmtDeg}, "zoomFov")
    CreateKeybind(g, "Zoom key", zoomKey, function(k)
        zoomKey = k
        zoomActive = false
        cfg.zoomKey = k and k.Name or ""
        QueueSave()
    end)

    local s = CreateGroup(TabSet.Camera.Right, "Resolution stretch")
    CfgToggle(s, "Enable stretch", "stretch")
    CfgSlider(s, {Text = "Stretch X", Min = 50, Max = 120, Format = fmtPct}, "stretchX")
    CfgSlider(s, {Text = "Stretch Y", Min = 50, Max = 120, Format = fmtPct}, "stretchY")
end

-- Models
do
    local h = CreateGroup(TabSet.Models.Left, "Highlight")
    CfgToggle(h, "Enable highlight", "hlEnabled")
    CfgToggle(h, "Character", "hlChar")
    CfgToggle(h, "Weapon / viewmodel", "hlWeapon")
    CfgDropdown(h, {Text = "Color", Options = ColorNames}, "hlColor")
    CfgSlider(h, {Text = "Fill transparency", Min = 0, Max = 100, Format = fmtPct}, "hlFill")
    CfgSlider(h, {Text = "Outline transparency", Min = 0, Max = 100, Format = fmtPct}, "hlOutline")
    CfgToggle(h, "Rainbow", "hlRainbow")
    CfgToggle(h, "Pulse", "hlPulse")
    CfgSlider(h, {Text = "Pulse speed", Min = 1, Max = 10}, "hlPulseSpeed")

    local s = CreateGroup(TabSet.Models.Right, "Arms skin")
    CfgToggle(s, "Enable arms skin", "skinEnabled")
    CfgDropdown(s, {Text = "Style", Options = SkinNames}, "skinStyle")
    CfgDropdown(s, {Text = "Color", Options = ColorNames}, "skinColor")
    CfgSlider(s, {Text = "Transparency", Min = 0, Max = 95, Format = fmtPct}, "skinTransparency")
    CfgSlider(s, {Text = "Reflectance", Min = 0, Max = 100, Format = fmtPct}, "skinReflect")
end

-- Sounds
do
    local g = CreateGroup(TabSet.Sounds.Left, "Shot sounds")
    CfgToggle(g, "Enable shot sounds", "shotEnabled")
    CfgDropdown(g, {Text = "Sound", Options = ShotNames, Callback = function() previewShot() end}, "shotSound")
    CfgSlider(g, {Text = "Volume", Min = 0, Max = 100, Format = fmtPct}, "shotVolume")
    CfgSlider(g, {Text = "Pitch", Min = 50, Max = 200, Format = fmtPct}, "shotPitch")
    CfgToggle(g, "Only with weapon in hand", "shotNeedWeapon")
    CfgToggle(g, "Repeat while held", "shotRepeat")
    CfgSlider(g, {Text = "Repeat delay (ms)", Min = 40, Max = 600, Step = 10}, "shotRate")
    CreateButton(g, "Preview sound", function() previewShot() end)

    local m = CreateGroup(TabSet.Sounds.Right, "Original sounds")
    CfgToggle(m, "Mute original shot sounds", "shotMute")
end

-- Effects
do
    local function refreshTrail() setTrail(cfg.trailEnabled) end
    local tr = CreateGroup(TabSet.FX.Left, "Trail")
    CfgToggle(tr, "Movement trail", "trailEnabled", setTrail)
    CfgDropdown(tr, {Text = "Style", Options = TRAIL_STYLES, Callback = refreshTrail}, "trailStyle")
    CfgDropdown(tr, {Text = "Color mode", Options = {"Solid", "Gradient", "Rainbow"}, Callback = refreshTrail}, "trailMode")
    CfgDropdown(tr, {Text = "Color", Options = ColorNames, Callback = refreshTrail}, "trailColor")
    CfgDropdown(tr, {Text = "Second color (gradient)", Options = ColorNames, Callback = refreshTrail}, "trailColor2")
    CfgSlider(tr, {Text = "Width", Min = 20, Max = 300, Format = fmtPct, Callback = refreshTrail}, "trailWidth")
    CfgSlider(tr, {Text = "Length", Min = 20, Max = 300, Format = fmtPct, Callback = refreshTrail}, "trailLife")
    CfgSlider(tr, {Text = "Transparency", Min = 0, Max = 90, Format = fmtPct, Callback = refreshTrail}, "trailAlpha")

    local rg = CreateGroup(TabSet.FX.Left, "Ring under player")
    CfgToggle(rg, "Enable ring", "ringEnabled")
    CfgDropdown(rg, {Text = "Style", Options = {"Static", "Pulse", "Ripple", "Spinning arc", "Double ring", "Disc"}}, "ringStyle")
    CfgDropdown(rg, {Text = "Color", Options = ColorNames}, "ringColor")
    CfgToggle(rg, "Rainbow color", "ringRainbow")
    CfgSlider(rg, {Text = "Size", Min = 40, Max = 300, Format = fmtPct}, "ringSize")
    CfgSlider(rg, {Text = "Thickness", Min = 20, Max = 300, Format = fmtPct}, "ringThick")
    CfgSlider(rg, {Text = "Transparency", Min = 0, Max = 90, Format = fmtPct}, "ringAlpha")
    CfgSlider(rg, {Text = "Animation speed", Min = 20, Max = 300, Format = fmtPct}, "ringSpeed")

    local jr = CreateGroup(TabSet.FX.Right, "Jump ring")
    CfgToggle(jr, "Jump land ring", "jumpRingEnabled")
    CfgDropdown(jr, {Text = "Style", Options = {"Ring", "Disc", "Double ring", "Shockwave"}}, "jumpStyle")
    CfgDropdown(jr, {Text = "Color", Options = ColorNames}, "jumpColor")
    CfgToggle(jr, "Rainbow color", "jumpRainbow")
    CfgSlider(jr, {Text = "Size", Min = 40, Max = 300, Format = fmtPct}, "jumpSize")
    CfgSlider(jr, {Text = "Duration", Min = 30, Max = 300, Format = fmtPct}, "jumpDuration")
    CfgSlider(jr, {Text = "Thickness", Min = 20, Max = 300, Format = fmtPct}, "jumpThick")
    CfgSlider(jr, {Text = "Transparency", Min = 0, Max = 90, Format = fmtPct}, "jumpAlpha")

    local au = CreateGroup(TabSet.FX.Right, "Character aura")
    CfgToggle(au, "Enable aura", "auraEnabled")
    CfgDropdown(au, {Text = "Style", Options = {"Sparkles", "Flame", "Halo", "Orbit"}}, "auraStyle")
    CfgDropdown(au, {Text = "Color", Options = ColorNames}, "auraColor")
    CfgDropdown(au, {Text = "Second color", Options = ColorNames}, "auraColor2")
    CfgToggle(au, "Rainbow color", "auraRainbow")
    CfgSlider(au, {Text = "Density", Min = 5, Max = 100}, "auraDensity")
    CfgSlider(au, {Text = "Size", Min = 30, Max = 300, Format = fmtPct}, "auraSize")
    CfgSlider(au, {Text = "Speed", Min = 30, Max = 300, Format = fmtPct}, "auraSpeed")
end

-- ============================================================
--  ВЫГРУЗКА
-- ============================================================
local function Unload()
    if unloaded then return end
    unloaded = true
    SaveNow()

    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    if fovConn then
        fovConn:Disconnect()
        fovConn = nil
    end
    pcall(function() RunService:UnbindFromRenderStep(RENDER_NAME) end)
    pcall(function() RunService:UnbindFromRenderStep(RENDER_FOV) end)
    pcall(function() RunService:UnbindFromRenderStep(RENDER_ESP) end)

    setTrail(false)
    setVignette(false)
    cleanupModels()
    cleanupTargets()
    cleanupVisuals()
    cleanupShot()
    Lighting.ClockTime = originalClock
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = originalFov end

    for _, g in ipairs({CrosshairGui, ScreenGui}) do pcall(function() g:Destroy() end) end
    env.ScorpionUnload = nil
end
env.ScorpionUnload = Unload

-- Settings
do
    local g = CreateGroup(TabSet.Settings.Left, "Menu")
    CfgSlider(g, {
        Text = "UI scale", Min = 70, Max = 130, Format = fmtPct,
        Callback = function(v) MainScale.Scale = v / 100 end,
    }, "uiScale")
    CfgDropdown(g, {Text = "Menu accent", Options = AccentNames, Callback = function(i) ApplyAccent(i) end}, "menuAccent")
    CfgToggle(g, "Notifications", "notify")
    CreateKeybind(g, "Menu key", menuKey, function(k)
        menuKey = k or Enum.KeyCode.Insert
        cfg.menuKey = menuKey.Name
        ftL.Text = menuKey.Name:upper() .. " — hide / show"
        QueueSave()
    end)
    CreateButton(g, "Save config", SaveNow)
    CreateButton(g, "Unload script", Unload)
end

-- ============================================================
--  ПЕРЕТАСКИВАНИЕ И БИНДЫ
-- ============================================================
local menuOpen = true
local function toggleMenu()
    menuOpen = not menuOpen
    local base = cfg.uiScale / 100
    if menuOpen then
        MainFrame.Visible = true
        MainScale.Scale = base * 0.94
        TweenService:Create(MainScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Scale = base,
        }):Play()
    else
        local tw = TweenService:Create(MainScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Scale = base * 0.94,
        })
        tw.Completed:Once(function()
            if not menuOpen then MainFrame.Visible = false end
        end)
        tw:Play()
    end
end

local dragging, dragStart, startPos = false, nil, nil

DragBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        startPos = MainFrame.Position
    end
end)
bind(UserInputService.InputChanged, function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
bind(UserInputService.InputEnded, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

bind(UserInputService.InputBegan, function(i, gp)
    if gp or Binding then return end
    if i.KeyCode == menuKey then
        toggleMenu()
    elseif zoomKey and i.KeyCode == zoomKey then
        zoomActive = not zoomActive
    end
end)

-- ============================================================
--  ИНТРО
-- ============================================================
task.spawn(function()
    local intro = new("ScreenGui", {
        Name = "ScorpionIntro", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1000, Parent = GuiParent,
    })
    local bg = new("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = intro,
    })
    local lbl = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(500, 80),
        BackgroundTransparency = 1, RichText = true, Font = Enum.Font.GothamBlack, TextSize = 46, TextTransparency = 1,
        Text = '<font color="#FFFFFF">SCORPION</font><font color="#8A8A8A">.WTF</font>', Parent = intro,
    })
    local tin = TweenInfo.new(0.3)
    TweenService:Create(bg, tin, {BackgroundTransparency = 0.35}):Play()
    TweenService:Create(lbl, tin, {TextTransparency = 0}):Play()
    task.wait(1)
    TweenService:Create(bg, tin, {BackgroundTransparency = 1}):Play()
    TweenService:Create(lbl, tin, {TextTransparency = 1}):Play()
    task.wait(0.35)
    intro:Destroy()
    if not unloaded and ScreenGui.Parent then ScreenGui.Enabled = true end
end)
