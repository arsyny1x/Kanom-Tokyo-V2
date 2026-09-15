-- Wait Game Loaded
if not game:IsLoaded() then
    game.Loaded:Wait()
end
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
local _RagdollPath = workspace:WaitForChild("IncludeToGame"):WaitForChild("Ragdoll")
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
        return nil
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
    _env.TweenSpeed = 300
    _env.WarpDistance = 50

    -- รีโมทเควสเซสชันปัจจุบัน (GUID เปลี่ยนทุกเซิร์ฟเวอร์ ห้าม hardcode : TakeQuestImpl ค้นหา runtime)
    _env.QuestRemoteName = nil

    -- Boss แปลงร่าง : ร่าง1 -> ร่าง2 (ฆ่าต่ออัตโนมัติในรอบเดียว)
    -- Jason มี 2 ร่าง : Jason -> JasonKakuja
    _env.BossTransform = {
        ["Jason"] = "JasonKakuja",
    }

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

local noclipLoop = nil
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
    if _env.QuestRemote and _env.QuestRemote.Parent then
        pcall(function()
            _env.QuestRemote:FireServer("RemoveQuest")
        end)
        _wait(0.5)
    else
        _env.QuestRemote = nil
    end
    if IsQuest() then -- ยิงไม่ออก/รีโมทตาย → กดปุ่ม Close เอง
        local Quest = PlayerGui:FindFirstChild("Quest", 3)
        if Quest then
            local Close = Quest:WaitForChild("Close", 3)
            if Close then
                firesignal(Close.MouseButton1Click)
                _wait(0.5)
            end
        end
    end
end

function IsValidQuest(QuestInfo)
    local Quest = PlayerGui:FindFirstChild("Quest", 3)
    if Quest then
        local CurrentQuestInfo = Quest.QuestInfo.Text
        return CurrentQuestInfo == QuestInfo
    end
    return false
end

function TakeQuest(arg)
    -- v2 : dialog-first + runtime discovery (GUID เปลี่ยนทุกเซิร์ฟเวอร์) — ตัวจริง TakeQuestImpl ท้าย section
    return TakeQuestImpl(arg)
end
--[[ LEGACY TakeQuest (disabled 2026-09-14) : ยิงรีโมทตรงโดยไม่เปิด dialog + hardcode/brute-force GUID
function TakeQuest_LEGACY(arg)
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

    -- รีโมทรับเควสตัวเดียว (sniffed 2026-09-14) : ไม่ brute-force แล้ว
    local net = ReplicatedStorage:FindFirstChild("Network")
    local qr = net and net:FindFirstChild("{BEEBD4AC-C2F3-4586-BBA5-77CADBD1EECF}")
    if not qr or not qr:IsA("RemoteEvent") then
        print("TakeQuest failed, quest remote missing")
        return
    end
    _env.QuestRemote = qr -- เก็บไว้ให้ RemoveQuest ใช้ด้วย
    local okFire, errFire = pcall(function()
        qr:FireServer(unpack(args))
    end)
    if not okFire then
        print("TakeQuest fire error: " .. tostring(errFire))
        return
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

-- LEGACY-END ]]
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
-- Quest Accept : dialog-only (เปิด dialog จริง + กด Choice)
-- ยิงรีโมทตรงลบทิ้งหมดแล้ว (GUID เปลี่ยนทุกเซิร์ฟเวอร์ + เซิร์ฟเวอร์รับเฉพาะตอน dialog เปิด)
--==================================================
-- เปิด dialog ของ NPC ตัวนี้ (บินไป + ยิง prompt + รอ NpcDialogue) : ได้ dlg หรือ nil
local function OpenGiverDialog(questData)
    local prompt = GetGiverPrompt(questData)
    if not prompt then
        print("TakeQuest failed, prompt not found: " .. tostring(questData.GiverName))
        return nil
    end
    CloseDialog()
    if typeof(fireproximityprompt) ~= "function" then
        print("TakeQuest failed, executor has no fireproximityprompt")
        return nil
    end
    local prt = prompt.Parent
    if not (prt and prt:IsA("BasePart")) then
        print("TakeQuest failed, bad prompt part: " .. tostring(questData.GiverName))
        return nil
    end
    local arriveDist = 8
    pcall(function()
        if prompt.MaxActivationDistance then
            arriveDist = math.max(prompt.MaxActivationDistance - 2, 3)
        end
    end)
    if not TweentoWait(prt.CFrame * CFrame.new(0, 0, 3), 12, arriveDist) then
        print("TakeQuest failed, cannot reach NPC: " .. tostring(questData.GiverName))
        return nil
    end
    local t0 = tick()
    while tick() - t0 < 15 do
        pcall(fireproximityprompt, prompt)
        local w0 = tick()
        while tick() - w0 < 1.5 do
            local cur = PlayerGui:FindFirstChild("NpcDialogue")
            if cur then
                local npcName = ""
                pcall(function()
                    npcName = cur.Container.Head.NpcName.Text
                end)
                if npcName ~= "" and npcName ~= questData.GiverName and npcName ~= (questData.FolderName or "") then
                    CloseDialog()
                    _wait(0.5)
                    break
                end
                return cur
            end
            _wait(0.2)
        end
    end
    print("TakeQuest failed, dialog not opened: " .. tostring(questData.GiverName))
    return nil
end

-- กด Choice ใน dialog ให้เกมยิงรีโมทเอง (รีโมทถูกชัวร์ ไม่ต้องเดา)
local function ClickDialogChoice(dlg, questData)
    local t1 = tick()
    while tick() - t1 < 8 do
        if IsValidQuest(questData.QuestInfo) then
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
    return IsValidQuest(questData.QuestInfo)
end

function TakeQuestImpl(arg)
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
        return false
    end
    if IsValidQuest(questData.QuestInfo) then
        return true -- ถืออยู่แล้ว
    end
    -- dialog-only : เปิด dialog จริงแล้วกด Choice ให้เกมยิงรีโมทเอง (ทางเดียวที่ติดชัวร์)
    local dlg = OpenGiverDialog(questData)
    if not dlg then
        return false
    end
    if ClickDialogChoice(dlg, questData) then
        CloseDialog()
        print("Quest accepted via dialog: " .. tostring(questData.GiverName))
        return true
    end
    CloseDialog()
    print("TakeQuest NOT accepted: " .. tostring(questData.GiverName))
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

if _env.AttackDelay == nil then _env.AttackDelay = 0.5 end -- กันยิงรีโมทตีถี่เกิน (โดน rate-limit/เตะ)
function NormalAttack()
    local now = tick()
    if now - (_env._atkT or 0) < (_env.AttackDelay or 0.5) then
        return -- ยังไม่ครบ 0.5 วิ ข้าม (ยิงถี่เซิร์ฟเวอร์ไม่นับอยู่ดี)
    end
    _env._atkT = now
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

-- Jason ใช้ string match : เข้าเกมมาตอนร่าง 2 เกิดค้างอยู่ก็เจอเลย
-- เทียบแบบหลวม (เว้นวรรค/พิมพ์เล็กใหญ่) + substring (Jason เจอ JasonKakuja)
local function BossNameNorm(s)
    return string.lower((string.gsub(tostring(s), "[%s_%-]+", "")))
end

local function BossNameMatch(instName, wantName)
    if instName == wantName then
        return true
    end
    local a, b = BossNameNorm(instName), BossNameNorm(wantName)
    if a == b then
        return true
    end
    -- substring : หา Jason เจอ JasonKakuja ด้วย (ทิศเดียว กันยิงผิดตัว)
    if string.find(a, b, 1, true) then
        return true
    end
    return false
end

-- หาตัวบอสในแมพ : MobsFolder → MobsFolder.Boss (ลึก) → ใต้ workspace.AI (ลึก)
-- + fallback กวาดทั้ง AI แบบเทียบชื่อหลวมๆ (กันชื่อมีเว้นวรรค/พิมพ์ต่าง)
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
        -- fallback : เทียบชื่อหลวมๆ ทั้ง AI (ร่างแปลงบางตัวชื่อมีเว้นวรรค)
        local ok2, all = pcall(function()
            return ai:GetDescendants()
        end)
        if ok2 and all then
            for _, d in ipairs(all) do
                if (d:IsA("Model") or d:IsA("Folder")) and BossNameMatch(d.Name, name) then
                    if d:FindFirstChild("Humanoid") or d:FindFirstChild("HumanoidRootPart") then
                        return d
                    end
                end
            end
        end
    end
    return nil
end

-- ขยายชื่อบอสพร้อมร่างแปลง (เช่น Jason -> JasonKakuja)
-- + ย้อนกลับ : เลือก JasonKakuja ไว้แต่เกมอยู่ร่าง 1 ก็ฆ่าร่าง 1 ก่อนเพื่อไปร่าง 2
local function ExpandBossTargets(name)
    local list = { name }
    local seen = { [name] = true }
    -- ย้อนกลับ : หาร่างก่อนหน้า (เช่น หา JasonKakuja -> ได้ Jason)
    if _env.BossTransform then
        local want = BossNameNorm(name)
        for pre, nxt in pairs(_env.BossTransform) do
            if BossNameNorm(nxt) == want and not seen[pre] then
                table.insert(list, 1, pre)
                seen[pre] = true
            end
        end
    end
    -- ไปข้างหน้า : ตาม chain แปลงร่าง
    local cur = name
    for _ = 1, 5 do
        local nxt = _env.BossTransform and _env.BossTransform[cur]
        if not nxt or seen[nxt] then
            break
        end
        table.insert(list, nxt)
        seen[nxt] = true
        cur = nxt
    end
    return list
end

-- Kill Boss By Name (direct, no closest-search like KillMonster)
-- ฆ่าร่างแปลงต่ออัตโนมัติ (เช่น Jason ตาย -> รอ JasonKakuja เกิดแล้วฆ่าต่อ)
function KillBoss(name)
    if not name or name == "" then
        return
    end

    local Boss = FindBossInstance(name)
    if not Boss then
        return
    end

    -- รอ Humanoid/RootPart โหลด (บอสเพิ่งเกิดหุ่นยังไม่ครบ อย่าเพิ่งออก)
    local BossHumanoid = Boss:FindFirstChild("Humanoid")
    if not BossHumanoid then
        pcall(function()
            BossHumanoid = Boss:WaitForChild("Humanoid", 5)
        end)
        BossHumanoid = BossHumanoid or Boss:FindFirstChild("Humanoid")
    end
    local BossRootPart = Boss:FindFirstChild("HumanoidRootPart")
    if not BossRootPart then
        if Boss:IsA("Model") then
            pcall(function()
                BossRootPart = Boss:WaitForChild("HumanoidRootPart", 5)
            end)
        end
        BossRootPart = BossRootPart or Boss:FindFirstChild("HumanoidRootPart")
        if not BossRootPart and Boss:IsA("Model") then
            BossRootPart = Boss.PrimaryPart
        end
    end
    if not BossHumanoid or not BossRootPart then
        print("Boss found but no Humanoid/Root yet: " .. name .. " (retry next tick)")
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

    -- มีร่างต่อ : รอเกิด (20 วิ เช็คทุก 0.2 วิ เพราะร่าง 2 มาไว 1-2 วิ) แล้วฆ่าต่อทันที
    local nextForm = _env.BossTransform and _env.BossTransform[name]
    if nextForm then
        print("Waiting transform: " .. name .. " -> " .. nextForm)
        local t0 = tick()
        local found = nil
        while tick() - t0 < 20 do
            found = FindBossInstance(nextForm)
            if found then
                break
            end
            _wait(0.2)
        end
        if found then
            print("Boss transformed: " .. name .. " -> " .. nextForm)
            _wait(0.5) -- รอให้ร่าง 2 เซ็ต Humanoid/RootPart ครบก่อนเข้าตี
            KillBoss(nextForm)
        else
            print("Transform not spawned: " .. nextForm)
        end
    end
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
local GetHeldBoardQuest -- forward : ตัวจริงอยู่ section Quest Board ข้างล่าง (กัน nil call)
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

    -- ถือเควสบอร์ดอยู่ + บอร์ดเปิดอยู่ → ให้บอร์ดทำจนจบก่อน ไม่แย่ง
    -- (บอร์ดปิด = เควสกำพร้า ไม่มีใครทำต่อ ลบทิ้งรับของตัวเอง)
    if GetHeldBoardQuest() and _env.AutoQuestBoard then
        return
    end
    -- ถ้าถือเควสที่เลือกไว้อยู่แล้ว → ฟาร์มเควสนั้นต่อจนจบ ไม่สลับกลางคัน
    local current = GetHeldSelectedQuest()
    if not current then
        if IsQuest() then
            -- ถือเควสของคนอื่น : เจ้าของเปิดอยู่ = รอ / ปิดหมด = เควสกำพร้า ลบทิ้ง
            if _env.AutoFarmLevel then
                return -- level จะล้างให้เองรอบหน้า
            end
            local noroGiver = _env._noroQuestGiver
            local noroQ = noroGiver and FindQuestByGiver(noroGiver)
            if _env.AutoNoro and noroQ and IsValidQuest(noroQ.QuestInfo) then
                return -- เควสฟาร์มของ Noro รอ
            end
            RemoveQuest()
            print("Selected: reject orphan quest")
            _wait(0.5)
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
-- Mob Farm (tab Select Farm : ฟาร์มมอนตามชื่อ ไม่รับเควส)
--==================================================
local function GetMobList()
    local list = {}
    if MobsFolder then
        local playerNames = {}
        for _, p in ipairs(Players:GetPlayers()) do
            playerNames[p.Name] = true
        end
        for _, v in ipairs(MobsFolder:GetChildren()) do
            if v:IsA("Model") and v.Name ~= "Boss" and not playerNames[v.Name]
                and not table.find(list, v.Name) then
                table.insert(list, v.Name)
            end
        end
    end
    if #list == 0 then
        return { "No Mob Found" }
    end
    table.sort(list)
    return list
