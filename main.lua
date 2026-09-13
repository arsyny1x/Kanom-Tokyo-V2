--==================================================
--  MacHub V2 | KanomTokyo
--  Entry : main.lua (Executor)
--  Logic เดิม 100% — จัดแค่ format / คอมเมนต์ให้อ่านง่าย
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
local GuiService = game:GetService("GuiService")
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
local QuestPath = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("TalkNpc"):WaitForChild("Quests")
local QuestRemotes = ReplicatedStorage:WaitForChild("Network")
local RagdollPath = workspace:WaitForChild("IncludeToGame"):WaitForChild("Ragdoll")
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
-- Quest Data
--==================================================
local Loaded, Funcs = {}, {} do
    Loaded.Quest = {}

    Funcs.GetPlayerLevel = function(self)
        return Player.Data.Level.Value or 0
    end

    Funcs.GetBestQuest = function(self)
        for _, Quest in ipairs(Loaded.Quest) do
            if Quest.LevelRequired <= Funcs.GetPlayerLevel() then
                return Quest
            end
        end
    end

    for _, v in next, QuestPath:GetChildren() do
        local Quest = v:FindFirstChild("Quest")
        if v.Name:match("QuestGiver") and Quest and Quest:IsA("ModuleScript") then
            local Success, MQuest = pcall(require, Quest)
            if Success and MQuest then
                table.insert(Loaded.Quest, {
                    GiverName = MQuest.GiverName or v.Name,
                    FolderName = v.Name,
                    QuestModule = Quest,
                    QuestInfo = MQuest.QuestInfo,
                    Target = MQuest.Target,
                    LevelRequired = MQuest.LevelRequired or 0,
                })
            end
        end
    end

    table.sort(Loaded.Quest, function(a, b)
        return a.LevelRequired > b.LevelRequired
    end)
end

--==================================================
-- Config
--==================================================
do
    _env.SaveSettingPath = Player.UserId

    -- Direction
    _env.Distance = 6
    _env.Angles = 90

    -- Tween
    _env.TweenSpeed = 1000
    _env.WarpDistance = 100

    -- ชื่อรีโมทเควสที่รู้จัก (ถ้าเปลี่ยนเซิร์ฟเวอร์แล้วไม่มีชื่อนี้ จะค้นหาใหม่เอง)
    _env.QuestRemoteName = "{1D59754F-9078-407D-A57E-CFE305974190}"

    -- UI themes
    _env.Theme = {
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
-- Quest Functions
--==================================================
function IsQuest()
    return PlayerGui.HUD:FindFirstChild("Quest")
end

function RemoveQuest()
    if _env.QuestRemote then
        _env.QuestRemote:FireServer("RemoveQuest")
        _wait(0.5)
    else
        local Quest = PlayerGui:FindFirstChild("Quest", 3)
        if Quest then
            local Close = Quest:WaitForChild("Close", 3)
            firesignal(Close.MouseButton1Click)
            _wait(0.5)
        end
    end
end

function IsValidQuest(QuestInfo)
    local Quest = PlayerGui:FindFirstChild("Quest", 3)
    if Quest then
        local CurrentQuestInfo = Quest.QuestInfo.Text
        return CurrentQuestInfo == QuestInfo
    end
end

function TakeQuest(arg)
    -- หา quest data ที่เก็บ QuestModule ตัวจริงไว้ตอนโหลด (ไม่เดาชื่อโฟลเดอร์)
    local questData = nil
    if type(arg) == "table" and arg.QuestModule then
        questData = arg
    else
        for _, q in ipairs(Loaded.Quest) do
            if q.GiverName == arg then
                questData = q
                break
            end
        end
    end
    if not questData or not questData.QuestModule then
        print("TakeQuest failed, quest not found: " .. tostring(arg))
        return
    end
    local GiverName = questData.GiverName

    local args = {
        "RequestQuest",
        questData.QuestModule,
    }

    -- หา NPC ผู้ให้เควส : ลอง GiverName → FolderName → ค้นทั้ง TalkNpc
    local giverRoot = nil
    local talkNpc = workspace:FindFirstChild("TalkNpc")
    local giverFolder = talkNpc and talkNpc:FindFirstChild("QuestGiver")
    if giverFolder then
        local npc = giverFolder:FindFirstChild(GiverName)
            or (questData.FolderName and giverFolder:FindFirstChild(questData.FolderName))
        giverRoot = npc and npc:FindFirstChild("HumanoidRootPart")
    end
    if not giverRoot and talkNpc then
        for _, v in ipairs(talkNpc:GetDescendants()) do
            if v.Name == GiverName or (questData.FolderName and v.Name == questData.FolderName) then
                if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") then
                    giverRoot = v:FindFirstChild("HumanoidRootPart")
                    break
                elseif v:IsA("BasePart") then
                    giverRoot = v
                    break
                end
            end
        end
    end
    if not giverRoot then
        print("TakeQuest failed, giver not found: " .. tostring(GiverName))
        return
    end

    Tweento(giverRoot.CFrame * CFrame.new(0, 0, 3) * CFrame.Angles(0, math.rad(180), 0))

    -- 1) รีโมทที่จำไว้ (ถ้าตัวจริงยังอยู่)
    if _env.QuestRemote and not _env.QuestRemote.Parent then
        _env.QuestRemote = nil
    end
    -- 2) ชื่อรีโมทที่รู้จัก (GUID ที่เคยเจอว่าใช้ได้)
    if not _env.QuestRemote then
        local net = ReplicatedStorage:FindFirstChild("Network")
        local known = net and _env.QuestRemoteName and net:FindFirstChild(_env.QuestRemoteName)
        if known and known:IsA("RemoteEvent") then
            _env.QuestRemote = known
            print("Use known quest remote")
        end
    end
    -- 3) ยิงด้วยตัวที่ได้
    if _env.QuestRemote then
        pcall(function()
            _env.QuestRemote:FireServer(unpack(args))
        end)
    else
        -- 4) ค้นหาใหม่ : ชื่อทรง GUID (เช่น {...}) ลองก่อน
        local net = ReplicatedStorage:FindFirstChild("Network")
        local cands = {}
        if net then
            for _, v in ipairs(net:GetChildren()) do
                if v:IsA("RemoteEvent") then
                    if v.Name:match("^%b{}$") then
                        table.insert(cands, 1, v)
                    else
                        table.insert(cands, v)
                    end
                end
            end
        end
        for _, v in ipairs(cands) do
            pcall(function()
                v:FireServer(unpack(args))
            end)
            -- รอผลต่อรีโมทนานหน่อยก่อนตัดสิน (กันเซิร์ฟแล็กแล้วเลยรีโมทถูก)
            local okT = tick()
            local found = false
            while tick() - okT < 2 do
                if IsQuest() then
                    found = true
                    break
                end
                _wait(0.2)
            end
            if found then
                _env.QuestRemote = v
                _env.QuestRemoteName = v.Name
                print("Found Remote " .. v.Name)
                break
            else
                print("Try Remote " .. v.Name .. " (no quest)")
            end
        end
        if not _env.QuestRemote then
            print("TakeQuest failed, no quest remote found")
            return
        end
    end

    -- ยืนยันว่ารับเควสติดจริง (กัน remote เก่าค้างแล้วยิงลงหลุม)
    local t0 = tick()
    while tick() - t0 < 3 do
        if IsQuest() then
            _env._takeFail = 0
            return true
        end
        _wait(0.2)
    end

    _env._takeFail = (_env._takeFail or 0) + 1
    print("TakeQuest NOT accepted (" .. tostring(_env._takeFail) .. "x): " .. tostring(GiverName))
    if _env._takeFail >= 3 then
        _env.QuestRemote = nil
        _env._takeFail = 0
        print("Reset quest remote, will rediscover next try")
    end
    return false
