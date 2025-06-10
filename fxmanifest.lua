server_script 'hunk_sv.lua'
client_script 'hunk.lua'
fx_version 'cerulean'
game 'gta5'

author 'EUAN'
description 'DJ台插件'
version '0.0.3'
lua54 'yes'

shared_scripts {
	'@es_extended/imports.lua'
}

client_script {
	'config.lua',
	'client.lua'
}

server_scripts {
    '@sandbox-patches/patches.lua',
	'config.lua',
	'server.lua',
	'@oxmysql/lib/MySQL.lua'
}

ui_page 'ui/index.html'

files {'ui/index.html', 'ui/**'
}
-- 需要排除加密的文件列表
escrow_ignore {
    'config.lua',
    'server.lua',
	'utils/notify.lua'
}
dependency {'oxmysql' -- 'es_extended'
}

shared_scripts {'config.lua'}