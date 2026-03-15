-- ╔══════════════════════════════════════════════════╗
-- ║              MIKU  —  FPS CHEAT                  ║
-- ║   ESP | AimBot | TriggerBot | Teleport | Fly     ║
-- ║          Style : Z3US / Rivals                   ║
-- ╚══════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer
local Mouse            = LocalPlayer:GetMouse()



-- ══════════════════════════════
--            CONFIG
-- ══════════════════════════════
local Cfg = {
    AimBot = {
        Enabled      = false,
        Smoothness   = 0.08,   -- 0.01 = instant  /  1 = très lent
        FOV          = 150,
        WallCheck    = false,
        TeamCheck    = false,
        Prediction   = false,
        StickyAim    = false,
        Key          = Enum.UserInputType.MouseButton2,
    },
    TriggerBot = {
        Enabled = false,
        FOV     = 40,
        Delay   = 0.03,
    },
    ESP = {
        Enabled    = false,
        WallESP    = true,   -- voir à travers les murs
        HealthBar  = true,
        NameTag    = true,
        Box        = true,
        Distance   = true,
        Color      = Color3.fromRGB(255, 220, 0),  -- JAUNE
        TeamCheck  = false,
    },
    Fly = {
        Enabled = false,
        Speed   = 60,
    },
    Speed = {
        Enabled = false,
        Value   = 32,
    },
    NoClip = {
        Enabled = false,
    },
    InfJump = {
        Enabled = false,
    },
    Teleport = {
        SavedPos = nil,
    },
    AutoTP = {
        Enabled  = false,
        Distance = 5,
        Delay    = 0.8,
    },

    WallShot = {
        Enabled = false,  -- tire même derrière les murs
    },
}

-- ══════════════════════════════
--           UTILITIES
-- ══════════════════════════════
local function getRoot(p)
    return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
local function getHead(p)
    return p.Character and p.Character:FindFirstChild("Head")
end
local function getHum(p)
    return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end
local function isAlive(p)
    local h = getHum(p)
    return h and h.Health > 0
end
local function isTeam(p)
    return p.Team ~= nil and p.Team == LocalPlayer.Team
end
local function screenCenter()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end
local function toScreen(pos)
    local s, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), s.Z > 0 and on
end
local function distCenter(sp)
    return (sp - screenCenter()).Magnitude
end
local function hasLOS(target)
    if not Cfg.AimBot.WallCheck then return true end
    local char = LocalPlayer.Character
    if not char then return true end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return true end
    local head = getHead(target)
    if not head then return false end
    local ray = RaycastParams.new()
    ray.FilterDescendantsInstances = {char, target.Character}
    ray.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(root.Position, (head.Position - root.Position), ray)
    return result == nil
end

-- ══════════════════════════════
--          FOV CIRCLE
-- ══════════════════════════════
local FovCircle = Drawing.new("Circle")
FovCircle.Visible     = false
FovCircle.Thickness   = 1.2
FovCircle.Color       = Color3.fromRGB(255, 220, 0)
FovCircle.Transparency = 0.7
FovCircle.Filled      = false
FovCircle.NumSides    = 128
FovCircle.Radius      = Cfg.AimBot.FOV
FovCircle.Position    = screenCenter()

-- ══════════════════════════════════════════════════════
--   AIMBOT — Compatible toutes armes Rivals
--   Méthode : on cherche le Camera.CameraSubject pour
--   savoir si on est en 1ère personne (outil équipé)
--   et on force la rotation via le Motor6D du cou + root
-- ══════════════════════════════════════════════════════
local function getBest()
    local best, bestD = nil, math.huge

    -- Récupère le character ET le nom du joueur local pour double vérification
    local myChar = LocalPlayer.Character
    local myName = LocalPlayer.Name

    for _, p in ipairs(Players:GetPlayers()) do
        -- TRIPLE vérification : jamais soi-même
        if p == LocalPlayer then continue end
        if p.Name == myName then continue end
        if p.Character == myChar then continue end

        if not isAlive(p) then continue end
        if Cfg.AimBot.TeamCheck and isTeam(p) then continue end

        local head = getHead(p)
        if not head then continue end

        -- Vérifie que cette tête n appartient pas à notre propre character
        if myChar and head:IsDescendantOf(myChar) then continue end

        if not hasLOS(p) then continue end

        local sp, on = toScreen(head.Position)
        if not on then continue end
        -- Distance depuis la SOURIS (pas le centre écran)
        local mousePos = UserInputService:GetMouseLocation()
        local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        if d < Cfg.AimBot.FOV and d < bestD then
            bestD = d
            best  = p
        end
    end
    return best
end

local lockedTarget = nil

-- Trouve le Motor6D du cou pour orienter la tête (1ère personne)
local function getNeckMotor()
    local char = LocalPlayer.Character
    if not char then return nil end
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if not torso then return nil end
    for _, m in ipairs(torso:GetChildren()) do
        if m:IsA("Motor6D") and (m.Name == "Neck" or m.Name == "NeckRigAttachment") then
            return m
        end
    end
    -- R15 : cherche dans le HumanoidRootPart aussi
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        for _, m in ipairs(root:GetChildren()) do
            if m:IsA("Motor6D") then return m end
        end
    end
    return nil
end

-- ══════════════════════════════════════════════════════════
-- AIMBOT CORE — méthode exacte des vrais scripts Rivals
-- En 1ère personne  : Camera.CFrame direct (instantané)
-- En 3ème personne  : mousemoverel (suit la souris)
-- Le FOV circle suit la souris comme dans KiCiaHook
-- ══════════════════════════════════════════════════════════

local function isFirstPerson()
    return Camera.CameraType == Enum.CameraType.Custom
        and (Camera.CFrame.Position - (LocalPlayer.Character and
        LocalPlayer.Character:FindFirstChild("Head") and
        LocalPlayer.Character.Head.Position or Vector3.zero)).Magnitude < 2
end

local function doSnap(headPos)
    local camPos = Camera.CFrame.Position
    local targetCF = CFrame.new(camPos, headPos)

    if isFirstPerson() then
        -- 1ère personne : snap Camera direct, instantané
        Camera.CFrame = targetCF
    else
        -- 3ème personne : mousemoverel — déplace la souris
        -- vers le pixel de la tête (comme Exunys V2)
        local vec = Camera:WorldToViewportPoint(headPos)
        local mousePos = UserInputService:GetMouseLocation()
        local deltaX = vec.X - mousePos.X
        local deltaY = vec.Y - mousePos.Y
        -- Sensitivity = 1 pour snap instantané
        mousemoverel(deltaX, deltaY)
    end
end

