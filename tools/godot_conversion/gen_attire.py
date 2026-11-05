"""Таблица одежды/брони для Godot: godot/assets/data/attire.json + иконки в godot/assets/icons/items/."""
import json, os, shutil
R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# id: (название, иконка, слот, прячет, показывает, руки_вьюмодели, пули, ближний, описание)
A = {
 "jacket": ("Jacket", "ui/items/jacket.png", "torso", [], [], "", .15, .15, "Куртка."),
 "tshirt_long": ("Longsleeve T-Shirt", "ui/items/tshirt.long.png", "torso", ["Torso"], [], "", .05, .05, "Лонгслив."),
 "tshirt": ("T-Shirt", "ui/items/tshirt.png", "torso", ["Torso"], ["Torso_01"], "", .03, .03, "Футболка."),
 "tanktop": ("Tank Top", "ui/items/shirt.tanktop.png", "torso", ["Torso"], ["Torso_01"], "", .02, .02, "Майка."),
 "burlap_shirt": ("Burlap Shirt", "ui/items/burlap.shirt.png", "torso", ["Torso"], [], "", .03, .03, "Рубаха из мешковины."),
 "jacket_snow": ("Snow Jacket", "ui/items/jacket_snow.png", "torso", ["Torso"], [], "", .12, .12, "Зимняя куртка."),
 "player_urban_torso": ("Urban Jacket", "ui/items/jacket.png", "torso", ["Torso"], [], "", .1, .1, "Городская куртка."),
 "roadsign_jacket": ("Road Sign Jacket", "ui/items/roadsign.jacket.png", "chest", [], [], "", .2, .2, "Броня из дорожных знаков."),
 "heavy_plate_jacket": ("Heavy Plate Jacket", "ui/items/heavy.plate.jacket.png", "chest", ["Torso"], [], "", .25, .25, "Тяжёлая броня."),
 "metal_plate_torso": ("Metal Chest Plate", "ui/items/metal.plate.torso.png", "chest", [], [], "", .25, .25, "Металлический нагрудник."),
 "wood_armour_jacket": ("Wood Chestplate", "ui/items/wood.armor.jacket.png", "chest", [], [], "", .15, .2, "Деревянный нагрудник."),
 "bone_armour": ("Bone Armor", "ui/items/bone.armor.suit.png", "chest", [], [], "", .15, .2, "Броня из костей."),
 "hide_vest": ("Hide Vest", "ui/items/attire.hide.vest.png", "chest", [], [], "", .08, .08, "Жилет из шкуры."),
 "poncho": ("Hide Poncho", "ui/items/attire.hide.poncho.png", "chest", [], [], "", .06, .06, "Пончо."),
 "pants_hide": ("Hide Pants", "ui/items/attire.hide.pants.png", "legs", ["Legs"], ["Legs_01"], "", .1, .1, "Штаны из шкуры."),
 "burlap_trousers": ("Burlap Trousers", "ui/items/burlap.trousers.png", "legs", ["Legs"], [], "", .03, .03, "Штаны из мешковины."),
 "shorts": ("Shorts", "ui/items/pants.shorts.png", "legs", ["Legs"], ["Legs_01"], "", .02, .02, "Шорты."),
 "player_urban_legs": ("Urban Pants", "ui/items/pants.png", "legs", ["Legs"], [], "", .08, .08, "Штаны."),
 "heavy_plate_legs": ("Heavy Plate Pants", "ui/items/heavy.plate.pants.png", "legs", ["Legs"], [], "", .25, .25, "Тяжёлые штаны."),
 "maleunderwear_coconut": ("Coconut Underwear", "ui/items/pants.shorts.png", "underwear", [], [], "", 0, 0, "Кокосовое бельё."),
 "wood_armor_pants": ("Wood Armor Pants", "ui/items/wood.armor.pants.png", "kneepads", [], [], "", .12, .15, "Наколенники."),
 "roadsign_kilt": ("Road Sign Kilt", "ui/items/roadsign.kilt.png", "kilt", [], [], "", .15, .15, "Килт."),
 "shoes_boots": ("Boots", "ui/items/shoes.boots.png", "feet", ["Feet"], [], "", .1, .1, "Ботинки."),
 "boots_hide": ("Hide Boots", "ui/items/attire.hide.boots.png", "feet", ["Feet"], [], "", .06, .06, "Сапоги из шкуры."),
 "burlap_shoes": ("Burlap Shoes", "ui/items/burlap.shoes.png", "feet", ["Feet"], [], "", .03, .03, "Обмотки."),
 "divingflippers": ("Diving Fins", "ui/items/diving.fins.png", "feet", ["Feet"], [], "", 0, 0, "Ласты."),
 "tactical_gloves": ("Tactical Gloves", "ui/items/tactical.gloves.png", "hands", [], [], "TacticalGloves_vm", .05, .05, "Тактические перчатки."),
 "burlap_gloves": ("Leather Gloves", "ui/items/burlap.gloves.png", "hands", [], [], "BurlapGloves_vm", .03, .03, "Перчатки."),
 "roadsign_gloves": ("Roadsign Gloves", "ui/items/roadsign.gloves.png", "hands", [], [], "RoadsignGloves_vm", .06, .06, "Перчатки из знаков."),
 "hat_cap": ("Baseball Cap", "ui/items/hat.cap.png", "head", ["hair"], [], "", .05, .05, "Кепка."),
 "heavy_plate_helmet": ("Heavy Plate Helmet", "ui/items/heavy.plate.helmet.png", "head", ["hair"], [], "", .4, .4, "Тяжёлый шлем."),
 "riot_helmet": ("Riot Helmet", "ui/items/riot.helmet.png", "head", ["hair"], [], "", .25, .25, "Шлем ОМОНа."),
 "bucket_helmet": ("Bucket Helmet", "ui/items/bucket.helmet.png", "head", ["hair"], [], "", .12, .12, "Шлем-ведро."),
 "wooden_helmet": ("Wood Armor Helmet", "ui/items/wood.armor.helmet.png", "head", ["hair"], [], "", .15, .15, "Деревянный шлем."),
 "roadsign_helmet": ("Road Sign Helmet", "ui/items/roadsigns.png", "head", ["hair"], [], "", .2, .2, "Шлем из знаков."),
 "hat_boonie": ("Boonie Hat", "ui/items/hat.boonie.png", "head", ["hair"], [], "", .05, .05, "Панама."),
 "beenie_hat": ("Beenie Hat", "ui/items/hat.beenie.png", "head", ["hair"], [], "", .03, .03, "Шапка."),
 "hat_wolf": ("Wolf Headdress", "ui/items/hat.wolf.png", "head", ["hair"], [], "", .1, .1, "Голова волка."),
 "candlehat": ("Candle Hat", "ui/items/hat.candle.png", "head", ["hair"], [], "", .05, .05, "Шляпа со свечой."),
 "minerhat": ("Miners Hat", "ui/items/hat.miner.png", "head", ["hair"], [], "", .05, .05, "Шахтёрская каска."),
 "hat_burlap_wrap": ("Burlap Headwrap", "ui/items/burlap.headwrap.png", "head", ["hair"], [], "", .05, .05, "Повязка."),
 "nest_hat": ("Nest Hat", "ui/items/attire.nesthat.png", "head", ["hair"], [], "", .02, .02, "Шапка-гнездо."),
 "party_hat": ("Party Hat", "ui/items/partyhat.png", "head", [], [], "", 0, 0, "Праздничный колпак."),
 "bunnyears": ("Bunny Ears", "ui/items/attire.bunnyears.png", "head", [], [], "", 0, 0, "Уши кролика."),
 "metal_mask": ("Metal Facemask", "ui/items/metal.facemask.png", "face", ["beard"], [], "", .5, .5, "Металлическая маска."),
 "bandana": ("Bandana Mask", "ui/items/mask.bandana.png", "face", ["beard"], [], "", .05, .05, "Бандана."),
 "balaclava": ("Balaclava", "ui/items/mask.balaclava.png", "face", ["beard", "hair"], [], "", .05, .05, "Балаклава."),
 "deer_skull_mask": ("Deer Skull Mask", "ui/items/deer.skull.mask.png", "face", ["beard"], [], "", .1, .1, "Маска из черепа оленя."),
 "sunglasses": ("Sunglasses", "ui/items/sunglasses.png", "eyes", [], [], "", 0, 0, "Очки."),
 "divinggoggles": ("Diving Mask", "ui/items/diving.mask.png", "eyes", [], [], "", 0, 0, "Маска для ныряния."),
 "night_vision_goggles": ("Night Vision Goggles", "ui/items/nightvisiongoggles.png", "eyes", [], [], "", 0, 0, "ПНВ."),
 "small_backpack": ("Small Backpack", "ui/items/smallbackpack.png", "back", [], [], "", 0, 0, "Маленький рюкзак."),
 "large_backpack": ("Large Backpack", "ui/items/largebackpack.png", "back", [], [], "", 0, 0, "Большой рюкзак."),
 "divingtank": ("Diving Tank", "ui/items/diving.tank.png", "back", [], [], "", 0, 0, "Акваланг."),
 "wetsuit": ("Wetsuit", "ui/items/diving.wetsuit.png", "suit", ["Torso", "Legs"], [], "", .05, .05, "Гидрокостюм."),
 "ghost_sheet": ("Ghost Costume", "ui/items/ghostsheet.png", "suit", [], [], "", 0, 0, "Костюм привидения."),
 "bunnycostume": ("Bunny Onesie", "ui/items/bunny.suit.png", "suit", ["Torso", "Legs"], [], "", .05, .05, "Кролик."),
 "easter_onesie": ("Easter Onesie", "ui/items/attire.bunny.onesie.png", "suit", ["Torso", "Legs"], [], "", .05, .05, "Пасхальный кролик."),
 "chickencostume": ("Chicken Costume", "ui/items/chicken.costume.png", "suit", ["Torso", "Legs"], [], "", .05, .05, "Костюм курицы."),
 "egg_suit": ("Egg Suit", "ui/items/attire.egg.suit.png", "suit", ["Torso", "Legs"], [], "", .05, .05, "Костюм яйца."),
 "horse_costume": ("Horse Costume", "ui/items/horse.costume.png", "suit", ["Torso", "Legs"], [], "", .05, .05, "Костюм лошади."),
 # полные костюмы — модели игроков (characters/models), заменяют всё тело
 "suit_hazmat": ("Hazmat Suit", "ui/items/hazmatsuit.png", "full", ["all"], [], "", .3, .3, "Химзащита."),
 "suit_hazmat_v2": ("Hazmat Suit (new)", "ui/items/hazmatsuit.png", "full", ["all"], [], "", .3, .3, "Химзащита."),
 "suit_arctic_hazmat": ("Arctic Suit", "ui/items/hazmatsuit.arcticsuit.png", "full", ["all"], [], "", .3, .3, "Арктический костюм."),
 "suit_nomad": ("Nomad Suit", "ui/items/hazmatsuit.nomadsuit.png", "full", ["all"], [], "", .3, .3, "Костюм кочевника."),
 "suit_spacesuit": ("Space Suit", "ui/items/hazmatsuit.spacesuit.png", "full", ["all"], [], "", .3, .3, "Скафандр."),
 "suit_scientist": ("Scientist Suit", "items/clothing/scientist.png", "full", ["all"], [], "", .3, .3, "Костюм учёного."),
 "suit_scientist_v2": ("Scientist Suit (new)", "items/clothing/scientist.png", "full", ["all"], [], "", .3, .3, "Костюм учёного."),
 "suit_heavy_scientist": ("Heavy Scientist Suit", "items/clothing/scientist.png", "full", ["all"], [], "", .5, .5, "Тяжёлый учёный."),
 "suit_jump_suit": ("Jumpsuit", "ui/items/hazmatsuit.png", "full", ["all"], [], "", .1, .1, "Комбинезон."),
 "suit_ninja_hood": ("Ninja Suit", "ui/items/attire.ninja.suit.png", "full", ["all"], [], "", .1, .1, "Костюм ниндзя."),
 "suit_gingerbread": ("Gingerbread Suit", "ui/items/gingerbreadsuit.png", "full", ["all"], [], "", .1, .1, "Пряничный человечек."),
}
os.makedirs(f"{R}/godot/assets/icons/items", exist_ok=True)
out = {}
for k, (nm, ic, slot, hide, show, arms, pr, me, ds) in A.items():
    src = f"{R}/icons/{ic}"
    if not os.path.exists(src):
        print("NO ICON", k, ic)
        continue
    dst = f"{R}/godot/assets/icons/items/attire_{os.path.basename(ic)}"
    shutil.copy(src, dst)
    if not os.path.exists(f"{R}/godot/assets/player/{k}.gltf"):
        print("NO MODEL", k)
        continue
    out[k] = {"name": nm, "icon": "res://assets/icons/items/attire_" + os.path.basename(ic), "slot": slot, "hide": hide, "show": show,
              "arms": arms, "prot": pr, "melee_prot": me, "desc": ds, "scene": f"res://assets/player/{k}.gltf"}
json.dump(out, open(f"{R}/godot/assets/data/attire.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(out))
