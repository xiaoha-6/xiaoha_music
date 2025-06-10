-- 在文件开头获取框架
Framework = nil

-- 全局变量，用于测试功能
testActive = false
testActiveHere = false
testActiveAt = false
testDjBoothActive = false
testDjBoothId = nil
testDjBoothText = ""

-- 歌词相关变量
currentLyrics = {}
currentLyricText = ""
currentLyricIndex = 0
isShowingLyrics = false
lyricUpdateThreadActive = false
lastLyricUpdateTime = 0
lyricsRequestCallback = nil

-- 这里是脚本开头的代码，用于获取框架引用
Citizen.CreateThread(function()
    waitForFramework()
end)

local PlayerData = nil

-- 添加调试函数，用于记录API响应
function LogAPIResponse(data, label)
    if not Config.Debug.EnablePrints then return end
    
    label = label or "API Response"
    print("================ " .. label .. " ================")
    
    if type(data) == "table" then
        for k, v in pairs(data) do
            if type(v) == "table" then
                print(k .. ": [Table]")
            elseif type(v) == "string" and string.len(v) > 100 then
                print(k .. ": " .. string.sub(v, 1, 100) .. "... [truncated]")
            else
                print(k .. ": " .. tostring(v))
            end
        end
    else
        print(tostring(data))
    end
    
    print("================ End " .. label .. " ================")
end

Citizen.CreateThread(function()
    while true do
        Wait(100)
        if Config.IsFrameworkReady() then
            PlayerData = Config.GetPlayerData()
            if PlayerData then
                break
            end
        end
    end

    if not PlayerData then
        print("Warning: Could not get player data, retrying...")
    end
end)

Citizen.CreateThread(function()
    while not Config.IsFrameworkReady() do
        Wait(100)
    end

    for _, djTable in pairs(Config.DJTables) do
        local zoneData = {
            name = djTable.name,
            coords = djTable.coords,
            label = djTable.label,
            radius = 1.5,
            distance = 2.5,
            debug = Config.Debug.ShowTargetZone,
            enableJobCheck = djTable.enableJobCheck,
            allowedJobs = djTable.allowedJobs,
            onSelect = function()
                openDJTable(djTable.name)
            end,
            canInteract = function()
                return isJobAllowed(djTable.name)
            end
        }

        local success = Config.Target.addZone(zoneData)
        if not success and Config.Debug.EnablePrints then
            print("Failed to create target zone for DJ table: " .. djTable.name)
        end
    end
end)
-- Register the event for QB-target
RegisterNetEvent("openDJTable")
AddEventHandler("openDJTable", function(data)
    Config.Debug.Print("Received openDJTable event", Config.Debug.Levels.Info)
    Config.Debug.Print("Data: " .. json.encode(data), Config.Debug.Levels.Debug)

    if type(data) == 'table' and data.djTableId then
        Config.Debug.Print("Opening DJ table with ID: " .. data.djTableId, Config.Debug.Levels.Info)
        openDJTable(data.djTableId)
    elseif type(data) == 'string' then
        Config.Debug.Print("Opening DJ table with string ID: " .. data, Config.Debug.Levels.Info)
        openDJTable(data)
    else
        Config.Debug.Print("Invalid djTableId in openDJTable event", Config.Debug.Levels.Error)
    end
end)

-- 修改职业检查函数
function isJobAllowed(djTableId)
    -- 查找对应的DJ台配置
    local djTable = nil
    for _, dj in pairs(Config.DJTables) do
        if dj.name == djTableId then
            djTable = dj
            break
        end
    end

    if not djTable then
        return false
    end

    -- 如果该DJ台未启用职业限制，直接返回true
    if not djTable.enableJobCheck then
        return true
    end

    -- 获取最新的玩家数据
    PlayerData = Config.GetPlayerData()
    if not PlayerData then
        print("Warning: Unable to get player data for job check")
        return false
    end

    local playerJobName = PlayerData.job and PlayerData.job.name or nil
    if not playerJobName then
        print("Warning: Player job data not found")
        return false
    end

    return djTable.allowedJobs[playerJobName] == true
end

-- 修改打印函数，使用调试配置
function DebugPrint(message, level)
    Config.Debug.Print(message, level or Config.Debug.Levels.Debug)
end

-- RegisterCommand('demo', function()
--     -- openDJTable('test')
--     SetNuiFocus(true, true)

--     -- 发送打开界面消息
--     SendNUIMessage({
--         action = 'openDJTable',
--         djTableId = 1
--     })
-- end, false)
-- 修改打开 DJ 台函数
function openDJTable(djTableId)
    -- 检查权限
    if not isJobAllowed(djTableId) then
        Config.Notify('你没有权限使用这个DJ台！', 'error')
        return
    end

    -- 设置NUI焦点
    SetNuiFocus(true, true)

    -- 发送打开界面消息
    SendNUIMessage({
        action = 'openDJTable',
        djTableId = djTableId
    })

    -- 调试输出
    print("Opening DJ table:", djTableId)
end

-- 监听服务端返回的数据
RegisterNetEvent("dj:receiveMusicData")
AddEventHandler("dj:receiveMusicData", function(musicData)
    -- 服务器端调试输出
    Config.Debug.Print(musicData, Config.Debug.Levels.Debug, 'server')
    -- NUI 调试输出
    Config.Debug.Print(musicData, Config.Debug.Levels.Debug, 'nui')
    
    -- 记录API响应以便于调试
    if Config.Debug.EnablePrints then
        local success, parsedData = pcall(json.decode, musicData)
        if success and parsedData then
            LogAPIResponse(parsedData, "Music Data From Server")
            if parsedData.result and parsedData.result.songs and #parsedData.result.songs > 0 then
                local firstSong = parsedData.result.songs[1]
                LogAPIResponse(firstSong, "First Song Details")
                
                if firstSong.album then
                    LogAPIResponse(firstSong.album, "Album Details")
                end
            end
        end
    end

    SendNUIMessage({
        action = "musicData",
        data = musicData,
    })
end)

-- 后端检测 ESC 的逻辑
Citizen.CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustReleased(0, 322) then -- ESC键
            SetNuiFocus(false, false)
            SendNUIMessage({
                action = 'closeDJTable'
            })
        end
    end
end)

-- 监听 NUI 事件
RegisterNUICallback('fetchMusicData', function(data, cb)
    local search = data.search
    TriggerServerEvent("dj:fetchMusicData", search)
    cb('ok')
end)
-- 监听 NUI 事件
RegisterNUICallback('nodianji', function(data, cb)
    Config.Notify('5秒内不能点击列表', 'error')
    cb('ok')
end)

-- -- 监听 NUI 事件
RegisterNUICallback('localmusic', function(data, cb)
    TriggerServerEvent("dj:localMusicData")
    cb('ok')
end)

-- 添加全局变量来跟踪当前播放的音乐实例和状态
local currentMusicInstance = nil
local currentMusicData = nil
local isMusicPaused = false

-- 添加音量检查函数
function checkVolumeInRange(djTable, volume)
    if not djTable or not djTable.volume then return volume end
    
    local min = djTable.volume.min or 0.0
    local max = djTable.volume.max or 1.0
    
    -- 确保音量在配置的范围内
    return math.max(min, math.min(max, volume))
end

-- 修改距离检查函数
function isPlayerInRange(coords, range)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - coords)
    return distance <= range
end

-- 添加全局变量来跟踪音量设置
local currentVolumes = {}
local volumeUpdateThreads = {} -- 添加线程跟踪

