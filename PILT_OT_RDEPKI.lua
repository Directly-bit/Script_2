--[[
    ☢️ ПУЛЬТ ОТ ЯДЕРКИ — v3
    Новое:
      - кнопка по центру экрана
      - перетаскивание мышью/пальцем
      - клик отличается от перетаскивания (drag threshold)
]]

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LP  = Players.LocalPlayer
local PG  = LP:WaitForChild("PlayerGui")
local Cam = workspace.CurrentCamera

-- ─── ПАРАМЕТРЫ ───
local COUNTDOWN_START = 10
local RAINBOW_SPEED   = 2
local BOMB_COLOR      = Color3.fromRGB(255, 255, 0)
local BOMB_SYMBOL     = "☢"
local BOMB_SIZE       = 10
local BOMB_SPEED      = 300
local PUSH_FORCE      = 5000
local DEATH_DELAY     = 10
local DRAG_THRESHOLD  = 10   -- пикселей: меньше = клик, больше = перетаскивание

local isActive = false
local function log(msg) print("[NUKE] " .. tostring(msg)) end

-- ─── РАДУГА ───
local function getRainbowColor(t)
    return Color3.new(
        math.sin(t * RAINBOW_SPEED) * 0.5 + 0.5,
        math.sin(t * RAINBOW_SPEED + 2) * 0.5 + 0.5,
        math.sin(t * RAINBOW_SPEED + 4) * 0.5 + 0.5
    )
end

-- ─── УДАЛЕНИЕ СТАРОГО GUI ───
local old = PG:FindFirstChild("NukePanel")
if old then old:Destroy() end

-- ─── GUI ───
local gui = Instance.new("ScreenGui")
gui.Name = "NukePanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PG

-- ═══════════════════════════════════════
-- КНОПКА ПО ЦЕНТРУ
-- ═══════════════════════════════════════
local btn = Instance.new("TextButton")
btn.Name = "NukeButton"
btn.AnchorPoint = Vector2.new(0.5, 0.5)              -- 🎯 якорь в центр
btn.Position    = UDim2.new(0.5, 0, 0.5, 0)          -- 🎯 ровно центр
btn.Size        = UDim2.new(0, 90, 0, 90)
btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
btn.Text        = "☢"
btn.TextSize    = 46
btn.Font        = Enum.Font.GothamBlack
btn.TextColor3  = Color3.fromRGB(255, 60, 60)
btn.BorderSizePixel = 0
btn.AutoButtonColor = false
btn.Active      = true                                 -- 🎯 важно для drag
btn.Parent      = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = btn

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 60, 60)
stroke.Thickness = 3
stroke.Parent = btn

-- Пульсация обводки
task.spawn(function()
    while btn.Parent do
        local tw = TweenService:Create(
            stroke,
            TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Thickness = 6, Color = Color3.fromRGB(255, 200, 0) }
        )
        tw:Play()
        tw.Completed:Wait()
    end
end)

-- ═══════════════════════════════════════
-- ОТСЧЁТ
-- ═══════════════════════════════════════
local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 400, 0, 200)
label.Position = UDim2.new(0.5, -200, 0.5, -100)
label.BackgroundTransparency = 1
label.TextSize = 150
label.Font = Enum.Font.GothamBlack
label.TextStrokeTransparency = 0
label.TextStrokeColor3 = Color3.new(0, 0, 0)
label.Visible = false
label.ZIndex = 10
label.Parent = gui

-- ═══════════════════════════════════════
-- БОМБА
-- ═══════════════════════════════════════
local function createBomb()
    local bomb = Instance.new("Part")
    bomb.Name = "NukeBomb"
    bomb.Shape = Enum.PartType.Ball
    bomb.Size = Vector3.new(BOMB_SIZE, BOMB_SIZE, BOMB_SIZE)
    bomb.Color = BOMB_COLOR
    bomb.Material = Enum.Material.Neon
    bomb.Anchored = true
    bomb.CanCollide = false
    bomb.CanQuery = false
    bomb.CanTouch = false
    bomb.CastShadow = false
    bomb.Massless = true
    bomb.Parent = Cam  -- в камере, чтобы античит не съел

    for _, face in ipairs({
        Enum.NormalId.Front, Enum.NormalId.Back,
        Enum.NormalId.Left, Enum.NormalId.Right,
        Enum.NormalId.Top, Enum.NormalId.Bottom
    }) do
        local sg = Instance.new("SurfaceGui")
        sg.Face = face
        sg.CanvasSize = Vector2.new(200, 200)
        sg.LightInfluence = 0
        sg.Parent = bomb

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, 0, 1, 0)
        t.BackgroundTransparency = 1
        t.Text = BOMB_SYMBOL
        t.TextColor3 = Color3.new(0, 0, 0)
        t.TextScaled = true
        t.Font = Enum.Font.GothamBlack
        t.Parent = sg
    end

    local light = Instance.new("PointLight")
    light.Color = BOMB_COLOR
    light.Range = 60
    light.Brightness = 8
    light.Parent = bomb

    return bomb
