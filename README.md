# Rust — оружие для Garry's Mod (ресурсы, разложенные по типам)

Содержимое трёх аддонов Steam Workshop (Garry's Mod, база TFA), распакованное из `.gma` и разложенное по категориям.

| Workshop ID | Аддон | Файлов |
|---|---|---|
| [2782092042](https://steamcommunity.com/sharedfiles/filedetails/?id=2782092042) | [TFA] Rust Melee (Throwable!) | 349 |
| [2529785777](https://steamcommunity.com/sharedfiles/filedetails/?id=2529785777) | [TFA][AT] Rust Firearms | 782 |
| [2529802557](https://steamcommunity.com/sharedfiles/filedetails/?id=2529802557) | [TFA][AT] Rust Explosives | 252 |

Для работы в игре нужен [TFA Base](https://steamcommunity.com/sharedfiles/filedetails/?id=415143062).
Все права на модели, текстуры и звуки принадлежат их авторам (оригинальные ресурсы — Facepunch Studios / Rust, порт — автор аддонов в Workshop).

## Структура

```
animations/viewmodels/<оружие>/   c_*.mdl (+.vvd/.vtx) — модели от первого лица, в них зашиты все анимации
models/weapons/<оружие>/          w_*.mdl — модели в мире (в руках у игрока / на земле), с LOD и .phy
models/attachments/<модуль>/      модули: прицелы, глушитель, фонарик, лазер, дульные насадки
models/ammo/<снаряд>/             стрелы, ракеты, гильзы, гранаты подствольника
textures/weapons/<оружие>/        .vtf (albedo / normal / specular / AO) + .vmt
sounds/weapons/                   звуки стрельбы, перезарядки, ударов, бросков
sounds/distant/                   дальние звуки выстрелов и взрывов
sounds/loops/                     зацикленные .wav (горение, полёт стрелы, двигатель ракеты)
particles/                        эффекты взрывов/огня (.pcf) и их текстуры
icons/spawnmenu|hud|attachments/  иконки для меню спавна, HUD и модулей
lua/                              код оружия, сущностей и модулей (TFA)
manifest.csv                      соответствие: путь в репозитории → исходный путь в аддоне → ID пака
tools/                            скрипты распаковки, сортировки и обратной сборки
```

> В движке Source анимации не хранятся отдельными файлами — они скомпилированы внутрь `.mdl`.
> Поэтому в `animations/` лежат viewmodel‑модели (`c_*`), содержащие анимации от первого лица.
> Извлечь их в `.smd` можно декомпилятором Crowbar.

## Как собрать обратно в аддон

Файлы разложены не по путям движка, поэтому напрямую в `garrysmod/addons` их класть нельзя. Соберите:

```bash
python3 tools/build_addon.py "<путь к GarrysMod>/garrysmod/addons/rust_weapons"
```

Скрипт восстановит исходную структуру (`models/`, `materials/`, `sound/`, `particles/`, `lua/`) по `manifest.csv`.

## Совпадающие файлы

Часть файлов с одинаковым путём есть сразу в нескольких паках (`fire_arrow`, общие звуки вроде `deploy.mp3`, дальние звуки взрывов).
Оставлена версия из более нового пака (порядок: Firearms → Explosives → Melee) — так же, как это происходит в игре при установке всех трёх.