end

-- 1 tick = ฆ่ามอนที่ติ๊กไว้ทีละตัว วนตามลำดับ (ไม่ยุ่งกับเควสเลย)
local function FarmMobTick()
    local sel = _env.SelectedMobs
    if type(sel) == "string" then
        sel = { sel }
        _env.SelectedMobs = sel
    end
    if type(sel) ~= "table" or #sel == 0 then
        return
    end
    local n = #sel
    for i = 1, n do
        if not _env.AutoFarmMob then
            return
        end
        _env._mobIdx = ((_env._mobIdx or 0) % n) + 1
        local name = sel[_env._mobIdx]
        if name and name ~= "" and name ~= "No Mob Found" then
            if MobsFolder and MobsFolder:FindFirstChild(name) then
                KillMonster(name)
                return -- ฆ่าทีละตัว ที่เหลือรอรอบหน้า
            end
        end
    end
end

-- mob : "ready" (มีตัวที่ติ๊กไว้เกิดอยู่) / nil
local function MobStatus()
    if not _env.AutoFarmMob then
        return nil
    end
    local sel = _env.SelectedMobs
    if type(sel) == "string" then
        sel = { sel }
    end
    if type(sel) ~= "table" or #sel == 0 then
        return nil
    end
    if not MobsFolder then
        return nil
    end
    for _, name in ipairs(sel) do
        if name and name ~= "" and name ~= "No Mob Found" then
            local inst = MobsFolder:FindFirstChild(name)
            if inst then
                local hum = inst:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    return "ready"
                end
            end
        end
    end
    return nil
end

--==================================================
-- Auto Buy Weapon (ซื้ออาวุธตามทีมตอนเวลารีเซ็ต : GUI ล้วน ไม่เดารีโมท)
--==================================================
local function GetWeaponDB(team)
    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    local DataBase = Modules and Modules:FindFirstChild("DataBase")
    local Weapons = DataBase and DataBase:FindFirstChild("Weapons")
    return Weapons and Weapons:FindFirstChild(team) or nil
end

-- รายชื่ออาวุธที่ขายหน้าร้าน (ลูกตรงของโฟลเดอร์ทีมเท่านั้น ไม่ขุด Stages/Devs)
local function GetShopWeaponList(team)
    local list = {}
    local folder = GetWeaponDB(team)
    if folder then
        for _, w in ipairs(folder:GetChildren()) do
            if w:IsA("ModuleScript") and not table.find(list, w.Name) then
                table.insert(list, w.Name)
            end
        end
    end
    if #list == 0 then
        return { "No Weapon Found" }
    end
    table.sort(list)
    return list
end

-- ทีมตอนนี้ : อ่านจาก Player attribute ตรงๆ (Player.Team เกมนี้ไม่ใช้ เป็น nil)
local function GetPlayerTeam()
    local attr = nil
    pcall(function() attr = Player:GetAttribute("Team") end)
    if attr == "CCG" or attr == "GHOUL" then
        return attr
    end
    local owned = {}
    for _, t in ipairs(Player.Backpack:GetChildren()) do
        owned[t.Name] = true
    end
    local ch = Player.Character
    if ch then
        for _, t in ipairs(ch:GetChildren()) do
            if t:IsA("Tool") then
                owned[t.Name] = true
            end
        end
    end
    for _, team in ipairs({ "CCG", "GHOUL" }) do
        local folder = GetWeaponDB(team)
        if folder then
            for _, w in ipairs(folder:GetChildren()) do
                if w:IsA("ModuleScript") and owned[w.Name] then
                    return team
                end
            end
        end
    end
    -- ตอนจะซื้อเช็คสดทุกครั้ง : ของในตัวตรงทีมไหนใช้ทีมนั้นก่อน
    -- ตัวเปล่า = ใช้ทีมที่ติ๊กไว้ใน Select Team เท่านั้น ไม่เดาเอง
    if _env.SelectTeam == "CCG" or _env.SelectTeam == "GHOUL" then
        return _env.SelectTeam
    end
    return nil
end

local function OwnsWeapon(name)
    if not name or name == "" then
        return false
    end
    if Player.Backpack:FindFirstChild(name) then
        return true
    end
    local ch = Player.Character
    if ch and ch:FindFirstChild(name) then
        return true
    end
    return false
end

local function GetWeaponSeller(team)
    local tn = workspace:FindFirstChild("TalkNpc")
    local tf = tn and tn:FindFirstChild(team)
    local npc = tf and tf:FindFirstChild("Weapon")
    if not npc then
        return nil, nil
    end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    local prompt = hrp and hrp:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = npc:FindFirstChildOfClass("ProximityPrompt", true) -- fallback ค้นลึกทั้งตัว (บางทีม prompt ไม่อยู่ใน HRP)
    end
    return npc, prompt
end

local function CloseWeaponShop()
    local ws = PlayerGui:FindFirstChild("WeaponShop")
    local frame = ws and ws.Container:FindFirstChild("WeaponFrame")
    local close = frame and frame:FindFirstChild("Close")
    if close then
        pcall(function() firesignal(close.MouseButton1Click) end)
    end
end

-- กดปุ่ม GUI แบบปุ่มจริง (GuiService.SelectedObject + Enter) : firesignal เปิดแค่เปลือก ของไม่โหลด
local function PressGuiButton(choice)
    pcall(function()
        GuiService.SelectedObject = choice
    end)
    _wait(0.2)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
    end)
    _wait(0.05)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)
    _wait(0.1)
    pcall(function()
        GuiService.SelectedObject = nil
    end)
end

local function ClickShopChoice()
    -- รอ dialog พิมพ์จบก่อน (กดเร็วไปร้านเปิดเปล่า)
    local choice = nil
    local t0 = tick()
    while tick() - t0 < 10 do
        if not _env.AutoBuyWeapon then
            return false
        end
        local dlg = PlayerGui:FindFirstChild("NpcDialogue")
        local container = dlg and dlg:FindFirstChild("Container")
        local ansList = container and container:FindFirstChild("AnswerList")
        choice = ansList and ansList:FindFirstChild("Choice")
        if choice then
            break
        end
        _wait(0.5)
    end
    if not choice then
        return false
    end
    _wait(2)
    local t1 = tick()
    while tick() - t1 < 12 do
        if not _env.AutoBuyWeapon then
            return false
        end
        if not choice.Parent then
            return false -- dialog ถูกปิดไปแล้ว
        end
        PressGuiButton(choice)
        _wait(1)
        local ws = PlayerGui:FindFirstChild("WeaponShop")
        local frame = ws and ws.Container:FindFirstChild("WeaponFrame")
        local sf = frame and frame.Frame:FindFirstChild("ScrollingFrame")
        if sf then
            for _, c in ipairs(sf:GetChildren()) do
                if c:IsA("GuiButton") then
                    return true
                end
            end
        end
    end
    return false
end

local function OpenWeaponShop(team)
    local npc, prompt = GetWeaponSeller(team)
    if not npc or not prompt then
        print("BuyWeapon: seller not found: " .. tostring(team))
        return false
    end
    if typeof(fireproximityprompt) ~= "function" then
        print("BuyWeapon: executor has no fireproximityprompt")
        return false
    end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if not TweentoWait(hrp.CFrame * CFrame.new(0, 0, 3), 15, 8) then
        print("BuyWeapon: cannot reach seller")
        return false
    end
    -- 1) ยิง prompt ให้ dialog เปิด
    CloseDialog()
    local t0 = tick()
    local dlg = nil
    while tick() - t0 < 15 do
        if not _env.AutoBuyWeapon then
            return false
        end
        pcall(fireproximityprompt, prompt)
        _wait(1)
        dlg = PlayerGui:FindFirstChild("NpcDialogue")
        if dlg then
            break
        end
    end
    if not dlg then
        print("BuyWeapon: dialog did not open")
        return false
    end
    -- 2) กด Choice ใน dialog เพื่อเปิดจอร้าน
    if not ClickShopChoice() then
        print("BuyWeapon: shop did not open")
        CloseDialog()
        return false
    end
    return true
end

-- ป้ายชื่อมีเลขสต็อกติด ("Scorpion 1/56") ตัดออกก่อนเทียบ
local function StripStock(label)
    local base = string.match(tostring(label), "^(.-)%s+%d+/%d+$")
    if base then
        return base
    end
    return tostring(label)
end

-- ซื้อ 1 ชิ้นตอนร้านเปิดอยู่แล้ว (ไม่เปิด/ปิดร้านเอง ให้ caller จัดการ)
local function BuySingleWeapon(ws, name)
    if not ws then
        return false
    end
    local sf = ws.Container.WeaponFrame.Frame.ScrollingFrame
    local target = nil
    for _, c in ipairs(sf:GetChildren()) do
        if c:IsA("GuiButton") then
            local lbl = c:FindFirstChildOfClass("TextLabel", true)
            if lbl and StripStock(lbl.Text) == name then
                target = c
                break
            end
        end
    end
    if not target then
        print("BuyWeapon: not in shop: " .. name)
        return "not_in_shop"
    end
    pcall(function() firesignal(target.MouseButton1Click) end)
    local info = ws.Container.Info
    local t0 = tick()
    while tick() - t0 < 8 do
        local wn = info:FindFirstChild("WeaponName")
        if wn and wn:IsA("TextLabel") and StripStock(wn.Text) == name and info.Visible then
            break
        end
        _wait(0.3)
    end
    local equip = info:FindFirstChild("Equip")
    if equip and equip:IsA("TextButton") and equip.Visible then
        print("BuyWeapon: already owned: " .. name)
        return true
    end
    local bottom = info:FindFirstChild("Bottom")
    local buy = bottom and bottom:FindFirstChild("Buy")
    if not buy then
        print("BuyWeapon: no buy button")
        return false
    end
    pcall(function() firesignal(buy.MouseButton1Click) end)
    _wait(1.5)
    if OwnsWeapon(name) then
        print("BuyWeapon: bought " .. name)
        return true
    end
    local equip2 = info:FindFirstChild("Equip")
    if equip2 and equip2:IsA("TextButton") and equip2.Visible then
        print("BuyWeapon: bought " .. name)
        return true
    end
    print("BuyWeapon: buy failed (money?) " .. name)
    return false
end

-- รายชื่อที่จะซื้อของทีมนี้ (normalize string เก่า/เดี่ยวเป็น table ให้หมด)
local function GetSelectedBuyWeapons(team)
    local sel = nil
    if team == "CCG" then
        sel = _env.SelectedCcgWeapons
        if sel == nil and _env.SelectedCcgWeapon ~= nil then
            sel = _env.SelectedCcgWeapon -- ค่าเดี่ยวเซฟเก่า
        end
    elseif team == "GHOUL" then
        sel = _env.SelectedGhoulWeapons
        if sel == nil and _env.SelectedGhoulWeapon ~= nil then
            sel = _env.SelectedGhoulWeapon
        end
    end
    if type(sel) == "string" then
        sel = { sel }
    end
    if type(sel) ~= "table" then
        return {}
    end
    return sel
