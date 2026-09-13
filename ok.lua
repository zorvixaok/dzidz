if getgenv then getgenv().__SM_error = nil end
local __ok, __err = xpcall(function()
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local plr               = Players.LocalPlayer
local SCRIPT_NAME  = "StrongmanRebirthsGUI"
local CONFIG_FILE  = "StrongmanSimulator_settings.json"
local RATE_LIMIT_PER_SEC = 400
local TARGET_PLACE = 6766156863
local log = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	pcall(print, "[Strongman] " .. table.concat(parts, " "))
end
if not game:IsLoaded() then
	pcall(function() game.Loaded:Wait() end)
end
if not plr then
	plr = Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer
end
if not plr then error("[Strongman] LocalPlayer not found") end
local b32 = bit32
local function md5hex(msg)
	msg = tostring(msg)
	local s = {7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
	           5,9,14,20, 5,9,14,20, 5,9,14,20, 5,9,14,20,
	           4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
	           6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21}
	local K = {}
	for i = 1, 64 do K[i] = math.floor(math.abs(math.sin(i)) * 4294967296) % 4294967296 end
	local a0,b0,c0,d0 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
	local bitlen = #msg * 8
	msg = msg .. "\128"
	while (#msg % 64) ~= 56 do msg = msg .. "\0" end
	local lo = bitlen % 4294967296
	local hi = math.floor(bitlen / 4294967296)
	for i = 0, 3 do msg = msg .. string.char(b32.band(b32.rshift(lo, 8*i), 0xFF)) end
	for i = 0, 3 do msg = msg .. string.char(b32.band(b32.rshift(hi, 8*i), 0xFF)) end
	for chunk = 0, (#msg / 64) - 1 do
		local M = {}
		local base = chunk * 64
		for j = 0, 15 do
			local p1,p2,p3,p4 = msg:byte(base + j*4 + 1, base + j*4 + 4)
			M[j] = p1 + p2*256 + p3*65536 + p4*16777216
		end
		local A,B,C,D = a0,b0,c0,d0
		for i = 0, 63 do
			local F, g
			if i < 16 then F = b32.bor(b32.band(B,C), b32.band(b32.bnot(B), D)); g = i
			elseif i < 32 then F = b32.bor(b32.band(D,B), b32.band(b32.bnot(D), C)); g = (5*i + 1) % 16
			elseif i < 48 then F = b32.bxor(B, b32.bxor(C, D)); g = (3*i + 5) % 16
			else F = b32.bxor(C, b32.bor(B, b32.bnot(D))); g = (7*i) % 16 end
			F = (F + A + K[i+1] + M[g]) % 4294967296
			A = D; D = C; C = B
			B = (B + b32.lrotate(F, s[i+1])) % 4294967296
		end
		a0 = (a0 + A) % 4294967296
		b0 = (b0 + B) % 4294967296
		c0 = (c0 + C) % 4294967296
		d0 = (d0 + D) % 4294967296
	end
	local out = {}
	for _, v in ipairs({a0,b0,c0,d0}) do
		for i = 0, 3 do out[#out + 1] = string.format("%02x", b32.band(b32.rshift(v, 8*i), 0xFF)) end
	end
	return table.concat(out)
end
local function hashedRemoteName(name)
	return md5hex(name .. game.JobId)
end
local function loadConfig()
	local raw
	pcall(function() raw = readfile(CONFIG_FILE) end)
	if not raw then return {} end
	local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and type(t) == "table" then return t end
	return {}
end
local function saveConfig(t)
	local ok, raw = pcall(function() return HttpService:JSONEncode(t) end)
	if ok then pcall(function() writefile(CONFIG_FILE, raw) end) end
end
local cfg = loadConfig()
cfg.target = tonumber(cfg.target) or 1000000
cfg.farm   = cfg.farm ~= false
cfg.anchor = cfg.anchor ~= false
cfg.quiet  = cfg.quiet ~= false
local rateLast = 0
local function rateLimit()
	local minGap = 1 / RATE_LIMIT_PER_SEC
	local d = os.clock() - rateLast
	if d < minGap then task.wait(minGap - d) end
	rateLast = os.clock()
end
local placeOk = (game.PlaceId == TARGET_PLACE)
local Lib = workspace:WaitForChild("Lib", 30)
local function findRemote(name, class)
	if not name then return nil end
	local inst = game:GetService("ReplicatedStorage"):FindFirstChild(hashedRemoteName(name))
	if not inst then return nil end
	if class and not inst:IsA(class) then return nil end
	return inst
end
local upgradeRemote = findRemote("StrongMan_UpgradeStrength", "RemoteFunction")
local sellRemote    = findRemote("TGSPetSystem_SellMultiPets", "RemoteFunction")
local anchorRemote  = findRemote("StrongmanWorkout_SetIsWorkingOut", "RemoteEvent")
local DS
if Lib then
	pcall(function() DS = require(Lib.Data.TGSDataStore) end)
end
local function itemsData()
	local d = DS and DS.PlayerData
	if d and d.Items then return d.Items end
	return nil
end
local function getRebirths()
	local it = itemsData()
	if it and it.Stat and it.Stat.Rebirth then return it.Stat.Rebirth end
	local ls = plr:FindFirstChild("leaderstats")
	local r = ls and ls:FindFirstChild("Rebirths")
	return (r and r.Value) or 0
end
local function getEnergy()
	local it = itemsData()
	if it and it.Currency and it.Currency.Default then return it.Currency.Default end
	return nil
end
local function fmt(n)
	n = tonumber(n)
	if not n then return "?" end
	local s = string.format("%.0f", n)
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^%s+", ""):gsub("%s+$", ""))
end
local uiGuard = { active = false, saved = nil, since = 0 }
local function getUiConns()
	if not (DS and DS.StatUpdatedEvent) then return nil end
	if type(getconnections) ~= "function" then return nil end
	local ok, conns = pcall(getconnections, DS.StatUpdatedEvent.Event)
	if not ok or type(conns) ~= "table" or #conns == 0 then return nil end
	return conns
end
local function suppressUi()
	if not cfg.quiet or uiGuard.active then return false end
	local conns = getUiConns()
	if not conns then return false end
	local saved = {}
	for _, c in ipairs(conns) do
		local fn = c.Function
		if type(fn) == "function" then
			local ok = pcall(function() c:Disconnect() end)
			if ok then saved[#saved + 1] = fn end
		end
	end
	if #saved == 0 then return false end
	uiGuard.saved = saved
	uiGuard.active = true
	uiGuard.since = os.clock()
	return true
end
local function releaseUi(refresh)
	if not uiGuard.active then return end
	uiGuard.active = false
	local saved = uiGuard.saved
	uiGuard.saved = nil
	if DS and DS.StatUpdatedEvent then
		for _, fn in ipairs(saved or {}) do
			pcall(function() DS.StatUpdatedEvent.Event:Connect(fn) end)
		end
		if refresh then
			pcall(function()
				local d = DS.PlayerData
				DS.StatUpdatedEvent:Fire("Items", (d and d.Items) or {}, nil)
			end)
		end
	end
end
local function countFor(R)
	return math.min(math.max(1, math.floor(R * 0.01)), 50000)
end
local function stepCost(level)
	return math.floor(level ^ 1.25 + 1)
end
local function totalCost(R, count)
	local t = 0
	local lvl = R
	for _ = 1, count do
		t = t + stepCost(lvl)
		lvl = lvl + 1
	end
	return t
end
local function ensureAnchored()
	local char = plr.Character
	if not char then return false end
	if char.PrimaryPart and char.PrimaryPart.Anchored then return true end
	if anchorRemote then anchorRemote:FireServer(true) end
	local t = os.clock()
	while os.clock() - t < 3 do
		char = plr.Character
		if char and char.PrimaryPart and char.PrimaryPart.Anchored then return true end
		task.wait(0.05)
	end
	return false
end
local function unanchor()
	if anchorRemote then pcall(function() anchorRemote:FireServer(false) end) end
end
local farmBatch = cfg.quiet and 120 or 300
local farmErr = nil
local lastSellMs = 0
local function sellFakePets(n)
	if not sellRemote then
		farmErr = "remote TGSPetSystem_SellMultiPets not found"
		return false
	end
	local list = table.create(n)
	local stamp = tostring(os.clock())
	for i = 1, n do
		list[i] = { Id = "dupe_" .. i .. "_" .. stamp, Name = "4Carat", Rarity = "Legendary" }
	end
	local quiet = suppressUi()
	local t0 = os.clock()
	local ok, err = pcall(function() sellRemote:InvokeServer(list) end)
	lastSellMs = math.floor((os.clock() - t0) * 1000)
	if quiet then
		task.wait(0.25)
		releaseUi(true)
	end
	if not ok then
		farmErr = tostring(err)
		return false
	end
	farmErr = nil
	return true
end
local running = false
local stopRequested = false
local lastStatus = "Ready"
local GEN = ((getgenv and getgenv().__StrongmanSim_gen) or 0) + 1
if getgenv then getgenv().__StrongmanSim_gen = GEN end
local function genAlive()
	if not getgenv then return true end
	return getgenv().__StrongmanSim_gen == GEN
end
local hooks = {
	status = function() end,
	progress = function() end,
	getTarget = function() return cfg.target end,
	farm = cfg.farm,
	anchor = cfg.anchor,
}
local function waitForRebirths(prev, timeout)
	local t = os.clock()
	while os.clock() - t < timeout do
		local r = getRebirths()
		if r and r ~= prev then return r end
		task.wait(0.1)
	end
	return getRebirths()
end
local function buyToTarget(targetTotal, h)
	h = h or hooks
	if running then h.status("Already running — hit «Stop»") return end
	if not placeOk then
		h.status(("WARNING: PlaceId=%d — this is not [X2]Strongman (%d). Script may not work."):format(game.PlaceId, TARGET_PLACE))
	end
	if not upgradeRemote then
		h.status("NOT WORKING: remote StrongMan_UpgradeStrength not found (check console logs)")
		log("remote not found:", hashedRemoteName("StrongMan_UpgradeStrength"))
		return
	end
	stopRequested = false
	running = true
	task.spawn(function()
		local ok, err = pcall(function()
			local target = math.floor(tonumber(targetTotal) or 0)
			if target < 1 or target > 1e12 then error("Invalid target (1 .. 1e12)") end
			local R0 = getRebirths() or 0
			if target <= R0 then
				h.status(("Already have %s rebirths — target %s reached"):format(fmt(R0), fmt(target)))
				return
			end
			if h.anchor and not ensureAnchored() then
				error("Failed to anchor character (StrongmanWorkout_SetIsWorkingOut)")
			end
			local R = R0
			local calls, fails, spent = 0, 0, 0
			local lastDiag = nil
			while R < target and not stopRequested and genAlive() do
				h.progress(R0, R, target)
				local targetNow = math.floor(tonumber(h.getTarget()) or target)
				if targetNow >= 1 and targetNow <= 1e12 then target = targetNow end
				local count = countFor(R)
				local v59 = 1
				local cost = totalCost(R, count)
				local E = getEnergy()
				if E ~= nil and cost > E * 0.98 then
					if not h.farm then
						error(("Not enough energy: need ~%s, have %s (enable autofarm)"):format(fmt(cost), fmt(E)))
					end
					local attempts = 0
					while E ~= nil and cost > getEnergy() * 0.98 and not stopRequested and genAlive() do
						attempts = attempts + 1
						if attempts > 200 then
							error("Farm not giving energy. " .. tostring(farmErr or "check SellMultiPets remote"))
						end
						h.status(("Low energy — farming%s (%s pets, %dms) ~%s / %s"):format(
							cfg.quiet and " quietly" or "", fmt(farmBatch), lastSellMs, fmt(getEnergy()), fmt(cost)))
						if not sellFakePets(farmBatch) then
							error("Farm not working: " .. tostring(farmErr))
						end
						if cfg.quiet then
							if lastSellMs > 900 then
								farmBatch = math.max(40, math.floor(farmBatch * 0.7))
							elseif lastSellMs < 350 then
								farmBatch = math.min(250, math.floor(farmBatch * 1.3))
							end
						end
						rateLimit()
						task.wait(cfg.quiet and 0.35 or 0.3)
					end
				end
				if stopRequested or not genAlive() then break end
				if h.anchor and not ensureAnchored() then
					error("Character unanchored, failed to re-anchor")
				end
				local Rbefore = R
				local E0 = getEnergy()
				h.status(("Call #%d: +%s rebirths (batch 1 × %s), cost ~%s"):format(
					calls + 1, fmt(count * v59), fmt(count), fmt(cost)))
				local t0 = os.clock()
				local okI, res = pcall(function()
					return upgradeRemote:InvokeServer(1, "Rebirth")
				end)
				calls = calls + 1
				local newR = waitForRebirths(R, 4)
				local gained = (newR or R) - Rbefore
				if okI and gained > 0 then
					fails = 0
					spent = spent + math.max(0, (E0 or 0) - (getEnergy() or E0 or 0))
					R = newR
					local cd = 0.75
					local window = math.max(cd - 0.1, 0.1) + 0.1
					local elapsed = os.clock() - t0
					if elapsed < window then task.wait(window - elapsed) end
				else
					fails = fails + 1
					lastDiag = ("ok=%s res=%s gained=%d energy=%s"):format(
						tostring(okI), tostring(res), gained, tostring(getEnergy()))
					log("call failed:", lastDiag)
					h.status(("Call gave no result (%d/3): %s"):format(fails, lastDiag))
					if fails >= 3 then
						error("3 calls in a row with no result — server may have closed the hole or anticheat triggered. " .. tostring(lastDiag))
					end
					task.wait(0.25)
				end
				rateLimit()
			end
			h.progress(R0, R, target)
			local totalGain = R - R0
			if stopRequested or not genAlive() then
				h.status(("Stopped at %s rebirths (gain %s)"):format(fmt(R), fmt(totalGain)))
			elseif totalGain > 0 then
				h.status(("Done: %s rebirths · calls %d · spent ~%s energy"):format(
					fmt(R), calls, fmt(spent)))
			else
				h.status("NOT WORKING: no call credited rebirths. " .. tostring(lastDiag or "see console"))
			end
		end)
		if not ok then
			h.status("Error: " .. tostring(err))
			log("ERROR:", tostring(err))
		end
		if h.anchor then unanchor() end
		running = false
	end)
end
if getgenv and getgenv().__StrongmanSim_idled then
	pcall(function() getgenv().__StrongmanSim_idled:Disconnect() end)
end
local idledConn
do
	local vu = game:GetService("VirtualUser")
	idledConn = plr.Idled:Connect(function()
		pcall(function()
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	end)
end
if getgenv then getgenv().__StrongmanSim_idled = idledConn end
local function mk(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local function pickParentGui()
	local pg = plr:FindFirstChildOfClass("PlayerGui") or plr:WaitForChild("PlayerGui", 5)
	if pg then return pg, pg:GetFullName() end
	local okH, h = pcall(function() return gethui and gethui() end)
	if okH and h then return h, h:GetFullName() end
	local okC, c = pcall(function() return game:GetService("CoreGui") end)
	if okC and c then return c, c:GetFullName() end
	return plr:WaitForChild("PlayerGui", 10), "PlayerGui(waited)"
end
local parentGui, parentPath = pickParentGui()
local old = parentGui:FindFirstChild(SCRIPT_NAME)
if old then old:Destroy() end
local GUI_W, GUI_H = 400, 372
local function viewportSize()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize
	if not v or v.X < 64 or v.Y < 64 then
		v = Vector2.new(1920, 1080)
	end
	return v
end
local function clampPos(px, py)
	local v = viewportSize()
	px = math.clamp(tonumber(px) or 0, 8, math.max(8, v.X - GUI_W - 8))
	py = math.clamp(tonumber(py) or 0, 8, math.max(8, v.Y - 60))
	return math.floor(px), math.floor(py)
end
local COL = {
	bg = Color3.fromRGB(24, 24, 28),
	panel = Color3.fromRGB(33, 33, 39),
	panel2 = Color3.fromRGB(40, 40, 47),
	green = Color3.fromRGB(46, 204, 113),
	red = Color3.fromRGB(231, 76, 60),
	blue = Color3.fromRGB(52, 152, 219),
	gray = Color3.fromRGB(90, 90, 100),
	text = Color3.fromRGB(240, 240, 245),
	dim = Color3.fromRGB(165, 165, 175),
}
local gui = mk("ScreenGui", {
	Name = SCRIPT_NAME,
	ResetOnSpawn = false,
	Enabled = true,
	IgnoreGuiInset = true,
	DisplayOrder = 2147483647,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = parentGui,
})
local main = mk("Frame", {
	Name = "Main",
	Size = UDim2.new(0, GUI_W, 0, GUI_H),
	Position = UDim2.new(0.5, -GUI_W / 2, 0.4, -GUI_H / 2),
	BackgroundColor3 = COL.bg,
	BorderSizePixel = 0,
	Parent = gui,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }),
	mk("UIStroke", { Color = Color3.fromRGB(60, 60, 70), Thickness = 1 }),
})
if cfg.px and cfg.py then
	local px, py = clampPos(cfg.px, cfg.py)
	main.Position = UDim2.new(0, px, 0, py)
end
local header = mk("TextLabel", {
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = COL.panel,
	BorderSizePixel = 0,
	Text = "  [X2]Strongman — rebirths",
	TextColor3 = COL.text,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }),
})
local closeBtn = mk("TextButton", {
	Size = UDim2.new(0, 30, 0, 24),
	Position = UDim2.new(1, -34, 0, 6),
	BackgroundColor3 = COL.red,
	BorderSizePixel = 0,
	Text = "X",
	TextColor3 = COL.text,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	Parent = main,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }),
})
local statsLbl = mk("TextLabel", {
	Size = UDim2.new(1, -20, 0, 20),
	Position = UDim2.new(0, 10, 0, 42),
	BackgroundTransparency = 1,
	Text = "Rebirths: …   Energy: …",
	TextColor3 = COL.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})
mk("TextLabel", {
	Size = UDim2.new(0, 45, 0, 26),
	Position = UDim2.new(0, 10, 0, 68),
	BackgroundTransparency = 1,
	Text = "Target:",
	TextColor3 = COL.dim,
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})
local targetBox = mk("TextBox", {
	Size = UDim2.new(0, 220, 0, 28),
	Position = UDim2.new(0, 58, 0, 67),
	BackgroundColor3 = COL.panel2,
	BorderSizePixel = 0,
	Text = tostring(cfg.target),
	PlaceholderText = "how many total rebirths",
	PlaceholderColor3 = COL.gray,
	TextColor3 = COL.text,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	ClearTextOnFocus = false,
	Parent = main,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }),
})
local presetRow = mk("Frame", {
	Size = UDim2.new(0, 322, 0, 24),
	Position = UDim2.new(0, 58, 0, 100),
	BackgroundTransparency = 1,
	Parent = main,
})
local function preset(offset, value, text)
	local b = mk("TextButton", {
		Size = UDim2.new(0, 66, 0, 22),
		Position = UDim2.new(0, offset, 0, 0),
		BackgroundColor3 = COL.panel2,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = COL.dim,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		Parent = presetRow,
	}, {
		mk("UICorner", { CornerRadius = UDim.new(0, 5) }),
	})
	b.MouseButton1Click:Connect(function()
		targetBox.Text = tostring(value)
	end)
