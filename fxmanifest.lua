fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'county-vehdamage'
author 'County RP'
description 'Hard-RP engine damage: crashes wear the engine down in tiers, a dead engine needs a mechanic (or an emergency kit to limp home).'
version '1.0.0'

dependencies {
    'qb-core',
}

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
