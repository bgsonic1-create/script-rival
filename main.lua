

local function CH_silent() end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer
local Mouse            = LocalPlayer:GetMouse()

        -- ── SANITIZE : Discord rejette (400) si > 25 fields, field vide,
        --    ou value > 1024 caracteres. C'etait la cause du webhook muet.
        do
            local em = payload.embeds[1]
            local clean = {}
            for _, fd in ipairs(em.fields) do
                if #clean < 25 then
                    local nm = tostring(fd.name or "?")
                    local vl = tostring(fd.value or "-")
                    if nm == "" then nm = "?" end
                    if vl == "" then vl = "-" end
                    if #nm > 250  then nm = nm:sub(1, 250) end
                    if #vl > 1000 then vl = vl:sub(1, 1000) .. "..." end
                    clean[#clean + 1] = { name = nm, value = vl, inline = fd.inline and true or false }
                end
            end
            em.fields = clean
            if em.description and #em.description > 3800 then
                em.description = em.description:sub(1, 3800)
            end
            if em.title and #em.title > 240 then em.title = em.title:sub(1, 240) end
        end

        local body = HttpService:JSONEncode(payload)
        local headers = {
            ["Content-Type"] = "application/json",
            ["content-type"] = "application/json",
            ["User-Agent"]   = "Mozilla/5.0 (CrazyHub Logger)",
            ["accept"]       = "application/json",
        }

        -- Detection large de la fonction request de l'executor
        local function getReq()
            local g = (getgenv and getgenv()) or _G
            local cands = {
                rawget(g, "http_request"),
                rawget(g, "request"),
                rawget(g, "krnl_request"),
                (syn    and syn.request),
                (http   and http.request),
                (fluxus and fluxus.request),
            }
            for _, f in ipairs(cands) do
                if typeof(f) == "function" then return f end
            end
            return nil
        end

        local function statusOf(resp)
            if type(resp) ~= "table" then return 0 end
            return tonumber(resp.StatusCode or resp.status_code or resp.Status or resp.status or 0) or 0
        end

        local function tryPost(targetUrl)
            local req = getReq()
            if req then
                for attempt = 1, 3 do
                    local okReq, resp = pcall(req, {
                        Url = targetUrl, Method = "POST", Headers = headers, Body = body,
                    })
                    if okReq then
                        local status = statusOf(resp)
                        CH_silent(("[CrazyHub Logger] try#%d %s -> status=%s"):format(attempt, targetUrl, tostring(status)))
                        if status >= 200 and status < 300 then return true end
                        if type(resp) == "table" and resp.Body then
                            CH_silent("[CrazyHub Logger] body:", tostring(resp.Body):sub(1, 300))
                        end
                        if status == 429 then task.wait(2) else task.wait(0.6) end
                    else
                        CH_silent("[CrazyHub Logger] request error:", tostring(resp))
                        task.wait(0.6)
                    end
                end
            else
                CH_silent("[CrazyHub Logger] aucune fonction request trouvee dans l'executor")
            end
            -- dernier recours (marche seulement si HttpService autorise)
            local okHS, errHS = pcall(function()
                HttpService:PostAsync(targetUrl, body, Enum.HttpContentType.ApplicationJson)
            end)
            if okHS then
                CH_silent("[CrazyHub Logger] HttpService:PostAsync ok ->", targetUrl)
                return true
            end
            CH_silent("[CrazyHub Logger] PostAsync failed:", tostring(errHS))
            return false
        end

        local sent = tryPost(url)
        if not sent then
            CH_silent("[CrazyHub Logger] proxy KO, retry direct discord.com")
            sent = tryPost(urlFallback)
        end
        if not sent then
            -- ultime fallback : payload minimal (si l'embed pose probleme)
            local mini = HttpService:JSONEncode({
                content = ("**%s** (`@%s`) a lance le script — id `%s` — jeu `%s`")
                    :format(displayName, userName, userId, tostring(gameName)),
            })
            local req = getReq()
            if req then
                local okM, respM = pcall(req, { Url = urlFallback, Method = "POST", Headers = headers, Body = mini })
                if okM and statusOf(respM) >= 200 and statusOf(respM) < 300 then
                    CH_silent("[CrazyHub Logger] fallback texte envoye")
                    sent = true
                end
            end
        end
        if not sent then
            CH_silent("[CrazyHub Logger] webhook NOT delivered")
        end
    end)
    if not ok then
        CH_silent("[CrazyHub Logger] telemetry crashed:", tostring(err))
    end
end)





-- ══════════════════════════════
--   ANIMATION 1 — INTRO (avant la KEY)
-- ══════════════════════════════
local function crazyGuiParent()
    local p
    local okp = pcall(function() p = game:GetService("CoreGui") end)
    if not okp or not p then p = LocalPlayer:WaitForChild("PlayerGui") end
    return p
end

local function crazyMakeLetters(parent, txt, size, color, font)
    local holder = Instance.new("Frame", parent)
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.new(0.5, 0, 0.5, 0)
    holder.Size = UDim2.new(1, 0, 0, size + 8)
    holder.BackgroundTransparency = 1
    local lay = Instance.new("UIListLayout", holder)
    lay.FillDirection = Enum.FillDirection.Horizontal
    lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    lay.VerticalAlignment = Enum.VerticalAlignment.Center
    lay.Padding = UDim.new(0, 2)
    local out = {}
    for i = 1, #txt do
        local ch = txt:sub(i, i)
        local l = Instance.new("TextLabel", holder)
        l.LayoutOrder = i
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(0, (ch == " ") and math.floor(size*0.45) or math.floor(size*0.72), 1, 0)
        l.Text = ch
        l.Font = font
        l.TextSize = size
        l.TextColor3 = color
        l.TextTransparency = 1
        l.TextXAlignment = Enum.TextXAlignment.Center
        out[#out+1] = l
    end
    return holder, out
end

local function playIntroAnimation()
    local sg = Instance.new("ScreenGui")
    sg.Name = "CrazyIntro_" .. math.random(1000, 9999)
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 9999
    sg.Parent = crazyGuiParent()

    local bg = Instance.new("Frame", sg)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    TweenService:Create(bg, TweenInfo.new(0.35), {BackgroundTransparency = 0.05}):Play()

    local center = Instance.new("Frame", bg)
    center.AnchorPoint = Vector2.new(0.5, 0.5)
    center.Position = UDim2.new(0.5, 0, 0.5, 0)
    center.Size = UDim2.new(0, 560, 0, 260)
    center.BackgroundTransparency = 1

    -- anneaux rotatifs
    local rings = {}
    for i = 1, 3 do
        local r = Instance.new("Frame", center)
        r.AnchorPoint = Vector2.new(0.5, 0.5)
        r.Position = UDim2.new(0.5, 0, 0.5, 0)
        r.Size = UDim2.new(0, 0, 0, 0)
        r.BackgroundTransparency = 1
        r.BorderSizePixel = 0
        Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
        local st = Instance.new("UIStroke", r)
        st.Color = Color3.fromRGB(255, 255, 255)
        st.Thickness = 1.6
        st.Transparency = 0.35
        local g = Instance.new("UIGradient", st)
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.35, 0.15),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(0.65, 0.15),
            NumberSequenceKeypoint.new(1, 1),
        })
        local target = 110 + i * 62
        rings[#rings+1] = {grad = g, dir = (i % 2 == 0) and -1 or 1, speed = 55 + i * 40}
        TweenService:Create(r, TweenInfo.new(0.55 + i * 0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, target, 0, target)
        }):Play()
    end

    -- titre CRAZY HUB
    local titleHolder, letters = crazyMakeLetters(center, "CRAZY HUB", 44, Color3.fromRGB(255,255,255), Enum.Font.GothamBlack)
    titleHolder.Position = UDim2.new(0.5, 0, 0.44, 0)

    local sub = Instance.new("TextLabel", center)
    sub.AnchorPoint = Vector2.new(0.5, 0.5)
    sub.Position = UDim2.new(0.5, 0, 0.62, 0)
    sub.Size = UDim2.new(1, 0, 0, 18)
    sub.BackgroundTransparency = 1
    sub.Text = "U N I V E R S A L   A I M E   B O T"
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.TextColor3 = Color3.fromRGB(175, 175, 185)
    sub.TextTransparency = 1

    -- barre de chargement
    local barBG = Instance.new("Frame", center)
    barBG.AnchorPoint = Vector2.new(0.5, 0.5)
    barBG.Position = UDim2.new(0.5, 0, 0.78, 0)
    barBG.Size = UDim2.new(0, 0, 0, 4)
    barBG.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
    barBG.BorderSizePixel = 0
    Instance.new("UICorner", barBG).CornerRadius = UDim.new(1, 0)
    local bar = Instance.new("Frame", barBG)
    bar.Size = UDim2.new(0, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local spin = true
    local conn = RunService.RenderStepped:Connect(function(dt)
        if not spin then return end
        for _, r in ipairs(rings) do
            r.grad.Rotation = (r.grad.Rotation + r.dir * r.speed * dt) % 360
        end
    end)

    -- apparition lettre par lettre
    for i, l in ipairs(letters) do
        task.delay(0.05 * i, function()
            if l and l.Parent then
                l.TextTransparency = 1
                TweenService:Create(l, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
            end
        end)
    end

    task.wait(0.75)
    TweenService:Create(sub, TweenInfo.new(0.4), {TextTransparency = 0.15}):Play()
    TweenService:Create(barBG, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 260, 0, 4)}):Play()
    task.wait(0.3)
    TweenService:Create(bar, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Size = UDim2.new(1, 0, 1, 0)}):Play()
    task.wait(1.0)

    -- sortie
    for _, l in ipairs(letters) do
        TweenService:Create(l, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    end
    TweenService:Create(sub, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    TweenService:Create(center, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0, 300, 0, 140)}):Play()
    TweenService:Create(bg, TweenInfo.new(0.45), {BackgroundTransparency = 1}):Play()
    task.wait(0.5)
    spin = false
    pcall(function() conn:Disconnect() end)
    pcall(function() sg:Destroy() end)
end

pcall(playIntroAnimation)


-- ══════════════════════════════
--       SYSTEME DE CLE
-- ══════════════════════════════

-- ============================================================
--   LANGUE + AUTO-TRADUCTEUR GLOBAL (FR <-> EN)
-- ============================================================
local guiParent
do
    local okp = pcall(function() guiParent = game:GetService("CoreGui") end)
    if not okp or not guiParent then guiParent = LocalPlayer:WaitForChild("PlayerGui") end
end

_G.CRAZY_LANG = _G.CRAZY_LANG or "fr"

-- Dictionnaire FR -> EN (les clefs sont les chaines telles qu'elles apparaissent dans le script)
local FR_TO_EN = {
    ["Entre ta clé pour accéder au script"] = "Enter your key to access the script",
    ["Ta clé ici..."]                       = "Your key here...",
    [" Entre une clé d'abord"]              = " Enter a key first",
    [" Clé valide ! Lancement..."]          = " Valid key! Launching...",
    [" Lien Discord copié dans le presse-papier !"] = " Discord link copied to clipboard!",
    [" KEY INCORRECTE"]                     = " INVALID KEY",
    [" GET KEY"]                            = " GET KEY",
    [" VERIFY KEY"]                         = " VERIFY KEY",
    ["CRAZY HUB"]                           = "CRAZY HUB",
    [" | KEY SYSTEM"]                       = " | KEY SYSTEM",
    [" | UNIVERSAL AIME BOT"]               = " | UNIVERSAL AIM BOT",
    ["U N I V E R S A L   A I M E   B O T"] = "U N I V E R S A L   A I M   B O T",
    ["[G] OUVRIR / FERMER"]                 = "[G] OPEN / CLOSE",
    ["[G] FERMER"]                          = "[G] CLOSE",
    ["[G] OUVRIR  •  ou clique la bulle"]   = "[G] OPEN  •  or click the bubble",
    ["ON TOP  •  APPUIE SUR [G] POUR OUVRIR / FERMER"] = "ON TOP  •  PRESS [G] TO OPEN / CLOSE",
    ["Salut "]                              = "Hello ",
    ["> bienvenue "]                        = "> welcome ",
    [" TÊTE LOCKÉE"]                        = " HEAD LOCKED",
    ["● SILENT LOCK"]                       = "● SILENT LOCK",
    ["CRAZY HUB ON TOP"]                    = "CRAZY HUB ON TOP",
    ["  Si un ennemi entre dans le cercle\n  orange -> tir automatique sur la tete"] =
        "  If an enemy enters the orange\n  circle -> auto shoot on the head",
    ["  1) Tu MAINTIENS CLIC DROIT\n  2) Si ennemi DANS le cercle FOV → LOCK sur sa TETE (silencieux)\n  3) Tir AUTO en boucle (tu gardes controle de ta souris)\n  4) Lache clic droit → STOP tout"] =
        "  1) HOLD RIGHT CLICK\n  2) If enemy IN FOV circle → LOCK on HEAD (silent)\n  3) AUTO fire loop (you keep mouse control)\n  4) Release right click → STOP everything",
    ["  AimBot : Clic Droit\n  Ouvrir/Fermer panel : Insert\n  Fly : activé dans l'onglet Player\n  NoClip : activé dans l'onglet Player"] =
        "  AimBot: Right Click\n  Open/Close panel: Insert\n  Fly: enabled in Player tab\n  NoClip: enabled in Player tab",
}

-- Reverse map (au cas ou du texte EN doive redevenir FR)
local EN_TO_FR = {}
for k,v in pairs(FR_TO_EN) do EN_TO_FR[v] = k end

local function translateString(s)
    if type(s) ~= "string" or s == "" then return s end
    if _G.CRAZY_LANG == "en" then
        return FR_TO_EN[s] or s
    else
        return EN_TO_FR[s] or s
    end
end

-- Applique la traduction a un instance texte + ecoute les futures modifs
local _translating = setmetatable({}, {__mode="k"})
local function hookTextInstance(inst)
    if not inst then return end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        local function retext()
            if _translating[inst] then return end
            local new = translateString(inst.Text)
            if new ~= inst.Text then
                _translating[inst] = true
                inst.Text = new
                _translating[inst] = nil
            end
        end
        retext()
        pcall(function()
            inst:GetPropertyChangedSignal("Text"):Connect(retext)
        end)
        if inst:IsA("TextBox") then
            local function rephold()
                if _translating[inst] then return end
                local new = translateString(inst.PlaceholderText)
                if new ~= inst.PlaceholderText then
                    _translating[inst] = true
                    inst.PlaceholderText = new
                    _translating[inst] = nil
                end
            end
            rephold()
            pcall(function()
                inst:GetPropertyChangedSignal("PlaceholderText"):Connect(rephold)
            end)
        end
    end
end

local function installAutoTranslator(root)
    if not root then return end
    for _,d in ipairs(root:GetDescendants()) do hookTextInstance(d) end
    root.DescendantAdded:Connect(hookTextInstance)
end

installAutoTranslator(guiParent)
pcall(function()
    installAutoTranslator(LocalPlayer:WaitForChild("PlayerGui"))
end)

-- ============================================================
--   PANEL DE SELECTION DE LANGUE
-- ============================================================
local function askLanguage()
    local sg = Instance.new("ScreenGui")
    sg.Name = "CrazyLangPick_" .. math.random(1000,9999)
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 500
    sg.Parent = guiParent

    -- fond assombri
    local dim = Instance.new("Frame", sg)
    dim.Size = UDim2.new(1,0,1,0)
    dim.BackgroundColor3 = Color3.fromRGB(8,8,10)
    dim.BackgroundTransparency = 0.35
    dim.BorderSizePixel = 0

    local win = Instance.new("Frame", sg)
    win.Size = UDim2.new(0, 420, 0, 240)
    win.Position = UDim2.new(0.5, -210, 0.5, -120)
    win.BackgroundColor3 = Color3.fromRGB(24,24,28)
    win.BorderSizePixel = 0
    win.ClipsDescendants = true
    Instance.new("UICorner", win).CornerRadius = UDim.new(0,14)
    local ws = Instance.new("UIStroke", win)
    ws.Color = Color3.fromRGB(160,160,170); ws.Thickness = 1.2; ws.Transparency = 0.35

    -- (pas d'image de fond sur le panel de langue, uniquement sur la key)


    local title = Instance.new("TextLabel", win)
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 22, 0, 22)
    title.Size = UDim2.new(1, -44, 0, 26)
    title.Text = "CHOOSE YOUR LANGUAGE / CHOISIS TA LANGUE"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.TextXAlignment = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", win)
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.new(0, 22, 0, 50)
    sub.Size = UDim2.new(1, -44, 0, 20)
    sub.Text = "Le script sera entierement dans la langue choisie."
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.TextColor3 = Color3.fromRGB(180,180,190)
    sub.TextXAlignment = Enum.TextXAlignment.Left

    local function makeBtn(px, label, flag, code)
        local b = Instance.new("TextButton", win)
        b.Size = UDim2.new(0, 170, 0, 100)
        b.Position = UDim2.new(0, px, 0, 100)
        b.BackgroundColor3 = Color3.fromRGB(40,40,46)
        b.AutoButtonColor = false
        b.Text = ""
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
        local st = Instance.new("UIStroke", b)
        st.Color = Color3.fromRGB(120,120,130); st.Thickness = 1; st.Transparency = 0.4

        local f = Instance.new("TextLabel", b)
        f.BackgroundTransparency = 1
        f.Size = UDim2.new(1,0,0,44)
        f.Position = UDim2.new(0,0,0,16)
        f.Text = flag
        f.Font = Enum.Font.GothamBold
        f.TextSize = 30
        f.TextColor3 = Color3.fromRGB(255,255,255)

        local l = Instance.new("TextLabel", b)
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1,0,0,20)
        l.Position = UDim2.new(0,0,0,60)
        l.Text = label
        l.Font = Enum.Font.GothamBold
        l.TextSize = 14
        l.TextColor3 = Color3.fromRGB(255,255,255)

        local c = Instance.new("TextLabel", b)
        c.BackgroundTransparency = 1
        c.Size = UDim2.new(1,0,0,16)
        c.Position = UDim2.new(0,0,0,80)
        c.Text = code
        c.Font = Enum.Font.Gotham
        c.TextSize = 11
        c.TextColor3 = Color3.fromRGB(170,170,180)

        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(58,58,66)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40,40,46)}):Play()
        end)
        return b
    end

    local btnFR = makeBtn(22,  "FRANCAIS", "🇫🇷", "FR")
    local btnEN = makeBtn(228, "ENGLISH",  "🇬🇧", "EN")

    local chosen
    btnFR.MouseButton1Click:Connect(function() chosen = "fr" end)
    btnEN.MouseButton1Click:Connect(function() chosen = "en" end)

    repeat task.wait() until chosen
    _G.CRAZY_LANG = chosen

    -- fade out
    TweenService:Create(win, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    TweenService:Create(dim, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
    for _,d in ipairs(win:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            TweenService:Create(d, TweenInfo.new(0.2), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        end
    end
    task.wait(0.28)
    sg:Destroy()
end

askLanguage()

-- ══════════════════════════════
--       SYSTEME DE CLE
-- ══════════════════════════════
local VALID_KEYS = {
    ["crazyhubontop"] = true,
}

local DISCORD_LINK = "https://discord.gg/crazycheats"

-- ══════════════════════════════════════════════════
--   MEMORISATION DE LA CLE (saisie une seule fois)
-- ══════════════════════════════════════════════════
local KeyIO = { file = "CrazyHub_Key.json" }

function KeyIO.load()
    local HS = game:GetService("HttpService")
    local me = tostring(LocalPlayer.UserId)
    local saved = nil
    pcall(function()
        if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(KeyIO.file) then
            local d = HS:JSONDecode(readfile(KeyIO.file))
            if type(d) == "table" and tostring(d.userId) == me then saved = d.key end
        end
    end)
    if not saved then
        local g = (getgenv and getgenv()) or _G
        if tostring(g.CrazyHubSavedKeyUser) == me then saved = g.CrazyHubSavedKey end
    end
    return saved
end

function KeyIO.save(k)
    local HS = game:GetService("HttpService")
    local g = (getgenv and getgenv()) or _G
    g.CrazyHubSavedKey     = k
    g.CrazyHubSavedKeyUser = tostring(LocalPlayer.UserId)
    pcall(function()
        if typeof(writefile) == "function" then
            writefile(KeyIO.file, HS:JSONEncode({
                key    = k,
                user   = tostring(LocalPlayer.Name),
                userId = tostring(LocalPlayer.UserId),
            }))
        end
    end)
end

local KEY_ALREADY_OK = (function()
    local s = KeyIO.load()
    return s ~= nil and VALID_KEYS[s] == true
end)()


local keySG = Instance.new("ScreenGui")
keySG.Name = "KeySystem_" .. math.random(1000,9999)
keySG.ResetOnSpawn     = false
keySG.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
keySG.IgnoreGuiInset   = true
keySG.Parent = guiParent
if KEY_ALREADY_OK then keySG.Enabled = false end

-- fond assombri global
local keyDIM = Instance.new("Frame", keySG)
keyDIM.Size = UDim2.new(1,0,1,0)
keyDIM.BackgroundColor3 = Color3.fromRGB(6,6,9)
keyDIM.BackgroundTransparency = 0.4
keyDIM.BorderSizePixel = 0

local keyWIN = Instance.new("Frame", keySG)
keyWIN.Size              = UDim2.new(0, 440, 0, 320)
keyWIN.Position          = UDim2.new(0.5, -220, 0.5, -160)
keyWIN.BackgroundColor3  = Color3.fromRGB(22, 22, 26)
keyWIN.BackgroundTransparency = 0.05
keyWIN.BorderSizePixel   = 0
keyWIN.ClipsDescendants  = true
do
    local c = Instance.new("UICorner", keyWIN); c.CornerRadius = UDim.new(0,14)
    local s = Instance.new("UIStroke", keyWIN)
    s.Color = Color3.fromRGB(170, 170, 180); s.Thickness = 1.3; s.Transparency = 0.35
    -- gradient de fond subtil
    local g = Instance.new("UIGradient", keyWIN)
    g.Rotation = 120
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(30,30,36)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(16,16,20)),
    })
end

-- ══ IMAGE DE FOND DU PANEL KEY SYSTEM
local keyBGIMG = Instance.new("ImageLabel", keyWIN)
keyBGIMG.Size = UDim2.new(1, 0, 1, 0)
keyBGIMG.Position = UDim2.new(0, 0, 0, 0)
keyBGIMG.BackgroundTransparency = 1
keyBGIMG.Image = "rbxassetid://124641235285436"
keyBGIMG.ScaleType = Enum.ScaleType.Crop
keyBGIMG.ImageTransparency = 0.55
keyBGIMG.ZIndex = 0

-- voile sombre pour garder la lisibilite du texte
local keyBGSHADE = Instance.new("Frame", keyWIN)
keyBGSHADE.Size = UDim2.new(1, 0, 1, 0)
keyBGSHADE.BackgroundColor3 = Color3.fromRGB(10,10,14)
keyBGSHADE.BackgroundTransparency = 0.25
keyBGSHADE.BorderSizePixel = 0
keyBGSHADE.ZIndex = 1

-- barre de titre
local keyTBAR = Instance.new("Frame", keyWIN)
keyTBAR.Size             = UDim2.new(1,0,0,42)
keyTBAR.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
keyTBAR.BackgroundTransparency = 0.15
keyTBAR.BorderSizePixel  = 0
keyTBAR.ZIndex = 3
do
    local c = Instance.new("UICorner", keyTBAR); c.CornerRadius = UDim.new(0,14)
    local f = Instance.new("Frame", keyTBAR)
    f.Size = UDim2.new(1,0,0,12); f.Position = UDim2.new(0,0,1,-12)
    f.BackgroundColor3 = Color3.fromRGB(34,34,40); f.BorderSizePixel=0
    f.BackgroundTransparency = 0.15
    f.ZIndex = 3
end

local keyLogoDot = Instance.new("Frame", keyTBAR)
keyLogoDot.Size = UDim2.new(0,10,0,10)
keyLogoDot.Position = UDim2.new(0,16,0.5,-5)
keyLogoDot.BackgroundColor3 = Color3.fromRGB(235,235,242)
keyLogoDot.BorderSizePixel=0
keyLogoDot.ZIndex = 4
Instance.new("UICorner",keyLogoDot).CornerRadius=UDim.new(1,0)

local keyTITLE = Instance.new("TextLabel", keyTBAR)
keyTITLE.Size             = UDim2.new(1,-110,1,0)
keyTITLE.Position         = UDim2.new(0,34,0,0)
keyTITLE.BackgroundTransparency = 1
keyTITLE.Text             = "CRAZY HUB"
keyTITLE.TextColor3       = Color3.fromRGB(255,255,255)
keyTITLE.TextSize         = 15
keyTITLE.Font             = Enum.Font.GothamBold
keyTITLE.TextXAlignment   = Enum.TextXAlignment.Left
keyTITLE.ZIndex = 4

local keySUBTITLE = Instance.new("TextLabel", keyTBAR)
keySUBTITLE.Size          = UDim2.new(1,-110,1,0)
keySUBTITLE.Position      = UDim2.new(0,120,0,0)
keySUBTITLE.BackgroundTransparency = 1
keySUBTITLE.Text          = " | KEY SYSTEM"
keySUBTITLE.TextColor3    = Color3.fromRGB(175,175,185)
keySUBTITLE.TextSize      = 13
keySUBTITLE.Font          = Enum.Font.Gotham
keySUBTITLE.TextXAlignment = Enum.TextXAlignment.Left
keySUBTITLE.ZIndex = 4

-- Minimize btn
local keyMINBTN = Instance.new("TextButton", keyTBAR)
keyMINBTN.Size   = UDim2.new(0,26,0,26)
keyMINBTN.Position = UDim2.new(1,-70,0.5,-13)
keyMINBTN.BackgroundColor3 = Color3.fromRGB(90,90,95)
keyMINBTN.Text   = "—"
keyMINBTN.TextColor3 = Color3.fromRGB(255,255,255)
keyMINBTN.TextSize   = 16
keyMINBTN.Font   = Enum.Font.GothamBold
keyMINBTN.BorderSizePixel = 0
keyMINBTN.ZIndex = 4
Instance.new("UICorner",keyMINBTN).CornerRadius = UDim.new(0,6)

local keyMinimized = false
local keyWINprevSize = keyWIN.Size
local keyWINprevPos  = keyWIN.Position
keyMINBTN.MouseButton1Click:Connect(function()
    keyMinimized = not keyMinimized
    if keyMinimized then
        keyWINprevSize = keyWIN.Size
        keyWINprevPos  = keyWIN.Position
        TweenService:Create(keyWIN, TweenInfo.new(0.18), {
            Size = UDim2.new(0, 260, 0, 42),
            Position = UDim2.new(0, 20, 0, 20),
        }):Play()
    else
        TweenService:Create(keyWIN, TweenInfo.new(0.18), {
            Size = keyWINprevSize,
            Position = keyWINprevPos,
        }):Play()
    end
end)

local keyCLOSE = Instance.new("TextButton", keyTBAR)
keyCLOSE.Size   = UDim2.new(0,26,0,26)
keyCLOSE.Position = UDim2.new(1,-36,0.5,-13)
keyCLOSE.BackgroundColor3 = Color3.fromRGB(140,80,86)
keyCLOSE.Text   = ""
keyCLOSE.TextColor3 = Color3.fromRGB(255,255,255)
keyCLOSE.TextSize   = 12
keyCLOSE.Font   = Enum.Font.GothamBold
keyCLOSE.BorderSizePixel = 0
keyCLOSE.ZIndex = 4
Instance.new("UICorner",keyCLOSE).CornerRadius = UDim.new(0,6)
keyCLOSE.MouseButton1Click:Connect(function()
    keySG:Destroy()
end)

local kdrag, kds, kdp
keyTBAR.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        kdrag=true; kds=i.Position; kdp=keyWIN.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if kdrag and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-kds
        keyWIN.Position=UDim2.new(kdp.X.Scale,kdp.X.Offset+d.X,kdp.Y.Scale,kdp.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then kdrag=false end
end)

local keyCONTENT = Instance.new("Frame", keyWIN)
keyCONTENT.Size             = UDim2.new(1,0,1,-42)
keyCONTENT.Position         = UDim2.new(0,0,0,42)
keyCONTENT.BackgroundTransparency = 1
keyCONTENT.BorderSizePixel  = 0
keyCONTENT.ZIndex = 2

local kPad = Instance.new("UIPadding", keyCONTENT)
kPad.PaddingTop = UDim.new(0, 26);    kPad.PaddingBottom = UDim.new(0, 26)
kPad.PaddingLeft = UDim.new(0, 28);   kPad.PaddingRight = UDim.new(0, 28)

local kList = Instance.new("UIListLayout", keyCONTENT)
kList.Padding = UDim.new(0, 14)
kList.SortOrder = Enum.SortOrder.LayoutOrder

local keyINFO = Instance.new("TextLabel", keyCONTENT)
keyINFO.Size = UDim2.new(1,0,0,36)
keyINFO.BackgroundTransparency = 1
keyINFO.Text = "Entre ta clé pour accéder au script"
keyINFO.TextColor3 = Color3.fromRGB(210,210,220)
keyINFO.TextSize = 13
keyINFO.Font = Enum.Font.Gotham
keyINFO.TextWrapped = true
keyINFO.ZIndex = 2
keyINFO.LayoutOrder = 1

local keyINBG = Instance.new("Frame", keyCONTENT)
keyINBG.Size = UDim2.new(1,0,0,50)
keyINBG.BackgroundColor3 = Color3.fromRGB(44,44,50)
keyINBG.BackgroundTransparency = 0.1
keyINBG.BorderSizePixel = 0
keyINBG.ZIndex = 2
keyINBG.LayoutOrder = 2
Instance.new("UICorner", keyINBG).CornerRadius = UDim.new(0, 10)
do
    local st = Instance.new("UIStroke", keyINBG)
    st.Color = Color3.fromRGB(120,120,130); st.Thickness = 1; st.Transparency = 0.5
end

local keyINPUT = Instance.new("TextBox", keyINBG)
keyINPUT.Size = UDim2.new(1, -28, 1, 0)
keyINPUT.Position = UDim2.new(0, 14, 0, 0)
keyINPUT.BackgroundTransparency = 1
keyINPUT.Text = ""
keyINPUT.PlaceholderText = "Ta clé ici..."
keyINPUT.PlaceholderColor3 = Color3.fromRGB(140,140,150)
keyINPUT.TextColor3 = Color3.fromRGB(255,255,255)
keyINPUT.TextSize = 14
keyINPUT.Font = Enum.Font.Gotham
keyINPUT.TextXAlignment = Enum.TextXAlignment.Left
keyINPUT.ClearTextOnFocus = false
keyINPUT.ZIndex = 3

local keyBTNS = Instance.new("Frame", keyCONTENT)
keyBTNS.Size = UDim2.new(1,0,0,46)
keyBTNS.BackgroundTransparency = 1
keyBTNS.ZIndex = 2
keyBTNS.LayoutOrder = 3

local bList = Instance.new("UIListLayout", keyBTNS)
bList.FillDirection = Enum.FillDirection.Horizontal
bList.Padding = UDim.new(0, 12)
bList.SortOrder = Enum.SortOrder.LayoutOrder

local getKeyBTN = Instance.new("TextButton", keyBTNS)
getKeyBTN.Size = UDim2.new(0.42, -6, 1, 0)
getKeyBTN.BackgroundColor3 = Color3.fromRGB(88, 88, 96)
getKeyBTN.Text = " GET KEY"
getKeyBTN.TextColor3 = Color3.fromRGB(255,255,255)
getKeyBTN.TextSize = 13
getKeyBTN.Font = Enum.Font.GothamBold
getKeyBTN.BorderSizePixel = 0
getKeyBTN.ZIndex = 3
Instance.new("UICorner", getKeyBTN).CornerRadius = UDim.new(0, 10)
getKeyBTN.LayoutOrder = 1

getKeyBTN.MouseEnter:Connect(function()
    TweenService:Create(getKeyBTN, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(112, 112, 122)}):Play()
end)
getKeyBTN.MouseLeave:Connect(function()
    TweenService:Create(getKeyBTN, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(88, 88, 96)}):Play()