end

-- หา ProximityPrompt ของ NPC ผู้ให้เควส (เช่น TalkNpc.QuestGiver.<ชื่อ>.HumanoidRootPart.ProximityPrompt)
local function GetGiverPrompt(questData)
    if not questData then
        return nil
    end
    local talkNpc = workspace:FindFirstChild("TalkNpc")
    if not talkNpc then
        return nil
    end
    local names = {}
    if questData.GiverName then
        table.insert(names, questData.GiverName)
    end
    if questData.FolderName and questData.FolderName ~= questData.GiverName then
        table.insert(names, questData.FolderName)
    end
    -- 1) ตรงโฟลเดอร์ QuestGiver
    local qg = talkNpc:FindFirstChild("QuestGiver")
    if qg then
        for _, n in ipairs(names) do
            local npc = qg:FindFirstChild(n)
            if npc then
                local pr = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
                if pr then
                    return pr
                end
            end
        end
    end
    -- 2) deep-search ทั้ง TalkNpc
    for _, d in ipairs(talkNpc:GetDescendants()) do
        if d:IsA("Model") and (d.Name == names[1] or d.Name == names[2]) then
            local pr = d:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pr then
                return pr
            end
        end
    end
    return nil
end

-- ปิด NpcDialogue ที่เปิดค้างด้วยปุ่ม Goodbye (กัน dialog เก่าของ NPC ตัวอื่นค้าง)
local function CloseDialog()
    local dlg = PlayerGui:FindFirstChild("NpcDialogue")
    if not dlg then
        return true
    end
    local ansList = dlg:FindFirstChild("Container") and dlg.Container:FindFirstChild("AnswerList")
    local bye = ansList and ansList:FindFirstChild("Goodbye")
    if bye then
        pcall(function()
            firesignal(bye.MouseButton1Click)
        end)
    end
    local t = tick()
    while tick() - t < 2 do
        if not PlayerGui:FindFirstChild("NpcDialogue") then
            break
        end
        _wait(0.2)
    end
    if not PlayerGui:FindFirstChild("NpcDialogue") then
        print("Closed stale dialog")
        return true
    end
    return false
end

-- รับเควสผ่าน dialog : tween หา NPC → เปิด prompt → คลิกข้ามบทพูด → กด Choice
function TakeQuestViaDialog(arg)
    local questData = nil
    if type(arg) == "table" and arg.GiverName then
        questData = arg
    else
        for _, q in ipairs(Loaded.Quest) do
            if q.GiverName == arg then
                questData = q
                break
            end
        end
    end
    if not questData then
        print("TakeQuestViaDialog failed, quest not found: " .. tostring(arg))
        return false
    end

    print("Dialog take: " .. tostring(questData.GiverName))
    local prompt = GetGiverPrompt(questData)
    if not prompt then
        print("TakeQuestViaDialog failed, prompt not found: " .. tostring(questData.GiverName))
        return false
    end
    print("Dialog prompt found")
    CloseDialog()
    if typeof(fireproximityprompt) ~= "function" then
        print("TakeQuestViaDialog failed, executor has no fireproximityprompt")
        return false
    end

    -- บินไปจนถึง NPC จริง (ยิง tween ซ้ำถ้ายังไม่ถึง) ไม่ถึง = ไม่ยิง
    local prt = prompt.Parent
    if not (prt and prt:IsA("BasePart")) then
        print("TakeQuestViaDialog failed, bad prompt part: " .. tostring(questData.GiverName))
        return false
    end
    local arriveDist = 8
    pcall(function()
        if prompt.MaxActivationDistance then
            arriveDist = math.max(prompt.MaxActivationDistance - 2, 3)
        end
    end)
    if not TweentoWait(prt.CFrame * CFrame.new(0, 0, 3), 12, arriveDist) then
        print("TakeQuestViaDialog failed, cannot reach NPC: " .. tostring(questData.GiverName))
        return false
    end
    print("Reached NPC, firing prompt...")

    -- ยิง prompt ซ้ำจนกว่า dialog ของ NPC ตัวนี้จะเปิด (กันยิงวืด / dialog ค้างของตัวอื่น)
    local dlg = nil
    local t0 = tick()
    local tries = 0
    while tick() - t0 < 15 and not dlg do
        tries = tries + 1
        pcall(fireproximityprompt, prompt)
        print("Dialog prompt fired (" .. tries .. "x)")
        local w0 = tick()
        while tick() - w0 < 1.5 do
            local cur = PlayerGui:FindFirstChild("NpcDialogue")
            if cur then
                local npcName = ""
                pcall(function()
                    npcName = cur.Container.Head.NpcName.Text
                end)
                if npcName ~= "" and npcName ~= questData.GiverName and npcName ~= (questData.FolderName or "") then
                    print("Wrong NPC dialog (" .. tostring(npcName) .. "), closing...")
                    CloseDialog()
                    cur = nil
                    _wait(0.5)
                else
                    dlg = cur
                    break
                end
            end
            _wait(0.2)
        end
    end
    if not dlg then
        print("TakeQuestViaDialog failed, dialog not opened: " .. tostring(questData.GiverName))
        return false
    end
    print("Dialog opened, pressing Choice...")
    _wait(0.5) -- ให้ UI เซ็ตตัวแป๊บนึง

    -- กด Choice พร้อมคลิกข้ามบทพูดไปพร้อมกัน (อันไหนติดก่อนเอาเลย ไม่รอแยกเฟส)
    local t1 = tick()
    while tick() - t1 < 8 do
        if IsQuest() then
            print("Quest accepted via dialog: " .. tostring(questData.GiverName))
            return true
        end
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(5, 5, 0, true, game, 1)
            _wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(5, 5, 0, false, game, 1)
        end)
        local container = dlg:FindFirstChild("Container")
        local ansList = container and container:FindFirstChild("AnswerList")
        local choice = ansList and ansList:FindFirstChild("Choice")
        if choice then
            pcall(function()
                firesignal(choice.MouseButton1Click)
            end)
        end
        _wait(0.25)
    end

    print("TakeQuestViaDialog NOT accepted: " .. tostring(questData.GiverName))
    return false
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

    local warpDistance = _env.WarpDistance
    local speed = _env.TweenSpeed
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

