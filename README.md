# Rust для Garry's Mod: персонажи, одежда, оружие, анимации, текстуры, звуки, скрипты

Содержимое аддонов Steam Workshop (Garry's Mod), распакованное из `.gma` и разложенное по типам.

## Структура

```
characters/models/<персонаж>/    модели игрока: rust_model (обычный персонаж), hazmat, hazmat_v2, arctic_hazmat,
                                 nomad, spacesuit, scientist, scientist_v2, heavy_scientist, jump_suit, ninja_hood, gingerbread
characters/clothing/<предмет>/   одежда и броня (~70): головные уборы, маски, куртки, штаны, обувь, перчатки,
                                 броня, водолазное снаряжение, рюкзаки, костюмы
characters/arms/<что>/           руки от первого лица для костюмов и одежды (c_arms_human — обычные)
animations/viewmodels/<оружие>/  модели от первого лица c_* — внутри них все анимации
models/weapons/<оружие>/         модели оружия в мире (w_*)
models/attachments/<модуль>/     прицелы, глушители, фонарик, лазер и т.д.
models/ammo/<снаряд>/            стрелы, ракеты, гильзы, патроны
models/world/...                 постройки, лут, ящики, деревья, руда, транспорт, окружение
textures/characters/             текстуры персонажей и одежды
textures/weapons/                текстуры оружия
textures/world/                  текстуры построек и окружения
textures/effects/                декали, оверлеи, спрайты, эффекты
icons/                           иконки предметов, инвентаря, HUD, UI
sounds/                          звуки по категориям
particles/                       эффекты (.pcf) и их текстуры
scripts/                         Lua-код
ui/fonts/                        шрифты интерфейса
manifest.csv                     путь в репозитории → исходный путь в игре → ID пака
tools/                           скрипты: распаковка .gma, сортировка, обратная сборка
```

> В движке Source анимации скомпилированы внутрь `.mdl`. Анимации от первого лица — в `animations/viewmodels`,
> анимации тела — внутри моделей персонажей. Вытащить их в `.smd` можно декомпилятором Crowbar.

## Как собрать обратно

```bash
python3 tools/build_addon.py "<путь к GarrysMod>/garrysmod/addons/rust_content"
```

Скрипт восстановит исходную структуру и исходные имена файлов по `manifest.csv`.

Все права на ресурсы принадлежат их авторам (оригинал — Facepunch Studios / Rust).