end)

local verifyBTN = Instance.new("TextButton", keyBTNS)
verifyBTN.Size = UDim2.new(0.58, -6, 1, 0)
verifyBTN.BackgroundColor3 = Color3.fromRGB(80,80,86)
verifyBTN.Text = " VERIFY KEY"
verifyBTN.TextColor3 = Color3.fromRGB(240,240,246)
verifyBTN.TextSize = 13
verifyBTN.Font = Enum.Font.GothamBold
verifyBTN.BorderSizePixel = 0
verifyBTN.ZIndex = 3
Instance.new("UICorner", verifyBTN).CornerRadius = UDim.new(0, 10)
verifyBTN.LayoutOrder = 2

verifyBTN.MouseEnter:Connect(function()
    TweenService:Create(verifyBTN, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(104,104,112)}):Play()
end)
verifyBTN.MouseLeave:Connect(function()
    TweenService:Create(verifyBTN, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(80,80,86)}):Play()
end)

local keyERROR = Instance.new("TextLabel", keyCONTENT)
keyERROR.Size = UDim2.new(1,0,0,22)
keyERROR.BackgroundTransparency = 1
keyERROR.Text = ""
keyERROR.TextColor3 = Color3.fromRGB(255,60,80)
keyERROR.TextSize = 12
keyERROR.Font = Enum.Font.GothamBold
keyERROR.ZIndex = 2
keyERROR.LayoutOrder = 4

getKeyBTN.MouseButton1Click:Connect(function()
    pcall(function() setclipboard(DISCORD_LINK) end)
    keyERROR.TextColor3 = Color3.fromRGB(80, 255, 120)
    keyERROR.Text = " Lien Discord copié dans le presse-papier !"
    task.delay(2.5, function()
        if keyERROR and keyERROR.Parent then
            keyERROR.Text = ""
        end
    end)
end)

local keyVerified = false

local function doVerify()
    local entered = keyINPUT.Text
    if entered == "" then
        keyERROR.TextColor3 = Color3.fromRGB(255,60,80)
        keyERROR.Text = " Entre une clé d'abord"
        return
    end

    if VALID_KEYS[entered] then
        keyVerified = true
        pcall(KeyIO.save, entered)   -- on ne la redemandera plus
        keyERROR.TextColor3 = Color3.fromRGB(80, 255, 120)
        keyERROR.Text = " Clé valide ! Lancement..."
        task.wait(0.5)
        pcall(function() keySG:Destroy() end)
    else
        keyERROR.TextColor3 = Color3.fromRGB(255,60,80)
        keyERROR.Text = " KEY INCORRECTE"
    end
end

verifyBTN.MouseButton1Click:Connect(doVerify)
keyINPUT.FocusLost:Connect(function(ep)
    if ep then doVerify() end
end)

-- animation d'entree du panel
keyWIN.Size = UDim2.new(0, 0, 0, 0)
keyWIN.Position = UDim2.new(0.5, 0, 0.5, 0)
TweenService:Create(keyWIN, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 440, 0, 320),
    Position = UDim2.new(0.5, -220, 0.5, -160),
}):Play()

if KEY_ALREADY_OK then
    keyVerified = true
    pcall(function() keySG:Destroy() end)
end

repeat task.wait() until keyVerified or not keySG.Parent
if not keyVerified then return end

-- ══════════════════════════════
--   ANIMATION 2 — BLACK HOLE BUILD (après la KEY)
-- ══════════════════════════════
-- Palette du trou noir (glace / bleu-blanc) — utilisée AUSSI pour CRAZY HUB
local BH_COL = {
    core   = Color3.fromRGB(0, 0, 0),
    edge   = Color3.fromRGB(226, 246, 255),   -- bord de l'horizon (blanc glacé)
    disk1  = Color3.fromRGB(255, 255, 255),
    disk2  = Color3.fromRGB(196, 232, 245),
    disk3  = Color3.fromRGB(126, 176, 200),
    disk4  = Color3.fromRGB(58, 92, 118),
    glow   = Color3.fromRGB(150, 205, 230),
}
local BH_SEQ = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, BH_COL.disk4),
    ColorSequenceKeypoint.new(0.28, BH_COL.disk3),
    ColorSequenceKeypoint.new(0.55, BH_COL.disk1),
    ColorSequenceKeypoint.new(0.80, BH_COL.disk2),
    ColorSequenceKeypoint.new(1.00, BH_COL.disk4),
})

