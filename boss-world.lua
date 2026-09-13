--==================================================
--  MacHub V2 | Boss World (World Boss Farm)
--  Entry : boss-world.lua (Executor, แยกจาก main.lua)
--  มีแค่ Auto Farm World Boss + UI เดิม (Profile/General/Setting)
--==================================================

-- Wait Game Loaded
pcall(function()
    local Selection = workspace:FindFirstChild("Model"):FindFirstChild("Selection")
    if game:GetService("Players").LocalPlayer.Team == nil and Selection then
        repeat
            task.wait()
        until #Selection:GetChildren() > 0
    end
end)

local LoadedScriptStartTime = tick()

local _env = getgenv()
local _wait = task.wait

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
    _env.SaveBossSettingPath = Player.UserId

    -- Direction
    _env.BossDistance = 6
    _env.BossAngles = 90

    -- Tween
    _env.BossTweenSpeed = 300
    _env.BossWarpDistance = 50

    -- Retry : Slider = ตั้งยอดรวมอย่างเดียว, กด AutoRetry = เอายอดนั้นไปใช้ (ไม่บวกเพิ่ม)
    if _env.RetryTotal == nil then _env.RetryTotal = 5 end
    if _env.RetryLeft == nil then _env.RetryLeft = _env.RetryTotal end
    if _env.AutoRetry == nil then _env.AutoRetry = false end
    if _env.RetryInfinite == nil then _env.RetryInfinite = false end
    _env._loadingConfig = true -- กัน LoadConfig ไปเติมรอบระหว่างโหลด

    -- UI themes
    _env.BossTheme = {
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
function Error(msg)
    local info = debug.getinfo(2)
    local line = info and info.currentline or "Unknown"
    local source = info and info.source or "Unknown"
    print("[error] Line: " .. line .. " | Source: " .. source .. " | Message: " .. tostring(msg))
end

function GetRootPart()
    local Character = Player.Character or Player.CharacterAdded:Wait()
    local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 5)
    return HumanoidRootPart
end

local function EnableNoclip(state)
    if state then
        if noclipLoop then
            return
        end

        noclipLoop = RunService.Stepped:Connect(function()
            local char = Player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")

            if char and hrp and hum then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end

                if hum.MoveDirection.Magnitude > 0 then
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                else
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)
    else
        if noclipLoop then
            noclipLoop:Disconnect()
            noclipLoop = nil
        end
    end
end

function SelectTeam(TeamName)
    local Selection = Model:WaitForChild("Selection", 9e4)
    local TeamPart = Selection:WaitForChild(TeamName, 5)

    if TeamPart and TeamPart:FindFirstChild("ClickDetector") then
        _wait(0.5)
        print("Select Team " .. TeamName)
        fireclickdetector(TeamPart.ClickDetector)
    end
end

--==================================================
-- Player Actions
--==================================================
function PlayerClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    _wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

function GetAttackRemote()
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
                    print("Captured Args!")
                end
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)

        print("Trigger click")
        _wait(0.5)
        PlayerClick()

        local timeout = 0
        repeat
            _wait(0.1)
            timeout = timeout + 0.1
        until _env.SavedArgs or timeout > 5
    end
    return _env.SavedArgs, _env.AttackRemote
end

function NormalAttack()
    local args, remote = GetAttackRemote()
    if args and remote then
        remote:FireServer(unpack(args))
    end
end

function IsEquipWeapon()
    local HUD = PlayerGui:WaitForChild("HUD", 3)
    if not HUD then
        return false
    end
    return HUD.Container.Skills.Visible
end

function EquipWeapon()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    _wait()
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    _wait(0.5)
end

function Tweento(targetCFrame)
    local character = Player.Character or Player.CharacterAdded:Wait()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end

    local warpDistance = _env.BossWarpDistance
    local speed = _env.BossTweenSpeed
    local minTweenTime = 0.1
    local startPos = hrp.Position
    local endPos = targetCFrame.Position
    local distance = (endPos - startPos).Magnitude

    if distance <= warpDistance then
        hrp.CFrame = targetCFrame
        return
    end

    local direction = (endPos - startPos).Unit
    local preWarpPos = endPos - direction * warpDistance
    local preWarpCFrame = CFrame.new(preWarpPos, endPos)
    local tweenDistance = (preWarpPos - startPos).Magnitude
    local timeToTravel = math.max(tweenDistance / speed, minTweenTime)
    local tweenInfo = TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, { CFrame = preWarpCFrame })

    tween:Play()
    tween.Completed:Wait()
    hrp.CFrame = targetCFrame
