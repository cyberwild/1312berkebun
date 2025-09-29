-- Reconstructed Original Lua Script (Deobfuscated Approximation for Luraph v14.4.2)
-- This is the closest to 100% original based on decoded strings and logic patterns.
-- Features: Auto buy eggs, ESP for objects/pets, auto water fruits, auto collect fruits/mutations, favorite items, pet gifting, server hop, etc.
-- Note: Bitwise operations and truncated parts are approximated; run JAR tools locally for full deobfuscation.

local bit32 = require("bit32")  -- Assuming Roblox LuaU environment

-- Constants (approximated from bitwise patterns like s.W[0X8], etc.)
local constants = { [0] = 0, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [7] = 7, [8] = 8, [9] = 9 }  -- Placeholder for s.W array

-- Aliases from script
local rrotate = bit32.rrotate
local unpack = string.unpack
local bor = bit32.bor
local countlz = bit32.countlz  -- Assuming countrz is countlz (typo in original?)

-- Function OL (Set table values)
local function setTableValues(t1, t2, val1, val2)
    t1[1][34], t1[1][9] = val1, val2
end

-- Function kw (Calculation with conditions)
local function calculateValue(obj, param1, param2, param3)
    param3[18] = nil
    if not param2[13775] then
        param2[10466] = -3515534763 + ((bor((bor(obj.constants[5])), obj.constants[8], obj.constants[8])) + obj.constants[9] == param2[0x9fa] and param2[0x9fa] or obj.constants[6])
        param1 = -0xC746984 + (((countlz(obj.constants[7])) - param2[0x1111] ~= obj.constants[4] and obj.constants[8] or obj.constants[8]) - param2[0xFCE])
        param2[13775] = param1
    else
        param1 = param2[13775]
    end
    return param1
end

-- Function q (Auto buy best egg)
local function autoBuyBestEgg(config)
    local services = config[1]
    local utils = config[2]
    local ui = config[0]
    return function()
        local stock = utils.GetStockGeneric(ui.PetShop_UI.Frame.ScrollingFrame, "Best", "no")
        if stock then
            services.BuyPetEgg:FireServer(stock)
        end
    end
end

-- Function I (ESP for objects like eggs)
local function objectESP(config)
    local services = config[1]
    local player = config[2]
    local ui = config[0]
    local esp = config[3]
    return function()
        local path = services.GetFarmPath("Objects_Physical")
        if not path then return end
        local data = services.DataClient.GetSaved_Data()
        if not data then return end
        for _, obj in ipairs(path:GetChildren()) do
            pcall(function()
                if obj:GetAttribute("OWNER") == player.Name and obj:GetAttribute("READY") and obj:GetAttribute("TimeToHatch") <= 0 then
                    local uuid = obj:GetAttribute("OBJECT_UUID")
                    local objData = data[uuid]
                    if objData then
                        local entry = objData.Data
                        local type = entry.Type
                        local baseWeight = entry.BaseWeight
                        local currentWeight = services.Calculator.CurrentWeight(baseWeight, 1)
                        local formatted = ui:DecimalNumberFormat(currentWeight)
                        local category = (currentWeight > 9 and "Titanic") or (currentWeight >= 6 and "Semi Titanic") or (currentWeight > 3 and "Huge") or "Small"
                        if type and formatted then
                            esp.CreateESP(obj, {
                                Color = Color3.fromRGB(255, 255, 255),
                                Text = string.format("<font color='rgb(3,211,252)'>%s</font>\n<font color='rgb(255,215,0)'>%s</font>\n<font color='rgb(100,255,100)'>%s (%s)</font>", 
                                    tostring(obj:GetAttribute("EggName")), type, tostring(formatted) .. " KG" or "N/A", category)
                            })
                        end
                    end
                end
            end)
        end
        task.wait(1)
    end
end

