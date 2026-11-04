local function makedeezhands(name, skin, bgs)
    name = "~ Rust hands: " .. name 
    player_manager.AddValidModel(name, "models/player/darky_m/rust/c_arms_human.mdl")
    list.Set("PlayerOptionsModel", name, "models/player/darky_m/rust/c_arms_human.mdl")
    player_manager.AddValidHands(name, "models/player/darky_m/rust/c_arms_human.mdl", skin, bgs)
end

makedeezhands("Bare", 0, "00000000")
makedeezhands("Bare dark", 1, "00000000")
makedeezhands("Bare Hoodie", 0, "00100000")
makedeezhands("Bare dark Hoodie", 1, "00100000")

makedeezhands("Tactical", 0, "01000000")
makedeezhands("Tactical dark", 1, "01000000")

makedeezhands("Roadsign", 0, "02000000")
makedeezhands("Roadsign dark", 1, "02000000")
makedeezhands("Roadsign Hoodie", 0, "02100000")

makedeezhands("Burlap", 0, "03000000")
makedeezhands("Burlap dark", 1, "03000000")