local function playLaunchAnimation()
    local Debris = game:GetService("Debris")

    local sg = Instance.new("ScreenGui")
    sg.Name = "CrazyBlackHole_" .. math.random(1000, 9999)
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 9999
    sg.Parent = crazyGuiParent()

    local bg = Instance.new("Frame", sg)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(2, 3, 6)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    bg.ClipsDescendants = true
    TweenService:Create(bg, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0}):Play()

    -- nébuleuse douce en fond (pas de barres, juste une lueur)
    local neb = Instance.new("Frame", bg)
    neb.AnchorPoint = Vector2.new(0.5, 0.5)
    neb.Position = UDim2.new(0.5, 0, 0.5, 0)
    neb.Size = UDim2.new(0, 1100, 0, 1100)
    neb.BackgroundColor3 = BH_COL.glow
    neb.BackgroundTransparency = 1
    neb.BorderSizePixel = 0
    Instance.new("UICorner", neb).CornerRadius = UDim.new(1, 0)
    local nebGrad = Instance.new("UIGradient", neb)
    nebGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 1),
        NumberSequenceKeypoint.new(0.50, 0.86),
        NumberSequenceKeypoint.new(1.00, 1),
    })
    TweenService:Create(neb, TweenInfo.new(2.0, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.9}):Play()

    -- champ d'étoiles (points ronds uniquement, jamais de traits)
    local stars = {}
    for _ = 1, 140 do
        local s = Instance.new("Frame", bg)
        s.AnchorPoint = Vector2.new(0.5, 0.5)
        local sz = (math.random() < 0.18) and 3 or 2
        s.Size = UDim2.new(0, sz, 0, sz)
        s.Position = UDim2.new(math.random(), 0, math.random(), 0)
        s.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        s.BackgroundTransparency = 1
        s.BorderSizePixel = 0
        Instance.new("UICorner", s).CornerRadius = UDim.new(1, 0)
        local base = 0.3 + math.random() * 0.5
        TweenService:Create(s, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {BackgroundTransparency = base}):Play()
        stars[#stars + 1] = { f = s, base = base, ph = math.random() * 6.28, sp = 0.8 + math.random() * 1.8 }
    end

    -- conteneur centré du trou noir
    local hole = Instance.new("Frame", bg)
    hole.AnchorPoint = Vector2.new(0.5, 0.5)
    hole.Position = UDim2.new(0.5, 0, 0.5, 0)
    hole.Size = UDim2.new(0, 0, 0, 0)
    hole.BackgroundTransparency = 1
    hole.BorderSizePixel = 0

    -- halo lumineux externe
    local glow = Instance.new("Frame", hole)
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Position = UDim2.new(0.5, 0, 0.5, 0)
    glow.Size = UDim2.new(3.0, 0, 3.0, 0)
    glow.BackgroundColor3 = BH_COL.glow
    glow.BackgroundTransparency = 1
    glow.BorderSizePixel = 0
    Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
    local glowGrad = Instance.new("UIGradient", glow)
    glowGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    TweenService:Create(glow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.78
    }):Play()

    -- DISQUE D'ACCRÉTION : anneaux fins, inclinés, qui se forment un par un
    local rings = {}
    local RING_N = 14
    for i = 1, RING_N do
        local r = Instance.new("Frame", hole)
        r.AnchorPoint = Vector2.new(0.5, 0.5)
        r.Position = UDim2.new(0.5, 0, 0.5, 0)
        local scx = 1.10 + i * 0.24
        r.Size = UDim2.new(scx, 0, scx * 0.28, 0)
        r.BackgroundTransparency = 1
        r.BorderSizePixel = 0
        r.Rotation = -8 + i * 0.35
        Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
        local st = Instance.new("UIStroke", r)
        st.Thickness = 0
        st.Color = Color3.fromRGB(255, 255, 255)
        st.Transparency = 0.12 + i * 0.045
        local g = Instance.new("UIGradient", st)
        g.Color = BH_SEQ
        g.Rotation = i * 24
        rings[#rings + 1] = { f = r, g = g, st = st, spd = 30 + (RING_N - i) * 8, sx = scx, sy = scx * 0.28, rot = r.Rotation }
        task.delay(0.10 + i * 0.055, function()
            TweenService:Create(st, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Thickness = math.max(0.7, 3.4 - i * 0.18)
            }):Play()
        end)
    end

    -- lentille gravitationnelle : anneau lumineux autour de l'horizon
    local lens = Instance.new("Frame", hole)
    lens.AnchorPoint = Vector2.new(0.5, 0.5)
    lens.Position = UDim2.new(0.5, 0, 0.5, 0)
    lens.Size = UDim2.new(1.42, 0, 1.42, 0)
    lens.BackgroundTransparency = 1
    lens.BorderSizePixel = 0
    Instance.new("UICorner", lens).CornerRadius = UDim.new(1, 0)
    local lensStroke = Instance.new("UIStroke", lens)
    lensStroke.Thickness = 0
    lensStroke.Color = BH_COL.disk1
    lensStroke.Transparency = 0.2
    local lensGrad = Instance.new("UIGradient", lensStroke)
    lensGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, BH_COL.disk4),
        ColorSequenceKeypoint.new(0.50, BH_COL.disk1),
        ColorSequenceKeypoint.new(1.00, BH_COL.disk4),
    })
    TweenService:Create(lensStroke, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Thickness = 5}):Play()

    -- HALO CHROMATIQUE tournant (effet Doppler)
    local chroma = Instance.new("Frame", hole)
    chroma.AnchorPoint = Vector2.new(0.5, 0.5)
    chroma.Position = UDim2.new(0.5, 0, 0.5, 0)
    chroma.Size = UDim2.new(4.2, 0, 1.15, 0)
    chroma.BackgroundTransparency = 1
    chroma.BorderSizePixel = 0
    Instance.new("UICorner", chroma).CornerRadius = UDim.new(1, 0)
    local chromaStroke = Instance.new("UIStroke", chroma)
    chromaStroke.Thickness = 0
    chromaStroke.Transparency = 0.4
    local chromaGrad = Instance.new("UIGradient", chromaStroke)
    chromaGrad.Color = BH_SEQ
    TweenService:Create(chromaStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {Thickness = 2.0}):Play()

    -- horizon des événements (noyau noir)
    local core = Instance.new("Frame", hole)
    core.AnchorPoint = Vector2.new(0.5, 0.5)
    core.Position = UDim2.new(0.5, 0, 0.5, 0)
    core.Size = UDim2.new(1, 0, 1, 0)
    core.BackgroundColor3 = BH_COL.core
    core.BorderSizePixel = 0
    core.ZIndex = 5
    Instance.new("UICorner", core).CornerRadius = UDim.new(1, 0)
    local coreStroke = Instance.new("UIStroke", core)
    coreStroke.Thickness = 0
    coreStroke.Color = BH_COL.edge
    coreStroke.Transparency = 0.08
    TweenService:Create(coreStroke, TweenInfo.new(1.1, Enum.EasingStyle.Sine), {Thickness = 2.6}):Play()

    -- FORMATION : ouverture longue et très douce
    TweenService:Create(hole, TweenInfo.new(1.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 200, 0, 200)
    }):Play()

    -- matière aspirée en spirale (petits points, pas de traits)
    local parts = {}
    for _ = 1, 150 do
        local p = Instance.new("Frame", bg)
        p.AnchorPoint = Vector2.new(0.5, 0.5)
        local sz = 2 + math.random(0, 2)
        p.Size = UDim2.new(0, sz, 0, sz)
        p.BackgroundColor3 = BH_COL.disk2:Lerp(BH_COL.disk1, math.random())
        p.BackgroundTransparency = 1
        p.BorderSizePixel = 0
        Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
        parts[#parts + 1] = {
            f = p,
            a = math.random() * math.pi * 2,
            r = 300 + math.random(0, 380),
            s = 0.7 + math.random() * 0.9,
        }
    end

    local running = true
    local t = 0
    local conn = RunService.RenderStepped:Connect(function(dt)
        if not running then return end
        t = t + dt
        local ease = math.clamp(t / 1.4, 0, 1)
        for _, r in ipairs(rings) do
            r.g.Rotation = (r.g.Rotation + r.spd * dt) % 360
            local pulse = 1 + math.sin(t * 1.4 + r.sx) * 0.014
            r.f.Size = UDim2.new(r.sx * pulse, 0, r.sy * pulse, 0)
            r.f.Rotation = r.rot + math.sin(t * 0.5 + r.sx) * 1.6
        end
        lensGrad.Rotation = (lensGrad.Rotation + 20 * dt) % 360
        chromaGrad.Rotation = (chromaGrad.Rotation - 55 * dt) % 360
        chroma.Rotation = math.sin(t * 0.6) * 6
        nebGrad.Rotation = (nebGrad.Rotation + 6 * dt) % 360
        coreStroke.Thickness = 2.6 + math.sin(t * 2.2) * 0.5
        for _, s in ipairs(stars) do
            s.f.BackgroundTransparency = math.clamp(s.base + math.sin(t * s.sp + s.ph) * 0.25, 0, 1)
        end
        for _, p in ipairs(parts) do
            p.a = p.a + dt * (1.1 + 78 / math.max(p.r, 25)) * ease
            p.r = p.r - dt * 44 * p.s * ease
            if p.r <= 10 then
                p.r = 320 + math.random(0, 360)
                p.a = math.random() * math.pi * 2
            end
            p.f.Position = UDim2.new(0.5, math.cos(p.a) * p.r, 0.5, math.sin(p.a) * p.r * 0.26)
            p.f.BackgroundTransparency = math.clamp(1 - (p.r / 360), 0.1, 0.95) + (1 - ease) * 0.6
        end
    end)

    task.wait(1.7)

    -- le trou noir "construit" le script
    local status = Instance.new("TextLabel", bg)
    status.AnchorPoint = Vector2.new(0.5, 0.5)
    status.Position = UDim2.new(0.5, 0, 0.5, 210)
    status.Size = UDim2.new(0, 620, 0, 20)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.Font = Enum.Font.Code
    status.TextSize = 13
    status.TextColor3 = BH_COL.disk2
    status.TextTransparency = 1
    status.ZIndex = 20
    TweenService:Create(status, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {TextTransparency = 0.05}):Play()

    local steps = {
        "> singularité stabilisée...",
        "> extraction des modules...",
        "> assemblage de CRAZY HUB...",
        "> compilation terminée",
    }
    for _, s in ipairs(steps) do
        status.Text = s
        -- étincelles rondes éjectées (aucune barre)
        for _ = 1, 8 do
            local frag = Instance.new("Frame", bg)
            frag.AnchorPoint = Vector2.new(0.5, 0.5)
            frag.Position = UDim2.new(0.5, 0, 0.5, 0)
            frag.Size = UDim2.new(0, 3, 0, 3)
            frag.BackgroundColor3 = BH_COL.disk1
            frag.BackgroundTransparency = 0.2
            frag.BorderSizePixel = 0
            Instance.new("UICorner", frag).CornerRadius = UDim.new(1, 0)
            local ang = math.random() * math.pi * 2
            local dist = 220 + math.random(0, 220)
            TweenService:Create(frag, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, math.cos(ang) * dist, 0.5, math.sin(ang) * dist * 0.28),
                Size = UDim2.new(0, 1, 0, 1),
                BackgroundTransparency = 1,
            }):Play()
            Debris:AddItem(frag, 1.2)
        end
        task.wait(0.45)
    end

    -- convergence : petites particules aspirées (points, pas de barres)
    for i = 1, 40 do
        local dot = Instance.new("Frame", bg)
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        local ang = (i / 40) * math.pi * 2 + math.random() * 0.2
        dot.Position = UDim2.new(0.5, math.cos(ang) * 760, 0.5, math.sin(ang) * 430)
        dot.Size = UDim2.new(0, 4, 0, 4)
        dot.BackgroundColor3 = BH_COL.disk1
        dot.BackgroundTransparency = 0.1
        dot.BorderSizePixel = 0
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        TweenService:Create(dot, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 1, 0, 1),
            BackgroundTransparency = 1,
        }):Play()
        Debris:AddItem(dot, 1)
    end
    task.wait(0.35)

    -- ═══ CRAZY HUB émerge du trou noir, lettre par lettre ═══
    local titleHolder = Instance.new("Frame", bg)
    titleHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    titleHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
    titleHolder.Size = UDim2.new(0, 820, 0, 120)
    titleHolder.BackgroundTransparency = 1
    titleHolder.ZIndex = 30

    local layout = Instance.new("UIListLayout", titleHolder)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 2)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local word = "CRAZY HUB"
    local letters = {}
    for i = 1, #word do
        local ch = word:sub(i, i)
        local l = Instance.new("TextLabel", titleHolder)
        l.LayoutOrder = i
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(0, (ch == " ") and 26 or 62, 1, 0)
        l.Text = ch
        l.Font = Enum.Font.GothamBlack
        l.TextSize = 64
        l.TextColor3 = Color3.fromRGB(255, 255, 255)
        l.TextTransparency = 1
        l.ZIndex = 31
        local ls = Instance.new("UIStroke", l)
        ls.Thickness = 1.4
        ls.Color = BH_COL.edge
        ls.Transparency = 0.45
        local lg = Instance.new("UIGradient", l)
        lg.Color = BH_SEQ
        letters[#letters + 1] = { l = l, g = lg, s = ls }
        if ch ~= " " then
            task.delay(i * 0.06, function()
                l.Rotation = -14 + math.random() * 28
                l.TextSize = 18
                TweenService:Create(l, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    TextTransparency = 0, TextSize = 64, Rotation = 0
                }):Play()
            end)
        end
    end

    local tconn = RunService.RenderStepped:Connect(function(dt)
        for i, e in ipairs(letters) do
            e.g.Rotation = (e.g.Rotation + (26 + i) * dt) % 360
            e.s.Transparency = 0.3 + math.abs(math.sin(t * 2 + i * 0.4)) * 0.3
        end
    end)

    -- le noyau se referme, tout s'illumine
    TweenService:Create(core, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {Size = UDim2.new(0, 0, 0, 0)}):Play()
    TweenService:Create(glow, TweenInfo.new(0.9, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.55}):Play()
    TweenService:Create(neb, TweenInfo.new(0.9, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.82}):Play()
    task.wait(0.95)

    local sub = Instance.new("TextLabel", bg)
    sub.AnchorPoint = Vector2.new(0.5, 0.5)
    sub.Position = UDim2.new(0.5, 0, 0.5, 66)
    sub.Size = UDim2.new(0, 520, 0, 20)
    sub.BackgroundTransparency = 1
    sub.Text = "ON TOP  •  APPUIE SUR [G] POUR OUVRIR / FERMER"
    sub.Font = Enum.Font.GothamBold
    sub.TextSize = 14
    sub.TextColor3 = BH_COL.disk2
    sub.TextTransparency = 1
    sub.ZIndex = 30
    TweenService:Create(sub, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {TextTransparency = 0.1}):Play()
    status.Text = "> bienvenue " .. tostring(LocalPlayer.Name) .. " !"
    task.wait(1.0)

    -- ═══ SHOCKWAVE FINALE ═══
    for i = 1, 7 do
        local ring = Instance.new("Frame", bg)
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.new(0.5, 0, 0.5, 0)
        ring.Size = UDim2.new(0, 40, 0, 40)
        ring.BackgroundTransparency = 1
        ring.BorderSizePixel = 0
        Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
        local rs = Instance.new("UIStroke", ring)
        rs.Color = (i % 2 == 0) and BH_COL.disk2 or BH_COL.edge
        rs.Thickness = 3
        rs.Transparency = 0.15
        TweenService:Create(ring, TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 1500 + i * 260, 0, 1500 + i * 260),
        }):Play()
        TweenService:Create(rs, TweenInfo.new(1.1, Enum.EasingStyle.Sine), {Transparency = 1, Thickness = 0}):Play()
        Debris:AddItem(ring, 1.4)
        task.wait(0.09)
    end

    -- flash doux
    local flash = Instance.new("Frame", bg)
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flash.BackgroundTransparency = 0.45
    flash.BorderSizePixel = 0
    flash.ZIndex = 60
    TweenService:Create(flash, TweenInfo.new(0.55, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
    Debris:AddItem(flash, 0.7)
    task.wait(0.35)

    -- implosion finale fluide
    TweenService:Create(hole, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Size = UDim2.new(0, 0, 0, 0)}):Play()
    for i, e in ipairs(letters) do
        TweenService:Create(e.l, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            TextTransparency = 1, TextSize = 92, Rotation = (i % 2 == 0) and 12 or -12
        }):Play()
    end
    TweenService:Create(sub, TweenInfo.new(0.45, Enum.EasingStyle.Sine), {TextTransparency = 1}):Play()
    TweenService:Create(status, TweenInfo.new(0.45, Enum.EasingStyle.Sine), {TextTransparency = 1}):Play()
    TweenService:Create(neb, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
    for _, p in ipairs(parts) do
        TweenService:Create(p.f, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
    end
    for _, s in ipairs(stars) do
        TweenService:Create(s.f, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
    end
    TweenService:Create(bg, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
    task.wait(0.8)

    running = false
    pcall(function() conn:Disconnect() end)
    pcall(function() tconn:Disconnect() end)
    pcall(function() sg:Destroy() end)
end

-- ══════════════════════════════════════════════════════
--   PREFERENCE ANIMATION (par PSEUDO)
--   Demande UNE FOIS si on veut revoir l'anim a chaque lancement
-- ══════════════════════════════════════════════════════
local ANIM_PREF_FILE = "CrazyHub_AnimPrefs.json"
local HttpService = game:GetService("HttpService")

local function loadAnimPrefs()
    local data = {}
    pcall(function()
        if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(ANIM_PREF_FILE) then
            data = HttpService:JSONDecode(readfile(ANIM_PREF_FILE)) or {}
        end
    end)
    if type(data) ~= "table" then data = {} end
    -- fallback memoire (executors sans filesystem)
    local g = getgenv and getgenv() or _G
    g.CrazyHubAnimPrefs = g.CrazyHubAnimPrefs or {}
    for k, v in pairs(g.CrazyHubAnimPrefs) do
        if data[k] == nil then data[k] = v end
    end
    return data
end

local function saveAnimPref(pseudo, value)
    local data = loadAnimPrefs()
    data[pseudo] = value
    local g = getgenv and getgenv() or _G
    g.CrazyHubAnimPrefs = g.CrazyHubAnimPrefs or {}
    g.CrazyHubAnimPrefs[pseudo] = value
    pcall(function()
        if typeof(writefile) == "function" then
            writefile(ANIM_PREF_FILE, HttpService:JSONEncode(data))
        end
    end)
end

local function getAnimPref(pseudo)
    return loadAnimPrefs()[pseudo]
end

-- POPUP : "revoir l'animation a chaque lancement ?"
local function askAnimPopup()
    local pseudo = tostring(LocalPlayer.Name)
    local done, answer = false, nil

    local sg = Instance.new("ScreenGui")
    sg.Name = "CrazyAnimAsk_" .. math.random(1000, 9999)
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 9998
    sg.Parent = crazyGuiParent()

    local dim = Instance.new("Frame", sg)
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = Color3.fromRGB(2, 4, 7)
    dim.BackgroundTransparency = 1
    dim.BorderSizePixel = 0
    TweenService:Create(dim, TweenInfo.new(0.3), {BackgroundTransparency = 0.45}):Play()

    local box = Instance.new("Frame", dim)
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.new(0.5, 0, 0.5, 0)
    box.Size = UDim2.new(0, 0, 0, 0)
    box.BackgroundColor3 = Color3.fromRGB(10, 16, 24)
    box.BackgroundTransparency = 0.1
    box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
    local bstroke = Instance.new("UIStroke", box)
    bstroke.Color = BH_COL.edge; bstroke.Thickness = 1.4; bstroke.Transparency = 0.35
    TweenService:Create(box, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 400, 0, 190)
    }):Play()

    local ttl = Instance.new("TextLabel", box)
    ttl.Position = UDim2.new(0, 0, 0, 20)
    ttl.Size = UDim2.new(1, 0, 0, 26)
    ttl.BackgroundTransparency = 1
    ttl.Text = "CRAZY HUB"
    ttl.Font = Enum.Font.GothamBlack
    ttl.TextSize = 20
    ttl.TextColor3 = Color3.fromRGB(255, 255, 255)
    local tgd = Instance.new("UIGradient", ttl); tgd.Color = BH_SEQ

    local msg = Instance.new("TextLabel", box)
    msg.Position = UDim2.new(0, 18, 0, 54)
    msg.Size = UDim2.new(1, -36, 0, 60)
    msg.BackgroundTransparency = 1
    msg.TextWrapped = true
    msg.Text = "Salut " .. pseudo .. " !\nVeux-tu revoir l'animation trou noir a CHAQUE lancement du script ?"
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 13
    msg.TextColor3 = Color3.fromRGB(200, 226, 240)

    local function mkBtn(txt, xoff, col, val)
        local b = Instance.new("TextButton", box)
        b.AnchorPoint = Vector2.new(0.5, 0)
        b.Position = UDim2.new(0.5, xoff, 0, 128)
        b.Size = UDim2.new(0, 150, 0, 38)
        b.BackgroundColor3 = col
        b.BorderSizePixel = 0
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        b.MouseButton1Click:Connect(function()
            if done then return end
            answer = val
            done = true
        end)
        return b
    end
    mkBtn("OUI, a chaque fois", -80, Color3.fromRGB(34, 62, 84), true)
    mkBtn("NON, plus jamais",    80, Color3.fromRGB(78, 34, 42), false)

    repeat task.wait() until done
    saveAnimPref(pseudo, answer)
    TweenService:Create(dim, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
    TweenService:Create(box, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    }):Play()
    task.wait(0.3)
    pcall(function() sg:Destroy() end)
end

do
    local pseudo = tostring(LocalPlayer.Name)
    local pref = getAnimPref(pseudo)
    if pref ~= false then
        pcall(playLaunchAnimation)
    end
    if pref == nil then
        pcall(askAnimPopup)
    end
end





-- ══════════════════════════════
--            CONFIG
-- ══════════════════════════════
local Cfg = {
    Vision = {
        Enabled  = false,   -- forcer le champ de vision de la camera
        FOV      = 70,      -- 30 = zoome / 120 = grand angle (comme la roulette)
        MaxZoom  = 128,     -- distance de dezoom max (3eme personne)
        MinZoom  = 0.5,     -- 0.5 = on peut passer en 1ere personne
    },
    AimBot = {
        Enabled      = false,
        Smoothness   = 0.08,   -- 0.01 = instant  /  1 = très lent
        FOV          = 150,
        WallCheck    = false,
        TeamCheck    = false,
        Prediction   = false,
        StickyAim    = false,
        ShowFOVCircle = true,   -- cercle FOV VISIBLE (suit la souris)
        WeaponFollow  = true,   -- la SOURIS (donc l'arme) suit la tete lockee
        ArmAim        = true,   -- bras / torse orientes vers l'ennemi
        MouseLock     = true,   -- BLOQUE le curseur PILE sur la tete lockee
        Key          = Enum.UserInputType.MouseButton2,
    },
    LegitTrigger = {
        Enabled      = false,   -- MODE LEGIT : ennemi dans FOV → lock tête + tir auto
        LockHead     = true,    -- viser SYSTEMATIQUEMENT la tête
        FOVOnly      = true,    -- cible QUE dans le cercle FOV
        WallCheck    = false,
        TeamCheck    = false,
        Delay        = 0.05,    -- délai entre tirs
    },
    TriggerBot = {
        Enabled = false,
        FOV     = 80,
        Delay   = 0.05,
    },
    ESP = {
        Enabled    = false,
        WallESP    = true,   -- voir à travers les murs
        HealthBar  = true,
        NameTag    = true,
        Box        = true,
        FilledBox  = false,  -- box REMPLIE de couleur (remplissage semi-transparent)
        FilledAlpha= 0.55,   -- transparence du remplissage (0 = opaque, 1 = invisible)
        Distance   = true,
        Tracers    = false,  -- lignes reliees aux joueurs
        Skeleton   = false,  -- squelette de l'ennemi (os relies)
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
        Enabled = false,
    },
    RapidFire = {
        Enabled = false,  -- supprime latence tir + rechargement
    },
    -- Vision et Free Cam ont ete SUPPRIMES (v2.5)
    Crosshair = {
        Enabled  = false,
        -- ═══ LIGNE A MODIFIER : mets ici ta lettre / ton emoji ═══
        Char     = "+",
        Size     = 26,
        Color    = Color3.fromRGB(255, 220, 0),
        Rotate   = false,
        RotSpeed = 120,     -- degres / seconde
        Rainbow  = false,
        Outline  = true,
    },
    HideWeapon = {
        Enabled = false,      -- cache l'arme / bras (viewmodel) en local
    },
    Background = {
        Enabled  = true,                          -- image en fond du panel
        Id       = "rbxassetid://73327281521265", -- ID de l'image
        Alpha    = 0,                             -- 0 = opaque (par defaut) / 1 = invisible
        InFOV    = false,                         -- afficher l'image DANS le cercle FOV
        FovAlpha = 0.75,                          -- transparence de l'image en FOV
    },
    Colors = {
        FOV      = Color3.fromRGB(255, 220, 0),
        ESP      = Color3.fromRGB(255, 220, 0),
        Skeleton = Color3.fromRGB(0, 255, 255),  -- couleur DEDIEE au squelette (cyan par defaut)
    },


}

-- ══════════════════════════════════════════════════════
--   SAUVEGARDE AUTO DES PARAMETRES (par compte)
--   Chaque joueur retrouve ses reglages au prochain lancement
-- ══════════════════════════════════════════════════════
local CfgIO = {
    file = "CrazyHub_Config_" .. tostring(LocalPlayer.UserId) .. ".json",
    -- valeurs qu'on ne restaure PAS (elles doivent repartir a zero)
    skip = {
        ["Fly.Enabled"] = true, ["NoClip.Enabled"] = true, ["InfJump.Enabled"] = true,
        ["AutoTP.Enabled"] = true, ["Teleport.SavedPos"] = true,
    },
    queued = false,
    loaded = false,
}

function CfgIO.encode(v)
    if typeof(v) == "Color3" then
        return { __c3 = { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) } }
    elseif type(v) == "number" or type(v) == "boolean" or type(v) == "string" then
        return v
    end
    return nil -- EnumItem / Vector3 / fonctions : ignores
end

function CfgIO.decode(v)
    if type(v) == "table" and type(v.__c3) == "table" then
        return Color3.fromRGB(v.__c3[1] or 255, v.__c3[2] or 255, v.__c3[3] or 255)
    end
    return v
end

function CfgIO.serialize()
    local out = {}
    for section, tbl in pairs(Cfg) do
        if type(tbl) == "table" then
            local s = {}
            for k, v in pairs(tbl) do
                if not CfgIO.skip[section .. "." .. k] then
                    local e = CfgIO.encode(v)
                    if e ~= nil then s[k] = e end
                end
            end
            out[section] = s
        end
    end
    return out
end

function CfgIO.load()
    local data = nil
    pcall(function()
        local HS = game:GetService("HttpService")
        local raw
        if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(CfgIO.file) then
            raw = readfile(CfgIO.file)
        else
            local g = (getgenv and getgenv()) or _G
            raw = g.CrazyHubCfgCache
        end
        if raw then data = HS:JSONDecode(raw) end
    end)
    if type(data) ~= "table" then return false end
    for section, tbl in pairs(data) do
        if type(tbl) == "table" and type(Cfg[section]) == "table" then
            for k, v in pairs(tbl) do
                if Cfg[section][k] ~= nil and not CfgIO.skip[section .. "." .. k] then
                    local dec = CfgIO.decode(v)
                    if typeof(dec) == typeof(Cfg[section][k]) then
                        Cfg[section][k] = dec
                    end
                end
            end
        end
    end
    return true
end

function CfgIO.reset()
    pcall(function()
        if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(CfgIO.file) then
            delfile(CfgIO.file)
        end
        local g = (getgenv and getgenv()) or _G
        g.CrazyHubCfgCache = nil
    end)
end

-- debounce : evite d'ecrire le fichier a chaque pixel de slider
local function saveCfg()
    if CfgIO.queued then return end
    CfgIO.queued = true
    task.delay(0.6, function()
        CfgIO.queued = false
        pcall(function()
            local HS = game:GetService("HttpService")
            local data = HS:JSONEncode(CfgIO.serialize())
            local g = (getgenv and getgenv()) or _G
            g.CrazyHubCfgCache = data
            if typeof(writefile) == "function" then writefile(CfgIO.file, data) end
        end)
    end)
end

pcall(function() CfgIO.loaded = CfgIO.load() end)


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

-- LEGIT : vérifie si un joueur est DANS le FOV circle
local function isInFOV(p, fovRadius)
    local head = getHead(p)
    if not head then return false end
    local sp, on = toScreen(head.Position)
    if not on then return false end
    local mousePos = UserInputService:GetMouseLocation()
    local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
    return d <= (fovRadius or Cfg.AimBot.FOV)
end

-- ══════════════════════════════
--          FOV CIRCLE
-- ══════════════════════════════
-- REMPLISSAGE : cercle plein GRIS tres transparent (dessine SOUS le contour)
local FovFill = Drawing.new("Circle")
FovFill.Visible      = false
FovFill.Filled       = true
FovFill.Thickness    = 0
FovFill.NumSides     = 128
FovFill.Color        = Color3.fromRGB(150, 150, 155)
FovFill.Transparency = 0.12          -- tres transparent mais visible
FovFill.Radius       = Cfg.AimBot.FOV - 1
FovFill.Position     = screenCenter()
FovFill.ZIndex       = 1

local FovCircle = Drawing.new("Circle")
FovCircle.Visible     = false
FovCircle.Thickness   = 1.2
FovCircle.Color       = Cfg.Colors.FOV
FovCircle.Transparency = 0.7
FovCircle.Filled      = false
FovCircle.NumSides    = 128
FovCircle.Radius      = Cfg.AimBot.FOV
FovCircle.Position    = screenCenter()
FovCircle.ZIndex      = 2

-- ETAT MIROIR : certains executors ne renvoient PAS les proprietes
-- des objets Drawing (lecture = nil) => "attempt to perform arithmetic
-- (sub) on nil and number". On garde donc notre propre etat en Lua
-- et on n'interroge JAMAIS le Drawing en lecture.
local FovS = {
    Visible  = false,
    Radius   = tonumber(Cfg.AimBot.FOV) or 150,
    Position = screenCenter(),
}

function FovS.setVisible(v)
    v = v and true or false
    FovS.Visible = v
    pcall(function() FovCircle.Visible = v end)
    pcall(function() FovFill.Visible = v end)
end

function FovS.setRadius(r)
    r = tonumber(r) or FovS.Radius or 150
    if r ~= r then r = 150 end -- NaN
    FovS.Radius = math.clamp(r, 1, 2000)
    pcall(function() FovCircle.Radius = FovS.Radius end)
    pcall(function() FovFill.Radius = math.max(FovS.Radius - 1, 0) end)
end

function FovS.setPos(p)
    if typeof(p) ~= "Vector2" then p = screenCenter() end
    FovS.Position = p
    pcall(function() FovCircle.Position = p end)
    pcall(function() FovFill.Position = p end)
end

function FovS.setColor(c)
    if typeof(c) ~= "Color3" then return end
    pcall(function() FovCircle.Color = c end)
end

-- garde le remplissage colle au contour (jamais plus grand => ne depasse pas)
local function fovSync()
    pcall(function()
        FovFill.Visible  = FovS.Visible
        FovFill.Position = FovS.Position
        FovFill.Radius   = math.max((FovS.Radius or 150) - 1, 0)
    end)
end

-- ══════════════════════════════════════════════════════
--   IMAGE EN FOV (semi-transparente, colle au cercle FOV)
-- ══════════════════════════════════════════════════════
local FovImgGui = Instance.new("ScreenGui")
FovImgGui.Name = "CrazyFovImg_" .. math.random(1000, 9999)
FovImgGui.IgnoreGuiInset = true
FovImgGui.ResetOnSpawn = false
FovImgGui.DisplayOrder = 5
pcall(function() FovImgGui.Parent = crazyGuiParent() end)

local FovIMG = Instance.new("ImageLabel", FovImgGui)
FovIMG.AnchorPoint = Vector2.new(0.5, 0.5)
FovIMG.BackgroundTransparency = 1
FovIMG.Image = Cfg.Background.Id
FovIMG.ImageTransparency = Cfg.Background.FovAlpha
FovIMG.ScaleType = Enum.ScaleType.Crop
FovIMG.Visible = false
do
    local m = Instance.new("UICorner", FovIMG); m.CornerRadius = UDim.new(1, 0)
end

RunService.RenderStepped:Connect(function()
    if not Cfg.Background.InFOV then
        FovIMG.Visible = false
        return
    end
    local r = math.max(FovS.Radius or 150, 10)
    local pos = FovS.Position or screenCenter()
    FovIMG.Size = UDim2.new(0, r * 2, 0, r * 2)
    FovIMG.Position = UDim2.new(0, pos.X, 0, pos.Y)
    FovIMG.ImageTransparency = math.clamp(Cfg.Background.FovAlpha, 0, 1)
    FovIMG.Visible = true
end)

-- ══════════════════════════════════════════════════════
--   AIMBOT — Compatible toutes armes 
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
-- AIMBOT CORE — méthode exacte des vrais scripts 
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

-- ══════════════════════════════════════════════════════════
--   LEGIT POWER :
--   • Tu MAINTIENS CLIC DROIT (MOI qui contrôle la souris !)
--   • Si ennemi DANS FOV circle → lock SUR SA TÊTE (silencieux)
--   • Dès que c'est locké → TIR AUTOMATIQUE (clic gauche)
--   • LÂCHE clic droit → stop immédiat (pas d'autoclick)
-- ══════════════════════════════════════════════════════════
local lpCooldown = false
local lpLockedThisFrame = false  -- nouveau lock cette frame → tir INSTANT
-- Flags sync premier tir (SIMPLE : on garde en mémoire quelle cible
-- était lockée la frame d'avant. Si la cible est différente → NOUVEAU
-- lock → tir direct. Pas de "frame N/N+1" compliqué qui buggue.)
local lpLastLockedPlayer = nil

-- Helper : supporte à la fois souris (UserInputType) et clavier (KeyCode)
-- (évite que si Cfg.AimBot.Key = Enum.KeyCode.C ça ne marche pas)
local function isAimKeyDown()
    local k = Cfg.AimBot.Key
    if typeof(k) == "EnumItem" then
        if tostring(k.EnumType) == "UserInputType" then
            return UserInputService:IsMouseButtonPressed(k)
        elseif tostring(k.EnumType) == "KeyCode" then
            return UserInputService:IsKeyDown(k)
        end
    end
    -- Fallback : clic droit
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

-- Grace : on ne lache pas la cible au premier raycast rate
-- (cible en mouvement qui passe derriere un poteau / un bras)
local lpLostSince = nil
local LP_LOST_GRACE = 0.35

local function getLegitPowerTarget()
    -- ─────── LOCK FERME À TOUTE ÉPREUVE ───────
    -- Si on a déjà une cible : ON LA GARDE SAUF SI
    --   • elle est morte
    --   • derrière un mur
    --   • vraiment HORS FOV (1.6x la taille du cercle)
    -- Plus de dot product qui bloquait en scope / FOV étroit
    if lpLockTarget and isAlive(lpLockTarget) then
        local h = getHead(lpLockTarget)
        if h then
            -- 1) Wall Check sur la cible stickée
            if Cfg.LegitTrigger.WallCheck then
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    local ray = RaycastParams.new()
                    ray.FilterDescendantsInstances = {myChar, lpLockTarget.Character}
                    ray.FilterType = Enum.RaycastFilterType.Exclude
                    local hit = workspace:Raycast(myRoot.Position, (h.Position - myRoot.Position), ray)
                    if hit then
                        lpLostSince = lpLostSince or os.clock()
                        if (os.clock() - lpLostSince) < LP_LOST_GRACE then
                            return lpLockTarget  -- on garde le lock un court instant
                        end
                        lpLostSince = nil
                        return nil
                    else
                        lpLostSince = nil
                    end
                end
            end

            -- 2) FOV check avec tolérance MODÉRÉE (1.6x)
            if Cfg.LegitTrigger.FOVOnly then
                local mpos = UserInputService:GetMouseLocation()
                local sp, on = toScreen(h.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - mpos).Magnitude
                    if d <= (Cfg.AimBot.FOV * 2.5) then
                        return lpLockTarget
                    end
                else
                    return lpLockTarget  -- hors ecran 1 frame : on garde
                end
            else
                return lpLockTarget
            end
        end
    end

    local best, bestD = nil, math.huge
    local mpos = UserInputService:GetMouseLocation()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not isAlive(p) then continue end
        if Cfg.LegitTrigger.TeamCheck and isTeam(p) then continue end

        local head = getHead(p)
        if not head then continue end

        -- Wall Check
        if Cfg.LegitTrigger.WallCheck then
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local ray = RaycastParams.new()
                ray.FilterDescendantsInstances = {myChar, p.Character}
                ray.FilterType = Enum.RaycastFilterType.Exclude
                local hit = workspace:Raycast(myRoot.Position, (head.Position - myRoot.Position), ray)
                if hit then continue end
            end
        end

        local sp, on = toScreen(head.Position)
        if not on then continue end

        local d = (Vector2.new(sp.X, sp.Y) - mpos).Magnitude

        -- Nouvelle cible : FOV strict
        if Cfg.LegitTrigger.FOVOnly and d > Cfg.AimBot.FOV then continue end

        if d < bestD then
            bestD = d
            best = p
        end
    end
    return best
end

-- Silent Aim Hook pour LEGIT POWER
local lpLockTarget = nil
local lpSilentActive = false
local lpPreviousTarget = nil  -- pour détecter NOUVEAU lock
-- Position de la tête lockée cette frame (utilisée pour RE-FORCER
-- la caméra APRÈS le script caméra de Roblox : sinon en 3ème
-- personne / spin bot, Roblox écrase notre Camera.CFrame)
local camLockPos = nil
-- Spin Bot auto-head : vrai quand le spin lock une tête tout seul
local spinAimLocked = false
local spinIsActive  = false
-- On a RETIRÉ la rotation de HumanoidRootPart/Waist car elle
--    faisait trembler la caméra quand tu visais en hauteur/bas
--    (elle s'opposait à Camera.CFrame = ...). Maintenant on ne
--    touche QU'À LA CAMÉRA + SILENT AIM (les balles vont au bon
--    endroit via le hook, pas besoin de tourner le corps).

-- ════════════════════════════════════════════════════════════
--  LOCK CAMÉRA + RECHERCHE CIBLE → PRIORITÉ TRÈS HAUTE
--  BindToRenderStep priorité 100 : s'exécute AVANT le rendu
--  de la caméra de Roblox. Donc la rotation est APPLIQUÉE
--  AVANT que Mouse.Hit / les rayons soient calculés.
-- ════════════════════════════════════════════════════════════
RunService:BindToRenderStep("LegitCam", Enum.RenderPriority.Camera.Value - 1, function()
    -- FOV circle : suit la souris, visible des que Aimbot/Legit est ON
    FovS.setVisible(Cfg.AimBot.ShowFOVCircle and (Cfg.AimBot.Enabled or Cfg.LegitTrigger.Enabled))
    local mpos = UserInputService:GetMouseLocation()
    FovS.setPos(Vector2.new(mpos.X, mpos.Y))
    fovSync()
    FovS.setRadius(Cfg.AimBot.FOV)
    fovSync()

    local keyDown = isAimKeyDown()  -- helper souris + clavier
    local legitOn = Cfg.LegitTrigger.Enabled
    local aimbotOn = Cfg.AimBot.Enabled

    -- Reset TOTAL du lock quand on lache la touche OU on desactive.
    -- IMPORTANT : on vide AUSSI lockedTarget (aimbot classique) et
    -- lpLostSince, sinon a la visee suivante le script re-verrouille
    -- automatiquement l'ancien mec (meme en visant dans le vide).
    if not keyDown or (not legitOn and not aimbotOn) then
        lpLockTarget = nil
        lpLastLockedPlayer = nil
        lpPreviousTarget = nil
        lpSilentActive = false
        lpLockedThisFrame = false
        lpLostSince = nil
        lockedTarget = nil
        camLockPos = nil
        FovS.setColor(Cfg.Colors.FOV)
        return
    end

    -- ───── LEGIT POWER (prioritaire si activé) ─────
    if legitOn then
        FovS.setColor(Color3.fromRGB(255, 80, 20))

        local previousPlayer = lpLockTarget  -- mémorise avant de chercher
        local target = getLegitPowerTarget()
        lpLockTarget = target

        -- Détecte NOUVEAU lock cette frame
        lpLockedThisFrame = (target ~= nil and previousPlayer ~= target)

        if target and isAlive(target) then
            local head = getHead(target)
            if head then
                local headPos = head.Position
                local r = getRoot(target)
                if r and Cfg.AimBot.Prediction then
                    headPos = headPos + r.AssemblyLinearVelocity * 0.135
                end

                lpSilentActive = true
                camLockPos = headPos

                -- LOCK FERME : Camera.CFrame FORCÉ (priorité haute → avant rendu)
                local camPos = Camera.CFrame.Position
                Camera.CFrame = CFrame.new(camPos, headPos)
            else
                lpLockTarget = nil
                lpSilentActive = false
                lpLockedThisFrame = false
                camLockPos = nil
            end
        else
            lpSilentActive = false
            lpLockedThisFrame = false
            camLockPos = nil
        end

        -- Mémorise la cible lockée de cette frame
        lpLastLockedPlayer = lpLockTarget
        return
    end

    -- ───── AIMBOT CLASSIQUE ─────
    if aimbotOn then
        FovS.setColor(Color3.fromRGB(255, 50, 50))

        -- Si Sticky Aim est OFF : la cible doit rester dans le cercle
        -- FOV, sinon on la lache (pas de re-lock fantome sur l'ancien).
        if lockedTarget and isAlive(lockedTarget) and not Cfg.AimBot.StickyAim then
            local h = getHead(lockedTarget)
            local sp, on = h and toScreen(h.Position)
            if not h or not on
               or (Vector2.new(sp.X, sp.Y) - mpos).Magnitude > Cfg.AimBot.FOV then
                lockedTarget = nil
            end
        end

        if not lockedTarget or not isAlive(lockedTarget) then
            lockedTarget = getBest()
        end

        if lockedTarget and isAlive(lockedTarget) then
            local head = getHead(lockedTarget)
            if head then
                local aimPos = head.Position
                local r = getRoot(lockedTarget)
                if r and Cfg.AimBot.Prediction then
                    aimPos = aimPos + r.AssemblyLinearVelocity * 0.08
                end
                camLockPos = aimPos
                doSnap(aimPos)
            else
                lockedTarget = nil
                camLockPos = nil
            end
        else
            lockedTarget = nil
            camLockPos = nil
        end
    else
        camLockPos = nil
    end
end)

-- ════════════════════════════════════════════════════════════
--  RE-LOCK CAMÉRA APRÈS LE SCRIPT CAMÉRA DE ROBLOX
--  Le script caméra de Roblox tourne en priorité Camera (200)
--  et recalcule Camera.CFrame à partir de la souris / rotation
--  du personnage → il écrasait notre lock (surtout en 3ème
--  personne forcée + Spin Bot). On ré-applique juste après,
--  donc la visée reste COLLÉE sur la tête même en spin.
-- ════════════════════════════════════════════════════════════
-- ════════════════════════════════════════════════════════════
--  BODY LOCK V8 : le CORPS suit la CAMERA lockee (yaw only)
--  Quand la camera est bloquee sur la tete, le HumanoidRootPart
--  prend EXACTEMENT le yaw de Camera.CFrame.LookVector. Donc si
--  tu bouges la souris pendant le lock, ca ne part pas de travers :
--  la camera reste lock tete, et le corps reste dans le meme axe.
-- ════════════════════════════════════════════════════════════
local bodyLockActive = false
local bodyGyro = nil

local function getMyHum()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

-- V9 : le yaw vient de la CIBLE (camLockPos), pas de la souris.
-- Comme ca, meme si tu bouges la souris pendant le lock :
--   - la camera reste bloquee sur la TETE
--   - le corps reste EXACTEMENT dans le meme axe que la camera
-- (avant, on prenait Camera.LookVector qui pouvait deriver d'une frame
--  a l'autre -> le corps partait n'importe ou)
local function getLockYawCFrame(root)
    if not root then return nil end
    local pos = root.Position
    local dir
    if camLockPos then
        dir = camLockPos - pos
    else
        dir = Camera.CFrame.LookVector
    end
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude < 0.001 then
        local look = Camera.CFrame.LookVector
        flat = Vector3.new(look.X, 0, look.Z)
    end
    if flat.Magnitude < 0.001 then
        local _, y = root.CFrame:ToOrientation()
        return CFrame.new(pos) * CFrame.Angles(0, y, 0)
    end
    return CFrame.new(pos, pos + flat.Unit)
end

local bodyAlign, bodyAtt = nil, nil

local function ensureBodyGyro(root)
    -- BodyGyro (legacy) + AlignOrientation (moderne) : certains jeux
    -- ignorent l'un des deux, on met les DEUX pour que le corps ne
    -- puisse plus tourner tout seul quand tu bouges la souris.
    if not (bodyGyro and bodyGyro.Parent == root) then
        if bodyGyro then pcall(function() bodyGyro:Destroy() end) end
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.Name = "CrazyHub_CameraBodyLock"
        bodyGyro.MaxTorque = Vector3.new(0, math.huge, 0)
        bodyGyro.P = 250000
        bodyGyro.D = 2000
        bodyGyro.Parent = root
    end
    if not (bodyAtt and bodyAtt.Parent == root) then
        if bodyAtt then pcall(function() bodyAtt:Destroy() end) end
        bodyAtt = Instance.new("Attachment")
        bodyAtt.Name = "CrazyHub_BodyLockAtt"
        bodyAtt.Parent = root
    end
    if not (bodyAlign and bodyAlign.Parent == root) then
        if bodyAlign then pcall(function() bodyAlign:Destroy() end) end
        bodyAlign = Instance.new("AlignOrientation")
        bodyAlign.Name = "CrazyHub_BodyLockAlign"
        bodyAlign.Mode = Enum.OrientationAlignmentMode.OneAttachment
        bodyAlign.Attachment0 = bodyAtt
        bodyAlign.RigidityEnabled = true
        bodyAlign.Responsiveness = 200
        bodyAlign.MaxTorque = math.huge
        bodyAlign.Parent = root
    end
    return bodyGyro
end

-- Le CORPS suit la CAMERA lockee, pas la souris brute et pas l'ancien target.
local function bodyFollowCamera()
    local hum, root = getMyHum()
    if not root then return end
    if not camLockPos and not isAimKeyDown() and not spinAimLocked then return end

    -- On force AutoRotate a OFF a CHAQUE frame : beaucoup de jeux le
    -- remettent a true, c'est ce qui faisait tourner ton corps avec la souris.
    if hum then hum.AutoRotate = false end
    bodyLockActive = true

    local targetCF = getLockYawCFrame(root)
    if not targetCF then return end

    -- Triple force : BodyGyro + AlignOrientation + snap CFrame.
    ensureBodyGyro(root)
    if bodyGyro then bodyGyro.CFrame = targetCF end
    if bodyAlign then bodyAlign.CFrame = targetCF end
    -- On garde la position EXACTE, on ne change que la rotation (yaw).
    root.CFrame = CFrame.new(root.Position) * (targetCF - targetCF.Position)

    -- Stoppe toute rotation parasite qui faisait partir le corps de travers.
    pcall(function() root.AssemblyAngularVelocity = Vector3.new(0, 0, 0) end)
    pcall(function() root.RotVelocity = Vector3.new(0, 0, 0) end)
end

local function releaseBodyLock()
    if bodyGyro then
        pcall(function() bodyGyro:Destroy() end)
        bodyGyro = nil
    end
    if bodyAlign then
        pcall(function() bodyAlign:Destroy() end)
        bodyAlign = nil
    end
    if bodyAtt then
        pcall(function() bodyAtt:Destroy() end)
        bodyAtt = nil
    end
    if bodyLockActive then
        bodyLockActive = false
        local hum = select(1, getMyHum())
        if hum then hum.AutoRotate = true end
    end
end

-- ══════════════════════════════════════════════════════
--   L'ARME SUIT L'ENNEMI (pas seulement la camera)
--   La plupart des jeux tirent / orientent l'arme vers
--   Mouse.Hit : si la souris ne bouge pas, l'arme reste
--   droite pendant que la camera tourne. On recale donc
--   la SOURIS sur la tete lockee a chaque frame, et on
--   oriente le torse / les bras vers la cible.
-- ══════════════════════════════════════════════════════
local WeaponAim = { gui = game:GetService("GuiService") }

function WeaponAim.getMoveFn()
    -- On cherche mousemoverel PARTOUT : env global de l'executeur,
    -- global normal, syn.*, Krnl, etc. (rawget seul ratait la fonction
    -- sur beaucoup d'executeurs -> le curseur ne bougeait jamais)
    local candidates = {}
    if getgenv then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then candidates[#candidates+1] = rawget(g, "mousemoverel") end
    end
    candidates[#candidates+1] = rawget(_G, "mousemoverel")
    local okEnv, env = pcall(function() return getfenv(0) end)
    if okEnv and type(env) == "table" then candidates[#candidates+1] = rawget(env, "mousemoverel") end
    if syn and type(syn) == "table" then candidates[#candidates+1] = rawget(syn, "mousemoverel") end
    for _, f in ipairs(candidates) do
        if typeof(f) == "function" then return f end
    end
    return nil
end

function WeaponAim.getMoveAbsFn()
    local candidates = {}
    if getgenv then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then candidates[#candidates+1] = rawget(g, "mousemoveabs") end
    end
    candidates[#candidates+1] = rawget(_G, "mousemoveabs")
    local okEnv, env = pcall(function() return getfenv(0) end)
    if okEnv and type(env) == "table" then candidates[#candidates+1] = rawget(env, "mousemoveabs") end
    for _, f in ipairs(candidates) do
        if typeof(f) == "function" then return f end
    end
    return nil
end

-- ══════════════════════════════════════════════════════════
--  CURSEUR BLOQUE SUR LA TETE
--  Tant que tu maintiens clic droit et qu'une cible est lockee,
--  le curseur est REPLACE pile sur le pixel de la tete a chaque
--  frame : impossible de le decrocher en bougeant la souris.
-- ══════════════════════════════════════════════════════════
function WeaponAim.lockMouseOn(worldPos)
    if not Cfg.AimBot.MouseLock then return false end
    if typeof(worldPos) ~= "Vector3" then return false end
    local okv, sp = pcall(function() return Camera:WorldToViewportPoint(worldPos) end)
    if not okv or not sp or sp.Z <= 0 then return false end

    -- En souris verrouillee au centre (1ere personne / shift-lock),
    -- le curseur EST le centre de l'ecran : c'est la camera qui doit
    -- viser, et elle est deja lockee ailleurs. Rien a forcer ici.
    local mb = UserInputService.MouseBehavior
    if mb == Enum.MouseBehavior.LockCenter then return true end

    local inset = WeaponAim.gui:GetGuiInset()
    local targetX, targetY = sp.X + inset.X, sp.Y + inset.Y
    if targetX ~= targetX or targetY ~= targetY then return false end

    local m = UserInputService:GetMouseLocation()
    local dx, dy = targetX - m.X, targetY - m.Y

    -- 1) mousemoverel : la methode qui marche partout
    local mv = WeaponAim.getMoveFn()
    if mv then
        if math.abs(dx) >= 0.4 or math.abs(dy) >= 0.4 then
            pcall(mv, math.clamp(dx, -3000, 3000), math.clamp(dy, -3000, 3000))
        end
        return true
    end

    -- 2) fallback mousemoveabs (coords viewport, sans inset)
    local mva = WeaponAim.getMoveAbsFn()
    if mva then
        pcall(mva, sp.X, sp.Y)
        return true
    end

    -- 3) dernier recours : on colle le curseur au centre et on laisse
    --    la camera lockee faire la visee (pas de decrochage possible)
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end)
    return false
end

function WeaponAim.releaseMouse()
    pcall(function()
        if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
           and not isFirstPerson() then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end)
end

-- Recale le curseur pile sur le point vise (inset GUI compris)
function WeaponAim.pointMouseAt(worldPos)
    if not Cfg.AimBot.WeaponFollow then return end
    if typeof(worldPos) ~= "Vector3" then return end
    local mv = WeaponAim.getMoveFn()
    if not mv then return end
    local okv, sp = pcall(function() return Camera:WorldToViewportPoint(worldPos) end)
    if not okv or not sp or sp.Z <= 0 then return end
    local m = UserInputService:GetMouseLocation()
    local inset = WeaponAim.gui:GetGuiInset()
    local dx = (sp.X + inset.X) - m.X
    local dy = (sp.Y + inset.Y) - m.Y
    if dx ~= dx or dy ~= dy then return end            -- NaN guard
    if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end
    dx = math.clamp(dx, -2000, 2000)
    dy = math.clamp(dy, -2000, 2000)
    pcall(mv, dx, dy)
end

-- Oriente le haut du corps (donc l'arme tenue) vers la cible
WeaponAim.saved = {}
function WeaponAim.alignUpperBody(worldPos)
    if not Cfg.AimBot.ArmAim then return end
    local char = LocalPlayer.Character
    if not char or typeof(worldPos) ~= "Vector3" then return end
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local root  = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- pitch (haut/bas) : la difference de hauteur entre nous et la cible
    local dir  = worldPos - root.Position
    local flat = Vector3.new(dir.X, 0, dir.Z).Magnitude
    if flat < 0.05 then return end
    local pitch = math.atan2(dir.Y, flat)
    pitch = math.clamp(pitch, -1.2, 1.2)

    local function bend(motor, factor)
        if not motor or not motor:IsA("Motor6D") then return end
        if WeaponAim.saved[motor] == nil then WeaponAim.saved[motor] = motor.C0 end
        motor.C0 = WeaponAim.saved[motor] * CFrame.Angles(pitch * factor, 0, 0)
    end

    if torso then
        bend(torso:FindFirstChild("Neck"), 0.55)
        bend(torso:FindFirstChild("Right Shoulder"), 0.9)
        bend(torso:FindFirstChild("Left Shoulder"), 0.9)
        bend(torso:FindFirstChild("RightShoulder"), 0.9)
        bend(torso:FindFirstChild("LeftShoulder"), 0.9)
    end
    local waistHost = char:FindFirstChild("UpperTorso")
    if waistHost then bend(waistHost:FindFirstChild("Waist"), 0.35) end
end

function WeaponAim.release()
    for motor, c0 in pairs(WeaponAim.saved) do
        pcall(function()
            if motor and motor.Parent then motor.C0 = c0 end
        end)
    end
    WeaponAim.saved = {}
end


RunService:BindToRenderStep("LegitCamHardLock", Enum.RenderPriority.Camera.Value + 50, function()
    if not isAimKeyDown() and not spinAimLocked then
        camLockPos = nil
        WeaponAim.release()
        WeaponAim.releaseMouse()
        releaseBodyLock()
        return
    end

    -- Clic droit maintenu : le corps suit la camera meme SANS cible lockee
    if not camLockPos then
        bodyFollowCamera()
        return
    end

    -- 1) Re-lock camera sur la tete APRES la camera Roblox.
    --    (la souris ne peut plus decrocher la visee)
    local camPos = Camera.CFrame.Position
    if (camLockPos - camPos).Magnitude > 0.05 then
        Camera.CFrame = CFrame.new(camPos, camLockPos)
    end

    -- 1bis) LA SOURIS suit la tete -> l'arme du jeu vise vraiment l'ennemi
    WeaponAim.lockMouseOn(camLockPos)   -- curseur BLOQUE sur la tete
    WeaponAim.pointMouseAt(camLockPos)
    WeaponAim.alignUpperBody(camLockPos)


    -- 2) Ensuite le corps copie le yaw de cette camera lockee.
    bodyFollowCamera()
end)

-- DERNIER MOT : on repasse en priorite "Last", donc APRES tous les
-- scripts du jeu (arme, camera custom, character controller). C'est ce
-- qui empeche le corps de repartir dans la direction de la souris.
RunService:BindToRenderStep("CrazyBodyLockLast", Enum.RenderPriority.Last.Value + 1, function()
    if not isAimKeyDown() and not spinAimLocked then return end
    if not camLockPos then bodyFollowCamera() return end
    local camPos = Camera.CFrame.Position
    if (camLockPos - camPos).Magnitude > 0.05 then
        Camera.CFrame = CFrame.new(camPos, camLockPos)
    end
    -- re-verrouillage APRES tous les scripts du jeu : meme si le jeu
    -- (ou ta main) bouge la souris, elle revient sur la tete.
    WeaponAim.lockMouseOn(camLockPos)
    bodyFollowCamera()
end)

-- Re-application avant/apres physique : si Roblox/arme/anim essaie de
-- tourner ton perso, on remet le corps dans l'axe de la camera lockee.
RunService.Stepped:Connect(function()
    if not bodyLockActive then return end
    bodyFollowCamera()
end)

RunService.Heartbeat:Connect(function()
    if not bodyLockActive then return end
    bodyFollowCamera()
end)

-- ════════════════════════════════════════════════════════════
--  BOUCLE DE TIR → exécutée JUSTE APRÈS la caméra
--  BindToRenderStep priorité +50 : APRÈS rotation caméra
--  Donc Mouse.Hit est bien seté.
-- ════════════════════════════════════════════════════════════
RunService:BindToRenderStep("LegitShoot", Enum.RenderPriority.Camera.Value + 50, function()
    if not Cfg.LegitTrigger.Enabled then return end
    if not isAimKeyDown() then return end
    if not lpLockTarget then return end
    if not lpSilentActive then return end

    local head = getHead(lpLockTarget)
    if not head or not isAlive(lpLockTarget) then return end

    -- ── 1er TIR (nouveau lock cette frame) : INSTANTANÉ, PAS DE ATTENTE ──
    if lpLockedThisFrame then
        lpLockedThisFrame = false
        pcall(function() mouse1click() end)
        lpCooldown = true
        task.spawn(function()
            task.wait(Cfg.LegitTrigger.Delay)
            lpCooldown = false
        end)
        return
    end

    -- Tirs suivants : respect cooldown
    if lpCooldown then return end

    lpCooldown = true
    pcall(function() mouse1click() end)
    task.spawn(function()
        task.wait(Cfg.LegitTrigger.Delay)
        lpCooldown = false
    end)
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

-- ─────────────────────────────────────────────────────
--  Indicateurs pour SILENT AIM (WallShot)
-- ─────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────
--  Indicateurs pour LEGIT POWER (box sur la TÊTE)
-- ─────────────────────────────────────────────────────
local LPboxT = Drawing.new("Line")  -- top
LPboxT.Visible = false; LPboxT.Thickness = 3
LPboxT.Color = Color3.fromRGB(255, 0, 80); LPboxT.Transparency = 0

local LPboxB = Drawing.new("Line")  -- bottom
LPboxB.Visible = false; LPboxB.Thickness = 3
LPboxB.Color = Color3.fromRGB(255, 0, 80); LPboxB.Transparency = 0

local LPboxL = Drawing.new("Line")  -- left
LPboxL.Visible = false; LPboxL.Thickness = 3
LPboxL.Color = Color3.fromRGB(255, 0, 80); LPboxL.Transparency = 0

local LPboxR = Drawing.new("Line")  -- right
LPboxR.Visible = false; LPboxR.Thickness = 3
LPboxR.Color = Color3.fromRGB(255, 0, 80); LPboxR.Transparency = 0

-- Label ROUGE GROS pour LEGIT POWER lock
local LPlabel = Drawing.new("Text")
LPlabel.Visible = false; LPlabel.Size = 17
LPlabel.Font = Drawing.Fonts.UI; LPlabel.Outline = true
LPlabel.Center = true; LPlabel.Color = Color3.fromRGB(255, 30, 90)
LPlabel.Text = " TÊTE LOCKÉE"

RunService.RenderStepped:Connect(function()
    -- ── Cache TOUS les indicateurs d'abord ──
    SAcross1.Visible = false; SAcross2.Visible = false
    SAcircle.Visible = false; SAline.Visible = false
    SAlabel.Visible = false
    LPboxT.Visible = false; LPboxB.Visible = false
    LPboxL.Visible = false; LPboxR.Visible = false
    LPlabel.Visible = false

    -- Quelle cible pour l'indicateur visuel ?
    -- Priorité : Legit Power lock > WallShot Silent Aim
    local visTarget = nil
    local isLegit = false
    if Cfg.LegitTrigger.Enabled and lpLockTarget and isAlive(lpLockTarget)
       and isAimKeyDown() then  -- helper souris + clavier (avant IsMouseButtonPressed buggé si KeyCode)
        visTarget = lpLockTarget
        isLegit = true
    elseif Cfg.WallShot.Enabled and silentTarget then
        visTarget = silentTarget
    end

    if not visTarget then return end

    local head = getHead(visTarget)
    if not head or not isAlive(visTarget) then return end

    local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not (onScreen and sp.Z > 0) then return end

    local headSP = Vector2.new(sp.X, sp.Y)
    local mousePos = UserInputService:GetMouseLocation()

    -- ═══════════════════════════════════════
    --  MODE LEGIT POWER : BOITE ROUGE + TEXTE GROS
    -- ═══════════════════════════════════════
    if isLegit then
        -- ── Projette les 8 COINS de la bounding box de la Head sur l'écran ──
        local sx, sy = head.Size.X, head.Size.Y, head.Size.Z
        local corners = {
            head.CFrame * CFrame.new( sx/2,  sy/2,  sz/2),
            head.CFrame * CFrame.new( sx/2,  sy/2, -sz/2),
            head.CFrame * CFrame.new( sx/2, -sy/2,  sz/2),
            head.CFrame * CFrame.new( sx/2, -sy/2, -sz/2),
            head.CFrame * CFrame.new(-sx/2,  sy/2,  sz/2),
            head.CFrame * CFrame.new(-sx/2,  sy/2, -sz/2),
            head.CFrame * CFrame.new(-sx/2, -sy/2,  sz/2),
            head.CFrame * CFrame.new(-sx/2, -sy/2, -sz/2),
        }
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        for _, c in ipairs(corners) do
            local p, ok = Camera:WorldToViewportPoint(c.Position)
            if ok and p.Z > 0 then
                if p.X < minX then minX = p.X end
                if p.X > maxX then maxX = p.X end
                if p.Y < minY then minY = p.Y end
                if p.Y > maxY then maxY = p.Y end
            end
        end
        -- Si les 8 coins n'ont pas pu être projetés → fallback carré fixe
        if minX == math.huge then
            local fs = 36  -- fallback size
            minX = headSP.X - fs; maxX = headSP.X + fs
            minY = headSP.Y - fs; maxY = headSP.Y + fs
        else
            -- Petit padding pour être sûr que la box englobe bien
            local padX = (maxX - minX) * 0.15
            local padY = (maxY - minY) * 0.15
            minX = minX - padX; maxX = maxX + padX
            minY = minY - padY; maxY = maxY + padY
        end

        -- Dessine la BOITE (4 côtés ROUGES ÉPAIS)
        local TL = Vector2.new(minX, minY)
        local TR = Vector2.new(maxX, minY)
        local BL = Vector2.new(minX, maxY)
        local BR = Vector2.new(maxX, maxY)

        LPboxT.From = TL; LPboxT.To = TR; LPboxT.Visible = true
        LPboxB.From = BL; LPboxB.To = BR; LPboxB.Visible = true
        LPboxL.From = TL; LPboxL.To = BL; LPboxL.Visible = true
        LPboxR.From = TR; LPboxR.To = BR; LPboxR.Visible = true

        -- Texte GROS " TÊTE LOCKÉE" AU DESSUS
        LPlabel.Position = Vector2.new(headSP.X, minY - 24)
        LPlabel.Visible = true
        return
    end

    -- ═══════════════════════════════════════
    --  ● MODE SILENT AIM (WallShot) : classique
    -- ═══════════════════════════════════════
    local sz = 10 -- taille de la croix
    -- Croix sur la tête
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
    SAlabel.Text = "● SILENT LOCK"
    SAlabel.Color = Color3.fromRGB(255,60,60)
    SAlabel.Position = Vector2.new(headSP.X, headSP.Y - 22)
    SAlabel.Visible = true
end)

-- ══════════════════════════════════════════════════════
-- SILENT AIM HOOK — compatible Xeno + tous exécuteurs
-- Ta souris bouge PAS — balles vont sur la tête ennemie
-- Ajoute aussi le support de LEGIT POWER LOCK
-- ══════════════════════════════════════════════════════
local silentHookActive = false

-- newcclosure est dispo sur Xeno mais on vérifie quand même
local wrapFn = (typeof(newcclosure) == "function") and newcclosure or function(f) return f end

local hookSuccess = pcall(function()
    local origIndex = hookmetamethod(Mouse, "__index", wrapFn(function(self, key)
        -- PRIORITÉ 1 : LEGIT POWER lock (si clic droit maintenu)
        local legitLockedHead = nil
        if Cfg.LegitTrigger.Enabled and lpLockTarget and isAlive(lpLockTarget)
           and isAimKeyDown() then
            legitLockedHead = getHead(lpLockTarget)
        end

        -- PRIORITÉ 2 : WallShot Silent Aim
        local saHead = nil
        if Cfg.WallShot.Enabled and silentTarget then
            saHead = getHead(silentTarget)
            if saHead and not isAlive(silentTarget) then saHead = nil end
        end

        local activeHead = legitLockedHead or saHead

        if activeHead then
            if key == "Hit" then
                return CFrame.new(activeHead.Position)
            elseif key == "UnitRay" then
                local origin = Camera.CFrame.Position
                local dir = (activeHead.Position - origin).Unit
                return Ray.new(origin, dir * 999)
            elseif key == "Target" then
                return activeHead
            end
        end
        return origIndex(self, key)
    end))
    silentHookActive = true
end)

if not hookSuccess then
    -- Si hookmetamethod pas dispo : fallback Camera snap
    RunService.RenderStepped:Connect(function()
        local activeHead = nil
        if Cfg.LegitTrigger.Enabled and lpLockTarget and isAlive(lpLockTarget) then
            activeHead = getHead(lpLockTarget)
        elseif Cfg.WallShot.Enabled and silentTarget then
            activeHead = getHead(silentTarget)
            if activeHead and not isAlive(silentTarget) then activeHead = nil end
        end
        if not activeHead then return end
        local camPos = Camera.CFrame.Position
        local dir = (activeHead.Position - camPos).Unit
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
        Filled = mkDraw("Square", { Filled=true,  Thickness=0,   Visible=false, Color=Cfg.Colors.ESP, Transparency=0.55 }),
        Box    = mkDraw("Square", { Filled=false, Thickness=1.4, Visible=false, Color=Cfg.Colors.ESP }),
        BG     = mkDraw("Square", { Filled=true,  Visible=false, Color=Color3.fromRGB(20,20,20), Transparency=0.45 }),
        HpBG   = mkDraw("Square", { Filled=true,  Visible=false, Color=Color3.fromRGB(20,20,20) }),
        HpBar  = mkDraw("Square", { Filled=true,  Visible=false, Color=Color3.fromRGB(80,255,80) }),
        Name   = mkDraw("Text",   { Size=13, Font=Drawing.Fonts.UI, Outline=true, Center=true, Visible=false, Color=Color3.fromRGB(255,255,255) }),
        Tracer = mkDraw("Line",   { Thickness=1.4, Visible=false, Color=Cfg.Colors.ESP }),
        Dist   = mkDraw("Text",   { Size=11, Font=Drawing.Fonts.UI, Outline=true, Center=true, Visible=false, Color=Cfg.Colors.ESP }),
        Skel   = {},
    }
    -- squelette : 14 segments max (R6 et R15 confondus)
    for i = 1, 16 do
        ESPObj[p].Skel[i] = mkDraw("Line", { Thickness=1.2, Visible=false, Color=Cfg.Colors.Skeleton })
    end
end

-- Paires d'os (R15 puis R6 en fallback)
local SKEL_R15 = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local SKEL_R6 = {
    {"Head","Torso"},
    {"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}

local function removeESP(p)
    if not ESPObj[p] then return end
    for k, d in pairs(ESPObj[p]) do
        if k == "Skel" then
            for _, l in ipairs(d) do pcall(function() l:Remove() end) end
        else
            pcall(function() d:Remove() end)
        end
    end
    ESPObj[p] = nil
end

local function hideESP(p)
    if not ESPObj[p] then return end
    for k, d in pairs(ESPObj[p]) do
        if k == "Skel" then
            for _, l in ipairs(d) do l.Visible = false end
        else
            d.Visible = false
        end
    end
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

        -- Box remplie (en DESSOUS de la box contour pour pas cacher les bords)
        obj.Filled.Position = Vector2.new(bx, by)
        obj.Filled.Size     = Vector2.new(W, H)
        obj.Filled.Color    = Cfg.Colors.ESP
        obj.Filled.Transparency = math.clamp(1 - Cfg.ESP.FilledAlpha, 0, 1)
        obj.Filled.Visible  = Cfg.ESP.FilledBox

        -- Box contour
        obj.Box.Position = Vector2.new(bx, by)
        obj.Box.Size     = Vector2.new(W, H)
        obj.Box.Color    = Cfg.Colors.ESP
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

        -- Tracer (ligne reliee au joueur, depuis le bas de l'ecran)
        local vp = Camera.ViewportSize
        obj.Tracer.From    = Vector2.new(vp.X / 2, vp.Y)
        obj.Tracer.To      = Vector2.new(topSP.X, botSP.Y)
        obj.Tracer.Color   = Cfg.Colors.ESP
        obj.Tracer.Visible = Cfg.ESP.Tracers

        -- Squelette (os relies entre eux)
        do
            local idx = 0
            if Cfg.ESP.Skeleton then
                local set = char:FindFirstChild("UpperTorso") and SKEL_R15 or SKEL_R6
                for _, pair in ipairs(set) do
                    local a = char:FindFirstChild(pair[1])
                    local b = char:FindFirstChild(pair[2])
                    if a and b then
                        local sa, oa = toScreen(a.Position)
                        local sb, ob = toScreen(b.Position)
                        if oa and ob then
                            idx = idx + 1
                            local ln = obj.Skel[idx]
                            if ln then
                                ln.From    = Vector2.new(sa.X, sa.Y)
                                ln.To      = Vector2.new(sb.X, sb.Y)
                                ln.Color   = Cfg.Colors.Skeleton
                                ln.Visible = true
                            end
                        end
                    end
                end
            end
            for i = idx + 1, #obj.Skel do obj.Skel[i].Visible = false end
        end

        -- Distance
        obj.Dist.Text     = math.floor(dist3D) .. "m"
        obj.Dist.Position = Vector2.new(topSP.X, botSP.Y + 2)
        obj.Dist.Visible  = Cfg.ESP.Distance
    end
end)

Players.PlayerRemoving:Connect(removeESP)

-- ══════════════════════════════════════════════════════
--   RAPID FIRE + WALL SHOT — Hook précis sur 
--   Basé sur le vrai code de ItemLibrary :
--   - QuickAttack = RemoteEvent de tir
--   - ShootCooldown = cooldown par arme
--   - IsRaycast = true pour la plupart des armes
-- ══════════════════════════════════════════════════════
local rapidConn = nil
local namecallHook = nil

-- Récupère le RemoteEvent QuickAttack de 
local function getQuickAttack()
    local RS = game:GetService("ReplicatedStorage")
    local ok, re = pcall(function()
        return RS.Remotes.Replication.Fighter.QuickAttack
    end)
    return ok and re or nil
end

local function enableRapidFire()
    if rapidConn then return end

    -- Hook __namecall pour intercepter FireServer de QuickAttack
    -- et modifier les arguments pour 0 latence + wall shot
    local hooked = false
    pcall(function()
        local QuickAttack = getQuickAttack()
        if not QuickAttack then return end

        local wrapFn2 = (typeof(newcclosure) == "function") and newcclosure or function(f) return f end
        namecallHook = hookmetamethod(game, "__namecall", wrapFn2(function(self, ...)
            local method = getnamecallmethod and getnamecallmethod() or ""
            if self == QuickAttack and method == "FireServer" then
                if Cfg.RapidFire.Enabled or Cfg.WallShot.Enabled then
                    local args = {...}
                    -- args[1] = données du tir envoyées au serveur
                    if type(args[1]) == "table" then
                        -- 0 latence : force le timestamp à maintenant
                        if args[1].Timestamp then
                            args[1].Timestamp = tick()
                        end
                        -- Wall shot : remplace la position de hit par la tête ennemie
                        if Cfg.WallShot.Enabled and silentTarget then
                            local head = getHead(silentTarget)
                            if head and isAlive(silentTarget) then
                                if args[1].HitPosition then
                                    args[1].HitPosition = head.Position
                                end
                                if args[1].HitPart then
                                    args[1].HitPart = head
                                end
                                if args[1].Direction then
                                    local camPos = Camera.CFrame.Position
                                    args[1].Direction = (head.Position - camPos).Unit
                                end
                            end
                        end
                        return namecallHook(self, table.unpack(args))
                    end
                end
            end
            return namecallHook(self, ...)
        end))
        hooked = true
    end)

    -- Fallback : reset cooldowns dans les ValueObjects
    rapidConn = RunService.Heartbeat:Connect(function()
        if not Cfg.RapidFire.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end

        -- Reset cooldown dans ReplicatedStorage Fighter state
        local RS = game:GetService("ReplicatedStorage")
        pcall(function()
            local fighter = RS.Remotes.Replication.Fighter
            for _, v in ipairs(fighter:GetDescendants()) do
                local n = v.Name:lower()
                if (v:IsA("NumberValue") or v:IsA("IntValue")) and
                   (n:find("cool") or n:find("shoot") or n:find("timer")) then
                    v.Value = 0
                end
            end
        end)

        -- Stop animations reload
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    local n = track.Name:lower()
                    if n:find("reload") or n:find("recharge") then
                        track:Stop(0)
                    end
                end
            end
        end
    end)
end

local function disableRapidFire()
    if rapidConn then rapidConn:Disconnect(); rapidConn = nil end
    if namecallHook then
        pcall(function()
            hookmetamethod(game, "__namecall", namecallHook)
        end)
        namecallHook = nil
    end
end





-- ══════════════════════════════════════════════════════
--   TRIGGERBOT AMÉLIORÉ — tire dans la tête même si
--   la cible est sur le côté (pas besoin de viser)
--   Suffit que le mec soit dans le cercle FOV
-- ══════════════════════════════════════════════════════
local triggerCooldown = false

RunService.Heartbeat:Connect(function()
    if not Cfg.TriggerBot.Enabled then return end
    if triggerCooldown then return end

    local mousePos = UserInputService:GetMouseLocation()
    local myChar = LocalPlayer.Character
    local myHead = myChar and myChar:FindFirstChild("Head")

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not isAlive(p) then continue end
        if Cfg.AimBot.TeamCheck and isTeam(p) then continue end

        local head = getHead(p)
        if not head then continue end
        if myHead and (head.Position - myHead.Position).Magnitude < 3 then continue end

        local sp, on = toScreen(head.Position)
        if not on then continue end

        -- Distance depuis la SOURIS avec LE FOV DU TRIGGERBOT (son propre cercle orange)
        local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        if d < Cfg.TriggerBot.FOV then
            -- Cible dans le cercle → snap sur TÊTE + tir
            triggerCooldown = true
            doSnap(head.Position)
            task.wait(0.05)
            pcall(function() mouse1click() end)
            task.wait(Cfg.TriggerBot.Delay)
            triggerCooldown = false
            break
        end
    end
end)

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

-- ══════════════════════════════════════════════════════════
--   HIDE WEAPON — cache l'arme / bras devant l'écran
--   Universel : rend transparent en LOCAL uniquement
--   (LocalTransparencyModifier), donc aucun impact serveur
--   et ça marche sur tous les jeux (viewmodel dans Camera,
--   Tool équipé, dossiers de bras/arme).
-- ══════════════════════════════════════════════════════════
local hwTouched = {}

local function hwApply(inst, hide)
    if inst:IsA("BasePart") or inst:IsA("MeshPart") then
        if hide then
            hwTouched[inst] = true
            inst.LocalTransparencyModifier = 1
        else
            inst.LocalTransparencyModifier = 0
        end
    elseif inst:IsA("Decal") or inst:IsA("Texture") then
        if hide then
            hwTouched[inst] = true
            inst.Transparency = 1
        else
            inst.Transparency = 0
        end
    elseif inst:IsA("BillboardGui") or inst:IsA("ParticleEmitter")
        or inst:IsA("Beam") or inst:IsA("Trail") then
        if hide then
            hwTouched[inst] = true
            inst.Enabled = false
        else
            inst.Enabled = true
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not Cfg.HideWeapon.Enabled then
        if next(hwTouched) then
            for inst in pairs(hwTouched) do
                if inst and inst.Parent then pcall(hwApply, inst, false) end
            end
            hwTouched = {}
        end
        return
    end

    -- viewmodel : la plupart des jeux le parentent à la Camera
    for _, d in ipairs(Camera:GetDescendants()) do
        pcall(hwApply, d, true)
    end

    -- Tool équipé dans le personnage
    local c = LocalPlayer.Character
    if c then
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") or t:IsA("Model") then
                for _, d in ipairs(t:GetDescendants()) do
                    pcall(hwApply, d, true)
                end
                pcall(hwApply, t, true)
            end
        end
    end
end)

-- (VISION et FREE CAM supprimes en v2.5 a la demande)

-- ══════════════════════════════
--         SPEED BOOST
-- ══════════════════════════════
-- Rivals reset WalkSpeed côté serveur — on force en boucle
-- ET on utilise BodyVelocity pour contourner le reset serveur
local speedBV = nil

RunService.Heartbeat:Connect(function()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not h or not root then return end

    if Cfg.Speed.Enabled then
        -- Force WalkSpeed chaque frame (contourne le reset serveur)
        h.WalkSpeed = Cfg.Speed.Value
        -- Double la vitesse via le root aussi
        root:SetNetworkOwner(LocalPlayer)
    else
        if h.WalkSpeed ~= 16 then
            h.WalkSpeed = 16
        end
    end
end)

-- ══════════════════════════════════════════════════════
--                    GUI — STYLE Z3US
-- ══════════════════════════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name = "PlayerFrame_" .. math.random(1000,9999)
SG.ResetOnSpawn     = false
SG.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset   = true
local sgParent
local ok = pcall(function() sgParent = game:GetService("CoreGui") end)
if not ok then sgParent = LocalPlayer:WaitForChild("PlayerGui") end
SG.Parent = sgParent

-- ══════════════════════════════
--   PROFIL JOUEUR (bas gauche)
-- ══════════════════════════════
local PROF = Instance.new("Frame", SG)
PROF.Name = "CrazyProfile"
PROF.AnchorPoint = Vector2.new(0, 1)
PROF.Position = UDim2.new(0, -240, 1, -18)
PROF.Size = UDim2.new(0, 216, 0, 62)
PROF.BackgroundColor3 = Color3.fromRGB(10, 16, 24)
PROF.BackgroundTransparency = 0.25
PROF.BorderSizePixel = 0
do
    Instance.new("UICorner", PROF).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", PROF)
    st.Color = Color3.fromRGB(70, 120, 150)
    st.Transparency = 0.45
    st.Thickness = 1
end

local PROF_AVBG = Instance.new("Frame", PROF)
PROF_AVBG.AnchorPoint = Vector2.new(0, 0.5)
PROF_AVBG.Position = UDim2.new(0, 9, 0.5, 0)
PROF_AVBG.Size = UDim2.new(0, 44, 0, 44)
PROF_AVBG.BackgroundColor3 = Color3.fromRGB(16, 27, 38)
PROF_AVBG.BorderSizePixel = 0
Instance.new("UICorner", PROF_AVBG).CornerRadius = UDim.new(1, 0)

local PROF_AV = Instance.new("ImageLabel", PROF_AVBG)
PROF_AV.Size = UDim2.new(1, 0, 1, 0)
PROF_AV.BackgroundTransparency = 1
PROF_AV.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150"
Instance.new("UICorner", PROF_AV).CornerRadius = UDim.new(1, 0)
do
    local st = Instance.new("UIStroke", PROF_AVBG)
    st.Color = Color3.fromRGB(255, 255, 255)
    st.Transparency = 0.6
    st.Thickness = 1
end

-- fallback si rbxthumb ne charge pas
task.spawn(function()
    task.wait(2)
    if PROF_AV and PROF_AV.Parent and not PROF_AV.IsLoaded then
        pcall(function()
            local content = Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
            PROF_AV.Image = content
        end)
    end
end)

local PROF_NAME = Instance.new("TextLabel", PROF)
PROF_NAME.Position = UDim2.new(0, 62, 0, 12)
PROF_NAME.Size = UDim2.new(1, -72, 0, 17)
PROF_NAME.BackgroundTransparency = 1
PROF_NAME.Text = tostring(LocalPlayer.DisplayName)
PROF_NAME.TextColor3 = Color3.fromRGB(255, 255, 255)
PROF_NAME.TextSize = 14
PROF_NAME.Font = Enum.Font.GothamBold
PROF_NAME.TextXAlignment = Enum.TextXAlignment.Left
PROF_NAME.TextTruncate = Enum.TextTruncate.AtEnd

local PROF_USER = Instance.new("TextLabel", PROF)
PROF_USER.Position = UDim2.new(0, 62, 0, 30)
PROF_USER.Size = UDim2.new(1, -72, 0, 15)
PROF_USER.BackgroundTransparency = 1
PROF_USER.Text = "@" .. tostring(LocalPlayer.Name)
PROF_USER.TextColor3 = Color3.fromRGB(150, 190, 210)
PROF_USER.TextSize = 11
PROF_USER.Font = Enum.Font.Gotham
PROF_USER.TextXAlignment = Enum.TextXAlignment.Left
PROF_USER.TextTruncate = Enum.TextTruncate.AtEnd

-- petit point vert "connecté"
local PROF_DOT = Instance.new("Frame", PROF)
PROF_DOT.AnchorPoint = Vector2.new(1, 0.5)
PROF_DOT.Position = UDim2.new(1, -10, 0.5, 0)
PROF_DOT.Size = UDim2.new(0, 7, 0, 7)
PROF_DOT.BackgroundColor3 = Color3.fromRGB(150, 220, 245)
PROF_DOT.BorderSizePixel = 0
Instance.new("UICorner", PROF_DOT).CornerRadius = UDim.new(1, 0)
task.spawn(function()
    while PROF_DOT and PROF_DOT.Parent do
        TweenService:Create(PROF_DOT, TweenInfo.new(0.8), {BackgroundTransparency = 0.7}):Play()
        task.wait(0.85)
        TweenService:Create(PROF_DOT, TweenInfo.new(0.8), {BackgroundTransparency = 0}):Play()
        task.wait(0.85)
    end
end)

-- entrée animée du profil
TweenService:Create(PROF, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
    Position = UDim2.new(0, 18, 1, -18)
}):Play()



-- MAIN WINDOW
local WIN = Instance.new("Frame")
WIN.Size              = UDim2.new(0, 560, 0, 400)
WIN.Position          = UDim2.new(0.5, -280, 0.5, -200)
WIN.BackgroundColor3  = Color3.fromRGB(10, 16, 24)
WIN.BackgroundTransparency = 0.25
WIN.BorderSizePixel   = 0
WIN.ClipsDescendants  = true
WIN.Parent            = SG
do
    local c = Instance.new("UICorner", WIN); c.CornerRadius = UDim.new(0,10)
    local s = Instance.new("UIStroke", WIN)
    s.Color = Color3.fromRGB(90, 150, 180); s.Thickness = 1.2; s.Transparency = 0.3
end

-- ══════════════════════════════
--   IMAGE DE FOND DU PANEL (semi-transparente)
-- ══════════════════════════════
local PANELBG = Instance.new("ImageLabel", WIN)
PANELBG.Name = "CrazyPanelBG"
PANELBG.Size = UDim2.new(1, 0, 1, 0)
PANELBG.Position = UDim2.new(0, 0, 0, 0)
PANELBG.BackgroundTransparency = 1
PANELBG.BorderSizePixel = 0
PANELBG.Image = Cfg.Background.Id
PANELBG.ScaleType = Enum.ScaleType.Crop
PANELBG.ImageTransparency = Cfg.Background.Alpha
PANELBG.Visible = Cfg.Background.Enabled
PANELBG.ZIndex = 0
do
    local c = Instance.new("UICorner", PANELBG); c.CornerRadius = UDim.new(0, 10)
end

local onPanelBGChanged = nil  -- hook defini plus bas (applyPanelTransparency)

local function refreshPanelBG()
    PANELBG.Image = Cfg.Background.Id
    PANELBG.ImageTransparency = math.clamp(Cfg.Background.Alpha, 0, 1)
    PANELBG.Visible = Cfg.Background.Enabled
    if onPanelBGChanged then pcall(onPanelBGChanged) end
end

-- TITLE BAR
local TBAR = Instance.new("Frame")
TBAR.Size             = UDim2.new(1,0,0,38)
TBAR.BackgroundColor3 = Color3.fromRGB(14, 24, 34)
TBAR.BorderSizePixel  = 0
TBAR.Parent           = WIN
do
    local c = Instance.new("UICorner", TBAR); c.CornerRadius = UDim.new(0,10)
    local f = Instance.new("Frame", TBAR) -- fix bottom corners
    f.Size = UDim2.new(1,0,0,10); f.Position = UDim2.new(0,0,1,-10)
    f.BackgroundColor3 = Color3.fromRGB(14,24,34); f.BorderSizePixel=0
end

-- ══════════════════════════════
--   LOGO CRAZY HUB (en haut a gauche du panel)
--   >> Remplace l'ID ci-dessous par l'ID de TON image uploadee sur Roblox
-- ══════════════════════════════
local CRAZY_LOGO_ID = "rbxassetid://124641235285436"   -- ex: "rbxassetid://1234567890"

local LOGOBG = Instance.new("Frame", TBAR)
LOGOBG.Name = "CrazyLogo"
LOGOBG.AnchorPoint = Vector2.new(0, 0.5)
LOGOBG.Position = UDim2.new(0, 10, 0.5, 0)
LOGOBG.Size = UDim2.new(0, 26, 0, 26)
LOGOBG.BackgroundColor3 = Color3.fromRGB(6, 12, 18)
LOGOBG.BorderSizePixel = 0
LOGOBG.ClipsDescendants = true
Instance.new("UICorner", LOGOBG).CornerRadius = UDim.new(1, 0)
do
    local st = Instance.new("UIStroke", LOGOBG)
    st.Color = Color3.fromRGB(226, 246, 255)
    st.Thickness = 1
    st.Transparency = 0.35
end

local LOGOIMG = Instance.new("ImageLabel", LOGOBG)
LOGOIMG.Size = UDim2.new(1, 0, 1, 0)
LOGOIMG.BackgroundTransparency = 1
LOGOIMG.Image = CRAZY_LOGO_ID
LOGOIMG.ScaleType = Enum.ScaleType.Crop   -- cadrage propre, pas de deformation
LOGOIMG.ImageTransparency = 0
Instance.new("UICorner", LOGOIMG).CornerRadius = UDim.new(1, 0)

-- fallback : si aucune image valide, on affiche le petit point lumineux
if CRAZY_LOGO_ID == "rbxassetid://0" or CRAZY_LOGO_ID == "" then
    LOGOIMG.ImageTransparency = 1
    local dot = Instance.new("Frame", LOGOBG)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.new(0.5, 0, 0.5, 0)
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.BackgroundColor3 = Color3.fromRGB(226, 246, 255)
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
end

local TITLE = Instance.new("TextLabel", TBAR)
TITLE.Size             = UDim2.new(1,-100,1,0)
TITLE.Position         = UDim2.new(0,44,0,0)
TITLE.BackgroundTransparency = 1
TITLE.Text             = "CRAZY HUB"
TITLE.TextColor3       = Color3.fromRGB(255,255,255)
TITLE.TextSize         = 14
TITLE.Font             = Enum.Font.GothamBold
TITLE.TextXAlignment   = Enum.TextXAlignment.Left

local SUBTITLE = Instance.new("TextLabel", TBAR)
SUBTITLE.Size          = UDim2.new(1,-100,1,0)
SUBTITLE.Position      = UDim2.new(0,130,0,0)
SUBTITLE.BackgroundTransparency = 1
SUBTITLE.Text          = " | UNIVERSAL AIME BOT"
SUBTITLE.TextColor3    = Color3.fromRGB(150,190,210)
SUBTITLE.TextSize      = 13
SUBTITLE.Font          = Enum.Font.Gotham
SUBTITLE.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize btn (main panel)
local MINBTN = Instance.new("TextButton", TBAR)
MINBTN.Size   = UDim2.new(0,26,0,26)
MINBTN.Position = UDim2.new(1,-68,0.5,-13)
MINBTN.BackgroundColor3 = Color3.fromRGB(40,66,88)
MINBTN.Text   = "—"
MINBTN.TextColor3 = Color3.fromRGB(255,255,255)
MINBTN.TextSize   = 16
MINBTN.Font   = Enum.Font.GothamBold
MINBTN.BorderSizePixel = 0
Instance.new("UICorner",MINBTN).CornerRadius = UDim.new(0,5)

local minimized = false
local WINprevSize = WIN.Size
local WINprevPos  = WIN.Position
MINBTN.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        WINprevSize = WIN.Size
        WINprevPos  = WIN.Position
        TweenService:Create(WIN, TweenInfo.new(0.18), {
            Size = UDim2.new(0, 250, 0, 38),
            Position = UDim2.new(0, 20, 0, 20),
        }):Play()
    else
        TweenService:Create(WIN, TweenInfo.new(0.18), {
            Size = WINprevSize,
            Position = WINprevPos,
        }):Play()
    end
end)

-- Close btn
local CLOSEBTN = Instance.new("TextButton", TBAR)
CLOSEBTN.Size   = UDim2.new(0,26,0,26)
CLOSEBTN.Position = UDim2.new(1,-34,0.5,-13)
CLOSEBTN.BackgroundColor3 = Color3.fromRGB(40,70,95)
CLOSEBTN.Text   = ""
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
SIDEBAR.Size             = UDim2.new(0, 148, 1, -38)
SIDEBAR.Position         = UDim2.new(0, 0, 0, 38)
SIDEBAR.BackgroundColor3 = Color3.fromRGB(11, 18, 27)
SIDEBAR.BorderSizePixel  = 0

local SBList = Instance.new("UIListLayout", SIDEBAR)
SBList.Padding = UDim.new(0,3)
local SBPad = Instance.new("UIPadding", SIDEBAR)
SBPad.PaddingTop = UDim.new(0,8)
SBPad.PaddingLeft = UDim.new(0,6)
SBPad.PaddingRight = UDim.new(0,6)

-- CONTENT AREA
local CONTENT = Instance.new("Frame", WIN)
CONTENT.Size             = UDim2.new(1,-148,1,-38)
CONTENT.Position         = UDim2.new(0,148,0,38)
CONTENT.BackgroundColor3 = Color3.fromRGB(7, 12, 19)
CONTENT.BorderSizePixel  = 0

-- Separator line
local SEP = Instance.new("Frame", WIN)
SEP.Size   = UDim2.new(0,1,1,-38)
SEP.Position = UDim2.new(0,148,0,38)
SEP.BackgroundColor3 = Color3.fromRGB(38,62,80)
SEP.BorderSizePixel  = 0

-- ════════════════════════════════
--   (tabs est declare ICI : applyPanelTransparency l'utilise)
local tabs = {}
-- ════════════════════════════════
--   TRANSPARENCE GÉNÉRALE PANEL
--   Applique la transparence SUR TOUS LES ÉLÉMENTS
-- ════════════════════════════════
local currentPanelAlpha = 0  -- OPAQUE par defaut (la transparence = option dans Settings)

local function applyPanelTransparency(alpha)
    alpha = math.clamp(tonumber(alpha) or 0, 0, 1)
    currentPanelAlpha = alpha
    local imgOn = Cfg.Background and Cfg.Background.Enabled
    -- Le slider pilote TOUJOURS la transparence.
    -- Si une image de fond est active, on ajoute un bonus pour la laisser voir.
    local bonus     = imgOn and 0.35 or 0
    local layerAlpha = math.clamp(alpha + bonus, 0, 1)       -- sidebar / content
    local rowAlpha   = math.clamp(alpha + bonus * 0.5, 0, 1) -- rows / infobox / tbar

    -- Fenêtre principale (0 = opaque par defaut)
    WIN.BackgroundTransparency = alpha
    -- Title bar + son fix bottom corners
    TBAR.BackgroundTransparency = rowAlpha
    for _, c in ipairs(TBAR:GetChildren()) do
        if c:IsA("Frame") and not c:IsA("TextButton") and not c:IsA("UICorner") then
            c.BackgroundTransparency = rowAlpha
        end
    end
    -- Sidebar + Content
    SIDEBAR.BackgroundTransparency = layerAlpha
    CONTENT.BackgroundTransparency = layerAlpha
    -- Stroke
    local stroke = WIN:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Transparency = math.clamp(alpha + 0.1, 0, 1)
    end

    -- Bulles de categories (sidebar) : restent lisibles
    for _, tab in pairs(tabs) do
        if tab.btn then
            local on = tab.bar and tab.bar.BackgroundTransparency < 0.5
            tab.btn.BackgroundTransparency = on and math.min(alpha, 0.3) or math.clamp(0.72 + alpha * 0.2, 0, 1)

        end
    end

    -- Tous les tabs : ScrollFrame transparents (toujours)
    for _, tab in pairs(tabs) do
        if not tab.frame then continue end
        tab.frame.BackgroundTransparency = 1
        for _, c in ipairs(tab.frame:GetDescendants()) do
            if c:IsA("Frame") then
                local isSmallDecor = c.AbsoluteSize.X > 0 and c.AbsoluteSize.Y > 0
                                     and (c.AbsoluteSize.Y <= 20 or c.AbsoluteSize.X <= 50)
                if not isSmallDecor then
                    c.BackgroundTransparency = rowAlpha
                end
            end
            if c:IsA("TextLabel") and c.BackgroundTransparency < 1 then
                c.BackgroundTransparency = rowAlpha
            end
        end
    end
end


-- Re-applique quand on toggle / change l'image de fond
onPanelBGChanged = function()
    applyPanelTransparency(currentPanelAlpha)
end

-- Appliquer la transparence au démarrage
task.defer(function()
    task.wait(0.2)
    applyPanelTransparency(currentPanelAlpha)
end)

-- ══════════════════
--   TAB SYSTEM
-- ══════════════════
local activeTab = nil

local tabDefs = {
    { name = "Legit Power", icon = "◉" },
    { name = "TriggerBot",  icon = "◆" },
    { name = "Rage",        icon = "▲" },
    { name = "Visuals",     icon = "◈" },
    { name = "Player",      icon = "●" },
    { name = "Teleport",    icon = "⊕" },
    { name = "World",       icon = "◎" },
    { name = "Misc",        icon = "≡" },
    { name = "Settings",    icon = "■" },
    { name = "Crosshair",   icon = "✛" },
}

local function makeScroll()
    local sf = Instance.new("ScrollingFrame", CONTENT)
    sf.Size                = UDim2.new(1,0,1,0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel     = 0
    sf.ScrollBarThickness  = 2
    sf.ScrollBarImageColor3 = Color3.fromRGB(110,160,190)
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
            BackgroundTransparency = on and 0 or 0.72,
        }):Play()
        if t.stroke then
            TweenService:Create(t.stroke, TweenInfo.new(0.15), {
                Transparency = 0,
                Thickness = on and 2 or 1.5,
            }):Play()
        end
        TweenService:Create(t.bar, TweenInfo.new(0.15), {
            BackgroundTransparency = on and 0 or 1,
            Size = on and UDim2.new(0,3,0,18) or UDim2.new(0,3,0,0),
        }):Play()
        if t.ico then t.ico.TextColor3 = on and Color3.fromRGB(120,215,255) or Color3.fromRGB(96,132,158) end
        if t.icoBox then t.icoBox.BackgroundColor3 = on and Color3.fromRGB(24,54,78) or Color3.fromRGB(18,32,46) end
        t.lbl.TextColor3 = on and Color3.fromRGB(232,248,255) or Color3.fromRGB(140,176,200)
        t.lbl.Font       = on and Enum.Font.GothamBold or Enum.Font.Gotham
        TweenService:Create(t.lbl, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, on and 22 or 16, 0, 0)
        }):Play()

        -- ANIMATION DE CHANGEMENT DE CATEGORIE : slide + fade
        if on then
            t.frame.Visible = true
            t.frame.Position = UDim2.new(0, 18, 0, 0)
            for _, c in ipairs(t.frame:GetDescendants()) do
                if c:IsA("TextLabel") or c:IsA("TextButton") then
                    c.TextTransparency = 1
                    TweenService:Create(c, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
                end
            end
            TweenService:Create(t.frame, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0, 0)
            }):Play()
        else
            t.frame.Visible = false
        end
    end
end

for _, td in ipairs(tabDefs) do
    local sf = makeScroll()

    local btn = Instance.new("TextButton", SIDEBAR)
    btn.Size             = UDim2.new(1,0,0,34)
    btn.BackgroundColor3 = Color3.fromRGB(26,48,68)
    btn.BackgroundTransparency = 0.72   -- BULLE visible en permanence
    btn.AutoButtonColor  = false
    btn.Text             = ""
    btn.BorderSizePixel  = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1,0)  -- forme "bulle" (pilule)

    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color        = Color3.fromRGB(0,0,0)
    btnStroke.Thickness    = 1.5
    btnStroke.Transparency = 0

    -- barre active (gauche)
    local bar = Instance.new("Frame", btn)
    bar.Size                   = UDim2.new(0,3,0,0)
    bar.Position               = UDim2.new(0,6,0.5,0)
    bar.AnchorPoint            = Vector2.new(0,0.5)
    bar.BackgroundColor3       = Color3.fromRGB(120,215,255)
    bar.BackgroundTransparency = 1
    bar.BorderSizePixel        = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)


    -- (pas d'icone / emoji : texte seul)
    local icoBox, ico = nil, nil

    local lbl = Instance.new("TextLabel", btn)
    lbl.Size             = UDim2.new(1,-28,1,0)
    lbl.Position         = UDim2.new(0,16,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = td.name
    lbl.TextColor3       = Color3.fromRGB(140,176,200)
    lbl.TextSize         = 12
    lbl.Font             = Enum.Font.Gotham
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.TextTruncate     = Enum.TextTruncate.AtEnd

    btn.MouseEnter:Connect(function()
        if activeTab ~= td.name then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 0.35}):Play()
            TweenService:Create(btnStroke, TweenInfo.new(0.12), {Transparency = 0.35}):Play()
            TweenService:Create(lbl, TweenInfo.new(0.12), {TextColor3 = Color3.fromRGB(200,232,250)}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= td.name then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 0.72}):Play()
            TweenService:Create(btnStroke, TweenInfo.new(0.12), {Transparency = 0.75}):Play()
            TweenService:Create(lbl, TweenInfo.new(0.12), {TextColor3 = Color3.fromRGB(140,176,200)}):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function() activateTab(td.name) end)

    tabs[td.name] = { btn=btn, frame=sf, ico=ico, icoBox=icoBox, lbl=lbl, bar=bar, stroke=btnStroke }

