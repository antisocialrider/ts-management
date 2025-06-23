local QBCore = exports['qb-core']:GetCoreObject()

local function SendNuiNotification(src, message, type)
    TriggerClientEvent("ts-management:sendNuiNotification", src, message, type)
end

local function Printing(...)
    if Config.Debugging then
        print(...)
    end
end

local function HasBossPermission(source, jobName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or type(Player) ~= 'table' or
       not Player.PlayerData or type(Player.PlayerData) ~= 'table' or
       not Player.PlayerData.job or type(Player.PlayerData.job) ~= 'table' or
       not Player.PlayerData.job.grade or type(Player.PlayerData.job.grade) ~= 'table' or
       not Player.PlayerData.charinfo or type(Player.PlayerData.charinfo) ~= 'table' then
        SendNuiNotification(source, 'Permission Denied: Player data not fully loaded or invalid.', 'error')
        return false
    end

    if Player.PlayerData.job.name == jobName and Player.PlayerData.job.grade.isboss then
        return true, Player.PlayerData.job.name
    end
    SendNuiNotification(source, 'Permission Denied: You do not have boss permissions for this job.', 'error')
    return false
end

RegisterCommand("openksmanagement", function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        if Player.PlayerData then
            local hasPermission, jobName = HasBossPermission(source, Player.PlayerData.job.name)
            if hasPermission then
                TriggerClientEvent("ts-management:toggleUI", source, jobName)
            else
                SendNuiNotification(source, 'Access Denied: You are not a boss of any job.', 'error')
            end
        else
            SendNuiNotification(source, 'Access Denied: Your player data is not loaded.', 'error')
        end
    end
end, false)

local function ensureTablesExist()
    MySQL.Sync.execute([[
        CREATE TABLE IF NOT EXISTS `ts_society_funds` (
            `job_name` VARCHAR(50) NOT NULL PRIMARY KEY,
            `amount` DOUBLE NOT NULL DEFAULT '0'
        );
    ]])
    Printing('^2[ts-management]^7 Table `ts_society_funds` checked/created.')

    MySQL.Sync.execute([[
        CREATE TABLE IF NOT EXISTS `ts_transactions` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `job_name` VARCHAR(50) NOT NULL, -- NOT NULL
            `type` VARCHAR(50) NOT NULL,     -- NOT NULL
            `amount` DOUBLE NULL DEFAULT NULL,
            `initiator_cid` VARCHAR(50) NULL DEFAULT NULL,
            `initiator_name` VARCHAR(100) NULL DEFAULT NULL,
            `target_cid` VARCHAR(50) NULL DEFAULT NULL,
            `target_name` VARCHAR(100) NULL DEFAULT NULL,
            `reason` TEXT NULL DEFAULT NULL,
            `timestamp` BIGINT NOT NULL,     -- NOT NULL
            PRIMARY KEY (`id`),
            INDEX `job_name` (`job_name`)
        );
    ]])
    Printing('^2[ts-management]^7 Table `ts_transactions` checked/created.')
end

local function GetSocietyBalanceDB(jobName)
    Printing(string.format('^4DEBUG^7 [ts-management]: GetSocietyBalanceDB called for job: %s', jobName))
    local result = MySQL.Sync.fetchScalar('SELECT amount FROM ts_society_funds WHERE job_name = ?', { jobName })
    Printinging(string.format('^4DEBUG^7 [ts-management]: GetSocietyBalanceDB result for %s: %s (type: %s)', jobName, tostring(result), type(result)))

    if result == nil then
        Printing(string.format('^3WARNING^7 [ts-management]: No existing balance for %s. Inserting with 0.', jobName))
        local insertSuccess = MySQL.Sync.execute('INSERT INTO ts_society_funds (job_name, amount) VALUES (?, ?) ON DUPLICATE KEY UPDATE amount = amount', { jobName, 0 })
        Printing(string.format('^4DEBUG^7 [ts-management]: Inserted initial 0 balance for %s. Success: %s', jobName, tostring(insertSuccess)))
        return 0.00
    end
    return tonumber(result)
end

