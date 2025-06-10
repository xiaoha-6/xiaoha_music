Notify = {}

function Notify.Init()
    if Config.Framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
    elseif Config.Framework == 'qb' then
        QBCore = exports["qb-core"]:GetCoreObject()
    elseif Config.Framework == 'qbox' then
        QBX = exports['qbx_core']:GetCoreObject()
    end
end

function Notify.Show(source, message, type)
    if Config.Framework == 'esx' then
        TriggerClientEvent('esx:showNotification', source, message)
    elseif Config.Framework == 'qb' then
        TriggerClientEvent('QBCore:Notify', source, message, type)
    elseif Config.Framework == 'qbox' then
        TriggerClientEvent('QBCore:Notify', source, message, type)
    end
end

function Notify.Error(source, message)
    Notify.Show(source, message, 'error')
end

function Notify.Success(source, message)
    Notify.Show(source, message, 'success')
end

function Notify.Info(source, message)
    Notify.Show(source, message, 'info')
end

return Notify