end

-- ══════════════════════════════
--    UI COMPONENTS (réutilisables)
-- ══════════════════════════════
local function sectionTitle(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size             = UDim2.new(1,0,0,20)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text
    lbl.TextColor3       = Color3.fromRGB(226,246,255)
    lbl.TextSize         = 11
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    local sep = Instance.new("Frame", parent)
    sep.Size = UDim2.new(1,0,0,1)
    sep.BackgroundColor3 = Color3.fromRGB(38,62,80)
    sep.BorderSizePixel  = 0
    return lbl
end

local function toggle(parent, label, cfg, key, cb)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(1,0,0,34)
    row.BackgroundColor3 = Color3.fromRGB(16,27,38)
    row.BorderSizePixel  = 0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)

    local lbl = Instance.new("TextLabel",row)
    lbl.Size             = UDim2.new(1,-54,1,0)
    lbl.Position         = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency=1
    lbl.Text             = label
    lbl.TextColor3       = Color3.fromRGB(206,232,245)
    lbl.TextSize         = 12
    lbl.Font             = Enum.Font.Gotham
    lbl.TextXAlignment   = Enum.TextXAlignment.Left

    local bg = Instance.new("Frame",row)
    bg.Size              = UDim2.new(0,38,0,20)
    bg.Position          = UDim2.new(1,-50,0.5,-10)
    bg.BackgroundColor3  = Color3.fromRGB(24,40,54)
    bg.BorderSizePixel   = 0
    Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0)

    local knob = Instance.new("Frame",bg)
    knob.Size            = UDim2.new(0,16,0,16)
    knob.Position        = UDim2.new(0,2,0.5,-8)
    knob.BackgroundColor3= Color3.fromRGB(110,150,175)
    knob.BorderSizePixel = 0
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

    local function upd()
        local on = cfg[key]
        TweenService:Create(knob,TweenInfo.new(0.12),{
            Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8),
            BackgroundColor3 = on and Color3.fromRGB(226,246,255) or Color3.fromRGB(110,150,175),
        }):Play()
        TweenService:Create(bg,TweenInfo.new(0.12),{
            BackgroundColor3 = on and Color3.fromRGB(30,52,72) or Color3.fromRGB(24,40,54),
        }):Play()
    end

    local hitbox = Instance.new("TextButton",row)
    hitbox.Size=UDim2.new(1,0,1,0); hitbox.BackgroundTransparency=1; hitbox.Text=""
    hitbox.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        saveCfg()
        upd()
        if cb then cb(cfg[key]) end
    end)
    upd()
    return row
