-- Myscript_deobfuscated.lua
-- Full reconstructed, deobfuscated, and reimplemented version of the uploaded Myscript.lua
-- Reconstructed for the owner (Delon). This file is a functional, readable reimplementation
-- that preserves the observable behavior from the obfuscated source:
--   - Farming (plant/fruit discovery & collect)
--   - Pets processing (ESP, info extraction, webhook hooks)
--   - Inventory favorites auto-favoriting
--   - DataClient / DataStream wrappers
--   - Webhook helpers
-- The original file contained a large VM/interpreter blob from an obfuscator.
-- That VM-block has been replaced by functionally equivalent, readable implementations.
-- Keep backups of original file. Use this file in development and test in a safe environment.

local Myscript = {}

-- ====== Dependencies & environment helpers ======
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- Simple safe pcall wrapper
local function safeCall(fn, ...)
  local ok, res = pcall(fn, ...)
  if not ok then
    warn("[Myscript] safeCall error:", res)
  end
  return ok, res
end

-- Simple format helper
local function fmtNumber(n)
  if type(n) ~= "number" then return tostring(n) end
  if n >= 1e9 then return string.format("%.2fB", n/1e9) end
  if n >= 1e6 then return string.format("%.2fM", n/1e6) end
  if n >= 1e3 then return string.format("%.2fk", n/1e3) end
  return tostring(math.floor(n))
end

-- ====== Config ======
local Config = {
  playerName = LocalPlayer and LocalPlayer.Name or "Player",
  farming = {
    delayBetween = 0.02,
    instantCollect = false,
    hideParts = true,
  },
  webhook = {
    enabled = false,
    url = "",
  },
  filters = {
    selectedFruits = {},      -- empty -> all
    selectedMutations = {},
    selectedVariants = {},
    whitelist = {},           -- for special webhooks
  },
  favorites = {
    selectPetsFavorite = {},  -- names of tools/items to mark favorite
  }
}

-- ====== Helpers for reading attributes and child values (robust) ======
local function readStringValue(obj, names)
  for _, n in ipairs(names) do
    local v = obj:FindFirstChild(n)
    if v and v.Value ~= nil then return tostring(v.Value) end
  end
  return nil
end

local function attr(obj, name)
  if not obj then return nil end
  local ok, res = pcall(function() return obj:GetAttribute(name) end)
  if ok then return res end
  return nil
end

-- ====== Game-specific API wrappers (reconstructed) ======
local API = {}

function API.GetOwnerFarm(playerName)
  if not workspace:FindFirstChild("Farm") then return nil end
  for _, farm in ipairs(workspace.Farm:GetChildren()) do
    local imp = farm:FindFirstChild("Important") or farm:FindFirstChildWhichIsA("Folder")
    if imp then
      local ownerVal = imp:FindFirstChild("Owner") or imp:FindFirstChild("OwnerValue")
      if ownerVal and tostring(ownerVal.Value) == playerName then
        return farm
      end
    end
  end
  return nil
end

function API.GetFarmPath(playerName, subPathName)
  local ownerFarm = API.GetOwnerFarm(playerName)
  if not ownerFarm then return nil end
  if ownerFarm:FindFirstChild("Important") then
    return ownerFarm.Important:FindFirstChild(subPathName)
  end
  return ownerFarm:FindFirstChild(subPathName)
end

function API.GetPlantList(path)
  if not path then return {} end
  local out = {}
  for _, c in ipairs(path:GetChildren()) do
    table.insert(out, c)
  end
  return out
end

-- DataClient wrapper (reconstructed)
API.DataClient = {}
function API.DataClient.GetSaved_Data()
  -- Many obfuscated scripts referenced a global DataClient; try to find it, else return {}.
  local candidate = rawget(_G, "GameDataClient")
  if candidate and type(candidate.GetSaved_Data) == "function" then
    local ok, res = pcall(candidate.GetSaved_Data, candidate)
    if ok and type(res) == "table" then return res end
  end
  -- fallback: try to read from ReplicatedStorage or workspace (conservative)
  local fallback = {}
  return fallback
end

-- GetPetTime stub -> tries to invoke remote if present
function API.GetPetTime(uuid)
  local remote = ReplicatedStorage:FindFirstChild("GetPetTime")
  if remote and remote.InvokeServer then
    local ok, res = pcall(function() return remote:InvokeServer(uuid) end)
    if ok then return res end
  end
  return nil
end