end

--==================================================
-- World Boss (dynamic list from Modules.DataBase["World bosses"])
--==================================================
local WorldBossData = {}

-- "World bosses" เป็น ModuleScript (return table) ไม่ใช่โฟลเดอร์ → require เอาชื่อ
local function LoadWorldBossData()
    for k in pairs(WorldBossData) do
        WorldBossData[k] = nil
    end
    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    local DataBase = Modules and Modules:FindFirstChild("DataBase")
    local mod = DataBase and DataBase:FindFirstChild("World bosses")
    if mod and mod:IsA("ModuleScript") then
        local ok, data = pcall(require, mod)
        if ok and type(data) == "table" then
            for name, info in pairs(data) do
                if type(name) == "string" then
                    WorldBossData[name] = info
                end
            end
        end
    end
end

local function GetWorldBossList()
    if not next(WorldBossData) then
        LoadWorldBossData()
    end
    local list = {}
    for name in pairs(WorldBossData) do
        table.insert(list, name)
    end
    if #list == 0 then
        return { "No Boss Found" }
    end
    table.sort(list)
    return list
end

-- กดปุ่ม Start ใน HUD เพื่อให้เวิลด์บอสเกิด (ต้องกดก่อนบอสถึงเกิด)
local function PressBossStart()
    local HUD = PlayerGui:FindFirstChild("HUD")
    local startBtn = HUD and HUD:FindFirstChild("Start")
    if not startBtn then
        return false
    end
    local ok = pcall(function()
        firesignal(startBtn.MouseButton1Click)
    end)
    if ok then
        print("Pressed Boss Start")
    end
    return ok
end

-- หาตัวบอสในแมพ : MobsFolder → MobsFolder.Boss (ลึก) → ใต้ workspace.AI (ลึก)
local function FindBossInstance(name)
    if not name or name == "" then
        return nil
    end
    if MobsFolder then
        local inst = MobsFolder:FindFirstChild(name)
        if inst then
            return inst
        end
        local bossFolder = MobsFolder:FindFirstChild("Boss")
        if bossFolder then
            local ok, found = pcall(function()
                return bossFolder:FindFirstChild(name, true)
            end)
            if ok and found then
                return found
            end
        end
    end
    local ai = workspace:FindFirstChild("AI")
    if ai then
        local ok, found = pcall(function()
            return ai:FindFirstChild(name, true)
        end)
        if ok and found then
            return found
        end
    end
    return nil
end

-- Kill Boss By Name (direct, ไม่หาใกล้สุด)
function KillBoss(name)
    if not name or name == "" then
        return
    end

    local Boss = FindBossInstance(name)
    if not Boss then
        return
    end

    local BossHumanoid = Boss:FindFirstChild("Humanoid")
    local BossRootPart = Boss:FindFirstChild("HumanoidRootPart")
    if not BossRootPart and Boss:IsA("Model") then
        BossRootPart = Boss.PrimaryPart
    end
    if not BossHumanoid or not BossRootPart then
        return
    end

    print("Found Boss: " .. Boss.Name)

    while BossHumanoid.Health > 0 and Boss.Parent do
        if not IsEquipWeapon() then
            EquipWeapon()
        end

        Tweento(BossRootPart.CFrame * CFrame.new(0, -_env.BossDistance, -3) * CFrame.Angles(math.rad(_env.BossAngles), 0, 0))

        local RootPart = GetRootPart()
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero

        NormalAttack()
        _wait()
    end
    print("Killed Boss: " .. name)
end

-- 1 tick = ฆ่า 1 ตัวที่เกิดแล้ว (ไม่เจอ = ข้าม)
local function WorldBossTick()
    local Selected = _env.SelectedWorldBoss
    if type(Selected) == "string" then
        Selected = { Selected }
        _env.SelectedWorldBoss = Selected
    end
    if type(Selected) ~= "table" then
        return
    end
    for _, BossName in ipairs(Selected) do
        if not _env.AutoFarmWorldBoss then
            return
        end
        if BossName and BossName ~= "" and BossName ~= "No Boss Found" then
            if FindBossInstance(BossName) then
                KillBoss(BossName)
                return -- ฆ่าทีละตัวต่อรอบ
            end
        end
    end
    -- มาถึงนี่ = ไม่มีบอสที่เลือกเกิดอยู่ : กด Start ให้เกิด + พิมพ์บอกทุก 5 วิ
    local now = tick()
    if now - (_env._worldBossStartT or 0) >= 3 then
        _env._worldBossStartT = now
        PressBossStart()
    end
    if now - (_env._worldBossMsgT or 0) >= 5 then
        _env._worldBossMsgT = now
        if #Selected == 0 then
            print("Auto Farm World Boss: no boss selected!")
        else
            print("Waiting for boss (not spawned): " .. table.concat(Selected, ", "))
        end
    end