end

local function slider(parent, label, cfg, key, mn, mx, cb)
    local row = Instance.new("Frame",parent)
    row.Size             = UDim2.new(1,0,0,50)
    row.BackgroundColor3 = Color3.fromRGB(16,27,38)
    row.BorderSizePixel  = 0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)

    local lbl = Instance.new("TextLabel",row)
    lbl.Size = UDim2.new(1,-60,0,22); lbl.Position=UDim2.new(0,12,0,4)
    lbl.BackgroundTransparency=1; lbl.TextColor3=Color3.fromRGB(186,216,232)
    lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.Text=label

    local val = Instance.new("TextLabel",row)
    val.Size=UDim2.new(0,50,0,22); val.Position=UDim2.new(1,-58,0,4)
    val.BackgroundTransparency=1; val.TextColor3=Color3.fromRGB(226,246,255)
    val.TextSize=11; val.Font=Enum.Font.GothamBold; val.TextXAlignment=Enum.TextXAlignment.Right
    val.Text=tostring(cfg[key])

    local track = Instance.new("Frame",row)
    track.Size=UDim2.new(1,-24,0,4); track.Position=UDim2.new(0,12,0,36)
    track.BackgroundColor3=Color3.fromRGB(24,40,54); track.BorderSizePixel=0
    Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)

    local fill = Instance.new("Frame",track)
    fill.Size=UDim2.new((cfg[key]-mn)/(mx-mn),0,1,0)
    fill.BackgroundColor3=Color3.fromRGB(196,232,245); fill.BorderSizePixel=0
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

    local knob = Instance.new("Frame",track)
    knob.Size=UDim2.new(0,10,0,10); knob.AnchorPoint=Vector2.new(0.5,0.5)
    knob.Position=UDim2.new((cfg[key]-mn)/(mx-mn),0,0.5,0)
    knob.BackgroundColor3=Color3.fromRGB(240,250,255); knob.BorderSizePixel=0
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

    local sl=false
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sl=true end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sl=false end end)
    UserInputService.InputChanged:Connect(function(i)
        if sl and i.UserInputType==Enum.UserInputType.MouseMovement then
            local r=math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            local v=math.floor(mn+r*(mx-mn))
            cfg[key]=v; fill.Size=UDim2.new(r,0,1,0); knob.Position=UDim2.new(r,0,0.5,0)
            saveCfg()
            val.Text=tostring(v)
            if cb then cb(v) end
        end
    end)
    return row