RunService.RenderStepped:Connect(function()
    -- FOV circle suit la souris (comme KiCiaHook/Exunys)
    local mpos = UserInputService:GetMouseLocation()
    FovCircle.Position = Vector2.new(mpos.X, mpos.Y)
    FovCircle.Radius   = Cfg.AimBot.FOV

    -- AimBot
    if Cfg.AimBot.Enabled and UserInputService:IsMouseButtonPressed(Cfg.AimBot.Key) then
        FovCircle.Color = Color3.fromRGB(255, 50, 50)

        -- Garder la cible lockée si toujours valide
        if lockedTarget and isAlive(lockedTarget) then
            local head = getHead(lockedTarget)
            if head then
                local aimPos = head.Position
                if Cfg.AimBot.Prediction then
                    local r = getRoot(lockedTarget)
                    if r then aimPos = aimPos + r.AssemblyLinearVelocity * 0.06 end
                end
                doSnap(aimPos)
            else
                lockedTarget = nil
            end
        else
            lockedTarget = getBest()
            if lockedTarget then
                local head = getHead(lockedTarget)
                if head then doSnap(head.Position) end
            end
        end
    else
        lockedTarget = nil
        FovCircle.Color = Color3.fromRGB(255, 220, 0)
    end

    -- TriggerBot : tire UNIQUEMENT si le viseur (centre écran) est sur la tête
    -- Pas juste dans le cercle FOV — on fait un raycast depuis la caméra
    if Cfg.TriggerBot.Enabled then
        local char = LocalPlayer.Character
        local camCF = Camera.CFrame
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        if char then ray.FilterDescendantsInstances = {char} end

        -- On cast depuis le centre exact de la caméra vers où elle regarde
        local result = workspace:Raycast(camCF.Position, camCF.LookVector * 500, ray)
        if result and result.Instance then
            -- Vérifie si ce qu'on touche appartient à un ennemi
            local hitPart = result.Instance
            local hitChar = hitPart.Parent
            local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
            if hitPlayer and hitPlayer ~= LocalPlayer then
                if isAlive(hitPlayer) then
                    if not (Cfg.AimBot.TeamCheck and isTeam(hitPlayer)) then
                        -- On est bien en train de viser cet ennemi → on tir
                        task.wait(Cfg.TriggerBot.Delay)
                        mouse1click()
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════
--   SILENT AIM + WALL SHOT — Xeno compatible
--   hookmetamethod correctement appelé sur Mouse (pas game)
--   Xeno supporte cette API — le bug était l'argument wrong
-- ══════════════════════════════════════════════════════════
local silentTarget = nil

-- Trouve la cible la plus proche de la souris SANS wall check
local function updateSilentTarget()
    if not Cfg.WallShot.Enabled then silentTarget = nil return end
    local best, bestD = nil, math.huge
    local myChar = LocalPlayer.Character
    local myHead = myChar and myChar:FindFirstChild("Head")
    local mousePos = UserInputService:GetMouseLocation()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not isAlive(p) then continue end
        if Cfg.AimBot.TeamCheck and isTeam(p) then continue end
        local head = getHead(p)
        if not head then continue end
        if myHead and (head.Position - myHead.Position).Magnitude < 3 then continue end
        local sp, on = toScreen(head.Position)
        if not on then continue end
        local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        if d < Cfg.AimBot.FOV and d < bestD then
            bestD = d; best = p
        end
    end
    silentTarget = best
end

RunService.Heartbeat:Connect(updateSilentTarget)

-- ══════════════════════════════════════════════════════
--   SILENT AIM ESP — indicateur visuel du lock Wall Shot
--   Montre exactement sur quelle tête le silent aim vise
--   Croix rouge sur la tête + ligne depuis ta souris
-- ══════════════════════════════════════════════════════

-- Croix sur la tête lockée
local SAcross1 = Drawing.new("Line")
SAcross1.Visible = false; SAcross1.Thickness = 2
SAcross1.Color = Color3.fromRGB(255,40,40); SAcross1.Transparency = 0

local SAcross2 = Drawing.new("Line")
SAcross2.Visible = false; SAcross2.Thickness = 2
SAcross2.Color = Color3.fromRGB(255,40,40); SAcross2.Transparency = 0

-- Cercle autour de la tête lockée
local SAcircle = Drawing.new("Circle")
SAcircle.Visible = false; SAcircle.Thickness = 1.5
SAcircle.Color = Color3.fromRGB(255,80,80); SAcircle.Transparency = 0.3
SAcircle.Filled = false; SAcircle.NumSides = 32; SAcircle.Radius = 10

-- Ligne depuis la souris vers la tête lockée
local SAline = Drawing.new("Line")
SAline.Visible = false; SAline.Thickness = 1
SAline.Color = Color3.fromRGB(255,40,40); SAline.Transparency = 0.5

-- Label "LOCKED" au dessus de la tête
local SAlabel = Drawing.new("Text")
SAlabel.Visible = false; SAlabel.Size = 12
SAlabel.Font = Drawing.Fonts.UI; SAlabel.Outline = true
SAlabel.Center = true; SAlabel.Color = Color3.fromRGB(255,60,60)
SAlabel.Text = "● SILENT LOCK"

RunService.RenderStepped:Connect(function()
    if not Cfg.WallShot.Enabled or not silentTarget then
        SAcross1.Visible = false; SAcross2.Visible = false
        SAcircle.Visible = false; SAline.Visible = false
        SAlabel.Visible = false
        return
    end

    local head = getHead(silentTarget)
    if not head or not isAlive(silentTarget) then
        SAcross1.Visible = false; SAcross2.Visible = false
        SAcircle.Visible = false; SAline.Visible = false
        SAlabel.Visible = false
        return
    end

    local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
    local headSP = Vector2.new(sp.X, sp.Y)
    local mousePos = UserInputService:GetMouseLocation()
    local sz = 10 -- taille de la croix

    if onScreen and sp.Z > 0 then
        -- Croix ✕ sur la tête
        SAcross1.From = headSP - Vector2.new(sz, sz)
        SAcross1.To   = headSP + Vector2.new(sz, sz)
        SAcross1.Visible = true

        SAcross2.From = headSP + Vector2.new(-sz, sz)
        SAcross2.To   = headSP + Vector2.new(sz, -sz)
        SAcross2.Visible = true

        -- Cercle autour
        SAcircle.Position = headSP
        SAcircle.Visible = true

        -- Ligne souris → tête
        SAline.From = mousePos
        SAline.To   = headSP
        SAline.Visible = true

        -- Label
        SAlabel.Position = Vector2.new(headSP.X, headSP.Y - 22)
        SAlabel.Visible = true
    else
        -- Cible hors écran mais lockée — flèche vers le bord
        SAcross1.Visible = false; SAcross2.Visible = false
        SAcircle.Visible = false; SAline.Visible = false
        SAlabel.Visible = false
    end
end)

-- ══════════════════════════════════════════════════════
-- SILENT AIM HOOK — compatible Xeno + tous exécuteurs
-- Ta souris bouge PAS — balles vont sur la tête ennemie
-- ══════════════════════════════════════════════════════
local silentHookActive = false

-- newcclosure est dispo sur Xeno mais on vérifie quand même
local wrapFn = (typeof(newcclosure) == "function") and newcclosure or function(f) return f end

local hookSuccess = pcall(function()
    local origIndex = hookmetamethod(Mouse, "__index", wrapFn(function(self, key)
        if Cfg.WallShot.Enabled and silentTarget then
            local head = getHead(silentTarget)
            if head and isAlive(silentTarget) then
                if key == "Hit" then
                    return CFrame.new(head.Position)
                elseif key == "UnitRay" then
                    local origin = Camera.CFrame.Position
                    local dir = (head.Position - origin).Unit
                    return Ray.new(origin, dir * 999)
                elseif key == "Target" then
                    return head
                end
            end
        end
        return origIndex(self, key)
    end))
    silentHookActive = true
end)

if not hookSuccess then
    -- Si hookmetamethod pas dispo : on snap la caméra seulement
    -- sans bouger la souris (pas de mousemoverel)
    RunService.RenderStepped:Connect(function()
        if not Cfg.WallShot.Enabled or not silentTarget then return end
        local head = getHead(silentTarget)
        if not head or not isAlive(silentTarget) then return end
        local camPos = Camera.CFrame.Position
        local dir = (head.Position - camPos).Unit
        Camera.CFrame = CFrame.new(camPos, camPos + dir)
    end)
end

-- ══════════════════════════════
--        AUTO-TP (se TP sur la cible la plus proche en boucle)
-- ══════════════════════════════
local autoTPconn
local function startAutoTP()
    if autoTPconn then autoTPconn:Disconnect() end
    autoTPconn = RunService.Heartbeat:Connect(function()
        if not Cfg.AutoTP.Enabled then
            autoTPconn:Disconnect()
            autoTPconn = nil
            return
        end

        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        -- Trouve l'ennemi vivant le plus proche
        local best, bestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if not isAlive(p) then continue end
            if Cfg.AimBot.TeamCheck and isTeam(p) then continue end
            local r = getRoot(p)
            if not r then continue end
            local d = (r.Position - myRoot.Position).Magnitude
            if d < bestDist then bestDist = d; best = p end
        end

        if best then
            local tRoot = getRoot(best)
            if tRoot then
                -- Se TP juste derrière la cible
                local offset = tRoot.CFrame.LookVector * (-Cfg.AutoTP.Distance)
                myRoot.CFrame = CFrame.new(tRoot.Position + offset + Vector3.new(0,2,0))
            end
        end

        task.wait(Cfg.AutoTP.Delay)
    end)
end

-- ══════════════════════════════
--             ESP
-- ══════════════════════════════
local ESPObj = {}

local function mkDraw(kind, props)
    local d = Drawing.new(kind)
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function buildESP(p)
    if ESPObj[p] then return end
    ESPObj[p] = {
        Box    = mkDraw("Square", { Filled=false, Thickness=1.4, Visible=false, Color=Cfg.ESP.Color }),
        BG     = mkDraw("Square", { Filled=true,  Visible=false, Color=Color3.fromRGB(20,20,20), Transparency=0.45 }),
        HpBG   = mkDraw("Square", { Filled=true,  Visible=false, Color=Color3.fromRGB(20,20,20) }),
        HpBar  = mkDraw("Square", { Filled=true,  Visible=false, Color=Color3.fromRGB(80,255,80) }),
        Name   = mkDraw("Text",   { Size=13, Font=Drawing.Fonts.UI, Outline=true, Center=true, Visible=false, Color=Color3.fromRGB(255,255,255) }),
        Dist   = mkDraw("Text",   { Size=11, Font=Drawing.Fonts.UI, Outline=true, Center=true, Visible=false, Color=Cfg.ESP.Color }),
    }
end

local function removeESP(p)
    if not ESPObj[p] then return end
    for _, d in pairs(ESPObj[p]) do d:Remove() end
    ESPObj[p] = nil
end

local function hideESP(p)
    if not ESPObj[p] then return end
    for _, d in pairs(ESPObj[p]) do d.Visible = false end
end

RunService.RenderStepped:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        buildESP(p)

        local show = Cfg.ESP.Enabled and isAlive(p)
        if Cfg.ESP.TeamCheck and isTeam(p) then show = false end

        if not show then hideESP(p) continue end

        local char = p.Character
        if not char then hideESP(p) continue end

        local head = char:FindFirstChild("Head")
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not head or not root or not hum then hideESP(p) continue end

        -- Distance check
        local dist3D = (root.Position - Camera.CFrame.Position).Magnitude
        if dist3D > 1500 then hideESP(p) continue end

        local topSP, topOn = toScreen(head.Position + Vector3.new(0, 0.65, 0))
        local botSP, botOn = toScreen(root.Position - Vector3.new(0, 2.8, 0))
        if not topOn or not botOn then hideESP(p) continue end

        local H    = math.abs(botSP.Y - topSP.Y)
        local W    = H * 0.52
        local bx   = topSP.X - W / 2
        local by   = topSP.Y
        local obj  = ESPObj[p]
        local hpR  = math.clamp(hum.Health / hum.MaxHealth, 0, 1)

        -- Box
        obj.Box.Position = Vector2.new(bx, by)
        obj.Box.Size     = Vector2.new(W, H)
        obj.Box.Color    = Cfg.ESP.Color
        obj.Box.Visible  = Cfg.ESP.Box

        -- HealthBar (gauche)
        local barX = bx - 6
        obj.HpBG.Position = Vector2.new(barX, by)
        obj.HpBG.Size     = Vector2.new(3, H)
        obj.HpBG.Visible  = Cfg.ESP.HealthBar

        obj.HpBar.Position = Vector2.new(barX, by + H * (1 - hpR))
        obj.HpBar.Size     = Vector2.new(3, H * hpR)
        obj.HpBar.Color    = Color3.fromRGB(
            math.floor(255 * (1-hpR)),
            math.floor(255 * hpR),
            50
        )
        obj.HpBar.Visible = Cfg.ESP.HealthBar

        -- Name
        obj.Name.Text     = p.Name
        obj.Name.Position = Vector2.new(topSP.X, by - 16)
        obj.Name.Visible  = Cfg.ESP.NameTag

        -- Distance
        obj.Dist.Text     = math.floor(dist3D) .. "m"
        obj.Dist.Position = Vector2.new(topSP.X, botSP.Y + 2)
        obj.Dist.Visible  = Cfg.ESP.Distance
    end
end)

