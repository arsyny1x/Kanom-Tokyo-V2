# STRUCTURE — main.lua

ไฟล์เดียวจบ แบ่งเป็น section ตามคอมเมนต์ `----` ในโค้ด:

- `Services` — Players, TweenService, ReplicatedStorage, RunService, VirtualInputManager, VirtualUser
- `Player / Paths` — LocalPlayer, PlayerGui, TargetRemote, QuestPath, MobsFolder, RagdollPath
- `Anti-AFK` — VirtualUser.ClickButton2
- `Quest Data` — Loaded.Quest (เก็บ QuestModule + FolderName ตัวจริงไว้ด้วย ไม่เดาชื่อตอนรับเควส) + Funcs.GetBestQuest (เรียง LevelRequired มาก→น้อย)
- `Quest Functions` — TakeQuest รับได้ทั้งชื่อ/table ใช้ QuestModule ตัวจริง หา NPC แบบหลายชั้น (GiverName → FolderName → deep-search TalkNpc) ยิงรีโมทแล้วเช็คว่าเควสเข้าจริง (รอผลรีโมทละ 2 วิตอนค้นหา กันเซิร์ฟแล็ก) ไม่เข้าครบ 3 ครั้งทิ้ง remote เก่าแล้วค้นหาใหม่เอง — ลำดับรีโมท: ตัวที่จำไว้ → ชื่อ GUID ที่รู้จัก (`_env.QuestRemoteName`) → ค้นหาใหม่แบบ GUID-like ก่อน
- `Dialog Accept` — GetGiverPrompt (หา ProximityPrompt ของ NPC) / TakeQuestViaDialog (tween → fireproximityprompt → รอ NpcDialogue → คลิกมุมจอข้ามบทพูด → firesignal Choice.MouseButton1Click) ใช้ตอน Select Farm ติ๊กไว้มากกว่า 1 เควส
- `Config` — Distance / Angles / TweenSpeed / WarpDistance / Theme
- `Helpers` — Error / GetRootPart / EnableNoclip / SelectTeam
- `Quest Functions` — IsQuest / RemoveQuest / IsValidQuest / TakeQuest
- `Player Actions` — PlayerClick / GetAttackRemote / NormalAttack / IsEquipWeapon / EquipWeapon / Tweento
- `Monsters` — EatMonster / GetCloseMonster / KillMonster
- `Boss` — GetBossDataFolder / GetBossList (dynamic จาก Modules.DataBase.Npc.Boss) / FindBossInstance (MobsFolder → MobsFolder.Boss → workspace.AI) / KillBoss (direct, ไม่หาใกล้สุด) + BossTick ใน Main Loop (ฆ่าทีละตัวต่อรอบ ไม่เจอพิมพ์บอกทุก 5 วิ)
- `UI/MainTab` — Section Boss Farm: Select Boss Dropdown (Multi) + Refresh Boss List + Auto Farm Boss Toggle (noclip แชร์กันทุกโหมดฟาร์ม: ปิดหมดถึงจะปิด noclip) หมายเหตุ: เปลี่ยน Flag เป็น `Select Bosses` (config เก่าที่เซฟชื่อเดียวไว้จะไม่ถูกอ่าน เริ่มใหม่)
- `Quest Board` — GetBoardQuestData (require สดจาก Modules.DataBase.QuestBoard ตามชื่อ + cache) / GetHeldBoardQuest (เทียบ QuestInfo ใน HUD.Quest กับ DB) / OpenBoardGui (tween หา NPC Quest board → fireproximityprompt ซ้ำจนจอเปิด) / ClickUI (คลิกจริงผ่าน VIM กลางปุ่ม + GuiService:GetGuiInset().Y — ห้าม firesignal ปุ่ม Next/Previous เพราะ require ใน Refresh ของเกมพังบนเธรด executor) / ClickBoardNav (คลิกแล้วรอจน index ขยับจริง ไม่ขยับยิงซ้ำ 3 ครั้งแล้วให้อีกปุ่มสะกิด) / GetBoardState (อ่าน index+รายการเควสพร้อม UID/isCompleted จาก upvalue ปุ่ม Next ผ่าน debug.getupvalues) / BoardIsGreen + BoardQuestAcceptable (ปุ่มเขียว + Action=Accept + เวลถึง + ข้าม isCompleted + ตัวกรอง Collect/Boss) / CollectChest (ยิง prompt หีบ Workspace.Chest) / BoardTick (คลิก Next ไล่ทีละเควสไม่เกินจำนวนจริง เจออันรับได้ firesignal Accept ทันที, ถือเควสบอร์ดฟาร์มตาม Type Kill/Eat/Collect, Eat บังคับ AutoEat ชั่วคราว, ไม่ถือไปรับใหม่, วนครบไม่เจออ่าน ResetTime แล้วรอ) — เควสบอร์ด priority สูงสุด: Selected/Level ถืออยู่ห้ามยกเลิก ให้บอร์ดทำจนจบก่อน (บอร์ดวิ่งก่อนใน loop ตอนว่างเลยได้หยิบก่อน)
- `UI/BoardTab` — Auto Quest Board + Skip Collect Quests + Skip Boss Quests (บอสรับเฉพาะตอนเกิด)
- `Quest Select` — GetQuestList / FindQuestByGiver / GetHeldSelectedQuest (เช็คว่าเควสที่ถืออยู่เป็นของ Selected ไหม) / FarmSelectedQuestsTick (ถือเควสไหนฟาร์มต่อจนจบ ไม่สลับ, วนคิวตามลำดับที่ติ๊ก, ข้ามมอนไม่เกิด/เวลไม่ถึง)
- `Farm Ticks` — BossTick (ฆ่าทีละตัวต่อรอบ) / AutoFarmLevelTick (1 รอบต่อ cycle, ไม่แย่งเควส Selected) / Main Loop แบบ round-robin เปิดพร้อมกันได้ทุกอัน ทุก tick มี xpcall กัน thread หลักตาย
- `UI/SelectFarmTab` — Select Quests Dropdown (Multi) + Refresh Quest List + Auto Farm Selected Toggle (เปิดแล้วปิด AutoFarmLevel ให้, Selected ได้ priority ใน main loop)
- `Farm` — AutoFarmLevelTick (1 tick = 1 เควสไซเคิล, logic เดิม)
- `Arduino Core` — setup() ครั้งเดียว + loop(dt, now) ทุกเฟรม ขับด้วย RunService.RenderStepped เส้นเดียว (ไม่มี while/task.spawn) + state machine load_config → wait_data → wait_temp → settling → ready + guard _env._arduinoConn กันรันซ้ำ
- `Teleport Helpers` — GetTalkNpcList / GetTalkNpcRoot + GetPlayerList / FindPlayer / TeleportToPlayer (via Tweento)
- `UI` — MacHub V2: ProfileTab / MainTab (Console+Toggle) / TeleportTab (NPC+Player) / SettingTab (Slider+Dropdown)
- `Load Config` — รวมอยู่ใน Arduino loop แล้ว (stage load_config โหลด 1 ครั้ง, ไม่บล็อก)