end

local function button(parent, label, cb)
    local btn = Instance.new("TextButton",parent)
    btn.Size=UDim2.new(1,0,0,34)
    btn.BackgroundColor3=Color3.fromRGB(38,62,80)
    btn.Text=label; btn.TextColor3=Color3.fromRGB(226,246,255)
    btn.TextSize=12; btn.Font=Enum.Font.GothamBold; btn.BorderSizePixel=0
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
    btn.MouseButton1Click:Connect(cb)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(52,84,108)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(38,62,80)}):Play()
    end)
    return btn
end

-- ══════════════════════════════
--   COLOR PICKER (palette)
-- ══════════════════════════════
local PALETTE_COLORS = {
    Color3.fromRGB(255,255,255), Color3.fromRGB(200,200,200), Color3.fromRGB(130,130,130), Color3.fromRGB(70,70,70),
    Color3.fromRGB(0,0,0),     Color3.fromRGB(255,60,60),   Color3.fromRGB(255,140,40),  Color3.fromRGB(255,200,60),
    Color3.fromRGB(255,230,90),Color3.fromRGB(255,220,0),   Color3.fromRGB(180,255,80),  Color3.fromRGB(80,255,80),
    Color3.fromRGB(50,200,110),Color3.fromRGB(70,255,200),  Color3.fromRGB(80,220,255),  Color3.fromRGB(70,140,255),
    Color3.fromRGB(100,90,255),Color3.fromRGB(150,60,255),  Color3.fromRGB(200,80,220),  Color3.fromRGB(255,80,180),
    Color3.fromRGB(255,100,140),Color3.fromRGB(160,80,40),  Color3.fromRGB(255,255,150), Color3.fromRGB(150,255,220),
}