-- 修改音量控制函数
RegisterNUICallback('setVolume', function(data, cb)
    if not data.name or data.volume == nil then
        print("^1[DJ系统] 错误：缺少音量控制所需的数据^0")
        print("^3[DJ系统] 接收的数据：" .. json.encode(data) .. "^0")
        return cb('error')
    end

    -- 获取DJ台配置
    local djTableId = data.name:match("([^_]+_[^_]+)_")
    if not djTableId and data.djTableId then
        djTableId = data.djTableId
    end
    
    if djTableId then
        djTableId = djTableId:gsub("_$", "")
    end
    
    print("^3[DJ系统] 音乐实例名称：" .. data.name .. "^0")
    print("^3[DJ系统] 提取的DJ台ID：" .. (djTableId or "未知") .. "^0")
    print("^3[DJ系统] 设置音量为：" .. data.volume .. "^0")

    -- 验证提取的ID
    if not djTableId then
        print("^1[DJ系统] 错误：无法从音乐名称提取DJ台ID：" .. data.name .. "^0")
        return cb('error')
    end

    -- 查找DJ台配置
    local djTable = nil
    for _, dj in pairs(Config.DJTables) do
        if dj.name == djTableId then
            djTable = dj
            break
        end
    end

    if not djTable then
        print("^1[DJ系统] 错误：未找到DJ台配置。ID：" .. djTableId .. "^0")
        return cb('error')
    end

    -- 确保volume是0-1范围内的值
    local volume = data.volume
    if volume > 1 then
        volume = volume / 100  -- 假设前端传来的是百分比形式(0-100)
    end
    volume = math.max(0.0, math.min(1.0, volume))

    -- 检查音乐实例是否存在
    if not exports['xsound']:soundExists(data.name) then
        print("^1[DJ系统] 错误：音乐实例不存在：" .. data.name .. "^0")
        return cb('error')
    end

    -- 停止现有的音量更新线程
    if volumeUpdateThreads[data.name] then
        volumeUpdateThreads[data.name] = false
    end

    -- 保存音量设置
    currentVolumes[data.name] = volume
    print("^2[DJ系统] 保存音量设置：" .. data.name .. " = " .. volume .. "^0")

    -- 设置音量
    local success = exports['xsound']:setVolume(data.name, volume)
    
    if success then
        print("^2[DJ系统] 成功设置音量为 " .. volume .. " - 音乐：" .. data.name .. "^0")
        
        -- 发送音量更新事件到前端
        SendNUIMessage({
            action = "volumeUpdated",
            volume = volume * 100,
            name = data.name
        })

        -- 通知服务器音量变化以便同步到其他玩家
        TriggerServerEvent('dj:setVolume', data.name, volume)
        print("^2[DJ系统] 已发送音量同步请求到服务器^0")

        -- 启动新的音量维持线程
        volumeUpdateThreads[data.name] = true
        Citizen.CreateThread(function()
            local instanceId = data.name
            local targetVolume = volume
            
            while volumeUpdateThreads[instanceId] and exports['xsound']:soundExists(instanceId) do
                local currentVol = exports['xsound']:getVolume(instanceId)
                if currentVol ~= targetVolume then
                    print("^3[DJ系统] 音量不匹配，重新设置：" .. currentVol .. " -> " .. targetVolume .. "^0")
                    exports['xsound']:setVolume(instanceId, targetVolume)
                end
                Citizen.Wait(200)
            end
        end)
        
        cb('ok')
    else
        print("^1[DJ系统] 设置音量失败^0")
        cb('error')
    end
end)

-- 停止当前播放的音乐并清理状态
function stopCurrentMusic()
    if currentMusicInstance then
        if exports['xsound']:soundExists(currentMusicInstance) then
            exports['xsound']:Destroy(currentMusicInstance)
        end
        currentMusicInstance = nil
        currentMusicData = nil
        
        -- 确保停止歌词显示
        stopLyricsDisplay()
        
        -- 通知UI音乐已停止
        SendNUIMessage({
            action = "trackEnded"
        })
    end
end

-- 添加停止音乐的事件处理
RegisterNetEvent('dj:stopMusicForAll')
AddEventHandler('dj:stopMusicForAll', function(djTableId)
    -- 检查是否是当前播放的音乐
    if currentMusicData and currentMusicData.djTableId == djTableId then
        stopCurrentMusic()
    end
end)

-- 修改播放音乐函数
RegisterNUICallback('playMusic', function(data, cb)
    if not data.name or not data.url or not data.djTableId then
        print("Error: Missing required music data")
        return cb('error')
    end

    -- 获取DJ台配置
    local djTable = nil
    for _, dj in pairs(Config.DJTables) do
        if dj.name == data.djTableId then
            djTable = dj
            break
        end
    end

    if not djTable then
        print("Error: DJ table not found:", data.djTableId)
        return cb('error')
    end

    -- 检查玩家是否在DJ台范围内
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - djTable.coords)
    if distance > djTable.interactionRange then
        Config.Notify('你离DJ台太远了', 'error')
        return cb('error')
    end

    -- 设置初始音量
    local volume = (data.volume or 100) / 100
    volume = checkVolumeInRange(djTable, volume)

    -- 从URL中提取歌曲ID（如果没有明确提供）
    local songId = data.id
    if not songId and data.url then
        songId = data.url:match("id=(%d+)")
        print("Extracted song ID from URL: " .. (songId or "none"))
    end

    -- 触发服务器事件来同步音乐播放
    TriggerServerEvent('dj:syncMusic', {
        name = data.name,
        url = data.url,
        djTableId = data.djTableId,
        volume = volume,
        artist = data.artist,
        album = data.album,
        duration = data.duration,
        avatar = data.avatar,
        id = songId -- 确保ID被传递
    })

    print("Triggered syncMusic with song ID: " .. (songId or "none"))
    cb('ok')
end)

-- 修改音乐播放事件以启动歌词显示
RegisterNetEvent('dj:playMusicForAll')
AddEventHandler('dj:playMusicForAll', function(musicData)
    -- 获取DJ台配置
    local djTable = nil
    for _, dj in pairs(Config.DJTables) do
        if dj.name == musicData.djTableId then
            djTable = dj
            break
        end
    end

    if not djTable then 
        print("^1[DJ系统] 错误：未找到DJ台配置: " .. (musicData.djTableId or "未知") .. "^0")
        return 
    end

    -- 先停止当前播放的音乐
    stopCurrentMusic()
    
    -- 提前保存音乐数据，确保currentMusicData在启动歌词显示前已设置
    currentMusicData = musicData
    print("^2[DJ系统] 接收到播放请求：" .. musicData.name .. " - DJ台: " .. musicData.djTableId .. "^0")

    -- 生成唯一的音乐实例ID
    local musicInstanceId = musicData.djTableId .. "_" .. musicData.name

    print("^3[DJ系统] 开始播放URL：" .. musicData.url .. "^0")
    print("^3[DJ系统] 音量设置：" .. tostring(musicData.volume) .. "^0")
    print("^3[DJ系统] 播放位置：" .. vector3(djTable.coords.x, djTable.coords.y, djTable.coords.z) .. "^0")

    -- 使用3D音频播放
    local success = exports['xsound']:PlayUrlPos(musicInstanceId, 
        musicData.url, 
        musicData.volume, 
        djTable.coords,
        false,
        {
            onPlayStart = function()
                print("^2[DJ系统] 音乐开始播放: " .. musicInstanceId .. "^0")
                -- 设置3D音频参数
                exports['xsound']:setSoundDynamic(musicInstanceId, true)
                -- 设置最大听觉距离
                exports['xsound']:Distance(musicInstanceId, djTable.musicRange)
                -- 设置3D音频位置
                exports['xsound']:Position(musicInstanceId, djTable.coords)

                -- 通知UI音乐已开始播放
                SendNUIMessage({
                    action = "musicStarted",
                    musicInfo = {
                        name = musicData.name,
                        artist = musicData.artist,
                        album = musicData.album,
                        duration = musicData.duration,
                        avatar = musicData.avatar,
                        djTableId = musicData.djTableId,
                        volume = musicData.volume * 100,
                        id = musicData.id or musicInstanceId
                    }
                })
                
                -- 检查我们是否有歌曲ID，如果没有则尝试从URL提取
                local songId = musicData.id
                if not songId and musicData.url then
                    -- 从网易云音乐URL提取ID
                    songId = musicData.url:match("id=(%d+)")
                    print("^3[DJ系统] 从URL提取歌曲ID: " .. (songId or "未找到") .. "^0")
                end
                
                -- 启动歌词显示
                if songId then
                    print("^2[DJ系统] 开始显示歌词 ID: " .. songId .. "^0")
                    -- 设置当前歌曲数据为全局变量，确保歌词渲染线程可以访问
                    isShowingLyrics = true  -- 确保启用歌词显示标志
                    startLyricsDisplay(musicInstanceId, songId, musicData.name)
                else
                    print("^3[DJ系统] 无法显示歌词: 缺少歌曲ID^0")
                    -- 如果没有歌词，也设置一个默认值
                    currentLyricText = "♪ 无歌词 ♪"
                    isShowingLyrics = true
                    lastLyricUpdateTime = GetGameTimer()
                end
            end,
            onPlayEnd = function()
                print("^2[DJ系统] 音乐播放结束: " .. musicInstanceId .. "^0")
                -- 通知服务器音乐已结束
                TriggerServerEvent('dj:stopMusic', musicData.djTableId)
                stopCurrentMusic()
            end
        }
    )

    if success then
        print("^2[DJ系统] 成功开始播放音乐^0")
        currentMusicInstance = musicInstanceId

        -- 创建音量更新线程
        Citizen.CreateThread(function()
            while currentMusicInstance == musicInstanceId do
                if not exports['xsound']:soundExists(musicInstanceId) then 
                    stopLyricsDisplay() -- 确保歌词显示停止
                    print("^3[DJ系统] 音乐实例不存在，停止线程^0")
                    break 
                end
                
                local playerPos = GetEntityCoords(PlayerPedId())
                local dist = #(playerPos - djTable.coords)
                
                if dist > djTable.musicRange then
                    exports['xsound']:setVolume(musicInstanceId, 0.0)
                else
                    -- 使用平方反比定律计算音量衰减
                    local distanceFactor = 1.0 - math.pow(dist / djTable.musicRange, 2)
                    local adjustedVolume = musicData.volume * math.max(0.0, distanceFactor)
                    exports['xsound']:setVolume(musicInstanceId, adjustedVolume)
                end
                
                Citizen.Wait(100) -- 更频繁更新音量
            end
        end)

        -- 记录播放历史
        TriggerServerEvent('dj:addToRecentPlays', musicData.djTableId, {
            name = musicData.name,
            artist = musicData.artist,
            album = musicData.album,
            duration = musicData.duration,
            avatar = musicData.avatar,
            url = musicData.url
        })
    else
        print("^1[DJ系统] 播放音乐失败: " .. (musicData.url or "未知URL") .. "^0")
    end
end)