-- Tween ไปจนถึงจริง (ยิง tween ซ้ำถ้ายังไม่ถึง เช่นโดนดึงกลับ) คืน true ถ้าถึงใน timeout
function TweentoWait(targetCFrame, timeout, arriveDist)
    timeout = timeout or 10
    arriveDist = arriveDist or 8
    local t0 = tick()
    while tick() - t0 < timeout do
        Tweento(targetCFrame)
        local root = GetRootPart()
        if root then
            local d = (root.Position - targetCFrame.Position).Magnitude
            if d <= arriveDist then
                return true
            end
        end
        _wait(0.3)
    end
    return false
end

--==================================================
-- Monsters
--==================================================
function EatMonster(name)
    _wait(0.5)
    local RootPart = GetRootPart()
    for _, Mob in next, workspace.IncludeToGame.Ragdoll:GetChildren() do
        if Mob.PrimaryPart and Mob.Name == name then
            local Distance = (Mob.PrimaryPart.Position - RootPart.Position).Magnitude

            if Distance <= 40 then
                local ClickHitbox = Mob:FindFirstChild("ClickHitbox")
                local ClickDetector = ClickHitbox:FindFirstChildWhichIsA("ClickDetector")
                if ClickHitbox and ClickDetector then
                    Mob.PrimaryPart.CFrame = RootPart.CFrame
                    _wait(0.3)
                    fireclickdetector(ClickDetector)
                    print("Eating: " .. Mob.Name)
                    _wait(2.5)
                end
            end
        end
    end
end

function GetCloseMonster(name)
    local RootPart = GetRootPart()

    local CloseMonster = nil
    local BestDistance = math.huge

    for _, v in MobsFolder:GetChildren() do
        local MobsHumanoid = v:FindFirstChild("Humanoid")
        if v.Name == name and MobsHumanoid and MobsHumanoid.Health > 0 then
            local MobRootPart = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
            if MobRootPart then
                local Distance = (RootPart.Position - MobRootPart.Position).Magnitude
                if Distance < BestDistance then
                    BestDistance = Distance
                    CloseMonster = v
                end
            end
        end
    end

    if CloseMonster and BestDistance then
        print("Found Close Monster: " .. CloseMonster.Name .. "|" .. math.floor(BestDistance) .. " Stud")
    end
    return CloseMonster
end

function KillMonster(name)
    local CloseMonster = GetCloseMonster(name)
    if not CloseMonster then
        return
    end

    local MobsHumanoid = CloseMonster:FindFirstChild("Humanoid")
    local MobsRootPart = CloseMonster:FindFirstChild("HumanoidRootPart")
    if not MobsRootPart and MobsHumanoid then
        return
    end

    while MobsHumanoid.Health > 0 and CloseMonster.Parent do
        if not IsEquipWeapon() then
            EquipWeapon()
        end

        Tweento(MobsRootPart.CFrame * CFrame.new(0, -_env.Distance, -3) * CFrame.Angles(math.rad(_env.Angles), 0, 0))

        local RootPart = GetRootPart()
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero

        NormalAttack()
        _wait()
    end

    if _env.AutoEat then
        EatMonster(name)
    end
end

--==================================================
-- Boss (dynamic list from Modules.DataBase.Npc.Boss)
--==================================================
local function GetBossDataFolder()
    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    local DataBase = Modules and Modules:FindFirstChild("DataBase")
    local Npc = DataBase and DataBase:FindFirstChild("Npc")
    return Npc and Npc:FindFirstChild("Boss") or nil
end

local function GetBossList()
    local list = {}
    local folder = GetBossDataFolder()
    if not folder then
        return { "No Boss Found" }
    end
    if folder:IsA("ModuleScript") then
        -- เป็นโมดูล return table (แบบ World bosses) → require เอาชื่อ key
        local ok, data = pcall(require, folder)
        if ok and type(data) == "table" then
            for name in pairs(data) do
                if type(name) == "string" and not table.find(list, name) then
                    table.insert(list, name)
                end
            end
        end
    else
        for _, v in ipairs(folder:GetChildren()) do
            if not table.find(list, v.Name) then
                table.insert(list, v.Name)
            end
        end
    end
    if #list == 0 then
        return { "No Boss Found" }
    end
    table.sort(list)
    return list
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

-- Kill Boss By Name (direct, no closest-search like KillMonster)
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

        Tweento(BossRootPart.CFrame * CFrame.new(0, -_env.Distance, -3) * CFrame.Angles(math.rad(_env.Angles), 0, 0))

        local RootPart = GetRootPart()
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero

        NormalAttack()
        _wait()
    end
    print("Killed Boss: " .. name)
end

--==================================================
-- Quest Select (dynamic list from Loaded.Quest)
--==================================================
local function GetQuestList()
    local list = {}
    for _, q in ipairs(Loaded.Quest) do
        if q.GiverName and not table.find(list, q.GiverName) then
            table.insert(list, q.GiverName)
        end
    end
    if #list == 0 then
        return { "No Quest Found" }
    end
    return list
end

local function FindQuestByGiver(giverName)
    if not giverName then
        return nil
    end
    for _, q in ipairs(Loaded.Quest) do
        if q.GiverName == giverName then
            return q
        end
    end
    return nil
end

-- เควสที่ถืออยู่ตอนนี้ตรงกับเควสที่ติ๊กไว้ใน Selected หรือไม่ (มี = เจ้าของคือ Selected)
local function GetHeldSelectedQuest()
    if not IsQuest() then
        return nil
    end
    local sel = _env.SelectedQuests
    if type(sel) == "string" then
        sel = { sel }
    end
    if type(sel) ~= "table" then
        return nil
    end
    for _, name in ipairs(sel) do
        local q = FindQuestByGiver(name)
        if q and IsValidQuest(q.QuestInfo) then
            return q
        end
    end
    return nil
end

