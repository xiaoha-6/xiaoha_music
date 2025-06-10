-- 获取当前资源路径下的 MP3 文件夹
local resourcePath = GetResourcePath(GetCurrentResourceName()) .. "/mp3"

-- 框架检测和初始化
local QBCore = nil
local ESX = nil
local isQBCore = false

Citizen.CreateThread(function()
    if GetResourceState('es_extended') ~= 'missing' then
        ESX = exports['es_extended']:getSharedObject()
        print("^2[DJ系统] 检测到ESX框架，已初始化^0")
    elseif GetResourceState('qb-core') ~= 'missing' then
        QBCore = exports['qb-core']:GetCoreObject()
        isQBCore = true
        print("^2[DJ系统] 检测到QB-Core框架，已初始化^0")
    else
        print("^1[DJ系统] 警告: 未检测到支持的框架(ESX或QB-Core)，部分功能可能无法正常工作^0")
    end
end)

-- 获取玩家信息的辅助函数
local function GetPlayerData(source)
    local src = source
    local playerData = {
        source = src,
        identifier = nil,
        name = nil
    }
    
    if isQBCore and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            playerData.identifier = Player.PlayerData.citizenid
            playerData.name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        end
    elseif ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            playerData.identifier = xPlayer.identifier
            playerData.name = xPlayer.getName()
        end
    else
        -- 如果没有检测到框架，使用默认标识符
        playerData.identifier = "steam:" .. src
        playerData.name = GetPlayerName(src) or "未知玩家"
    end
    
    return playerData
end

-- 导出GetIoLib函数以便客户端可以调用io.js功能
exports('GetIoLib', function()
    return exports['sandbox-patches']:GetIoLib()
end)

-- 处理歌词文件保存的服务器端事件
RegisterNetEvent('dj:saveLyricsToFile', function(fileName, content)
    local src = source
    
    -- 构建文件路径 (保存在resources/[DJ]/xiaoha_music/lyrics目录)
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local lyricsDir = resourcePath .. "/lyrics"
    local filePath = lyricsDir .. "/" .. fileName
    
    print("Attempting to save lyrics to: " .. filePath)
    
    -- 使用io.js保存文件（包括目录创建）
    local ioLib = exports['sandbox-patches']:GetIoLib()
    if not ioLib or not ioLib.saveLyricsFile then
        print("Error: ioLib or saveLyricsFile function not found")
        TriggerClientEvent('dj:notify', src, '保存歌词失败: IO库不可用', 'error')
        return
    end
    
    local result = ioLib.saveLyricsFile(nil, filePath, content)
    
    if result and result.success then
        print("Lyrics saved successfully to: " .. filePath)
        TriggerClientEvent('dj:notify', src, '歌词保存成功', 'success')
    else
        local errorMsg = result and result.error or "Unknown error"
        print("Error saving lyrics file: " .. errorMsg)
        TriggerClientEvent('dj:notify', src, '保存歌词失败: ' .. errorMsg, 'error')
    end
end)

-- 从文件读取歌词数据的服务器端事件
RegisterNetEvent('dj:getLyricsFromFile', function(songId, songName)
    local src = source
    
    -- 构建文件名
    local fileName = songId .. "_" .. string.gsub(songName, "[^%w]", "") .. ".json"
    
    -- 构建文件路径
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local lyricsDir = resourcePath .. "/lyrics"
    local filePath = lyricsDir .. "/" .. fileName
    
    print("Looking for lyrics file: " .. filePath)
    
    -- 尝试打开并读取文件
    local ioLib = exports['sandbox-patches']:GetIoLib()
    if not ioLib then
        print("Error: io library not found")
        TriggerClientEvent('dj:receiveLyricsData', src, nil)
        return
    end
    
    -- 检查文件是否存在
    local fileHandle = ioLib.open(nil, filePath, "r")
    if not fileHandle then
        print("Lyrics file not found: " .. filePath)
        TriggerClientEvent('dj:receiveLyricsData', src, nil)
        return
    end
    
    -- 读取文件内容
    local content = ioLib.read(fileHandle, "*a")
    ioLib.close(nil, fileHandle)
    
    if not content then
        print("Error reading lyrics file content")
        TriggerClientEvent('dj:receiveLyricsData', src, nil)
        return
    end
    
    print("Read lyrics file content: " .. string.sub(content, 1, 50) .. "...")
    
    -- 解析JSON内容
    local success, lyricsData = pcall(function()
        -- 如果内容以hex:开头，需要转换
        if string.sub(content, 1, 4) == "hex:" then
            content = string.sub(content, 5)
            -- 将hex转换为普通字符串
            content = (content:gsub('..', function(cc)
                return string.char(tonumber(cc, 16))
            end))
        end
        
        -- 尝试解析JSON
        local parsed = json.decode(content)
        print("Successfully parsed JSON data for: " .. songName)
        return parsed
    end)
    
    if success and lyricsData then
        print("Lyrics file loaded successfully for " .. songName .. " with " .. (lyricsData.lrc and string.len(lyricsData.lrc) or 0) .. " bytes of lyrics")
        TriggerClientEvent('dj:receiveLyricsData', src, lyricsData)
    else
        print("Error parsing lyrics JSON data: " .. tostring(lyricsData))
        TriggerClientEvent('dj:receiveLyricsData', src, nil)
    end
end)

