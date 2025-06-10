Config = {}

-- Framework configuration
Config.Framework = {
    -- Set to 'auto' for automatic detection, or specify: 'qb', 'esx', etc.
    type = 'auto',
    
    -- Framework definitions
    definitions = {
        ['qb'] = {
            name = 'qb-core',
            getCore = function()
                return exports['qb-core']:GetCoreObject()
            end,
            getPlayerData = function(core)
                if core then
                    return core.Functions.GetPlayerData()
                end
                return nil
            end,
            notify = function(message, type)
                local QBCore = exports['qb-core']:GetCoreObject()
                if QBCore then
                    QBCore.Functions.Notify(message, type)
                end
            end
        },
        ['esx'] = {
            name = 'es_extended',
            getCore = function()
                return exports['es_extended']:getSharedObject()
            end,
            getPlayerData = function(core)
                if core then
                    return core.GetPlayerData()
                end
                return nil
            end,
            notify = function(message, type)
                TriggerEvent('esx:showNotification', message)
            end
        },
        -- Add more frameworks here
        ['custom'] = {
            name = 'custom-framework',
            getCore = function()
                -- Add custom framework core getter
                return nil
            end,
            getPlayerData = function(core)
                -- Add custom player data getter
                return nil
            end,
            notify = function(message, type)
                -- Add custom notification function
            end
        }
    },

    -- Auto detect framework
    detect = function()
        -- 尝试检测 QB Core
        local success, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if success and core then
            return 'qb'
        end

        -- 尝试检测 ESX
        success, core = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if success and core then
            return 'esx'
        end

        return nil
    end,

    -- Get current framework
    getCurrent = function()
        local fwType = Config.Framework.type
        if fwType == 'auto' then
            fwType = Config.Framework.detect()
        end
        
        if fwType then
            return Config.Framework.definitions[fwType]
        end
        
        print("No framework detected or configured!")
        return nil
    end
}

-- Target system configuration
Config.Target = {
    -- Set to 'auto' for automatic detection, or specify: 'ox_target', 'qb-target', etc.
    type = 'auto',
    
    -- Target system definitions
    definitions = {
        ['ox_target'] = {
            name = 'ox_target',
            isAvailable = function()
                return GetResourceState('ox_target') == 'started'
            end,
            addZone = function(data)
                return exports['ox_target']:addSphereZone({
                    coords = data.coords,
                    radius = data.radius or 1.5,
                    debug = data.debug,
                    options = {
                        {
                            name = 'dj_table_' .. data.name,
                            label = data.label,
                            icon = 'music',
                            onSelect = data.onSelect,
                            canInteract = data.canInteract
                        }
                    },
                    distance = data.distance or 2.5
                })
            end
        },
        ['qb-target'] = {
            name = 'qb-target',
            isAvailable = function()
                return GetResourceState('qb-target') == 'started'
            end,
            addZone = function(data)
                local jobList = nil
                if data.enableJobCheck then
                    jobList = {}
                    for jobName, _ in pairs(data.allowedJobs) do
                        jobList[jobName] = 0
                    end
                end

                return exports['qb-target']:AddCircleZone(
                    "dj_table_" .. data.name,
                    data.coords,
                    data.radius or 1.5,
                    {
                        name = "dj_table_" .. data.name,
                        debugPoly = data.debug,
                        useZ = true
                    },
                    {
                        options = {
                            {
                                type = "client",
                                event = "openDJTable",
                                icon = "fas fa-music",
                                label = data.label,
                                djTableId = data.name,
                                job = jobList
                            }
                        },
                        distance = data.distance or 2.5
                    }
                )
            end
        },
        -- Add more target systems here
        ['custom_target'] = {
            name = 'custom-target',
            isAvailable = function()
                -- Add custom availability check
                return false
            end,
            addZone = function(data)
                -- Add custom zone creation logic
            end
        }
    },

    -- Auto detect target system
    detect = function()
        local systems = Config.Target.definitions
        for sysType, sys in pairs(systems) do
            if sys.isAvailable() then
                return sysType
            end
        end
        return nil
    end,

    -- Get current target system
    getCurrent = function()
        local targetType = Config.Target.type
        if targetType == 'auto' then
            targetType = Config.Target.detect()
        end
        
        if targetType then
            return Config.Target.definitions[targetType]
        end
        
        print("No target system detected or configured!")
        return nil
    end,

    -- Add zone wrapper function
    addZone = function(data)
        local targetSystem = Config.Target.getCurrent()
        if not targetSystem then
            print("Error: No target system available")
            return false
        end

        return targetSystem.addZone(data)
    end
}