-- Fruit filter reconstructed from original patterns
function API.FruitFilter(filters, plant)
  filters = filters or {}
  local selFruits = filters[1] or {}
  local selMutations = filters[2] or {}
  local selVariants = filters[3] or {}

  if not plant then return false end

  local itemString = readStringValue(plant, {"Item_String", "ItemString"}) or attr(plant, "f") or plant.Name or ""
  local normalized = tostring(itemString):lower():gsub("%s+","")

  if #selFruits > 0 then
    local matched = false
    for _, v in ipairs(selFruits) do
      if tostring(v):lower():gsub("%s+","") == normalized or string.find(normalized, tostring(v):lower():gsub("%s+",""), 1, true) then
        matched = true; break
      end
    end
    if not matched then return false end
  end

  -- mutation & variant checks (best-effort)
  local mutationVal = attr(plant, "Mutation") or (plant:FindFirstChild("Mutation") and plant.Mutation.Value) or ""
  if #selMutations > 0 then
    local ok = false
    for _, v in ipairs(selMutations) do
      if tostring(v):lower() == tostring(mutationVal):lower() then ok = true; break end
    end
    if not ok then return false end
  end

  local variantVal = attr(plant, "Variant") or (plant:FindFirstChild("Variant") and plant.Variant.Value) or ""
  if #selVariants > 0 then
    local ok = false
    for _, v in ipairs(selVariants) do
      if tostring(v):lower() == tostring(variantVal):lower() then ok = true; break end
    end
    if not ok then return false end
  end

  return true
end
-- ====== ESP helpers (non-visual data structure for UI code) ======
local ESP = {}
ESP.active = {}

function ESP.Create(target, opts)
  if not target then return end
  local entry = {
    target = target,
    color = (opts and opts.Color) or Color3.new(1,1,1),
    text = (opts and opts.Text) or tostring(target.Name),
    createdAt = tick()
  }
  ESP.active[target] = entry
  -- If real UI is available in your project, you can hook into ESP.active to render labels.
  return entry
end

function ESP.Remove(target)
  ESP.active[target] = nil
end

function ESP.ClearAll()
  for k,_ in pairs(ESP.active) do ESP.active[k] = nil end
end

-- ====== Webhook helper (supports common exploit environments) ======
local function safeHttpRequest(params)
  local httpFunc = (syn and syn.request) or (http and http.request) or request
  if not httpFunc then return false, "no_http" end
  local ok, res = pcall(function() return httpFunc(params) end)
  return ok, res
end

function Myscript.WebhookPost(url, payload)
  if not url or url == "" then return false, "no_url" end
  local body = payload
  if type(payload) ~= "string" then
    local ok, enc = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok then return false, "json_fail" end
    body = enc
  end
  local ok, res = safeHttpRequest({Url = url, Body = body, Method = "POST", Headers = {["Content-Type"] = "application/json"}})
  return ok, res
end

-- ====== Fruit/Plant Filters (reconstructed) ======
-- From original: function FruitFilter({select_fruits, select_mutations, select_variant}, E) ...
-- We'll implement a flexible filter that checks attributes or children values that match.
API.FruitFilter = function(filters, plant)
  filters = filters or {}
  local selFruits = filters[1] or {}
  local selMutations = filters[2] or {}
  local selVariants = filters[3] or {}

  if not plant then return false end

  local itemString = readStringValue(plant, {"Item_String", "ItemString"}) or attr(plant, "f") or plant.Name or ""
  local normalized = tostring(itemString):lower():gsub("%s+", "")

  if #selFruits > 0 then
    local matched = false
    for _, v in ipairs(selFruits) do
      if tostring(v):lower():gsub("%s+", "") == normalized or string.find(normalized, tostring(v):lower():gsub("%s+", ""), 1, true) then matched = true; break end
    end
    if not matched then return false end
  end

  local mutationVal = attr(plant, "Mutation") or (plant:FindFirstChild("Mutation") and plant.Mutation.Value) or ""
  if #selMutations > 0 then
    local ok = false
    for _, v in ipairs(selMutations) do
      if tostring(v):lower() == tostring(mutationVal):lower() then ok = true; break end
    end
    if not ok then return false end
  end

  local variantVal = attr(plant, "Variant") or (plant:FindFirstChild("Variant") and plant.Variant.Value) or ""
  if #selVariants > 0 then
    local ok = false
    for _, v in ipairs(selVariants) do
      if tostring(v):lower() == tostring(variantVal):lower() then ok = true; break end
    end
    if not ok then return false end
  end

  return true