-- 函数用于从API获取歌曲信息（包括封面）
local function getSongInfo(songId, callback)
    if not songId then return callback(nil) end
    
    local apiUrl = "https://api.qijieya.cn/meting/?type=song&id=" .. songId
    
    PerformHttpRequest(apiUrl, function(statusCode, response, headers)
        if statusCode ~= 200 then
            print("Error fetching song info: Status code " .. statusCode)
            return callback(nil)
        end
        
        local success, data = pcall(json.decode, response)
        if not success or not data then
            print("Error parsing song info response: " .. tostring(response))
            return callback(nil)
        end
        
        callback(data)
    end, "GET", "", {
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "Mozilla/5.0"
    })
end

RegisterNetEvent("dj:fetchMusicData")
AddEventHandler("dj:fetchMusicData", function(query)
    local src = source
    local useNewFormat = false
    
    if type(query) == "table" then
        useNewFormat = query.useNewFormat
        query = query.search
    end

    if not query then
        print("Error: No search query provided")
        return
    end

    PerformHttpRequest(query, function(statusCode, response, headers)
        print("API Response Status:", statusCode)

        if statusCode ~= 200 then
            print("Error: HTTP request failed with status code:", statusCode)
            return
        end

        -- 解析响应数据
        local success, data = pcall(json.decode, response)
        if not success or not data then
            print("Error: Failed to parse API response")
        TriggerClientEvent("dj:receiveMusicData", src, response)
            return
        end
        
        -- 检查是否有歌曲数据
        if data and data.result and data.result.songs then
            local songsToProcess = #data.result.songs
            local processedSongs = 0
            
            -- 没有歌曲的情况下直接返回原始响应
            if songsToProcess == 0 then
                TriggerClientEvent("dj:receiveMusicData", src, response)
                return
            end
            
            -- 为每首歌添加封面和API URL
            for i, song in ipairs(data.result.songs) do
                if song.id then
                    -- 为每首歌添加新API URL
                    song.api_url = "https://api.qijieya.cn/meting/?server=netease&type=url&id=" .. song.id
                    song.api_lrc = "https://api.qijieya.cn/meting/?server=netease&type=lrc&id=" .. song.id
                    song.api_pic = "https://api.qijieya.cn/meting/?server=netease&type=pic&id=" .. song.id
                    
                    -- 获取歌曲完整信息，包括封面
                    local apiUrl = "https://api.qijieya.cn/meting/?server=netease&type=song&id=" .. song.id
                    
                    PerformHttpRequest(apiUrl, function(songStatusCode, songResponse, songHeaders)
                        processedSongs = processedSongs + 1
                        
                        if songStatusCode == 200 then
                            local songSuccess, songData = pcall(json.decode, songResponse)
                            
                            if songSuccess and songData and songData[1] and songData[1].pic then
                                -- 将封面URL直接添加到歌曲数据中
                                print("Got cover pic from API for " .. song.name .. ": " .. songData[1].pic)
                                if not song.picUrl then
                                    song.picUrl = songData[1].pic
                                end
                                
                                -- 也将封面添加到album对象中
                                if song.album and not song.album.picUrl then
                                    song.album.picUrl = songData[1].pic
                                elseif not song.album then
                                    song.album = {picUrl = songData[1].pic, name = songData[1].name or ""}
                                end
                            else
                                print("Failed to parse song data or no pic available for song: " .. song.name)
                            end
                        else
                            print("Error fetching song data: Status code " .. songStatusCode .. " for song: " .. song.name)
                        end
                        
                        -- 当所有歌曲处理完毕后发送响应
                        if processedSongs >= songsToProcess then
                            local updatedResponse = json.encode(data)
                            print("Sending processed music data to client")
                            TriggerClientEvent("dj:receiveMusicData", src, updatedResponse)
                        end
                    end, "GET", "", {
                        ["Content-Type"] = "application/json",
                        ["User-Agent"] = "Mozilla/5.0"
                    })
                else
                    -- 没有ID的歌曲直接计数
                    processedSongs = processedSongs + 1
                    
                    -- 检查是否所有歌曲都已处理
                    if processedSongs >= songsToProcess then
                        local updatedResponse = json.encode(data)
                        TriggerClientEvent("dj:receiveMusicData", src, updatedResponse)
                    end
                end
            end
        else
            -- 如果没有标准格式的歌曲数据，直接返回原始响应
            TriggerClientEvent("dj:receiveMusicData", src, response)
        end
    end, "GET", "", {
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "Mozilla/5.0"
    })
end)

