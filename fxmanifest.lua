fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Caio William Oliveira Faria'
description 'Standalone PvP Queue System - OOP Architecture'
version '2.0.0'

shared_script 'shared/config.lua'

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/classes/*.lua',
    'server/main.lua'
}
