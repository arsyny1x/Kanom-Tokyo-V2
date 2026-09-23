-- Wait Game Loaded
repeat
	task.wait()
until game:IsLoaded() and game.Players and game.Players.LocalPlayer;
pcall(function()
    local Selection = workspace:FindFirstChild("Model"):FindFirstChild("Selection")
    if game:GetService("Players").LocalPlayer.Team == nil and Selection then
        repeat
            task.wait()
        until #Selection:GetChildren() > 0
    end
end)

local _env = getgenv()
local _wait = task.wait

-- ปิดโหมด main.lua ทั้งหมดกันตีกัน (thread main ยังหมุนแต่ไม่มีโหมดไหนทำงาน)
for _, k in ipairs({
    "AutoFarmLevel", "AutoFarmSelected", "AutoFarmMob", "AutoFarmBoss",
    "AutoQuestBoard", "AutoNoro", "AutoEvent",
    "AutoStats", "AutoSkill", "AutoPK", "AutoBuyWeapon", "AutoBuyBlackMarket",
}) do
    _env[k] = false
end
pcall(function()
    local pf = workspace:FindFirstChild("MacHubEventPlatform")
    if pf then pf:Destroy() end
end)

--==================================================
-- Services
--==================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

--==================================================
-- Player
--==================================================
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--==================================================
-- Paths
--==================================================
local TargetRemote = ReplicatedStorage:WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent")
local RagdollPath = workspace:FindFirstChild("IncludeToGame") and workspace.IncludeToGame:FindFirstChild("Ragdoll")
local MobsFolder = workspace:WaitForChild("AI/Player")
local Model = workspace:FindFirstChild("Model")

--==================================================
-- Anti-AFK
--==================================================
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

--==================================================
-- Config
--==================================================
do
    _env.SaveArenaSettingPath = Player.UserId

    -- Direction
    if _env.ArenaDistance == nil then _env.ArenaDistance = 6 end
    if _env.ArenaAngles == nil then _env.ArenaAngles = 90 end

    -- Tween
    if _env.ArenaTweenSpeed == nil then _env.ArenaTweenSpeed = 300 end
    if _env.ArenaWarpDistance == nil then _env.ArenaWarpDistance = 50 end

    -- Attack : ยิงรีโมทตีไม่เกิน 1 ครั้ง / 0.5 วิ (กัน rate-limit/เตะ)
    if _env.AttackDelay == nil then _env.AttackDelay = 0.05 end

    -- Arena
    _env.AutoArena = _env.AutoArena or false
    _env.ArenaAntiDeath = _env.ArenaAntiDeath or false
    if _env.ArenaRetreatHP == nil then _env.ArenaRetreatHP = 30 end -- หนีตอนเลือดเหลือกี่ %
    if _env.ArenaFleeMode == nil then _env.ArenaFleeMode = "Run Away" end -- Run Away = หนีออกจากจุดกลางมอน / Hover Above = ลอยบนหัวตัวที่ตี +30
    if _env.ArenaFleeDistance == nil then _env.ArenaFleeDistance = 60 end -- flee distance (slider 10-150)
    _env.ArenaMaxRest = 180 -- พักนานสุดกี่วิ (กันเลือดไม่รีเจนแล้วค้าง)

    -- UI themes
    _env.ArenaTheme = {
        "Light",
        "Dark",
        "Purple",
        "Green",
        "Orange",
        "Pink",
        "Blue",
        "Red",
        "Neon",
    }
end

--==================================================
-- Helpers
--==================================================
function ArenaError(msg)
    local info = debug.getinfo(2)
    local line = info and info.currentline or "Unknown"
    print("[arena error] Line: " .. line .. " | Message: " .. tostring(msg))
end

function ArenaGetRoot()
    local char = Player.Character or Player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

-- แผ่นใสกันตกที่ y-35 (กันเกมวาร์ปกลับตอนตัวร่วง) วิ่งตาม X/Z ของผู้เล่น
local function ArenaEnsureFallPlatform(x, z)
    local pf = _env._arenaFallPlatform
    if pf and pf.Parent then
        return pf
    end
    local platform = Instance.new("Part")
    platform.Name = "MacHubArenaFallPlatform"
    platform.Size = Vector3.new(40, 1, 40)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 1
    platform.CFrame = CFrame.new(x or 0, -35, z or 0)
    platform.Parent = workspace
    _env._arenaFallPlatform = platform
    return platform