--==================================================
-- Selected Quest Farm (tab Select Farm)
--==================================================
local function FarmSelectedQuestsTick()
    local Selected = _env.SelectedQuests
    if type(Selected) == "string" then
        Selected = { Selected }
        _env.SelectedQuests = Selected
    end
    if type(Selected) ~= "table" or #Selected == 0 then
        return
    end

    local PlayerLevel = 0
    pcall(function()
        PlayerLevel = Player.Data.Level.Value or 0
    end)

    -- ถ้าถือเควสที่เลือกไว้อยู่แล้ว → ฟาร์มเควสนั้นต่อจนจบ ไม่สลับกลางคัน
    local current = GetHeldSelectedQuest()
    if not current then
        -- ถือเควสของคนอื่นอยู่ (เช่นของ Level farm) → รอ ไม่แย่ง
        if IsQuest() then
            return
        end
        -- หยิบคิวถัดไปที่เวลถึง (วนตามลำดับที่ติ๊กไว้)
        local n = #Selected
        for i = 1, n do
            _env._selectedIdx = ((_env._selectedIdx or 0) % n) + 1
            local cand = FindQuestByGiver(Selected[_env._selectedIdx])
            if cand and (cand.LevelRequired or 0) <= PlayerLevel then
                current = cand
                break
            end
        end
        if not current then
            return -- ไม่มีเควสที่รับได้เลย (เวลไม่ถึง/ชื่อผิด) รอรอบหน้า
        end
        -- เลือกไว้มากกว่า 1 เควส → รับผ่าน dialog NPC (เสถียรกว่าตอนสลับเควสบ่อย)
        local selCount = (type(Selected) == "table") and #Selected or 0
        if selCount > 1 then
            TakeQuestViaDialog(current)
        else
            TakeQuest(current.GiverName)
        end
        print("TakeQuest: " .. current.GiverName)
        _wait(0.5)
        if not IsValidQuest(current.QuestInfo) then
            return -- รับไม่ติด รอรอบหน้า
        end
    end

    for _, MonsterName in ipairs(current.Target or {}) do
        if not _env.AutoFarmSelected then
            return
        end
        -- ไม่เจอมอน = ข้ามไปตัวต่อไปเลย (ไม่รอ)
        if MobsFolder:FindFirstChild(MonsterName) then
            KillMonster(MonsterName)
        end
    end
end

--==================================================
--==================================================
-- Quest Board (auto : NPC กดคุย → เปิดจอ → รับ → ฟาร์มตาม Type)
-- ข้อมูลเควสอ่านสดจาก Modules.DataBase.QuestBoard (require ตามชื่อ)
--==================================================
local function GetBoardDBFolder()
    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    local DataBase = Modules and Modules:FindFirstChild("DataBase")
    return DataBase and DataBase:FindFirstChild("QuestBoard") or nil
end

-- ข้อมูลบอร์ดเควสตามชื่อ (cache)
local function GetBoardQuestData(name)
    if not name or name == "" then
        return nil
    end
    _env._boardDB = _env._boardDB or {}
    if _env._boardDB[name] ~= nil then
        return _env._boardDB[name] or nil
    end
    local folder = GetBoardDBFolder()
    local mod = folder and folder:FindFirstChild(name, true)
    if mod and mod:IsA("ModuleScript") then
        local ok, m = pcall(require, mod)
        if ok and type(m) == "table" then
            local info = {
                Name = m.Name or name,
                Type = m.Type,
                Target = m.Target,
                LevelRequired = m.LevelRequired or 0,
                QuestInfo = m.QuestInfo,
                Goal = m.Goal,
            }
            _env._boardDB[name] = info
            return info
        end
    end
    _env._boardDB[name] = false
    return nil
end

-- เควสบอร์ดที่ถืออยู่ตอนนี้ (เทียบ QuestInfo ใน HUD กับ DB) : ไม่ใช่ = nil
local function GetHeldBoardQuest()
    local hud = PlayerGui:FindFirstChild("HUD")
    local hq = hud and hud:FindFirstChild("Quest")
    local qi = hq and hq:FindFirstChild("QuestInfo")
    local text = qi and qi.Text
    if not text or text == "" then
        return nil
    end
    local folder = GetBoardDBFolder()
    if not folder then
        return nil
    end
    for _, mod in ipairs(folder:GetDescendants()) do
        if mod:IsA("ModuleScript") then
            local info = GetBoardQuestData(mod.Name)
            if info and info.QuestInfo == text then
                return info
            end
        end
    end
    return nil
end

-- เควสนี้ล่าบอสใช่ไหม (target อยู่ใน Boss แต่ไม่อยู่ในมอนปกติ)
local function IsBoardBossQuest(info)
    if not info or type(info.Target) ~= "table" or #info.Target == 0 then
        return false
    end
    for _, t in ipairs(info.Target) do
        if MobsFolder and MobsFolder:FindFirstChild(t) then
            return false -- มีมอนปกติให้ตี = ไม่ใช่เควสบอส
        end
    end
    for _, t in ipairs(info.Target) do
        if FindBossInstance(t) then
            return true
        end
    end
    return false
end

local function GetBoardGui()
    return PlayerGui:FindFirstChild("QuestBoard")
end

local function CloseBoardGui()
    local gui = GetBoardGui()
    if not gui then
        return
    end
    local exitBtn = gui:FindFirstChild("Container") and gui.Container:FindFirstChild("QuestContent") and gui.Container.QuestContent:FindFirstChild("Exit")
    if exitBtn then
        pcall(function()
            firesignal(exitBtn.MouseButton1Click)
        end)
    end
    _wait(0.3)
end

-- ไปเปิดจอบอร์ด (tween หา NPC → ยิง prompt ซ้ำจนจอเปิด)
local function OpenBoardGui()
    local gui = GetBoardGui()
    if gui then
        return gui
    end
    local talkNpc = workspace:FindFirstChild("TalkNpc")
    local board = talkNpc and talkNpc:FindFirstChild("Quest board")
    local hrp = board and board:FindFirstChild("HumanoidRootPart")
    local prompt = hrp and hrp:FindFirstChild("ProximityPrompt")
    if not prompt then
        print("Quest Board: prompt not found")
        return nil
    end
    if typeof(fireproximityprompt) ~= "function" then
        print("Quest Board: executor has no fireproximityprompt")
        return nil
    end
    TweentoWait(hrp.CFrame * CFrame.new(0, 0, 5), 12, 8)
    local t0 = tick()
    local tries = 0
    while tick() - t0 < 10 and _env.AutoQuestBoard do
        tries = tries + 1
        pcall(fireproximityprompt, prompt)
        local w0 = tick()
        while tick() - w0 < 1.5 do
            gui = GetBoardGui()
            if gui then
                break
            end
            _wait(0.2)
        end
        if gui then
            break
        end
    end
    if not gui then
        print("Quest Board: dialog not opened")
        return nil
    end
    return gui
end

-- อ่านเควสที่จอบอร์ดโชว์อยู่
local function ReadBoardQuest(gui)
    local qc = gui and gui:FindFirstChild("Container") and gui.Container:FindFirstChild("QuestContent")
    if not qc then
        return nil
    end
    local acc = qc:FindFirstChild("Accept")
    local c = acc and acc.BackgroundColor3
    local lvlText = qc:FindFirstChild("Level") and qc.Level.Text or ""
    return {
        name = qc:FindFirstChild("QuestName") and qc.QuestName.Text or "",
        action = acc and acc:FindFirstChild("Action") and acc.Action.Text or "",
        r = c and math.floor(c.R * 255 + 0.5) or 999,
        g = c and math.floor(c.G * 255 + 0.5) or 999,
        levelReq = tonumber(string.match(lvlText, "(%d+)")) or 0,
    }
end