end

-- อาวุธที่ถืออยู่ตอนนี้ (attribute สดจากเกม)
local function GetEquippedWeapon()
    local w = nil
    pcall(function() w = Player:GetAttribute("Weapon") end)
    if type(w) == "string" and w ~= "" then
        return w
    end
    return nil
end

-- ของที่ต้องซื้อจริง : ตัดว่าง/อันที่ใส่อยู่/อันที่มีแล้วออก
local function GetBuyWanted(team)
    local out = {}
    local equipped = GetEquippedWeapon()
    for _, name in ipairs(GetSelectedBuyWeapons(team)) do
        if name and name ~= "" and name ~= "No Weapon Found" then
            -- ข้ามอันที่ใส่อยู่ + อันที่มีในกระเป๋าแล้ว
            if name ~= equipped and not OwnsWeapon(name) then
                table.insert(out, name)
            end
        end
    end
    return out, equipped
end

-- วินาทีรีร้านจากจอเกม (WeaponShop.Container.WeaponFrame.Time เช่น "00h:14m:43s")
local function GetShopResetSeconds()
    local secs = nil
    pcall(function()
        local ws = PlayerGui:FindFirstChild("WeaponShop")
        local frame = ws and ws.Container:FindFirstChild("WeaponFrame")
        local t = frame and frame:FindFirstChild("Time")
        local txt = t and t:IsA("TextLabel") and t.Text or nil
        if txt then
            local h, m, s = string.match(txt, "(%d+)h:(%d+)m:(%d+)s")
            if h then
                secs = (tonumber(h) or 0) * 3600 + (tonumber(m) or 0) * 60 + (tonumber(s) or 0)
            end
        end
    end)
    return secs
end

-- buy : "ready" (ถึงเวลาต้องไปซื้อ) / nil — เรียกทุกติ๊กใน election ได้ ปลอดภัย ไม่ขยับตัว
local function BuyStatus()
    if not _env.AutoBuyWeapon then
        return nil
    end
    local function buyIdleDbg(msg)
        if tick() - (_env._buyDbgT or 0) >= 15 then
            _env._buyDbgT = tick()
            print("BuyWeapon idle: " .. msg)
        end
    end
    if tick() < (_env._buyCooldownUntil or 0) then
        buyIdleDbg("cooldown")
        return nil
    end
    local team = GetPlayerTeam()
    if not team then
        buyIdleDbg("unknown team (no weapon owned + SelectTeam empty)")
        return nil
    end
    local wanted, equipped = GetBuyWanted(team)
    if #wanted == 0 then
        buyIdleDbg("team=" .. tostring(team) .. " nothing to buy (equipped=" .. tostring(equipped) .. ")")
        return nil
    end
    -- จอร้านมีแค่ตอนเปิด : อ่านเวลานับถอยหลังตอนนั้นแล้วพักยาว ไม่แวะบ่อย
    return "ready"
end

-- 1 tick = ไปซื้อของที่เลือกไว้ (รันเฉพาะตอน driver เลือก เหนือฟาร์ม ต่ำกว่าบอส)
local function BuyWeaponTick()
    if not _env.AutoBuyWeapon then
        return
    end
    local team = GetPlayerTeam()
    if not team then
        print("BuyWeapon: unknown team")
        return
    end
    local wanted = GetBuyWanted(team)
    if #wanted == 0 then
        return
    end
    print("BuyWeapon: buying " .. table.concat(wanted, ", ") .. " [" .. team .. "]")
    if not OpenWeaponShop(team) then
        _env._buyCooldownUntil = tick() + 60 -- เปิดร้านไม่ติด พัก 60 วิค่อยลองใหม่
        return
    end
    local ws = PlayerGui:FindFirstChild("WeaponShop")
    if ws then
        for _, name in ipairs(wanted) do
            if not _env.AutoBuyWeapon then
                break
            end
            -- ซื้อแล้ว/หยิบมาใส่ระหว่างรอบ = ข้าม
            if name ~= GetEquippedWeapon() and not OwnsWeapon(name) then
                BuySingleWeapon(ws, name)
                _wait(0.5)
            end
        end
    end
    -- อ่านเวลานับถอยหลังในจอร้านแล้วพักจนรีสต็อก (กันแวะบ่อย)
    local secs = GetShopResetSeconds()
    _env._buyCooldownUntil = tick() + (secs or 60) + 10
    if secs then
        print("BuyWeapon: next check in " .. secs + 10 .. "s (shop restock)")
    end
    CloseWeaponShop()
    CloseDialog()
end

--==================================================
-- Black Market (auto : คุย NPC → dialog → กดปุ่มจริงทุกขั้น → ซื้อของตาม rank)
--==================================================
local BmRarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythical", "Secret" }
local BmItemsByRarity = {
    Common = { "Flower", "Kagune Crystal" },
    Rare = { "Bulk Fragment" },
    Epic = { "Aogiri Shard", "Quinque Shard", "Rin Fragment", "Serpent Fragment" },
    Legendary = { "Abyss Shard", "Abyssal Catalyst", "Arata fragment", "Crimson Catalyst", "Endless core", "Madness Core", "Oath Chains", "One-Eyed Kakuhou", "RC medicine", "Rin eye", "Shachi kakuhou" },
    Mythical = { "Centipede", "Crimson Watchflower", "Dharmachakra", "Inferno Core", "Insecticide", "Madness : XIII", "Noro's Kakuhou", "One-Eyed Core", "Seal of Shackles", "Violet Bloom" },
    Secret = { "Gate Key" },
}

local function GetBmFrame()
    local sg = PlayerGui:FindFirstChild("ScreenGui")
    return sg and sg:FindFirstChild("BlackMarket") or nil
end

local function GetBmSeller()
    local tn = workspace:FindFirstChild("TalkNpc")
    local npc = tn and tn:FindFirstChild("BlackMarket")
    if not npc then
        return nil, nil
    end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    local prompt = hrp and hrp:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = npc:FindFirstChildOfClass("ProximityPrompt", true)
    end
    return npc, prompt
end

-- สต็อกปัจจุบันในจอ (ชื่อไอเทมที่ขายรอบนี้)
local function GetBmStockNames()
    local out = {}
    local bm = GetBmFrame()
    local stock = bm and bm.Content.Boby.Items:FindFirstChild("Stock")
    if stock then
        for _, c in ipairs(stock:GetChildren()) do
            if c:IsA("GuiButton") then
                local lbl = c:FindFirstChild("ItemName", true)
                if lbl and lbl.Text ~= "" then
                    table.insert(out, lbl.Text)
                end
            end
        end
    end
    return out
end

local function GetBmStockButton(name)
    local bm = GetBmFrame()
    local stock = bm and bm.Content.Boby.Items:FindFirstChild("Stock")
    if not stock then
        return nil
    end
    for _, c in ipairs(stock:GetChildren()) do
        if c:IsA("GuiButton") then
            local lbl = c:FindFirstChild("ItemName", true)
            if lbl and lbl.Text == name then
                return c
            end
        end
    end
    return nil
end

-- Yen ตอนนี้ (อ่านจาก HUD : "Yen: 94,411¥")
local function GetBmYen()
    local yen = nil
    pcall(function()
        local txt = PlayerGui.HUD.Container.Profile.Yen.Amount.Text
        local digits = string.gsub(tostring(txt), "[^%d]", "")
        if digits ~= "" then
            local y = tonumber(digits)
            if y then
                yen = y
            end
        end
    end)
    return yen
end

-- ราคาของที่เลือกอยู่ (Requirements : Amount "x10,000" + Label "Yen"/ชื่อของ)
local function GetBmSelectedCost()
    local amount, label = nil, nil
    pcall(function()
        local bm = GetBmFrame()
        local req = bm.Content.Boby.Selection.Info.Requirements
        for _, c in ipairs(req:GetChildren()) do
            if c:IsA("GuiButton") then
                local scope = c:FindFirstChild("Scope", true)
                local content = scope and scope:FindFirstChild("Content")
                if content then
                    local a = content:FindFirstChild("Amount")
                    local l = content:FindFirstChild("Label")
                    if a and a:IsA("TextLabel") then
                        local digits = string.gsub(tostring(a.Text), "[^%d]", "")
                        if digits ~= "" then
                            local v = tonumber(digits)
                            if v then
                                amount = v
                            end
                        end
                    end
                    if l and l:IsA("TextLabel") and l.Text ~= "" then
                        label = l.Text
                    end
                    if amount then
                        break
                    end
                end
            end
        end
    end)
    return amount, label
end

local function OpenBmShop()
    local npc, prompt = GetBmSeller()
    if not npc or not prompt then
        print("BlackMarket: seller not found")
        return false
    end
    if typeof(fireproximityprompt) ~= "function" then
        print("BlackMarket: executor has no fireproximityprompt")
        return false
    end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if not TweentoWait(hrp.CFrame * CFrame.new(0, 0, 3), 15, 8) then
        print("BlackMarket: cannot reach seller")
        return false
    end
    CloseDialog()
    local t0 = tick()
    local choice = nil
    while tick() - t0 < 10 do
        if not _env.AutoBuyBlackMarket then
            return false
        end
        pcall(fireproximityprompt, prompt)
        _wait(1)
        local dlg = PlayerGui:FindFirstChild("NpcDialogue")
        local ansList = dlg and dlg.Container:FindFirstChild("AnswerList")
        choice = ansList and ansList:FindFirstChild("Choice")
        if choice then
            break
        end
    end
    if not choice then
        print("BlackMarket: dialog did not open")
        return false
    end
    _wait(2) -- รอ dialog พิมพ์จบ (กดเร็วไปร้านเปิดเปล่า)
    local t1 = tick()
    while tick() - t1 < 12 do
        if not _env.AutoBuyBlackMarket then
            return false
        end
        if not choice.Parent then
            return false
        end
        PressGuiButton(choice)
        _wait(1)
        local bm = GetBmFrame()
        if bm and bm.Visible and #GetBmStockNames() > 0 then
            return true
        end
    end
    print("BlackMarket: shop did not open")
    CloseDialog()
    return false
end

local function CloseBmShop()
    local bm = GetBmFrame()
    local close = bm and bm.Content:FindFirstChild("Close")
    if close then
        PressGuiButton(close)
        _wait(0.5)
    end
    CloseDialog()
end

-- ซื้อ 1 ชิ้นตอนร้านเปิดอยู่แล้ว
local function BmBuySingle(name)
    local btn = GetBmStockButton(name)
    if not btn then
        print("BlackMarket: not in stock: " .. name)
        return "not_in_stock"
    end
    PressGuiButton(btn)
    local info = GetBmFrame().Content.Boby.Selection.Info
    local t0 = tick()
    while tick() - t0 < 8 do
        if info.ItemName.Text == name then
            break
        end
        _wait(0.3)
    end
    if info.ItemName.Text ~= name then
        print("BlackMarket: select failed: " .. name)
        return false
    end
    local cost, label = GetBmSelectedCost()
    if cost and label == "Yen" then
        local yen = GetBmYen()
        if yen and yen < cost then
            print("BlackMarket: not enough Yen for " .. name .. " (" .. yen .. "/" .. cost .. ")")
            return false
        end
    end
    local yenBefore = GetBmYen()
    local buy = info:FindFirstChild("Buy")
    if not buy then
        print("BlackMarket: no buy button")
        return false
    end
    PressGuiButton(buy)
    local t1 = tick()
    while tick() - t1 < 6 do
        local yen = GetBmYen()
        if yenBefore and yen and yen < yenBefore then
            print("BlackMarket: bought " .. name .. " (" .. yenBefore .. "->" .. yen .. ")")
            return true
        end
        _wait(0.5)
    end
    -- Yen ไม่อ่าน/ไม่ลด (จ่ายด้วยของ) : ถือว่ากดแล้ว ให้รอบหน้าเช็คสต็อกเอง
    print("BlackMarket: buy pressed: " .. name)
    return true
end

-- ของที่ติ๊กไว้รวมทุก rank
local function GetBmWanted()
    local out = {}
    for _, rank in ipairs(BmRarityOrder) do
        local sel = _env["SelectedBm" .. rank]
        if type(sel) == "string" then
            sel = { sel }
        end
        if type(sel) == "table" then
            for _, name in ipairs(sel) do
                if name and name ~= "" and not table.find(out, name) then
                    table.insert(out, name)
                end
            end
        end
    end
    return out