end
preset(0, 100000, "100k")
preset(72, 500000, "500k")
preset(144, 1000000, "1M")
preset(216, 10000000, "10M")
local function button(text, color, x, y, w, h, cb)
	local b = mk("TextButton", {
		Size = UDim2.new(0, w, 0, h or 32),
		Position = UDim2.new(0, x, 0, y),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = COL.text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Parent = main,
	}, {
		mk("UICorner", { CornerRadius = UDim.new(0, 7) }),
	})
	b.MouseButton1Click:Connect(cb)
	return b
end
local statusLbl = mk("TextLabel", {
	Size = UDim2.new(1, -20, 0, 46),
	Position = UDim2.new(0, 10, 0, 240),
	BackgroundTransparency = 1,
	Text = "Ready",
	TextColor3 = COL.dim,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = main,
})
local barBg = mk("Frame", {
	Size = UDim2.new(1, -20, 0, 12),
	Position = UDim2.new(0, 10, 0, 290),
	BackgroundColor3 = COL.panel2,
	BorderSizePixel = 0,
	Parent = main,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }),
})
local barFill = mk("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = COL.green,
	BorderSizePixel = 0,
	Parent = barBg,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }),
})
mk("TextLabel", {
	Size = UDim2.new(1, -20, 0, 16),
	Position = UDim2.new(0, 10, 0, 306),
	BackgroundTransparency = 1,
	Text = "start = start to target · Check = test and logs · Unload = remove script",
	TextColor3 = COL.gray,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})