-- อ่าน state จริงของจอบอร์ดจากเกม (index ปัจจุบัน + รายการเควสพร้อม UID/completed)
-- จำเป็นเพราะเควสชื่อซ้ำกันได้ (เช่น Shadows of Rin 2 UID) ดูแค่ชื่อแยกไม่ออก
local function GetBoardState(gui)
    if not gui then
        return nil
    end
    local nxt = gui.Container and gui.Container:FindFirstChild("Next")
    if not nxt then
        return nil
    end
    if typeof(getconnections) ~= "function" then
        return nil
    end
    local ok, conns = pcall(function()
        return getconnections(nxt.MouseButton1Click)
    end)
    if not ok or not conns or not conns[1] then
        return nil
    end
    local fn = conns[1].Function
    if typeof(fn) ~= "function" then
        return nil
    end
    local getups = debug and debug.getupvalues
    if typeof(getups) ~= "function" then
        return nil
    end
    local ok2, ups = pcall(getups, fn)
    if not ok2 or type(ups) ~= "table" then
        return nil
    end
    local idx, list = ups[1], ups[2]
    if type(idx) ~= "number" or type(list) ~= "table" or #list == 0 then
        return nil
    end
    return { idx = idx, list = list }
end

-- คลิกจริงแบบ ClickUI (VIM) : ปุ่ม Next/Previous ของบอร์ดต้องใช้คลิกจริงเท่านั้น
-- firesignal เรียก handler บนเธรด executor ทำให้ require ใน Refresh ของเกมพัง
-- (index ขยับแต่จอค้าง ปุ่ม Accept ส่งโมดูลผิดตัวตาม) พิสูจน์ในเกมแล้ว
-- VIM ต้องบวก GuiInset.Y (ขอบบน 58px) ไม่งั้นคลิกพลาดเป้า (เทสในเกม: ไม่บวก 0/3, บวก 2/2)
local function ClickUI(btn)
    if not btn or not btn.AbsolutePosition or not btn.Visible then
        return false
    end
    local x = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
    local y = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2)
    local okInset, inset = pcall(function()
        return GuiService:GetGuiInset()
    end)
    if okInset and inset then
        y = y + inset.Y
    end
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
    end)
    task.wait(0.05)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)
    return true
end
local ClickBoardButton = ClickUI

-- กด Next/Previous ด้วยคลิกจริง แล้วรอจน index ขยับ (กันคลิกวืด เช่น toast ลอยบัง)
-- คืน idx ใหม่ (หรือเดิมถ้าไม่ขยับครบ 3 ครั้ง)
local function ClickBoardNav(gui, dir)
    gui = gui or GetBoardGui()
    if not gui then
        return nil
    end
    local function navBtn(g, d)
        return g and g.Container and g.Container:FindFirstChild(d == "prev" and "Previous" or "Next")
    end
    local st0 = GetBoardState(gui)
    local before = st0 and st0.idx or nil
    for _ = 1, 3 do
        if not _env.AutoQuestBoard then
            return nil
        end
        local g = GetBoardGui()
        if not g then
            return nil
        end
        ClickBoardButton(navBtn(g, dir))
        _wait(1) -- รอ Refresh ของเกมวาดจอตาม
        local st = GetBoardState(GetBoardGui())
        if st and before and st.idx ~= before then
            return st.idx
        end
        if not before then
            return st and st.idx or nil
        end
    end
    -- ไม่ขยับเลย : ลองอีกปุ่มสะกิดทีนึง
    local g = GetBoardGui()
    if g then
        ClickBoardButton(navBtn(g, dir == "prev" and "next" or "prev"))
        _wait(1)
        local st = GetBoardState(GetBoardGui())
        if st then
            return st.idx
        end
    end
    return before
end

-- ปุ่ม Accept เขียว + ข้อความ Accept (จอเชื่อถือได้เพราะใช้คลิกจริงนำทาง)
local function BoardIsGreen(shown)
    return shown and shown.action == "Accept" and shown.r < 50 and shown.g > 100
end

local function BoardQuestAcceptable(info, shown, entry)
    if not info or not shown then
        return false
    end
    if entry and entry.isCompleted then
        return false -- รับไปแล้ว (ดูจาก UID ของเกม ชื่อซ้ำก็แยกออก)
    end
    if shown.action ~= "Accept" then
        return false -- On Progress / Completed
    end
    if not (shown.r < 50 and shown.g > 100) then
        return false -- ปุ่มไม่เขียว = รับไม่ได้
    end
    local plvl = 0
    pcall(function()
        plvl = Player.Data.Level.Value or 0
    end)
    if (info.LevelRequired or 0) > plvl then
        return false
    end
    if info.Type == "Collect" and _env.SkipBoardCollect then
        return false
    end
    if IsBoardBossQuest(info) then
        if _env.SkipBoardBoss then
            local spawned = false
            for _, t in ipairs(info.Target or {}) do
                if FindBossInstance(t) then
                    spawned = true
                    break
                end
            end
            if not spawned then
                return false
            end
        end
    end
    return true
end

-- เก็บหีบ (Collect) : วนยิง prompt ทุกหีบในแมพ 1 รอบ
local function CollectChest()
    for _, chest in ipairs(workspace:GetChildren()) do
        if not _env.AutoQuestBoard then
            return
        end
        if chest.Name == "Chest" and chest:IsA("Model") then
            local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            local part = prompt and prompt.Parent
            if prompt and part and part:IsA("BasePart") then
                if TweentoWait(part.CFrame * CFrame.new(0, 0, 4), 8, 8) then
                    pcall(fireproximityprompt, prompt)
                    _wait(0.6)
                end
                if not IsQuest() then
                    return -- เควสจบแล้ว
                end
            end
        end
    end
end

-- บังคับ AutoEat ชั่วคราวตอนฟาร์มเควส Type=Eat (คืนค่าตอนจบ)
local function BoardEnsureEat(want)
    if want then
        if not _env._boardForcedEat then
            _env._boardForcedEat = { saved = _env.AutoEat }
            _env.AutoEat = true
        end
    elseif _env._boardForcedEat then
        _env.AutoEat = _env._boardForcedEat.saved
        _env._boardForcedEat = nil
        print("Board Eat done: restore AutoEat")
    end
end