Players.PlayerRemoving:Connect(removeESP)

-- ══════════════════════════════
--             FLY
-- ══════════════════════════════
local flyConn, flyBodies

local function enableFly()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not root then return end
    if hum then hum.PlatformStand = true end

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(9e9,9e9,9e9)
    bg.P = 9e4
    bg.CFrame = root.CFrame
    bg.Parent = root

    local bv = Instance.new("BodyVelocity")
    bv.Velocity  = Vector3.zero
    bv.MaxForce  = Vector3.new(9e9,9e9,9e9)
    bv.Parent    = root
    flyBodies    = {bg=bg, bv=bv}

    flyConn = RunService.RenderStepped:Connect(function()
        if not Cfg.Fly.Enabled then
            bg:Destroy(); bv:Destroy()
            if hum then hum.PlatformStand = false end
            flyBodies = nil
            flyConn:Disconnect()
            return
        end
        local d = Vector3.zero
        local UIS = UserInputService
        if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)       then d = d + Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.yAxis end
        bv.Velocity = d.Magnitude > 0 and d.Unit * Cfg.Fly.Speed or Vector3.zero
        bg.CFrame   = Camera.CFrame
    end)
end

local function disableFly()
    Cfg.Fly.Enabled = false
    if flyBodies then
        pcall(function() flyBodies.bg:Destroy() flyBodies.bv:Destroy() end)
        flyBodies = nil
    end
    if flyConn then flyConn:Disconnect() flyConn = nil end
    local char = LocalPlayer.Character
    if char then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