end

local function ArenaDestroyFallPlatform()
    if _env._arenaFallPlatform and _env._arenaFallPlatform.Parent then
        pcall(function() _env._arenaFallPlatform:Destroy() end)
    end
    _env._arenaFallPlatform = nil
end

local arenaNoclip = nil
local function ArenaNoclip(state)
    if state then
        if arenaNoclip then return end
        -- สร้างแผ่นกันตกใต้ตัวทันทีที่เปิด
        local myRoot = ArenaGetRoot()
        if myRoot then
            ArenaEnsureFallPlatform(myRoot.Position.X, myRoot.Position.Z)
        end
        arenaNoclip = RunService.Stepped:Connect(function()
            local char = Player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            if char and hrp and hum then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                -- แผ่นกันตกตามใต้ตัวที่ y-35 (ขยับเฉพาะตอนห่างเกิน 10 กันสแปม)
                local pf = _env._arenaFallPlatform
                if pf and pf.Parent then
                    local dx = pf.Position.X - hrp.Position.X
                    local dz = pf.Position.Z - hrp.Position.Z
                    if dx * dx + dz * dz > 100 then
                        pf.CFrame = CFrame.new(hrp.Position.X, -35, hrp.Position.Z)
                    end
                end
            end
        end)
    else
        if arenaNoclip then
            arenaNoclip:Disconnect()
            arenaNoclip = nil
        end
        ArenaDestroyFallPlatform()
    end
end

function ArenaTweento(targetCFrame)
    local hrp = ArenaGetRoot()
    if not hrp then return end
    local warpDistance = _env.ArenaWarpDistance
    local speed = _env.ArenaTweenSpeed
    local startPos = hrp.Position
    local endPos = targetCFrame.Position
    local distance = (endPos - startPos).Magnitude
    if distance <= warpDistance then
        hrp.CFrame = targetCFrame
        return
    end
    local direction = (endPos - startPos).Unit
    local preWarpPos = endPos - direction * warpDistance
    if _env._arenaTween then
        pcall(function() _env._arenaTween:Cancel() end)
        _env._arenaTween = nil
    end
    local tween = TweenService:Create(hrp,
        TweenInfo.new(math.max((preWarpPos - startPos).Magnitude / speed, 0.1), Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(preWarpPos, endPos) })
    _env._arenaTween = tween
    tween:Play()
    tween.Completed:Wait()
    if _env._arenaTween == tween then
        _env._arenaTween = nil
        hrp.CFrame = targetCFrame
    end
end

function ArenaClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    _wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

function ArenaGetAttack()
    if not _env.SavedArgs and not _env.AttackRemote then
        local mt = getrawmetatable(game)
        local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local args = { ... }
            local method = getnamecallmethod()
            if self == TargetRemote and method == "FireServer" and not _env.SavedArgs then
                if args[1] and args[1][1] and args[1][1][1] == "NormalAttack" then
                    _env.SavedArgs = args
                    _env.AttackRemote = self
                    print("Arena: captured attack args")
                end
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
        _wait(0.5)
        ArenaClick()
        local timeout = 0
        repeat
            _wait(0.1)
            timeout = timeout + 0.1
        until _env.SavedArgs or timeout > 5
    end
    return _env.SavedArgs, _env.AttackRemote
end

function ArenaAttack()
    local now = tick()
    if now - (_env._arenaAtkT or 0) < (_env.AttackDelay or 0.5) then
        return -- ยังไม่ครบ 0.5 วิ ข้าม (กันยิงรีโมทถี่)
    end
    _env._arenaAtkT = now
    local args, remote = ArenaGetAttack()
    if args and remote then
        remote:FireServer(unpack(args))
    end
end

function ArenaEquipped()
    local HUD = PlayerGui:WaitForChild("HUD", 3)
    if not HUD then return false end
    return HUD.Container.Skills.Visible
end

function ArenaEquip()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    _wait()
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    _wait(0.5)
end

-- ตัวละครตัวเองใน AI/Player + เลือด
local function ArenaMe()
    local model = MobsFolder and MobsFolder:FindFirstChild(Player.Name)
    if not model then return nil, nil end
    local hum = model:FindFirstChild("Humanoid")
    if not hum or hum.MaxHealth <= 0 then return model, nil end
    return model, hum
end

