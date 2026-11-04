CreateConVar( "tfa_rust_throwable_flytime", 30, FCVAR_ARCHIVE, "fly time", 2, 90 )
CreateConVar( "tfa_rust_throwable_sticktime", 90, FCVAR_ARCHIVE, "stick time", 0, 1800 )
CreateConVar( "tfa_rust_throwable_stick_in_player", 1, FCVAR_ARCHIVE, "sticks in players?", 0, 1 )
CreateConVar( "tfa_rust_throwable_stick_in_npc", 1, FCVAR_ARCHIVE, "sticks in npcs?", 0, 1 )
CreateConVar( "tfa_rust_throwable_stick_in_ragdolls", 1, FCVAR_ARCHIVE, "stick in ragdolls?", 0, 1 )
CreateConVar( "tfa_rust_throwable_stick_in_props", 1, FCVAR_ARCHIVE, "stick in props?", 0, 1 )
CreateConVar( "tfa_rust_throwable_stick_in_world", 1, FCVAR_ARCHIVE, "stick in world?", 0, 1 )
CreateConVar( "tfa_rust_throwable_nostick", 0, FCVAR_ARCHIVE, "disable sticking", 0, 1 )
CreateConVar( "tfa_rust_throwable_enable", 1, FCVAR_ARCHIVE, "enable throwing meelees", 0, 1 )

if TFA and TFA.AddFireSound then
    TFA.AddFireSound("TFA_RUST_CBOW", {"weapons/rust_mp3/compound-bow-attack-001.mp3", "weapons/rust_mp3/compound-bow-attack-002.mp3", "weapons/rust_mp3/compound-bow-attack-003.mp3"})
end

if not DARKY_RUST then DARKY_RUST = {} end

DARKY_RUST.melee = true

if not DARKY_RUST.firearms and not DARKY_RUST.explosives then 
    local gunshots = file.Find( "sound/weapons/rust_distant/*", "GAME" )
    local mp3s = file.Find( "sound/weapons/rust_mp3/*.mp3", "GAME" )
    local wavs = file.Find( "sound/weapons/rust/*.wav", "GAME" )

    for i=1, #mp3s do
        local snd = string.sub(mp3s[i],1,-5)
        sound.Add(
            {
                name = "darky_rust."..snd,
                channel = CHAN_STATIC,
                volume = 1.0,
                soundlevel = 180,
                sound = "weapons/rust_mp3/"..snd..".mp3"
            }
        )	
    end

    for i=1, #wavs do
        local snd = string.sub(wavs[i],1,-5)
        sound.Add(
            {
                name = "darky_rust."..snd,
                channel = CHAN_STATIC,
                volume = 1.0,
                soundlevel = 180,
                sound = "^weapons/rust/"..snd..".wav"
            }
        )	
    end

    for i=1, #gunshots do
        local snd = string.sub(gunshots[i],1,-5)
        sound.Add(
            {
                name = "darky_rust."..snd,
                channel = CHAN_STATIC,
                volume = 1.0,
                soundlevel = 180,
                sound = "^weapons/rust_distant/"..snd..".mp3"
            }
        )	
    end
end