ถ้าจะแยกโมดูลในอนาคต แนะนำแยกตามหัวข้อนี้เป็น `src/*.lua` ได้เลยโดยไม่ต้องแก้ logic ข้างใน

# boss-world.lua (ไฟล์โลกบอส แยกจาก main.lua)

- รันไฟล์เดียวจบสำหรับฟาร์ม World Boss โดยเฉพาะ
- `Config` แยกชุด (`BossDistance`, `BossAngles`, `BossTweenSpeed`, `BossWarpDistance`, `BossTheme`) + เซฟคอนฟิกแยกโฟลเดอร์ `MacHub V2 Boss` ไม่ชนกับ main
- `World Boss` — LoadWorldBossData / GetWorldBossList (`World bosses` เป็น ModuleScript ต้อง require เอาชื่อ key) / PressBossStart (กดปุ่ม `HUD.Start` ให้บอสเกิด กดซ้ำทุก 3 วิตอนไม่มีบอส) / FindBossInstance (MobsFolder → MobsFolder.Boss → workspace.AI) / KillBoss (direct) / WorldBossTick (ฆ่าทีละตัวต่อรอบ)
- `UI` — ProfileTab (Select Team) / General (Console + Select Boss Multi + Refresh + Auto Farm World Boss + Retry Rounds Slider) / Setting (Slider + Theme) ไม่มี Tab เควส/Teleport
- `Auto Retry` — Slider `Rounds` Min 0–30 (ตั้งยอดรวมอย่างเดียว, debounce กันสแปมตอนลาก) + Toggle `Auto Retry` (กดเปิด = เอายอดไปใช้ตรงๆ ไม่บวกเพิ่ม) + Toggle `Loop Forever` (วนไม่จำกัด) : watcher จับ `RetryUI.Frame` เปิด → รอ 2 วิให้หน้านิ่ง → กด Retry → พัก 3 วิก่อนรอบถัดไป (cooldown กันเบิ้ล 8 วิ) หมดรอบปิด toggle ให้เอง
- `Slider Sync` — FindRetrySliderUI / SyncRetrySlider (lib ไม่มี :Set ให้ เลยหาแถว Rounds จากโครงสร้าง UI แล้วขยับ fill/knob/ตัวเลขเอง ใช้ตอนนับรอบถดถอย/โหลดคอนฟิกเสร็จ) รอบเหลือโชว์ใน Console เพราะ Slider ของ UI lib ไม่มี API ตั้งค่าตอนรัน
- ใช้ `_env` คีย์แยก (`SelectedWorldBoss`, `AutoFarmWorldBoss`, `LoadedBossData`) รันพร้อม main ไม่ตีกัน