-- 修改暂停音乐函数
RegisterNUICallback('zanting', function(data, cb)
    if not data.name then
        print("Error: Missing music instance ID for pause")
        return cb('error')
    end

    print("Attempting to pause music: " .. data.name)
    
    if exports['xsound']:soundExists(data.name) then
        if exports['xsound']:isPlaying(data.name) then
            exports['xsound']:Pause(data.name)
            isMusicPaused = true
            print("Successfully paused music: " .. data.name)
            SendNUIMessage({
                action = "musicPaused"
            })
            
            -- 通知服务器暂停音乐（使用统一的事件名）
            TriggerServerEvent('dj:pauseMusicForAll', data.name)
            cb('ok')
        else
            print("Music is already paused: " .. data.name)
            cb('error')
        end
    else
        print("Error: Music instance not found: " .. data.name)
        cb('error')
    end
end)

-- 修改恢复播放函数
RegisterNUICallback('bofang', function(data, cb)
    if not data.name then
        print("Error: Missing music instance ID for resume")
        return cb('error')
    end

    print("Attempting to resume music: " .. data.name)
    
    if exports['xsound']:soundExists(data.name) then
        if not exports['xsound']:isPlaying(data.name) then
            exports['xsound']:Resume(data.name)
            isMusicPaused = false
            print("Successfully resumed music: " .. data.name)
            SendNUIMessage({
                action = "musicResumed"
            })
            
            -- 通知服务器恢复播放音乐（使用统一的事件名）
            TriggerServerEvent('dj:resumeMusicForAll', data.name)
            cb('ok')
        else
            print("Music is already playing: " .. data.name)
            cb('error')
        end
    else
        print("Error: Music instance not found: " .. data.name)
        cb('error')
    end
end)

-- 监听 NUI 事件
RegisterNUICallback('pauseResume', function(data, cb)
    if not data.name then
        print("Error: Missing music name for pause/resume")
        return cb('error')
    end

    if exports['xsound']:isPlaying(data.name) then
        exports['xsound']:pause(data.name)
    else
        exports['xsound']:resume(data.name)
    end

    cb('ok')
end)

-- 监听 NUI 事件
RegisterNUICallback('closeNui', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeDJTable'
    })
    if cb then cb('ok') end
end)

-- 监听 NUI 事件
RegisterNUICallback('getCurrentTime', function(data, cb)
    if not data.name then
        return cb({ currentTime = 0, duration = 0 })
    end

    local musicInstanceId = data.name
    if exports['xsound']:soundExists(musicInstanceId) then
        local currentTime = exports['xsound']:getTimeStamp(musicInstanceId)
        local duration = exports['xsound']:getMaxDuration(musicInstanceId)

        currentTime = tonumber(currentTime) or 0
        duration = tonumber(duration) or 0

        if currentTime > duration then
            currentTime = duration
        end

        cb({
            currentTime = currentTime,
            duration = duration
        })
    else
        cb({ currentTime = 0, duration = 0 })
    end
end)

-- 监听来自服务器的设置声音事件
RegisterNetEvent("dj:setVolumes")
AddEventHandler("dj:setVolumes", function(name, volume)
    -- 确保参数有效
    if name and volume and exports['xsound']:soundExists(name) then
        exports['xsound']:setVolume(name, volume)
        print("Volume set via network event: " .. name .. " = " .. tostring(volume))
        
        -- 发送音量更新事件到前端
        SendNUIMessage({
            action = "volumeUpdated",
            volume = volume * 100,
            name = name
        })
    end
end)

-- 监听来自服务器的列表
RegisterNetEvent("dj:receiveMP3ListHTML")
AddEventHandler("dj:receiveMP3ListHTML", function(htmlString)
    -- print(htmlString)
    SendNUIMessage({
        action = "tracks",
        data = htmlString,
    })
end)


local function playMusic(data)
    local playerCoords = GetEntityCoords(PlayerPedId())

    local djBoothCoords = GetEntityCoords(djBooth)


    local distance = #(playerCoords - djBoothCoords)
    if distance <= Config.MaxDistance then
        local volume = 1.0 - (distance / Config.MaxDistance)

        volume = math.max(0.0, math.min(1.0, volume))


        SendNUIMessage({
            type = "playMusic",
            link = data.link,
            volume = volume
        })
    else
        SendNUIMessage({
            type = "stopMusic"
        })
    end
end


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if isPlaying then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local djBoothCoords = GetEntityCoords(djBooth)
            local distance = #(playerCoords - djBoothCoords)

            if distance > Config.MaxDistance then
                SendNUIMessage({
                    type = "stopMusic"
                })
                isPlaying = false
            else
                local volume = 1.0 - (distance / Config.MaxDistance)
                volume = math.max(0.0, math.min(1.0, volume))
                SendNUIMessage({
                    type = "updateVolume",
                    volume = volume
                })
            end
        end
        Citizen.Wait(0)
    end
end)


-- 添加获取音乐时长的函数
function getMusicDuration(musicInstanceId)
    if exports['xsound']:soundExists(musicInstanceId) then
        return exports['xsound']:getMaxDuration(musicInstanceId)
    end
    return 0
end

RegisterNetEvent("dj:playMusic")
AddEventHandler("dj:playMusic", function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then 
        print("^1[DJ系统] 错误：无法获取玩家信息^0")
        return 
    end

    if not data or not data.djTableId or not data.name then
        print("^1[DJ系统] 错误：缺少必要的歌曲信息^0")
        return
    end

    -- 检查DJ台是否已经在播放音乐
    if isDJTableOccupied(data.djTableId) then
        local currentDJ = activeDJTables[data.djTableId].djId
        if currentDJ ~= src then
            TriggerClientEvent('esx:showNotification', src, '这个DJ台正在被其他玩家使用中')
            return
        end
    end

    -- 停止其他DJ台正在播放的音乐
    for djTableId, data in pairs(activeDJTables) do
        if data.djId == src then
            clearDJTable(djTableId)
        end
    end

    -- 更新DJ台状态
    activeDJTables[data.djTableId] = {
        djId = src,
        musicData = data,
        timestamp = os.time()
    }

    -- 广播给所有客户端播放音乐
    TriggerClientEvent('dj:playMusicForAll', -1, data)
end)

-- 监听来自服务器的设置声音事件
RegisterNetEvent("dj:setVolumes")
AddEventHandler("dj:setVolumes", function(name, volume)
    -- 确保参数有效
    if name and volume and exports['xsound']:soundExists(name) then
        exports['xsound']:setVolume(name, volume)
    end
end)

-- 监听来自服务器的列表
RegisterNetEvent("dj:receiveMP3ListHTML")
AddEventHandler("dj:receiveMP3ListHTML", function(htmlString)
    -- print(htmlString)
    SendNUIMessage({
        action = "tracks",
        data = htmlString,
    })
end)

-- 监听 NUI 事件
RegisterNUICallback('addComment', function(data, cb)
    if not data.songId or not data.content then
        cb({ success = false, message = "缺少必要信息" })
        return
    end

    if string.len(data.content) < 1 or string.len(data.content) > 500 then
        cb({ success = false, message = "评论长度必须在1-500字之间" })
        return
    end

    -- 触发服务器事件添加评论
    TriggerServerEvent('dj:addComment', data.songId, data.songName, data.songArtist, data.content)
    cb({ success = true })
end)

-- 获取评论
RegisterNUICallback('getComments', function(data, cb)
    if not data.songId then
        cb({ success = false, message = "缺少歌曲ID" })
        return
    end

    -- 触发服务器事件获取评论
    TriggerServerEvent('dj:getComments', data.songId)
    cb({ success = true })
end)

-- 点赞评论
RegisterNUICallback('likeComment', function(data, cb)
    if not data.commentId then
        cb({ success = false, message = "缺少评论ID" })
        return
    end

    TriggerServerEvent('dj:likeComment', data.commentId)
    cb({ success = true })
end)

-- 接收更新的评论
RegisterNetEvent('dj:updateComments')
AddEventHandler('dj:updateComments', function(comments)
    SendNUIMessage({
        action = "updateComments",
        comments = comments
    })
end)