end

--==================================================
-- Main Loop
--==================================================
if not _env.LoadedBossFunc then
    _env.LoadedBossFunc = true
    task.spawn(function()
        while _wait() do
            if not _env.LoadedBossData then
                repeat
                    _wait()
                until _env.LoadedBossData
            end

            if _env.AutoFarmWorldBoss then
                xpcall(WorldBossTick, Error)
            end
        end
    end)
end

--==================================================
-- UI : MacHub V2 Boss
--==================================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/arsyny1x/replica-mac-ui/refs/heads/main/main.lua"))()

local Window = Library.CreateWindow({
    Title = "MacHub V2 Boss",
    Folder = "MacHub V2 Boss",
    AutoSaveSetting = true,
    Size = UDim2.fromOffset(650, 450),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Theme = _env.BossTheme,
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
    Title = "World Boss Farm",
    Subtitle = "Select boss, then enable Auto Farm World Boss",
})

_env.SelectedWorldBoss = {}

local InitialBossList = GetWorldBossList()
if InitialBossList[1] and InitialBossList[1] ~= "No Boss Found" then
    _env.SelectedWorldBoss = { InitialBossList[1] }
end

local BossDropdown = MainTab:Dropdown({
    Title = "Select Boss",
    Subtitle = "Tap to select multiple",
    Flag = "Select World Boss",
    Icon = "lucide:skull",
    Values = InitialBossList,
    Multi = true,
    Default = _env.SelectedWorldBoss,
    Callback = function(v)
        if type(v) == "table" then
            _env.SelectedWorldBoss = v
        elseif v ~= nil then
            _env.SelectedWorldBoss = { v }
        end
        print("Selected Boss: " .. table.concat(_env.SelectedWorldBoss, ", "))
    end,
})