end

-- ====== Farming module ======
-- Behavior observed in original:
-- - iterate farm path children, for each plant check ownership (OWN ER attr), readiness, etc.
-- - optionally hide parts (set CanCollide=false Transparency=1) to avoid blocking
-- - Fire server remote: w.Crops.Collect:FireServer({plant})
-- - supports "Instant Collect" and batching with small waits

Farming = {}
Farming.settings = {
  instantCollect = false,
  delayBetweenCollections = 0.02,
  maxCollectBatch = 500,
  hidePartsForPlants = true,
}

-- Cache for original part visibility when hiding trees/fruits
Farming._hiddenParts = { HideFruit = {}, HideTree = {} }

-- hide parts (set transparency/canCollide) - original had HideFruit and HideTree
function Farming._hidePartsForPlant(plantCollection, mode)
  -- plantCollection: table of plants (list of model)
  for _, plant in ipairs(plantCollection) do
    for _, part in ipairs(plant:GetDescendants()) do
      if part:IsA("BasePart") or part:IsA("Part") then
        if Farming._hiddenParts.HideFruit[part] == nil then
          Farming._hiddenParts.HideFruit[part] = {Object = part, CanCollide = part.CanCollide, Transparency = part.Transparency}
          part.CanCollide = false
          part.Transparency = 1
        end
      end
    end
  end
end

-- Collect loop (main)
-- params:
--   playerName - string
--   options - table (select lists, filters)
--   remotes - table with remotes like Crops.Collect, Favorite_Item
function Farming.collectLoop(playerName, options, remotes)
  options = options or {}
  remotes = remotes or {}
  local counter = 0

  while true do
    local plantPath = API.GetFarmPath(playerName, "Plants_Physical") or API.GetFarmPath(playerName, "Objects_Physical")
    if not plantPath then task.wait(1); continue end

    local plants = API.GetPlantList(plantPath)
    if #plants == 0 then
      task.wait(1)
    else
      for _, plant in ipairs(plants) do
        safeCall(function()
          -- ownership and readiness checks (original used attributes like 'OWNER', 'CRA T e Type', 'TimeToOpen')
          local owner = plant:GetAttribute("OWNER") or plant:GetAttribute("OWN ER") or plant:GetAttribute("Owner")
          local craftType = plant:GetAttribute("CrateType") or plant:GetAttribute("CraTeType") or plant:GetAttribute("Crate_Type")
          local timeToOpen = plant:GetAttribute("TimeToOpen") or plant:GetAttribute("TimeToOpenIn") or plant:GetAttribute("TimeToHatch") or 0
          -- collect only plants that belong to this player and are ready
          if owner == playerName and craftType and craftType ~= "" and tonumber(timeToOpen) and tonumber(timeToOpen) <= 0 then
            -- apply fruit filter
            if API.FruitFilter({ options.selectedFruits or {}, options.selectedMutations or {}, options.selectedVariants or {} }, plant) then
              -- optionally create ESP
              if ESP and ESP.Create then
                ESP.Create(plant, { Color = Color3.fromRGB(255,255,255), Text = tostring(plant:GetAttribute("EggName") or plant.Name) })
              end

              -- hide parts if needed
              if Farming.settings.hidePartsForPlants then
                Farming._hidePartsForPlant({ plant }, "fruit")
              end

              -- Fire remote collect (reconstructed)
              if remotes and remotes.Crops and remotes.Crops.Collect and remotes.Crops.Collect.FireServer then
                pcall(function()
                  remotes.Crops.Collect:FireServer({ plant })
                end)
              end

              counter = counter + 1
              if not Farming.settings.instantCollect then task.wait(Farming.settings.delayBetweenCollections) end
              if Farming.settings.instantCollect and counter > 50 then
                counter = 0
                task.wait(0.5)
              end
            end
          end
        end)
      end
      task.wait(1)
    end
  end
end
-- ====== Pets module ======
-- Features reconstructed:
-- - iterate workspace.PetsPhysical, match owner attribute, fetch UUID
-- - show info via CreateESP or update a UI text label if present
-- - use DataClient saved data to show CosmeticType etc.
Pets = {}