-- 添加通知事件处理
RegisterNetEvent('dj:notify')
AddEventHandler('dj:notify', function(message, type)
    Config.Notify(message, type)
end)

-- 添加测试命令
RegisterCommand('testmusic', function()
    local testURL = "https://music.163.com/song/media/outer/url?id=28875146.mp3"
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    print("测试播放音乐...")
    print("玩家坐标: " .. tostring(playerCoords))
    
    local success = exports['xsound']:PlayUrl('test_music', testURL, 0.5, {
        position = playerCoords,
        range = 50.0,
        loop = false,
        volume = 0.5,
        maxDistance = 50.0,
        falloff = 'linear'
    })
    
    print("测试播放结果: " .. tostring(success))
end, false)

-- 监听 NUI 事件
RegisterNUICallback('playPrevious', function(data, cb)
    if not data.currentId then
        print("Error: Missing current song ID")
        return cb('error')
    end

    -- 获取当前歌曲在列表中的位置
    local currentIndex = -1
    for i, song in ipairs(musicList) do
        if song.id == data.currentId then
            currentIndex = i
            break
        end
    end

    if currentIndex > 1 then
        -- 播放上一首
        local prevSong = musicList[currentIndex - 1]
        TriggerEvent("dj:playMusic", {
            url = string.format("https://api.qijieya.cn/meting/?type=url&id=%s", prevSong.id),
            name = prevSong.name,
            artist = prevSong.singer,
            album = prevSong.album,
            avatar = prevSong.avatar,
            djTableId = 'vanilla_club',
            volume = 100,
            duration = prevSong.duration
        })
    end
    cb('ok')
end)

-- 监听 NUI 事件
RegisterNUICallback('playNext', function(data, cb)
    if not data.currentId then
        print("Error: Missing current song ID")
        return cb('error')
    end

    -- 获取当前歌曲在列表中的位置
    local currentIndex = -1
    for i, song in ipairs(musicList) do
        if song.id == data.currentId then
            currentIndex = i
            break
        end
    end

    if currentIndex > 0 and currentIndex < #musicList then
        -- 播放下一首
        local nextSong = musicList[currentIndex + 1]
        TriggerEvent("dj:playMusic", {
            
            url = string.format("https://api.qijieya.cn/meting/?type=url&id=%s", nextSong.id),
            name = nextSong.name,
            artist = nextSong.singer,
            album = nextSong.album,
            avatar = nextSong.avatar,
            djTableId = 'vanilla_club',
            volume = 100,
            duration = nextSong.duration
        })
    end
    cb('ok')
end)

-- 添加到文件顶部
local musicList = {}

-- 在 InitData 函数中更新 musicList
RegisterNUICallback('InitData', function(data, cb)
    local musicData = type(data) == 'string' and json.decode(data) or data
    if not musicData.result then return end
    local songs = musicData.result.songs
    if not songs or #songs == 0 then return end
    
    -- 清空并更新音乐列表
    musicList = {}
    for _, song in ipairs(songs) do
        local musicInfo = {}
        musicInfo.id = song.id
        musicInfo.name = song.name
        -- 歌手
        musicInfo.singer = '未知艺术家'
        if song.artists and song.artists[0] then
            musicInfo.singer = song.artists[0].name
        elseif song.ar and song.ar[0] then
            musicInfo.singer = song.ar[0].name
        end
        -- 专辑封面
        musicInfo.avatar = 'https://via.placeholder.com/50'
        if song.album and song.album.picId then
            musicInfo.avatar = string.format("https://p2.music.126.net/%s.jpg", song.album.picId)
        elseif song.al and song.al.picId then
            musicInfo.avatar = string.format("https://p2.music.126.net/%s.jpg", song.al.picId)
        elseif song.album and song.album.picUrl then
            musicInfo.avatar = song.album.picUrl
        elseif song.al and song.al.picUrl then
            musicInfo.avatar = song.al.picUrl
        end
        musicInfo.album = song.album and song.album.name or '未知专辑'
        local timeNumber = math.floor((song.duration or 0) / 1000)
        musicInfo.duration = string.format("%d:%02d", math.floor(timeNumber / 60), timeNumber % 60)
        table.insert(musicList, musicInfo)
    end
    cb('ok')
end)

-- 添加辅助函数来检查音乐状态
function isMusicPlaying(musicInstanceId)
    return exports['xsound']:soundExists(musicInstanceId) and exports['xsound']:isPlaying(musicInstanceId)
end

-- 在音乐结束时清理资源
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for instanceId, _ in pairs(volumeUpdateThreads) do
            volumeUpdateThreads[instanceId] = false
        end
    end
end)

-- 添加设置音乐时间的函数
RegisterNUICallback('setMusicTime', function(data, cb)
    if not data.name or not data.time then
        print("Error: Missing required data for time control")
        return cb('error')
    end

    if not exports['xsound']:soundExists(data.name) then
        print("Error: Music instance not found:", data.name)
        return cb('error')
    end

    -- 设置音乐时间
    exports['xsound']:setTimeStamp(data.name, data.time)
    
    -- 发送时间更新事件
    SendNUIMessage({
        action = "timeUpdate",
        currentTime = data.time,
        duration = exports['xsound']:getMaxDuration(data.name)
    })
    
    cb('ok')
end)

-- 修改获取最近播放列表的回调
RegisterNUICallback('getRecentPlays', function(data, cb)
    if not data.djTableId then
        print("Error: Missing DJ table ID for recent plays")
        return cb({ items = {}, total = 0, page = 1, pageSize = 10 })
    end

    print("Requesting recent plays for DJ table:", data.djTableId)
    TriggerServerEvent('dj:getRecentPlays', {
        djTableId = data.djTableId,
        page = data.page or 1,
        pageSize = data.pageSize or 10,
        timeFilter = data.timeFilter or 'all'
    })
    
    cb('ok')
end)

-- 修改接收最近播放列表的事件处理
RegisterNetEvent('dj:receiveRecentPlays')
AddEventHandler('dj:receiveRecentPlays', function(data)
    print("Received recent plays:", json.encode(data))
    SendNUIMessage({
        action = "updateRecentPlays",
        data = data
    })
end)

-- 存储已生成的DJ台对象
local spawnedDJBooths = {}

-- 获取DJ台模型
local function getDJBoothModel(djTableId)
    for _, djTable in pairs(Config.DJTables) do
        if djTable.name == djTableId then
            return djTable.models and djTable.models.booth or Config.DJBoothModels.default.booth
        end
    end
    return Config.DJBoothModels.default.booth
end

-- 加载模型
local function loadModel(model)
    if not HasModelLoaded(model) then
        RequestModel(GetHashKey(model))
        while not HasModelLoaded(GetHashKey(model)) do
            Wait(1)
        end
    end
end

-- 创建粒子特效的函数
local function createParticleEffect(djTableId, coords)
    -- 查找对应的DJ台配置
    local djTable = nil
    for _, table in pairs(Config.DJTables) do
        if table.name == djTableId then
            djTable = table
            break
        end
    end

    -- 如果没有找到DJ台配置或粒子特效被禁用，则返回
    if not djTable or not djTable.enableParticleEffect then return end

    local particleName = "core" -- 主粒子效果
    local particleEffect = StartParticleFxLoopedAtCoord(particleName, coords.x, coords.y, coords.z + 1.5, 0.0, 0.0, 0.0, 1.0, false, false, false, false)

    -- 使用不同的粒子效果来模拟光线
    local lightParticleName = "scr_indep_firework" -- 尝试使用其他粒子效果
    local lightParticleEffect = StartParticleFxLoopedAtCoord(lightParticleName, coords.x, coords.y, coords.z + 1.5, 0.0, 0.0, 0.0, 1.0, false, false, false, false)

    -- 设置粒子特效的持续时间
    Citizen.SetTimeout(5000, function()
        StopParticleFxLooped(particleEffect, 0)
        StopParticleFxLooped(lightParticleEffect, 0) -- 停止光线粒子效果
    end)
end

-- 修改生成DJ台的函数
local function spawnDJBooth(djTableId)
    if spawnedDJBooths[djTableId] then
        return
    end

    local model = getDJBoothModel(djTableId)
    local djTable = nil
    
    -- 查找对应的DJ台配置
    for _, table in pairs(Config.DJTables) do
        if table.name == djTableId then
            djTable = table
            break
        end
    end

    if not djTable then
        return
    end

    -- 加载模型
    loadModel(model)

    -- 生成DJ台
    local coords = djTable.coords
    local heading = djTable.heading or 0.0

    -- 创建DJ台
    local boothObject = CreateObject(GetHashKey(model), coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(boothObject, heading)
    FreezeEntityPosition(boothObject, true)

    -- 存储生成的对象
    spawnedDJBooths[djTableId] = boothObject

    -- 创建粒子特效
    createParticleEffect(djTableId, coords)
end

-- 删除DJ台
local function removeDJBooth(djTableId)
    if spawnedDJBooths[djTableId] then
        if DoesEntityExist(spawnedDJBooths[djTableId]) then
            DeleteEntity(spawnedDJBooths[djTableId])
        end
        spawnedDJBooths[djTableId] = nil
    end
end

-- 生成所有DJ台
Citizen.CreateThread(function()
    while not Config.IsFrameworkReady() do
        Wait(100)
    end

    for _, djTable in pairs(Config.DJTables) do
        spawnDJBooth(djTable.name)
    end
end)

-- 在资源停止时清理所有DJ台
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for djTableId, _ in pairs(spawnedDJBooths) do
            removeDJBooth(djTableId)
        end
    end
end)