local function guiAlive()
	local ok, alive = pcall(function() return gui and gui.Parent ~= nil end)
	return ok and alive == true
end
local function setStatus(text)
	lastStatus = tostring(text)
	log(lastStatus)
	pcall(function()
		if guiAlive() then
			statusLbl.Text = lastStatus
			statusLbl.TextColor3 = (lastStatus:find("NOT WORKING") or lastStatus:find("Error")) and COL.red or COL.dim
		end
	end)
end
local function setProgress(r0, r, target)
	if not guiAlive() then return end
	local denom = math.max(1, target - r0)
	local f = math.clamp((r - r0) / denom, 0, 1)
	pcall(function() barFill.Size = UDim2.new(f, 0, 1, 0) end)
end
hooks.status = setStatus
hooks.progress = setProgress
hooks.getTarget = function()
	local ok, n = pcall(function() return tonumber(targetBox.Text) end)
	return (ok and n) or cfg.target
end
button("▶ start", COL.green, 10, 132, 130, 32, function()
	local t = tonumber(targetBox.Text)
	if not t or t < 1 or t > 1e12 then
		setStatus("Enter correct number (1 .. 1e12)")
		return
	end
	cfg.target = math.floor(t)
	saveConfig(cfg)
	buyToTarget(math.floor(t), hooks)
end)
button("■  Stop", COL.red, 148, 132, 90, 32, function()
	stopRequested = true
	setStatus("Stopping after current call…")
end)
button("Unload", COL.gray, 246, 132, 144, 32, function()
	stopRequested = true
	task.spawn(function()
		local t = os.clock()
		while running and os.clock() - t < 5 do task.wait(0.1) end
		unanchor()
		releaseUi(true)
		pcall(function() idledConn:Disconnect() end)
		if getgenv then getgenv().__StrongmanSim_gen = nil end
		pcall(function() gui:Destroy() end)
	end)
end)
button("🔍 Check (test, logs in console)", COL.blue, 10, 172, 380, 26, function()
	task.spawn(function()
		local lines = {}
		lines[#lines + 1] = ("place=%s (%d) version=%s job=%s"):format(game.Name, game.PlaceId, tostring(game.PlaceVersion), game.JobId)
		lines[#lines + 1] = ("placeOk=%s  PlayerGui=%s"):format(tostring(placeOk), parentGui:GetFullName())
		lines[#lines + 1] = ("TGSDataStore=%s  itemsData=%s"):format(tostring(DS ~= nil), tostring(itemsData() ~= nil))
		lines[#lines + 1] = ("upgrade=%s  sell=%s  anchor=%s"):format(
			upgradeRemote and "OK" or "NO", sellRemote and "OK" or "NO", anchorRemote and "OK" or "NO")
		lines[#lines + 1] = ("rebirths=%s energy=%s"):format(fmt(getRebirths()), fmt(getEnergy()))
		for _, l in ipairs(lines) do log("DIAG:", l) end
		local okA = ensureAnchored()
		lines[#lines + 1] = "anchor=" .. tostring(okA)
		if upgradeRemote then
			local R0 = getRebirths() or 0
			local need = stepCost(R0) * 2
			local Enow = getEnergy()
			lines[#lines + 1] = ("stepCost=%s need2x=%s energy=%s"):format(fmt(stepCost(R0)), fmt(need), fmt(Enow))
			if (Enow == nil or Enow < need) and sellRemote then
				log("TEST: low energy — farming 1 batch before test")
				sellFakePets(FARM_BATCH)
				task.wait(1)
				Enow = getEnergy()
				lines[#lines + 1] = "energy after farm=" .. fmt(Enow)
			end
			local E0 = getEnergy()
			local okC, res = pcall(function() return upgradeRemote:InvokeServer(1, "Rebirth") end)
			local R1 = waitForRebirths(R0, 5) or R0
			local E1 = getEnergy()
			lines[#lines + 1] = ("test call: ok=%s res=%s gained=%s energyDelta=%s"):format(
				tostring(okC), tostring(res), tostring(R1 - R0),
				(E0 ~= nil and E1 ~= nil) and tostring(E0 - E1) or "?")
			if R1 - R0 <= 0 then
				setStatus(("Check: call gave no result (res=%s). Cost 1 rebirth ~%s, energy %s — check console"):format(
					tostring(res), fmt(stepCost(R0)), fmt(getEnergy())))
			else
				setStatus(("Check OK: +%s rebirths per call"):format(tostring(R1 - R0)))
			end
		else
			setStatus("Check: remote StrongMan_UpgradeStrength NOT found — see console")
		end
		if sellRemote then
			local E0 = getEnergy()
			local okS = sellFakePets(5)
			task.wait(1)
			local E1 = getEnergy()
			lines[#lines + 1] = ("farm test: ok=%s err=%s energyDelta=%s"):format(
				tostring(okS), tostring(farmErr), (E0 ~= nil and E1 ~= nil) and tostring(E1 - E0) or "?")
		else
			lines[#lines + 1] = "farm test: sell remote NOT FOUND"
		end
		for _, l in ipairs(lines) do log("TEST:", l) end
		unanchor()
	end)
end)
local function toggle(text, state, x, w, y)
	local t = mk("TextButton", {
		Size = UDim2.new(0, w, 0, 26),
		Position = UDim2.new(0, x, 0, y),
		BackgroundColor3 = state and COL.green or COL.panel2,
		BorderSizePixel = 0,
		Text = "",
		Parent = main,
	}, {
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }),
		mk("TextLabel", {
			Size = UDim2.new(1, -10, 1, 0),
			Position = UDim2.new(0, 5, 0, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = state and Color3.fromRGB(20, 20, 25) or COL.dim,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			Parent = t,
		}),
	})
	return t
end
local farmTgl = toggle("Farm pets", cfg.farm, 10, 150, 206)
local quietTgl = toggle("Quiet mode", cfg.quiet, 166, 128, 206)
local anchorTgl = toggle("Auto-anchor", cfg.anchor, 300, 100, 206)
local function paintToggle(t, state)
	t.BackgroundColor3 = state and COL.green or COL.panel2
	t:FindFirstChildWhichIsA("TextLabel").TextColor3 =
		state and Color3.fromRGB(20, 20, 25) or COL.dim
end
farmTgl.MouseButton1Click:Connect(function()
	cfg.farm = not cfg.farm
	hooks.farm = cfg.farm
	paintToggle(farmTgl, cfg.farm)
	saveConfig(cfg)
end)
quietTgl.MouseButton1Click:Connect(function()
	cfg.quiet = not cfg.quiet
	farmBatch = cfg.quiet and 120 or 300
	paintToggle(quietTgl, cfg.quiet)
	saveConfig(cfg)
end)
anchorTgl.MouseButton1Click:Connect(function()
	cfg.anchor = not cfg.anchor
	hooks.anchor = cfg.anchor
	paintToggle(anchorTgl, cfg.anchor)
	saveConfig(cfg)
end)
hooks.farm = cfg.farm
hooks.anchor = cfg.anchor
do
	local dragging, dragStart, startPos = false, nil, nil
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					local px, py = clampPos(main.Position.X.Offset, main.Position.Y.Offset)
					cfg.px, cfg.py = px, py
					saveConfig(cfg)
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(0, startPos.X.Offset + d.X, 0, startPos.Y.Offset + d.Y)
		end
	end)
end
closeBtn.MouseButton1Click:Connect(function()
	stopRequested = true
	task.spawn(function()
		local t = os.clock()
		while running and os.clock() - t < 5 do task.wait(0.1) end
		unanchor()
		releaseUi(true)
		pcall(function() idledConn:Disconnect() end)
		pcall(function() gui:Destroy() end)
	end)
end)
local function recenter()
	pcall(function()
		local v = viewportSize()
		local px, py = clampPos(math.floor((v.X - GUI_W) / 2), math.floor((v.Y - GUI_H) / 2))
		main.Position = UDim2.new(0, px, 0, py)
		cfg.px, cfg.py = px, py
		saveConfig(cfg)
	end)
end
local function showGui()
	pcall(function()
		if gui.Parent == nil then gui.Parent = parentGui end
		gui.Enabled = true
		gui.DisplayOrder = 2147483647
		main.Visible = true
	end)
	recenter()
	log("show: parent=" .. tostring(gui.Parent and gui.Parent:GetFullName()) ..
		" viewport=" .. tostring(viewportSize()) .. " pos=" .. tostring(main.Position))
end
local function hideGui()
	pcall(function() main.Visible = false end)
end
do
	pcall(function()
		UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.KeyCode == Enum.KeyCode.RightShift then
				if main.Visible then hideGui() else showGui() end
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			pcall(function()
				if gui and gui.Parent == nil then
					gui.Parent = parentGui
				end
			end)
			pcall(function()
				if uiGuard.active and os.clock() - uiGuard.since > 20 then
					releaseUi(true)
				end
			end)
		end
	end)
end
task.spawn(function()
	while guiAlive() do
		pcall(function()
			statsLbl.Text = ("Rebirths: %s    Energy: %s"):format(fmt(getRebirths()), fmt(getEnergy()))
		end)
		task.wait(1)
	end
end)
if getgenv then
	getgenv().StrongmanRebirths = {
		buy = function(t) buyToTarget(t, hooks) end,
		stop = function() stopRequested = true end,
		status = function() return lastStatus end,
		isRunning = function() return running end,
		setFarm = function(v) hooks.farm = v and true or false end,
		setQuiet = function(v)
			cfg.quiet = v and true or false
			farmBatch = cfg.quiet and 120 or 300
		end,
		sellTest = function(n) return sellFakePets(n or farmBatch) end,
		show = function() showGui() end,
		hide = function() hideGui() end,
		recenter = function() recenter() end,
		selftest = function() return { place = game.PlaceId, rebirths = getRebirths(), energy = getEnergy(), upgrade = upgradeRemote ~= nil, sell = sellRemote ~= nil, anchor = anchorRemote ~= nil, parent = tostring(parentGui and parentGui:GetFullName()), viewport = tostring(viewportSize()), quiet = cfg.quiet, farmBatch = farmBatch, lastSellMs = lastSellMs, uiSuppressed = uiGuard.active } end,
		destroy = function()
			stopRequested = true
			unanchor()
			releaseUi(true)
			pcall(function() gui:Destroy() end)
		end,
	}
end
log(("boot: place=%s(%d) ver=%s job=%s"):format(game.Name, game.PlaceId, tostring(game.PlaceVersion), game.JobId))
log(("boot: placeOk=%s Lib=%s DS=%s"):format(tostring(placeOk), tostring(Lib ~= nil), tostring(DS ~= nil)))
log(("boot: upgrade=%s sell=%s anchor=%s"):format(
	upgradeRemote and "OK" or "NO", sellRemote and "OK" or "NO", anchorRemote and "OK" or "NO"))
log(("boot: rebirths=%s energy=%s"):format(fmt(getRebirths()), fmt(getEnergy())))
log(("boot: gui parent=%s viewport=%s pos=%s"):format(tostring(parentPath), tostring(viewportSize()), tostring(main.Position)))
log("boot: if window not visible — hit RightShift or run getgenv().StrongmanRebirths.show()")
do
	local warns = {}
	if not placeOk then warns[#warns + 1] = "you are not in [X2]Strongman Simulator (PlaceId " .. game.PlaceId .. ")" end
	if not upgradeRemote then warns[#warns + 1] = "no buy remote" end
	if not sellRemote then warns[#warns + 1] = "no pet dupe remote (farm will not work)" end
	if #warns > 0 then
		setStatus("WARNING: " .. table.concat(warns, "; "))
	else
		setStatus(("Ready. Rebirths %s, energy %s"):format(fmt(getRebirths()), fmt(getEnergy())))
	end
end
end, function(e) return tostring(e) .. "\n" .. tostring(debug.traceback()) end)
if not __ok and getgenv then getgenv().__SM_error = __err end
if not __ok then
	pcall(print, "[Strongman] FAILED: " .. tostring(__err))
end
if getgenv then getgenv().__SM_error = nil end
local __ok, __err = xpcall(function()
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local plr               = Players.LocalPlayer
local SCRIPT_NAME  = "StrongmanRebirthsGUI"
local CONFIG_FILE  = "StrongmanSimulator_settings.json"
local RATE_LIMIT_PER_SEC = 400
local TARGET_PLACE = 6766156863
local log = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	pcall(print, "[Strongman] " .. table.concat(parts, " "))
end
if not game:IsLoaded() then
	pcall(function() game.Loaded:Wait() end)
end
if not plr then
	plr = Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer
end
if not plr then error("[Strongman] LocalPlayer not found") end
local b32 = bit32
local function md5hex(msg)
	msg = tostring(msg)
	local s = {7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
	           5,9,14,20, 5,9,14,20, 5,9,14,20, 5,9,14,20,
	           4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
	           6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21}
	local K = {}
	for i = 1, 64 do K[i] = math.floor(math.abs(math.sin(i)) * 4294967296) % 4294967296 end
	local a0,b0,c0,d0 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
	local bitlen = #msg * 8
	msg = msg .. "\128"
	while (#msg % 64) ~= 56 do msg = msg .. "\0" end
	local lo = bitlen % 4294967296
	local hi = math.floor(bitlen / 4294967296)
	for i = 0, 3 do msg = msg .. string.char(b32.band(b32.rshift(lo, 8*i), 0xFF)) end
	for i = 0, 3 do msg = msg .. string.char(b32.band(b32.rshift(hi, 8*i), 0xFF)) end
	for chunk = 0, (#msg / 64) - 1 do
		local M = {}
		local base = chunk * 64
		for j = 0, 15 do
			local p1,p2,p3,p4 = msg:byte(base + j*4 + 1, base + j*4 + 4)
			M[j] = p1 + p2*256 + p3*65536 + p4*16777216
		end
		local A,B,C,D = a0,b0,c0,d0
		for i = 0, 63 do
			local F, g
			if i < 16 then F = b32.bor(b32.band(B,C), b32.band(b32.bnot(B), D)); g = i
			elseif i < 32 then F = b32.bor(b32.band(D,B), b32.band(b32.bnot(D), C)); g = (5*i + 1) % 16
			elseif i < 48 then F = b32.bxor(B, b32.bxor(C, D)); g = (3*i + 5) % 16
			else F = b32.bxor(C, b32.bor(B, b32.bnot(D))); g = (7*i) % 16 end
			F = (F + A + K[i+1] + M[g]) % 4294967296
			A = D; D = C; C = B
			B = (B + b32.lrotate(F, s[i+1])) % 4294967296
		end
		a0 = (a0 + A) % 4294967296
		b0 = (b0 + B) % 4294967296
		c0 = (c0 + C) % 4294967296
		d0 = (d0 + D) % 4294967296
	end
	local out = {}
	for _, v in ipairs({a0,b0,c0,d0}) do
		for i = 0, 3 do out[#out + 1] = string.format("%02x", b32.band(b32.rshift(v, 8*i), 0xFF)) end
	end
	return table.concat(out)
end
local function hashedRemoteName(name)
	return md5hex(name .. game.JobId)
end
local function loadConfig()
	local raw
	pcall(function() raw = readfile(CONFIG_FILE) end)
	if not raw then return {} end
	local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and type(t) == "table" then return t end
	return {}
end
local function saveConfig(t)
	local ok, raw = pcall(function() return HttpService:JSONEncode(t) end)
	if ok then pcall(function() writefile(CONFIG_FILE, raw) end) end
end
local cfg = loadConfig()
cfg.target = tonumber(cfg.target) or 1000000
cfg.farm   = cfg.farm ~= false
cfg.anchor = cfg.anchor ~= false
cfg.quiet  = cfg.quiet ~= false
local rateLast = 0
local function rateLimit()
	local minGap = 1 / RATE_LIMIT_PER_SEC
	local d = os.clock() - rateLast
	if d < minGap then task.wait(minGap - d) end
	rateLast = os.clock()
end
local placeOk = (game.PlaceId == TARGET_PLACE)
local Lib = workspace:WaitForChild("Lib", 30)
local function findRemote(name, class)
	if not name then return nil end
	local inst = game:GetService("ReplicatedStorage"):FindFirstChild(hashedRemoteName(name))
	if not inst then return nil end
	if class and not inst:IsA(class) then return nil end
	return inst
end
local upgradeRemote = findRemote("StrongMan_UpgradeStrength", "RemoteFunction")
local sellRemote    = findRemote("TGSPetSystem_SellMultiPets", "RemoteFunction")
local anchorRemote  = findRemote("StrongmanWorkout_SetIsWorkingOut", "RemoteEvent")
local DS
if Lib then
	pcall(function() DS = require(Lib.Data.TGSDataStore) end)
end
local function itemsData()
	local d = DS and DS.PlayerData
	if d and d.Items then return d.Items end
	return nil
end
local function getRebirths()
	local it = itemsData()
	if it and it.Stat and it.Stat.Rebirth then return it.Stat.Rebirth end
	local ls = plr:FindFirstChild("leaderstats")
	local r = ls and ls:FindFirstChild("Rebirths")
	return (r and r.Value) or 0
end
local function getEnergy()
	local it = itemsData()
	if it and it.Currency and it.Currency.Default then return it.Currency.Default end
	return nil
end
local function fmt(n)
	n = tonumber(n)
	if not n then return "?" end
	local s = string.format("%.0f", n)
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^%s+", ""):gsub("%s+$", ""))
end
local uiGuard = { active = false, saved = nil, since = 0 }
local function getUiConns()
	if not (DS and DS.StatUpdatedEvent) then return nil end
	if type(getconnections) ~= "function" then return nil end
	local ok, conns = pcall(getconnections, DS.StatUpdatedEvent.Event)
	if not ok or type(conns) ~= "table" or #conns == 0 then return nil end
	return conns
end
local function suppressUi()
	if not cfg.quiet or uiGuard.active then return false end
	local conns = getUiConns()
	if not conns then return false end
	local saved = {}
	for _, c in ipairs(conns) do
		local fn = c.Function
		if type(fn) == "function" then
			local ok = pcall(function() c:Disconnect() end)
			if ok then saved[#saved + 1] = fn end
		end
	end
	if #saved == 0 then return false end
	uiGuard.saved = saved
	uiGuard.active = true
	uiGuard.since = os.clock()
	return true
end
local function releaseUi(refresh)
	if not uiGuard.active then return end
	uiGuard.active = false
	local saved = uiGuard.saved
	uiGuard.saved = nil
	if DS and DS.StatUpdatedEvent then
		for _, fn in ipairs(saved or {}) do
			pcall(function() DS.StatUpdatedEvent.Event:Connect(fn) end)
		end
		if refresh then
			pcall(function()
				local d = DS.PlayerData
				DS.StatUpdatedEvent:Fire("Items", (d and d.Items) or {}, nil)
			end)
		end
	end
end
local function countFor(R)
	return math.min(math.max(1, math.floor(R * 0.01)), 50000)
end
local function stepCost(level)
	return math.floor(level ^ 1.25 + 1)
end
local function totalCost(R, count)
	local t = 0
	local lvl = R
	for _ = 1, count do
		t = t + stepCost(lvl)
		lvl = lvl + 1
	end
	return t
end
local function ensureAnchored()
	local char = plr.Character
	if not char then return false end
	if char.PrimaryPart and char.PrimaryPart.Anchored then return true end
	if anchorRemote then anchorRemote:FireServer(true) end
	local t = os.clock()
	while os.clock() - t < 3 do
		char = plr.Character
		if char and char.PrimaryPart and char.PrimaryPart.Anchored then return true end
		task.wait(0.05)
	end
	return false
end
local function unanchor()
	if anchorRemote then pcall(function() anchorRemote:FireServer(false) end) end
end
local farmBatch = cfg.quiet and 120 or 300
local farmErr = nil
local lastSellMs = 0
local function sellFakePets(n)
	if not sellRemote then
		farmErr = "remote TGSPetSystem_SellMultiPets not found"
		return false
	end
	local list = table.create(n)
	local stamp = tostring(os.clock())
	for i = 1, n do
		list[i] = { Id = "dupe_" .. i .. "_" .. stamp, Name = "4Carat", Rarity = "Legendary" }
	end
	local quiet = suppressUi()
	local t0 = os.clock()
	local ok, err = pcall(function() sellRemote:InvokeServer(list) end)
	lastSellMs = math.floor((os.clock() - t0) * 1000)
	if quiet then
		task.wait(0.25)
		releaseUi(true)
	end
	if not ok then
		farmErr = tostring(err)
		return false
	end
	farmErr = nil
	return true
end
local running = false
local stopRequested = false
local lastStatus = "Ready"
local GEN = ((getgenv and getgenv().__StrongmanSim_gen) or 0) + 1
if getgenv then getgenv().__StrongmanSim_gen = GEN end
local function genAlive()
	if not getgenv then return true end
	return getgenv().__StrongmanSim_gen == GEN
end
local hooks = {
	status = function() end,
	progress = function() end,
	getTarget = function() return cfg.target end,
	farm = cfg.farm,
	anchor = cfg.anchor,
}
local function waitForRebirths(prev, timeout)
	local t = os.clock()
	while os.clock() - t < timeout do
		local r = getRebirths()
		if r and r ~= prev then return r end
		task.wait(0.1)
	end
	return getRebirths()
end
local function buyToTarget(targetTotal, h)
	h = h or hooks
	if running then h.status("Already running — hit «Stop»") return end
	if not placeOk then
		h.status(("WARNING: PlaceId=%d — this is not [X2]Strongman (%d). Script may not work."):format(game.PlaceId, TARGET_PLACE))
	end
	if not upgradeRemote then
		h.status("NOT WORKING: remote StrongMan_UpgradeStrength not found (check console logs)")
		log("remote not found:", hashedRemoteName("StrongMan_UpgradeStrength"))
		return
	end
	stopRequested = false
	running = true
	task.spawn(function()
		local ok, err = pcall(function()
			local target = math.floor(tonumber(targetTotal) or 0)
			if target < 1 or target > 1e12 then error("Invalid target (1 .. 1e12)") end
			local R0 = getRebirths() or 0
			if target <= R0 then
				h.status(("Already have %s rebirths — target %s reached"):format(fmt(R0), fmt(target)))
				return
			end
			if h.anchor and not ensureAnchored() then
				error("Failed to anchor character (StrongmanWorkout_SetIsWorkingOut)")
			end
			local R = R0
			local calls, fails, spent = 0, 0, 0
			local lastDiag = nil
			while R < target and not stopRequested and genAlive() do
				h.progress(R0, R, target)
				local targetNow = math.floor(tonumber(h.getTarget()) or target)
				if targetNow >= 1 and targetNow <= 1e12 then target = targetNow end
				local count = countFor(R)
				local v59 = 1
				local cost = totalCost(R, count)
				local E = getEnergy()
				if E ~= nil and cost > E * 0.98 then
					if not h.farm then
						error(("Not enough energy: need ~%s, have %s (enable autofarm)"):format(fmt(cost), fmt(E)))
					end
					local attempts = 0
					while E ~= nil and cost > getEnergy() * 0.98 and not stopRequested and genAlive() do
						attempts = attempts + 1
						if attempts > 200 then
							error("Farm not giving energy. " .. tostring(farmErr or "check SellMultiPets remote"))
						end
						h.status(("Low energy — farming%s (%s pets, %dms) ~%s / %s"):format(
							cfg.quiet and " quietly" or "", fmt(farmBatch), lastSellMs, fmt(getEnergy()), fmt(cost)))
						if not sellFakePets(farmBatch) then
							error("Farm not working: " .. tostring(farmErr))
						end
						if cfg.quiet then
							if lastSellMs > 900 then
								farmBatch = math.max(40, math.floor(farmBatch * 0.7))
							elseif lastSellMs < 350 then
								farmBatch = math.min(250, math.floor(farmBatch * 1.3))
							end
						end
						rateLimit()
						task.wait(cfg.quiet and 0.35 or 0.3)
					end
				end
				if stopRequested or not genAlive() then break end
				if h.anchor and not ensureAnchored() then
					error("Character unanchored, failed to re-anchor")
				end
				local Rbefore = R
				local E0 = getEnergy()
				h.status(("Call #%d: +%s rebirths (batch 1 × %s), cost ~%s"):format(
					calls + 1, fmt(count * v59), fmt(count), fmt(cost)))
				local t0 = os.clock()
				local okI, res = pcall(function()
					return upgradeRemote:InvokeServer(1, "Rebirth")
				end)
				calls = calls + 1
				local newR = waitForRebirths(R, 4)
				local gained = (newR or R) - Rbefore
				if okI and gained > 0 then
					fails = 0
					spent = spent + math.max(0, (E0 or 0) - (getEnergy() or E0 or 0))
					R = newR
					local cd = 0.75
					local window = math.max(cd - 0.1, 0.1) + 0.1
					local elapsed = os.clock() - t0
					if elapsed < window then task.wait(window - elapsed) end
				else
					fails = fails + 1
					lastDiag = ("ok=%s res=%s gained=%d energy=%s"):format(
						tostring(okI), tostring(res), gained, tostring(getEnergy()))
					log("call failed:", lastDiag)
					h.status(("Call gave no result (%d/3): %s"):format(fails, lastDiag))
					if fails >= 3 then
						error("3 calls in a row with no result — server may have closed the hole or anticheat triggered. " .. tostring(lastDiag))
					end
					task.wait(0.25)
				end
				rateLimit()
			end
			h.progress(R0, R, target)
			local totalGain = R - R0
			if stopRequested or not genAlive() then
				h.status(("Stopped at %s rebirths (gain %s)"):format(fmt(R), fmt(totalGain)))
			elseif totalGain > 0 then
				h.status(("Done: %s rebirths · calls %d · spent ~%s energy"):format(
					fmt(R), calls, fmt(spent)))
			else
				h.status("NOT WORKING: no call credited rebirths. " .. tostring(lastDiag or "see console"))
			end
		end)
		if not ok then
			h.status("Error: " .. tostring(err))
			log("ERROR:", tostring(err))
		end
		if h.anchor then unanchor() end
		running = false
	end)
end
if getgenv and getgenv().__StrongmanSim_idled then
	pcall(function() getgenv().__StrongmanSim_idled:Disconnect() end)
end
local idledConn
do
	local vu = game:GetService("VirtualUser")
	idledConn = plr.Idled:Connect(function()
		pcall(function()
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	end)
end
if getgenv then getgenv().__StrongmanSim_idled = idledConn end
local function mk(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local function pickParentGui()
	local pg = plr:FindFirstChildOfClass("PlayerGui") or plr:WaitForChild("PlayerGui", 5)
	if pg then return pg, pg:GetFullName() end
	local okH, h = pcall(function() return gethui and gethui() end)
	if okH and h then return h, h:GetFullName() end
	local okC, c = pcall(function() return game:GetService("CoreGui") end)
	if okC and c then return c, c:GetFullName() end
	return plr:WaitForChild("PlayerGui", 10), "PlayerGui(waited)"
end
local parentGui, parentPath = pickParentGui()
local old = parentGui:FindFirstChild(SCRIPT_NAME)
if old then old:Destroy() end
local GUI_W, GUI_H = 400, 372
local function viewportSize()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize
	if not v or v.X < 64 or v.Y < 64 then
		v = Vector2.new(1920, 1080)
	end
	return v
end
local function clampPos(px, py)
	local v = viewportSize()
	px = math.clamp(tonumber(px) or 0, 8, math.max(8, v.X - GUI_W - 8))
	py = math.clamp(tonumber(py) or 0, 8, math.max(8, v.Y - 60))
	return math.floor(px), math.floor(py)
end
local COL = {
	bg = Color3.fromRGB(24, 24, 28),
	panel = Color3.fromRGB(33, 33, 39),
	panel2 = Color3.fromRGB(40, 40, 47),
	green = Color3.fromRGB(46, 204, 113),
	red = Color3.fromRGB(231, 76, 60),
	blue = Color3.fromRGB(52, 152, 219),
	gray = Color3.fromRGB(90, 90, 100),
	text = Color3.fromRGB(240, 240, 245),
	dim = Color3.fromRGB(165, 165, 175),
}
local gui = mk("ScreenGui", {
	Name = SCRIPT_NAME,
	ResetOnSpawn = false,
	Enabled = true,
	IgnoreGuiInset = true,
	DisplayOrder = 2147483647,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = parentGui,
})
local main = mk("Frame", {
	Name = "Main",
	Size = UDim2.new(0, GUI_W, 0, GUI_H),
	Position = UDim2.new(0.5, -GUI_W / 2, 0.4, -GUI_H / 2),
	BackgroundColor3 = COL.bg,
	BorderSizePixel = 0,
	Parent = gui,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }),
	mk("UIStroke", { Color = Color3.fromRGB(60, 60, 70), Thickness = 1 }),
})
if cfg.px and cfg.py then
	local px, py = clampPos(cfg.px, cfg.py)
	main.Position = UDim2.new(0, px, 0, py)
end
local header = mk("TextLabel", {
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = COL.panel,
	BorderSizePixel = 0,
	Text = "  [X2]Strongman — rebirths",
	TextColor3 = COL.text,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }),
})
local closeBtn = mk("TextButton", {
	Size = UDim2.new(0, 30, 0, 24),
	Position = UDim2.new(1, -34, 0, 6),
	BackgroundColor3 = COL.red,
	BorderSizePixel = 0,
	Text = "X",
	TextColor3 = COL.text,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	Parent = main,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }),
})
local statsLbl = mk("TextLabel", {
	Size = UDim2.new(1, -20, 0, 20),
	Position = UDim2.new(0, 10, 0, 42),
	BackgroundTransparency = 1,
	Text = "Rebirths: …   Energy: …",
	TextColor3 = COL.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})
mk("TextLabel", {
	Size = UDim2.new(0, 45, 0, 26),
	Position = UDim2.new(0, 10, 0, 68),
	BackgroundTransparency = 1,
	Text = "Target:",
	TextColor3 = COL.dim,
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})
local targetBox = mk("TextBox", {
	Size = UDim2.new(0, 220, 0, 28),
	Position = UDim2.new(0, 58, 0, 67),
	BackgroundColor3 = COL.panel2,
	BorderSizePixel = 0,
	Text = tostring(cfg.target),
	PlaceholderText = "how many total rebirths",
	PlaceholderColor3 = COL.gray,
	TextColor3 = COL.text,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	ClearTextOnFocus = false,
	Parent = main,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }),
})
local presetRow = mk("Frame", {
	Size = UDim2.new(0, 322, 0, 24),
	Position = UDim2.new(0, 58, 0, 100),
	BackgroundTransparency = 1,
	Parent = main,
})
local function preset(offset, value, text)
	local b = mk("TextButton", {
		Size = UDim2.new(0, 66, 0, 22),
		Position = UDim2.new(0, offset, 0, 0),
		BackgroundColor3 = COL.panel2,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = COL.dim,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		Parent = presetRow,
	}, {
		mk("UICorner", { CornerRadius = UDim.new(0, 5) }),
	})
	b.MouseButton1Click:Connect(function()
		targetBox.Text = tostring(value)
	end)
end
preset(0, 100000, "100k")
preset(72, 500000, "500k")
preset(144, 1000000, "1M")
preset(216, 10000000, "10M")
local function button(text, color, x, y, w, h, cb)
	local b = mk("TextButton", {
		Size = UDim2.new(0, w, 0, h or 32),
		Position = UDim2.new(0, x, 0, y),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = COL.text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Parent = main,
	}, {
		mk("UICorner", { CornerRadius = UDim.new(0, 7) }),
	})
	b.MouseButton1Click:Connect(cb)
	return b
end
local statusLbl = mk("TextLabel", {
	Size = UDim2.new(1, -20, 0, 46),
	Position = UDim2.new(0, 10, 0, 240),
	BackgroundTransparency = 1,
	Text = "Ready",
	TextColor3 = COL.dim,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = main,
})
local barBg = mk("Frame", {
	Size = UDim2.new(1, -20, 0, 12),
	Position = UDim2.new(0, 10, 0, 290),
	BackgroundColor3 = COL.panel2,
	BorderSizePixel = 0,
	Parent = main,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }),
})
local barFill = mk("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = COL.green,
	BorderSizePixel = 0,
	Parent = barBg,
}, {
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }),
})
mk("TextLabel", {
	Size = UDim2.new(1, -20, 0, 16),
	Position = UDim2.new(0, 10, 0, 306),
	BackgroundTransparency = 1,
	Text = "Buy = buy to target · Check = test and logs · Unload = remove script",
	TextColor3 = COL.gray,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = main,
})
local function guiAlive()
	local ok, alive = pcall(function() return gui and gui.Parent ~= nil end)
	return ok and alive == true
end
local function setStatus(text)
	lastStatus = tostring(text)
	log(lastStatus)
	pcall(function()
		if guiAlive() then
			statusLbl.Text = lastStatus
			statusLbl.TextColor3 = (lastStatus:find("NOT WORKING") or lastStatus:find("Error")) and COL.red or COL.dim
		end
	end)
end
local function setProgress(r0, r, target)
	if not guiAlive() then return end
	local denom = math.max(1, target - r0)
	local f = math.clamp((r - r0) / denom, 0, 1)
	pcall(function() barFill.Size = UDim2.new(f, 0, 1, 0) end)
end
hooks.status = setStatus
hooks.progress = setProgress
hooks.getTarget = function()
	local ok, n = pcall(function() return tonumber(targetBox.Text) end)
	return (ok and n) or cfg.target
end
button("▶  START", COL.green, 10, 132, 130, 32, function()
	local t = tonumber(targetBox.Text)
	if not t or t < 1 or t > 1e12 then
		setStatus("Enter correct number (1 .. 1e12)")
		return
	end
	cfg.target = math.floor(t)
	saveConfig(cfg)
	buyToTarget(math.floor(t), hooks)
end)
button("■  Stop", COL.red, 148, 132, 90, 32, function()
	stopRequested = true
	setStatus("Stopping after current call…")
end)
button("Unload", COL.gray, 246, 132, 144, 32, function()
	stopRequested = true
	task.spawn(function()
		local t = os.clock()
		while running and os.clock() - t < 5 do task.wait(0.1) end
		unanchor()
		releaseUi(true)
		pcall(function() idledConn:Disconnect() end)
		if getgenv then getgenv().__StrongmanSim_gen = nil end
		pcall(function() gui:Destroy() end)
	end)
end)
button("🔍 Check (test, logs in console)", COL.blue, 10, 172, 380, 26, function()
	task.spawn(function()
		local lines = {}
		lines[#lines + 1] = ("place=%s (%d) version=%s job=%s"):format(game.Name, game.PlaceId, tostring(game.PlaceVersion), game.JobId)
		lines[#lines + 1] = ("placeOk=%s  PlayerGui=%s"):format(tostring(placeOk), parentGui:GetFullName())
		lines[#lines + 1] = ("TGSDataStore=%s  itemsData=%s"):format(tostring(DS ~= nil), tostring(itemsData() ~= nil))
		lines[#lines + 1] = ("upgrade=%s  sell=%s  anchor=%s"):format(
			upgradeRemote and "OK" or "NO", sellRemote and "OK" or "NO", anchorRemote and "OK" or "NO")
		lines[#lines + 1] = ("rebirths=%s energy=%s"):format(fmt(getRebirths()), fmt(getEnergy()))
		for _, l in ipairs(lines) do log("DIAG:", l) end
		local okA = ensureAnchored()
		lines[#lines + 1] = "anchor=" .. tostring(okA)
		if upgradeRemote then
			local R0 = getRebirths() or 0
			local need = stepCost(R0) * 2
			local Enow = getEnergy()
			lines[#lines + 1] = ("stepCost=%s need2x=%s energy=%s"):format(fmt(stepCost(R0)), fmt(need), fmt(Enow))
			if (Enow == nil or Enow < need) and sellRemote then
				log("TEST: low energy — farming 1 batch before test")
				sellFakePets(FARM_BATCH)
				task.wait(1)
				Enow = getEnergy()
				lines[#lines + 1] = "energy after farm=" .. fmt(Enow)
			end
			local E0 = getEnergy()
			local okC, res = pcall(function() return upgradeRemote:InvokeServer(1, "Rebirth") end)
			local R1 = waitForRebirths(R0, 5) or R0
			local E1 = getEnergy()
			lines[#lines + 1] = ("test call: ok=%s res=%s gained=%s energyDelta=%s"):format(
				tostring(okC), tostring(res), tostring(R1 - R0),
				(E0 ~= nil and E1 ~= nil) and tostring(E0 - E1) or "?")
			if R1 - R0 <= 0 then
				setStatus(("Check: call gave no result (res=%s). Cost 1 rebirth ~%s, energy %s — check console"):format(
					tostring(res), fmt(stepCost(R0)), fmt(getEnergy())))
			else
				setStatus(("Check OK: +%s rebirths per call"):format(tostring(R1 - R0)))
			end
		else
			setStatus("Check: remote StrongMan_UpgradeStrength NOT found — see console")
		end
		if sellRemote then
			local E0 = getEnergy()
			local okS = sellFakePets(5)
			task.wait(1)
			local E1 = getEnergy()
			lines[#lines + 1] = ("farm test: ok=%s err=%s energyDelta=%s"):format(
				tostring(okS), tostring(farmErr), (E0 ~= nil and E1 ~= nil) and tostring(E1 - E0) or "?")
		else
			lines[#lines + 1] = "farm test: sell remote NOT FOUND"
		end
		for _, l in ipairs(lines) do log("TEST:", l) end
		unanchor()
	end)
end)
local function toggle(text, state, x, w, y)
	local t = mk("TextButton", {
		Size = UDim2.new(0, w, 0, 26),
		Position = UDim2.new(0, x, 0, y),
		BackgroundColor3 = state and COL.green or COL.panel2,
		BorderSizePixel = 0,
		Text = "",
		Parent = main,
	}, {
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }),
		mk("TextLabel", {
			Size = UDim2.new(1, -10, 1, 0),
			Position = UDim2.new(0, 5, 0, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = state and Color3.fromRGB(20, 20, 25) or COL.dim,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			Parent = t,
		}),
	})
	return t
end
local farmTgl = toggle("Farm pets", cfg.farm, 10, 150, 206)
local quietTgl = toggle("Quiet mode", cfg.quiet, 166, 128, 206)
local anchorTgl = toggle("Auto-anchor", cfg.anchor, 300, 100, 206)
local function paintToggle(t, state)
	t.BackgroundColor3 = state and COL.green or COL.panel2
	t:FindFirstChildWhichIsA("TextLabel").TextColor3 =
		state and Color3.fromRGB(20, 20, 25) or COL.dim
end
farmTgl.MouseButton1Click:Connect(function()
	cfg.farm = not cfg.farm
	hooks.farm = cfg.farm
	paintToggle(farmTgl, cfg.farm)
	saveConfig(cfg)
end)
quietTgl.MouseButton1Click:Connect(function()
	cfg.quiet = not cfg.quiet
	farmBatch = cfg.quiet and 120 or 300
	paintToggle(quietTgl, cfg.quiet)
	saveConfig(cfg)
end)
anchorTgl.MouseButton1Click:Connect(function()
	cfg.anchor = not cfg.anchor
	hooks.anchor = cfg.anchor
	paintToggle(anchorTgl, cfg.anchor)
	saveConfig(cfg)
end)
hooks.farm = cfg.farm
hooks.anchor = cfg.anchor
do
	local dragging, dragStart, startPos = false, nil, nil
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					local px, py = clampPos(main.Position.X.Offset, main.Position.Y.Offset)
					cfg.px, cfg.py = px, py
					saveConfig(cfg)
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(0, startPos.X.Offset + d.X, 0, startPos.Y.Offset + d.Y)
		end
	end)
end
closeBtn.MouseButton1Click:Connect(function()
	stopRequested = true
	task.spawn(function()
		local t = os.clock()
		while running and os.clock() - t < 5 do task.wait(0.1) end
		unanchor()
		releaseUi(true)
		pcall(function() idledConn:Disconnect() end)
		pcall(function() gui:Destroy() end)
	end)
end)
local function recenter()
	pcall(function()
		local v = viewportSize()
		local px, py = clampPos(math.floor((v.X - GUI_W) / 2), math.floor((v.Y - GUI_H) / 2))
		main.Position = UDim2.new(0, px, 0, py)
		cfg.px, cfg.py = px, py
		saveConfig(cfg)
	end)
end
local function showGui()
	pcall(function()
		if gui.Parent == nil then gui.Parent = parentGui end
		gui.Enabled = true
		gui.DisplayOrder = 2147483647
		main.Visible = true
	end)
	recenter()
	log("show: parent=" .. tostring(gui.Parent and gui.Parent:GetFullName()) ..
		" viewport=" .. tostring(viewportSize()) .. " pos=" .. tostring(main.Position))
end
local function hideGui()
	pcall(function() main.Visible = false end)
end
do
	pcall(function()
		UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.KeyCode == Enum.KeyCode.RightShift then
				if main.Visible then hideGui() else showGui() end
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			pcall(function()
				if gui and gui.Parent == nil then
					gui.Parent = parentGui
				end
			end)
			pcall(function()
				if uiGuard.active and os.clock() - uiGuard.since > 20 then
					releaseUi(true)
				end
			end)
		end
	end)
end
task.spawn(function()
	while guiAlive() do
		pcall(function()
			statsLbl.Text = ("Rebirths: %s    Energy: %s"):format(fmt(getRebirths()), fmt(getEnergy()))
		end)
		task.wait(1)
	end
end)
if getgenv then
	getgenv().StrongmanRebirths = {
		buy = function(t) buyToTarget(t, hooks) end,
		stop = function() stopRequested = true end,
		status = function() return lastStatus end,
		isRunning = function() return running end,
		setFarm = function(v) hooks.farm = v and true or false end,
		setQuiet = function(v)
			cfg.quiet = v and true or false
			farmBatch = cfg.quiet and 120 or 300
		end,
		sellTest = function(n) return sellFakePets(n or farmBatch) end,
		show = function() showGui() end,
		hide = function() hideGui() end,
		recenter = function() recenter() end,
		selftest = function() return { place = game.PlaceId, rebirths = getRebirths(), energy = getEnergy(), upgrade = upgradeRemote ~= nil, sell = sellRemote ~= nil, anchor = anchorRemote ~= nil, parent = tostring(parentGui and parentGui:GetFullName()), viewport = tostring(viewportSize()), quiet = cfg.quiet, farmBatch = farmBatch, lastSellMs = lastSellMs, uiSuppressed = uiGuard.active } end,
		destroy = function()
			stopRequested = true
			unanchor()
			releaseUi(true)
			pcall(function() gui:Destroy() end)
		end,
	}
end
log(("boot: place=%s(%d) ver=%s job=%s"):format(game.Name, game.PlaceId, tostring(game.PlaceVersion), game.JobId))
log(("boot: placeOk=%s Lib=%s DS=%s"):format(tostring(placeOk), tostring(Lib ~= nil), tostring(DS ~= nil)))
log(("boot: upgrade=%s sell=%s anchor=%s"):format(
	upgradeRemote and "OK" or "NO", sellRemote and "OK" or "NO", anchorRemote and "OK" or "NO"))
log(("boot: rebirths=%s energy=%s"):format(fmt(getRebirths()), fmt(getEnergy())))
log(("boot: gui parent=%s viewport=%s pos=%s"):format(tostring(parentPath), tostring(viewportSize()), tostring(main.Position)))
log("boot: if window not visible — hit RightShift or run getgenv().StrongmanRebirths.show()")
do
	local warns = {}
	if not placeOk then warns[#warns + 1] = "you are not in [X2]Strongman Simulator (PlaceId " .. game.PlaceId .. ")" end
	if not upgradeRemote then warns[#warns + 1] = "no buy remote" end
	if not sellRemote then warns[#warns + 1] = "no pet dupe remote (farm will not work)" end
	if #warns > 0 then
		setStatus("WARNING: " .. table.concat(warns, "; "))
	else
		setStatus(("Ready. Rebirths %s, energy %s"):format(fmt(getRebirths()), fmt(getEnergy())))
	end
end
end, function(e) return tostring(e) .. "\n" .. tostring(debug.traceback()) end)
if not __ok and getgenv then getgenv().__SM_error = __err end
if not __ok then
	pcall(print, "[Strongman] FAILED: " .. tostring(__err))
end
