local RewardType = {
  Points = 1,
  Experience = 2,
  Gold = 3,
  Item = 4,
  Storage = 5,
  Teleport = 6
}

local Config = {
  TasksOpCode = 110,
  StoragePoints = 87613,
  StorageSlot = 87614, -- 87615 - 87625 reserved (10)
  StorageKillsSelected = 87626, -- 87627 - 87637 reserved (10)
  StorageKillsCurrent = 87638, -- 87639 - 87649 reserved (10)
  ActiveTasksLimit = 3, -- max 10 or you will have to adjust storage keys
  RecommendedLevelRange = 10, -- when player is within this range (at level 20, 10-20 and 20-30 levels), "Recommended" text will be displayed in tasks list
  RequiredKills = {Min = 100, Max = 5000}, -- Minimum and Maximum amount of kills that player can select
  KillsForBonus = 100, -- every how many kills should bonus be applied (not counting minimum amount of kills)
  --[[
    % increased rank points gained per KillsForBonus kills
    If player selects to kill 100 Trolls, only base value is granted
    Selecting 200 kills grants base value + PointsIncrease%
    Default: 100
    Type: Percent
  ]]
  PointsIncrease = 100,
  --[[
    % increased experience points gained per KillsForBonus kills
    Default: 10
    Type: Percent
  ]]
  ExperienceIncrease = 10,
  --[[
    % increased gold coins gained per KillsForBonus kills
    Default: 10
    Type: Percent
  ]]
  GoldIncrease = 10,
  Party = {
    Enabled = true, -- should party members share kills
    Range = 8 -- party members in this range (tiles) will have task kill added, 0 to make it infinite range
  },
  Ranks = {
    [5] = "Huntsman",
    [15] = "Ranger",
    [30] = "Big Game Hunter",
    [45] = "Trophy Hunter",
    [60] = "Pro Hunter",
    [75] = "Elite Hunter"
  },
  Tasks = {
    --[[
      {
        RaceName = "Trolls", -- Name of the task
        Level = 8, -- Recommended level for this task (see RecommendedLevelRange)
        Monsters = {"Troll", "Troll Champion"}, -- List of monsters that count for the task, case-sensitive
        Rewards = {
          {Type = RewardType.Points, BaseValue = 1}, -- Adds rank points
          {Type = RewardType.Experience, BaseValue = 1000}, -- Gives experience
          {Type = RewardType.Gold, BaseValue = 500} -- Gives gold coins to bank
          {Type = RewardType.Item, Id = 2353, Amount = 1}, -- Rewards with 1 Burning Heart item
          {Type = RewardType.Storage, Key = 1234, Value = 1, Description = "Access to new hunting area"}, -- Sets storage 1234 with value 1
          {Type = RewardType.Teleport, Position = Position(1000, 1000, 7), Description = "Troll Boss fight"} -- Teleports to Position when task is completed
        }
      },
    ]]
    {
      RaceName = "Trolls",
      Level = 8,
      Monsters = {"Troll", "Frost Troll", "Swamp Troll"},
      Rewards = {
        {Type = RewardType.Points, BaseValue = 1},
        {Type = RewardType.Experience, BaseValue = 1000},
        {Type = RewardType.Gold, BaseValue = 500},
        {Type = RewardType.Item, Id = 2353, Amount = 1},
        {Type = RewardType.Storage, Key = 1234, Value = 1, Description = "Access to new hunting area"},
        {Type = RewardType.Teleport, Position = Position(1000, 1000, 7), Description = "Troll Boss fight"}
      }
    },
    {
      RaceName = "Rotworms",
      Level = 8,
      Monsters = {"Rotworm"},
      Rewards = {
        {Type = RewardType.Points, BaseValue = 1},
        {Type = RewardType.Experience, BaseValue = 1000},
        {Type = RewardType.Gold, BaseValue = 500}
      }
    },
    {
      RaceName = "Small Spiders",
      Level = 8,
      Monsters = {"Spider", "Poison Spider"},
      Rewards = {
        {Type = RewardType.Points, BaseValue = 1},
        {Type = RewardType.Experience, BaseValue = 1000},
        {Type = RewardType.Gold, BaseValue = 500}
      }
    },
    {
      RaceName = "Orcs",
      Level = 12,
      Monsters = {"Orc", "Orc Spearman", "Orc Shaman", "Orc Warrior", "Orc Rider"},
      Rewards = {
        {Type = RewardType.Points, BaseValue = 1},
        {Type = RewardType.Experience, BaseValue = 1500},
        {Type = RewardType.Gold, BaseValue = 800}
      }
    },
    {
      RaceName = "Minotaurs",
      Level = 12,
      Monsters = {"Minotaur", "Minotaur Archer", "Minotaur Mage", "Minotaur Guard"},
      Rewards = {
        {Type = RewardType.Points, BaseValue = 1},
        {Type = RewardType.Experience, BaseValue = 1500},
        {Type = RewardType.Gold, BaseValue = 800}
      }
    },
    {
      RaceName = "Dwarves",
      Level = 20,
      Monsters = {"Dwarf", "Dwarf Soldier", "Dwarf Guard", "Dwarf Geomancer"},
      Rewards = {
        {Type = RewardType.Points, BaseValue = 2},
        {Type = RewardType.Experience, BaseValue = 5000},
        {Type = RewardType.Gold, BaseValue = 1200}
      }
    },
    {
      RaceName = "Elves",
      Level = 25,
      Monsters = {"Elf", "Elf Scout", "Elf Arcanist"},
      Rewards = {
        {Type = RewardType.Points, BaseValue = 2},
        {Type = RewardType.Experience, BaseValue = 7000},
        {Type = RewardType.Gold, BaseValue = 1600}
      }
    },
  }
}