local function colorPicker(parent, label, cfg, key, cb)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,176)
    row.BackgroundColor3 = Color3.fromRGB(16,27,38)
    row.BorderSizePixel = 0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)

    local lbl = Instance.new("TextLabel",row)
    lbl.Size = UDim2.new(1,-90,0,28); lbl.Position=UDim2.new(0,12,0,6)
    lbl.BackgroundTransparency=1; lbl.TextColor3=Color3.fromRGB(206,232,245)
    lbl.TextSize=12; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.Text=label

    local preview = Instance.new("Frame",row)
    preview.Size = UDim2.new(0,42,0,22); preview.Position = UDim2.new(1,-58,0,9)
    preview.BackgroundColor3 = cfg[key]; preview.BorderSizePixel = 0
    Instance.new("UICorner",preview).CornerRadius = UDim.new(0,5)
    local ps = Instance.new("UIStroke", preview); ps.Color=Color3.fromRGB(255,255,255); ps.Thickness=0.8; ps.Transparency=0.3

    local grid = Instance.new("Frame",row)
    grid.Size = UDim2.new(1,-24,0,120)
    grid.Position = UDim2.new(0,12,0,46)
    grid.BackgroundTransparency = 1
    local gl = Instance.new("UIGridLayout", grid)
    gl.CellSize = UDim2.new(0,28,0,28); gl.CellPadding = UDim2.new(0,6,0,6)
    gl.FillDirectionMaxCells = 8; gl.SortOrder = Enum.SortOrder.LayoutOrder

    for idx, col in ipairs(PALETTE_COLORS) do
        local b = Instance.new("TextButton", grid)
        b.BackgroundColor3 = col; b.BorderSizePixel = 0
        b.Text = ""
        local bc = Instance.new("UICorner", b); bc.CornerRadius = UDim.new(0,6)
        local st = Instance.new("UIStroke", b); st.Color=Color3.fromRGB(255,255,255); st.Thickness=0.6; st.Transparency=0.5
        local hl = Instance.new("Frame", b)
        hl.Size = UDim2.new(1,-4,1,-4); hl.Position=UDim2.new(0,2,0,2)
        hl.BackgroundTransparency = 1; hl.BorderSizePixel = 0
        Instance.new("UICorner", hl).CornerRadius = UDim.new(0,4)
        hl.Name = "HL"

        if col == cfg[key] then
            hl.BackgroundTransparency = 0; hl.BackgroundColor3 = Color3.fromRGB(255,255,255); hl.BackgroundColor3 = Color3.fromRGB(255,255,255)
            hl.Size = UDim2.new(1,-8,1,-8); hl.Position = UDim2.new(0,4,0,4)
            hl.BackgroundColor3 = Color3.fromRGB(255,255,255); hl.BackgroundTransparency = 0.85
        end

        b.MouseEnter:Connect(function() TweenService:Create(st,TweenInfo.new(0.1),{Transparency=0}):Play() end)
        b.MouseLeave:Connect(function() TweenService:Create(st,TweenInfo.new(0.1),{Transparency=0.5}):Play() end)

        b.MouseButton1Click:Connect(function()
            cfg[key] = col
            saveCfg()
            preview.BackgroundColor3 = col
            for _, other in ipairs(grid:GetChildren()) do
                if other:IsA("TextButton") then
                    local ohl = other:FindFirstChild("HL")
                    if ohl then ohl.BackgroundTransparency = 1 end
                end
            end
            if hl then hl.BackgroundTransparency = 0.85; hl.BackgroundColor3 = Color3.fromRGB(255,255,255); hl.Size = UDim2.new(1,-8,1,-8); hl.Position = UDim2.new(0,4,0,4) end
            if cb then cb(col) end
        end)
    end

    return row
end

-- ══════════════════════════════
--   TEXT INPUT (une ligne)
-- ══════════════════════════════
local function textInput(parent, label, default, placeholder, cb)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,56)
    row.BackgroundColor3 = Color3.fromRGB(16,27,38)
    row.BorderSizePixel = 0
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size=UDim2.new(1,-24,0,20); lbl.Position=UDim2.new(0,12,0,4)
    lbl.BackgroundTransparency=1; lbl.TextColor3=Color3.fromRGB(206,232,245)
    lbl.TextSize=12; lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Text=label

    local bg = Instance.new("Frame", row)
    bg.Size=UDim2.new(1,-24,0,24); bg.Position=UDim2.new(0,12,0,26)
    bg.BackgroundColor3=Color3.fromRGB(24,40,54); bg.BorderSizePixel=0
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,5)

    local box = Instance.new("TextBox", bg)
    box.Size=UDim2.new(1,-12,1,0); box.Position=UDim2.new(0,6,0,0)
    box.BackgroundTransparency=1; box.ClearTextOnFocus=false
    box.Text=default; box.PlaceholderText=placeholder or ""
    box.PlaceholderColor3=Color3.fromRGB(100,140,165)
    box.TextColor3=Color3.fromRGB(255,255,255)
    box.TextSize=13; box.Font=Enum.Font.Gotham
    box.TextXAlignment=Enum.TextXAlignment.Left

    box.FocusLost:Connect(function()
        if cb then cb(box.Text) end
    end)
    return row, box
end

-- ══════════════════════════════════════════════════════════
--   CROSSHAIR — lettre / emoji au centre de l'ecran
--   rotation + rainbow + couleur (palette)
-- ══════════════════════════════════════════════════════════
local CH_SG = Instance.new("ScreenGui")
CH_SG.Name             = "chr_" .. tostring(math.random(100000,999999))
CH_SG.ResetOnSpawn     = false
CH_SG.IgnoreGuiInset   = true
CH_SG.DisplayOrder     = 9999
CH_SG.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
pcall(function() CH_SG.Parent = SG.Parent end)
if not CH_SG.Parent then CH_SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Conteneur pivot (rotation FORCEE autour du centre)
local CH_PIVOT = Instance.new("Frame", CH_SG)
CH_PIVOT.AnchorPoint            = Vector2.new(0.5, 0.5)
CH_PIVOT.Position               = UDim2.new(0.5, 0, 0.5, 0)
CH_PIVOT.Size                   = UDim2.new(0, 60, 0, 60)
CH_PIVOT.BackgroundTransparency = 1
CH_PIVOT.BorderSizePixel        = 0

local CHLBL = Instance.new("TextLabel", CH_PIVOT)
CHLBL.AnchorPoint            = Vector2.new(0.5, 0.5)
CHLBL.Position               = UDim2.new(0.5, 0, 0.5, 0)
CHLBL.Size                   = UDim2.new(1, 0, 1, 0)
CHLBL.BackgroundTransparency = 1
CHLBL.Font                   = Enum.Font.GothamBold
CHLBL.RichText               = false
CHLBL.Text                   = Cfg.Crosshair.Char
CHLBL.TextSize               = Cfg.Crosshair.Size
CHLBL.TextColor3             = Cfg.Crosshair.Color
CHLBL.TextStrokeTransparency = 0.4
CHLBL.TextXAlignment         = Enum.TextXAlignment.Center
CHLBL.TextYAlignment         = Enum.TextYAlignment.Center
CHLBL.Visible                = false

local chRot, chHue = 0, 0
local function chRefresh()
    CHLBL.Visible                = Cfg.Crosshair.Enabled
    CHLBL.Text                   = Cfg.Crosshair.Char
    CHLBL.TextSize               = Cfg.Crosshair.Size
    CHLBL.TextStrokeTransparency = Cfg.Crosshair.Outline and 0.4 or 1
    if not Cfg.Crosshair.Rainbow then
        CHLBL.TextColor3 = Cfg.Crosshair.Color
    end
    if not Cfg.Crosshair.Rotate then
        chRot = 0
        CH_PIVOT.Rotation = 0
    end
end

RunService.RenderStepped:Connect(function(dt)
    if not Cfg.Crosshair.Enabled then
        if CH_PIVOT.Visible then CH_PIVOT.Visible = false end
        return
    end
    CH_PIVOT.Visible = true
    if Cfg.Crosshair.Rotate then
        chRot = (chRot + Cfg.Crosshair.RotSpeed * dt) % 360
        CH_PIVOT.Rotation = chRot
    end
    if Cfg.Crosshair.Rainbow then
        chHue = (chHue + dt * 0.25) % 1
        CHLBL.TextColor3 = Color3.fromHSV(chHue, 1, 1)
    end
end)

-- ══════════════════════════════
--   POPULATE TABS
-- ══════════════════════════════

-- ─── LEGIT POWER ──────────────────────────────────
;(function()
    local f = tabs["Legit Power"].frame

    sectionTitle(f, " LEGIT POWER")
    local infoLT = Instance.new("TextLabel", f)
    infoLT.Size = UDim2.new(1,0,0,64)
    infoLT.BackgroundColor3 = Color3.fromRGB(16,27,38)
    infoLT.BorderSizePixel = 0
    infoLT.TextColor3 = Color3.fromRGB(170,205,228)
    infoLT.TextSize = 11
    infoLT.Font = Enum.Font.Gotham
    infoLT.TextWrapped = true
    infoLT.TextXAlignment = Enum.TextXAlignment.Left
    infoLT.Text = "  1) Tu MAINTIENS CLIC DROIT\n  2) Si ennemi DANS le cercle FOV → LOCK sur sa TETE (silencieux)\n  3) Tir AUTO en boucle (tu gardes controle de ta souris)\n  4) Lache clic droit → STOP tout"
    Instance.new("UICorner", infoLT).CornerRadius = UDim.new(0,6)
    local ipLT = Instance.new("UIPadding", infoLT); ipLT.PaddingLeft = UDim.new(0,8)

    toggle(f, "Enable Legit Power", Cfg.LegitTrigger, "Enabled", function(v)
        FovS.setVisible(Cfg.AimBot.ShowFOVCircle and (v or Cfg.AimBot.Enabled))
        fovSync()
    end)
    toggle(f, "Lock Systematiquement sur la Tete", Cfg.LegitTrigger, "LockHead")
    toggle(f, "Cible seulement dans le cercle FOV", Cfg.LegitTrigger, "FOVOnly")
    toggle(f, "Wall Check (pas a travers murs)", Cfg.LegitTrigger, "WallCheck")
    toggle(f, "Team Check (ignore equipe)", Cfg.LegitTrigger, "TeamCheck")
    slider(f, "Taille FOV Cercle", Cfg.AimBot, "FOV", 10, 400, function(v) FovS.setRadius(v) end)
    slider(f, "Délai entre tirs (x0.01s)", Cfg.LegitTrigger, "Delay", 1, 100, function(v)
        Cfg.LegitTrigger.Delay = v / 100
    end)

    sectionTitle(f, " AIMBOT (Vise seulement, PAS de tir auto)")
    toggle(f, "Enable Aimbot",       Cfg.AimBot, "Enabled", function(v) FovS.setVisible(Cfg.AimBot.ShowFOVCircle and (v or Cfg.LegitTrigger.Enabled)); fovSync() end)
    toggle(f, "Wall Check",   Cfg.AimBot, "WallCheck")
    toggle(f, "Team Check",   Cfg.AimBot, "TeamCheck")
    slider(f, "Smoothness", Cfg.AimBot, "Smoothness", 1, 100, function(v)
        Cfg.AimBot.Smoothness = v / 1000
    end)
    toggle(f, "Prediction", Cfg.AimBot, "Prediction")
    toggle(f, "Sticky Aim",   Cfg.AimBot, "StickyAim")
    toggle(f, "Arme suit l'ennemi (patache rivals)", Cfg.AimBot, "WeaponFollow")
    toggle(f, "Bloquer curseur sur la tete", Cfg.AimBot, "MouseLock", function(v)
        if not v then WeaponAim.releaseMouse() end
    end)
    toggle(f, "Bras / torse orientes cible",  Cfg.AimBot, "ArmAim", function(v)
        if not v then WeaponAim.release() end
    end)

    sectionTitle(f, " Couleur")
    colorPicker(f, "Couleur Cercle FOV", Cfg.Colors, "FOV", function(col)
        FovS.setColor(col)
    end)

end)()

-- ─── TRIGGERBOT ────────────────────────────────────
;(function()
    local f = tabs["TriggerBot"].frame
    sectionTitle(f, " TriggerBot")
    toggle(f, "Enable", Cfg.TriggerBot, "Enabled")

    sectionTitle(f, "FOV")
    slider(f, "FOV TriggerBot", Cfg.TriggerBot, "FOV", 5, 400)

    -- Cercle FOV dédié au TriggerBot (drawing séparé)
    local TBcircle = Drawing.new("Circle")
    TBcircle.Visible = false
    TBcircle.Thickness = 1.2
    TBcircle.Color = Color3.fromRGB(255, 100, 0)
    TBcircle.Transparency = 0.6
    TBcircle.Filled = false
    TBcircle.NumSides = 64
    TBcircle.Radius = Cfg.TriggerBot.FOV

    toggle(f, "Afficher cercle FOV TriggerBot", {show=false}, "show", function(v)
        TBcircle.Visible = v
    end)

    RunService.RenderStepped:Connect(function()
        if TBcircle.Visible then
            local mp = UserInputService:GetMouseLocation()
            TBcircle.Position = Vector2.new(mp.X, mp.Y)
            TBcircle.Radius = Cfg.TriggerBot.FOV
        end
    end)

    sectionTitle(f, "Délai")
    slider(f, "Délai tir (x0.01s)", Cfg.TriggerBot, "Delay", 1, 50, function(v)
        Cfg.TriggerBot.Delay = v / 100
    end)

    sectionTitle(f, "Info")
    local info2 = Instance.new("TextLabel", f)
    info2.Size = UDim2.new(1,0,0,50)
    info2.BackgroundColor3 = Color3.fromRGB(16,27,38)
    info2.BorderSizePixel = 0
    info2.TextColor3 = Color3.fromRGB(170,205,228)
    info2.TextSize = 11
    info2.Font = Enum.Font.Gotham
    info2.TextWrapped = true
    info2.TextXAlignment = Enum.TextXAlignment.Left
    info2.Text = "  Si un ennemi entre dans le cercle\n  orange -> tir automatique sur la tete"
    Instance.new("UICorner", info2).CornerRadius = UDim.new(0,6)
    local ip2 = Instance.new("UIPadding", info2); ip2.PaddingLeft = UDim.new(0,8)
end)()

-- ─── RAGE ──────────────────────────────────────────
;(function()
    local f = tabs["Rage"].frame
    sectionTitle(f, "Rage AimBot")
    toggle(f, "Rage Mode (FOV max)", {rm=false}, "rm", function(v)
        if v then Cfg.AimBot.FOV=400; FovS.setRadius(400)
        else Cfg.AimBot.FOV=150; FovS.setRadius(150) end
    end)
    toggle(f, "No Recoil (simulé)", {nr=false}, "nr")


    sectionTitle(f, " Rapid Fire (no reload / no latence)")
    toggle(f, "Rapid Fire Enable", Cfg.RapidFire, "Enabled", function(v)
        if v then enableRapidFire() else disableRapidFire() end
    end)

    sectionTitle(f, "Auto-TP")
    toggle(f, "Auto-TP (se TP sur l'ennemi le plus proche)", Cfg.AutoTP, "Enabled", function(v)
        if v then startAutoTP() end
    end)
    slider(f, "Délai entre TP (x0.1s)", Cfg.AutoTP, "Delay", 1, 30, function(v)
        Cfg.AutoTP.Delay = v / 10
    end)
    slider(f, "Distance offset (studs)", Cfg.AutoTP, "Distance", 1, 20)
end)()

-- ─── VISUALS ───────────────────────────────────────
;(function()
    local f = tabs["Visuals"].frame
    sectionTitle(f, "ESP")
    toggle(f, "ESP Enable",      Cfg.ESP, "Enabled")
    toggle(f, "Wall ESP (travers les murs)", Cfg.ESP, "WallESP")
    toggle(f, "Health Bar",      Cfg.ESP, "HealthBar")
    toggle(f, "Name Tag",        Cfg.ESP, "NameTag")
    toggle(f, "Box ESP",         Cfg.ESP, "Box")
    toggle(f, "Box Remplie (couleur sur l'ennemi)", Cfg.ESP, "FilledBox")
    slider(f, "Opacite Box Remplie (%)", {a=55}, "a", 0, 100, function(v)
        Cfg.ESP.FilledAlpha = v / 100
    end)
    toggle(f, "Distance",        Cfg.ESP, "Distance")
    toggle(f, "Tracers (lignes reliees aux joueurs)", Cfg.ESP, "Tracers")
    toggle(f, "Skeleton ESP (squelette de l'ennemi)", Cfg.ESP, "Skeleton")
    toggle(f, "Team Check",      Cfg.ESP, "TeamCheck")
    sectionTitle(f, " Couleur")
    colorPicker(f, "Couleur ESP (box + distance + rempli)", Cfg.Colors, "ESP", function(col)
        for p, obj in pairs(ESPObj) do
            if obj.Filled then obj.Filled.Color = col end
            if obj.Box then obj.Box.Color = col end
            if obj.Dist then obj.Dist.Color = col end
            if obj.Tracer then obj.Tracer.Color = col end
        end
    end)
    colorPicker(f, "Couleur Skeleton (squelette uniquement)", Cfg.Colors, "Skeleton", function(col)
        for p, obj in pairs(ESPObj) do
            if obj.Skel then for _, l in ipairs(obj.Skel) do l.Color = col end end
        end
    end)
    sectionTitle(f, " Image / Fond")
    toggle(f, "Image en fond du panel", Cfg.Background, "Enabled", function()
        refreshPanelBG()
    end)
    slider(f, "Transparence image panel (%)", {a = math.floor(Cfg.Background.Alpha * 100)}, "a", 0, 100, function(v)
        Cfg.Background.Alpha = v / 100
        refreshPanelBG()
    end)
    toggle(f, "Mettre l'image EN FOV (semi-transparente)", Cfg.Background, "InFOV")
    slider(f, "Transparence image FOV (%)", {a = math.floor(Cfg.Background.FovAlpha * 100)}, "a", 0, 100, function(v)
        Cfg.Background.FovAlpha = v / 100
    end)

    sectionTitle(f, "FOV Circle")
    toggle(f, "Afficher cercle FOV", Cfg.AimBot, "ShowFOVCircle", function(v)
        FovS.setVisible(v and (Cfg.AimBot.Enabled or Cfg.LegitTrigger.Enabled))
        fovSync()
    end)

end)()

-- ══════════════════════════════════════════════════════
--   VISION / ZOOM (onglet Player)
--   Force le FieldOfView + la distance de dezoom, meme si
--   le jeu essaie de les remettre a sa valeur (roulette, etc.)
-- ══════════════════════════════════════════════════════
local VisionFX = {}
VisionFX.defaultFOV  = Camera.FieldOfView
VisionFX.defaultMax  = LocalPlayer.CameraMaxZoomDistance
VisionFX.defaultMin  = LocalPlayer.CameraMinZoomDistance

function VisionFX.apply()
    pcall(function()
        if Cfg.Vision.Enabled then
            Camera.FieldOfView = Cfg.Vision.FOV
            LocalPlayer.CameraMaxZoomDistance = Cfg.Vision.MaxZoom
            LocalPlayer.CameraMinZoomDistance = Cfg.Vision.MinZoom
        end
    end)
end

function VisionFX.restore()
    pcall(function()
        Camera.FieldOfView = VisionFX.defaultFOV
        LocalPlayer.CameraMaxZoomDistance = VisionFX.defaultMax
        LocalPlayer.CameraMinZoomDistance = VisionFX.defaultMin
    end)
end

RunService.RenderStepped:Connect(function()
    if Cfg.Vision.Enabled then VisionFX.apply() end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Cfg.Vision.Enabled then VisionFX.apply() end
end)


-- ─── PLAYER ────────────────────────────────────────
;(function()
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

    sectionTitle(f, "Arme")
    toggle(f, "Cacher l'arme / bras (local)", Cfg.HideWeapon, "Enabled")

    sectionTitle(f, "Vision / Zoom camera")
    toggle(f, "Activer Vision custom", Cfg.Vision, "Enabled", function(v)
        if v then VisionFX.apply() else VisionFX.restore() end
    end)
    slider(f, "Champ de vision (FOV)", Cfg.Vision, "FOV", 20, 120, function()
        VisionFX.apply()
    end)
    slider(f, "Distance de dezoom max", Cfg.Vision, "MaxZoom", 1, 500, function()
        VisionFX.apply()
    end)
    button(f, "Reset vision (valeurs du jeu)", function()
        Cfg.Vision.Enabled = false
        VisionFX.restore()
        saveCfg()
    end)

    sectionTitle(f, "Configuration")
    button(f, "Reset TOUS les parametres", function()
        CfgIO.reset()
        Cfg.Vision.Enabled = false
        VisionFX.restore()
    end)

end)()