RegisterNetEvent("dj:playMusicData")
AddEventHandler("dj:playMusicData", function(data)
    print('音乐开始播放，链接' .. data.url)
    local src = source

    if not data.url or not data.name or not data.djTableId then
        Config.Debug.Print("Missing required parameters for music playback", Config.Debug.Levels.Error)
        Config.Notify(src, '播放失败：缺少必要信息', 'error')
        return
    end

    -- 广播给所有客户端
    TriggerClientEvent("dj:playMusic", -1, data.url, data.name, data.djTableId, data.volume or 0.7, data.duration or 0)
end)

RegisterNetEvent("dj:playlocalMusic")
AddEventHandler("dj:playlocalMusic", function(name, url, djTableId, volume)
    local src = source

    if not name or not url or not djTableId then
        print("Error: Missing required parameters for local music playback")
        return
    end

    if not url:match("^nui://") then
        print("Error: Invalid local music URL format")
        return
    end

    -- 广播给所有客户端
    TriggerClientEvent("dj:playMusic", -1, url, name, djTableId, volume or 0.7)
end)

RegisterNetEvent("dj:zanting")
AddEventHandler("dj:zanting", function(name)
    if not name then return end
    -- 统一使用新的暂停事件
    TriggerClientEvent("dj:pauseMusic", -1, name)
    print("^2[DJ系统] 歌曲已暂停: " .. name .. "^0")
end)

RegisterNetEvent("dj:bofang")
AddEventHandler("dj:bofang", function(name)
    if not name then return end
    -- 统一使用新的恢复播放事件
    TriggerClientEvent("dj:resumeMusic", -1, name)
    print("^2[DJ系统] 歌曲已恢复播放: " .. name .. "^0")
end)

RegisterNetEvent("dj:setVolume")
AddEventHandler("dj:setVolume", function(name, volume)
    local src = source
    
    if not name then 
        print("^1[DJ系统] 错误：音量控制缺少音乐实例名称^0")
        return 
    end
    
    if not volume then
        print("^1[DJ系统] 错误：音量控制缺少音量值^0")
        return
    end
    
    -- 确保音量在有效范围内
    volume = tonumber(volume)
    if not volume then
        print("^1[DJ系统] 错误：音量值不是有效数字^0")
        return
    end
    
    -- 如果音量大于1，假定是百分比(0-100)，转换为0-1
    if volume > 1 then
        volume = volume / 100
    end
    
    -- 限制音量在0-1范围
    volume = math.max(0.0, math.min(1.0, volume))
    
    print("^2[DJ系统] 设置音量: " .. name .. " = " .. tostring(volume) .. "^0")
    
    -- 检查哪个DJ台在播放该歌曲
    local djTableId = name:match("([^_]+_[^_]+)_")
    if djTableId then
        -- 如果找到了相关DJ台，确保音量设置被保存
        if activeDJTables[djTableId] and activeDJTables[djTableId].musicData then
            activeDJTables[djTableId].musicData.volume = volume
            print("^2[DJ系统] 更新DJ台 " .. djTableId .. " 的音量设置^0")
        end
    end
    
    -- 广播给所有客户端更新音量
    TriggerClientEvent("dj:setVolumes", -1, name, volume)
end)

-- 遍历指定目录，获取 MP3 文件信息
local function getMP3Files(directory)
    if not directory then
        Config.Debug.Print("Directory path is nil", Config.Debug.Levels.Error)
        return {}
    end

    directory = string.gsub(directory, "//", "/")
    Config.Debug.Print("Scanning directory: " .. directory, Config.Debug.Levels.Info)

    local mp3Files = {}

    local handle = io.popen('dir "' .. directory .. '" /b')
    if not handle then
        Config.Debug.Print("Failed to open directory: " .. directory, Config.Debug.Levels.Error)
        return {}
    end

    local fileCount = 0
    for file in handle:lines() do
        if file:match("%.mp3$") then
            fileCount = fileCount + 1
            local path = "nui://" .. GetCurrentResourceName() .. "/mp3/" .. file
            Config.Debug.Print("Found MP3 file: " .. file .. " -> " .. path, Config.Debug.Levels.Debug)

            table.insert(mp3Files, {
                name = file:gsub("%.mp3$", ""),
                hash = tostring(math.random(100000, 999999)),
                img = "https://via.placeholder.com/50",
                path = path
            })
        end
    end

    handle:close()
    Config.Debug.Print("Total MP3 files found: " .. fileCount, Config.Debug.Levels.Info)
    return mp3Files