local Cache = {}

local StartupEvent = GlobalEvent("TasksStartUp")

function StartupEvent.onStartup()
  Cache.Ranks = {}
  local ordered = {}
  for key, _ in pairs(Config.Ranks) do
    table.insert(ordered, key)
  end
  table.sort(ordered)

  for i = 1, #ordered do
    local from = ordered[i]
    local to = i == #ordered and -1 or ordered[i + 1] - 1
    if to ~= -1 then
      for k = from, to do
        Cache.Ranks[k] = Config.Ranks[from]
      end
    else
      Cache.LastRank = from
    end
  end

  Cache.Tasks = {}
  for id, task in ipairs(Config.Tasks) do
    for _, name in ipairs(task.Monsters) do
      Cache.Tasks[name] = id
    end
  end
end

local LoginEvent = CreatureEvent("TasksLogin")

function LoginEvent.onLogin(player)
  player:registerEvent("TasksExtended")
  player:registerEvent("TasksKill")
  player:sendTasksData()
  return true
end

local ExtendedEvent = CreatureEvent("TasksExtended")

function ExtendedEvent.onExtendedOpcode(player, opcode, buffer)
  if opcode == Config.TasksOpCode then
    local status, json_data =
      pcall(
      function()
        return json.decode(buffer)
      end
    )
    if not status then
      return false
    end

    local action = json_data.action
    local data = json_data.data
    if action == "start" then
      player:startNewTask(data.taskId, data.kills)
    elseif action == "cancel" then
      player:cancelTask(data)
    end
  end
  return true
end

function Player:openTasksList()
  self:sendExtendedOpcode(Config.TasksOpCode, json.encode({action = "open"}))
end

function Player:closeTasksList()
  self:sendExtendedOpcode(Config.TasksOpCode, json.encode({action = "close"}))
end