-- Function o (ESP for pets)
local function petESP(config)
    local player = config[4]
    local esp = config[3]
    local settings = config[1]
    local data = config[0]
    local ui = config[2]
    return function()
        local path = workspace:FindFirstChild('PetsPhysical')
        if not path then return end
        for _, pet in ipairs(path:GetChildren()) do
            pcall(function()
                if pet:GetAttribute('OWNER') == player.Name then
                    local uuid = pet:GetAttribute('UUID')
                    if uuid then
                        local instance = ui:FindFirstChild(uuid, true)
                        local type = instance and instance:FindFirstChild("PET_TYPE", true).Text or "N/A"
                        local selected = settings['Select Pets ESP']
                        if table.find(selected, "All") or table.find(selected, type .. " " .. uuid) then
                            local existingEsp = pet:FindFirstChild('ESP')
                            local timeInfo = data:GetPetTime(uuid)
                            local time = timeInfo and timeInfo.Result or 'N/A'
                            local passive = timeInfo and timeInfo.Passive and timeInfo.Passive[1] or 'N/A'
                            local mutation = data:GetPetMutationName(type) or 'N/A'
                            if not existingEsp then
                                esp.CreateESP(pet, {
                                    Color = Color3.fromRGB(92,247,240),
                                    Text = "Pets: " .. type .. "\nTime: " .. time .. '\n Passive: ' .. passive .. "\nMutation: " .. mutation .. '\n\n'
                                })
                            else
                                local billboard = existingEsp:FindFirstChild("BillboardGui", true)
                                local label = billboard and billboard:FindFirstChild("TextLabel")
                                if label then
                                    label.Text = "Pets: " .. type .. '\nTime: ' .. time .. "\n Passive: " .. passive .. "\nMutation: " .. mutation .. "\n"
                                end
                            end
                        end
                    end
                end
            end)
        end
        task.wait(2)
    end
end

-- Function F (Auto water fruits)
local function autoWaterFruits(config)
    local settings = config[1]
    local player = config[0]
    local utils = config[2]
    local remotes = config[3]
    return function()
        local delay = settings['Delay to Water '] or 0.1
        task.wait(delay)
        local path = utils.GetFarmPath('Plants_Physical')
        if not path then return end
        local tool = player.Character:FindFirstChildWhichIsA('Tool')
        for _, plant in ipairs(path:GetChildren()) do
            if not settings['Auto Water Fruits'] then break end
            if not (tool and tool.Name:match("Watering Can")) then break end
            if plant:IsA('Model') and table.find(settings['Select Water Fruits'], plant.Name) then
                remotes.Water_RE:FireServer(plant:GetPivot().Position)
                task.wait(0.15)
            end
        end
    end
end

-- Function u (Auto collect whitelisted fruits)
local function autoCollectWhitelistedFruits(config)
    local player = config[0]
    local utils = config[3]
    local remotes = config[2]
    local services = config[1]
    local crops = config[4]
    return function()
        local list = utils.GetPlantList(remotes.GetFarmPath('Plants_Physical'), {})
        local whitelist = player["Select Whitelist Fruit"]
        local filters = {whitelist, {}, {}}
        local count = 0
        for i = 1, #list do
            if not player["Auto Collect Whitelisted Fruits"] then break end
            if player["Stop Collect If Backpack Is Full Max"] and services.IsMaxInventory() then break end
            local plant = list[i]
            if not plant:GetAttribute('Favorited') and remotes.FruitFilter(filters, plant) then
                if not player["Instant Collect"] then
                    task.wait(player['Delay To Collect'] or 0)
                end
                crops.Crops.Collect:FireServer({plant})
                count = count + 1
                if not player["Instant Collect"] then
                    task.wait(0.02)
                end
                if player["Instant Collect"] and count > 50 then break end
            end
        end
        task.wait(1)
    end
end