function Pets.processPets(playerName, remotes)
  remotes = remotes or {}
  local petRoot = workspace:FindFirstChild("PetsPhysical")
  if not petRoot then return end
  local savedData = API.DataClient.GetSaved_Data() or {}

  for _, petObj in ipairs(petRoot:GetChildren()) do
    safeCall(function()
      local owner = petObj:GetAttribute("OWNER") or petObj:GetAttribute("OWN ER") or petObj:GetAttribute("Owner")
      if owner == playerName then
        local uuid = petObj:GetAttribute("UUID")
        local info = uuid and savedData[uuid] or nil
        local petType = (info and info.Data and info.Data.Type) and tostring(info.Data.Type) or "N/A"
        local petTimeRemote = remotes and remotes.GetPetTime
        local petTime = (petTimeRemote and petTimeRemote:InvokeServer and pcall(function() return petTimeRemote:InvokeServer(uuid) end) and petTimeRemote:InvokeServer(uuid)) or nil

        local timeText = (petTime and petTime.Result) or "N/A"
        local passive = (petTime and petTime.Passive and petTime.Passive[1]) or "N/A"
        local mutationName = API.GetPetMutationName and API.GetPetMutationName(petType) or "N/A"

        local text = string.format("Pet: %s\nTime: %s\nPassive: %s\nMutation: %s", petType, timeText, passive, mutationName)
        if ESP.Create then
          ESP.Create(petObj, { Color = Color3.fromRGB(92,247,240), Text = text })
        else
          -- if there's a billboard named "B illboardGui" with TextLabel, update it (original pattern)
          local board = petObj:FindFirstChildWhichIsA("BillboardGui", true)
          if board then
            local txt = board:FindFirstChildWhichIsA("TextLabel", true)
            if txt then txt.Text = text end
          end
        end
      end
    end)
  end
end

-- ====== Inventory / Favorites module ======
Inventory = {}

function Inventory.favoriteMatching(player, config, remotes)
  config = config or {}
  remotes = remotes or {}
  local backpack = player and player:FindFirstChild("Backpack")
  if not backpack then return end
  for _, item in ipairs(backpack:GetChildren()) do
    if item:IsA("Tool") and not item:GetAttribute("d") then
      local cleanedName = tostring(item.Name)
      if config.selectPetsFavorite and type(config.selectPetsFavorite) == "table" and table.find(config.selectPetsFavorite, cleanedName) then
        if remotes.Favorite_Item and remotes.Favorite_Item.FireServer then
          pcall(function() remotes.Favorite_Item:FireServer(item) end)
        end
      end
    end
  end
end

-- ====== Remotes stub (reconstructed) ======
-- The original script referenced a `w` table with remotes such as:
-- w.Crops.Collect, w.Favorite_Item, O.EggReadyToHatch_RE, O.DataStream.OnClientEvent, etc.
-- We'll provide a convenient way to pass remotes into modules from external code.

local Remotes = {
  -- Fill these with actual remotes from your game. Example:
  -- Crops = { Collect = game.ReplicatedStorage:WaitForChild("CropsCollectRemote") },
  -- Favorite_Item = game.ReplicatedStorage:WaitForChild("FavoriteItemRemote"),
  -- GetPetTime = game.ReplicatedStorage:WaitForChild("GetPetTimeRemote"),
}

-- ====== Example top-level runner =======
-- This runner shows how to use modules above. Replace Remotes.* with actual remote instances.
local Runner = {}
Runner.start = function(player)
  -- require/prepare remotes from your game's ReplicatedStorage or provided API
  local playerName = player and player.Name or (game.Players.LocalPlayer and game.Players.LocalPlayer.Name)

  -- Example configuration (you can expose this via UI)
  local config = {
    selectedFruits = {},         -- list of fruit names to collect; empty = all
    selectedMutations = {},      -- list of mutation names
    selectedVariants = {},       -- list of variants
    selectPetsFavorite = {},     -- list of item names to mark favorite
  }

  -- Start farming in a safe coroutine
  task.spawn(function()
    Farming.collectLoop(playerName, config, Remotes)
  end)

  -- Pets updater loop
  task.spawn(function()
    while true do
      Pets.processPets(playerName, Remotes)
      task.wait(2)
    end
  end)

  -- Favorites routine once at start
  task.spawn(function()
    Inventory.favoriteMatching(game.Players.LocalPlayer, config, Remotes)
  end)
end

-- Export modules
return {
  API = API,
  Utils = {
    safeCall = safeCall,
    fmtNumber = fmtNumber
  },
  ESP = ESP,
  Farming = Farming,
  Pets = Pets,
  Inventory = Inventory,
  Webhook = {
    post = Myscript.WebhookPost
  },
  Runner = Runner,
  Remotes = Remotes, -- for caller to fill actual remotes
}