end

-- ══════════════════════════════
--           NOCLIP
-- ══════════════════════════════
local ncConn
local function startNC()
    ncConn = RunService.Stepped:Connect(function()
        if not Cfg.NoClip.Enabled then ncConn:Disconnect() return end
        local c = LocalPlayer.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end

-- ══════════════════════════════
--        INFINITE JUMP
-- ══════════════════════════════
UserInputService.JumpRequest:Connect(function()
    if not Cfg.InfJump.Enabled then return end
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- ══════════════════════════════
--         SPEED BOOST
-- ══════════════════════════════
RunService.Heartbeat:Connect(function()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if not h then return end
    h.WalkSpeed = Cfg.Speed.Enabled and Cfg.Speed.Value or 16
end)

-- ══════════════════════════════════════════════════════
--                    GUI — STYLE Z3US
-- ══════════════════════════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name             = "MIKU_GUI"
SG.ResetOnSpawn     = false
SG.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset   = true
local sgParent
local ok = pcall(function() sgParent = game:GetService("CoreGui") end)
if not ok then sgParent = LocalPlayer:WaitForChild("PlayerGui") end
SG.Parent = sgParent

-- MAIN WINDOW
local WIN = Instance.new("Frame")
WIN.Size              = UDim2.new(0, 560, 0, 400)
WIN.Position          = UDim2.new(0.5, -280, 0.5, -200)
WIN.BackgroundColor3  = Color3.fromRGB(12, 8, 22)
WIN.BorderSizePixel   = 0
WIN.ClipsDescendants  = true
WIN.Parent            = SG
do
    local c = Instance.new("UICorner", WIN); c.CornerRadius = UDim.new(0,10)
    local s = Instance.new("UIStroke", WIN)
    s.Color = Color3.fromRGB(80, 40, 120); s.Thickness = 1.2; s.Transparency = 0.3
end

-- TITLE BAR
local TBAR = Instance.new("Frame")
TBAR.Size             = UDim2.new(1,0,0,38)
TBAR.BackgroundColor3 = Color3.fromRGB(18, 10, 35)
TBAR.BorderSizePixel  = 0
TBAR.Parent           = WIN
do
    local c = Instance.new("UICorner", TBAR); c.CornerRadius = UDim.new(0,10)
    local f = Instance.new("Frame", TBAR) -- fix bottom corners
    f.Size = UDim2.new(1,0,0,10); f.Position = UDim2.new(0,0,1,-10)
    f.BackgroundColor3 = Color3.fromRGB(18,10,35); f.BorderSizePixel=0
end

-- Logo dot
local logoDot = Instance.new("Frame", TBAR)
logoDot.Size = UDim2.new(0,8,0,8)
logoDot.Position = UDim2.new(0,14,0.5,-4)
logoDot.BackgroundColor3 = Color3.fromRGB(255,220,0)
logoDot.BorderSizePixel=0
Instance.new("UICorner",logoDot).CornerRadius=UDim.new(1,0)

local TITLE = Instance.new("TextLabel", TBAR)
TITLE.Size             = UDim2.new(1,-100,1,0)
TITLE.Position         = UDim2.new(0,30,0,0)
TITLE.BackgroundTransparency = 1
TITLE.Text             = "MIKU"
TITLE.TextColor3       = Color3.fromRGB(255,255,255)
TITLE.TextSize         = 14
TITLE.Font             = Enum.Font.GothamBold
TITLE.TextXAlignment   = Enum.TextXAlignment.Left

local SUBTITLE = Instance.new("TextLabel", TBAR)
SUBTITLE.Size          = UDim2.new(1,-100,1,0)
SUBTITLE.Position      = UDim2.new(0,70,0,0)
SUBTITLE.BackgroundTransparency = 1
SUBTITLE.Text          = "| Rivals"
SUBTITLE.TextColor3    = Color3.fromRGB(160,100,220)
SUBTITLE.TextSize      = 13
SUBTITLE.Font          = Enum.Font.Gotham
SUBTITLE.TextXAlignment = Enum.TextXAlignment.Left

-- Close btn
local CLOSEBTN = Instance.new("TextButton", TBAR)
CLOSEBTN.Size   = UDim2.new(0,26,0,26)
CLOSEBTN.Position = UDim2.new(1,-34,0.5,-13)
CLOSEBTN.BackgroundColor3 = Color3.fromRGB(180,40,60)
CLOSEBTN.Text   = "✕"
CLOSEBTN.TextColor3 = Color3.fromRGB(255,255,255)
CLOSEBTN.TextSize   = 12
CLOSEBTN.Font   = Enum.Font.GothamBold
CLOSEBTN.BorderSizePixel = 0
Instance.new("UICorner",CLOSEBTN).CornerRadius = UDim.new(0,5)
CLOSEBTN.MouseButton1Click:Connect(function()
    SG:Destroy(); FovCircle:Remove()
end)

-- Drag
local drag, ds, dp
TBAR.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true; ds=i.Position; dp=WIN.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-ds
        WIN.Position=UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)

-- ══════════════════
--   SIDEBAR
-- ══════════════════
local SIDEBAR = Instance.new("Frame", WIN)
SIDEBAR.Size             = UDim2.new(0, 130, 1, -38)
SIDEBAR.Position         = UDim2.new(0, 0, 0, 38)
SIDEBAR.BackgroundColor3 = Color3.fromRGB(14, 9, 26)
SIDEBAR.BorderSizePixel  = 0

local SBList = Instance.new("UIListLayout", SIDEBAR)
SBList.Padding = UDim.new(0,2)
local SBPad = Instance.new("UIPadding", SIDEBAR)
SBPad.PaddingTop = UDim.new(0,8)
SBPad.PaddingLeft = UDim.new(0,6)
SBPad.PaddingRight = UDim.new(0,6)

-- CONTENT AREA
local CONTENT = Instance.new("Frame", WIN)
CONTENT.Size             = UDim2.new(1,-130,1,-38)
CONTENT.Position         = UDim2.new(0,130,0,38)
CONTENT.BackgroundColor3 = Color3.fromRGB(10, 7, 18)
CONTENT.BorderSizePixel  = 0

-- Separator line
local SEP = Instance.new("Frame", WIN)
SEP.Size   = UDim2.new(0,1,1,-38)
SEP.Position = UDim2.new(0,130,0,38)
SEP.BackgroundColor3 = Color3.fromRGB(60,30,90)
SEP.BorderSizePixel  = 0

-- ══════════════════
--   TAB SYSTEM
-- ══════════════════
local tabs = {}
local activeTab = nil

local tabDefs = {
    { name = "Legit",     icon = "◉" },
    { name = "Rage",      icon = "⚡" },
    { name = "Visuals",   icon = "👁" },
    { name = "Player",    icon = "👤" },
    { name = "Teleport",  icon = "⊕" },
    { name = "World",     icon = "◎" },
    { name = "Misc",      icon = "≡" },
    { name = "Settings",  icon = "⚙" },
}

local function makeScroll()
    local sf = Instance.new("ScrollingFrame", CONTENT)
    sf.Size                = UDim2.new(1,0,1,0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel     = 0
    sf.ScrollBarThickness  = 2
    sf.ScrollBarImageColor3 = Color3.fromRGB(180,80,255)
    sf.CanvasSize          = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Visible             = false

    local ul = Instance.new("UIListLayout", sf)
    ul.Padding = UDim.new(0,4)
    local up = Instance.new("UIPadding", sf)
    up.PaddingLeft=UDim.new(0,14); up.PaddingRight=UDim.new(0,14)
    up.PaddingTop=UDim.new(0,12);  up.PaddingBottom=UDim.new(0,12)
    return sf
end

local function activateTab(name)
    activeTab = name
    for n, t in pairs(tabs) do
        local on = n==name
        TweenService:Create(t.btn, TweenInfo.new(0.15), {
            BackgroundColor3 = on and Color3.fromRGB(35,18,65) or Color3.fromRGB(0,0,0),
            BackgroundTransparency = on and 0 or 1,
        }):Play()
        t.btn.TextColor3 = on and Color3.fromRGB(255,220,0) or Color3.fromRGB(180,160,210)
        t.frame.Visible  = on
    end
end

for _, td in ipairs(tabDefs) do
    local sf = makeScroll()

    local btn = Instance.new("TextButton", SIDEBAR)
    btn.Size             = UDim2.new(1,0,0,34)
    btn.BackgroundTransparency = 1
    btn.Text             = td.icon .. "  " .. td.name
    btn.TextColor3       = Color3.fromRGB(180,160,210)
    btn.TextSize         = 12
    btn.Font             = Enum.Font.Gotham
    btn.TextXAlignment   = Enum.TextXAlignment.Left
    btn.BorderSizePixel  = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    local bp = Instance.new("UIPadding", btn)
    bp.PaddingLeft = UDim.new(0,8)

    btn.MouseButton1Click:Connect(function() activateTab(td.name) end)

    tabs[td.name] = { btn=btn, frame=sf }
end

-- ══════════════════════════════
--    UI COMPONENTS (réutilisables)
-- ══════════════════════════════
local function sectionTitle(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size             = UDim2.new(1,0,0,20)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text
    lbl.TextColor3       = Color3.fromRGB(255,220,0)
    lbl.TextSize         = 11
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    local sep = Instance.new("Frame", parent)
    sep.Size = UDim2.new(1,0,0,1)
    sep.BackgroundColor3 = Color3.fromRGB(60,30,100)
    sep.BorderSizePixel  = 0
    return lbl
end

local function toggle(parent, label, cfg, key, cb)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(1,0,0,34)
    row.BackgroundColor3 = Color3.fromRGB(20,12,38)
    row.BorderSizePixel  = 0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)

    local lbl = Instance.new("TextLabel",row)
    lbl.Size             = UDim2.new(1,-54,1,0)
    lbl.Position         = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency=1
    lbl.Text             = label
    lbl.TextColor3       = Color3.fromRGB(220,210,235)
    lbl.TextSize         = 12
    lbl.Font             = Enum.Font.Gotham
    lbl.TextXAlignment   = Enum.TextXAlignment.Left

    local bg = Instance.new("Frame",row)
    bg.Size              = UDim2.new(0,38,0,20)
    bg.Position          = UDim2.new(1,-50,0.5,-10)
    bg.BackgroundColor3  = Color3.fromRGB(35,30,50)
    bg.BorderSizePixel   = 0
    Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0)

    local knob = Instance.new("Frame",bg)
    knob.Size            = UDim2.new(0,16,0,16)
    knob.Position        = UDim2.new(0,2,0.5,-8)
    knob.BackgroundColor3= Color3.fromRGB(100,80,140)
    knob.BorderSizePixel = 0
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

    local function upd()
        local on = cfg[key]
        TweenService:Create(knob,TweenInfo.new(0.12),{
            Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8),
            BackgroundColor3 = on and Color3.fromRGB(255,220,0) or Color3.fromRGB(100,80,140),
        }):Play()
        TweenService:Create(bg,TweenInfo.new(0.12),{
            BackgroundColor3 = on and Color3.fromRGB(80,55,15) or Color3.fromRGB(35,30,50),
        }):Play()
    end

    local hitbox = Instance.new("TextButton",row)
    hitbox.Size=UDim2.new(1,0,1,0); hitbox.BackgroundTransparency=1; hitbox.Text=""
    hitbox.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        upd()
        if cb then cb(cfg[key]) end
    end)
    upd()
    return row