-- Function G (Auto collect all fruits)
local function autoCollectAllFruits(config)
    local utils = config[2]
    local settings = config[1]
    local services = config[5]
    local remotes = config[0]
    local weather = config[4]
    local data = config[3]
    return function()
        if settings['Stop Collect If Weather Is Here'] and weather:IsWeather() then return end
        local list = data.GetPlantList(utils.GetFarmPath('Plants_Physical'), {})
        if #list == 0 then return end
        local count = 0
        for i = 1, #list do
            if not settings['Auto Collect All Fruits'] then break end
            if settings["Stop Collect If Backpack Is Full Max"] and services.IsMaxInventory() then break end
            local plant = list[i]
            if not plant:GetAttribute("Favorited") then
                if not settings["Instant Collect"] then
                    task.wait(settings['Delay To Collect'] or 0)
                end
                remotes.Crops.Collect:FireServer({plant})
                count = count + 1
                if not settings["Instant Collect"] then
                    task.wait(0.02)
                end
                if settings['Instant Collect'] and count > 50 then break end
            end
        end
        task.wait(1)
    end
end

-- Function K (Auto collect whitelisted mutations)
local function autoCollectWhitelistedMutations(config)
    local services = config[3]
    local settings = config[0]
    local utils = config[2]
    local crops = config[4]
    local remotes = config[1]
    return function()
        local list = crops.GetPlantList(utils.GetFarmPath("Plants_Physical"), {})
        local whitelist = settings['Select Whitelist Mutations']
        local filters = {{}, whitelist, {}}
        local count = 0
        for i = 1, #list do
            if not settings[" Auto Collect  W hite  listed Mutations"] then break end
            if settings['Stop Collect If   Backpack Is Full Max'] and services.IsMaxInventory() then break end
            local plant = list[i]
            if not plant:GetAttribute("Favorited") and utils.FruitFilter(filters, plant) then
                if not settings['Instant Collect'] then
                    task.wait(settings['Delay To Collect'] or 0)
                end
                remotes.Crops.Collect:FireServer({plant})
                count = count + 1
                if not settings['Instant Collect'] then
                    task.wait(0.02)
                end
                if settings["Instant Collect"] and count > 50 then break end
            end
        end
        task.wait(1)
    end
end

-- Function s (Auto open crates)
local function autoOpenCrates(config)
    local player = config[0]
    local remotes = config[2]
    local utils = config[1]
    local name = config[3]
    return function()
        local path = utils.GetFarmPath('Objects_Physical')
        if not path then return end
        local data = utils.DataClient.GetSaved_Data()
        if not data then return end
        for _, crate in ipairs(path:GetChildren()) do
            if crate:GetAttribute("OWNER") == name.Name and crate:GetAttribute("Crate Type") and crate:GetAttribute("TimeToOpen") <= 0 then
                local uuid = crate:GetAttribute('OBJECT_UUID')
                local entry = data[uuid]
                if entry then
                    local dataEntry = entry.Data
                    local type = dataEntry.CosmeticType
                    if table.find(player["Select Items "], type) then
                        remotes.CosmeticCrateService:FireServer("OpenCrate", crate)
                        return
                    end
                end
            end
        end
        task.wait(2)
    end
end

-- Function Q (Auto favorite items by thresholds)
local function autoFavoriteItems(config)
    local player = config[0]
    local settings = config[1]
    local remotes = config[3]
    local utils = config[2]
    return function()
        local backpack = utils:FindFirstChild('Backpack')
        if not backpack then return end
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA('Tool') and not item:GetAttribute("d") then
                local weightPart = item:FindFirstChild('Weight')
                local threshold = settings["Threshold Weight   "]
                local mode = settings["Threshold Weig  ht Mode  "]
                local noWeight = not weightPart or not threshold or threshold == "" or threshold == 0
                local valid = noWeight or (mode == 'Above' and weightPart.Value > threshold) or (weightPart.Value < threshold)
                if remotes.FruitFilter({settings["Select Fruits Favourite"], settings["Select Mutations Favorite"], settings['  Se lec t Va riant Favorite']}, item) and valid then
                    player.Favorite_Item:FireServer(item)
                end
            end
        end
        task.wait(1)
    end
end

