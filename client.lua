local isUiOpen = false

local function Printing(...)
    if Config.Debugging then
        print(...)
    end
end

RegisterNuiCallback('ts-management:requestEmployeeList', function(data, cb)
    TriggerServerEvent("ts-management:requestEmployeeList")
    cb('ok')
end)

RegisterNuiCallback('ts-management:depositFunds', function(data, cb)
    TriggerServerEvent("ts-management:depositFunds", data.amount)
    cb('ok')
end)

RegisterNuiCallback('ts-management:withdrawFunds', function(data, cb)
    TriggerServerEvent("ts-management:withdrawFunds", data.amount)
    cb('ok')
end)

RegisterNuiCallback('ts-management:addPayBonus', function(data, cb)
    TriggerServerEvent("ts-management:addPayBonus", data.targetPlayerId, data.amount)
    cb('ok')
end)

RegisterNuiCallback('ts-management:subtractPayBonus', function(data, cb)
    TriggerServerEvent("ts-management:subtractPayBonus", data.targetPlayerId, data.amount)
    cb('ok')
end)

RegisterNuiCallback('ts-management:requestSocietyFunds', function(data, cb)
    TriggerServerEvent("ts-management:requestSocietyFunds")
    cb('ok')
end)

RegisterNuiCallback('ts-management:requestTransactionHistory', function(data, cb)
    TriggerServerEvent("ts-management:requestTransactionHistory")
    cb('ok')
end)

RegisterNuiCallback('ts-management:sendAnnouncement', function(data, cb)
    TriggerServerEvent("ts-management:sendAnnouncement", data.message)
    cb('ok')
end)

RegisterNuiCallback('ts-management:hireEmployee', function(data, cb)
    TriggerServerEvent("ts-management:hireEmployee", data.targetPlayerId, data.initialRank)
    cb('ok')
end)

RegisterNuiCallback('ts-management:requestNearbyPlayers', function(data, cb)
    TriggerServerEvent("ts-management:requestNearbyPlayers")
    cb('ok')
end)

RegisterNuiCallback('ts-management:requestJobRanks', function(data, cb)
    TriggerServerEvent("ts-management:requestJobRanks")
    cb('ok')
end)


RegisterNuiCallback('ts-management:closeUI', function(data, cb)
    SetNuiFocus(false, false)
    SendNuiMessage(json.encode({
        type = 'uiState',
        state = false
    }))
    isUiOpen = false
    cb('ok')
end)

RegisterNetEvent('ts-management:toggleUI')
AddEventHandler('ts-management:toggleUI', function(jobName)
    isUiOpen = not isUiOpen
    SetNuiFocus(isUiOpen, isUiOpen)
    SendNuiMessage(json.encode({
        type = 'uiState',
        state = isUiOpen,
        job = jobName
    }))
    if isUiOpen then
        TriggerServerEvent("ts-management:requestEmployeeList")
        TriggerServerEvent("ts-management:requestSocietyFunds")
        TriggerServerEvent("ts-management:requestTransactionHistory")
        TriggerServerEvent("ts-management:requestNearbyPlayers")
        TriggerServerEvent("ts-management:requestJobRanks")
    end
end)

RegisterNetEvent("ts-management:receiveEmployeeList")
AddEventHandler("ts-management:receiveEmployeeList", function(employees)
    SendNuiMessage(json.encode({
        type = 'updateEmployeeList',
        employees = employees
    }))
end)

RegisterNetEvent("ts-management:receiveSocietyFunds")
AddEventHandler("ts-management:receiveSocietyFunds", function(balance)
    SendNuiMessage(json.encode({
        type = 'updateSocietyFunds',
        balance = balance
    }))
end)
RegisterNetEvent("ts-management:receiveTransactionHistory")
AddEventHandler("ts-management:receiveTransactionHistory", function(history)
    SendNuiMessage(json.encode({
        type = 'updateTransactionHistory',
        history = history
    }))
end)

RegisterNetEvent("ts-management:receiveNearbyPlayers")
AddEventHandler("ts-management:receiveNearbyPlayers", function(players)
    SendNuiMessage(json.encode({
        type = 'updateNearbyPlayers',
        players = players
    }))
end)

RegisterNetEvent("ts-management:receiveJobRanks")
AddEventHandler("ts-management:receiveJobRanks", function(ranks)
    SendNuiMessage(json.encode({
        type = 'updateJobRanks',
        ranks = ranks
    }))
end)

RegisterNetEvent("ts-management:sendNuiNotification")
AddEventHandler("ts-management:sendNuiNotification", function(message, type)
    SendNuiMessage(json.encode({
        type = 'serverNotification',
        message = message,
        status = type
    }))
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isUiOpen then
            SetNuiFocus(false, false)
            SendNuiMessage(json.encode({
                type = 'uiState',
                state = false
            }))
            isUiOpen = false
        end
    end
end)