end

local function slider(parent, label, cfg, key, mn, mx, cb)
    local row = Instance.new("Frame",parent)
    row.Size             = UDim2.new(1,0,0,50)
    row.BackgroundColor3 = Color3.fromRGB(20,12,38)
    row.BorderSizePixel  = 0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)

    local lbl = Instance.new("TextLabel",row)
    lbl.Size = UDim2.new(1,-60,0,22); lbl.Position=UDim2.new(0,12,0,4)
    lbl.BackgroundTransparency=1; lbl.TextColor3=Color3.fromRGB(200,190,220)
    lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.Text=label

    local val = Instance.new("TextLabel",row)
    val.Size=UDim2.new(0,50,0,22); val.Position=UDim2.new(1,-58,0,4)
    val.BackgroundTransparency=1; val.TextColor3=Color3.fromRGB(255,220,0)
    val.TextSize=11; val.Font=Enum.Font.GothamBold; val.TextXAlignment=Enum.TextXAlignment.Right
    val.Text=tostring(cfg[key])

    local track = Instance.new("Frame",row)
    track.Size=UDim2.new(1,-24,0,4); track.Position=UDim2.new(0,12,0,36)
    track.BackgroundColor3=Color3.fromRGB(40,30,60); track.BorderSizePixel=0
    Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)

    local fill = Instance.new("Frame",track)
    fill.Size=UDim2.new((cfg[key]-mn)/(mx-mn),0,1,0)
    fill.BackgroundColor3=Color3.fromRGB(180,60,255); fill.BorderSizePixel=0
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

    local knob = Instance.new("Frame",track)
    knob.Size=UDim2.new(0,10,0,10); knob.AnchorPoint=Vector2.new(0.5,0.5)
    knob.Position=UDim2.new((cfg[key]-mn)/(mx-mn),0,0.5,0)
    knob.BackgroundColor3=Color3.fromRGB(230,180,255); knob.BorderSizePixel=0
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

    local sl=false
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sl=true end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sl=false end end)
    UserInputService.InputChanged:Connect(function(i)
        if sl and i.UserInputType==Enum.UserInputType.MouseMovement then
            local r=math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            local v=math.floor(mn+r*(mx-mn))
            cfg[key]=v; fill.Size=UDim2.new(r,0,1,0); knob.Position=UDim2.new(r,0,0.5,0)
            val.Text=tostring(v)
            if cb then cb(v) end
        end
    end)
    return row