end

-- ตัว NPC คนขายปัจจุบัน (nil = ยังไม่เกิด/หายไปแล้ว)
local function GetBmSellerNpc()
    local tn = workspace:FindFirstChild("TalkNpc")
    return tn and tn:FindFirstChild("BlackMarket") or nil
end

-- เช็คครั้งเดียวต่อ 1 ตัวที่เกิด : เช็คแล้ว flag ตัวนั้นไว้ ไม่มาอีก
-- จนตัวเดิมหายไปแล้วตัวใหม่เกิด (instance เปลี่ยน) ค่อยเช็คใหม่
-- ถ้าไม่เกิด = ไม่มีอะไรให้เจอ = ไม่ไป
local function BmStatus()
    if not _env.AutoBuyBlackMarket then
        return nil
    end
    if tick() < (_env._bmCooldownUntil or 0) then
        return nil
    end
    if #GetBmWanted() == 0 then
        return nil
    end
    local npc = GetBmSellerNpc()
    if not npc then
        return nil -- ยังไม่เกิด/หายไปแล้ว ไม่มีอะไรให้เช็ค
    end
    local checked = _env._bmCheckedNpc
    if checked ~= nil then
        local stillAlive = false
        pcall(function()
            stillAlive = (checked.Parent ~= nil)
        end)
        if stillAlive and checked == npc then
            return nil -- ตัวเดิมเช็คแล้ว รอตัวใหม่
        end
        -- ตัวเดิมหายไปแล้ว (Parent หาย) หรือเป็น instance ใหม่ = ปล่อยให้เช็ครอบใหม่
    end
    return "ready"
end

-- 1 tick = เปิดร้าน ซื้อทุกอันที่ติ๊กไว้และมีในสต็อก แล้วปิด (พัก 60 วิกันแวะบ่อย)
local function BmBuyTick()
    if not _env.AutoBuyBlackMarket then
        return
    end
    local wanted = GetBmWanted()
    if #wanted == 0 then
        return
    end
    local npc = GetBmSellerNpc()
    if not npc then
        return -- ไม่เกิด ไม่เช็ค
    end
    if not OpenBmShop() then
        _env._bmCooldownUntil = tick() + 60
        return
    end
    -- เช็คตัวนี้แล้ว flag ไว้ จะไม่มาอีกจนกว่าตัวใหม่จะเกิด
    _env._bmCheckedNpc = npc
    local stock = GetBmStockNames()
    print("BlackMarket stock: " .. table.concat(stock, ", "))
    for _, name in ipairs(wanted) do
        if not _env.AutoBuyBlackMarket then
            break
        end
        if table.find(GetBmStockNames(), name) then
            BmBuySingle(name)
            _wait(0.5)
        else
            print("BlackMarket: skip (no stock): " .. name)
        end
    end
    _env._bmCooldownUntil = tick() + 60
    CloseBmShop()
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
GetHeldBoardQuest = function()
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

-- เควสนี้ล่าบอสใช่ไหม (เช็คชื่อบอส + ร่างแปลงด้วย เช่น Jason/JasonKakuja)
-- หมายเหตุ : เช็คจากชื่อ Target ใน DB อย่างเดียว ไม่เช็คว่าเกิดหรือยัง
-- (กันเควสบอสหลุดตอนบอสยังไม่เกิด แล้วไปรับมา)
local function IsBoardBossQuest(info)
    if not info or type(info.Target) ~= "table" or #info.Target == 0 then
        return false
    end
    -- มีมอนปกติให้ตี = ไม่ใช่เควสบอส (เช็คแค่ชื่อตรง ไม่รวมร่างแปลง)
    for _, t in ipairs(info.Target) do
        if MobsFolder and MobsFolder:FindFirstChild(t) then
            return false
        end
    end
    -- ชื่อตรงกับบอสใน DB หรือตรงกับร่างแปลง = เควสบอส
    local bossNames = {}
    for _, b in ipairs(GetBossList()) do
        bossNames[b] = true
    end
    if _env.BossTransform then
        for a, b in pairs(_env.BossTransform) do
            bossNames[a] = true
            bossNames[b] = true
        end
    end
    for _, t in ipairs(info.Target) do
        if bossNames[t] then
            return true
        end
        -- fallback : ถ้า DB บอสไม่มีชื่อนี้ แต่มีตัวเกิดในแมพ (บอส event) ก็นับเป็นบอส
        for _, expanded in ipairs(ExpandBossTargets(t)) do
            if FindBossInstance(expanded) then
                return true
            end
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
    -- Skip ON = ไม่รับเควสบอสเลยทุกกรณี (ไม่สนว่าเกิดหรือยัง)
    if _env.SkipBoardBoss and IsBoardBossQuest(info) then
        return false
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
            -- เควสของโหมดอื่น : เจ้าของเปิดอยู่ = รอ / ปิดหมด = เควสกำพร้า ลบทิ้งแล้วรับบอร์ดใหม่
            if _env.AutoFarmSelected and GetHeldSelectedQuest() then
                return
            end
            local noroGiver = _env._noroQuestGiver
            local noroQ = noroGiver and FindQuestByGiver(noroGiver)
            if _env.AutoNoro and noroQ and IsValidQuest(noroQ.QuestInfo) then
                return
            end
            if _env.AutoFarmLevel then
                return -- level จะล้างให้เองรอบหน้า
            end
            RemoveQuest()
            print("Board: reject orphan quest")
            _wait(0.5)
            return
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
            else
                -- บอส + ร่างแปลง (เช่น Jason -> JasonKakuja) ฆ่าตัวที่เกิดอยู่
                for _, bossName in ipairs(ExpandBossTargets(monName)) do
                    if not _env.AutoQuestBoard or not IsQuest() then
                        return
                    end
                    if FindBossInstance(bossName) then
                        KillBoss(bossName)
                        break -- KillBoss ฆ่าร่างต่อให้เองในรอบเดียว
                    end
                end
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
                        secs = (tonumber(h) or 0) * 3600 + (tonumber(m) or 0) * 60 + (tonumber(s) or 0)
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
-- Noro Spawner (auto : เช็คเป๋า → ฟาร์มของขาด → ใส่ของ → เสก → ฆ่า)
-- กติกา : ใส่ของต่อเมื่อของในเป๋าพอครบเท่านั้น (ใส่ค้างแล้วออกเกมของหายฟรี)
-- กด 1 ที = ใส่ 1 ชิ้น (เทสในเกมแล้ว : firesignal ผ่าน)
--==================================================
_env.NoroRecipe = {
    -- Rin eye ดรอป 2 ที่ : 350-400 (1%) + 400-450 (3%) → ฟาร์ม 400-450 คุ้มสุด (ได้ Rin Fragment ด้วย)
    { name = "Bulk Fragment",    need = 12, quest = "QuestGiver (Lv.150-Lv.250)" },
    { name = "Serpent Fragment", need = 10, quest = "QuestGiver (Lv.350-Lv.400)" },
    { name = "Rin Fragment",     need = 10, quest = "QuestGiver (Lv.400-Lv.450)" },
    { name = "Rin eye",          need = 2,  quest = "QuestGiver (Lv.400-Lv.450)" },
}

local function NoroParseCount(txt): (number, number?)
    local a, b = string.match(tostring(txt or ""), "x(%d+)%s*/%s*(%d+)")
    if a then
        return (tonumber(a) or 0), tonumber(b)
    end
    return tonumber(string.match(tostring(txt or ""), "x(%d+)")) or 0, nil
end

local function NoroReqFrame()
    local rui = PlayerGui:FindFirstChild("RenderUI")
    local gui = rui and rui:FindFirstChild("Gui")
    return gui and gui:FindFirstChild("Requirement") or nil
end

-- ของที่ใส่ค้างในแท่นแล้ว (อ่านจากจอเสก xA/B)
local function NoroGetStaged(name)
    local fr = NoroReqFrame() and NoroReqFrame():FindFirstChild(name)
    local amt = fr and fr:FindFirstChild("Amount", true)
    if amt and (amt:IsA("TextLabel") or amt:IsA("TextButton")) then
        local a = NoroParseCount(amt.Text)
        return a or 0
    end
    return 0
end

-- ยอดที่ต้องใส่ (อ่าน B จากจอเสก ถ้าไม่มีใช้ตามสูตร)
local function NoroGetNeed(name, fallback)
    local fr = NoroReqFrame() and NoroReqFrame():FindFirstChild(name)
    local amt = fr and fr:FindFirstChild("Amount", true)
    if amt and (amt:IsA("TextLabel") or amt:IsA("TextButton")) then
        local _, b = NoroParseCount(amt.Text)
        if b and b > 0 then
            return b
        end
    end
    return fallback
end

-- ของในกระเป๋า (Menu.MenuFrames.Inventory...Scrolling.<ชื่อ>.Amount)
local function NoroGetBag(name)
    local menu = PlayerGui:FindFirstChild("Menu")
    local mf = menu and menu:FindFirstChild("MenuFrames")
    local inv = mf and mf:FindFirstChild("Inventory")
    local sf = inv and inv:FindFirstChild("ScrollingFrame")
    local cg = sf and sf:FindFirstChild("CanvasGroup")
    local scr = cg and cg:FindFirstChild("Scrolling")
    local it = scr and scr:FindFirstChild(name)
    local amt = it and it:FindFirstChild("Amount", true)
    if amt and (amt:IsA("TextLabel") or amt:IsA("TextButton")) then
        local n = NoroParseCount(amt.Text)
        return n or 0
    end
    return 0
end

local function NoroSpawnerPart()
    local inc = workspace:FindFirstChild("IncludeToGame")
    local sp = inc and inc:FindFirstChild("Boss Spawner")
    local noro = sp and sp:FindFirstChild("Noro")
    if not noro then
        return nil
    end
    local rp = noro:FindFirstChild("Root Part")
    if rp and rp:IsA("BasePart") then
        return rp
    end
    for _, d in ipairs(noro:GetDescendants()) do
        if d:IsA("BasePart") then
            return d
        end
    end
    return nil
end

-- กด ADD 1 ที (firesignal ตรงปุ่มจริง ไม่ต้องเดารีโมท)
local function NoroPressAdd(name)
    local fr = NoroReqFrame() and NoroReqFrame():FindFirstChild(name)
    local content = fr and fr:FindFirstChild("Scope") and fr.Scope:FindFirstChild("Content")
    local btn = content and content:FindFirstChild("Button")
    if btn and btn:IsA("TextButton") then
        pcall(function()
            firesignal(btn.MouseButton1Click)
        end)
        return true
    end
    return false
end

-- ฟาร์มของที่ขาด : รับเควสตามสูตรแล้วตี (ไม่แย่งเควสบอร์ด/Selected)
local function NoroFarmMaterial(r)
    if GetHeldBoardQuest() and _env.AutoQuestBoard then
        return
    end
    if _env.AutoFarmSelected and GetHeldSelectedQuest() then
        return
    end
    local q = FindQuestByGiver(r.quest)
    if not q then
        print("Noro: quest not found " .. tostring(r.quest))
        return
    end
    local lvl = 0
    pcall(function()
        lvl = Player.Data.Level.Value or 0
    end)
    if (q.LevelRequired or 0) > lvl then
        local now = tick()
        if now - (_env._noroLvlMsgT or 0) >= 30 then
            _env._noroLvlMsgT = now
            print("Noro: level too low for " .. r.quest .. " (need " .. tostring(q.LevelRequired) .. ")")
        end
        return
    end
    if IsQuest() then
        if IsValidQuest(q.QuestInfo) then
            -- ถือเควสถูกแล้ว → ตีต่อ
        elseif _env.AutoFarmLevel or _env.AutoFarmSelected then
            return -- เควสของโหมดอื่น → รอ ไม่แย่ง
        else
            RemoveQuest()
            print("Noro: reject other quest")
            return
        end
    else
        TakeQuest(r.quest)
        _env._noroQuestGiver = r.quest -- จำไว้ว่าเควสนี้ของ Noro (driver election ใช้เช็ค)
        print("Noro take: " .. r.quest .. " (farm " .. r.name .. ")")
        _wait(0.5)
        return
    end
    for _, monName in ipairs(q.Target or {}) do
        if not _env.AutoNoro then
            return
        end
        if not IsQuest() then
            return
        end
        if MobsFolder and MobsFolder:FindFirstChild(monName) then
            KillMonster(monName)
        end
    end