-- 监听来自服务器的暂停音乐事件
RegisterNetEvent('dj:pauseMusic')
AddEventHandler('dj:pauseMusic', function(musicInstanceId)
    if exports['xsound']:soundExists(musicInstanceId) and exports['xsound']:isPlaying(musicInstanceId) then
        exports['xsound']:Pause(musicInstanceId)
        isMusicPaused = true
        print("Music paused for all: " .. musicInstanceId)
        SendNUIMessage({
            action = "musicPaused",
            musicInstanceId = musicInstanceId
        })
    end
end)

-- 监听来自服务器的恢复播放事件
RegisterNetEvent('dj:resumeMusic')
AddEventHandler('dj:resumeMusic', function(musicInstanceId)
    if exports['xsound']:soundExists(musicInstanceId) and not exports['xsound']:isPlaying(musicInstanceId) then
        exports['xsound']:Resume(musicInstanceId)
        isMusicPaused = false
        print("Music resumed for all: " .. musicInstanceId)
        SendNUIMessage({
            action = "musicResumed",
            musicInstanceId = musicInstanceId
        })
    end
end)

-- 添加切换歌曲的事件处理
RegisterNUICallback('switchSong', function(data, cb)
    if not data.djTableId or not data.songData then
        print("Error: Missing required data for switching song")
        return cb('error')
    end

    -- 触发服务器事件来切换歌曲
    TriggerServerEvent('dj:switchSong', data.djTableId, data.songData)
    cb('ok')
end)

-- 监听来自服务器的切换歌曲事件
RegisterNetEvent('dj:switchSongForAll')
AddEventHandler('dj:switchSongForAll', function(songData)
    -- 停止当前播放的音乐
    if currentMusicInstance then
        exports['xsound']:Stop(currentMusicInstance)
    end

    -- 播放新歌曲
    currentMusicInstance = songData.djTableId .. "_" .. songData.name
    exports['xsound']:PlayUrl(currentMusicInstance, songData.url, songData.volume, {
        position = songData.coords,
        range = songData.range,
        loop = false,
        onPlayStart = function()
            print("Music started playing: " .. currentMusicInstance)
            SendNUIMessage({
                action = "musicStarted",
                musicInfo = {
                    name = songData.name,
                    artist = songData.artist,
                    album = songData.album,
                    duration = songData.duration,
                    avatar = songData.avatar,
                    djTableId = songData.djTableId,
                    volume = songData.volume * 100,
                    id = currentMusicInstance
                }
            })
        end,
        onPlayEnd = function()
            SendNUIMessage({
                action = "trackEnded"
            })
        end
    })

    print("Switched to new song: " .. songData.name)
end)
--[[
Citizen.CreateThread(function()
    -- SetEntityCoords(PlayerPedId(), -1661.05, -2964.81, 13.94, false, false, false, true)
    while true do
        Citizen.Wait(0)
        if isPlaying then
            -- 获取玩家当前的坐标
            local playerCoords = GetEntityCoords(PlayerPedId())

            -- 遍历所有的 DJ 台配置
            for _, djTable in ipairs(Config.DJTables) do
                -- 获取当前 DJ 台的坐标
                local djTableCoords = djTable.coords
                -- 计算玩家与当前 DJ 台之间的距离
                local distance = #(playerCoords - djTableCoords)
                -- 判断玩家是否在当前 DJ 台的最大距离范围内
                if distance < 30.0 then
                    -- 随机定义光线的数量
                    local numRays = math.random(3, 8)  -- 每个启动随机绘制5到15条光线

                    -- 定义多个起点偏移量
                    local offsets = {
                        vector3(0, 0, 8),      -- 上方
                        vector3(5, 5, 8),      -- 右上
                        vector3(-5, 5, 8),     -- 左上
                        vector3(5, -5, 8),     -- 右下
                        vector3(-5, -5, 8)     -- 左下
                    }

                    -- 循环绘制多条光线
                    for _, offset in ipairs(offsets) do
                        -- 计算当前起点坐标
                        local startCoords = djTableCoords + offset

                        -- 随机绘制光线
                        for i = 1, numRays do
                            -- 生成随机旋转角度（-360 到 360 度）
                            local randomAngle = math.random(-360, 360)
                            -- 将角度转换为弧度
                            local angleInRadians = math.rad(randomAngle)

                            -- 定义光线的长度
                            local lightLength = 50.0

                            -- 计算旋转后的光线终点坐标
                            local endX = startCoords.x + lightLength * math.cos(angleInRadians)
                            local endY = startCoords.y + lightLength * math.sin(angleInRadians)
                            local endZ = startCoords.z - lightLength  -- 从上往下射线，Z坐标减去光线长度

                            local endCoords = vector3(endX, endY, endZ)

                            -- 随机生成颜色
                            local r = math.random(0, 255)
                            local g = math.random(0, 255)
                            local b = math.random(0, 255)

                            -- 绘制随机颜色的光线特效
                            DrawLine(startCoords.x, startCoords.y, startCoords.z, endCoords.x, endCoords.y, endCoords.z, r, g, b, 255)
                        end
                    end
                end
            end
        end
    end
end)]]

-- 辅助函数：检查目录是否存在
function DoesDirectoryExist(path)
    -- Windows路径处理，确保使用反斜杠
    local formattedPath = string.gsub(path, "/", "\\")
    local handle = io.popen("if exist \"" .. formattedPath .. "\" echo true")
    local result = handle:read("*a")
    handle:close()
    return result:match("true") ~= nil
end

-- 辅助函数：创建目录
function CreateDirectory(path)
    -- Windows路径处理，确保使用反斜杠
    local formattedPath = string.gsub(path, "/", "\\")
    os.execute("mkdir \"" .. formattedPath .. "\"")
end

-- 处理保存歌词到JSON文件的请求
RegisterNUICallback('saveLyricsFile', function(data, cb)
    if not data.fileName or not data.content then
        print("Error: Missing required data for saving lyrics file")
        return cb({ success = false, error = "Missing required data" })
    end
    
    -- 发送到服务器处理文件保存
    TriggerServerEvent('dj:saveLyricsToFile', data.fileName, data.content)
    
    -- 直接返回成功给前端，文件保存会在服务器端完成
    print("Lyrics file saving request sent to server")
    cb({ success = true })
end)

-- 解析LRC歌词
function parseLyricContent(lrcText)
    if not lrcText then return {} end
    
    local lyrics = {}
    for line in lrcText:gmatch("[^\r\n]+") do
        local timeStr, text = line:match("%[(%d+:%d+%.%d+)%](.*)")
        if not timeStr then
            timeStr, text = line:match("%[(%d+:%d+)%](.*)")
        end
        
        if timeStr and text then
            local min, sec = timeStr:match("(%d+):(%d+)")
            local ms = timeStr:match("%.(%d+)") or "0"
            if min and sec then
                local timeInSeconds = tonumber(min) * 60 + tonumber(sec) + tonumber("0." .. ms)
                table.insert(lyrics, {time = timeInSeconds, text = text:gsub("^%s*(.-)%s*$", "%1")})
            end
        end
    end
    
    -- 按时间排序
    table.sort(lyrics, function(a, b) return a.time < b.time end)
    return lyrics
end

-- 获取当前应该显示的歌词
function getCurrentLyric(currentTime, lyrics)
    if not lyrics or #lyrics == 0 then return "♪ 无歌词 ♪" end
    
    local currentLine = ""
    local nextIndex = 1
    
    for i, lyric in ipairs(lyrics) do
        if currentTime >= lyric.time then
            currentLine = lyric.text
            nextIndex = i + 1
        else
            break
        end
    end
    
    -- 如果当前行为空但歌曲已经开始播放一段时间，显示第一行
    if currentLine == "" and currentTime > 0 and #lyrics > 0 then
        currentLine = lyrics[1].text
    end
    
    return currentLine ~= "" and currentLine or "♪ 音乐播放中 ♪", nextIndex
end

