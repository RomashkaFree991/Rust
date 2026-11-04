# Rust для Garry's Mod

Игровой режим Rust для Garry's Mod и карта rust_highland, разложенные по типам файлов.

## Структура

```
maps/rust_highland.bsp           карта (хранится через Git LFS)
characters/                      модели персонажей и одежды, руки от первого лица
animations/viewmodels/<предмет>/ модели от первого лица c_* — внутри них анимации оружия и инструментов
models/weapons|attachments|ammo  оружие в мире, модули, патроны
models/world/...                 постройки, деплоиблы, ящики, руда, растения, транспорт, окружение
textures/                        characters, weapons, world, effects
icons/                           иконки предметов, интерфейса, карты
sounds/                          звуки по категориям
particles/                       эффекты (.pcf) и их текстуры
scripts/gamemodes/rust/          код игрового режима (Lua), последняя версия
ui/fonts/                        шрифты интерфейса
manifest.csv                     путь в репозитории → исходный путь в игре → источник
tools/                           распаковка .gma, сортировка, обратная сборка
```

## Как установить в игру

1. Установите Git LFS и клонируйте репозиторий (иначе вместо карты будет текстовая ссылка):
   ```bash
   git lfs install
   git clone <адрес репозитория>
   ```
2. Соберите файлы обратно в папку игры:
   ```bash
   python3 tools/build_addon.py "<путь к Steam>/steamapps/common/GarrysMod/garrysmod"
   ```
3. Для оружия также нужен аддон Workshop [TFA][AT] Rust Firearms (2529785777).
4. Запустите Garry's Mod, выберите режим **Rust** справа внизу главного меню, нажмите **Start New Game**
   и выберите карту из категории **Rust**. Чтобы играть с друзьями, поменяйте число игроков справа вверху.

Все права на ресурсы принадлежат их авторам (оригинал — Facepunch Studios / Rust).