end

-- ═══════════════════════════════════════
-- ЗАПУСК
-- ═══════════════════════════════════════
local function startCountdown()
    if isActive then log("уже активно"); return end

    local char = LP.Character
    if not char then log("нет персонажа"); return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then log("мёртв"); return end

    isActive = true
    label.Visible = true
    log("отсчёт")

    for i = COUNTDOWN_START, 1, -1 do
        label.Text = tostring(i)
        local startT = tick()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not label.Parent then conn:Disconnect(); return end
            label.TextColor3 = getRainbowColor(tick() - startT)
        end)
        task.wait(1)
        conn:Disconnect()
    end

    label.Visible = false

    local ok, err = pcall(function()
        local char2 = LP.Character
        if not char2 then error("персонаж исчез") end

        local hrp = char2:FindFirstChild("HumanoidRootPart")
        local hum2 = char2:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum2 then error("нет HRP/Humanoid") end

        hum2.WalkSpeed = 0
        hum2.JumpPower = 0
        hrp.Anchored = true

        local bomb = createBomb()

        local startPos  = hrp.Position + Vector3.new(0, 500, 0)
        local targetPos = hrp.Position
        bomb.CFrame = CFrame.new(startPos)

        local dist = (targetPos - startPos).Magnitude
        local travelTime = math.max(dist / BOMB_SPEED, 1)

        local tw = TweenService:Create(
            bomb,
            TweenInfo.new(travelTime, Enum.EasingStyle.Linear),
            { CFrame = CFrame.new(targetPos) }
        )
        tw:Play()
        tw.Completed:Wait()

        hrp.Anchored = false

        local ex = Instance.new("Explosion")
        ex.Position = bomb.Position
        ex.BlastRadius = 100
        ex.BlastPressure = 0
        ex.DestroyJointRadiusPercent = 0
        ex.Parent = workspace

        local dir = (hrp.Position - bomb.Position)
        if dir.Magnitude < 0.1 then dir = Vector3.new(1, 1, 1) end
        dir = dir.Unit

        bomb:Destroy()

        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = dir * PUSH_FORCE + Vector3.new(0, PUSH_FORCE, 0)
        bv.P = 100000
        bv.Parent = hrp

        local bf = Instance.new("BodyForce")
        bf.Force = Vector3.new(0, workspace.Gravity * hrp:GetMass(), 0)
        bf.Parent = hrp

        local att = Instance.new("Attachment", hrp)
        local pe = Instance.new("ParticleEmitter")
        pe.Color = ColorSequence.new(BOMB_COLOR)
        pe.Size = NumberSequence.new(3)
        pe.Lifetime = NumberRange.new(2)
        pe.Rate = 200
        pe.Speed = NumberRange.new(10)
        pe.SpreadAngle = Vector2.new(180, 180)
        pe.LightEmission = 1
        pe.Parent = att

        task.delay(DEATH_DELAY, function()
            if bv then bv:Destroy() end
            if bf then bf:Destroy() end
            if pe then pe:Destroy() end
            if att then att:Destroy() end

            local h = char2 and char2:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then h.Health = 0 end
            isActive = false
        end)
    end)

    if not ok then
        warn("[NUKE] " .. tostring(err))
        isActive = false
        if LP.Character then
            local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
    end
end

-- ═══════════════════════════════════════
-- 🎯 ПЕРЕТАСКИВАНИЕ + КЛИК
-- ═══════════════════════════════════════
local dragging   = false
local dragStart  = nil      -- позиция курсора в момент нажатия
local startPos   = nil      -- позиция кнопки в момент нажатия
local moved      = false    -- флаг: двигали ли (для отличия клика от drag)

local function beginDrag(input)
    dragging  = true
    moved     = false
    dragStart = Vector2.new(input.Position.X, input.Position.Y)
    startPos  = btn.Position
end

local function updateDrag(input)
    if not dragging then return end

    local cur = Vector2.new(input.Position.X, input.Position.Y)
    local delta = cur - dragStart

    if delta.Magnitude > DRAG_THRESHOLD then
        moved = true
    end

    btn.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

local function endDrag()
    if not dragging then return end
    dragging = false

    -- Если НЕ двигали — это клик
    if not moved then
        startCountdown()
    end

    moved = false
end

-- 🖱 Мышь / тач
btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        beginDrag(input)

        -- Визуальный отклик
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    end
end)

btn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        updateDrag(input)
    end
end)

btn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        endDrag()

        -- Возврат цвета
        btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
end)

-- ═══════════════════════════════════════
-- 🎮 ГЕЙМПАД (клик по кнопке A)
-- ═══════════════════════════════════════
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.ButtonA then
        startCountdown()
    end
end)

log("✅ v3 загружен: кнопка в центре, таскается мышью/пальцем") ТГК КАНАЛ DELTA_ROBLOX_2