local function ArenaHPPct()
    local _, hum = ArenaMe()
    if not hum then return nil end
    return (hum.Health / hum.MaxHealth) * 100
end

-- กินศพฮีล (ไม่ได้ใช้แล้ว : กันตายดำลงพักอย่างเดียว)
function ArenaEat(name)
    _wait(0.5)
    local root = ArenaGetRoot()
    if not root or not RagdollPath then return end
    for _, mob in next, RagdollPath:GetChildren() do
        if mob.PrimaryPart and mob.Name == name then
            if (mob.PrimaryPart.Position - root.Position).Magnitude <= 40 then
                local hitbox = mob:FindFirstChild("ClickHitbox")
                local cd = hitbox and hitbox:FindFirstChildWhichIsA("ClickDetector")
                if hitbox and cd then
                    mob.PrimaryPart.CFrame = root.CFrame
                    _wait(0.3)
                    fireclickdetector(cd)
                    print("Arena eating: " .. mob.Name)
                    _wait(2.5)
                end
            end
        end
    end
end

--==================================================
-- Targeting : ทุก Model ใน AI/Player + Boss (เว้นตัวเอง)
--==================================================
-- มอนเกิดใหม่ต้องอายุครบก่อนค่อยล็อกเป้า (กันยิงตัวที่เพิ่งโผล่ : default 1.5 วิ)
local function ArenaSeenOk(model, seenNow)
    seenNow[model] = true
    _env._arenaSeen = _env._arenaSeen or {}
    local now = tick()
    local first = _env._arenaSeen[model]
    if not first then
        _env._arenaSeen[model] = now
        return false
    end
    return (now - first) >= (_env.ArenaSpawnGrace or 1.5)
end

local function ArenaConsider(list, model, seenNow, root, pending)
    local hum = model:FindFirstChild("Humanoid")
    local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    if not (hum and hum.Health > 0 and hrp) then return end
    if ArenaSeenOk(model, seenNow) then
        table.insert(list, { model = model, hum = hum, root = hrp })
    else
        -- ตัวยังอายุไม่ครบ : จำตัวใกล้สุดไว้ ไปยืนรอข้างๆ แทนยืนนิ่ง
        local d = (root.Position - hrp.Position).Magnitude
        if d < pending.d then
            pending.d = d
            pending.t = { model = model, hum = hum, root = hrp }
        end
    end
end

local function ArenaScanFresh()
    local root = ArenaGetRoot()
    if not root then return nil end
    -- ชื่อผู้เล่นจริงทั้งหมด (ข้าม ไม่โจมตีผู้เล่นด้วยกัน)
    local playerNames = {}
    for _, p in ipairs(Players:GetPlayers()) do
        playerNames[p.Name] = true
    end
    local list = {}
    local seenNow = {}
    local pending = { d = math.huge, t = nil }
    for _, v in ipairs(MobsFolder:GetChildren()) do
        if v:IsA("Model") and v.Name ~= Player.Name and v.Name ~= "Boss" and not playerNames[v.Name] then
            ArenaConsider(list, v, seenNow, root, pending)
        end
    end
    local bossFolder = MobsFolder:FindFirstChild("Boss")
    if bossFolder then
        for _, sub in ipairs(bossFolder:GetDescendants()) do
            if sub:IsA("Model") and sub.Name ~= Player.Name and not playerNames[sub.Name] then
                ArenaConsider(list, sub, seenNow, root, pending)
            end
        end
    end
    -- ล้างตัวที่หายไปแล้ว กันตารางโตไม่หยุด
    local kept = {}
    for m, t0 in pairs(_env._arenaSeen or {}) do
        if seenNow[m] then kept[m] = t0 end
    end
    _env._arenaSeen = kept
    local best, bestD = nil, math.huge
    for _, t in ipairs(list) do
        local d = (root.Position - t.root.Position).Magnitude
        if d < bestD then
            best, bestD = t, d
        end
    end
    return best, bestD, #list, pending.t
end