end

-- ใส่ของทุกอย่างจนเต็ม (เรียกเมื่อของในเป๋าพอครบแล้วเท่านั้น)
local function NoroFillAll()
    local part = NoroSpawnerPart()
    if part then
        TweentoWait(part.CFrame * CFrame.new(0, 0, 5), 12, 8)
    end
    for _, r in ipairs(_env.NoroRecipe) do
        while _env.AutoNoro do
            local staged = NoroGetStaged(r.name)
            local need = NoroGetNeed(r.name, r.need)
            if staged >= need then
                break
            end
            if NoroGetBag(r.name) <= 0 then
                break -- ของหมดกลางคัน → กลับไปฟาร์มรอบหน้า
            end
            if not NoroPressAdd(r.name) then
                print("Noro ADD button not found: " .. r.name)
                break
            end
            local t0 = tick()
            local ok = false
            while tick() - t0 < 3 do
                if NoroGetStaged(r.name) > staged then
                    ok = true
                    break
                end
                _wait(0.2)
            end
            if not ok then
                print("Noro ADD failed: " .. r.name)
                break
            end
            _wait(0.2)
        end
        if not _env.AutoNoro then
            return
        end
    end
    print("Noro: all staged, waiting spawn...")
end

-- 1 tick = ฆ่า Noro ที่เกิดแล้ว / ใส่ของถ้าครบ / ฟาร์มของขาด
local function NoroTick()
    -- กันเหนียว : เวลไม่ถึง 450 ปิดเอง + แจ้ง (กันเคสเปิดตอนเวลยังไม่โหลด)
    local lvl0 = 0
    pcall(function()
        lvl0 = Player.Data.Level.Value or 0
    end)
    if lvl0 < 450 then
        _env.AutoNoro = false
        print("Auto Spawn Noro requires Level 450+ (your level: " .. tostring(lvl0) .. "). Turning OFF.")
        return
    end
    -- เกิดแล้วฆ่าก่อน (ไม่สนว่าเสกเองหรือเกิดเอง)
    if FindBossInstance("Noro") then
        KillBoss("Noro")
        return
    end

    local allFull = true
    local farmTarget = nil
    local parts = {}
    for _, r in ipairs(_env.NoroRecipe) do
        local staged = NoroGetStaged(r.name)
        local need = NoroGetNeed(r.name, r.need)
        local bag = NoroGetBag(r.name)
        table.insert(parts, r.name .. " " .. staged .. "/" .. need .. " (bag " .. bag .. ")")
        if staged < need then
            allFull = false
            -- ใส่ได้ต่อเมื่อเป๋าพอกลบยอดที่เหลือ (กันใส่ค้างแล้วของไม่ครบ)
            if bag < (need - staged) and not farmTarget then
                farmTarget = r
            end
        end
    end
    local now = tick()
    if now - (_env._noroMsgT or 0) >= 10 then
        _env._noroMsgT = now
        print("Noro: " .. table.concat(parts, " | "))
    end

    if allFull then
        return -- ใส่ครบแล้ว → รอเสก (รอบหน้ามาเช็ค ถ้าเกิดก็ฆ่า)
    end
    if farmTarget then
        NoroFarmMaterial(farmTarget)
        return
    end
    NoroFillAll()
end

--==================================================
-- Event (auto join : สร้างแท่นยืนเหนือ Capture Point แล้ววาร์ปไปยืนเฉยๆ)
--==================================================
-- ใช้ Point วงเดียว (อันแรก) : แท่นอยู่กลางวง
local function GetEventPoint()
    local inc = workspace:FindFirstChild("IncludeToGame")
    local cp = inc and inc:FindFirstChild("CapturePoints")
    if not cp then
        return nil
    end
    for _, c in ipairs(cp:GetChildren()) do
        if c.Name == "Point" and c:IsA("BasePart") then
            return c
        end
    end
    return nil
end

-- จุดกลางวงจริง = Attachment "Circle" (Part มันใหญ่ 150 สูง เอากลาง Part ไม่ได้)
local function GetEventCirclePos(point)
    if not point then
        return nil
    end
    local circle = point:FindFirstChild("Circle")
    if circle and circle:IsA("Attachment") then
        return circle.WorldPosition
    end
    return point.Position
end

local function EnsureEventPlatform(circlePos)
    local pf = _env._eventPlatform
    if pf and pf.Parent then
        return pf
    end
    local platform = Instance.new("Part")
    platform.Name = "MacHubEventPlatform"
    platform.Size = Vector3.new(12, 1, 12)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 1
    platform.CFrame = CFrame.new(circlePos + Vector3.new(0, -10, 0)) -- ใต้ดิน (-10 Y)
    platform.Parent = workspace
    _env._eventPlatform = platform
    print("Event platform created at circle center")
    return platform
end

local function DestroyEventPlatform()
    if _env._eventPlatform and _env._eventPlatform.Parent then
        pcall(function()
            _env._eventPlatform:Destroy()
        end)
    end
    _env._eventPlatform = nil
end

-- 1 tick = ยืนบนแท่นกลางวง Point (ห่างค่อยวาร์ป ไม่สแปม)
-- Point ไม่มี = election เลือกงานอื่นทำรอเอง ไม่ปิด toggle
local function EventTick()
    local point = GetEventPoint()
    if not point then
        return
    end
    local circlePos = GetEventCirclePos(point)
    if not circlePos then
        return
    end
    local platform = EnsureEventPlatform(circlePos)
    -- แท่นตามวง (กันจุดขยับ, ใต้ดิน -10 Y)
    local wantCF = CFrame.new(circlePos + Vector3.new(0, -10, 0))
    if (platform.Position - wantCF.Position).Magnitude > 2 then
        platform.CFrame = wantCF
    end
    local root = GetRootPart()
    if not root then
        return
    end
    local standCF = platform.CFrame * CFrame.new(0, 1.5, 0) -- จมดินนิดๆ (เท้าฝังพื้นหน่อยๆ ไม่ลอย)
    if (root.Position - standCF.Position).Magnitude > 8 then
        Tweento(standCF)
        print("Event: teleported to Point")
    end
end

--==================================================
-- Auto Stats (อัพแต้มค้าง + แต้มที่ได้ใหม่ ลงตามที่ติ๊กไว้)
-- วิธี : ตั้ง TextBox จำนวน → firesignal ปุ่ม Upgrade (เทสในเกมแล้วผ่าน)
--==================================================
_env.SelectedStats = { "Damage" }

local function GetStatsFrame()
    local menu = PlayerGui:FindFirstChild("Menu")
    local mf = menu and menu:FindFirstChild("MenuFrames")
    return mf and mf:FindFirstChild("Stats") or nil
end

local function GetRemainPoints()
    local sf = GetStatsFrame()
    if not sf then
        return 0
    end
    for _, d in ipairs(sf:GetDescendants()) do
        if d.Name == "Point" and d:IsA("TextLabel") then
            return tonumber(string.match(tostring(d.Text), "(%d+)")) or 0
        end
    end
    return 0
end

local function StatPressUpgrade(statName, amount)
    local sf = GetStatsFrame()
    if not sf then
        return false
    end
    local tb = sf:FindFirstChild("NumberInsert")
    tb = tb and tb:FindFirstChildWhichIsA("TextBox", true)
    local row = sf:FindFirstChild("StatsContent")
    row = row and row:FindFirstChild(statName)
    local btn = row and row:FindFirstChild("Upgrade")
    if not tb or not btn then
        return false
    end
    local before = GetRemainPoints()
    if before <= 0 then
        return false
    end
    pcall(function()
        tb.Text = tostring(math.min(amount, before))
    end)
    _wait(0.2)
    pcall(function()
        firesignal(btn.MouseButton1Click)
    end)
    local t0 = tick()
    while tick() - t0 < 3 do
        if GetRemainPoints() < before then
            return true
        end
        _wait(0.2)
    end
    return false
end

-- 1 tick = มีแต้มค้างก็ไล่อัพตามที่ติ๊กไว้ (แบ่งเท่าๆ กันทีละสแตท)
local function StatTick()
    local sel = _env.SelectedStats
    if type(sel) == "string" then
        sel = { sel }
        _env.SelectedStats = sel
    end
    if type(sel) ~= "table" or #sel == 0 then
        return
    end
    local remain = GetRemainPoints()
    if remain <= 0 then
        return
    end
    local left = #sel
    for _, statName in ipairs(sel) do
        if not _env.AutoStats then
            return
        end
        remain = GetRemainPoints()
        if remain <= 0 then
            break
        end
        local chunk = math.ceil(remain / left)
        if StatPressUpgrade(statName, chunk) then
            print("Auto Stats: +" .. tostring(chunk) .. " " .. statName .. " (remain " .. GetRemainPoints() .. ")")
        else
            print("Auto Stats failed: " .. statName)
            break
        end
        left = left - 1
        _wait(0.3)
    end
end

--==================================================
-- Auto Skill (กดสกิลวน Z/X/C/V/F/R ผ่านปุ่มคีย์บอร์ดจำลอง)
-- ยิงเฉพาะตอน : ฟาร์มเปิดอยู่ + ถืออาวุธแล้ว (คูลดาวน์กดวืดเอง ไม่ต้องเช็ค)
--==================================================
_env.SelectedSkills = { "Z", "X", "C", "V" }
if _env.SkillDelay == nil then _env.SkillDelay = 3 end
if _env.HoldSkills == nil then _env.HoldSkills = {} end -- สกิลแบบกดค้าง (ใช้ร่วมกันทั้งฟาร์ม + PK)
if _env.HoldDuration == nil then _env.HoldDuration = 1.5 end -- กดค้างกี่วิ

local function IsHoldSkill(keyName)
    local hold = _env.HoldSkills
    if type(hold) == "string" then
        return hold == keyName
    end
    if type(hold) ~= "table" then
        return false
    end
    for _, k in ipairs(hold) do
        if k == keyName then
            return true
        end
    end
    return false
end

local function PressSkillKey(keyName)
    local ok, code = pcall(function()
        return Enum.KeyCode[keyName]
    end)
    if not ok or not code then
        return false
    end
    if IsHoldSkill(keyName) then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, code, false, game)
        end)
        _wait(_env.HoldDuration or 1.5)
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, code, false, game)
        end)
        return true
    end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, code, false, game)
    end)
    _wait(0.05)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, code, false, game)
    end)
    return true
end

local function SkillTick()
    if not (_env.AutoFarmLevel or _env.AutoFarmBoss or _env.AutoFarmSelected or _env.AutoFarmMob or _env.AutoQuestBoard or _env.AutoNoro or _env.AutoEvent) then
        return -- no farm running = no skill spam (fixes constant firing while idle)
    end
    local sel = _env.SelectedSkills
    if type(sel) == "string" then
        sel = { sel }
        _env.SelectedSkills = sel
    end
    if type(sel) ~= "table" or #sel == 0 then
        return
    end
    -- ยังไม่ถืออาวุธ = ไม่กด (KillMonster / KillBoss หยิบให้เอง)
    if not IsEquipWeapon() then
        return
    end
    local now = tick()
    if now - (_env._skillT or 0) < (_env.SkillDelay or 3) then
        return
    end
    _env._skillT = now
    local n = #sel
    _env._skillIdx = ((_env._skillIdx or 0) % n) + 1
    local key = sel[_env._skillIdx]
    if PressSkillKey(key) then
        print("Skill: " .. tostring(key))
    end
end