-- 修改3D文字绘制函数以提高可见性并添加背景
function DrawText3D(coords, text, alpha, djTable)
    -- 检查参数有效性
    if not coords or not text then return false end
    
    -- 检查是否全局禁用了歌词显示
    if not Config.Lyrics.Enabled then return false end
    
    -- 检查是否在DJ台上禁用了歌词显示
    if djTable and djTable.lyricsEnabled == false then return false end
    
    -- 获取玩家位置
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - coords)
    
    -- 如果距离太远就不渲染
    if distance > 50.0 then return false end
    
    -- 基本参数设置
    alpha = alpha or 255
    local scale = djTable and djTable.lyricsScale or Config.Lyrics.DefaultScale
    local font = djTable and djTable.lyricsFont or Config.Lyrics.DefaultFont
    
    -- 设置文本属性
    SetTextScale(scale, scale)
    SetTextFont(font)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, alpha)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    
    -- 移除颜色代码
    text = text:gsub("{%w+}", "")
    AddTextComponentString(text)
    
    -- 获取屏幕坐标
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if onScreen then
        -- 直接在屏幕坐标绘制文本
        EndTextCommandDisplayText(_x, _y)
        
        -- 为了增加可见性，绘制一个背景框
        if Config.Lyrics.BackgroundEnabled then
            local factor = string.len(text) / 370
            -- DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
        end
    end
    
    return true
end

-- 从JSON文件读取歌词
function loadLyricsFromFile(songId, songName)
    if not songId or not songName then 
        print("Missing songId or songName for lyrics loading")
        return {} 
    end
    
    print("Loading lyrics for: " .. songId .. " - " .. songName)
    
    -- 通过回调获取歌词数据
    local lyrics = {}
    local dataReceived = false
    
    -- 设置回调函数
    lyricsRequestCallback = function(lyricsData)
        if lyricsData and lyricsData.lrc then
            print("Received valid lyrics data with " .. string.len(lyricsData.lrc) .. " characters")
            lyrics = parseLyricContent(lyricsData.lrc)
            print("Lyrics loaded: " .. (lyricsData.name or "unknown") .. " (lines: " .. #lyrics .. ")")
        else
            print("No lyrics data received or invalid format")
        end
        dataReceived = true
    end
    
    -- 触发服务器事件获取歌词数据
    TriggerServerEvent('dj:getLyricsFromFile', songId, songName)
    
    -- 等待数据返回，最多等待3秒
    local startTime = GetGameTimer()
    while not dataReceived and (GetGameTimer() - startTime) < 3000 do
        Citizen.Wait(50)
    end
    
    -- 如果未收到数据，清理回调并返回空歌词
    if not dataReceived then
        print("Timed out waiting for lyrics data for: " .. songId .. " - " .. songName)
        lyricsRequestCallback = nil
        return {}
    end
    
    return lyrics
end

-- 完全重置歌词显示状态
function resetLyricsDisplay()
    print("完全重置歌词显示状态")
    
    -- 清除所有相关变量
    currentLyricText = ""
    currentLyricIndex = 0
    currentLyrics = {}
    isShowingLyrics = false
    lyricUpdateThreadActive = false
    lastLyricUpdateTime = 0
    
    -- 确保任何正在运行的歌词线程都会停止
    Citizen.Wait(100)
end

-- 开始歌词显示线程
function startLyricsDisplay(musicInstanceId, songId, songName)
    -- 先完全重置歌词状态，确保没有残留的设置
    resetLyricsDisplay()
    
    print("Starting lyrics display for: " .. songName .. " (ID: " .. tostring(songId) .. ")")
    
    -- 检查全局歌词设置是否启用
    if not Config.Lyrics.Enabled then
        print("Lyrics display globally disabled in config")
        return
    end
    
    -- 查找当前播放音乐的DJ台
    local djTable = nil
    if currentMusicData and currentMusicData.djTableId then
        for _, dj in pairs(Config.DJTables) do
            if dj.name == currentMusicData.djTableId then
                djTable = dj
                break
            end
        end
        
        -- 检查DJ台歌词设置是否启用
        if djTable and djTable.lyricsEnabled == false then
            print("Lyrics display disabled for DJ table: " .. djTable.name)
            return
        end
    end
    
    -- 重置变量
    currentLyricIndex = 0
    currentLyricText = "♪ 音乐加载中 ♪"
    isShowingLyrics = true
    lastLyricUpdateTime = GetGameTimer()
    
    -- 加载歌词（在单独线程中进行以避免阻塞主线程）
    Citizen.CreateThread(function()
        -- 加载歌词
        local lyrics = loadLyricsFromFile(songId, songName)
        
        -- 检查是否成功加载歌词
        if #lyrics == 0 then
            print("No lyrics found for: " .. songName)
            currentLyricText = "♪ 无歌词 ♪"
            return
        end
        
        -- 成功加载歌词，更新当前歌词
        currentLyrics = lyrics
        print("Lyrics loaded successfully: " .. #lyrics .. " lines")
        
        -- 启动更新线程
        lyricUpdateThreadActive = true
        Citizen.CreateThread(function()
            while lyricUpdateThreadActive and isShowingLyrics do
                if exports['xsound']:soundExists(musicInstanceId) then
                    local currentTime = exports['xsound']:getTimeStamp(musicInstanceId)
                    
                    -- 获取当前应该显示的歌词
                    local lyricText, nextIndex = getCurrentLyric(currentTime, currentLyrics)
                    
                    -- 只有在歌词变化时才更新
                    if lyricText ~= currentLyricText or nextIndex ~= currentLyricIndex then
                        currentLyricText = lyricText
                        currentLyricIndex = nextIndex
                        lastLyricUpdateTime = GetGameTimer()
                        print("Lyrics updated: " .. currentLyricText)
                    end
                else
                    -- 歌曲不存在，停止显示
                    print("Music no longer exists, stopping lyrics display")
                    lyricUpdateThreadActive = false
                    isShowingLyrics = false
                    break
                end
                
                Citizen.Wait(100) -- 更新频率
            end
        end)
    end)
end

-- 停止歌词显示
function stopLyricsDisplay()
    isShowingLyrics = false
    lyricUpdateThreadActive = false
    currentLyricText = ""
    currentLyrics = {}
end

-- 创建3D文字渲染线程
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- 检查是否有歌词需要显示
        if isShowingLyrics and currentLyricText ~= "" and currentMusicData then
            -- 查找当前播放音乐的DJ台
            local activeDjTable = nil
            for _, djTable in pairs(Config.DJTables) do
                if djTable.name == currentMusicData.djTableId then
                    activeDjTable = djTable
                    break
                end
            end
            
            -- 如果找到DJ台，显示歌词
            if activeDjTable then
                -- 确定歌词显示位置
                local coords = activeDjTable.lyricsCoords
                if not coords then
                    -- 如果没有指定歌词坐标，使用DJ台坐标加上偏移
                    coords = vector3(
                        activeDjTable.coords.x + (activeDjTable.lyricsOffsetX or 0.0),
                        activeDjTable.coords.y + (activeDjTable.lyricsOffsetY or 0.0),
                        activeDjTable.coords.z + (activeDjTable.lyricsHeight or 2.0)
                    )
                end
                
                -- 获取玩家距离
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - activeDjTable.coords)
                
                -- 在范围内显示歌词
                if distance <= (activeDjTable.musicRange or 25.0) then
                    -- 多次渲染以确保可见性
                    for i = 1, 3 do
                        DrawText3D(coords, currentLyricText, 255, activeDjTable)
                    end
                    
                    -- 每5秒输出一次调试信息
                    if (GetGameTimer() % 5000) < 50 then
                        print("正在显示歌词: " .. currentLyricText)
                        print("位置: " .. tostring(coords))
                        print("距离: " .. string.format("%.2f", distance))
                    end
                end
            end
        else
            -- 如果没有歌词需要显示，等待更长时间
            Citizen.Wait(1000)
        end
    end
end)

-- 添加歌词位置测试命令，便于微调坐标
RegisterCommand('testlyricpos', function(source, args)
    if #args < 5 then
        print("用法: /testlyricpos <DJ台ID> <x> <y> <z> <歌词文本>")
        print("例如: /testlyricpos galaxy_club 120.13 -1281.67 29.5 测试歌词位置")
        return
    end
    
    local djTableId = args[1]
    local x = tonumber(args[2])
    local y = tonumber(args[3])
    local z = tonumber(args[4])
    local text = table.concat(args, ' ', 5)
    
    -- 查找DJ台
    local djTable = nil
    for _, table in pairs(Config.DJTables) do
        if table.name == djTableId then
            djTable = table
            break
        end
    end
    
    if not djTable then
        print("找不到DJ台: " .. djTableId)
        return
    end
    
    -- 保存坐标到临时变量，便于调整位置
    local testCoords = vector3(x, y, z)
    
    -- 创建测试线程
    print("在坐标 " .. tostring(testCoords) .. " 测试歌词位置")
    print("坐标看起来合适后，可以更新config.lua中的lyricsCoords设置")
    
    testLyricPosActive = true
    Citizen.CreateThread(function()
        -- 保存原始设置
        local oldText = currentLyricText
        local oldShowing = isShowingLyrics
        
        -- 设置测试文本
        currentLyricText = text
        isShowingLyrics = true
        
        -- 显示10分钟，或者直到取消
        local endTime = GetGameTimer() + (10 * 60 * 1000)
        
        while testLyricPosActive and GetGameTimer() < endTime do
            Citizen.Wait(0)
            
            -- 绘制测试文本
            DrawText3D(testCoords, text, 255, djTable)
            
            -- 每秒输出一次当前坐标
            if (GetGameTimer() % 5000) < 50 then
                print("测试歌词位置: " .. tostring(testCoords))
            end
        end
        
        -- 恢复原始设置
        currentLyricText = oldText
        isShowingLyrics = oldShowing
        
        print("歌词位置测试结束")
    end)
end, false)