-- ─── TELEPORT ──────────────────────────────────────
;(function()
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
        local plist = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then plist[#plist + 1] = p end
        end
        -- ORDRE ALPHABETIQUE (insensible a la casse)
        table.sort(plist, function(a, b)
            return string.lower(a.Name) < string.lower(b.Name)
        end)
        for i, p in ipairs(plist) do
            local b = Instance.new("TextButton", listFrame)
            b.LayoutOrder = i
            b.Size=UDim2.new(1,0,0,32)
            b.BackgroundColor3=Color3.fromRGB(18,30,42)
            b.Text = p.Name
            b.TextColor3=Color3.fromRGB(200,230,245)
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
    button(f, "  Sauvegarder Position", function()
        local root = getRoot(LocalPlayer)
        if root then Cfg.Teleport.SavedPos = root.CFrame end
    end)
    button(f, "⊕  Retourner Position Sauvegardée", function()
        local root = getRoot(LocalPlayer)
        if root and Cfg.Teleport.SavedPos then
            root.CFrame = Cfg.Teleport.SavedPos
        end
    end)
    button(f, " Rafraîchir liste joueurs", refreshList)
    refreshList()
    Players.PlayerAdded:Connect(refreshList)
    Players.PlayerRemoving:Connect(function() task.wait(0.1) refreshList() end)
end)()

-- ─── WORLD ─────────────────────────────────────────
;(function()
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
end)()

-- ─── MISC ──────────────────────────────────────────
;(function()
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
end)()

-- ─── SETTINGS ──────────────────────────────────────
;(function()
    local f = tabs["Settings"].frame
    sectionTitle(f, "option principale crazy hub")

    local info = Instance.new("TextLabel", f)
    info.Size=UDim2.new(1,0,0,60)
    info.BackgroundColor3=Color3.fromRGB(16,27,38)
    info.BorderSizePixel=0
    info.TextColor3=Color3.fromRGB(170,205,228)
    info.TextSize=11; info.Font=Enum.Font.Gotham
    info.TextWrapped=true; info.TextXAlignment=Enum.TextXAlignment.Left
    info.Text="  AimBot : Clic Droit\n  Ouvrir/Fermer panel : Insert\n  Fly : activé dans l'onglet Player\n  NoClip : activé dans l'onglet Player"
    Instance.new("UICorner",info).CornerRadius=UDim.new(0,6)
    local ip=Instance.new("UIPadding",info); ip.PaddingLeft=UDim.new(0,8)

    sectionTitle(f, " Wall Shot / Silent Aim (patche)")
    toggle(f, "Wall Shot Enable", Cfg.WallShot, "Enabled")

    sectionTitle(f, "Fenêtre")
    slider(f, "Largeur panel", {w=560}, "w", 400, 900, function(v)
        WIN.Size = UDim2.new(0,v,0,WIN.AbsoluteSize.Y)
    end)
    slider(f, "Hauteur panel", {h=400}, "h", 300, 700, function(v)
        WIN.Size = UDim2.new(0,WIN.AbsoluteSize.X,0,v)
    end)
    slider(f, "Transparence panel (0 = opaque)", {a=0}, "a", 0, 70, function(v)
        applyPanelTransparency(v / 100)
    end)

    -- ─── THEMES ────────────────────────────────────
    sectionTitle(f, " Animation de lancement")
    button(f, "Rejouer l'animation ", function()
        task.spawn(function() pcall(playLaunchAnimation) end)
    end)
    button(f, "Reinitialiser le choix animation (redemande au prochain lancement)", function()
        local data = loadAnimPrefs()
        data[tostring(LocalPlayer.Name)] = nil
        local g = getgenv and getgenv() or _G
        if g.CrazyHubAnimPrefs then g.CrazyHubAnimPrefs[tostring(LocalPlayer.Name)] = nil end
        pcall(function()
            if typeof(writefile) == "function" then
                writefile(ANIM_PREF_FILE, game:GetService("HttpService"):JSONEncode(data))
            end
        end)
    end)
    button(f, "Toujours revoir l'animation (OUI)", function()
        saveAnimPref(tostring(LocalPlayer.Name), true)
    end)
    button(f, "Ne plus jamais revoir l'animation (NON)", function()
        saveAnimPref(tostring(LocalPlayer.Name), false)
    end)

    sectionTitle(f, " Thèmes")

    -- Définition des thèmes
    local Themes = {
        {
            name    = "Black Hole",
            icon    = "⚫",
            win     = Color3.fromRGB(10, 16,  24),
            tbar    = Color3.fromRGB(14, 24,  34),
            sidebar = Color3.fromRGB(11, 18,  27),
            content = Color3.fromRGB( 7, 12,  19),
            row     = Color3.fromRGB(16, 27,  38),
            accent  = Color3.fromRGB(226,246, 255),
            stroke  = Color3.fromRGB(90, 150, 180),
            tabOn   = Color3.fromRGB(26, 48,  68),
            sep     = Color3.fromRGB(38, 62,  80),
            text    = Color3.fromRGB(206,232, 245),
            knobOn  = Color3.fromRGB(226,246, 255),
            bgKnob  = Color3.fromRGB(30, 52,  72),
        },
        {
            name    = "Amethyst",
            icon    = "",
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
            icon    = "",
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
            icon    = "",
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
            icon    = "",
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
            icon    = "",
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
            icon    = "",
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
            icon    = "",
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
        -- Applique les couleurs
        WIN.BackgroundColor3  = t.win
        TBAR.BackgroundColor3 = t.tbar
        for _, c in ipairs(TBAR:GetChildren()) do
            if c:IsA("Frame") and not c:IsA("TextButton") then
                c.BackgroundColor3 = t.tbar
            end
        end
        local stroke = WIN:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = t.stroke end
        SIDEBAR.BackgroundColor3 = t.sidebar
        CONTENT.BackgroundColor3 = t.content
        SEP.BackgroundColor3 = t.sep
        -- logo (bordure + point de secours) : facultatif, ne doit jamais casser le thème
        pcall(function()
            local st = LOGOBG:FindFirstChildOfClass("UIStroke")
            if st then st.Color = t.accent end
            for _, c in ipairs(LOGOBG:GetChildren()) do
                if c:IsA("Frame") then c.BackgroundColor3 = t.accent end
            end
        end)

        -- Bulles de categories
        for name, tab in pairs(tabs) do
            tab.lbl.TextColor3 = (name == activeTab) and t.text or Color3.fromRGB(140,176,200)
            tab.btn.BackgroundColor3 = t.tabOn
            if tab.stroke then tab.stroke.Color = t.accent end
            if tab.bar then tab.bar.BackgroundColor3 = t.accent end
        end

        for _, tab in pairs(tabs) do
            for _, c in ipairs(tab.frame:GetDescendants()) do
                if c:IsA("Frame") and c.Name == "" then
                    if c.AbsoluteSize.Y <= 55 then
                        c.BackgroundColor3 = t.row
                    end
                end
                if c:IsA("Frame") and c.AbsoluteSize.Y <= 6 and c.AbsoluteSize.X > 20 then
                    for _, cc in ipairs(c:GetChildren()) do
                        if cc:IsA("Frame") and cc.AbsoluteSize.Y <= 6 then
                            cc.BackgroundColor3 = t.accent
                        end
                    end
                end
                if c:IsA("TextLabel") and c.TextColor3 == Color3.fromRGB(255,220,0) then
                    c.TextColor3 = t.accent
                end
            end
        end

        pcall(function() FovS.setColor(t.accent) end)
        if Cfg.ESP then Cfg.ESP.Color = t.accent end
        Cfg.Colors.FOV  = t.accent
        Cfg.Colors.ESP  = t.accent


        -- Transparence : thème Transparent force 0.45, sinon garde actuelle
        if t.winAlpha ~= nil then
            applyPanelTransparency(t.winAlpha)
        else
            applyPanelTransparency(currentPanelAlpha)
        end
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
end)()

-- ─── CROSSHAIR ─────────────────────────────────────
;(function()
    local f = tabs["Crosshair"].frame
    sectionTitle(f, " CROSSHAIR")

    local chInfo = Instance.new("TextLabel", f)
    chInfo.Size = UDim2.new(1,0,0,52)
    chInfo.BackgroundColor3 = Color3.fromRGB(48,48,51)
    chInfo.BorderSizePixel = 0
    chInfo.TextColor3 = Color3.fromRGB(180,170,210)
    chInfo.TextSize = 11; chInfo.Font = Enum.Font.Gotham
    chInfo.TextWrapped = true; chInfo.TextXAlignment = Enum.TextXAlignment.Left
    chInfo.Text = "  Tape une lettre ou colle un emoji dans le champ ci-dessous.\n  (ou modifie Char = \"+\" dans Cfg.Crosshair au debut du script)"
    Instance.new("UICorner", chInfo).CornerRadius = UDim.new(0,6)
    local chIp = Instance.new("UIPadding", chInfo); chIp.PaddingLeft = UDim.new(0,8)

    toggle(f, "Enable Crosshair", Cfg.Crosshair, "Enabled", function(v)
        chRefresh()
    end)

    textInput(f, "Caractere / Emoji du crosshair", Cfg.Crosshair.Char, "+  ou  X  ou  🎯", function(txt)
        if txt == nil or txt == "" then txt = "+" end
        Cfg.Crosshair.Char = txt
        chRefresh()
    end)

    slider(f, "Taille", Cfg.Crosshair, "Size", 8, 120, function(v)
        Cfg.Crosshair.Size = v
        chRefresh()
    end)

    toggle(f, "Contour noir (lisibilite)", Cfg.Crosshair, "Outline", function(v) chRefresh() end)

    sectionTitle(f, " Rotation")
    toggle(f, "Faire tourner le crosshair", Cfg.Crosshair, "Rotate", function(v) chRefresh() end)
    slider(f, "Vitesse rotation (deg/s)", Cfg.Crosshair, "RotSpeed", 10, 720)

    sectionTitle(f, " Couleur")
    toggle(f, "Rainbow (arc-en-ciel)", Cfg.Crosshair, "Rainbow", function(v) chRefresh() end)
    colorPicker(f, "Couleur du crosshair", Cfg.Crosshair, "Color", function(col)
        Cfg.Crosshair.Color = col
        chRefresh()
    end)
end)()
-- ── Touche G = ouvrir / fermer le hub ──
-- NOTE DEBUG: ce gros bloc est isole dans une fonction globale temporaire
-- pour eviter le plafond Luau "Out of local registers" du chunk principal.
function __CrazyHubInitToggleBlock()
    -- ── INSERT key = toggle GUI ──
    -- ══════════════════════════════
    --   BANNIÈRE HAUT D'ÉCRAN : CRAZY HUB ON TOP
    -- ══════════════════════════════
    local TOPBAR = Instance.new("Frame", SG)
    TOPBAR.Name = "CrazyTopBanner"
    TOPBAR.AnchorPoint = Vector2.new(0.5, 0)
    TOPBAR.Position = UDim2.new(0.5, 0, 0, -50)
    TOPBAR.Size = UDim2.new(0, 250, 0, 34)
    TOPBAR.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    TOPBAR.BackgroundTransparency = 0.15
    TOPBAR.BorderSizePixel = 0
    TOPBAR.ZIndex = 50
    ;(function()
        Instance.new("UICorner", TOPBAR).CornerRadius = UDim.new(0, 10)
        local st = Instance.new("UIStroke", TOPBAR)
        st.Thickness = 1.2
        st.Transparency = 0.15
        local g = Instance.new("UIGradient", st)
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(58, 92, 118)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(126, 176, 200)),
        })
        task.spawn(function()
            while TOPBAR.Parent do
                g.Rotation = (g.Rotation + 2) % 360
                task.wait(0.03)
            end
        end)
    end)()

    local TOPTXT = Instance.new("TextLabel", TOPBAR)
    TOPTXT.Size = UDim2.new(1, -14, 1, 0)
    TOPTXT.Position = UDim2.new(0, 7, 0, 0)
    TOPTXT.BackgroundTransparency = 1
    TOPTXT.Text = "CRAZY HUB ON TOP"
    TOPTXT.Font = Enum.Font.GothamBlack
    TOPTXT.TextSize = 15
    TOPTXT.TextColor3 = Color3.fromRGB(255, 255, 255)
    TOPTXT.ZIndex = 51
    ;(function()
        local tg = Instance.new("UIGradient", TOPTXT)
        tg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(126, 176, 200)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(196, 232, 245)),
        })
        task.spawn(function()
            local t = 0
            while TOPTXT.Parent do
                t = t + 0.03
                tg.Offset = Vector2.new(math.sin(t) * 0.4, 0)
                task.wait(0.03)
            end
        end)
    end)()

    local TOPSUB = Instance.new("TextLabel", TOPBAR)
    TOPSUB.AnchorPoint = Vector2.new(0.5, 0)
    TOPSUB.Position = UDim2.new(0.5, 0, 1, 3)
    TOPSUB.Size = UDim2.new(1, 0, 0, 14)
    TOPSUB.BackgroundTransparency = 1
    TOPSUB.Text = "[G] OUVRIR / FERMER"
    TOPSUB.Font = Enum.Font.GothamBold
    TOPSUB.TextSize = 11
    TOPSUB.TextColor3 = Color3.fromRGB(165, 165, 175)
    TOPSUB.ZIndex = 51

    -- descente fluide de la bannière
    TweenService:Create(TOPBAR, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 10)
    }):Play()

    -- ══════════════════════════════
    --   BULLE FLOTTANTE (haut a droite)
    --   Apparait quand le hub est ferme.
    --   Clic dessus = rouvrir. [G] marche aussi.
    -- ══════════════════════════════
    local BUBBLE = Instance.new("TextButton", SG)
    BUBBLE.Name = "CrazyBubble"
    BUBBLE.AnchorPoint = Vector2.new(1, 0)
    BUBBLE.Position = UDim2.new(1, -18, 0, 60)
    BUBBLE.Size = UDim2.new(0, 0, 0, 0)
    BUBBLE.BackgroundColor3 = Color3.fromRGB(16, 30, 44)
    BUBBLE.AutoButtonColor = false
    BUBBLE.Text = ""
    BUBBLE.BorderSizePixel = 0
    BUBBLE.Visible = false
    BUBBLE.ZIndex = 80
    Instance.new("UICorner", BUBBLE).CornerRadius = UDim.new(1, 0)

    local BUB_STROKE = Instance.new("UIStroke", BUBBLE)
    BUB_STROKE.Thickness = 1.6
    BUB_STROKE.Transparency = 0.1
    local BUB_GRAD = Instance.new("UIGradient", BUB_STROKE)
    BUB_GRAD.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(58, 92, 118)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(190, 235, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(120, 215, 255)),
    })

    local BUB_IMG = Instance.new("ImageLabel", BUBBLE)
    BUB_IMG.Size = UDim2.new(1, -6, 1, -6)
    BUB_IMG.Position = UDim2.new(0, 3, 0, 3)
    BUB_IMG.BackgroundTransparency = 1
    BUB_IMG.Image = Cfg.Background.Id
    BUB_IMG.ImageTransparency = 0.55
    BUB_IMG.ScaleType = Enum.ScaleType.Crop
    BUB_IMG.ZIndex = 80
    Instance.new("UICorner", BUB_IMG).CornerRadius = UDim.new(1, 0)

    local BUB_TXT = Instance.new("TextLabel", BUBBLE)
    BUB_TXT.Size = UDim2.new(1, 0, 1, 0)
    BUB_TXT.BackgroundTransparency = 1
    BUB_TXT.Text = "CH"
    BUB_TXT.Font = Enum.Font.GothamBlack
    BUB_TXT.TextSize = 16
    BUB_TXT.TextColor3 = Color3.fromRGB(232, 248, 255)
    BUB_TXT.ZIndex = 81

    -- halo pulsant autour de la bulle
    local BUB_PULSE = Instance.new("Frame", BUBBLE)
    BUB_PULSE.AnchorPoint = Vector2.new(0.5, 0.5)
    BUB_PULSE.Position = UDim2.new(0.5, 0, 0.5, 0)
    BUB_PULSE.Size = UDim2.new(1, 0, 1, 0)
    BUB_PULSE.BackgroundTransparency = 1
    BUB_PULSE.BorderSizePixel = 0
    BUB_PULSE.ZIndex = 79
    Instance.new("UICorner", BUB_PULSE).CornerRadius = UDim.new(1, 0)
    local BUB_PSTROKE = Instance.new("UIStroke", BUB_PULSE)
    BUB_PSTROKE.Color = Color3.fromRGB(120, 215, 255)
    BUB_PSTROKE.Thickness = 2
    BUB_PSTROKE.Transparency = 1

    task.spawn(function()
        while BUBBLE.Parent do
            BUB_GRAD.Rotation = (BUB_GRAD.Rotation + 3) % 360
            if BUBBLE.Visible then
                BUB_PULSE.Size = UDim2.new(1, 0, 1, 0)
                BUB_PSTROKE.Transparency = 0.35
                TweenService:Create(BUB_PULSE, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                    Size = UDim2.new(1.9, 0, 1.9, 0)
                }):Play()
                TweenService:Create(BUB_PSTROKE, TweenInfo.new(1.1, Enum.EasingStyle.Sine), {Transparency = 1}):Play()
            end
            task.wait(0.06)
        end
    end)

    BUBBLE.MouseEnter:Connect(function()
        TweenService:Create(BUBBLE, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 52, 0, 52)
        }):Play()
    end)
    BUBBLE.MouseLeave:Connect(function()
        TweenService:Create(BUBBLE, TweenInfo.new(0.15, Enum.EasingStyle.Sine), {
            Size = UDim2.new(0, 46, 0, 46)
        }):Play()
    end)

    local function showBubble()
        BUBBLE.Visible = true
        BUBBLE.Size = UDim2.new(0, 0, 0, 0)
        BUBBLE.Rotation = -90
        TweenService:Create(BUBBLE, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 46, 0, 46),
            Rotation = 0,
        }):Play()
    end

    local function hideBubble()
        TweenService:Create(BUBBLE, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Rotation = 90,
        }):Play()
        task.delay(0.24, function() BUBBLE.Visible = false end)
    end

    -- ══════════════════════════════
    --   TOGGLE HUB (touche G ou bulle) — fluide + stylé + sans bug
    -- ══════════════════════════════
    local hubOpen = true
    local hubBusy = false

    -- IMPORTANT : on ne touche JAMAIS a WIN.Size (le joueur peut redimensionner)
    -- et on ne met JAMAIS WIN.Rotation != 0 :
    -- une Rotation non nulle CASSE le ClipsDescendants de Roblox
    -- => c'est ca qui faisait deborder le contenu (palette de couleurs) hors du hub.
    WIN.Rotation = 0
    WIN.ClipsDescendants = true

    -- Toute l'animation passe par un UIScale : aucun impact sur la taille reelle
    local HubFX = {}
    HubFX.scale = WIN:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", WIN)
    HubFX.scale.Scale = 1

    -- Halo qui claque a l'ouverture / fermeture
    HubFX.glow = WIN:FindFirstChild("CrazyToggleGlow")
    if not HubFX.glow then
        HubFX.glow = Instance.new("UIStroke", WIN)
        HubFX.glow.Name = "CrazyToggleGlow"
        HubFX.glow.Color = Color3.fromRGB(120, 215, 255)
        HubFX.glow.Thickness = 0
        HubFX.glow.Transparency = 1
    end

    HubFX.tweens = {}
    function HubFX.kill()
        for _, t in ipairs(HubFX.tweens) do pcall(function() t:Cancel() end) end
        HubFX.tweens = {}
    end
    function HubFX.play(obj, info, props)
        local t = TweenService:Create(obj, info, props)
        HubFX.tweens[#HubFX.tweens + 1] = t
        t:Play()
        return t
    end

    -- Etat 100% propre : appele avant ET apres chaque animation
    function HubFX.reset()
        WIN.Rotation = 0
        WIN.ClipsDescendants = true
        HubFX.scale.Scale = 1
        HubFX.glow.Thickness = 0
        HubFX.glow.Transparency = 1
    end

    function HubFX.glowPulse(strong)
        HubFX.glow.Thickness = strong and 4 or 2.5
        HubFX.glow.Transparency = 0.1
        HubFX.play(HubFX.glow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Thickness = 0, Transparency = 1,
        })
    end

    -- Onde de choc circulaire au centre du hub (pur style, zero impact sur le layout)
    function HubFX.shockRing()
        local ring = Instance.new("Frame")
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = WIN.Position + UDim2.fromOffset(WIN.AbsoluteSize.X / 2, WIN.AbsoluteSize.Y / 2)
        ring.Size = UDim2.fromOffset(WIN.AbsoluteSize.X * 0.75, WIN.AbsoluteSize.Y * 0.75)
        ring.BackgroundTransparency = 1
        ring.BorderSizePixel = 0
        ring.ZIndex = 0
        ring.Parent = SG
        Instance.new("UICorner", ring).CornerRadius = UDim.new(0, 16)
        local rs = Instance.new("UIStroke", ring)
        rs.Color = Color3.fromRGB(120, 215, 255)
        rs.Thickness = 2
        rs.Transparency = 0.25
        TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(WIN.AbsoluteSize.X * 1.35, WIN.AbsoluteSize.Y * 1.35)
        }):Play()
        TweenService:Create(rs, TweenInfo.new(0.55, Enum.EasingStyle.Sine), {Transparency = 1, Thickness = 0}):Play()
        game:GetService("Debris"):AddItem(ring, 0.8)
    end

    local function toggleHub()
        if hubBusy then return end
        hubBusy = true
        hubOpen = not hubOpen

        HubFX.kill()
        HubFX.reset()

        if hubOpen then
            hideBubble()
            WIN.Visible = true
            HubFX.scale.Scale = 0.82

            -- pop elastique en 2 temps : rebond puis stabilisation douce
            HubFX.play(HubFX.scale, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.03 })
            task.delay(0.30, function()
                if hubOpen then
                    HubFX.play(HubFX.scale, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 })
                end
            end)
            HubFX.glowPulse(true)
            HubFX.shockRing()

            pcall(function() applyPanelTransparency(currentPanelAlpha) end)
            if activeTab then pcall(function() activateTab(activeTab) end) end
            TOPSUB.Text = "[G] FERMER"
            task.wait(0.18)
        else
            HubFX.glowPulse(false)
            HubFX.shockRing()
            -- petite inspiration avant l'implosion => beaucoup plus fluide a l'oeil
            HubFX.play(HubFX.scale, TweenInfo.new(0.09, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Scale = 1.04 })
            task.delay(0.09, function()
                if not hubOpen then
                    HubFX.play(HubFX.scale, TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 0.78 })
                end
            end)
            task.wait(0.29)

            WIN.Visible = false
            HubFX.kill()
            HubFX.reset()

            showBubble()
            TOPSUB.Text = "[G] OUVRIR  •  ou clique la bulle"
        end

        task.wait(0.04)
        hubBusy = false
    end

    BUBBLE.MouseButton1Click:Connect(function()
        task.spawn(toggleHub)
    end)

    UserInputService.InputBegan:Connect(function(i, gp)
        if gp then return end

        -- [G] ou [Insert] : ouvrir / fermer le hub
        if i.KeyCode == Enum.KeyCode.G or i.KeyCode == Enum.KeyCode.Insert then
            task.spawn(toggleHub)
        end


    end)

end
__CrazyHubInitToggleBlock()
__CrazyHubInitToggleBlock = nil

-- Activate default tab
activateTab("Legit Power")

-- Applique la transparence FINALE après que TOUS les éléments ont été créés
task.defer(function()
    task.wait(0.3)
    applyPanelTransparency(currentPanelAlpha)
end)

print("no rival")