--==================================================
-- Farm Ticks (round-robin : เปิดพร้อมกันได้ทุกอัน)
-- กติกาเควส : ใครถือเควสอยู่คนนั้นฟาร์มต่อจนจบ อีกอันรอ ไม่แย่งกัน
-- เควสบอร์ดมี priority สูงสุด : ถืออยู่ห้ามยกเลิก ให้บอร์ดทำจนจบก่อน (บอร์ดวิ่งก่อนใน loop ตอนว่างเลยได้หยิบก่อน)
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
            -- เช็คร่างแปลงด้วย (เลือก Jason อันเดียวก็เจอ JasonKakuja)
            for _, tryName in ipairs(ExpandBossTargets(BossName)) do
                if FindBossInstance(tryName) then
                    KillBoss(tryName)
                    return -- ฆ่าทีละตัวต่อรอบ แบ่งให้งานอื่นบ้าง
                end
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
        -- ถือเควสบอร์ดอยู่ + บอร์ดเปิดอยู่ → ให้บอร์ดทำจนจบก่อน ห้ามยกเลิก
        -- (บอร์ดปิด = เควสกำพร้า ปล่อยไหลไปเช็ค validity แล้วลบ)
        if GetHeldBoardQuest() and _env.AutoQuestBoard then
            return
        end
        -- เควสที่ถืออยู่เป็นของ Selected ที่เปิดอยู่ → รอ ไม่แย่ง
        if _env.AutoFarmSelected and GetHeldSelectedQuest() then
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
-- Auto Kill Players (ไล่ฆ่าผู้เล่นนอกเซฟโซน)
-- เป้า = ตัวละครผู้เล่นจริงใน workspace["AI/Player"] (ชื่อ = ชื่อผู้เล่น)
-- ข้ามตัวใน SafeZone (workspace.IncludeToGame.Zones) + ตัวที่ตี 10 วิแล้วเลือดไม่ลด
--==================================================
if _env.PkNoDamageTime == nil then _env.PkNoDamageTime = 10 end
if _env.PkSkipTime == nil then _env.PkSkipTime = 30 end
if _env.PkAttackDistance == nil then _env.PkAttackDistance = 6 end -- ระยะห่างตอนตีคน (ยืนใต้ตัวกี่ studs)

if _env.SelectedPkTargets == nil then _env.SelectedPkTargets = {} end -- PK targets (ว่าง = ทุกคน)

local function GetSafeZoneParts()
    if _env._pkZones and _env._pkZonesT and tick() - _env._pkZonesT < 30 then
        return _env._pkZones
    end
    local list = {}
    local inc = workspace:FindFirstChild("IncludeToGame")
    local zones = inc and inc:FindFirstChild("Zones")
    if zones then
        for _, z in ipairs(zones:GetChildren()) do
            if z.Name == "SafeZone" and z:IsA("BasePart") then
                table.insert(list, z)
            end
        end
    end
    _env._pkZones = list
    _env._pkZonesT = tick()
    return list
end

local function IsInSafeZone(pos)
    for _, z in ipairs(GetSafeZoneParts()) do
        local ok, localPos = pcall(function()
            return z.CFrame:PointToObjectSpace(pos)
        end)
        if ok and localPos then
            local s = z.Size
            if math.abs(localPos.X) <= s.X / 2
                and math.abs(localPos.Y) <= s.Y / 2
                and math.abs(localPos.Z) <= s.Z / 2 then
                return true
            end
        end
    end
    return false
end

-- โมเดลตัวละครของผู้เล่นคนนั้น (ข้ามตัวเอง + ตายแล้ว + โดนข้ามชั่วคราว)
local function GetPlayerModel(p)
    if not p or p == Player then
        return nil
    end
    if _env._pkSkip and _env._pkSkip[p.Name] and tick() < _env._pkSkip[p.Name] then
        return nil
    end
    local model = MobsFolder and MobsFolder:FindFirstChild(p.Name)
    if not model then
        return nil
    end
    local hum = model:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then
        return nil
    end
    local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    if not root then
        return nil
    end
    if IsInSafeZone(root.Position) then
        return nil
    end
    return model, hum, root
end

-- สแปมสกิล PK ที่ติ๊กไว้ (คั่น 0.3 วิ กันยิงถี่เกิน, ว่าง = ใช้สกิลฟาร์มแทน)
local function PkSpamSkills()
    local sel = _env.SelectedSkills -- same list as farm (one list for everything)
    if type(sel) == "string" then
        sel = { sel }
    end
    if type(sel) ~= "table" or #sel == 0 then
        return -- nothing selected = no spam
    end
    local now = tick()
    if now - (_env._pkSkillT or 0) < 0.3 then
        return
    end
    _env._pkSkillT = now
    local n = #sel
    _env._pkSkillIdx = ((_env._pkSkillIdx or 0) % n) + 1
    PressSkillKey(sel[_env._pkSkillIdx])
end

function KillPlayerTarget(model)
    if not model then
        return
    end
    local hum = model:FindFirstChild("Humanoid")
    local troot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    if not hum or not troot then
        return
    end
    print("PK attacking: " .. model.Name .. " (hp " .. math.floor(hum.Health) .. ")")
    local startHp = hum.Health
    local startT = tick()
    while hum.Health > 0 and model.Parent do
        if not _env.AutoPK then
            return
        end
        -- วาร์ปหนีเข้าเซฟโซน = เลิกตาม
        if IsInSafeZone(troot.Position) then
            print("PK escaped to safe zone: " .. model.Name)
            return
        end
        if not IsEquipWeapon() then
            EquipWeapon()
        end
        -- tween ลงข้างล่างเหมือนตีมอน (ระยะตาม Attack Distance ของ PK)
        Tweento(troot.CFrame * CFrame.new(0, -(_env.PkAttackDistance or 6), -3) * CFrame.Angles(math.rad(_env.Angles), 0, 0))
        local root = GetRootPart()
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        NormalAttack()
        PkSpamSkills()
        -- เลือดลด = รีจับเวลา / ครบเวลาเลือดไม่ลด = ข้ามไปตัวต่อไป
        if hum.Health < startHp - 1 then
            startHp = hum.Health
            startT = tick()
        elseif tick() - startT >= (_env.PkNoDamageTime or 10) then
            _env._pkSkip = _env._pkSkip or {}
            _env._pkSkip[model.Name] = tick() + (_env.PkSkipTime or 30)
            print("PK no damage " .. tostring(_env.PkNoDamageTime or 10) .. "s, skipping: " .. model.Name)
            return
        end
        _wait()
    end
    if hum.Health <= 0 then
        print("PK killed: " .. model.Name)
    end
end

-- รายชื่อผู้เล่นตอนนี้ (ไม่รวมตัวเอง) สำหรับ dropdown เลือกเป้า
local function GetPkPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            table.insert(list, p.Name)
        end
    end
    table.sort(list)
    if #list == 0 then
        return { "No Players Found" }
    end
    return list
end

-- อยู่ในลิสต์เป้าที่ติ๊กไว้ไหม (ว่าง = ทุกคน)
local function PkIsSelected(name)
    local sel = _env.SelectedPkTargets
    if type(sel) == "string" then
        sel = { sel }
    end
    if type(sel) ~= "table" or #sel == 0 then
        return true
    end
    for _, n in ipairs(sel) do
        if n == name then
            return true
        end
    end
    return false
end

-- 1 tick = เลือกคนที่นอกเซฟโซน + ใกล้สุด 1 คน (ไม่เจอ = ข้าม)
local function PkTick()
    local best, bestDist = nil, math.huge
    local myRoot = GetRootPart()
    local myPos = myRoot and myRoot.Position or nil
    for _, p in ipairs(Players:GetPlayers()) do
        if not _env.AutoPK then
            return
        end
        if not PkIsSelected(p.Name) then
            continue
        end
        local model, _, root = GetPlayerModel(p)
        if model and root then
            local d = myPos and (root.Position - myPos).Magnitude or 0
            if d < bestDist then
                best, bestDist = model, d
            end
        end
    end
    if best then
        print("PK target: " .. best.Name .. "|" .. math.floor(bestDist) .. " Stud")
        KillPlayerTarget(best)
        return
    end
    local now = tick()
    if now - (_env._pkMsgT or 0) >= 10 then
        _env._pkMsgT = now
        print("PK: no target outside safe zone")
    end
end

--==================================================
-- Driver Election (เปิดพร้อมกันได้ทุกอัน ไม่ดึงตัวกัน)
-- เช็คราคาถูก ไม่ขยับตัว ไม่ยิงรีโมท แล้วเลือกงานเดียวขับต่อรอบ
-- ลำดับ : event(มี Point ยืนก่อน ไม่มีปล่อยงานอื่นทำรอ) > pk > boss/noroเกิด > เควสที่ถือค้าง > รับงานใหม่
--==================================================
local function PkHasTarget()
    if not _env.AutoPK then
        return false
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if PkIsSelected(p.Name) and GetPlayerModel(p) then
            return true
        end
    end
    return false
end

local function BossHasTarget()
    if not _env.AutoFarmBoss then
        return false
    end
    local sel = _env.SelectedBoss
    if type(sel) == "string" then
        sel = { sel }
    end
    if type(sel) ~= "table" then
        return false
    end
    for _, name in ipairs(sel) do
        if name and name ~= "" and name ~= "No Boss Found" then
            for _, try in ipairs(ExpandBossTargets(name)) do
                if FindBossInstance(try) then
                    return true
                end
            end
        end
    end
    return false
end

local function NoroSpawned()
    return _env.AutoNoro and FindBossInstance("Noro") ~= nil
end

-- ถือเควสฟาร์มของ Noro อยู่ไหม
local function NoroHeldQuest()
    if not _env.AutoNoro or not IsQuest() then
        return nil
    end
    local giver = _env._noroQuestGiver
    if not giver then
        return nil
    end
    local q = FindQuestByGiver(giver)
    if q and IsValidQuest(q.QuestInfo) then
        return q
    end
    return nil
end

-- Noro พร้อมทำงานไหม (ไม่นับตอนใส่ครบรอเสก กับตอนเวลไม่ถึง)
local function NoroIsReady()
    if not _env.AutoNoro then
        return false
    end
    local lvl = 0
    pcall(function()
        lvl = Player.Data.Level.Value or 0
    end)
    if lvl < 450 then
        return false
    end
    if FindBossInstance("Noro") then
        return true
    end
    for _, r in ipairs(_env.NoroRecipe) do
        if NoroGetStaged(r.name) < NoroGetNeed(r.name, r.need) then
            if NoroGetBag(r.name) >= (NoroGetNeed(r.name, r.need) - NoroGetStaged(r.name)) then
                return true -- เป๋าพอใส่ครบ
            end
            local q = FindQuestByGiver(r.quest)
            if q and (q.LevelRequired or 0) <= lvl then
                return true -- ไปฟาร์มของขาดได้
            end
            return false -- ของไม่พอ + เวลไม่ถึง = รอ
        end
    end
    return false -- ใส่ครบแล้ว รอเสก
end

local function BoardIsReady()
    if not _env.AutoQuestBoard then
        return false
    end
    if GetHeldBoardQuest() then
        return true
    end
    if IsQuest() then
        return false -- ถือเควสคนอื่น รอ
    end
    if _env._boardWaitUntil and tick() < _env._boardWaitUntil then
        return false -- บอร์ดคูลดาวน์
    end
    return true
end

-- selected : "held" / "ready" / nil
local function SelectedStatus()
    if not _env.AutoFarmSelected then
        return nil
    end
    if GetHeldSelectedQuest() then
        return "held"
    end
    if IsQuest() then
        return nil -- ถือเควสคนอื่น รอ
    end
    local sel = _env.SelectedQuests
    if type(sel) == "string" then
        sel = { sel }
    end
    if type(sel) ~= "table" or #sel == 0 then
        return nil
    end
    local lvl = 0
    pcall(function()
        lvl = Player.Data.Level.Value or 0
    end)
    for _, name in ipairs(sel) do
        local q = FindQuestByGiver(name)
        if q and (q.LevelRequired or 0) <= lvl then
            return "ready"
        end
    end
    return nil
end

-- level : "held" / "ready" / "cleanup" / nil
local function LevelStatus()
    if not _env.AutoFarmLevel then
        return nil
    end
    local best = Funcs:GetBestQuest()
    if not best then
        return nil
    end
    if IsQuest() then
        if IsValidQuest(best.QuestInfo) then
            return "held"
        end
        return "cleanup" -- ถือเควสผิด/ของคนอื่น → ไปลบ
    end
    return "ready"
end

