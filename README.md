# Rust для Garry's Mod: персонажи, одежда, оружие, анимации, текстуры, звуки, скрипты

Содержимое аддонов Steam Workshop (Garry's Mod), распакованное из `.gma` и разложенное по типам.
Основа — игровой режим **gRust** и контент-паки **GRust Server Content** (zohart), плюс паки оружия и костюмов от Darky.

| Workshop ID | Аддон | Что даёт |
|---|---|---|
| [3636622724](https://steamcommunity.com/sharedfiles/filedetails/?id=3636622724) | gRust — Rust in Garry's Mod | код режима, оружие, инструменты, постройки, окружение, звуки |
| [3188160030](https://steamcommunity.com/sharedfiles/filedetails/?id=3188160030) | [GRust] Server Content — Models | базовый персонаж, ~70 предметов одежды и брони, постройки, лут |
| [3188161638](https://steamcommunity.com/sharedfiles/filedetails/?id=3188161638) | [GRust] Server Content — Materials | текстуры одежды и мира, иконки, UI |
| [3188165440](https://steamcommunity.com/sharedfiles/filedetails/?id=3188165440) | [GRust] Server Content — Sounds | звуки игрока, интерфейса, построек, оружия |
| [2529785777](https://steamcommunity.com/sharedfiles/filedetails/?id=2529785777) | [TFA][AT] Rust Firearms | огнестрел (TFA) |
| [2529802557](https://steamcommunity.com/sharedfiles/filedetails/?id=2529802557) | [TFA][AT] Rust Explosives | взрывчатка (TFA) |
| [2782092042](https://steamcommunity.com/sharedfiles/filedetails/?id=2782092042) | [TFA] Rust Melee (Throwable!) | ближний бой, луки (TFA) |
| [2395395483](https://steamcommunity.com/sharedfiles/filedetails/?id=2395395483) | Rust Hazmat Suit PM | хазмат |
| [2743974910](https://steamcommunity.com/sharedfiles/filedetails/?id=2743974910) | Rust Arctic Suit PM | арктический хазмат |
| [2659607667](https://steamcommunity.com/sharedfiles/filedetails/?id=2659607667) | Rust Nomad Suit PM | костюм кочевника |
| [2659610837](https://steamcommunity.com/sharedfiles/filedetails/?id=2659610837) | Rust Spacesuit PM | скафандр |
| [2467846835](https://steamcommunity.com/sharedfiles/filedetails/?id=2467846835) | Rust Scientist Nextbot/PM | учёный + NPC |
| [2815506728](https://steamcommunity.com/sharedfiles/filedetails/?id=2815506728) | Rust c_hands | руки |

Все права на ресурсы принадлежат их авторам (оригинал — Facepunch Studios / Rust; порты — авторы аддонов).
Автор GRust Server Content указывает, что часть предметов разрешено использовать только в режиме GRust.

## Структура

```
characters/models/<персонаж>/    модели игрока: rust_model (обычный голый персонаж), hazmat, hazmat_grust,
                                 arctic_hazmat, nomad, spacesuit, scientist, scientist_grust, heavy_scientist,
                                 jump_suit, ninja_hood, gingerbread
characters/clothing/<предмет>/   одежда и броня (~70): головные уборы, маски, куртки, штаны, обувь, перчатки,
                                 костяная/деревянная/металлическая/дорожная броня, тяжёлая броня, водолазное снаряжение,
                                 рюкзаки, костюмы (кролик, курица, лошадь, пасхальный, призрак) и т.д.
characters/arms/<что>/           руки от первого лица для костюмов и одежды (c_arms_human — обычные)
animations/viewmodels/<оружие>/  модели от первого лица c_* — внутри них все анимации (оружие и инструменты)
models/weapons/<оружие>/         модели оружия в мире (w_*)
models/attachments/<модуль>/     прицелы, глушители, фонарик, лазер и т.д.
models/ammo/<снаряд>/            стрелы, ракеты, гильзы, патроны
models/world/...                 постройки, деплоиблы, лут, ящики, деревья, руда, транспорт, окружение
textures/characters/             текстуры персонажей и одежды (кожа, лицо, глаза, все предметы одежды)
textures/weapons/                текстуры оружия
textures/world/                  текстуры построек и окружения
textures/effects/                декали, оверлеи, спрайты, эффекты
icons/                           иконки предметов, инвентаря, HUD, UI
sounds/                          звуки по категориям: player, weapons, footsteps, building, ui, vehicles, music...
particles/                       эффекты (.pcf) и их текстуры
scripts/gamemodes/rust/          код игрового режима gRust (Lua)
scripts/lua/                     код оружия TFA, персонажей и NPC
ui/fonts/                        шрифты интерфейса
manifest.csv                     путь в репозитории → исходный путь в игре → ID пака
tools/                           скрипты: распаковка .gma, сортировка, обратная сборка
```

> В движке Source анимации не хранятся отдельно — они скомпилированы внутрь `.mdl`.
> Анимации от первого лица — в `animations/viewmodels`, анимации тела игрока — внутри моделей персонажей.
> Вытащить их в `.smd` можно декомпилятором Crowbar.

## Как собрать обратно

Разложенные файлы не лежат по путям движка, поэтому соберите их:

```bash
python3 tools/build_addon.py "<путь к GarrysMod>/garrysmod/addons/rust_content"
```

Скрипт восстановит исходную структуру (`models/`, `materials/`, `sound/`, `particles/`, `resource/`, `lua/`, `gamemodes/rust/`) по `manifest.csv`.

## Совпадающие файлы

Многие файлы (оружие Darky, хазмат, учёный) есть сразу в нескольких паках. Оставлена версия из более позднего пака
в порядке: паки Darky → gRust → GRust Server Content. Так же происходит в игре, когда установлено всё сразу.
Если разные исходные файлы попадали в одно место, второй лежит в подпапке `grust/` или `zohart/`.

Не включён пак **[GRust] Server Content — Skins** (3188167084, ~775 МБ): это скины от мастерской Rust,
и их разрешено использовать только в режиме GRust.