local function AddTransactionToDB(transactionData)
    Printing(string.format('^4DEBUG^7 [ts-management]: AddTransactionToDB called. Data:'))
    Printing(string.format('^4DEBUG^7 [ts-management]:   job_name: %s (type: %s)', tostring(transactionData.job_name), type(transactionData.job_name)))
    Printing(string.format('^4DEBUG^7 [ts-management]:   type: %s (type: %s)', tostring(transactionData.type), type(transactionData.type)))
    Printing(string.format('^4DEBUG^7 [ts-management]:   amount: %s (type: %s)', tostring(transactionData.amount), type(transactionData.amount)))
    Printing(string.format('^4DEBUG^7 [ts-management]:   initiator_cid: %s (type: %s)', tostring(transactionData.initiator_cid), type(transactionData.initiator_cid)))
    Printing(string.format('^4DEBUG^7 [ts-management]:   initiator_name: %s (type: %s)', tostring(transactionData.initiator_name), type(transactionData.initiator_name)))
    Printing(string.format('^4DEBUG^7 [ts-management]:   target_cid: %s (type: %s)', tostring(transactionData.target_cid), type(transactionData.target_cid)))
    Printing(string.format('^4DEBUG^7 [ts-management]:   target_name: %s (type: %s)', tostring(transactionData.target_name), type(transactionData.target_name)))
    Printing(string.format('^4DEBUG^7 [ts-management]:   reason: %s (type: %s)', tostring(transactionData.reason), type(transactionData.reason)))
    Printing(string.format('^4DEBUG^7 [ts-management]:   timestamp: %s (type: %s)', tostring(transactionData.timestamp), type(transactionData.timestamp)))

    MySQL.Sync.execute([[
        INSERT INTO ts_transactions (job_name, type, amount, initiator_cid, initiator_name, target_cid, target_name, reason, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        tostring(transactionData.job_name),
        tostring(transactionData.type),
        transactionData.amount,
        tostring(transactionData.initiator_cid),
        tostring(transactionData.initiator_name),
        transactionData.target_cid,
        transactionData.target_name,
        tostring(transactionData.reason),
        tonumber(transactionData.timestamp)
    })
    Printing('^4DEBUG^7 [ts-management]: AddTransactionToDB: MySQL.Sync.execute call completed.')
end

local function GetTransactionHistoryDB(jobName)
    local results = MySQL.Sync.fetchAll('SELECT * FROM ts_transactions WHERE job_name = ? ORDER BY timestamp DESC', { jobName })
    local history = {}
    for _, row in ipairs(results) do
        table.insert(history, {
            type = row.type,
            amount = tonumber(row.amount),
            initiator = row.initiator_name,
            initiatorCid = row.initiator_cid,
            targetPlayerName = row.target_name,
            targetPlayerCid = row.target_cid,
            timestamp = tonumber(row.timestamp) * 1000,
            reason = row.reason,
            job = row.job_name
        })
    end
    return history
end

RegisterNetEvent("ts-management:requestEmployeeList")
AddEventHandler("ts-management:requestEmployeeList", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(Player) ~= 'table' or not Player.PlayerData then
        Printing('^1ERROR^7 [ts-management]: requestEmployeeList called with invalid Player or PlayerData.')
        return
    end

    local hasPermission, jobName = HasBossPermission(src, Player.PlayerData.job.name)
    if not hasPermission then return end

    Printing(string.format('^4DEBUG^7 [ts-management]: Boss (%s) requesting employee list for job: %s', Player.PlayerData.citizenid, jobName))

    local jobEmployees = {}
    local onlineCids = {}

    Printing('^4DEBUG^7 [ts-management]: Checking online players...')
    for _, onlineSrcId in pairs(QBCore.Functions.GetPlayers()) do
        local onlinePlayer = QBCore.Functions.GetPlayer(onlineSrcId)
        if type(onlinePlayer) == 'table' and onlinePlayer.PlayerData and type(onlinePlayer.PlayerData) == 'table' and onlinePlayer.PlayerData.job and type(onlinePlayer.PlayerData.job) == 'table' and onlinePlayer.PlayerData.job.grade and type(onlinePlayer.PlayerData.job.grade) == 'table' and onlinePlayer.PlayerData.charinfo and type(onlinePlayer.PlayerData.charinfo) == 'table' then
            if onlinePlayer.PlayerData.job.name == jobName then
                table.insert(jobEmployees, {
                    id = onlinePlayer.PlayerData.citizenid,
                    name = onlinePlayer.PlayerData.charinfo.firstname .. " " .. onlinePlayer.PlayerData.charinfo.lastname,
                    rank = onlinePlayer.PlayerData.job.grade.name,
                    isOnline = true
                })
                onlineCids[onlinePlayer.PlayerData.citizenid] = true
                Printing(string.format('^4DEBUG^7 [ts-management]: Found online employee %s (%s) for job %s. Added to list as ONLINE.', onlinePlayer.PlayerData.firstname, onlinePlayer.PlayerData.citizenid, jobName))
            else
                Printing(string.format('^4DEBUG^7 [ts-management]: Skipping online player %s (%s) - not in job %s (current job: %s).', onlinePlayer.PlayerData.firstname, onlinePlayer.PlayerData.citizenid, jobName, onlinePlayer.PlayerData.job.name))
            end
        else
            Printing(("^3WARNING^7 [ts-management]: Skipping malformed online player object in employee list (Source ID: %s): %s"):format(tostring(onlineSrcId), tostring(onlinePlayer)))
        end
    end

    Printing('^4DEBUG^7 [ts-management]: Checking offline players from database...')
    local offlineResults = MySQL.Sync.fetchAll('SELECT citizenid, charinfo, job FROM players WHERE job LIKE ?', { '{"name":"' .. jobName .. '"%' })
    for _, offlineEmpData in ipairs(offlineResults) do
        local citizenid = offlineEmpData.citizenid
        if onlineCids[citizenid] then
            Printing(string.format('^4DEBUG^7 [ts-management]: Skipping offline DB entry for %s - already identified as ONLINE.', citizenid))
        else
            local charinfo = json.decode(offlineEmpData.charinfo)
            local job = json.decode(offlineEmpData.job)
            if charinfo and type(charinfo) == 'table' and job and type(job) == 'table' and job.name == jobName and job.grade and type(job.grade) == 'table' then
                table.insert(jobEmployees, {
                    id = citizenid,
                    name = charinfo.firstname .. " " .. charinfo.lastname,
                    rank = job.grade.name,
                    isOnline = false
                })
                Printing(string.format('^4DEBUG^7 [ts-management]: Found offline employee %s (%s) for job %s. Added to list as OFFLINE.', charinfo.firstname, citizenid, jobName))
            else
                Printing(("^3WARNING^7 [ts-management]: Skipping malformed offline player data for CID %s: %s"):format(citizenid, json.encode(offlineEmpData)))
            end
        end
    end

    Printing(string.format('^4DEBUG^7 [ts-management]: Sending %d employees to client.', #jobEmployees))
    TriggerClientEvent("ts-management:receiveEmployeeList", src, jobEmployees)
end)

RegisterNetEvent("ts-management:requestNearbyPlayers")
AddEventHandler("ts-management:requestNearbyPlayers", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.coords then
        SendNuiNotification(src, 'Error: Your player data or coordinates are not loaded. Please move to an open area and try again.', 'error')
        TriggerClientEvent("ts-management:receiveNearbyPlayers", src, {})
        return
    end

    local bossCoords = Player.PlayerData.coords
    local nearbyPlayers = {}

    local hireRadius = Config.HireRadius or 20.0

    for _, onlineSrcId in pairs(QBCore.Functions.GetPlayers()) do
        local onlinePlayer = QBCore.Functions.GetPlayer(onlineSrcId)
        if onlinePlayer and type(onlinePlayer) == 'table' and onlinePlayer.PlayerData and type(onlinePlayer.PlayerData) == 'table' and onlinePlayer.PlayerData.coords and type(onlinePlayer.PlayerData.coords) == 'table' and onlinePlayer.PlayerData.citizenid and onlinePlayer.PlayerData.charinfo then
            local targetCoords = onlinePlayer.PlayerData.coords
            local distance = #(vector3(bossCoords.x, bossCoords.y, bossCoords.z) - vector3(targetCoords.x, targetCoords.y, targetCoords.z))

            if onlinePlayer.PlayerData.citizenid ~= Player.PlayerData.citizenid and distance <= hireRadius then
                table.insert(nearbyPlayers, {
                    id = onlinePlayer.PlayerData.citizenid,
                    name = onlinePlayer.PlayerData.charinfo.firstname .. " " .. onlinePlayer.PlayerData.charinfo.lastname,
                    job = onlinePlayer.PlayerData.job.name
                })
            end
        end
    end
    TriggerClientEvent("ts-management:receiveNearbyPlayers", src, nearbyPlayers)
end)

RegisterNetEvent("ts-management:requestJobRanks")
AddEventHandler("ts-management:requestJobRanks", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then
        SendNuiNotification(src, 'Error: Your job data is not loaded.', 'error')
        return
    end

    local jobName = Player.PlayerData.job.name
    local availableRanks = {}

    if QBCore.Shared.Jobs[jobName] and QBCore.Shared.Jobs[jobName].grades then
        for gradeName, gradeData in pairs(QBCore.Shared.Jobs[jobName].grades) do
            if not gradeData.isboss then
                table.insert(availableRanks, {
                    name = gradeName,
                    label = gradeData.name
                })
            end
        end
        table.sort(availableRanks, function(a, b)
            local levelA = QBCore.Shared.Jobs[jobName].grades[a.name].level or 0
            local levelB = QBCore.Shared.Jobs[jobName].grades[b.name].level or 0
            return levelA < levelB
        end)
    end
    TriggerClientEvent("ts-management:receiveJobRanks", src, availableRanks)
end)


RegisterNetEvent("ts-management:requestSocietyFunds")
AddEventHandler("ts-management:requestSocietyFunds", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return end

    local hasPermission, jobName = HasBossPermission(src, Player.PlayerData.job.name)
    if not hasPermission then return end

    local balance = GetSocietyBalanceDB(jobName)
    TriggerClientEvent("ts-management:receiveSocietyFunds", src, balance)
end)

RegisterNetEvent("ts-management:requestTransactionHistory")
AddEventHandler("ts-management:requestTransactionHistory", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return end

    local hasPermission, jobName = HasBossPermission(src, Player.PlayerData.job.name)
    if not hasPermission then return end

    local history = GetTransactionHistoryDB(jobName)
    TriggerClientEvent("ts-management:receiveTransactionHistory", src, history)
end)

RegisterNetEvent("ts-management:depositFunds")
AddEventHandler("ts-management:depositFunds", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return end

    local hasPermission, jobName = HasBossPermission(src, Player.PlayerData.job.name)
    if not hasPermission then return end

    if amount <= 0 then
        SendNuiNotification(src, 'Deposit amount must be positive.', 'error')
        return
    end
    if Player.Functions.GetMoney('cash') >= amount then
        if Player.Functions.RemoveMoney('cash', amount) then
            local currentBalance = GetSocietyBalanceDB(jobName)
            local newBalance = currentBalance + amount

            local success = MySQL.Sync.execute('INSERT INTO ts_society_funds (job_name, amount) VALUES (?, ?) ON DUPLICATE KEY UPDATE amount = ?', { jobName, newBalance, newBalance })

            if not success then
                Printing(string.format('^1ERROR^7 [ts-management]: MySQL.Sync.execute failed in depositFunds: %s', tostring(success)))
                SendNuiNotification(src, 'Database update failed for deposit.', 'error')
                return
            end

            AddTransactionToDB({
                job_name = jobName,
                type = "deposit",
                amount = amount,
                initiator_cid = Player.PlayerData.citizenid,
                initiator_name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                target_cid = nil,
                target_name = nil,
                reason = "Player deposit to society",
                timestamp = os.time()
            })
            TriggerClientEvent("ts-management:receiveSocietyFunds", src, newBalance)
            TriggerClientEvent("ts-management:receiveTransactionHistory", src, GetTransactionHistoryDB(jobName))
            SendNuiNotification(src, 'Funds deposited successfully.', 'success')
        else
            SendNuiNotification(src, 'Failed to remove money from player.', 'error')
        end
    else
        SendNuiNotification(src, 'Insufficient cash to deposit.', 'error')
    end
end)

RegisterNetEvent("ts-management:withdrawFunds")
AddEventHandler("ts-management:withdrawFunds", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return end

    local hasPermission, jobName = HasBossPermission(src, Player.PlayerData.job.name)
    if not hasPermission then return end

    if amount <= 0 then
        SendNuiNotification(src, 'Withdrawal amount must be positive.', 'error')
        return
    end

    local currentBalance = GetSocietyBalanceDB(jobName)
    if currentBalance >= amount then
        local newBalance = currentBalance - amount
        
        local success = MySQL.Sync.execute('INSERT INTO ts_society_funds (job_name, amount) VALUES (?, ?) ON DUPLICATE KEY UPDATE amount = ?', { jobName, newBalance, newBalance })

        if not success then
            Printing(string.format('^1ERROR^7 [ts-management]: MySQL.Sync.execute failed in withdrawFunds: %s', tostring(success)))
            SendNuiNotification(src, 'Database update failed for withdrawal.', 'error')
            return
        end

        Player.Functions.AddMoney('cash', amount)

        AddTransactionToDB({
            job_name = jobName,
            type = "withdraw",
            amount = amount,
            initiator_cid = Player.PlayerData.citizenid,
            initiator_name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
            target_cid = nil,
            target_name = nil,
            reason = "Player withdrawal from society",
            timestamp = os.time()
        })
        TriggerClientEvent("ts-management:receiveSocietyFunds", src, newBalance)
        TriggerClientEvent("ts-management:receiveTransactionHistory", src, GetTransactionHistoryDB(jobName))
        SendNuiNotification(src, 'Funds withdrawn successfully.', 'success')
    else
        SendNuiNotification(src, 'Insufficient society funds.', 'error')
    end
end)

RegisterNetEvent("ts-management:sendAnnouncement")
AddEventHandler("ts-management:sendAnnouncement", function(message)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return end

    local hasPermission, jobName = HasBossPermission(src, Player.PlayerData.job.name)
    if not hasPermission then return end

    if not message or message == "" then
        SendNuiNotification(src, 'Announcement message cannot be empty.', 'error')
        return
    end

    Printing(string.format('^4DEBUG^7 [ts-management]: sendAnnouncement: Initiator JobName: %s (type: %s)', tostring(jobName), type(jobName)))
    Printing(string.format('^4DEBUG^7 [ts-management]: sendAnnouncement: Message: %s (type: %s)', tostring(message), type(message)))
    Printing(string.format('^4DEBUG^7 [ts-management]: sendAnnouncement: Initiator CID: %s (type: %s)', tostring(Player.PlayerData.citizenid), type(Player.PlayerData.citizenid)))
    Printing(string.format('^4DEBUG^7 [ts-management]: sendAnnouncement: Initiator Name: %s (type: %s)', tostring(Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname), type(Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname)))
    Printing(string.format('^4DEBUG^7 [ts-management]: sendAnnouncement: Current Timestamp: %s (type: %s)', tostring(os.time()), type(os.time())))


    for _, onlineSrcId in pairs(QBCore.Functions.GetPlayers()) do
        local v = QBCore.Functions.GetPlayer(onlineSrcId)
        if v and type(v) == 'table' and v.PlayerData and type(v.PlayerData) == 'table' and v.PlayerData.job and type(v.PlayerData.job) == 'table' and v.PlayerData.job.name == jobName then
            if v.Source and type(v.Source) == 'number' then
                Printing(string.format('^4DEBUG^7 [ts-management]: sendAnnouncement: Sending to player source: %s (type: %s)', tostring(v.Source), type(v.Source)))
                SendNuiNotification(v.Source, 'Job Announcement (' .. jobName .. '): ' .. message, 'info')
            else
                Printing(string.format('^3WARNING^7 [ts-management]: sendAnnouncement: Skipping player %s because v.Source is invalid (type: %s, value: %s)', tostring(onlineSrcId), type(v.Source), tostring(v.Source)))
            end
        end
    end
    SendNuiNotification(src, 'Announcement sent to all online ' .. jobName .. ' members.', 'success')
end)

RegisterNetEvent("ts-management:hireEmployee")
AddEventHandler("ts-management:hireEmployee", function(targetCitizenId, initialRank)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then
        SendNuiNotification(src, 'Error: Your player data is not loaded.', 'error')
        return
    end

    local hasPermission, jobName = HasBossPermission(src, Player.PlayerData.job.name)
    if not hasPermission then return end

    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    if not targetPlayer or type(targetPlayer) ~= 'table' or not targetPlayer.PlayerData then
        SendNuiNotification(src, 'Target player not found or offline. Please ensure they are online and nearby.', 'error')
        return
    end

    if targetPlayer.PlayerData.job.name ~= 'unemployed' then
        SendNuiNotification(src, 'Player is already employed.', 'error')
        return
    end

    if not QBCore.Shared.Jobs[jobName] or not QBCore.Shared.Jobs[jobName].grades[initialRank] then
        SendNuiNotification(src, 'Invalid rank specified for this job.', 'error')
        return
    end

    targetPlayer.Functions.SetJob(jobName, initialRank)
    SendNuiNotification(src, 'Employee hired: ' .. targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname .. '.', 'success')
    SendNuiNotification(targetPlayer.Source, 'You have been hired as a ' .. QBCore.Shared.Jobs[jobName].grades[initialRank].label .. ' in ' .. jobName .. '!', 'info')

    AddTransactionToDB({
        job_name = jobName,
        type = "hire",
        amount = nil,
        initiator_cid = Player.PlayerData.citizenid,
        initiator_name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
        target_cid = targetPlayer.PlayerData.citizenid,
        target_name = targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname,
        reason = "Hired as " .. QBCore.Shared.Jobs[jobName].grades[initialRank].label,
        timestamp = os.time()
    })

    TriggerServerEvent("ts-management:requestEmployeeList")
end)

RegisterNetEvent("ts-management:promoteEmployee")
AddEventHandler("ts-management:promoteEmployee", function(targetCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return end

    local hasPermission, jobName = HasBossPermission(src, Player.PlayerData.job.name)
    if not hasPermission then return end

    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    if not targetPlayer or type(targetPlayer) ~= 'table' or not targetPlayer.PlayerData or type(targetPlayer.PlayerData) ~= 'table' or targetPlayer.PlayerData.job.name ~= jobName then
        SendNuiNotification(src, 'Target employee not found, offline, or not in your job.', 'error')
        return
    end

    local currentGradeName = targetPlayer.PlayerData.job.grade.name
    local currentGradeLevel = targetPlayer.PlayerData.job.grade.level

    local nextGrade = nil
    local nextGradeName = nil
    local nextGradeLevel = -1

    if QBCore.Shared.Jobs[jobName] and QBCore.Shared.Jobs[jobName].grades then
        for gradeName, gradeData in pairs(QBCore.Shared.Jobs[jobName].grades) do
            if gradeData.level == currentGradeLevel + 1 then
                nextGrade = gradeData
                nextGradeName = gradeName
                nextGradeLevel = gradeData.level
                break
            end
        end
    end

    if not nextGrade then
        SendNuiNotification(src, 'Employee is already at the highest rank or next rank not found.', 'error')
        return
    end

    targetPlayer.Functions.SetJob(jobName, nextGradeName)
    SendNuiNotification(src, 'Promoted ' .. targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname .. ' to ' .. nextGrade.label .. '.', 'success')
    SendNuiNotification(targetPlayer.Source, 'You have been promoted to ' .. nextGrade.label .. ' in ' .. jobName .. '!', 'info')

    AddTransactionToDB({
        job_name = jobName,
        type = "promotion",
        amount = nil,
        initiator_cid = Player.PlayerData.citizenid,
        initiator_name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
        target_cid = targetPlayer.PlayerData.citizenid,
        target_name = targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname,
        reason = "Promoted to " .. nextGrade.label,
        timestamp = os.time()
    })

    TriggerServerEvent("ts-management:requestEmployeeList")
end)

RegisterNetEvent("ts-management:demoteEmployee")
AddEventHandler("ts-management:demoteEmployee", function(targetCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return end

    local hasPermission, jobName = HasBossPermission(src, Player.PlayerData.job.name)
    if not hasPermission then return end

    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    if not targetPlayer or type(targetPlayer) ~= 'table' or not targetPlayer.PlayerData or type(targetPlayer.PlayerData) ~= 'table' or targetPlayer.PlayerData.job.name ~= jobName then
        SendNuiNotification(src, 'Target employee not found, offline, or not in your job.', 'error')
        return
    end

    local currentGradeName = targetPlayer.PlayerData.job.grade.name
    local currentGradeLevel = targetPlayer.PlayerData.job.grade.level

    local prevGrade = nil
    local prevGradeName = nil
    local prevGradeLevel = -1

    if QBCore.Shared.Jobs[jobName] and QBCore.Shared.Jobs[jobName].grades then
        for gradeName, gradeData in pairs(QBCore.Shared.Jobs[jobName].grades) do
            if gradeData.level == currentGradeLevel - 1 then
                prevGrade = gradeData
                prevGradeName = gradeName
                prevGradeLevel = gradeData.level
                break
            end
        end
    end

    if not prevGrade then
        SendNuiNotification(src, 'Employee is already at the lowest rank or previous rank not found.', 'error')
        return
    end

    targetPlayer.Functions.SetJob(jobName, prevGradeName)
    SendNuiNotification(src, 'Demoted ' .. targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname .. ' to ' .. prevGrade.label .. '.', 'success')
    SendNuiNotification(targetPlayer.Source, 'You have been demoted to ' .. prevGrade.label .. ' in ' .. jobName .. '!', 'info')

    AddTransactionToDB({
        job_name = jobName,
        type = "demotion",
        amount = nil,
        initiator_cid = Player.PlayerData.citizenid,
        initiator_name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
        target_cid = targetPlayer.PlayerData.citizenid,
        target_name = targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname,
        reason = "Demoted to " .. prevGrade.label,
        timestamp = os.time()
    })

    TriggerServerEvent("ts-management:requestEmployeeList")
end)

RegisterNetEvent("ts-management:fireEmployee")
AddEventHandler("ts-management:fireEmployee", function(targetCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return end

    local hasPermission, jobName = HasBossPermission(src, Player.PlayerData.job.name)
    if not hasPermission then return end

    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    local targetPlayerName = "Unknown"
    local targetJobName = "Unknown"

    if targetPlayer and type(targetPlayer) == 'table' and targetPlayer.PlayerData and type(targetPlayer.PlayerData) == 'table' then
        targetPlayerName = targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname
        targetJobName = targetPlayer.PlayerData.job.name

        if targetJobName ~= jobName then
            SendNuiNotification(src, 'You can only fire employees from your own job.', 'error')
            return
        end

        targetPlayer.Functions.SetJob('unemployed', 0)
        SendNuiNotification(src, 'Fired ' .. targetPlayerName .. '.', 'success')
        SendNuiNotification(targetPlayer.Source, 'You have been fired from ' .. jobName .. ' by your boss (' .. Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ').', 'info')
    else
        local offlinePlayerData = MySQL.Sync.fetchAll('SELECT citizenid, charinfo, job FROM players WHERE citizenid = ?', { targetCitizenId })
        if offlinePlayerData and #offlinePlayerData > 0 then
            local charinfo = json.decode(offlinePlayerData[1].charinfo)
            local job = json.decode(offlinePlayerData[1].job)

            if charinfo and type(charinfo) == 'table' and job and type(job) == 'table' and job.name == jobName then
                targetPlayerName = charinfo.firstname .. " " .. charinfo.lastname
                targetJobName = job.name

                if targetJobName ~= jobName then
                    SendNuiNotification(src, 'You can only fire employees from your own job.', 'error')
                    return
                end
                MySQL.Sync.execute('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode({ name = 'unemployed', grade = { name = 'unemployed', level = 0, isboss = false, label = 'Unemployed' } }), targetCitizenId })
                SendNuiNotification(src, 'Fired offline employee ' .. targetPlayerName .. '.', 'success')
            else
                SendNuiNotification(src, 'Target employee data invalid or not found in your job.', 'error')
                return
            end
        else
            SendNuiNotification(src, 'Target employee not found.', 'error')
            return
        end
    end
    AddTransactionToDB({
        job_name = jobName,
        type = "fire",
        amount = nil,
        initiator_cid = Player.PlayerData.citizenid,
        initiator_name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
        target_cid = targetCitizenId,
        target_name = targetPlayerName,
        reason = "Fired from job",
        timestamp = os.time()
    })
    TriggerServerEvent("ts-management:requestEmployeeList")
end)

AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        ensureTablesExist()
    end
end)