end

local function button(parent, label, cb)
    local btn = Instance.new("TextButton",parent)
    btn.Size=UDim2.new(1,0,0,34)
    btn.BackgroundColor3=Color3.fromRGB(60,30,100)
    btn.Text=label; btn.TextColor3=Color3.fromRGB(230,210,255)
    btn.TextSize=12; btn.Font=Enum.Font.GothamBold; btn.BorderSizePixel=0
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
    btn.MouseButton1Click:Connect(cb)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(90,50,150)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(60,30,100)}):Play()
    end)
    return btn
end

-- ══════════════════════════════
--   POPULATE TABS
-- ══════════════════════════════

-- ─── LEGIT ─────────────────────────────────────────
do
    local f = tabs["Legit"].frame

    sectionTitle(f, "Aimbot")
    toggle(f, "Enable",       Cfg.AimBot, "Enabled", function(v) FovCircle.Visible = v end)
    toggle(f, "Wall Check",   Cfg.AimBot, "WallCheck")
    toggle(f, "Team Check",   Cfg.AimBot, "TeamCheck")
    toggle(f, "Smoothness",   Cfg.AimBot, "Enabled") -- juste visuel, le vrai ctrl est slider
    slider(f, "Smoothness value", Cfg.AimBot, "Smoothness", 1, 100, function(v)
        Cfg.AimBot.Smoothness = v / 1000  -- 1=0.001 super rapide, 100=0.1
    end)
    toggle(f, "Enable Prediction", Cfg.AimBot, "Prediction")
    toggle(f, "Sticky Aim",   Cfg.AimBot, "StickyAim")
    slider(f, "FOV",          Cfg.AimBot, "FOV", 10, 400, function(v) FovCircle.Radius=v end)

    sectionTitle(f, "TriggerBot")
    toggle(f, "TriggerBot Enable", Cfg.TriggerBot, "Enabled")
    slider(f, "TriggerBot FOV", Cfg.TriggerBot, "FOV", 5, 150)
end

-- ─── RAGE ──────────────────────────────────────────
do
    local f = tabs["Rage"].frame
    sectionTitle(f, "Rage AimBot")
    toggle(f, "Rage Mode (FOV max)", {rm=false}, "rm", function(v)
        if v then Cfg.AimBot.FOV=400; FovCircle.Radius=400
        else Cfg.AimBot.FOV=150; FovCircle.Radius=150 end
    end)
    toggle(f, "No Recoil (simulé)", {nr=false}, "nr")
    toggle(f, "Auto Fire (TriggerBot raycast)", Cfg.TriggerBot, "Enabled")

    sectionTitle(f, "Auto-TP")
    toggle(f, "Auto-TP (se TP sur l'ennemi le plus proche)", Cfg.AutoTP, "Enabled", function(v)
        if v then startAutoTP() end
    end)
    slider(f, "Délai entre TP (x0.1s)", Cfg.AutoTP, "Delay", 1, 30, function(v)
        Cfg.AutoTP.Delay = v / 10
    end)
    slider(f, "Distance offset (studs)", Cfg.AutoTP, "Distance", 1, 20)
end

-- ─── VISUALS ───────────────────────────────────────
do
    local f = tabs["Visuals"].frame
    sectionTitle(f, "ESP")
    toggle(f, "ESP Enable",      Cfg.ESP, "Enabled")
    toggle(f, "Wall ESP (travers les murs)", Cfg.ESP, "WallESP")
    toggle(f, "Health Bar",      Cfg.ESP, "HealthBar")
    toggle(f, "Name Tag",        Cfg.ESP, "NameTag")
    toggle(f, "Box ESP",         Cfg.ESP, "Box")
    toggle(f, "Distance",        Cfg.ESP, "Distance")
    toggle(f, "Team Check",      Cfg.ESP, "TeamCheck")
    sectionTitle(f, "FOV Circle")
    toggle(f, "Afficher cercle FOV", {s=true}, "s", function(v)
        FovCircle.Visible = v and Cfg.AimBot.Enabled
    end)
end

-- ─── PLAYER ────────────────────────────────────────
do
    local f = tabs["Player"].frame
    sectionTitle(f, "Mouvement")
    toggle(f, "Fly",            Cfg.Fly,   "Enabled", function(v)
        if v then enableFly() else disableFly() end
    end)
    slider(f, "Vitesse Fly",    Cfg.Fly,   "Speed", 10, 300)
    toggle(f, "Speed Boost",    Cfg.Speed, "Enabled")
    slider(f, "Walk Speed",     Cfg.Speed, "Value", 16, 300)
    toggle(f, "NoClip",         Cfg.NoClip,"Enabled", function(v)
        if v then startNC() end
    end)
    toggle(f, "Infinite Jump",  Cfg.InfJump,"Enabled")
end

