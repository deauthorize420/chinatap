local BASE = rawget(_G, "CHINA_BASE") or 
"https://raw.githubusercontent.com/deauthorize420/chinatap/main/" 
local GUILIB_URL = BASE .. "chinatap_guilib.lua" local CHANGER_URL = BASE .. 
"chinatap_changer.lua" local ffi = rawget(_G, "ffi") local function r_ptr(a) 
return tonumber(ffi.cast("uint64_t*", a)[0]) end local function valid(p) return 
p ~= nil and p > 0x10000 and p < 0x7FFFFFFFFFFF end local SIG = { vm = "E8 ?? ??
?? ?? 48 8B CB E8 ?? ?? ?? ?? 84 C0 74 11 F3 0F 10 45 B0", } local function 
fetch(url, cacheFile) local src local bust = url .. "?nocache=" .. 
tostring({}):gsub("%W", "") pcall(function() src = http.Get(bust) end) if 
type(src) ~= "string" or #src <= 500 then pcall(function() src = http.Get(url) 
end) end if type(src) == "string" and #src > 500 then pcall(function() local f =
 file.Open(cacheFile, "w") if f then f:Write(src); f:Close() end end) return 
src, "server" end pcall(function() local f = file.Open(cacheFile, "r") if f then
src = f:Read(); f:Close() end end) if type(src) == "string" and #src > 500 then
return src, "cache" end return nil end local function load(url, cacheFile, 
name) local src, where = fetch(url, cacheFile) if not src then 
print("[chinatap] FATAL: cannot load " .. name) return nil end local chunk, err
= loadstring(src, "=" .. cacheFile) if not chunk then print("[chinatap] " .. 
name .. " compile error: " .. tostring(err)) return nil end local ok, mod = 
pcall(chunk) if not ok then print("[chinatap] " .. name .. " run error: " .. 
tostring(mod)) return nil end print("[chinatap] " .. name .. " loaded from " ..
tostring(where)) return mod end local M = load(GUILIB_URL, 
".\\chinatap_lua\\chinatap_guilib.lua", "guilib") if type(M) ~= "table" then 
return end local C = load(CHANGER_URL, 
".\\chinatap_lua\\chinatap_changer.lua", "changer") if type(C) ~= "table" then
return end local floor = math.floor local VM = {} local HS = {} local weaponLb,
skinLb, skinWd local sWear, sSeed, cbAuto local modelLb, modelWd, modelPaths 
local cbVm, vmX, vmY, vmZ local hsOn, hsCmb, hsCmbWd, hsVol local ksOn, ksCmb, 
ksCmbWd, ksVol local hlOn, hlMiss, hlHit, hlHurt, hlKill local wmOn, wmElems, 
wmPos local rgOn, rgCmb, rgCmbWd, rgPen, rgMin local ncOn, ncMode, ncSrc, 
ncText, ncSpeed local vrOn, vrMode local SND_NAMES, SND_PATHS local lastModelSel
= -1 local curPaints = { 0 } local lastSel = -1 local lastSig = nil local 
lastAutoDef = nil local lastAuto = false local function item() return 
C.items[weaponLb:Get()] end local function paint() return 
curPaints[skinLb:Get()] or 0 end local function settings() return sWear:Get(), 
sSeed:Get(), cbAuto:Get() end local function getSkinById(id) for k, v in 
pairs(C.skins) do if v.id == id then return v end end end local function 
getWeaponById(id) for k, v in pairs(C.items) do if v.id == id then return v end 
end end local function comboSelected(cmb) local idx = cmb:Get() if idx >= 0 then
local items = cmb:GetItems() if items and idx < #items then return items[idx + 
1] end end end local function setSkinList(weapon) local list = {} local 
paintkits = C.skins if weapon then local def = weapon.def or "" local wName = 
weapon.name or "" local function matches(k) return not k.only or k.only == 
weapon.id or k.only == def or k.only == wName end for _, v in ipairs(paintkits) 
do if (not v.weapon or v.weapon == weapon.id or v.weapon == def or v.weapon == 
wName) and (not v.not_weapon or (v.not_weapon ~= weapon.id and v.not_weapon ~= 
def and v.not_weapon ~= wName)) then if v.id == 0 then table.insert(list, 1, v) 
else table.insert(list, v) end end end end if #list == 0 then list = { { id = 0,
name = "Default" } } end return list end local function setModelList(weapon) 
local list = {} if weapon and weapon.models then for _, v in ipairs(weapon.models
) do table.insert(list, v) end end if #list == 0 then table.insert(list, 
"Default") end return list end local function updateSkins() local w = item() if 
w then local list = setSkinList(w) skinLb:SetItems(list) skinLb:Set(0) 
curPaints = list end end local function updateModels() local w = item() if w 
then local list = setModelList(w) modelLb:SetItems(list) modelLb:Set(0) end end 
local function updateWeaponSelect() local idx = weaponLb:Get() if idx >= 0 then 
local items = weaponLb:GetItems() if items and idx < #items then local w = items[
idx + 1] if w then updateSkins() updateModels() lastModelSel = -1 end end end 
end local function onWeaponChange() local w = item() if w then updateSkins() 
updateModels() lastModelSel = -1 end end local function onSkinChange() local idx
= skinLb:Get() if idx >= 0 then local items = skinLb:GetItems() if items and idx 
< #items then local s = items[idx + 1] if s then local w = item() if w and 
s.id == 0 then sWear:SetText("0") sSeed:SetText("0") cbAuto:Set(false) else 
sWear:SetText(tostring(s.wear or 0)) sSeed:SetText(tostring(s.seed or 0)) 
cbAuto:Set(s.auto or false) end end end end end local function onModelChange()
local idx = modelLb:Get() if idx >= 0 then local items = modelLb:GetItems() if 
items and idx < #items then local m = items[idx + 1] if m and m ~= "Default" 
then local w = item() if w and w.models then for i, v in ipairs(w.models) do if 
v == m then lastModelSel = i - 1 break end end end end end end local function 
setupUI() local ui = M.ui local win = ui.Window("ChinaTap", "chinatap", 300, 
500) win:SetVisible(true) win:SetDraggable(true) local tab = ui.TabControl(win) 
local t1 = tab:Add("Weapon") local t2 = tab:Add("Sound") local t3 = tab:Add(
"Visual") local t4 = tab:Add("Misc") local grp1 = ui.Group(t1, "Skin Changer") 
weaponLb = ui.ComboBox(grp1, "Weapon", C.items) weaponLb:Set(0) 
weaponLb.OnChange = onWeaponChange skinLb = ui.ComboBox(grp1, "Skin", {}) 
skinLb.OnChange = onSkinChange skinWd = ui.Button(grp1, "Update", function() 
updateSkins() end) sWear = ui.TextEntry(grp1, "Wear") sSeed = ui.TextEntry(grp1,
"Seed") cbAuto = ui.CheckBox(grp1, "Auto") local grp2 = ui.Group(t1, "Model 
Changer") modelLb = ui.ComboBox(grp2, "Model", {}) modelLb.OnChange = 
onModelChange modelWd = ui.Button(grp2, "Update", function() updateModels() end)
modelPaths = ui.MultiTextEntry(grp2, "Paths") local grp3 = ui.Group(t1, "Viewmodel
") cbVm = ui.CheckBox(grp3, "Enable") vmX = ui.Slider(grp3, "X", -10, 10, 0, 0.1)
vmY = ui.Slider(grp3, "Y", -10, 10, 0, 0.1) vmZ = ui.Slider(grp3, "Z", -10, 10, 0,
0.1) local grp4 = ui.Group(t2, "Hit Sound") hsOn = ui.CheckBox(grp4, "Enable") 
hsCmb = ui.ComboBox(grp4, "Sound", { "Default", "Custom" }) hsCmbWd = ui.Button(
grp4, "Browse", function() local path = M.file.OpenDialog("Select sound file", 
"*.wav;*.mp3") if path then hsCmb:Set(1) hsVol:SetText(path) end end) hsVol = 
ui.TextEntry(grp4, "Path") local grp5 = ui.Group(t2, "Kill Sound") ksOn = 
ui.CheckBox(grp5, "Enable") ksCmb = ui.ComboBox(grp5, "Sound", { "Default", 
"Custom" }) ksCmbWd = ui.Button(grp5, "Browse", function() local path = 
M.file.OpenDialog("Select sound file", "*.wav;*.mp3") if path then ksCmb:Set(1) 
ksVol:SetText(path) end end) ksVol = ui.TextEntry(grp5, "Path") local grp6 = 
ui.Group(t2, "Hit Logger") hlOn = ui.CheckBox(grp6, "Enable") hlMiss = 
ui.CheckBox(grp6, "Miss") hlHit = ui.CheckBox(grp6, "Hit") hlHurt = 
ui.CheckBox(grp6, "Hurt") hlKill = ui.CheckBox(grp6, "Kill") local grp7 = 
ui.Group(t3, "World Modulate") wmOn = ui.CheckBox(grp7, "Enable") wmElems = 
ui.MultiTextEntry(grp7, "Elements") wmPos = ui.TextEntry(grp7, "Position") local 
grp8 = ui.Group(t3, "Rainbow") rgOn = ui.CheckBox(grp8, "Enable") rgCmb = 
ui.ComboBox(grp8, "Mode", { "Rainbow", "Pulse" }) rgCmbWd = ui.Button(grp8, 
"Update", function() end) rgPen = ui.Slider(grp8, "Speed", 1, 20, 5, 1) rgMin = 
ui.Slider(grp8, "Min", 0, 255, 50, 1) local grp9 = ui.Group(t4, "Name Changer") 
ncOn = ui.CheckBox(grp9, "Enable") ncMode = ui.ComboBox(grp9, "Mode", { "Static",
"Spam", "Spam (Fast)" }) ncSrc = ui.Button(grp9, "Source", function() local path
= M.file.OpenDialog("Select name file", "*.txt") if path then ncText:SetText(
path) end end) ncText = ui.TextEntry(grp9, "File") ncSpeed = ui.Slider(grp9, 
"Speed", 1, 20, 5, 1) local grp10 = ui.Group(t4, "Vote Reset") vrOn = 
ui.CheckBox(grp10, "Enable") vrMode = ui.ComboBox(grp10, "Mode", { "Instant", 
"On Vote" }) end setupUI() local function getVM() if not cbVm:Get() then return 
end local w = item() if not w then return end local id = w.id or 0 local x = 
vmX:Get() local y = vmY:Get() local z = vmZ:Get() if x == 0 and y == 0 and z == 0
then return end return id, x, y, z end local function getHS() if not hsOn:Get() 
then return end local mode = hsCmb:Get() local path = hsVol:Get() if mode == 0 
then return "default" elseif mode == 1 and path and path ~= "" then return path 
end end local function getKS() if not ksOn:Get() then return end local mode = 
ksCmb:Get() local path = ksVol:Get() if mode == 0 then return "default" elseif 
mode == 1 and path and path ~= "" then return path end end local function getHL()
if not hlOn:Get() then return end return hlMiss:Get(), hlHit:Get(), hlHurt:Get(),
hlKill:Get() end local function getWM() if not wmOn:Get() then return end local 
elems = wmElems:Get() local pos = wmPos:Get() if elems and pos then return elems,
pos end end local function getRG() if not rgOn:Get() then return end local mode =
rgCmb:Get() local speed = rgPen:Get() local min = rgMin:Get() return mode, speed,
min end local function getNC() if not ncOn:Get() then return end local mode = 
ncMode:Get() local file = ncText:Get() local speed = ncSpeed:Get() if file and 
file ~= "" then return mode, file, speed end end local function getVR() if not 
vrOn:Get() then return end return vrMode:Get() == 0 end local function 
applyVM(id, x, y, z) local p = mem.FindPattern(DLL, SIG.vm) if not p then return 
end local addr = p + 0x1C local val = ffi.cast("float*", addr) val[0] = x val[1] 
= y val[2] = z end local function applyHS(path) if path == "default" then 
M.sound.PlayDefaultHit() else M.sound.PlayCustomHit(path) end end local function 
applyKS(path) if path == "default" then M.sound.PlayDefaultKill() else 
M.sound.PlayCustomKill(path) end end local function applyHL(miss, hit, hurt, 
kill) M.logger.Set(miss, hit, hurt, kill) end local function applyWM(elems, pos)
M.world.Apply(elems, pos) end local function applyRG(mode, speed, min) 
M.rainbow.Set(mode, speed, min) end local function applyNC(mode, file, speed) 
M.namechanger.Set(mode, file, speed) end local function applyVR(instant) 
M.votereset.Set(instant) end local function tick() local vm = getVM() if vm then 
applyVM(vm[1], vm[2], vm[3], vm[4]) end local hs = getHS() if hs then applyHS(hs)
end local ks = getKS() if ks then applyKS(ks) end local hl = getHL() if hl then 
applyHL(hl[1], hl[2], hl[3], hl[4]) end local wm = getWM() if wm then applyWM(wm[
1], wm[2]) end local rg = getRG() if rg then applyRG(rg[1], rg[2], rg[3]) end 
local nc = getNC() if nc then applyNC(nc[1], nc[2], nc[3]) end local vr = getVR()
if vr then applyVR(vr) end end local function main() print("[chinatap] loaded") 
while true do pcall(tick) M.util.Sleep(50) end end local ok, err = pcall(main) 
if not ok then print("[chinatap] error: " .. tostring(err)) end