-- Function k (Auto give pets to players)
local function autoGivePets(config)
    local settings = config[2]
    local remotes = config[3]
    local player = config[0]
    local services = config[1]
    local ui = config[4]
    return function()
        local delay = tonumber(settings["Delay To Give"]) or 0.1
        if not settings:Expired("Auto Give Pet To Players") then return end
        settings:Set("Auto Give Pets To Players", delay)
        local target = ui and ui:FindFirstChild(settings['Select Players'])
        if not target then return end
        local character = services.Character
        if not character then return end
        local selectedPets = settings['Choose Pets']
        local ageThreshold = tonumber(settings["Age Threshold   "]) or 0
        local weightThreshold = tonumber(settings["Weights Threshold   "]) or 0
        local mode = settings["Select Threshold Mode   "]
        for _, pet in ipairs(services.Backpack:GetChildren()) do
            if pet:IsA('Tool') and not pet:GetAttribute('\d') then
                local name = pet.Name:gsub("%b[]",''):gsub("^%s*(.-)%s *$",'%1')
                if table.find(selectedPets, name) then
                    local weight = tonumber(pet.Name:match('%[(.-) KG% ]') or "")
                    local age = tonumber(pet.Name:match('%[Age (%d+) %\]') or "")
                    local validWeight = weightThreshold == 0 or (weight and (mode == 'Above' and weight > weightThreshold or weight < weightThreshold))
                    local validAge = ageThreshold == 0 or (age and (mode == "Above" and age > ageThreshold or age < ageThreshold))
                    if validWeight and validAge then
                        repeat task.wait() character.Humanoid:EquipTool(pet) until character:FindFirstChild(pet.Name)
                        local equipped = character:FindFirstChild(pet.Name)
                        if equipped then
                            player.PetGiftingService:FireServer('GivePet', target)
                            break
                        end
                    end
                end
            end
        end
    end
end

-- Function U (Auto buy normal egg)
local function autoBuyNormalEgg(config)
    local services = config[1]
    local player = config[0]
    local ui = config[2]
    local utils = config[3]
    return function()
        local stock = utils.GetStockGeneric(ui.PetShop_UI.Frame.ScrollingFrame, "Normal", player['Select Eggs '])
        if stock then
            services.BuyPetEgg:FireServer(stock)
        end
    end
end

-- Function j (Server hop/rejoin logic)
local function serverHop(config)
    local settings = config[6]
    local player = config[2]
    local services = config[4]
    local data = config[5]
    local game = config[1]
    local hop = config[3]
    local teleport = config[0]
    return function()
        task.delay(player['Delay To Rejoin'] or 20, function()
            if player["Private Server Mode"] and services.IsPrivateServer() then
                if #game:GetPlayers() == 1 then
                    settings[1][settings[3]]:SetNotification({'Speed Hub X', "", 'Your private server has only 1 player. Please get more players by using an alt or inviting a friend.', 5, 0.5})
                    task.wait(10)
                else
                    teleport:Teleport(game.PlaceId, data)
                end
            else
                if #game:GetPlayers() >= game.MaxPlayers then
                    local success, err = pcall(teleport.Teleport, teleport, game.PlaceId)
                    if not success then
                        hop:HopServer()
                    end
                else
                    pcall(teleport.Teleport, teleport, game.PlaceId)
                end
            end
        end)
    end
end

-- Function jy (Entry point, approximated as main initializer)
local function mainEntry(obj)
    local tables = ({})
    tables = obj:Initialize(tables, tables)  -- Kw, Ow, Pw, etc. (truncated, approximated)
    -- Loop for setup (repeat until false, truncated)
    -- Calls like Cw, Mw, ow, Vw, Dw, DL, LL, etc.
    -- Returns main table[38](x, P) - assumed main executor
end

-- Other truncated functions (xL, mL, KL, etc.) approximated as internal loops/calculations
-- xL: Seems like conditional branching and table setup
-- mL: Loop with KL for processing
-- KL: Conditional returns with calculations
-- Etc. - These are internal VM handlers, need JAR for full devirtualization

-- Usage (approximated entry)
mainEntry({constants = constants}) -- Start the script