-- ─── TELEPORT ──────────────────────────────────────
do
    local f = tabs["Teleport"].frame
    sectionTitle(f, "Teleport vers joueurs")

    -- Liste dynamique
    local listFrame = Instance.new("Frame", f)
    listFrame.Size = UDim2.new(1,0,0,0)
    listFrame.AutomaticSize = Enum.AutomaticSize.Y
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel = 0
    local ll = Instance.new("UIListLayout", listFrame); ll.Padding=UDim.new(0,4)

    local function refreshList()
        for _, c in ipairs(listFrame:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local b = Instance.new("TextButton", listFrame)
            b.Size=UDim2.new(1,0,0,32)
            b.BackgroundColor3=Color3.fromRGB(22,14,40)
            b.Text="⊕  " .. p.Name
            b.TextColor3=Color3.fromRGB(210,190,240)
            b.TextSize=12; b.Font=Enum.Font.Gotham
            b.BorderSizePixel=0; b.TextXAlignment=Enum.TextXAlignment.Left
            Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
            local bp2=Instance.new("UIPadding",b); bp2.PaddingLeft=UDim.new(0,10)
            b.MouseButton1Click:Connect(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local troot = getRoot(p)
                if root and troot then
                    root.CFrame = troot.CFrame + Vector3.new(0,3,0)
                end
            end)
        end
    end

    sectionTitle(f, "Position")
    button(f, "💾  Sauvegarder Position", function()
        local root = getRoot(LocalPlayer)
        if root then Cfg.Teleport.SavedPos = root.CFrame end
    end)
    button(f, "⊕  Retourner Position Sauvegardée", function()
        local root = getRoot(LocalPlayer)
        if root and Cfg.Teleport.SavedPos then
            root.CFrame = Cfg.Teleport.SavedPos
        end
    end)
    button(f, "🔄 Rafraîchir liste joueurs", refreshList)
    refreshList()
    Players.PlayerAdded:Connect(refreshList)
    Players.PlayerRemoving:Connect(function() task.wait(0.1) refreshList() end)
end

-- ─── WORLD ─────────────────────────────────────────
do
    local f = tabs["World"].frame
    sectionTitle(f, "World")
    toggle(f, "Ambient Light Hack", {al=false}, "al", function(v)
        workspace.GlobalShadows = not v
    end)
    button(f, "Supprimer brouillard", function()
        workspace.FogEnd = 9e9
    end)
    button(f, "Plein jour (heure=12)", function()
        local l = workspace:FindFirstChildOfClass("Lighting")
        if l then l.TimeOfDay = "12:00:00" end
    end)
end

-- ─── MISC ──────────────────────────────────────────
do
    local f = tabs["Misc"].frame
    sectionTitle(f, "Divers")
    toggle(f, "Anti-AFK", {afk=false}, "afk", function(v)
        if v then
            spawn(function()
                while tabs["Misc"] and true do
                    task.wait(60)
                    local vc = LocalPlayer:FindFirstChildOfClass("VirtualUser")
                    if vc then vc:CaptureController() vc:ClickButton2(Vector2.new()) end
                end
            end)
        end
    end)
    button(f, "Rejoin serveur", function()
        local ts = game:GetService("TeleportService")
        ts:Teleport(game.PlaceId, LocalPlayer)
    end)
end

-- ─── SETTINGS ──────────────────────────────────────
do
    local f = tabs["Settings"].frame
    sectionTitle(f, "Raccourcis clavier")

    local info = Instance.new("TextLabel", f)
    info.Size=UDim2.new(1,0,0,60)
    info.BackgroundColor3=Color3.fromRGB(20,12,38)
    info.BorderSizePixel=0
    info.TextColor3=Color3.fromRGB(180,170,210)
    info.TextSize=11; info.Font=Enum.Font.Gotham
    info.TextWrapped=true; info.TextXAlignment=Enum.TextXAlignment.Left
    info.Text="  AimBot : Clic Droit\n  Ouvrir/Fermer panel : Insert\n  Fly : activé dans l'onglet Player\n  NoClip : activé dans l'onglet Player"
    Instance.new("UICorner",info).CornerRadius=UDim.new(0,6)
    local ip=Instance.new("UIPadding",info); ip.PaddingLeft=UDim.new(0,8)

    sectionTitle(f, "🔫 Wall Shot / Silent Aim (tire derrière les murs)")
    toggle(f, "Wall Shot Enable", Cfg.WallShot, "Enabled")

    sectionTitle(f, "Fenêtre")
    slider(f, "Largeur panel", {w=560}, "w", 400, 900, function(v)
        WIN.Size = UDim2.new(0,v,0,WIN.AbsoluteSize.Y)
    end)
    slider(f, "Hauteur panel", {h=400}, "h", 300, 700, function(v)
        WIN.Size = UDim2.new(0,WIN.AbsoluteSize.X,0,v)
    end)

    -- ─── THEMES ────────────────────────────────────
    sectionTitle(f, "🎨 Thèmes")

    -- Définition des thèmes
    local Themes = {
        {
            name    = "Default",
            icon    = "⬛",
            win     = Color3.fromRGB(12,  8,  22),
            tbar    = Color3.fromRGB(18, 10,  35),
            sidebar = Color3.fromRGB(14,  9,  26),
            content = Color3.fromRGB(10,  7,  18),
            row     = Color3.fromRGB(20, 12,  38),
            accent  = Color3.fromRGB(255,220,   0),
            stroke  = Color3.fromRGB(80, 40, 120),
            tabOn   = Color3.fromRGB(35, 18,  65),
            sep     = Color3.fromRGB(60, 30, 100),
            text    = Color3.fromRGB(220,210, 235),
            knobOn  = Color3.fromRGB(255,220,   0),
            bgKnob  = Color3.fromRGB(80, 55,  15),
        },
        {
            name    = "Amethyst",
            icon    = "💜",
            win     = Color3.fromRGB(14,  8,  28),
            tbar    = Color3.fromRGB(25, 12,  50),
            sidebar = Color3.fromRGB(18, 10,  36),
            content = Color3.fromRGB(11,  7,  22),
            row     = Color3.fromRGB(28, 14,  52),
            accent  = Color3.fromRGB(180, 80, 255),
            stroke  = Color3.fromRGB(140, 50, 220),
            tabOn   = Color3.fromRGB(50, 20,  90),
            sep     = Color3.fromRGB(80, 30, 130),
            text    = Color3.fromRGB(230,210, 255),
            knobOn  = Color3.fromRGB(200,100, 255),
            bgKnob  = Color3.fromRGB(60, 20,  100),
        },
        {
            name    = "Transparent",
            icon    = "🌫",
            win     = Color3.fromRGB(10, 10,  10),
            tbar    = Color3.fromRGB(15, 15,  15),
            sidebar = Color3.fromRGB(12, 12,  12),
            content = Color3.fromRGB(8,   8,   8),
            row     = Color3.fromRGB(18, 18,  18),
            accent  = Color3.fromRGB(255,255, 255),
            stroke  = Color3.fromRGB(100,100, 100),
            tabOn   = Color3.fromRGB(40, 40,  40),
            sep     = Color3.fromRGB(50, 50,  50),
            text    = Color3.fromRGB(240,240, 240),
            knobOn  = Color3.fromRGB(255,255, 255),
            bgKnob  = Color3.fromRGB(60, 60,  60),
            winAlpha = 0.45, -- transparence
        },
        {
            name    = "Blood Red",
            icon    = "🔴",
            win     = Color3.fromRGB(18,  4,  4),
            tbar    = Color3.fromRGB(30,  8,  8),
            sidebar = Color3.fromRGB(22,  5,  5),
            content = Color3.fromRGB(14,  3,  3),
            row     = Color3.fromRGB(35, 10, 10),
            accent  = Color3.fromRGB(255, 50, 50),
            stroke  = Color3.fromRGB(180, 20, 20),
            tabOn   = Color3.fromRGB(70, 15, 15),
            sep     = Color3.fromRGB(100, 20, 20),
            text    = Color3.fromRGB(255,200, 200),
            knobOn  = Color3.fromRGB(255, 60, 60),
            bgKnob  = Color3.fromRGB(100, 15, 15),
        },
        {
            name    = "Ocean",
            icon    = "🔵",
            win     = Color3.fromRGB(4,  12,  22),
            tbar    = Color3.fromRGB(6,  18,  35),
            sidebar = Color3.fromRGB(5,  14,  28),
            content = Color3.fromRGB(3,  10,  18),
            row     = Color3.fromRGB(8,  20,  40),
            accent  = Color3.fromRGB(0, 180, 255),
            stroke  = Color3.fromRGB(0, 100, 200),
            tabOn   = Color3.fromRGB(10, 35,  70),
            sep     = Color3.fromRGB(0,  60, 120),
            text    = Color3.fromRGB(200,235, 255),
            knobOn  = Color3.fromRGB(0, 200, 255),
            bgKnob  = Color3.fromRGB(0,  50, 100),
        },
        {
            name    = "Matrix",
            icon    = "🟢",
            win     = Color3.fromRGB(2,  10,   2),
            tbar    = Color3.fromRGB(4,  18,   4),
            sidebar = Color3.fromRGB(3,  12,   3),
            content = Color3.fromRGB(2,   8,   2),
            row     = Color3.fromRGB(5,  20,   5),
            accent  = Color3.fromRGB(0, 255,  80),
            stroke  = Color3.fromRGB(0, 140,  40),
            tabOn   = Color3.fromRGB(5,  40,  10),
            sep     = Color3.fromRGB(0,  80,  20),
            text    = Color3.fromRGB(180,255, 200),
            knobOn  = Color3.fromRGB(0, 255,  80),
            bgKnob  = Color3.fromRGB(0,  60,  20),
        },
        {
            name    = "Sakura",
            icon    = "🌸",
            win     = Color3.fromRGB(22,  8,  16),
            tbar    = Color3.fromRGB(35, 12,  25),
            sidebar = Color3.fromRGB(28,  9,  20),
            content = Color3.fromRGB(18,  6,  13),
            row     = Color3.fromRGB(40, 14,  28),
            accent  = Color3.fromRGB(255,120, 180),
            stroke  = Color3.fromRGB(200, 60, 120),
            tabOn   = Color3.fromRGB(70, 20,  45),
            sep     = Color3.fromRGB(120, 30,  70),
            text    = Color3.fromRGB(255,210, 230),
            knobOn  = Color3.fromRGB(255,140, 190),
            bgKnob  = Color3.fromRGB(100, 30,  60),
        },
        {
            name    = "Gold",
            icon    = "✨",
            win     = Color3.fromRGB(18, 14,   2),
            tbar    = Color3.fromRGB(28, 22,   4),
            sidebar = Color3.fromRGB(22, 17,   3),
            content = Color3.fromRGB(14, 11,   2),
            row     = Color3.fromRGB(32, 25,   5),
            accent  = Color3.fromRGB(255,200,  20),
            stroke  = Color3.fromRGB(200,150,  10),
            tabOn   = Color3.fromRGB(60, 45,   8),
            sep     = Color3.fromRGB(120, 90,  10),
            text    = Color3.fromRGB(255,245, 200),
            knobOn  = Color3.fromRGB(255,210,  40),
            bgKnob  = Color3.fromRGB(90,  65,   8),
        },
    }

    -- Fonction d'application du thème
    local function applyTheme(t)
        -- Fenêtre principale
        WIN.BackgroundColor3  = t.win
        local winAlpha = t.winAlpha or 0
        WIN.BackgroundTransparency = winAlpha

        -- Titlebar
        TBAR.BackgroundColor3 = t.tbar
        for _, c in ipairs(TBAR:GetChildren()) do
            if c:IsA("Frame") and not c:IsA("TextButton") then
                c.BackgroundColor3 = t.tbar
            end
        end

        -- Stroke
        local stroke = WIN:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = t.stroke end

        -- Sidebar
        SIDEBAR.BackgroundColor3 = t.sidebar

        -- Content
        CONTENT.BackgroundColor3 = t.content

        -- Séparateur
        SEP.BackgroundColor3 = t.sep

        -- Logo dot
        logoDot.BackgroundColor3 = t.accent

        -- Tous les onglets tabs
        for name, tab in pairs(tabs) do
            tab.btn.TextColor3 = (name == activeTab) and t.accent or Color3.fromRGB(180,160,210)
            if name == activeTab then
                tab.btn.BackgroundColor3 = t.tabOn
                tab.btn.BackgroundTransparency = 0
            end
        end

        -- Tous les rows dans tous les scrollframes
        for _, tab in pairs(tabs) do
            for _, c in ipairs(tab.frame:GetDescendants()) do
                if c:IsA("Frame") and c.Name == "" then
                    -- rows de toggle/slider
                    if c.AbsoluteSize.Y <= 55 then
                        c.BackgroundColor3 = t.row
                    end
                end
                -- Accent color sur les toggles (knob actif) et sliders (fill)
                if c:IsA("Frame") and c.AbsoluteSize.Y <= 6 and c.AbsoluteSize.X > 20 then
                    -- piste slider fill
                    for _, cc in ipairs(c:GetChildren()) do
                        if cc:IsA("Frame") and cc.AbsoluteSize.Y <= 6 then
                            cc.BackgroundColor3 = t.accent
                        end
                    end
                end
                -- TextLabels accent
                if c:IsA("TextLabel") and c.TextColor3 == Color3.fromRGB(255,220,0) then
                    c.TextColor3 = t.accent
                end
            end
        end

        -- FOV Circle couleur accent
        FovCircle.Color = t.accent
        Cfg.ESP.Color   = t.accent
    end

    -- Grille de boutons thèmes
    local themeGrid = Instance.new("Frame", f)
    themeGrid.Size = UDim2.new(1,0,0,0)
    themeGrid.AutomaticSize = Enum.AutomaticSize.Y
    themeGrid.BackgroundTransparency = 1
    themeGrid.BorderSizePixel = 0

    local grid = Instance.new("UIGridLayout", themeGrid)
    grid.CellSize    = UDim2.new(0.5,-6,0,42)
    grid.CellPadding = UDim2.new(0,6,0,6)
    grid.FillDirectionMaxCells = 2

    for _, t in ipairs(Themes) do
        local thm = t  -- capture
        local btn2 = Instance.new("TextButton", themeGrid)
        btn2.Size              = UDim2.new(0,1,0,42)
        btn2.BackgroundColor3  = thm.win
        btn2.BorderSizePixel   = 0
        btn2.Text              = thm.icon .. "  " .. thm.name
        btn2.TextColor3        = thm.text or Color3.fromRGB(240,240,240)
        btn2.TextSize          = 12
        btn2.Font              = Enum.Font.GothamBold
        Instance.new("UICorner", btn2).CornerRadius = UDim.new(0,7)

        local btnStroke = Instance.new("UIStroke", btn2)
        btnStroke.Color     = thm.stroke
        btnStroke.Thickness = 1.2
        btnStroke.Transparency = 0.4

        btn2.MouseEnter:Connect(function()
            TweenService:Create(btnStroke, TweenInfo.new(0.1), {Transparency=0}):Play()
        end)
        btn2.MouseLeave:Connect(function()
            TweenService:Create(btnStroke, TweenInfo.new(0.1), {Transparency=0.4}):Play()
        end)
        btn2.MouseButton1Click:Connect(function()
            applyTheme(thm)
            -- Highlight bouton actif
            for _, b in ipairs(themeGrid:GetChildren()) do
                if b:IsA("TextButton") then
                    local s = b:FindFirstChildOfClass("UIStroke")
                    if s then s.Thickness = b == btn2 and 2 or 1.2 end
                end
            end
        end)
    end
end

-- ── INSERT key = toggle GUI ──
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end

    -- [Insert] toggle panel
    if i.KeyCode == Enum.KeyCode.Insert then
        WIN.Visible = not WIN.Visible
    end


end)

-- Activate default tab
activateTab("Legit")

print("✦ MIKU V2 chargé — Appuie sur [Insert] pour ouvrir/fermer ✦")