function Player:sendTasksData()
  -- #region Send config
  local config = {
    kills = Config.RequiredKills,
    bonus = Config.KillsForBonus,
    range = Config.RecommendedLevelRange,
    points = Config.PointsIncrease,
    exp = Config.ExperienceIncrease,
    gold = Config.GoldIncrease
  }
  self:sendExtendedOpcode(Config.TasksOpCode, json.encode({action = "config", data = config}))
  -- #endregion

  -- #region Send tasks list
  local tasks = {}
  for _, task in ipairs(Config.Tasks) do
    if not task.Outfits then
      task.Outfits = {}
      for _, monster in ipairs(task.Monsters) do
        local monsterType = MonsterType(monster)
        if not monsterType then
          print("[Error] Tasks: Monster " .. monster .. " not found!")
        else
          table.insert(task.Outfits, monsterType:getOutfitOTC())
        end
      end
    end

    local taskData = {
      name = task.RaceName,
      lvl = task.Level,
      mobs = task.Monsters,
      outfits = task.Outfits,
      rewards = {}
    }

    for _, reward in ipairs(task.Rewards) do
      if reward.Type == RewardType.Points or reward.Type == RewardType.Experience or reward.Type == RewardType.Gold then
        table.insert(taskData.rewards, {type = reward.Type, value = reward.BaseValue})
      elseif reward.Type == RewardType.Item then
        table.insert(taskData.rewards, {type = reward.Type, name = ItemType(reward.Id):getName(), amount = reward.Amount})
      elseif reward.Type == RewardType.Storage or reward.Type == RewardType.Teleport then
        table.insert(taskData.rewards, {type = reward.Type, desc = reward.Description})
      end
    end

    table.insert(tasks, taskData)
  end

  local buffer = json.encode({action = "tasks", data = tasks})
  local s = {}
  for i = 1, #buffer, 8191 do
    s[#s + 1] = buffer:sub(i, i + 8191 - 1)
  end
  if #s == 1 then
    self:sendExtendedOpcode(Config.TasksOpCode, buffer)
  else
    self:sendExtendedOpcode(Config.TasksOpCode, "S" .. s[1])
    for i = 2, #s - 1 do
      self:sendExtendedOpcode(Config.TasksOpCode, "P" .. s[i])
    end
    self:sendExtendedOpcode(Config.TasksOpCode, "E" .. s[#s])
  end
  -- #endregion

  -- #region Send active tasks
  local active = {}
  for slot = 1, Config.ActiveTasksLimit do
    local taskId = self:getTaskIdBySlot(slot)
    if taskId ~= 0 then
      local requiredKills = self:getTaskRequiredKills(slot)
      local kills = self:getTaskKills(slot)
      table.insert(
        active,
        {
          kills = kills,
          required = requiredKills,
          slot = slot,
          taskId = taskId
        }
      )
    end
  end
  self:sendExtendedOpcode(Config.TasksOpCode, json.encode({action = "active", data = active}))
  -- #endregion

  self:sendTasksPointsUpdate()
end

function Player:sendTaskUpdate(taskId)
  local update = {}

  local slot = self:getSlotByTaskId(taskId)
  if not slot then
    update.status = 2 -- abandoned
    update.taskId = taskId
  else
    local requiredKills = self:getTaskRequiredKills(slot)
    local kills = self:getTaskKills(slot)

    if kills < requiredKills then
      update.status = 1 -- in progress
      update.kills = kills
      update.required = requiredKills
      update.taskId = taskId
    else
      update.status = 2 -- finished
      update.taskId = taskId
    end
  end

  self:sendExtendedOpcode(Config.TasksOpCode, json.encode({action = "update", data = update}))
end

function Player:sendTasksPointsUpdate()
  self:sendExtendedOpcode(Config.TasksOpCode, json.encode({action = "points", data = self:getTasksPoints()}))
end

function Player:startNewTask(taskId, kills)
  local task = Config.Tasks[taskId]
  if task then
    local slot = self:getFreeTaskSlot()
    if not slot then
      self:popupFYI("You can't accept more tasks.")
      return
    end

    if self:getSlotByTaskId(taskId) then
      self:popupFYI("You already have this task active.")
      return
    end

    kills = math.max(kills, Config.RequiredKills.Min)
    kills = math.min(kills, Config.RequiredKills.Max)

    self:setStorageValue(Config.StorageSlot + slot, taskId)
    self:setStorageValue(Config.StorageKillsCurrent + slot, 0)
    self:setStorageValue(Config.StorageKillsSelected + slot, kills)

    self:sendTaskUpdate(taskId)
  end
end

function Player:cancelTask(taskId)
  local task = Config.Tasks[taskId]
  if task then
    local slot = self:getSlotByTaskId(taskId)
    if slot then
      self:setStorageValue(Config.StorageSlot + slot, -1)
      self:setStorageValue(Config.StorageKillsCurrent + slot, -1)
      self:setStorageValue(Config.StorageKillsSelected + slot, -1)
      self:sendTaskUpdate(taskId)
    end
  end
end

local KillEvent = CreatureEvent("TasksKill")

function KillEvent.onKill(player, target)
  if not target or target:isPlayer() or target:getMaster() then
    return true
  end

  local taskId = Cache.Tasks[target:getName()]
  if taskId then
    local task = Config.Tasks[taskId]
    if task then
      local party = player:getParty()
      if party and Config.Party.Enabled then
        local members = party:getMembers()
        table.insert(members, party:getLeader())

        local killerPos = player:getPosition()
        for _, member in ipairs(members) do
          if Config.Party.Range > 0 then
            if member:getPosition():getDistance(killerPos) <= Config.Party.Range then
              member:taskProcessKill(taskId)
            end
          else
            member:taskProcessKill(taskId)
          end
        end
      else
        player:taskProcessKill(taskId)
      end
    end
  end

  return true
end

function Player:taskProcessKill(taskId)
  local slot = self:getSlotByTaskId(taskId)
  if slot then
    self:addTaskKill(slot)

    local requiredKills = self:getTaskRequiredKills(slot)
    local kills = self:getTaskKills(slot)
    if kills >= requiredKills then
      self:setStorageValue(Config.StorageSlot + slot, -1)
      self:setStorageValue(Config.StorageKillsCurrent + slot, -1)
      self:setStorageValue(Config.StorageKillsSelected + slot, -1)

      local task = Config.Tasks[taskId]
      for _, reward in ipairs(task.Rewards) do
        self:addTaskReward(reward, requiredKills)
      end
      self:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "[Task Status] You have finished " .. task.RaceName .. " task!")
    end
    self:sendTaskUpdate(taskId)
  end
end

function Player:addTaskReward(reward, requiredKills)
  local bonus = math.floor((math.max(0, requiredKills - Config.KillsForBonus) / Config.KillsForBonus) + 0.5)
  if reward.Type == RewardType.Points then
    bonus = bonus * Config.PointsIncrease
    local value = reward.BaseValue + math.floor((reward.BaseValue * bonus / 100) + 0.5)
    self:addTasksPoints(value)
    self:sendTextMessage(
      MESSAGE_STATUS_CONSOLE_ORANGE,
      "[Task Reward] Tasks Points +" .. value .. ", you have now " .. self:getTasksPoints() .. " tasks points."
    )
  elseif reward.Type == RewardType.Experience then
    bonus = bonus * Config.ExperienceIncrease
    local value = reward.BaseValue + math.floor((reward.BaseValue * bonus / 100) + 0.5)
    self:addExperience(value, true)
    self:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "[Task Reward] Experience +" .. value .. ".")
  elseif reward.Type == RewardType.Gold then
    bonus = bonus * Config.GoldIncrease
    local value = reward.BaseValue + math.floor((reward.BaseValue * bonus / 100) + 0.5)
    self:setBankBalance(self:getBankBalance() + value)
    self:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "[Task Reward] " .. value .. " gold added to your bank.")
  elseif reward.Type == RewardType.Item then
    local itemType = ItemType(reward.Id)
    local itemWeight = itemType:getWeight(reward.Amount)
    local playerCap = self:getFreeCapacity()
    if playerCap >= itemWeight then
      self:addItem(reward.Id, reward.Amount)
      self:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "[Task Reward] " .. reward.Amount .. "x " .. itemType:getName() .. ".")
    else
      self:getStoreInbox():addItem(reward.Id, reward.Amount)
      self:sendTextMessage(
        MESSAGE_STATUS_CONSOLE_ORANGE,
        "[Task Reward] Low on capacity, sending " .. reward.Amount .. "x " .. itemType:getName() .. " to your Purse."
      )
    end
  elseif reward.Type == RewardType.Storage then
    if self:getStorageValue(reward.Key) ~= reward.Value then
      self:setStorageValue(reward.Key, reward.Value)
      self:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, '[Task Reward] You have been granted "' .. reward.Description .. '".')
    end
  elseif reward.Type == RewardType.Teleport then
    self:teleportTo(reward.Position)
    self:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, '[Task Reward] You have been teleported to "' .. reward.Description .. '".')
  end
