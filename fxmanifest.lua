fx_version 'cerulean'
game 'gta5'

description 'SPiceZ Nitrous System'
version '1.0.5'

shared_script '@ox_lib/init.lua'

client_script 'client/main.lua'

server_scripts {
    'server/main.lua'
}

dependency 'ox_lib'