-- Debug options
Config.Debug = {
    ShowTargetZone = false,     -- 显示目标区域
    ShowQbZone = false,         -- QB target 调试
    EnablePrints = true,       -- 启用打印调试信息
    EnableNUIDebug = false,     -- 启用 NUI/HTML 调试
    -- 新增调试选项
    Levels = {
        None = 0,               -- 禁用所有调试输出
        Error = 1,              -- 只显示错误
        Warning = 2,            -- 显示警告和错误
        Info = 3,              -- 显示一般信息、警告和错误
        Debug = 4              -- 显示所有调试信息
    },
    CurrentLevel = 4,          -- 当前调试级别
}

-- 全局歌词显示设置
Config.Lyrics = {
    Enabled = true,             -- 全局开关，控制是否启用歌词显示功能
    BackgroundEnabled = true,   -- 是否显示歌词背景
    DefaultScale = 1.0,         -- 默认字体大小
    DefaultFont = 0,            -- 默认字体样式 (0-9)
}

-- 添加调试打印函数
Config.Debug.Print = function(message, level, target)
    level = level or Config.Debug.Levels.Info
    target = target or 'server' -- 'server' 或 'nui'
    
    -- 检查是否启用了相应的调试输出
    if target == 'nui' and not Config.Debug.EnableNUIDebug then
        return
    elseif target == 'server' and not Config.Debug.EnablePrints then
        return
    end
    
    if level > Config.Debug.CurrentLevel then
        return
    end
    
    local prefix = ""
    if level == Config.Debug.Levels.Error then
        prefix = "^1[ERROR]^7 "
    elseif level == Config.Debug.Levels.Warning then
        prefix = "^3[WARNING]^7 "
    elseif level == Config.Debug.Levels.Info then
        prefix = "^2[INFO]^7 "
    elseif level == Config.Debug.Levels.Debug then
        prefix = "^5[DEBUG]^7 "
    end
    
    if target == 'nui' then
        SendNUIMessage({
            action = 'debug',
            level = level,
            message = message,
            prefix = prefix
        })
    else
        print(prefix .. message)
    end
end

-- Notification system configuration
Config.NotifySystem = {
    -- Set to 'auto' to follow framework, or specify: 'qb', 'esx', 'custom', etc.
    type = 'auto',
    
    -- Notification system definitions
    definitions = {
        ['qb'] = {
            name = 'qb-core',
            notify = function(message, type)
                local QBCore = exports['qb-core']:GetCoreObject()
                if QBCore then
                    QBCore.Functions.Notify(message, type)
                end
            end
        },
        ['esx'] = {
            name = 'es_extended',
            notify = function(message, type)
                TriggerEvent('esx:showNotification', message)
            end
        },
        ['ox'] = {
            name = 'ox_lib',
            notify = function(message, type)
                exports['ox_lib']:notify({
                    title = 'DJ System',
                    description = message,
                    type = type
                })
            end
        },
        ['mythic'] = {
            name = 'mythic_notify',
            notify = function(message, type)
                exports['mythic_notify']:DoHudText(type, message)
            end
        },
        ['custom'] = {
            name = 'custom-notify',
            notify = function(message, type)
                -- Add your custom notification logic here
                -- Example:
                -- exports['your-notify']:ShowNotification(message, type)
            end
        }
    },

    -- Auto detect notification system based on framework
    detect = function()
        if Config.Framework.type ~= 'auto' then
            -- 如果框架是手动指定的，返回对应的通知系统
            return Config.Framework.type
        end

        -- 检测已安装的通知系统
        if GetResourceState('ox_lib') == 'started' then
            return 'ox'
        elseif GetResourceState('mythic_notify') == 'started' then
            return 'mythic'
        end

        -- 如果没有找到独立的通知系统，使用框架自带的
        local framework = Config.Framework.detect()
        if framework then
            return framework
        end

        return nil
    end,

    -- Get current notification system
    getCurrent = function()
        local notifyType = Config.NotifySystem.type
        if notifyType == 'auto' then
            notifyType = Config.NotifySystem.detect()
        end
        
        if notifyType then
            return Config.NotifySystem.definitions[notifyType]
        end
        
        Config.Debug.Print("No notification system detected or configured!", Config.Debug.Levels.Warning)
        return nil
    end,

    -- Send notification wrapper function
    send = function(message, type)
        local notifySystem = Config.NotifySystem.getCurrent()
        if notifySystem then
            notifySystem.notify(message, type)
        else
            -- 如果没有可用的通知系统，使用基础的聊天消息
            TriggerEvent('chat:addMessage', {
                color = { 255, 0, 0 },
                multiline = true,
                args = { 'DJ System', message }
            })
        end
    end
}