-- สแกนแคช: 80 ตัวสแกนเต็มทุกครั้งไม่ไหว เก็บผลไว้ใช้ซ้ำตาม ScanRate (ดีฟอลต์ 0.5 วิ)
local function ArenaNearest()
    local now = tick()
    local rate = (_env.ArenaScanRate or 0.5)
    local cache = _env._arenaCache
    if cache and (now - (cache.t or 0)) < rate then
        local b = cache.b
        if b then
            local m = b.model
            local hum = m and m.Parent and m:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                return cache.b, cache.bd, cache.n, cache.pend
            end
        elseif cache.pend then
            local pm = cache.pend.model
            if pm and pm.Parent then
                return nil, nil, cache.n, cache.pend
            end
        else
            return nil, nil, cache.n, nil
        end
    end
    local b, bd, n, pend = ArenaScanFresh()
    _env._arenaCache = { b = b, bd = bd, n = n, pend = pend, t = now }
    return b, bd, n, pend
end

--==================================================
-- Anti Death : stand under target like main (no orbit), flee far from mobs when low HP
-- rest at flee point until full HP (re-flee if mobs come close)
--==================================================
local _deepT0 = 0

local function ArenaShouldRetreat()
    if not _env.ArenaAntiDeath then return false end
    local pct = ArenaHPPct()
    if pct == nil then return false end
    return pct <= (_env.ArenaRetreatHP or 30)
end

-- ตำแหน่งตี = รอบตัวเป้าหมาย + หมุนช้าๆ (กัน NPC ติด state เดินแล้วไม่โจมตี)
local function ArenaAttackCF(troot, lift)
    return troot.CFrame * CFrame.new(0, lift, -3) * CFrame.Angles(math.rad(_env.ArenaAngles), 0, 0)
end

local _fleeCF = nil
-- ตำแหน่งมอนที่ยังเป็นทั้งหมด (สแกนสดแบบเบา : เอาแค่ Position ไม่เช็คอายุ spawn)
local function ArenaLiveMobPos()
    local out = {}
    local playerNames = {}
    for _, p in ipairs(Players:GetPlayers()) do
        playerNames[p.Name] = true
    end
    for _, v in ipairs(MobsFolder:GetChildren()) do
        if v:IsA("Model") and v.Name ~= Player.Name and v.Name ~= "Boss" and not playerNames[v.Name] then
            local hum = v:FindFirstChild("Humanoid")
            local hrp = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
            if hum and hum.Health > 0 and hrp then
                table.insert(out, hrp.Position)
            end
        end
    end
    local bossFolder = MobsFolder:FindFirstChild("Boss")
    if bossFolder then
        for _, sub in ipairs(bossFolder:GetDescendants()) do
            if sub:IsA("Model") and sub.Name ~= Player.Name and not playerNames[sub.Name] then
                local hum = sub:FindFirstChild("Humanoid")
                local hrp = sub:FindFirstChild("HumanoidRootPart") or sub.PrimaryPart
                if hum and hum.Health > 0 and hrp then
                    table.insert(out, hrp.Position)
                end
            end
        end
    end
    return out
end

-- เป้าสำหรับโหมด Above : ตัวล่าสุดที่กำลังตี (ยังเป็นอยู่) ถ้าไม่มีค่อยหาตัวใกล้สุด
local function ArenaAboveTarget()
    local last = _env._arenaLastT
    if last and last.Parent then
        local hum = last:FindFirstChild("Humanoid")
        local hrp = last:FindFirstChild("HumanoidRootPart") or last.PrimaryPart
        if hum and hum.Health > 0 and hrp then
            return last, hrp
        end
    end
    local b = ArenaScanFresh()
    if b and b.model and b.model.Parent then
        _env._arenaLastT = b.model
        return b.model, b.root
    end
    return nil, nil
end