end

-- 修改生成 HTML 字符串函数
local function generateHTML(mp3Files)
    if not mp3Files or #mp3Files == 0 then
        print("Warning: No MP3 files found to generate HTML")
        return ""
    end

    local htmlString = ""
    for i, track in ipairs(mp3Files) do
        if track.name and track.path then
            htmlString = htmlString .. string.format(
                '<div class="list-item" data-name="%s" data-url="%s" data-type="1" data-duration="0"><img src="%s" alt="封面"><div class="music-info"><span>%s</span></div><div class="music-controls"><i class="fas fa-play music-icon"></i></div></div>',
                track.name,
                track.path,
                track.img or "https://via.placeholder.com/50",
                track.name
            )
        end
    end
    return htmlString
end

-- 注册 FiveM 事件供客户端调用
RegisterNetEvent("dj:localMusicData")
AddEventHandler("dj:localMusicData", function()
    local src = source

    -- 获取 MP3 文件列表
    local mp3Files = getMP3Files(resourcePath)

    -- 生成 HTML
    local htmlString = generateHTML(mp3Files)
    -- print(htmlString)

    -- 发送 HTML 到客户端
    TriggerClientEvent("dj:receiveMP3ListHTML", src, htmlString)
end)

-- CreateThread(function()
--     local latest = false
--     local function Trim(value)
--         if value then
--             return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
--         else
--             return nil
--         end
--     end
--     while not latest do
--         local resource = 'xiaoha_DJ'
--         local search = 'DJ 台'

--         PerformHttpRequest("https://raw.gitcode.com/qq_55622586/genxin/raw/main/" .. resource,
--             function(err, Version, headers)
--                 if Version and type(Version) == 'string' then
--                     local ScriptVersion = GetResourceMetadata(resource, "version", 0)
--                     Version = Trim(Version)

--                     if ScriptVersion == Version then
--                         print("^2[通知] " .. resource .. " 已经是最新版本！^0")
--                         latest = true
--                     else
--                         print("^3[心晴提醒您] " .. resource .. " 有可用更新！ (" .. ScriptVersion .. " -> " .. Version .. ")")
--                         print("^3[心晴提醒您] https://keymaster.fivem.net/asset-grants?search=" .. search .. "^0")
--                     end
--                 else
--                     print("^3[Warning] Unable to get the version from GitHub.^0")
--                 end
--             end)
--         Wait(60 * 1000)
--     end
-- end)