-- 定义通知函数
Config.Notify = function(message, type)
    Config.NotifySystem.send(message, type)
end

-- DJ Booth Models Configuration
Config.DJBoothModels = {
    default = {
        booth = 'h4_prop_battle_dj_deck_01a_a'  -- DJ台模型
    }
}

-- DJ Tables configuration
Config.DJTables = {
    {
        name = "galaxy_club",
        coords = vec3(120.13, -1281.67, 29.00),
        label = "银河俱乐部DJ台",
        interactionRange = 2.5,
        musicRange = 25.0,
        volume = {
            min = 0.0,
            max = 0.8,
            default = 0.5
        },
        enableJobCheck = true,
        allowedJobs = {
            ["police"] = true
        },
        enableParticleEffect = true, -- 启用粒子特效
        models = {
            booth = 'h4_prop_battle_dj_deck_01a_a'
        },
        -- 歌词显示配置
        lyricsEnabled = true,   -- 此DJ台是否启用歌词显示
        lyricsHeight = 0.5, -- DJ台上方高度
        lyricsOffsetX = 0.0, -- X轴偏移
        lyricsOffsetY = 0.0, -- Y轴偏移
        lyricsFont = 0, -- 字体样式 (0-9)
        lyricsScale = 1.0, -- 文本大小调整为适中
        lyricsCoords = vector3(120.13, -1281.67, 30.10) -- 直接指定歌词显示坐标，高度提高
    },
    {
        name = "vanilla_club",
        coords = vector3(-582.86, -1050.79, 22.34),
        label = "香草俱乐部DJ台",
        interactionRange = 2.5,
        musicRange = 25.0,
        volume = {
            min = 0.0,
            max = 0.7,
            default = 0.4
        },
        enableJobCheck = true,
        allowedJobs = {
            ["uwu"] = true
        },
        enableParticleEffect = false, -- 禁用粒子特效
        models = {
            booth = 'h4_prop_battle_dj_deck_01a_a'
        },
        -- 歌词显示配置
        lyricsEnabled = true,   -- 此DJ台是否启用歌词显示
        lyricsHeight = 0.5, -- DJ台上方高度
        lyricsOffsetX = 0.0, -- X轴偏移
        lyricsOffsetY = 0.0, -- Y轴偏移
        lyricsFont = 0, -- 字体样式 (0-9)
        lyricsScale = 1.0, -- 文本大小调整为适中
        lyricsCoords = vector3(-582.86, -1050.79, 23.30) -- 直接指定歌词显示坐标，高度提高
    },

    {
        name = "miaomiao",
        coords = vector3(-1677.55, 432.37, 126.70),
        label = "喵喵集团DJ台",
        interactionRange = 2.5,
        musicRange = 25.0,
        volume = {
            min = 0.0,
            max = 0.7,
            default = 0.4
        },
        enableJobCheck = true,
        allowedJobs = {
            ["gang1"] = true
        },
        enableParticleEffect = false, -- 禁用粒子特效
        models = {
            booth = 'h4_prop_battle_dj_deck_01a_a'
        },
        -- 歌词显示配置
        lyricsEnabled = true,   -- 此DJ台是否启用歌词显示
        lyricsHeight = 0.5, -- DJ台上方高度
        lyricsOffsetX = 0.0, -- X轴偏移
        lyricsOffsetY = 0.0, -- Y轴偏移
        lyricsFont = 0, -- 字体样式 (0-9)
        lyricsScale = 1.0, -- 文本大小调整为适中
        lyricsCoords = vector3(-1677.55, 432.37, 127.60) -- 直接指定歌词显示坐标，高度提高
    },

}

-- Helper functions
Config.GetPlayerData = function()
    local framework = Config.Framework.getCurrent()
    if not framework then
        print("Error: No framework available")
        return nil
    end

    local core = framework.getCore()
    if not core then
        print("Error: Unable to get framework core")
        return nil
    end

    local playerData = framework.getPlayerData(core)
    if not playerData then
        print("Error: Unable to get player data from framework")
        return nil
    end

    return playerData
end

Config.IsFrameworkReady = function()
    local framework = Config.Framework.getCurrent()
    return framework ~= nil
end

return Config