-- 1 tick = ถือเควสบอร์ดอยู่ฟาร์มต่อ / ไม่ถือไปรับเควสใหม่
local function BoardTick()
    if _env._boardWaitUntil and tick() < _env._boardWaitUntil then
        return -- รอรอบอร์ดรีเฟรช (ไม่สแปม)
    end
    _env._boardWaitUntil = nil

    if IsQuest() then
        local held = GetHeldBoardQuest()
        if not held then
            return -- เควสของโหมดอื่น → รอ ไม่แย่ง
        end
        if held.Type == "Eat" then
            BoardEnsureEat(true)
        else
            BoardEnsureEat(false)
        end
        if held.Type == "Collect" then
            CollectChest()
            return
        end
        for _, monName in ipairs(held.Target or {}) do
            if not _env.AutoQuestBoard then
                return
            end
            if not IsQuest() then
                return -- เควสจบแล้ว
            end
            if MobsFolder and MobsFolder:FindFirstChild(monName) then
                KillMonster(monName)
            elseif FindBossInstance(monName) then
                KillBoss(monName)
            end
            -- ไม่เจอ = ข้าม (ไม่รอ) ให้รอบหน้ามาเช็คใหม่
        end
        return
    end

    BoardEnsureEat(false)

    -- ไม่มีเควส → ไปรับที่บอร์ด : คลิก Next ไล่ทีละเควส (ไม่เกินจำนวนจริง)
    -- เจอปุ่มเขียว + เควสผ่าน (เวลถึง/ตัวกรอง/ยังไม่รับ) กด Accept ทันทีบนจอนั้น
    -- วนครบไม่เจอ → อ่าน ResetTime แล้วพักรอจนคูลดาวน์หมด (ตาม logic เดิม)
    local gui = OpenBoardGui()
    if not gui then
        return
    end
    local st = GetBoardState(gui)
    local maxAttempts = st and #st.list or 0
    if maxAttempts <= 0 then
        maxAttempts = 6
    end
    if maxAttempts > 6 then
        maxAttempts = 6
    end
    local attempts = 0
    local picked = nil
    while _env.AutoQuestBoard do
        gui = GetBoardGui()
        if not gui then
            return
        end
        st = GetBoardState(gui)
        local entry = st and st.list[st.idx] or nil
        local shown = ReadBoardQuest(gui)
        local info = shown and GetBoardQuestData(shown.name) or nil
        if BoardIsGreen(shown) and BoardQuestAcceptable(info, shown, entry) then
            attempts = 0
            break
        end
        ClickBoardNav(gui, "next")
        attempts = attempts + 1
        if attempts >= maxAttempts then
            -- วนครบแล้วยังไม่มีอันรับได้ → รอจนบอร์ดรีเฟรช
            local secs = 300
            local g2 = GetBoardGui()
            if g2 then
                local ok2, txt = pcall(function()
                    return g2.Container.QuestContent.ResetTime.Text
                end)
                if ok2 and txt then
                    local h, m, s = string.match(txt, "(%d+)h:(%d+)m:(%d+)s")
                    if h then
                        secs = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
                    end
                end
            end
            if secs <= 0 then
                secs = 300
            end
            _env._boardWaitUntil = tick() + secs
            print("Quest Board limit! Waiting: " .. secs .. "s")
            CloseBoardGui()
            return
        end
    end
    if not _env.AutoQuestBoard then
        CloseBoardGui()
        return
    end
    -- กดรับ + ยืนยัน + ปิดจอ (Accept/Exit ใช้ firesignal ได้ ไม่มี require ข้างใน)
    gui = GetBoardGui()
    if not gui then
        return
    end
    local shownNow = ReadBoardQuest(gui)
    local acc = gui.Container.QuestContent:FindFirstChild("Accept")
    if acc then
        pcall(function()
            firesignal(acc.MouseButton1Click)
        end)
        print("Board TakeQuest: " .. tostring(shownNow and shownNow.name))
    end
    local t0 = tick()
    while tick() - t0 < 3 do
        if IsQuest() or not _env.AutoQuestBoard then
            break
        end
        _wait(0.2)
    end
    CloseBoardGui()
    if IsQuest() then
        print("Board quest accepted: " .. tostring(shownNow and shownNow.name))
    else
        print("Board quest NOT accepted: " .. tostring(shownNow and shownNow.name))
    end
end

--==================================================
-- Farm Ticks (round-robin : เปิดพร้อมกันได้ทุกอัน)
-- กติกาเควส : ใครถือเควสอยู่คนนั้นฟาร์มต่อจนจบ อีกอันรอ ไม่แย่งกัน
--==================================================
-- Boss : 1 tick = ฆ่า 1 ตัวที่เกิดแล้ว (ไม่เจอ = ข้าม)
local function BossTick()
    local Selected = _env.SelectedBoss
    if type(Selected) == "string" then
        Selected = { Selected }
        _env.SelectedBoss = Selected
    end
    if type(Selected) ~= "table" then
        return
    end
    for _, BossName in ipairs(Selected) do
        if not _env.AutoFarmBoss then
            return
        end
        if BossName and BossName ~= "" and BossName ~= "No Boss Found" then
            if FindBossInstance(BossName) then
                KillBoss(BossName)
                return -- ฆ่าทีละตัวต่อรอบ แบ่งให้งานอื่นบ้าง
            end
        end
    end
    -- มาถึงนี่ = ไม่เจอบอสเลยสักตัว (พิมพ์บอกทุก 5 วิ กันสแปม)
    local now = tick()
    if now - (_env._bossMsgT or 0) >= 5 then
        _env._bossMsgT = now
        if #Selected == 0 then
            print("Auto Farm Boss: no boss selected!")
        else
            print("Waiting for boss (not spawned): " .. table.concat(Selected, ", "))
        end
    end
end

-- Level : 1 tick = ดูแลเควสที่ดีที่สุด 1 รอบ (ไม่แย่งเควสของ Selected)
local function AutoFarmLevelTick()
    local BestQuest = Funcs:GetBestQuest()
    if not BestQuest then
        return
    end
    if IsQuest() then
        -- เควสที่ถืออยู่เป็นของ Selected ที่เปิดอยู่ → รอ ไม่แย่ง
        if _env.AutoFarmSelected and GetHeldSelectedQuest() then
            return
        end
        -- เควสที่ถืออยู่เป็นของ Quest Board ที่เปิดอยู่ → รอ ไม่แย่ง
        if _env.AutoQuestBoard and GetHeldBoardQuest() then
            return
        end
        if not IsValidQuest(BestQuest.QuestInfo) then
            RemoveQuest()
            print("Reject Current Quest")
            return
        end
    else
        TakeQuest(BestQuest.GiverName)
        print("TakeQuest: " .. BestQuest.GiverName)
        _wait(0.5)
        return
    end
    for _, MonsterName in ipairs(BestQuest.Target or {}) do
        if not _env.AutoFarmLevel then
            return
        end
        -- ไม่เจอมอน = ข้าม (ไม่รอ) ให้งานอื่นได้ทำบ้าง
        if MobsFolder:FindFirstChild(MonsterName) then
            KillMonster(MonsterName)
        end
    end
end

--==================================================
-- Main Loop
--==================================================
if not _env.LoadedFarmFunc then
    _env.LoadedFarmFunc = true
    task.spawn(function()
        while _wait() do
            if not _env.LoadedData then
                repeat
                    _wait()
                until _env.LoadedData
            end

            -- round-robin : เปิดพร้อมกันได้ทุกอัน อันไหนมีงานก็ทำ ไม่มีก็ข้าม
            if _env.AutoQuestBoard then
                xpcall(BoardTick, Error)
            end

            if _env.AutoFarmBoss then
                xpcall(BossTick, Error)
            end

            if _env.AutoFarmSelected then
                xpcall(FarmSelectedQuestsTick, Error)
            end

            
            if _env.AutoFarmLevel then
                xpcall(AutoFarmLevelTick, Error)
            end


        end
    end)
end