-- จุดหนี = จากที่เรายืน หนีออกจากจุดกลางมอน เป็นระยะ FleeDistance
local function ArenaFleePoint()
    local root = ArenaGetRoot()
    if not root then return nil end
    local myPos = root.Position
    local mobs = ArenaLiveMobPos()
    if #mobs == 0 then return nil end
    local cx, cz = 0, 0
    for _, p in ipairs(mobs) do
        cx, cz = cx + p.X, cz + p.Z
    end
    local away = Vector3.new(myPos.X - cx / #mobs, 0, myPos.Z - cz / #mobs)
    if away.Magnitude < 0.1 then
        away = Vector3.new(1, 0, 0)
    end
    return CFrame.new(myPos + away.Unit * (_env.ArenaFleeDistance or 60))
end

-- มอนใกล้สุดห่างจากเราเท่าไหร่
local function ArenaNearestMobDist()
    local root = ArenaGetRoot()
    if not root then return math.huge end
    local best = math.huge
    for _, p in ipairs(ArenaLiveMobPos()) do
        local d = (root.Position - p).Magnitude
        if d < best then best = d end
    end
    return best
end

-- พักที่จุดหนีจนเลือดเต็ม (มอนตามมาใกล้ค่อยย้ายจุดใหม่)
local function ArenaRestTick()
    local _, hum = ArenaMe()
    if not hum then
        print("Arena: waiting respawn...")
        _fleeCF = nil
        _wait(2)
        return
    end
    local pct = (hum.Health / hum.MaxHealth) * 100
    if pct >= 99.5 then
        print("Arena: HP full, resume (" .. math.floor(pct) .. "%)")
        _fleeCF = nil
        _env._arenaDeep = false
        return
    end
    if tick() - _deepT0 > (_env.ArenaMaxRest or 180) then
        print("Arena: hide timeout, back to fight")
        _fleeCF = nil
        _env._arenaDeep = false
        return
    end
    local root = ArenaGetRoot()
    if not root then return end
    if (_env.ArenaFleeMode or "Run Away") == "Hover Above" then
        -- โหมดลอยบนหัว : เกาะเหนือตัวที่ตี +30 Y (ตามตัวไปด้วยทุกติ๊ก)
        local _, troot = ArenaAboveTarget()
        if troot then
            local wantCF = CFrame.new(troot.Position + Vector3.new(0, 30, 0))
            if (root.Position - wantCF.Position).Magnitude > 5 then
                ArenaTweento(wantCF)
            end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        _wait(0.3)
        return
    end
    if not _fleeCF or ArenaNearestMobDist() < 30 then
        _fleeCF = ArenaFleePoint()
        if _fleeCF then
            print("Arena: fleeing to safe spot")
        end
    end
    if _fleeCF then
        if (root.Position - _fleeCF.Position).Magnitude > 8 then
            ArenaTweento(_fleeCF)
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    _wait(0.5)
end

-- high hide state: true = ลอยขึ้นบนเหนือตัวเดิมจนเลือดเต็ม (ข้างล่างโดนดึงกลับเลยไม่ลงแล้ว)
local function ArenaDeepUpdate()
    local _, hum = ArenaMe()
    if not hum then return _env._arenaDeep == true end
    local pct = (hum.Health / hum.MaxHealth) * 100
    if _env._arenaDeep then
        if pct >= 99.5 then
            _env._arenaDeep = false
            _fleeCF = nil
            print("Arena: HP full, back to fight")
        elseif tick() - _deepT0 > (_env.ArenaMaxRest or 180) then
            _env._arenaDeep = false
            _fleeCF = nil
            print("Arena: hide timeout, back to fight")
        end
    elseif ArenaShouldRetreat() then
        _env._arenaDeep = true
        _fleeCF = nil
        _deepT0 = tick()
        print("Arena: low HP, fleeing (" .. math.floor(pct) .. "%" .. ")")
    end
    return _env._arenaDeep == true
end

--==================================================
-- Kill (instance-based) + เช็คเลือดกลางไฟต์
--==================================================
local function ArenaKill(t)
    local model, hum, troot = t.model, t.hum, t.root
    print("Arena attacking: " .. model.Name .. " (hp " .. math.floor(hum.Health) .. ")")
    while hum.Health > 0 and model.Parent do
        if not _env.AutoArena then return end
        if ArenaDeepUpdate() then
            ArenaRestTick()
        else
            if not ArenaEquipped() then ArenaEquip() end
            ArenaTweento(ArenaAttackCF(troot, -(_env.ArenaDistance or 6)))
            local root = ArenaGetRoot()
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
            ArenaAttack()
            _wait()
        end
    end
    if hum.Health <= 0 then
        print("Arena killed: " .. model.Name)
    end
end

--==================================================
-- Main Loop
--==================================================
if not _env.LoadedArenaFunc then
    _env.LoadedArenaFunc = true
    task.spawn(function()
        while _wait() do
            if _env.AutoArena then
                local ok, err = pcall(function()
                    if ArenaDeepUpdate() then
                        ArenaRestTick()
                        return
                    end
                    local t, d, n, pending = ArenaNearest()
                    if t then
                        if _env._arenaLastT ~= t.model then
                            _env._arenaLastT = t.model
                            print("Arena target: " .. t.model.Name .. "|" .. math.floor(d) .. " Stud (" .. n .. " alive)")
                        end
                        ArenaKill(t)
                    elseif pending then
                        -- มีแต่มอนเกิดใหม่ : วาร์ปไปรอข้างๆ เลย อายุครบค่อยตี (ไม่ยืนนิ่ง)
                        if not ArenaEquipped() then ArenaEquip() end
                        ArenaTweento(ArenaAttackCF(pending.root, -(_env.ArenaDistance or 6)))
                        local proot = ArenaGetRoot()
                        if proot then
                            proot.AssemblyLinearVelocity = Vector3.zero
                            proot.AssemblyAngularVelocity = Vector3.zero
                        end
                        _wait(0.3)
                    else
                        local now = tick()
                        if now - (_env._arenaIdleT or 0) >= 10 then
                            _env._arenaIdleT = now
                            print("Arena: no target (waiting spawn)")
                        end
                        _wait(1)
                    end
                end)
                if not ok then ArenaError(err) end
            else
                _wait(0.5)
            end
        end
    end)
end

--==================================================
-- UI : MacHub V2 Arena
--==================================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/arsyny1x/replica-mac-ui/refs/heads/main/main.lua"))()

local Window = Library.CreateWindow({
    Title = "MacHub V2 Arena",
    Folder = "MacHub V2 Arena",
    AutoSaveSetting = true,
    Size = UDim2.fromOffset(650, 450),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Theme = _env.ArenaTheme,
    ToggleKey = Enum.KeyCode.RightControl,
})

-- Profile Tab
local ProfileTab = Window:CreateProfileTab({
    Title = "Roblox ID",
})

ProfileTab:Radio({
    Title = "Select Team",
    Flag = "Select Team",
    Default = "GHOUL",
    Options = { "GHOUL", "CCG" },
    Callback = function(v)
        _env.SelectTeam = v
    end,
})

ProfileTab:Toggle({
    Title = "Auto Select Team",
    Flag = "Auto Select Team",
    Icon = "lucide:mouse-pointer-click",
    Callback = function(v)
        _env.AutoSelectTeam = v
    end,
})

-- Main Tab
local MainTab = Window:CreateTab({
    Title = "General",
    Icon = "lucide:menu",
})

MainTab:SelectTab()

local console = MainTab:Console({ Height = 100 })

local oldPrint
oldPrint = hookfunction(print, function(...)
    oldPrint(...)

    local timeText = os.date("%H:%M:%S")

    local parts = {}
    for i, v in ipairs({ ... }) do
        parts[i] = tostring(v)
    end

    local message = table.concat(parts, " ")

    console:Log(timeText .. " " .. message, Color3.fromRGB(150, 150, 150))
end)

MainTab:Section({
    Title = "Auto Kill Mobs",
    Subtitle = "Kill mobs in AI/Player + Boss (never attack players)",
})

local AutoArena = MainTab:Toggle({
    Title = "Auto Attack Mobs",
    Subtitle = "Kill every mob, closest first. Never hits players.",
    Flag = "Auto Arena",
    Icon = "lucide:play",
})

AutoArena:OnChanged(function(v)
    _env.AutoArena = v
    if v then
        print("Auto Attack ON (mobs only, no players)")
        _env._arenaIdleT = 0
    else
        print("Auto Attack OFF")
        _env._arenaDeep = false
    end
    ArenaNoclip(v)
end)

MainTab:Section({
    Title = "Stay Alive",
    Subtitle = "When HP gets low, stop fighting and hide until HP is full.",
})

local AntiDeath = MainTab:Toggle({
    Title = "Auto Hide When HP Is Low",
    Subtitle = "Turn the whole hide system on or off.",
    Flag = "Anti Death",
    Icon = "lucide:heart-pulse",
})

AntiDeath:OnChanged(function(v)
    _env.ArenaAntiDeath = v
    if v then
        print("Auto Hide ON (hides below " .. tostring(_env.ArenaRetreatHP or 30) .. "% HP)")
    else
        print("Auto Hide OFF")
        _env._arenaDeep = false
    end
end)

MainTab:Slider({
    Title = "Hide When HP Below %",
    Subtitle = "Example: 30 means hide when HP drops to 30%.",
    Flag = "ArenaRetreatHP",
    Icon = "lucide:heart-crack",
    Min = 10,
    Max = 90,
    Default = _env.ArenaRetreatHP,
    Callback = function(v)
        _env["ArenaRetreatHP"] = v
        print("Hide below HP set: " .. tostring(v) .. "%")
    end,
})

MainTab:Dropdown({
    Title = "Hide Style",
    Subtitle = "Run Away teleports far from mobs. Hover Above floats +30 over the enemy.",
    Flag = "ArenaFleeMode",
    Icon = "lucide:wind",
    Values = { "Run Away", "Hover Above" },
    Value = _env.ArenaFleeMode,
    Callback = function(v)
        _env["ArenaFleeMode"] = v
        _fleeCF = nil
        print("Hide style: " .. tostring(v))
    end,
})

MainTab:Slider({
    Title = "Run-Away Distance",
    Subtitle = "Only used by Run Away style. How far to teleport from mobs.",
    Flag = "ArenaFleeDistance",
    Icon = "lucide:wind",
    Min = 10,
    Max = 150,
    Default = _env.ArenaFleeDistance,
    Callback = function(v)
        _env["ArenaFleeDistance"] = v
        print("Run-away distance set: " .. tostring(v) .. " studs")
    end,
})

MainTab:Section({
    Title = "How Hiding Works",
    Subtitle = "Run Away teleports far and waits. Hover Above follows the enemy from +30 above. Both return when HP is full (max 180s).",
})

-- Setting Tab
local Setting = Window:CreateTab({
    Title = "Setting",
    Icon = "lucide:cog",
})

Setting:Slider({
    Title = "Move Speed",
    Subtitle = "How fast you fly to targets. Higher is faster.",
    Flag = "ArenaTweenSpeed",
    Icon = "lucide:chevrons-up",
    Min = 50,
    Max = 300,
    Default = _env.ArenaTweenSpeed,
    Callback = function(v)
        _env["ArenaTweenSpeed"] = v
    end,
})

Setting:Slider({
    Title = "Teleport Range",
    Subtitle = "Farther than this teleports instead of flying.",
    Flag = "ArenaWarpDistance",
    Icon = "lucide:zap",
    Min = 10,
    Max = 50,
    Default = _env.ArenaWarpDistance,
    Callback = function(v)
        _env["ArenaWarpDistance"] = v
    end,
})

Setting:Slider({
    Title = "Target Check Delay",
    Subtitle = "How often to look for a new target. Higher means less lag but slower switching.",
    Flag = "ArenaScanRate",
    Icon = "lucide:timer",
    Min = 0.2,
    Max = 2,
    Default = _env.ArenaScanRate or 0.5,
    Callback = function(v)
        _env["ArenaScanRate"] = v
        print("Target check delay set: " .. tostring(v) .. "s (higher = less lag, slower switching)")
    end,
})

Setting:Section({
    Title = "Attack Position",
    Subtitle = "Where you stand when hitting an enemy. Default angle is 90.",
})

Setting:Slider({
    Title = "Attack Distance",
    Subtitle = "How far below the enemy you stand.",
    Flag = "ArenaDistance",
    Icon = "lucide:ruler",
    Min = 0,
    Max = 20,
    Default = _env.ArenaDistance,
    Callback = function(v)
        _env["ArenaDistance"] = v
    end,
})

Setting:Slider({
    Title = "Attack Angle",
    Subtitle = "Tilt while attacking. Default is 90.",
    Flag = "ArenaAngles",
    Icon = "lucide:rotate-cw",
    Min = 0,
    Max = 180,
    Default = _env.ArenaAngles,
    Callback = function(v)
        _env["ArenaAngles"] = v
    end,
})

Setting:Section({
    Title = "Set Theme",
})

Setting:Dropdown({
    Title = "Select Theme",
    Flag = "Arena Select Theme",
    Icon = "lucide:palette",
    Values = _env.ArenaTheme,
    Value = "Light",
    Callback = function(v)
        Window:SetTheme(v)
    end,
})

--==================================================
-- Load Config
--==================================================
pcall(function()
    Window:LoadConfig(_env.SaveArenaSettingPath)
end)

-- migrate old saved values to the new readable names + default angle 90
if _env.ArenaFleeMode == "Flee" then _env.ArenaFleeMode = "Run Away" end
if _env.ArenaFleeMode == "Above" then _env.ArenaFleeMode = "Hover Above" end
if _env.ArenaAngles == 40 then _env.ArenaAngles = 90 end



print("MacHub Arena loaded. Run this script ALONE in arena world (main.lua modes auto-disabled).")