end

function Player:getTaskIdBySlot(slot)
  return math.max(0, self:getStorageValue(Config.StorageSlot + slot))
end

function Player:getSlotByTaskId(taskId)
  for i = 1, Config.ActiveTasksLimit do
    local slotTask = self:getTaskIdBySlot(i)
    if taskId == slotTask then
      return i
    end
  end

  return nil
end

function Player:getTaskKills(slot)
  return math.max(0, self:getStorageValue(Config.StorageKillsCurrent + slot))
end

function Player:getTaskRequiredKills(slot)
  return math.max(0, self:getStorageValue(Config.StorageKillsSelected + slot))
end

function Player:addTaskKill(slot)
  self:setStorageValue(Config.StorageKillsCurrent + slot, self:getTaskKills(slot) + 1)
end

function Player:addTasksPoints(points)
  self:setStorageValue(Config.StoragePoints, self:getTasksPoints() + points)
  self:sendTasksPointsUpdate()
end

function Player:getTasksPoints()
  return math.max(0, self:getStorageValue(Config.StoragePoints))
end

function Player:getTasksRank()
  local rank = self:getTasksPoints()
  if rank >= Cache.LastRank then
    return Cache.Ranks[Cache.LastRank]
  end

  return Cache.Ranks[rank]
end

function Player:getFreeTaskSlot()
  for i = 1, Config.ActiveTasksLimit do
    if self:getTaskIdBySlot(i) == 0 then
      return i
    end
  end

  return nil
end

function MonsterType:getOutfitOTC()
  local outfit = self:outfit()
  return {
    type = outfit.lookType,
    auxType = outfit.lookTypeEx,
    head = outfit.lookHead,
    body = outfit.lookBody,
    legs = outfit.lookLegs,
    feet = outfit.lookFeet,
    addons = outfit.lookAddons,
    mount = outfit.lookMount
  }
end

LoginEvent:type("login")
LoginEvent:register()
ExtendedEvent:type("extendedopcode")
ExtendedEvent:register()
KillEvent:type("kill")
KillEvent:register()
StartupEvent:type("startup")
StartupEvent:register()