--==================================================
-- Teleport Helpers (dynamic NPC list)
--==================================================
local function GetTalkNpcList()
    local list = {}
    local folder = workspace:FindFirstChild("TalkNpc")
    if not folder then
        return { "No NPC Found" }
    end
    for _, v in ipairs(folder:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") then
            if not table.find(list, v.Name) then
                table.insert(list, v.Name)
            end
        end
    end
    if #list == 0 then
        return { "No NPC Found" }
    end
    table.sort(list)
    return list
end

local function GetTalkNpcRoot(name)
    local folder = workspace:FindFirstChild("TalkNpc")
    if not folder or not name then
        return nil
    end
    for _, v in ipairs(folder:GetDescendants()) do
        if v.Name == name then
            if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") then
                return v:FindFirstChild("HumanoidRootPart")
            end
            if v:IsA("BasePart") then
                return v
            end
        end
    end
    return nil
end

--==================================================
-- Teleport Player (via Tweento)
--==================================================
local function GetPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            table.insert(list, p.Name)
        end
    end
    if #list == 0 then
        return { "No Player Found" }
    end
    table.sort(list)
    return list
end

local function FindPlayer(query)
    if not query or query == "" then
        return nil
    end
    if typeof(query) == "Instance" and query:IsA("Player") then
        return query
    end
    local q = string.lower(tostring(query))
    -- exact match first (Name or DisplayName)
    for _, p in ipairs(Players:GetPlayers()) do
        if string.lower(p.Name) == q or string.lower(p.DisplayName) == q then
            return p
        end
    end
    -- partial match (Name or DisplayName)
    for _, p in ipairs(Players:GetPlayers()) do
        if string.find(string.lower(p.Name), q, 1, true) or string.find(string.lower(p.DisplayName), q, 1, true) then
            return p
        end
    end
    return nil
end

local function GetPlayerRoot(target)
    local targetPlayer = typeof(target) == "string" and FindPlayer(target) or target
    if not targetPlayer then
        return nil, nil
    end
    local char = targetPlayer.Character
    if not char then
        return nil, targetPlayer
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp, targetPlayer
end

function TeleportToPlayer(query)
    local hrp, targetPlayer = GetPlayerRoot(query)
    if not targetPlayer then
        print("Player not found: " .. tostring(query))
        return false
    end
    if not hrp then
        print("Player has no character: " .. targetPlayer.Name)
        return false
    end
    print("Teleporting to player: " .. targetPlayer.Name)
    Tweento(hrp.CFrame * CFrame.new(0, 0, 4))
    return true
end

--==================================================
-- UI : MacHub V2
--==================================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/arsyny1x/replica-mac-ui/refs/heads/main/main.lua"))()

local Window = Library.CreateWindow({
    Title = "MacHub V2",
    Folder = "MacHub V2",
    AutoSaveSetting = true,
    Size = UDim2.fromOffset(650, 450),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Theme = _env.Theme,
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

local AutoFarmLevel = MainTab:Toggle({
    Title = "Auto Farm Level",
    Flag = "Auto Farm Level",
    Icon = "lucide:arrow-big-up",
})

AutoFarmLevel:OnChanged(function(v)
    _env.AutoFarmLevel = v
    EnableNoclip(v or _env.AutoFarmBoss or _env.AutoFarmSelected or _env.AutoQuestBoard)
end)

local AutoEat = MainTab:Toggle({
    Title = "Auto Eat",
    Flag = "Auto Eat",
    Icon = "lucide:utensils",
})

AutoEat:OnChanged(function(v)
    _env["AutoEat"] = v
end)

MainTab:Section({
    Title = "Boss Farm",
    Subtitle = "Select boss, then enable Auto Farm Boss",
})

_env.SelectedBoss = {}

local InitialBossList = GetBossList()
if InitialBossList[1] and InitialBossList[1] ~= "No Boss Found" then
    _env.SelectedBoss = { InitialBossList[1] }
end

local BossDropdown = MainTab:Dropdown({
    Title = "Select Boss",
    Subtitle = "Tap to select multiple",
    Flag = "Select Bosses",
    Icon = "lucide:skull",
    Values = InitialBossList,
    Multi = true,
    Default = _env.SelectedBoss,
    Callback = function(v)
        if type(v) == "table" then
            _env.SelectedBoss = v
        elseif v ~= nil then
            _env.SelectedBoss = { v }
        end
        print("Selected Boss: " .. table.concat(_env.SelectedBoss, ", "))
    end,
})

MainTab:Button({
    Title = "Refresh Boss List",
    Icon = "lucide:refresh-cw",
    Callback = function()
        local list = GetBossList()
        BossDropdown:Refresh(list)
        print("Refreshed Boss list: " .. #list .. " found")
    end,
})

local AutoFarmBoss = MainTab:Toggle({
    Title = "Auto Farm Boss",
    Flag = "Auto Farm Boss",
    Icon = "lucide:swords",
})

AutoFarmBoss:OnChanged(function(v)
    _env.AutoFarmBoss = v
    if v then
        local sel = _env.SelectedBoss
        if type(sel) == "string" then
            sel = { sel }
        end
        if type(sel) ~= "table" or #sel == 0 then
            print("Auto Farm Boss ON, but no boss selected!")
        else
            print("Auto Farm Boss ON: " .. table.concat(sel, ", "))
        end
        _env._bossMsgT = 0
    end
    EnableNoclip(v or _env.AutoFarmLevel or _env.AutoFarmSelected or _env.AutoQuestBoard)
end)

-- Quest Board Tab
local BoardTab = Window:CreateTab({
    Title = "Quest Board",
    Icon = "lucide:clipboard-list",
})

BoardTab:Section({
    Title = "Auto Quest Board",
    Subtitle = "Talk to Quest board NPC, accept & farm",
})

local AutoQuestBoard = BoardTab:Toggle({
    Title = "Auto Quest Board",
    Flag = "Auto Quest Board",
    Icon = "lucide:play",
})

AutoQuestBoard:OnChanged(function(v)
    _env.AutoQuestBoard = v
    if not v then
        BoardEnsureEat(false)
        _env._boardWaitUntil = nil
        CloseBoardGui()
    else
        print("Auto Quest Board ON")
    end
    EnableNoclip(v or _env.AutoFarmLevel or _env.AutoFarmBoss or _env.AutoFarmSelected)
end)

local SkipBoardCollect = BoardTab:Toggle({
    Title = "Skip Collect Quests",
    Flag = "Skip Board Collect",
    Icon = "lucide:package-open",
})

SkipBoardCollect:OnChanged(function(v)
    _env.SkipBoardCollect = v
end)

local SkipBoardBoss = BoardTab:Toggle({
    Title = "Skip Boss Quests",
    Flag = "Skip Board Boss",
    Icon = "lucide:skull",
})

SkipBoardBoss:OnChanged(function(v)
    _env.SkipBoardBoss = v
end)

-- Select Farm Tab
local SelectFarmTab = Window:CreateTab({
    Title = "Select Farm",
    Icon = "lucide:list-checks",
})

SelectFarmTab:Section({
    Title = "Quest Select",
    Subtitle = "Farm only the selected quests",
})

_env.SelectedQuests = {}

local QuestDropdown = SelectFarmTab:Dropdown({
    Title = "Select Quests",
    Subtitle = "Tap to select multiple",
    Flag = "Select Quests",
    Icon = "lucide:scroll-text",
    Values = GetQuestList(),
    Multi = true,
    Default = _env.SelectedQuests,
    Callback = function(v)
        if type(v) == "table" then
            _env.SelectedQuests = v
        elseif v ~= nil then
            _env.SelectedQuests = { v }
        end
        print("Selected Quests: " .. table.concat(_env.SelectedQuests, ", "))
    end,
})

SelectFarmTab:Button({
    Title = "Refresh Quest List",
    Icon = "lucide:refresh-cw",
    Callback = function()
        local list = GetQuestList()
        QuestDropdown:Refresh(list)
        print("Refreshed Quest list: " .. #list .. " found")
    end,
})

local AutoFarmSelected = SelectFarmTab:Toggle({
    Title = "Auto Farm Selected",
    Flag = "Auto Farm Selected",
    Icon = "lucide:play",
})

AutoFarmSelected:OnChanged(function(v)
    _env.AutoFarmSelected = v
    if v then
        local sel = _env.SelectedQuests
        if type(sel) == "string" then
            sel = { sel }
        end
        if type(sel) ~= "table" or #sel == 0 then
            print("Auto Farm Selected ON, but no quest selected!")
        else
            print("Auto Farm Selected ON: " .. table.concat(sel, ", "))
        end
    end
    EnableNoclip(v or _env.AutoFarmLevel or _env.AutoFarmBoss or _env.AutoQuestBoard)
end)

-- Teleport Tab
local TeleportTab = Window:CreateTab({
    Title = "Teleport",
    Icon = "lucide:map-pin",
})

TeleportTab:Section({
    Title = "NPC Teleport",
    Subtitle = "Select NPC from the list, then press Teleport",
})

_env.SelectedTeleportNpc = nil

local InitialNpcList = GetTalkNpcList()
if InitialNpcList[1] and InitialNpcList[1] ~= "No NPC Found" then
    _env.SelectedTeleportNpc = InitialNpcList[1]
end

local NpcDropdown = TeleportTab:Dropdown({
    Title = "Select NPC",
    Flag = "Teleport NPC",
    Icon = "lucide:users",
    Values = InitialNpcList,
    Value = InitialNpcList[1],
    Callback = function(v)
        _env.SelectedTeleportNpc = v
        print("Selected NPC: " .. tostring(v))
    end,
})

TeleportTab:Button({
    Title = "Refresh NPC List",
    Icon = "lucide:refresh-cw",
    Callback = function()
        local list = GetTalkNpcList()
        NpcDropdown:Refresh(list)
        print("Refreshed NPC list: " .. #list .. " found")
    end,
})

TeleportTab:Button({
    Title = "Teleport",
    Icon = "lucide:navigation",
    Callback = function()
        local name = _env.SelectedTeleportNpc
        if not name or name == "" or name == "No NPC Found" then
            print("Please select an NPC first")
            return
        end
        local root = GetTalkNpcRoot(name)
        if not root then
            print("NPC not found: " .. tostring(name))
            return
        end
        print("Teleporting to: " .. tostring(name))
        Tweento(root.CFrame * CFrame.new(0, 0, 3) * CFrame.Angles(0, math.rad(180), 0))
    end,
})

TeleportTab:Section({
    Title = "Player Teleport",
    Subtitle = "Teleport to player via Tweento",
})

_env.SelectedTeleportPlayer = nil

local InitialPlayerList = GetPlayerList()
if InitialPlayerList[1] and InitialPlayerList[1] ~= "No Player Found" then
    _env.SelectedTeleportPlayer = InitialPlayerList[1]
end

local PlayerDropdown = TeleportTab:Dropdown({
    Title = "Select Player",
    Flag = "Teleport Player",
    Icon = "lucide:user",
    Values = InitialPlayerList,
    Value = InitialPlayerList[1],
    Callback = function(v)
        _env.SelectedTeleportPlayer = v
        print("Selected Player: " .. tostring(v))
    end,
})

TeleportTab:Input({
    Title = "Player Name",
    Placeholder = "Type full or partial name...",
    Callback = function(v)
        _env.SelectedTeleportPlayer = v
    end,
})

TeleportTab:Button({
    Title = "Refresh Player List",
    Icon = "lucide:refresh-cw",
    Callback = function()
        local list = GetPlayerList()
        PlayerDropdown:Refresh(list)
        print("Refreshed Player list: " .. #list .. " found")
    end,
})

TeleportTab:Button({
    Title = "Teleport To Player",
    Icon = "lucide:navigation",
    Callback = function()
        local name = _env.SelectedTeleportPlayer
        if not name or name == "" or name == "No Player Found" then
            print("Please select a player first")
            return
        end
        TeleportToPlayer(name)
    end,
})

-- Setting Tab
local Setting = Window:CreateTab({
    Title = "Setting",
    Icon = "lucide:cog",
})

Setting:Slider({
    Title = "Tween Speed",
    Flag = "TweenSpeed",
    Icon = "lucide:chevrons-up",
    Min = 50,
    Max = 1000,
    Default = _env.TweenSpeed,
    Callback = function(v)
        _env["TweenSpeed"] = v
    end,
})

Setting:Slider({
    Title = "Warp Distance",
    Flag = "Warp Distance",
    Icon = "lucide:zap",
    Min = 10,
    Max = 200,
    Default = _env.WarpDistance,
    Callback = function(v)
        _env["WarpDistance"] = v
    end,
})

Setting:Section({
    Title = "Direction Setting",
    Subtitle = "Adjust Attack Distance and Angle",
})

Setting:Slider({
    Title = "Distance",
    Flag = "Distance",
    Icon = "lucide:ruler",
    Min = 0,
    Max = 20,
    Default = _env.Distance,
    Callback = function(v)
        _env["Distance"] = v
    end,
})

Setting:Slider({
    Title = "Angles",
    Flag = "Angles",
    Icon = "lucide:rotate-cw",
    Min = 0,
    Max = 180,
    Default = _env.Angles,
    Callback = function(v)
        _env["Angles"] = v
    end,
})

Setting:Section({
    Title = "Set Theme",
})

Setting:Dropdown({
    Title = "Select Theme",
    Flag = "Select Theme",
    Icon = "lucide:palette",
    Values = _env.Theme,
    Value = "Light",
    Callback = function(v)
        Window:SetTheme(v)
    end,
})

--==================================================
-- Load Config + Wait Data
--==================================================
local LoadedScriptEndTime = LoadedScriptStartTime - tick()
print(string.format("Loaded Script In %.6fs", -LoadedScriptEndTime))

xpcall(function()
    local LoadedConfigStartTime = tick()
    task.spawn(function()
        Window:LoadConfig(_env.SaveSettingPath)
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
_env.LoadedData = true
print("Data loaded")