local function ElectDriver()
    -- Event มี Point = ยืนอีเวนต์ก่อนเลย ; Point ไม่มี = ปล่อยงานอื่นทำรอ เปิดค้างได้ทุกอัน
    if _env.AutoEvent and GetEventPoint() then
        return "event"
    end
    if PkHasTarget() then
        return "pk"
    end
    if BossHasTarget() then
        return "boss"
    end
    -- ซื้ออาวุธสำคัญรองจากบอส : ร้านรีสต็อกค่อยไปทีเดียว ไม่เฝ้า
    if BuyStatus() == "ready" then
        return "buy"
    end
    if BmStatus() == "ready" then
        return "bm"
    end
    if NoroSpawned() then
        return "noro"
    end
    -- เควสที่ถือค้าง : เจ้าของขับต่อจนจบ
    if _env.AutoQuestBoard and GetHeldBoardQuest() then
        return "board"
    end
    if _env.AutoFarmSelected and GetHeldSelectedQuest() then
        return "selected"
    end
    if _env.AutoNoro and NoroHeldQuest() then
        return "noro"
    end
    if LevelStatus() == "held" then
        return "level"
    end
    if IsQuest() then
        -- ถือเควสของคนอื่น : ให้ level ล้างให้ ถ้าไม่มี level ให้เจ้าของโหมดรอ
        if _env.AutoFarmLevel then
            return "level"
        end
        if _env.AutoFarmSelected then
            return "selected"
        end
        if _env.AutoQuestBoard then
            return "board"
        end
        if _env.AutoNoro then
            return "noro"
        end
        return nil
    end
    -- ว่าง : ใครรับงานใหม่ได้ก่อนตามลำดับเดิม (board > noro > selected > level)
    if BoardIsReady() then
        return "board"
    end
    if NoroIsReady() then
        return "noro"
    end
    if SelectedStatus() == "ready" then
        return "selected"
    end
    if LevelStatus() then
        return "level"
    end
    if MobStatus() == "ready" then
        return "mob"
    end
    return nil
end

local DriverTick = {
    pk = PkTick,
    boss = BossTick,
    board = BoardTick,
    noro = NoroTick,
    selected = FarmSelectedQuestsTick,
    level = AutoFarmLevelTick,
    mob = FarmMobTick,
    buy = BuyWeaponTick,
    bm = BmBuyTick,
    event = EventTick,
}

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

            -- driver election : เปิดพร้อมกันได้ทุกอัน สคริปต์เลือกงานสำคัญสุดทำทีละอย่าง ไม่ดึงตัวกัน
            -- Stats + Skill ไม่ขยับตัว วิ่งคู่กับ driver ได้เสมอ
            local driver = ElectDriver()
            if driver ~= _env._lastDriver then
                _env._lastDriver = driver
                print("Driver: " .. tostring(driver))
            end
            if driver then
                local fn = DriverTick[driver]
                if fn then
                    xpcall(fn, Error)
                end
            end

            if _env.AutoStats then
                xpcall(StatTick, Error)
            end

            if _env.AutoSkill then
                xpcall(SkillTick, Error)
            end


        end
    end)
end

--==================================================
-- Teleport Helpers (dynamic NPC list)
--==================================================
-- NPC ชื่อซ้ำแยกทีม (เช่น CCG/Ghoul) : อันที่ซ้ำต่อท้ายด้วยชื่อ parent -> "ชื่อ [ทีม]"
_env._npcDisplayMap = _env._npcDisplayMap or {}

local function GetTalkNpcList()
    local list = {}
    local folder = workspace:FindFirstChild("TalkNpc")
    if not folder then
        return { "No NPC Found" }
    end
    -- เก็บทุกตัวก่อน (ชื่อซ้ำกันได้)
    local entries = {}
    local nameCount = {}
    for _, v in ipairs(folder:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") then
            local parentName = (v.Parent and v.Parent.Name) or "?"
            local grandName = (v.Parent and v.Parent.Parent and v.Parent.Parent.Name) or nil
            table.insert(entries, { name = v.Name, parent = parentName, grand = grandName })
            nameCount[v.Name] = (nameCount[v.Name] or 0) + 1
        end
    end
    if #entries == 0 then
        return { "No NPC Found" }
    end
    -- สร้างชื่อโชว์ : ไม่ซ้ำใช้ชื่อเดิม, ซ้ำเติม " [parent]" (ยังชนอีกเติม grand + เลข)
    _env._npcDisplayMap = {}
    local used = {}
    for _, e in ipairs(entries) do
        local display = e.name
        if (nameCount[e.name] or 0) > 1 then
            display = e.name .. " [" .. e.parent .. "]"
            if used[display] then
                if e.grand and e.grand ~= e.parent then
                    display = e.name .. " [" .. e.grand .. "/" .. e.parent .. "]"
                end
            end
            local i = 2
            while used[display] do
                display = e.name .. " [" .. e.parent .. " #" .. i .. "]"
                i = i + 1
            end
        end
        if not used[display] then
            used[display] = true
            _env._npcDisplayMap[display] = { name = e.name, parent = e.parent }
            table.insert(list, display)
        end
    end
    table.sort(list)
    return list
end

local function GetTalkNpcRoot(name)
    local folder = workspace:FindFirstChild("TalkNpc")
    if not folder or not name then
        return nil
    end
    local function rootOf(v)
        if v:IsA("Model") then
            return v:FindFirstChild("HumanoidRootPart")
        end
        if v:IsA("BasePart") then
            return v
        end
        return nil
    end
    -- 1) ตรง display map (ชื่อ + parent)
    local info = _env._npcDisplayMap and _env._npcDisplayMap[name]
    if info then
        for _, v in ipairs(folder:GetDescendants()) do
            if v.Name == info.name and v.Parent and v.Parent.Name == info.parent then
                local r = rootOf(v)
                if r then
                    return r
                end
            end
        end
    end
    -- 2) แกะฟอร์แมต "ชื่อ [parent]" ตรงๆ (กัน map หายหลังรันใหม่)
    local base, par = string.match(tostring(name), "^(.-)%s*%[(.-)%]$")
    if base and par then
        -- เผื่อฟอร์แมต grand/parent : เอาแค่ parent ท้ายสุด
        local shortPar = string.match(par, "/(.+)$") or par
        shortPar = string.match(shortPar, "^(.-)%s*#%d+%s*$") or shortPar
        for _, v in ipairs(folder:GetDescendants()) do
            if v.Name == base and v.Parent and v.Parent.Name == shortPar then
                local r = rootOf(v)
                if r then
                    return r
                end
            end
        end
        -- grand/parent เต็ม : เทียบ parent chain
        for _, v in ipairs(folder:GetDescendants()) do
            if v.Name == base then
                local p = v.Parent and v.Parent.Name or ""
                local g = v.Parent and v.Parent.Parent and v.Parent.Parent.Name or ""
                if par == g .. "/" .. p or par == p then
                    local r = rootOf(v)
                    if r then
                        return r
                    end
                end
            end
        end
    end
    -- 3) fallback ชื่อตรงตัวแรก (พฤติกรรมเดิม)
    for _, v in ipairs(folder:GetDescendants()) do
        if v.Name == name then
            local r = rootOf(v)
            if r then
                return r
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
    EnableNoclip(v or _env.AutoFarmBoss or _env.AutoFarmSelected or _env.AutoFarmMob or _env.AutoQuestBoard or _env.AutoNoro or _env.AutoEvent or _env.AutoPK)
end)

-- Shop Tab
local ShopTab = Window:CreateTab({
    Title = "Shop",
    Icon = "lucide:shopping-cart",
})

ShopTab:Section({
    Title = "Auto Buy Weapon",
    Subtitle = "Buy when the shop restocks",
})

-- ย้ายค่าเดี่ยวเซฟเก่าเป็น multi (ครั้งเดียว)
local function MigrateWeaponSel(newKey, oldVal)
    if _env[newKey] == nil and type(oldVal) == "string" and oldVal ~= "" then
        _env[newKey] = { oldVal }
    end
    if type(_env[newKey]) == "string" then
        _env[newKey] = { _env[newKey] }
    end
    if type(_env[newKey]) ~= "table" then
        _env[newKey] = {}
    end
end
MigrateWeaponSel("SelectedCcgWeapons", _env.SelectedCcgWeapon)
MigrateWeaponSel("SelectedGhoulWeapons", _env.SelectedGhoulWeapon)

local CcgWeapons = GetShopWeaponList("CCG")

local CcgWeaponDropdown = ShopTab:Dropdown({
    Title = "CCG Weapons",
    Subtitle = "Tap to select multiple",
    Flag = "CCG Weapons",
    Icon = "lucide:swords",
    Values = CcgWeapons,
    Multi = true,
    Default = _env.SelectedCcgWeapons,
    Callback = function(v)
        if type(v) == "table" then
            _env.SelectedCcgWeapons = v
        elseif v ~= nil then
            _env.SelectedCcgWeapons = { v }
        else
            _env.SelectedCcgWeapons = {}
        end
        print("CCG weapons: " .. table.concat(_env.SelectedCcgWeapons, ", "))
    end,
})

local GhoulWeapons = GetShopWeaponList("GHOUL")

local GhoulWeaponDropdown = ShopTab:Dropdown({
    Title = "GHOUL Weapons",
    Subtitle = "Tap to select multiple",
    Flag = "GHOUL Weapons",
    Icon = "lucide:swords",
    Values = GhoulWeapons,
    Multi = true,
    Default = _env.SelectedGhoulWeapons,
    Callback = function(v)
        if type(v) == "table" then
            _env.SelectedGhoulWeapons = v
        elseif v ~= nil then
            _env.SelectedGhoulWeapons = { v }
        else
            _env.SelectedGhoulWeapons = {}
        end
        print("GHOUL weapons: " .. table.concat(_env.SelectedGhoulWeapons, ", "))
    end,
})

ShopTab:Button({
    Title = "Refresh Weapon Lists",
    Icon = "lucide:refresh-cw",
    Callback = function()
        local ccg = GetShopWeaponList("CCG")
        local ghoul = GetShopWeaponList("GHOUL")
        CcgWeaponDropdown:Refresh(ccg)
        GhoulWeaponDropdown:Refresh(ghoul)
        print("Refreshed weapons: CCG " .. #ccg .. ", GHOUL " .. #ghoul)
    end,
})

local AutoBuyWeapon = ShopTab:Toggle({
    Title = "Auto Buy Weapon",
    Flag = "Auto Buy Weapon",
    Icon = "lucide:shopping-cart",
})

ShopTab:Section({
    Title = "Black Market",
    Subtitle = "Buy materials when in stock",
})

for _, rank in ipairs(BmRarityOrder) do
    local key = "SelectedBm" .. rank
    if type(_env[key]) == "string" then
        _env[key] = { _env[key] }
    end
    if type(_env[key]) ~= "table" then
        _env[key] = {}
    end
    ShopTab:Dropdown({
        Title = rank,
        Subtitle = "Tap to select multiple",
        Flag = "BM " .. rank,
        Icon = "lucide:gem",
        Values = BmItemsByRarity[rank],
        Multi = true,
        Default = _env[key],
        Callback = function(sel)
            if type(sel) == "table" then
                _env[key] = sel
            elseif sel ~= nil then
                _env[key] = { sel }
            else
                _env[key] = {}
            end
            print("BM " .. rank .. ": " .. table.concat(_env[key], ", "))
        end,
    })
end

local AutoBuyBlackMarket = ShopTab:Toggle({
    Title = "Auto Buy Black Market",
    Flag = "Auto Buy Black Market",
    Icon = "lucide:store",
})

AutoBuyBlackMarket:OnChanged(function(v)
    _env.AutoBuyBlackMarket = v
    if v then
        _env._bmCooldownUntil = 0
        _env._bmCheckedNpc = nil -- ล้าง flag ให้เช็คตัวที่ยืนอยู่รอบนึง
        print("Auto Buy Black Market ON")
    else
        print("Auto Buy Black Market OFF")
    end
end)

AutoBuyWeapon:OnChanged(function(v)
    _env.AutoBuyWeapon = v
    if v then
        -- ล้างชื่อเน่าที่ไม่อยู่ในร้านออกจาก list (กันค่าค้างเซฟเก่า)
        local ccgList = GetShopWeaponList("CCG")
        local keptCcg = {}
        for _, n in ipairs(GetSelectedBuyWeapons("CCG")) do
            if table.find(ccgList, n) then
                table.insert(keptCcg, n)
            end
        end
        _env.SelectedCcgWeapons = keptCcg
        local ghoulList = GetShopWeaponList("GHOUL")
        local keptGhoul = {}
        for _, n in ipairs(GetSelectedBuyWeapons("GHOUL")) do
            if table.find(ghoulList, n) then
                table.insert(keptGhoul, n)
            end
        end
        _env.SelectedGhoulWeapons = keptGhoul
        _env._buyCooldownUntil = 0 -- เช็ครอบนึงทันที หลังจากนั้นพักตามเวลารีร้าน
        print("Auto Buy Weapon ON")
    else
        print("Auto Buy Weapon OFF")
    end
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
    Title = "Noro Spawner",
    Subtitle = "Farm mats → stage → spawn → kill",
})