-- 停止测试命令
RegisterCommand('stoptestpos', function()
    if testLyricPosActive then
        testLyricPosActive = false
        print("歌词位置测试已停止")
    else
        print("没有正在进行的位置测试")
    end
end, false)

-- 添加测试命令：显示静态歌词文本用于调试位置
RegisterCommand('testlyrics', function(source, args)
    local djTableId = args[1] or 'galaxy_club'
    local text = table.concat(args, ' ', 2) or '测试歌词显示位置'
    
    -- 查找DJ台
    local djTable = nil
    for _, table in pairs(Config.DJTables) do
        if table.name == djTableId then
            djTable = table
            break
        end
    end
    
    if not djTable then
        print("找不到DJ台: " .. djTableId)
        return
    end
    
    -- 创建测试歌词显示线程
    local testActive = true
    Citizen.CreateThread(function()
        print("开始测试歌词显示，DJ台: " .. djTableId)
        print("使用命令 'canceltest' 停止测试")
        
        -- 保存当前状态以便测试后恢复
        local oldLyricText = currentLyricText
        local oldIsShowing = isShowingLyrics
        
        -- 设置测试状态
        currentLyricText = text
        isShowingLyrics = true
        currentMusicData = {djTableId = djTableId}
        lastLyricUpdateTime = GetGameTimer()
        
        -- 等待取消命令
        while testActive do
            Citizen.Wait(1000)
        end
        
        -- 恢复原状态
        currentLyricText = oldLyricText
        isShowingLyrics = oldIsShowing
        print("测试结束")
    end)
end, false)

-- 取消测试命令
RegisterCommand('canceltest', function()
    testActive = false
end, false)

-- 添加命令：在玩家位置上方显示测试歌词
RegisterCommand('testlyricshere', function(source, args)
    local text = table.concat(args, ' ') or '测试歌词显示'
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- 在玩家位置上方显示歌词
    testActiveHere = true -- 使用全局变量而不是局部变量
    Citizen.CreateThread(function()
        print("开始测试歌词显示在玩家位置")
        print("使用命令 'canceltest' 停止测试")
        
        -- 保存当前状态
        local oldTextValue = currentLyricText
        local oldShowValue = isShowingLyrics
        local oldMusicData = currentMusicData
        
        -- 创建临时DJ台配置
        local testDjTable = {
            lyricsScale = 0.5,
            lyricsFont = 4
        }
        
        -- 每100ms更新一次玩家位置
        while testActiveHere do
            Citizen.Wait(0)
            
            -- 获取最新的玩家位置
            local coords = GetEntityCoords(playerPed)
            -- 在玩家上方2米处显示歌词
            coords = vector3(coords.x, coords.y, coords.z + 2.0)
            
            -- 绘制3D文字
            DrawText3D(coords, text, 255, testDjTable)
        end
        
        -- 恢复原状态
        currentLyricText = oldTextValue
        isShowingLyrics = oldShowValue
        currentMusicData = oldMusicData
        print("测试结束")
    end)
end, false)

-- 添加一个额外测试命令：测试特定高度的歌词显示
RegisterCommand('testlyricsat', function(source, args)
    if #args < 4 then
        print("用法: /testlyricsat <x> <y> <z> <歌词文本>")
        return
    end
    
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local z = tonumber(args[3])
    local text = table.concat(args, ' ', 4) or '测试歌词显示'
    
    if not x or not y or not z then
        print("无效的坐标")
        return
    end
    
    local coords = vector3(x, y, z)
    print("测试坐标: " .. tostring(coords))
    
    -- 在指定位置显示歌词
    testActiveAt = true -- 使用全局变量而不是局部变量
    Citizen.CreateThread(function()
        print("开始测试歌词显示在指定位置")
        print("使用命令 'canceltest' 停止测试")
        
        -- 创建临时DJ台配置
        local testDjTable = {
            lyricsScale = 0.5,
            lyricsFont = 4
        }
        
        while testActiveAt do
            Citizen.Wait(0)
            -- 绘制3D文字
            DrawText3D(coords, text, 255, testDjTable)
        end
        
        print("测试结束")
    end)
end, false)

-- 取消测试命令更新
RegisterCommand('canceltest', function()
    testActive = false
    testActiveHere = false
    testActiveAt = false
    print("所有测试已取消")
end, false)

currentMusicTime = 0
currentMusicDuration = 0

-- 更新当前播放信息
RegisterNUICallback('UpdateTrackInfo', function(data, cb)
    SendNUIMessage({
        action = "timeUpdate",
        currentTime = data.currentTime,
        duration = data.duration
    })
    cb({ success = true })
end)

-- 注册一个持久性的事件处理器，而不是每次都注册新的
RegisterNetEvent('dj:receiveLyricsData')
AddEventHandler('dj:receiveLyricsData', function(lyricsData)
    if lyricsRequestCallback then
        local callback = lyricsRequestCallback
        lyricsRequestCallback = nil
        callback(lyricsData)
    else
        print("Warning: Received lyrics data but no callback is registered")
    end
end)

-- 解析LRC歌词

-- 添加命令：在所有DJ台上同时显示测试文本
RegisterCommand('testalldjbooths', function(source, args)
    local text = table.concat(args, ' ') or '测试歌词显示'
    
    -- 设置全局歌词变量
    currentLyricText = text
    lastLyricUpdateTime = GetGameTimer()
    
    print("已设置所有DJ台显示文本: " .. text)
    print("使用命令 'clearalltext' 清除文本")
end, false)

-- 清除所有DJ台文本
RegisterCommand('clearalltext', function()
    currentLyricText = ""
    print("已清除所有DJ台文本")
end, false)

-- 添加命令：测试单个DJ台
RegisterCommand('testdjbooth', function(source, args)
    if #args < 1 then
        print("用法: /testdjbooth [DJ台ID] [文本]")
        print("可用的DJ台ID:")
        for _, table in pairs(Config.DJTables) do
            print("- " .. table.name)
        end
        return
    end
    
    local djTableId = args[1]
    local text = table.concat(args, ' ', 2) or '测试歌词显示'
    
    -- 查找DJ台
    local djTable = nil
    for _, table in pairs(Config.DJTables) do
        if table.name == djTableId then
            djTable = table
            break
        end
    end
    
    if not djTable then
        print("找不到DJ台: " .. djTableId)
        return
    end
    
    -- 在指定DJ台上显示文本
    testDjBoothActive = true
    testDjBoothId = djTableId
    testDjBoothText = text
    
    Citizen.CreateThread(function()
        print("开始在DJ台 " .. djTableId .. " 上显示文本")
        print("使用命令 'canceltest' 停止测试")
        
        while testDjBoothActive do
            Citizen.Wait(0)
            
            -- 计算位置
            local lyricsHeight = djTable.lyricsHeight or 3.0
            local offsetX = djTable.lyricsOffsetX or 0.0
            local offsetY = djTable.lyricsOffsetY or 0.0
            
            local coords = vector3(
                djTable.coords.x + offsetX, 
                djTable.coords.y + offsetY, 
                djTable.coords.z + lyricsHeight
            )
            
            -- 绘制3D文字
            DrawText3D(coords, testDjBoothText, 255, djTable)
        end
        
        print("测试结束")
    end)
end, false)

-- 取消测试命令更新
RegisterCommand('canceltest', function()
    testActive = false
    testActiveHere = false
    testActiveAt = false
    testDjBoothActive = false
    print("所有测试已取消")
end, false)

-- 添加额外的测试命令：直接设置当前歌词文本
RegisterCommand('setlyric', function(source, args)
    if #args < 1 then
        print("用法: /setlyric <歌词文本>")
        return
    end
    
    local text = table.concat(args, ' ')
    currentLyricText = text
    lastLyricUpdateTime = GetGameTimer()
    isShowingLyrics = true
    
    print("已设置当前歌词为: " .. text)
    print("可以使用 /clearlyric 清除歌词")
end, false)

RegisterCommand('clearlyric', function()
    currentLyricText = ""
    isShowingLyrics = false
    print("已清除当前歌词")
end, false)