MainTab:Button({
    Title = "Refresh Boss List",
    Icon = "lucide:refresh-cw",
    Callback = function()
        LoadWorldBossData()
        local list = GetWorldBossList()
        BossDropdown:Refresh(list)
        print("Refreshed Boss list: " .. #list .. " found")
    end,
})

local AutoFarmWorldBoss = MainTab:Toggle({
    Title = "Auto Farm World Boss",
    Flag = "Auto Farm World Boss",
    Icon = "lucide:swords",
})

AutoFarmWorldBoss:OnChanged(function(v)
    _env.AutoFarmWorldBoss = v
    if v then
        local sel = _env.SelectedWorldBoss
        if type(sel) == "string" then
            sel = { sel }
        end
        if type(sel) ~= "table" or #sel == 0 then
            print("Auto Farm World Boss ON, but no boss selected!")
        else
            print("Auto Farm World Boss ON: " .. table.concat(sel, ", "))
        end
        _env._worldBossMsgT = 0
    end
    EnableNoclip(v)
end)

MainTab:Section({
    Title = "Retry Rounds",
    Subtitle = "Auto press Retry when boss round ends",
})

-- ซิงก์หน้าตา Slider Rounds ด้วยโค้ด (lib ไม่มี :Set ให้) : หาแถว Rounds
-- จากโครงสร้างแล้วขยับ fill/knob/ตัวเลขเอง ใช้ตอนนับรอบถดถอย
local function FindRetrySliderUI()
    local cached = _env._retrySliderUI
    if cached and cached.fill and cached.fill.Parent then
        return cached
    end
    _env._retrySliderUI = nil
    local ok, ui = pcall(function()
        return gethui():FindFirstChild("ReplicaMac")
    end)
    if not ok or not ui then
        return nil
    end
    for _, d in ipairs(ui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text == "Rounds" then
            local row = d.Parent
            if not (row and row:IsA("Frame")) then
                break
            end
            local container = nil
            for _, c in ipairs(row:GetChildren()) do
                if c:IsA("Frame") and c.Name ~= "Separator" then
                    container = c
                    break
                end
            end
            local bar = nil
            if container then
                for _, c in ipairs(container:GetChildren()) do
                    if c:IsA("Frame") and c.Size.Y.Offset == 5 then
                        bar = c
                        break
                    end
                end
            end
            local fill, knob = nil, nil
            if bar then
                for _, c in ipairs(bar:GetChildren()) do
                    if c:IsA("Frame") and c.Size.Y.Scale == 1 then
                        fill = c
                    elseif c:IsA("TextButton") then
                        knob = c
                    end
                end
            end
            local valueText = nil
            if knob then
                local popup = knob:FindFirstChildWhichIsA("CanvasGroup")
                if popup then
                    for _, c in ipairs(popup:GetChildren()) do
                        if c:IsA("Frame") and c:FindFirstChildWhichIsA("TextLabel") then
                            valueText = c:FindFirstChildWhichIsA("TextLabel")
                            break
                        end
                    end
                end
            end
            if fill and knob then
                _env._retrySliderUI = { fill = fill, knob = knob, valueText = valueText }
                return _env._retrySliderUI
            end
            break
        end
    end
    return nil
end

local function SyncRetrySlider(v)
    v = v or _env.RetryTotal or 0
    local parts = FindRetrySliderUI()
    if not parts then
        return false
    end
    local min, max = 0, 30 -- ตรงกับ Slider Rounds ข้างล่าง
    local pct = math.clamp((v - min) / math.max(max - min, 1), 0, 1)
    pcall(function()
        parts.fill.Size = UDim2.fromScale(pct, 1)
        parts.knob.Position = UDim2.fromScale(pct, 0.5)
        if parts.valueText then
            parts.valueText.Text = tostring(math.floor(v + 0.5))
        end
    end)
    return true
end

local RetryRoundsSlider = MainTab:Slider({
    Title = "Rounds",
    Flag = "RetryRounds",
    Icon = "lucide:repeat",
    Min = 0,
    Max = 30,
    Default = _env.RetryTotal,
    Callback = function(v)
        -- Slider มีไว้ตั้งยอดรวมอย่างเดียว (ไม่เติมรอบเอง กันลากแล้วรอบเด้ง)
        -- debounce กันสแปมตอนลาก : รับค่าล่าสุดหลังนิ่ง 0.5 วิ
        _env.RetryTotal = v
        _env._retrySetT = tick()
        task.spawn(function()
            local myT = _env._retrySetT
            _wait(0.5)
            if _env._retrySetT == myT and not _env._loadingConfig then
                print("Retry rounds set: " .. v)
                SyncRetrySlider(v)
            end
        end)
    end,
})

local AutoRetry = MainTab:Toggle({
    Title = "Auto Retry",
    Flag = "Auto Retry",
    Icon = "lucide:rotate-cw",
})

AutoRetry:OnChanged(function(v)
    _env.AutoRetry = v
    if v and not _env._loadingConfig then
        -- กดเปิดเอง = เอายอดจาก Slider ไปใช้ตรงๆ (ไม่บวกเพิ่ม)
        if not _env.RetryInfinite then
            _env.RetryLeft = _env.RetryTotal
        end
        SyncRetrySlider(_env.RetryInfinite and _env.RetryTotal or _env.RetryLeft)
        print("Auto Retry ON (" .. (_env.RetryInfinite and "infinite" or (tostring(_env.RetryLeft) .. " rounds")) .. ")")
    end
end)

local InfiniteRetry = MainTab:Toggle({
    Title = "Loop Forever",
    Flag = "Loop Forever",
    Icon = "lucide:infinity",
})

InfiniteRetry:OnChanged(function(v)
    _env.RetryInfinite = v
    print(v and "Retry mode: infinite loop" or ("Retry mode: " .. tostring(_env.RetryTotal or 0) .. " rounds"))
end)

-- Setting Tab
local Setting = Window:CreateTab({
    Title = "Setting",
    Icon = "lucide:cog",
})

Setting:Slider({
    Title = "Tween Speed",
    Flag = "BossTweenSpeed",
    Icon = "lucide:chevrons-up",
    Min = 50,
    Max = 1000,
    Default = _env.BossTweenSpeed,
    Callback = function(v)
        _env["BossTweenSpeed"] = v
    end,
})

Setting:Slider({
    Title = "Warp Distance",
    Flag = "BossWarpDistance",
    Icon = "lucide:zap",
    Min = 10,
    Max = 200,
    Default = _env.BossWarpDistance,
    Callback = function(v)
        _env["BossWarpDistance"] = v
    end,
})

Setting:Section({
    Title = "Direction Setting",
    Subtitle = "Adjust Attack Distance and Angle",
})

Setting:Slider({
    Title = "Distance",
    Flag = "BossDistance",
    Icon = "lucide:ruler",
    Min = 0,
    Max = 20,
    Default = _env.BossDistance,
    Callback = function(v)
        _env["BossDistance"] = v
    end,
})

Setting:Slider({
    Title = "Angles",
    Flag = "BossAngles",
    Icon = "lucide:rotate-cw",
    Min = 0,
    Max = 180,
    Default = _env.BossAngles,
    Callback = function(v)
        _env["BossAngles"] = v
    end,
})

Setting:Section({
    Title = "Set Theme",
})

Setting:Dropdown({
    Title = "Select Theme",
    Flag = "Boss Select Theme",
    Icon = "lucide:palette",
    Values = _env.BossTheme,
    Value = "Light",
    Callback = function(v)
        Window:SetTheme(v)
    end,
})

--==================================================
-- Auto Retry (กดปุ่ม Retry ให้เองตามรอบที่ตั้งไว้)
--==================================================
if not _env._retryWatch then
    _env._retryWatch = true
    task.spawn(function()
        local wasOpen = false
        while _wait(0.25) do
            local retryUI = PlayerGui:FindFirstChild("RetryUI")
            local frame = retryUI and retryUI:FindFirstChild("Frame")
            local isOpen = frame and frame.Parent.Enabled and frame.Visible
            if isOpen and not wasOpen then
                wasOpen = true
                local left = _env.RetryLeft or 0
                local sincePress = tick() - (_env._retryPressT or 0)
                local canPress = _env.AutoRetry and (_env.RetryInfinite or left > 0) and sincePress >= 8
                if canPress then
                    _env._retryPressT = tick()
                    _wait(2) -- รอให้หน้า Retry นิ่งก่อนกด (กันกดไวไปแล้ววืด)
                    local btn = frame:FindFirstChild("Retry")
                    if btn and frame.Parent.Enabled and frame.Visible then
                        pcall(function()
                            firesignal(btn.MouseButton1Click)
                        end)
                        if _env.RetryInfinite then
                            print("Retry pressed (infinite loop)")
                            SyncRetrySlider(_env.RetryTotal)
                        else
                            _env.RetryLeft = left - 1
                            print("Retry pressed (" .. _env.RetryLeft .. "/" .. tostring(_env.RetryTotal or "?") .. " left)")
                            SyncRetrySlider(_env.RetryLeft)
                            if _env.RetryLeft <= 0 then
                                -- หมดรอบแล้ว : ปิด toggle ให้เอง หยุดกดถาวร
                                _env.AutoRetry = false
                                pcall(function()
                                    AutoRetry:Set(false)
                                end)
                                print("Retry rounds finished, Auto Retry OFF")
                            end
                        end
                        _wait(3) -- กดแล้วพักก่อนรอบถัดไป (กันยิงถี่ตอนหลายรอบ)
                    end
                elseif _env.AutoRetry and (_env.RetryInfinite or left > 0) then
                    print("Retry skipped (cooldown)")
                else
                    print("RetryUI opened (auto-retry off or 0 rounds left)")
                end
            elseif not isOpen then
                wasOpen = false
            end
        end
    end)
end

--==================================================
-- Load Config + Wait Data
--==================================================
local LoadedScriptEndTime = LoadedScriptStartTime - tick()
print(string.format("Loaded Script In %.6fs", -LoadedScriptEndTime))

xpcall(function()
    local LoadedConfigStartTime = tick()
    task.spawn(function()
        pcall(function()
            Window:LoadConfig(_env.SaveBossSettingPath)
        end)
        _wait(2) -- รอ delayed refresh ของ lib จบก่อนเปิดรับ callback จริง
        if not _env._bossScriptRan then
            _env.RetryLeft = _env.RetryTotal -- รันครั้งแรก : รอบที่เหลือ = ตาม Slider
        end
        _env._bossScriptRan = true
        _env._loadingConfig = false
        SyncRetrySlider(_env.RetryLeft) -- โหลดเสร็จขยับปุ่มให้ตรงรอบที่เหลือ
    end)
    local LoadedConfigEndTime = LoadedConfigStartTime - tick()
    print(string.format("Loaded Config In %.6fs", -LoadedConfigEndTime))
end, Error)

while not Player:FindFirstChild("Data") do
    if _env.AutoSelectTeam then
        pcall(function()
            SelectTeam(_env.SelectTeam)
        end)
    end
    _wait(1)
end

repeat
    _wait()
until not PlayerGui:FindFirstChild("Temp")

task.delay(1, function() end)
_env.LoadedBossData = true
print("Data loaded")