local AutoNoro = MainTab:Toggle({
    Title = "Auto Spawn Noro",
    Flag = "Auto Spawn Noro",
    Icon = "lucide:play",
})

AutoNoro:OnChanged(function(v)
    if v then
        local lvl = 0
        pcall(function()
            lvl = Player.Data.Level.Value or 0
        end)
        if lvl < 450 then
            print("Auto Spawn Noro requires Level 450+ (your level: " .. tostring(lvl) .. "). Turning OFF.")
            _env.AutoNoro = false
            pcall(function()
                AutoNoro:Set(false)
            end)
            EnableNoclip(_env.AutoFarmLevel or _env.AutoFarmBoss or _env.AutoFarmSelected or _env.AutoQuestBoard or _env.AutoEvent or _env.AutoPK)
            return
        end
        print("Auto Spawn Noro ON (Bulk 12 / Serpent 10 / RinFrag 10 / RinEye 2)")
        _env._noroMsgT = 0
    else
        print("Auto Spawn Noro OFF")
    end
    _env.AutoNoro = v
    EnableNoclip(v or _env.AutoFarmLevel or _env.AutoFarmBoss or _env.AutoFarmSelected or _env.AutoFarmMob or _env.AutoQuestBoard or _env.AutoEvent or _env.AutoPK)
end)

MainTab:Section({
    Title = "Event",
    Subtitle = "Stand on Capture Point",
})

local AutoEvent = MainTab:Toggle({
    Title = "Auto Join Event",
    Flag = "Auto Join Event",
    Icon = "lucide:flag",
})

AutoEvent:OnChanged(function(v)
    _env.AutoEvent = v
    if v then
        print("Auto Join Event ON")
        _env._eventMsgT = 0
    else
        print("Auto Join Event OFF")
        DestroyEventPlatform()
    end
    EnableNoclip(v or _env.AutoFarmLevel or _env.AutoFarmBoss or _env.AutoFarmSelected or _env.AutoFarmMob or _env.AutoQuestBoard or _env.AutoNoro or _env.AutoPK)
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
    EnableNoclip(v or _env.AutoFarmLevel or _env.AutoFarmSelected or _env.AutoFarmMob or _env.AutoQuestBoard or _env.AutoNoro or _env.AutoEvent or _env.AutoPK)
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
    EnableNoclip(v or _env.AutoFarmLevel or _env.AutoFarmBoss or _env.AutoFarmMob or _env.AutoQuestBoard or _env.AutoNoro or _env.AutoEvent or _env.AutoPK)
end)

SelectFarmTab:Section({
    Title = "Mob Farm",
    Subtitle = "Farm mobs by name, no quest needed",
})

_env.SelectedMobs = _env.SelectedMobs or {}

local MobDropdown = SelectFarmTab:Dropdown({
    Title = "Select Mobs",
    Subtitle = "Tap to select multiple",
    Flag = "Select Mobs",
    Icon = "lucide:ghost",
    Values = GetMobList(),
    Multi = true,
    Default = _env.SelectedMobs,
    Callback = function(v)
        if type(v) == "table" then
            _env.SelectedMobs = v
        elseif v ~= nil then
            _env.SelectedMobs = { v }
        else
            _env.SelectedMobs = {}
        end
        print("Selected Mobs: " .. table.concat(_env.SelectedMobs, ", "))
    end,
})

SelectFarmTab:Button({
    Title = "Refresh Mob List",
    Icon = "lucide:refresh-cw",
    Callback = function()
        local list = GetMobList()
        MobDropdown:Refresh(list)
        print("Refreshed Mob list: " .. #list .. " found")
    end,
})

local AutoFarmMob = SelectFarmTab:Toggle({
    Title = "Auto Farm Mobs",
    Flag = "Auto Farm Mobs",
    Icon = "lucide:play",
})

AutoFarmMob:OnChanged(function(v)
    _env.AutoFarmMob = v
    if v then
        local sel = _env.SelectedMobs
        if type(sel) == "string" then
            sel = { sel }
        end
        if type(sel) ~= "table" or #sel == 0 then
            print("Auto Farm Mobs ON, but no mob selected!")
        else
            print("Auto Farm Mobs ON: " .. table.concat(sel, ", "))
        end
        _env._mobIdx = 0
    end
    EnableNoclip(v or _env.AutoFarmLevel or _env.AutoFarmBoss or _env.AutoFarmSelected or _env.AutoQuestBoard or _env.AutoNoro or _env.AutoEvent or _env.AutoPK)
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
    EnableNoclip(v or _env.AutoFarmLevel or _env.AutoFarmBoss or _env.AutoFarmSelected or _env.AutoFarmMob or _env.AutoNoro or _env.AutoEvent or _env.AutoPK)
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

-- Stats Tab
local StatsTab = Window:CreateTab({
    Title = "Auto Stats",
    Icon = "lucide:chart-column",
})

StatsTab:Section({
    Title = "Auto Stats",
    Subtitle = "Select stats, then enable",
})

local _StatsDropdown = StatsTab:Dropdown({
    Title = "Select Stats",
    Subtitle = "Tap to select multiple",
    Flag = "Select Stats",
    Icon = "lucide:chart-column",
    Values = { "Damage", "Durability", "Stamina", "Speed" },
    Multi = true,
    Default = _env.SelectedStats,
    Callback = function(v)
        if type(v) == "table" then
            _env.SelectedStats = v
        elseif v ~= nil then
            _env.SelectedStats = { v }
        end
        print("Selected Stats: " .. table.concat(_env.SelectedStats, ", "))
    end,
})

local AutoStats = StatsTab:Toggle({
    Title = "Auto Stats",
    Flag = "Auto Stats",
    Icon = "lucide:play",
})

AutoStats:OnChanged(function(v)
    _env.AutoStats = v
    if v then
        local sel = _env.SelectedStats
        if type(sel) == "string" then
            sel = { sel }
        end
        if type(sel) ~= "table" or #sel == 0 then
            print("Auto Stats ON, but no stat selected!")
        else
            print("Auto Stats ON: " .. table.concat(sel, ", ") .. " (remain " .. GetRemainPoints() .. ")")
        end
    else
        print("Auto Stats OFF")
    end
end)

-- Skills Tab
local SkillsTab = Window:CreateTab({
    Title = "Skills",
    Icon = "lucide:zap",
})

SkillsTab:Section({
    Title = "Skills",
    Subtitle = "Pressed in rotation while farming or killing players",
})

local _SkillsDropdown = SkillsTab:Dropdown({
    Title = "Select Skills",
    Subtitle = "Tap to select multiple",
    Flag = "Select Skills",
    Icon = "lucide:swords",
    Values = { "Z", "X", "C", "V", "F", "R" },
    Multi = true,
    Default = _env.SelectedSkills,
    Callback = function(v)
        if type(v) == "table" then
            _env.SelectedSkills = v
        elseif v ~= nil then
            _env.SelectedSkills = { v }
        end
        print("Selected Skills: " .. table.concat(_env.SelectedSkills, ", "))
    end,
})

SkillsTab:Slider({
    Title = "Skill Delay (sec)",
    Flag = "SkillDelay",
    Icon = "lucide:timer",
    Min = 1,
    Max = 15,
    Default = _env.SkillDelay,
    Callback = function(v)
        _env["SkillDelay"] = v
    end,
})

SkillsTab:Section({
    Title = "Hold Skills",
    Subtitle = "Held down instead of tapped",
})

SkillsTab:Dropdown({
    Title = "Select Hold Skills",
    Subtitle = "Tap to select multiple",
    Flag = "Hold Skills",
    Icon = "lucide:hand",
    Values = { "Z", "X", "C", "V", "F", "R" },
    Multi = true,
    Default = _env.HoldSkills,
    Callback = function(v)
        if type(v) == "table" then
            _env.HoldSkills = v
        elseif v ~= nil then
            _env.HoldSkills = { v }
        else
            _env.HoldSkills = {}
        end
        print("Hold Skills: " .. table.concat(_env.HoldSkills, ", "))
    end,
})

SkillsTab:Slider({
    Title = "Hold Duration (sec)",
    Flag = "HoldDuration",
    Icon = "lucide:timer",
    Min = 0.5,
    Max = 5,
    Default = _env.HoldDuration,
    Callback = function(v)
        _env["HoldDuration"] = v
        print("Hold duration set: " .. tostring(v) .. "s")
    end,
})

local AutoSkill = SkillsTab:Toggle({
    Title = "Auto Skill",
    Flag = "Auto Skill",
    Icon = "lucide:play",
})

AutoSkill:OnChanged(function(v)
    _env.AutoSkill = v
    if v then
        local sel = _env.SelectedSkills
        if type(sel) == "string" then
            sel = { sel }
        end
        if type(sel) ~= "table" or #sel == 0 then
            print("Auto Skill ON, but no skill selected!")
        else
            print("Auto Skill ON: " .. table.concat(sel, ", ") .. " every " .. tostring(_env.SkillDelay or 3) .. "s")
        end
        _env._skillT = 0
    else
        print("Auto Skill OFF")
    end
end)

-- PK Tab
local PkTab = Window:CreateTab({
    Title = "Kill Players",
    Icon = "lucide:skull",
})

PkTab:Section({
    Title = "HIGH RISK BAN",
    Subtitle = "Killing real players is easily reported. Use at your own risk.",
})

PkTab:Section({
    Title = "Auto Kill Players",
    Subtitle = "Attack players outside safe zone only",
})

local AutoPK = PkTab:Toggle({
    Title = "Auto Kill Players",
    Flag = "Auto Kill Players",
    Icon = "lucide:play",
})

AutoPK:OnChanged(function(v)
    _env.AutoPK = v
    if v then
        print("Auto Kill Players ON (outside safe zone only)")
        _env._pkMsgT = 0
        _env._pkSkip = {}
    else
        print("Auto Kill Players OFF")
    end
    EnableNoclip(v or _env.AutoFarmLevel or _env.AutoFarmBoss or _env.AutoFarmSelected or _env.AutoFarmMob or _env.AutoQuestBoard or _env.AutoNoro or _env.AutoEvent or _env.AutoPK)
end)

PkTab:Section({
    Title = "Select Targets",
    Subtitle = "Empty = attack everyone",
})

local PkTargetDropdown = PkTab:Dropdown({
    Title = "Select PK Targets",
    Subtitle = "Tap to select multiple",
    Flag = "Select PK Targets",
    Icon = "lucide:crosshair",
    Values = GetPkPlayerList(),
    Multi = true,
    Default = _env.SelectedPkTargets,
    Callback = function(v)
        if type(v) == "table" then
            _env.SelectedPkTargets = v
        elseif v ~= nil then
            _env.SelectedPkTargets = { v }
        else
            _env.SelectedPkTargets = {}
        end
        print("PK Targets: " .. (#_env.SelectedPkTargets > 0 and table.concat(_env.SelectedPkTargets, ", ") or "everyone"))
    end,
})

PkTab:Button({
    Title = "Refresh Player List",
    Icon = "lucide:refresh-cw",
    Callback = function()
        local list = GetPkPlayerList()
        PkTargetDropdown:Refresh(list)
        print("Refreshed player list: " .. #list .. " found")
    end,
})

PkTab:Slider({
    Title = "No-Damage Skip (sec)",
    Flag = "PkNoDamageTime",
    Icon = "lucide:timer",
    Min = 5,
    Max = 30,
    Default = _env.PkNoDamageTime,
    Callback = function(v)
        _env["PkNoDamageTime"] = v
    end,
})

PkTab:Slider({
    Title = "Skip Cooldown (sec)",
    Flag = "PkSkipTime",
    Icon = "lucide:timer-off",
    Min = 10,
    Max = 120,
    Default = _env.PkSkipTime,
    Callback = function(v)
        _env["PkSkipTime"] = v
    end,
})

PkTab:Slider({
    Title = "Attack Distance",
    Flag = "PkAttackDistance",
    Icon = "lucide:ruler",
    Min = 0,
    Max = 20,
    Default = _env.PkAttackDistance,
    Callback = function(v)
        _env["PkAttackDistance"] = v
        print("PK attack distance set: " .. tostring(v) .. " studs")
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
    Min = 20,
    Max = 300,
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
    Max = 50,
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