-- 添加强制显示歌词命令
RegisterCommand('forcelyrics', function()
    local djTableId = "galaxy_club"  -- 默认使用银河俱乐部DJ台
    local text = "这是一个测试歌词，检查3D渲染"
    
    -- 重置状态
    currentLyricText = text
    isShowingLyrics = true
    lastLyricUpdateTime = GetGameTimer()
    
    print("强制显示歌词: " .. text)
    
    -- 创建一个持续5分钟的临时线程，直接在玩家位置上方显示歌词
    Citizen.CreateThread(function()
        local endTime = GetGameTimer() + (5 * 60 * 1000)  -- 5分钟后结束
        
        while GetGameTimer() < endTime do
            Citizen.Wait(0)
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local aboveCoords = vector3(playerCoords.x, playerCoords.y, playerCoords.z + 1.0)
            
            -- 直接在玩家上方显示
            local testTable = {
                lyricsScale = 0.8,
                lyricsFont = 0
            }
            
            DrawText3D(aboveCoords, text, 255, testTable)
        end
        
        print("强制显示歌词结束")
    end)
end, false)

-- 添加专门用于测试歌词渲染的命令，指定DJ台和精确位置
RegisterCommand('debuglyrics', function(source, args)
    if #args < 1 then
        print("用法: /debuglyrics <DJ台ID>")
        print("例如: /debuglyrics galaxy_club")
        return
    end
    
    local djTableId = args[1]
    local text = "测试歌词渲染 DEBUG"
    
    -- 查找DJ台
    local djTable = nil
    for _, table in pairs(Config.DJTables) do
        if table.name == djTableId then
            djTable = table
            break
        end
    end
    
    if not djTable then
        print("找不到DJ台: " .. djTableId)
        return
    end
    
    print("开始测试指定DJ台的歌词渲染: " .. djTableId)
    
    -- 创建全局变量以便可以取消测试
    debugLyricsActive = true
    
    -- 启动测试线程
    Citizen.CreateThread(function()
        local endTime = GetGameTimer() + (60 * 1000) -- 1分钟后结束
        
        while GetGameTimer() < endTime and debugLyricsActive do
            Citizen.Wait(0)
            
            -- 获取坐标
            local coords = djTable.lyricsCoords or vector3(
                djTable.coords.x, 
                djTable.coords.y,
                djTable.coords.z + (djTable.lyricsHeight or 0.5)
            )
            
            -- 绘制测试文本
            for i = 1, 5 do -- 多次绘制，确保可见
                DrawText3D(coords, text, 255, djTable)
            end
            
            -- 打印调试信息
            if (GetGameTimer() % 1000) < 50 then
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - coords)
                print("DEBUG - 渲染位置: " .. tostring(coords) .. ", 文本: " .. text .. ", 距离: " .. distance)
            end
        end
        
        debugLyricsActive = false
        print("歌词渲染测试结束")
    end)
end, false)

-- 取消测试命令更新，确保包含所有测试变量
RegisterCommand('canceltest', function()
    testActive = false
    testActiveHere = false
    testActiveAt = false
    testDjBoothActive = false
    debugLyricsActive = false
    print("所有测试已取消")
end, false)

-- 添加测试命令
RegisterCommand('testlyrics', function(source, args)
    local text = table.concat(args, ' ') or '测试歌词显示'
    
    -- 设置测试状态
    currentLyricText = text
    isShowingLyrics = true
    currentMusicData = {
        djTableId = 'vanilla_club' -- 使用默认DJ台
    }
    lastLyricUpdateTime = GetGameTimer()
    
    print("开始测试歌词显示")
    print("显示文本: " .. text)
    print("使用 /stoptest 停止测试")
end, false)

RegisterCommand('stoptest', function()
    currentLyricText = ""
    isShowingLyrics = false
    currentMusicData = nil
    print("停止歌词测试")
end, false)

-- 添加歌词开关命令
RegisterCommand('togglelyrics', function(source, args)
    -- 切换全局歌词显示设置
    Config.Lyrics.Enabled = not Config.Lyrics.Enabled
    
    -- 根据切换后的状态输出消息
    if Config.Lyrics.Enabled then
        Config.Notify('歌词显示已启用', 'success')
        print("歌词显示已启用")
    else
        Config.Notify('歌词显示已禁用', 'error')
        print("歌词显示已禁用")
        
        -- 确保关闭当前显示的歌词
        if isShowingLyrics then
            stopLyricsDisplay()
        end
    end
end, false)

-- 添加歌词背景开关命令
RegisterCommand('togglelyricsbackground', function(source, args)
    -- 切换全局歌词背景显示设置
    Config.Lyrics.BackgroundEnabled = not Config.Lyrics.BackgroundEnabled
    
    -- 根据切换后的状态输出消息
    if Config.Lyrics.BackgroundEnabled then
        Config.Notify('歌词背景已启用', 'success')
        print("歌词背景已启用")
    else
        Config.Notify('歌词背景已禁用', 'error')
        print("歌词背景已禁用")
    end
end, false)

-- 添加特定DJ台歌词开关命令
RegisterCommand('toggledjlyrics', function(source, args)
    if #args < 1 then
        print("用法: /toggledjlyrics <DJ台ID>")
        print("例如: /toggledjlyrics galaxy_club")
        
        -- 列出所有DJ台及其状态
        print("可用的DJ台:")
        for _, djTable in pairs(Config.DJTables) do
            local status = djTable.lyricsEnabled ~= false and "启用" or "禁用"
            print(" - " .. djTable.name .. " (" .. djTable.label .. "): " .. status)
        end
        return
    end
    
    local djTableId = args[1]
    
    -- 查找DJ台
    local djTable = nil
    for _, table in pairs(Config.DJTables) do
        if table.name == djTableId then
            djTable = table
            break
        end
    end
    
    if not djTable then
        Config.Notify('找不到DJ台: ' .. djTableId, 'error')
        print("找不到DJ台: " .. djTableId)
        return
    end
    
    -- 切换该DJ台的歌词显示设置
    djTable.lyricsEnabled = not (djTable.lyricsEnabled == true)
    
    -- 根据切换后的状态输出消息
    if djTable.lyricsEnabled then
        Config.Notify(djTable.label .. ' 歌词显示已启用', 'success')
        print(djTable.label .. " 歌词显示已启用")
    else
        Config.Notify(djTable.label .. ' 歌词显示已禁用', 'error')
        print(djTable.label .. " 歌词显示已禁用")
        
        -- 如果当前正在此DJ台播放歌曲，停止显示歌词
        if isShowingLyrics and currentMusicData and currentMusicData.djTableId == djTableId then
            stopLyricsDisplay()
        end
    end
end, false)

-- 兼容处理旧版事件
RegisterNetEvent('dj:zantings')
AddEventHandler('dj:zantings', function(musicInstanceId)
    -- 直接转发到新的事件处理器
    TriggerEvent('dj:pauseMusic', musicInstanceId)
    print("Legacy event 'dj:zantings' received, forwarding to 'dj:pauseMusic' for: " .. tostring(musicInstanceId))
end)

RegisterNetEvent('dj:bofangs')
AddEventHandler('dj:bofangs', function(musicInstanceId)
    -- 直接转发到新的事件处理器
    TriggerEvent('dj:resumeMusic', musicInstanceId)
    print("Legacy event 'dj:bofangs' received, forwarding to 'dj:resumeMusic' for: " .. tostring(musicInstanceId))
end)

-- 监听来自服务器的设置声音事件
RegisterNetEvent("dj:setVolumes")
AddEventHandler("dj:setVolumes", function(name, volume)
    -- 确保参数有效
    if not name then
        print("^1[DJ系统] 错误：接收音量事件缺少音乐名称^0")
        return
    end
    
    if volume == nil then
        print("^1[DJ系统] 错误：接收音量事件缺少音量值^0")
        return
    end
    
    -- 格式化音量
    volume = tonumber(volume)
    if not volume then
        print("^1[DJ系统] 错误：接收音量值不是有效数字^0")
        return
    end
    
    -- 确保音量在0-1范围内
    if volume > 1 then
        volume = volume / 100
    end
    volume = math.max(0.0, math.min(1.0, volume))
    
    print("^2[DJ系统] 接收到音量同步事件: " .. name .. " = " .. tostring(volume) .. "^0")
    
    if exports['xsound']:soundExists(name) then
        -- 保存音量设置
        currentVolumes[name] = volume
        
        -- 更新音量
        exports['xsound']:setVolume(name, volume)
        print("^2[DJ系统] 成功更新音量^0")
        
        -- 发送音量更新事件到前端
        SendNUIMessage({
            action = "volumeUpdated",
            volume = volume * 100,
            name = name
        })
    else
        print("^3[DJ系统] 警告：找不到音乐实例，无法设置音量: " .. name .. "^0")
    end
end)