-- 修改数据库初始化函数
local function CheckAndUpdateDatabaseSchema()
    -- 检查表是否存在
    MySQL.query("SHOW TABLES LIKE 'dj_comments'", {}, function(result)
        if not result or #result == 0 then
            -- 表不存在，创建表
            local createTableQuery = [[
                CREATE TABLE IF NOT EXISTS `dj_comments` (
                    `id` int(11) NOT NULL AUTO_INCREMENT,
                    `song_id` text NOT NULL,
                    `user_identifier` varchar(100) NOT NULL,
                    `user_name` varchar(100) NOT NULL,
                    `content` text NOT NULL,
                    `likes` int(11) DEFAULT 0,
                    `created_at` timestamp NULL DEFAULT current_timestamp(),
                    `song_name` varchar(100) NOT NULL,
                    `song_artist` varchar(100) NOT NULL,
                    PRIMARY KEY (`id`),
                    KEY `idx_song_id` (`song_id`(768))
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin
            ]]

            MySQL.query(createTableQuery, {}, function(success)
                if success then
                    print("^2[DJ系统] 评论数据表创建成功！^0")
                else
                    print("^1[DJ系统] 评论数据表创建失败！^0")
                end
            end)
        else
            print("^3[DJ系统] 检测到评论数据表已存在，正在检查字段...^0")
            -- 表已存在，检查并更新列
            MySQL.query("SHOW COLUMNS FROM dj_comments", {}, function(columns)
                if columns then
                    local existingColumns = {}
                    for _, column in ipairs(columns) do
                        existingColumns[column.Field] = true
                    end

                    -- 检查并添加缺失的列
                    local requiredColumns = {
                        { name = "id", type = "int(11) NOT NULL AUTO_INCREMENT", desc = "ID字段" },
                        { name = "song_id", type = "text NOT NULL", desc = "歌曲ID" },
                        { name = "user_identifier", type = "varchar(100) NOT NULL", desc = "用户标识" },
                        { name = "user_name", type = "varchar(100) NOT NULL", desc = "用户名" },
                        { name = "content", type = "text NOT NULL", desc = "评论内容" },
                        { name = "likes", type = "int(11) DEFAULT 0", desc = "点赞数" },
                        { name = "created_at", type = "timestamp NULL DEFAULT current_timestamp()", desc = "创建时间" },
                        { name = "song_name", type = "varchar(100) NOT NULL", desc = "歌曲名称" },
                        { name = "song_artist", type = "varchar(100) NOT NULL", desc = "歌手名称" }
                    }

                    local missingColumns = {}
                    for _, column in ipairs(requiredColumns) do
                        if not existingColumns[column.name] then
                            table.insert(missingColumns, column)
                            local alterQuery = string.format(
                                "ALTER TABLE dj_comments ADD COLUMN `%s` %s",
                                column.name,
                                column.type
                            )
                            MySQL.query(alterQuery)
                        end
                    end

                    if #missingColumns > 0 then
                        print("^3[DJ系统] 检测到缺失字段，已自动修复：^0")
                        for _, column in ipairs(missingColumns) do
                            print("^2[DJ系统] 添加字段: " .. column.desc .. " (" .. column.name .. ")^0")
                        end
                    else
                        print("^2[DJ系统] 所有字段检查完成，数据表结构完整！^0")
                    end

                    -- 检查索引
                    MySQL.query("SHOW INDEX FROM dj_comments WHERE Key_name = 'idx_song_id'", {},
                        function(indices)
                            if not indices or #indices == 0 then
                                -- 创建索引
                                MySQL.query([[
                                    CREATE INDEX `idx_song_id` ON `dj_comments` (`song_id`(768))
                                ]], {}, function(success)
                                    if success then
                                        print("^2[DJ系统] 歌曲ID索引创建成功！^0")
                                    else
                                        print("^1[DJ系统] 歌曲ID索引创建失败！^0")
                                    end
                                end)
                            end
                        end
                    )
                end
            end)
        end
    end)

    -- 检查最近播放表
    MySQL.query("SHOW TABLES LIKE 'dj_recent_plays'", {}, function(result)
        if not result or #result == 0 then
            -- 表不存在，创建表
            local createTableQuery = [[
                CREATE TABLE IF NOT EXISTS `dj_recent_plays` (
                    `id` int(11) NOT NULL AUTO_INCREMENT,
                    `dj_table_id` varchar(50) NOT NULL,
                    `song_name` varchar(255) NOT NULL,
                    `song_artist` varchar(255) DEFAULT '未知艺术家',
                    `song_album` varchar(255) DEFAULT '未知专辑',
                    `song_duration` varchar(50) DEFAULT NULL,
                    `song_avatar` varchar(255) DEFAULT NULL,
                    `song_url` text NOT NULL,
                    `played_at` timestamp NULL DEFAULT current_timestamp(),
                    `player_identifier` varchar(50) NOT NULL,
                    `player_name` varchar(100) DEFAULT NULL,
                    PRIMARY KEY (`id`),
                    KEY `idx_dj_table` (`dj_table_id`),
                    KEY `idx_player` (`player_identifier`),
                    KEY `idx_played_at` (`played_at`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]]

            MySQL.query(createTableQuery, {}, function(success)
                if success then
                    print("^2[DJ系统] 最近播放数据表创建成功！^0")
                else
                    print("^1[DJ系统] 最近播放数据表创建失败！^0")
                end
            end)
        else
            print("^3[DJ系统] 检测到最近播放数据表已存在，正在检查字段...^0")
            -- 检查并更新列
            MySQL.query("SHOW COLUMNS FROM dj_recent_plays", {}, function(columns)
                if columns then
                    local existingColumns = {}
                    for _, column in ipairs(columns) do
                        existingColumns[column.Field] = true
                    end

                    -- 检查并添加缺失的列
                    local requiredColumns = {
                        { name = "id", type = "int(11) NOT NULL AUTO_INCREMENT", desc = "ID字段" },
                        { name = "dj_table_id", type = "varchar(50) NOT NULL", desc = "DJ台ID" },
                        { name = "song_name", type = "varchar(255) NOT NULL", desc = "歌曲名称" },
                        { name = "song_artist", type = "varchar(255) DEFAULT '未知艺术家'", desc = "歌手名称" },
                        { name = "song_album", type = "varchar(255) DEFAULT '未知专辑'", desc = "专辑名称" },
                        { name = "song_duration", type = "varchar(50) DEFAULT NULL", desc = "歌曲时长" },
                        { name = "song_avatar", type = "varchar(255) DEFAULT NULL", desc = "歌曲封面" },
                        { name = "song_url", type = "text NOT NULL", desc = "歌曲链接" },
                        { name = "played_at", type = "timestamp NULL DEFAULT current_timestamp()", desc = "播放时间" },
                        { name = "player_identifier", type = "varchar(50) NOT NULL", desc = "玩家标识" },
                        { name = "player_name", type = "varchar(100) DEFAULT NULL", desc = "玩家名称" }
                    }

                    local missingColumns = {}
                    for _, column in ipairs(requiredColumns) do
                        if not existingColumns[column.name] then
                            table.insert(missingColumns, column)
                            local alterQuery = string.format(
                                "ALTER TABLE dj_recent_plays ADD COLUMN `%s` %s",
                                column.name,
                                column.type
                            )
                            MySQL.query(alterQuery)
                        end
                    end

                    if #missingColumns > 0 then
                        print("^3[DJ系统] 最近播放表检测到缺失字段，已自动修复：^0")
                        for _, column in ipairs(missingColumns) do
                            print("^2[DJ系统] 添加字段: " .. column.desc .. " (" .. column.name .. ")^0")
                        end
                    else
                        print("^2[DJ系统] 最近播放表所有字段检查完成，数据表结构完整！^0")
                    end

                    -- 检查索引
                    MySQL.query("SHOW INDEX FROM dj_recent_plays", {}, function(indices)
                        local existingIndices = {}
                        for _, index in ipairs(indices) do
                            existingIndices[index.Key_name] = true
                        end

                        -- 需要的索引列表
                        local requiredIndices = {
                            { name = "idx_dj_table", columns = "dj_table_id" },
                            { name = "idx_player", columns = "player_identifier" },
                            { name = "idx_played_at", columns = "played_at" }
                        }

                        -- 添加缺失的索引
                        for _, index in ipairs(requiredIndices) do
                            if not existingIndices[index.name] then
                                MySQL.query(string.format(
                                    "CREATE INDEX `%s` ON `dj_recent_plays` (`%s`)",
                                    index.name,
                                    index.columns
                                ))
                                print("^2[DJ系统] 创建索引: " .. index.name .. "^0")
                            end
                        end
                    end)
                end
            end)
        end
    end)
end

-- 数据库初始化
local function InitializeDatabase()
    -- 直接调用检查和更新函数
    Citizen.CreateThread(function()
        -- 等待一下确保MySQL已经准备好
        Citizen.Wait(1000)
        CheckAndUpdateDatabaseSchema()
    end)
end

-- 在资源启动时初始化数据库
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    print("Initializing DJ database...")
    InitializeDatabase()
end)

-- 添加资源停止时的处理
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    print("Stopping DJ database...")
end)

-- 修改评论相关的数据库操作
RegisterNetEvent('dj:addComment')
AddEventHandler('dj:addComment', function(songId, songName, songArtist, content)
    local src = source
    local playerData = GetPlayerData(src)

    if not playerData.identifier then
        TriggerClientEvent('dj:notify', src, '无法获取玩家信息', 'error')
        return
    end

    -- 基本的内容验证
    if not songId or not songName or not songArtist or not content or content:len() < 1 or content:len() > 500 then
        TriggerClientEvent('dj:notify', src, '评论内容无效', 'error')
        return
    end

    -- 确保数据库表和字段存在
    CheckAndUpdateDatabaseSchema()

    -- 添加评论到数据库
    MySQL.insert(
        'INSERT INTO dj_comments (song_id, song_name, song_artist, user_identifier, user_name, content) VALUES (?, ?, ?, ?, ?, ?)',
        { songId, songName, songArtist, playerData.identifier, playerData.name, content },
        function(id)
            if id then
                TriggerClientEvent('dj:notify', src, '评论发送成功', 'success')
                -- 获取并发送最新评论
                MySQL.query('SELECT * FROM dj_comments WHERE song_id = ? ORDER BY created_at DESC LIMIT 50',
                    { songId },
                    function(comments)
                        if comments then
                            TriggerClientEvent('dj:updateComments', src, comments)
                        end
                    end
                )
            else
                TriggerClientEvent('dj:notify', src, '评论发送失败', 'error')
            end
        end
    )
end)

-- 获取评论
RegisterNetEvent('dj:getComments')
AddEventHandler('dj:getComments', function(songId)
    local src = source

    MySQL.query('SELECT * FROM dj_comments WHERE song_id = ? ORDER BY created_at DESC LIMIT 50',
        { songId },
        function(comments)
            if comments then
                TriggerClientEvent('dj:updateComments', src, comments)
            end
        end
    )
end)

-- 点赞评论
RegisterNetEvent('dj:likeComment')
AddEventHandler('dj:likeComment', function(commentId)
    local src = source
    local playerData = GetPlayerData(src)

    if not playerData.identifier then return end

    MySQL.update('UPDATE dj_comments SET likes = likes + 1 WHERE id = ?',
        { commentId },
        function(affectedRows)
            if affectedRows > 0 then
                -- 获取评论所属的歌曲ID并更新评论列表
                MySQL.query('SELECT song_id FROM dj_comments WHERE id = ?', { commentId },
                    function(result)
                        if result and result[1] then
                            MySQL.query('SELECT * FROM dj_comments WHERE song_id = ? ORDER BY created_at DESC LIMIT 50',
                                { result[1].song_id },
                                function(comments)
                                    if comments then
                                        TriggerClientEvent('dj:updateComments', src, comments)
                                    end
                                end
                            )
                        end
                    end
                )
            end
        end
    )
end)

-- 修改获取最近播放列表的函数
RegisterNetEvent('dj:getRecentPlays')
AddEventHandler('dj:getRecentPlays', function(data)
    local src = source
    local playerData = GetPlayerData(src)
    
    if not playerData.identifier then return end
    
    local page = tonumber(data.page) or 1
    local pageSize = tonumber(data.pageSize) or 10
    local offset = (page - 1) * pageSize
    local djTableId = data.djTableId
    local timeFilter = data.timeFilter or 'all'

    -- 构建时间过滤条件
    local timeCondition = ""
    if timeFilter == '24h' then
        timeCondition = "AND played_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)"
    elseif timeFilter == '7d' then
        timeCondition = "AND played_at > DATE_SUB(NOW(), INTERVAL 7 DAY)"
    elseif timeFilter == '30d' then
        timeCondition = "AND played_at > DATE_SUB(NOW(), INTERVAL 30 DAY)"
    end

    -- 首先获取总数
    MySQL.Async.fetchScalar(string.format([[
        SELECT COUNT(*) FROM dj_recent_plays 
        WHERE dj_table_id = ? %s
    ]], timeCondition), {djTableId}, function(total)
        -- 然后获取分页数据
        MySQL.Async.fetchAll(string.format([[
            SELECT * FROM dj_recent_plays 
            WHERE dj_table_id = ? %s
            ORDER BY played_at DESC 
            LIMIT ? OFFSET ?
        ]], timeCondition), {djTableId, pageSize, offset}, function(results)
            if results then
                TriggerClientEvent('dj:receiveRecentPlays', src, {
                    items = results,
                    total = total or 0,
                    page = page,
                    pageSize = pageSize
                })
            else
                TriggerClientEvent('dj:receiveRecentPlays', src, {
                    items = {},
                    total = 0,
                    page = 1,
                    pageSize = pageSize
                })
            end
        end)
    end)
end)

-- 修改添加播放记录的函数
RegisterNetEvent('dj:addToRecentPlays')
AddEventHandler('dj:addToRecentPlays', function(djTableId, songData)
    local src = source
    local playerData = GetPlayerData(src)
    
    if not playerData.identifier then 
        print("Error: Player not found for recent plays")
        return 
    end

    if not djTableId or not songData then
        print("Error: Missing data for recent plays")
        return
    end

    -- 检查是否已存在相同记录（防止重复）
    MySQL.Async.fetchAll([[
        SELECT id FROM dj_recent_plays 
        WHERE dj_table_id = ? AND song_name = ? AND player_identifier = ?
        AND played_at > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
    ]], {
        djTableId,
        songData.name,
        playerData.identifier
    }, function(results)
        if results and #results > 0 then
            print("^3[DJ系统] 检测到重复播放记录，跳过记录^0")
            return
        end

        -- 插入新记录
        MySQL.Async.execute([[
            INSERT INTO dj_recent_plays 
            (dj_table_id, song_name, song_artist, song_album, song_duration, song_avatar, song_url, player_identifier, player_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            djTableId,
            songData.name,
            songData.artist or "未知艺术家",
            songData.album or "未知专辑",
            songData.duration or "",
            songData.avatar or "",
            songData.url,
            playerData.identifier,
            playerData.name
        }, function(rowsChanged)
            if rowsChanged > 0 then
                print(string.format("^2[DJ系统] 记录播放历史成功：%s - %s^0", songData.name, djTableId))
                -- 获取并发送最新的播放记录（第一页）
                MySQL.Async.fetchScalar([[
                    SELECT COUNT(*) FROM dj_recent_plays 
                    WHERE dj_table_id = ?
                ]], {djTableId}, function(total)
                    MySQL.Async.fetchAll([[
                        SELECT * FROM dj_recent_plays 
                        WHERE dj_table_id = ? 
                        ORDER BY played_at DESC 
                        LIMIT 10
                    ]], {djTableId}, function(results)
                        TriggerClientEvent('dj:receiveRecentPlays', src, {
                            items = results or {},
                            total = total or 0,
                            page = 1,
                            pageSize = 10
                        })
                    end)
                end)
            else
                print(string.format("^1[DJ系统] 记录播放历史失败：%s - %s^0", songData.name, djTableId))
            end
        end)
    end)
end)

-- 添加播放音乐事件处理
RegisterNetEvent("dj:playMusic")
AddEventHandler("dj:playMusic", function(data)
    local src = source
    local playerData = GetPlayerData(src)
    
    if not playerData.identifier then 
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
            -- 停止当前播放的音乐
            clearDJTable(data.djTableId)
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

-- 跟踪每个DJ台的状态
local activeDJTables = {}

-- 检查DJ台是否被占用
local function isDJTableOccupied(djTableId)
    return activeDJTables[djTableId] ~= nil
end

-- 清理DJ台状态
local function clearDJTable(djTableId)
    if activeDJTables[djTableId] then
        activeDJTables[djTableId] = nil
        TriggerClientEvent('dj:stopMusicForAll', -1, djTableId)
    end
end

-- 添加音乐同步事件处理
RegisterNetEvent('dj:syncMusic')
AddEventHandler('dj:syncMusic', function(musicData)
    local src = source
    local playerData = GetPlayerData(src)
    
    if not playerData.identifier then 
        print("^1[DJ系统] 错误：无法获取玩家信息^0")
        return 
    end
    
    if not musicData.url or not musicData.name or not musicData.djTableId then
        print("^1[DJ系统] 错误：缺少必要的音乐信息^0")
        return
    end

    -- 停止其他DJ台正在播放的音乐
    for djTableId, data in pairs(activeDJTables) do
        if data.djId == src then
            clearDJTable(djTableId)
        end
    end

    -- 更新DJ台状态
    activeDJTables[musicData.djTableId] = {
        djId = src,
        musicData = musicData,
        timestamp = os.time()
    }

    print("^2[DJ系统] 正在广播音乐到所有客户端: " .. musicData.name .. "^0")
    
    -- 广播给所有客户端，包括发送消息的客户端
    TriggerClientEvent('dj:playMusicForAll', -1, musicData)
end)

-- 添加停止音乐事件处理
RegisterNetEvent('dj:stopMusic')
AddEventHandler('dj:stopMusic', function(djTableId)
    local src = source
    local playerData = GetPlayerData(src)
    
    if not playerData.identifier then return end

    -- 检查是否是当前DJ
    if activeDJTables[djTableId] and activeDJTables[djTableId].djId == src then
        clearDJTable(djTableId)
    end
end)

-- 添加玩家断开连接的处理
AddEventHandler('playerDropped', function()
    local src = source
    
    -- 检查并清理该玩家控制的DJ台
    for djTableId, data in pairs(activeDJTables) do
        if data.djId == src then
            clearDJTable(djTableId)
        end
    end
end)

-- 处理暂停音乐的事件
RegisterNetEvent('dj:pauseMusicForAll')
AddEventHandler('dj:pauseMusicForAll', function(musicInstanceId)
    -- 广播给所有客户端暂停音乐
    TriggerClientEvent('dj:pauseMusic', -1, musicInstanceId)
    print("^2[DJ系统] 歌曲已暂停: " .. musicInstanceId .. "^0")
end)

-- 处理恢复播放音乐的事件
RegisterNetEvent('dj:resumeMusicForAll')
AddEventHandler('dj:resumeMusicForAll', function(musicInstanceId)
    -- 广播给所有客户端恢复播放音乐
    TriggerClientEvent('dj:resumeMusic', -1, musicInstanceId)
    print("^2[DJ系统] 歌曲已恢复播放: " .. musicInstanceId .. "^0")
end)

-- 添加切换歌曲事件处理
RegisterNetEvent('dj:switchSong')
AddEventHandler('dj:switchSong', function(djTableId, songData)
    local src = source
    local playerData = GetPlayerData(src)

    if not playerData.identifier then 
        print("^1[DJ系统] 错误：无法获取玩家信息^0")
        return 
    end

    -- 检查DJ台是否已经在播放音乐
    if isDJTableOccupied(djTableId) then
        local currentDJ = activeDJTables[djTableId].djId
        if currentDJ ~= src then
            -- 停止当前播放的音乐
            clearDJTable(djTableId)
        end
    end

    -- 更新DJ台状态
    activeDJTables[djTableId] = {
        djId = src,
        musicData = songData,
        timestamp = os.time()
    }

    -- 广播给所有客户端切换歌曲
    TriggerClientEvent('dj:switchSongForAll', -1, songData)
end)
