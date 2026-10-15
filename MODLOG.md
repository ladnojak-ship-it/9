# MODLOG — Minecraft в GTA V (passthrough)

Заметки сессии; из него получится field note в базу знаний.

## Цель
Пользователь: «мод на GTA, майнкрафт в GTA, пасру». Собирать всё должно в
GitHub Actions — на машине игрока ничего не ставим (ни MSVC, ни JDK).
Репозиторий: https://github.com/ladnojak-ship-it/9

## Окружение (проверено 2026-10-15)
- Windows, Steam; GTA V **Legacy**, `version.txt` = 1.0.231.0, ScriptHookV
  v3889.0/1158.13, game build VER_1_0_3889_0 → совпадает с примером
  (`examples/minecraft-gta5-passthrough`).
- Minecraft: FreesmLauncher, инстанс 67, game dir
  `C:\Users\Perimetr\AppData\Roaming\FreesmLauncher\instances\67\minecraft`,
  MC 26.3, Fabric Loader 0.19.5, LWJGL 3.4.3. Папка `mods` пустая — Fabric API
  ещё не стоит.
- В папке GTA уже лежат: `dinput8.dll` (ASI-загрузчик), `ScriptHookV.dll`,
  `args.txt` (`-nobattleye -noBE` + CRLF), `ReShade.ini`, `ReShadePreset.ini`,
  `reshade-shaders/Shaders/{ReShade.fxh,ReShadeUI.fxh}`, OpenIV (`xinput1_4.dll`).
  Из прошлой установки (2026-10-11, логи asiloader/ReShade/ScriptHookV) остались
  логи; самих `MCPassthrough.asi` и `ReShade64.asi` в папке нет — мод удалён.
  Рабочая папка `C:\dev\passthrough` тоже удалена, поэтому пересобираем из
  репозитория-примера.
- Python 3.14.7, git, gh (аккаунт ladnojak-ship-it), Git Bash (есть unzip, tar,
  curl), uv 0.13.0. JDK и MSVC на машине отсутствуют — отсюда требование
  «пусть Actions всё собирает». WSL на машине не работает (wsl.exe ругается).

## Маршрут
Passthrough: два реальных процесса, обмен состоянием. Берём готовый рабочий
пример `examples/minecraft-gta5-passthrough` (он же собран и проверен на этой
машине 10–11.10.2026) и переносим его в репозиторий `ladnojak-ship-it/9`, где
GitHub Actions собирает обе стороны:

- mc: ubuntu-latest + Temurin 25, `./gradlew build`, Fabric API с Modrinth
  (версия из `gradle.properties`) — артефакт `mc-mod`.
- gta: windows-latest, `gta/fetch_deps.sh` (проверен локально в Git Bash:
  ScriptHookV 3889.0, ReShade 6.8.0.2155 — URL живые), `gta/build.bat` (MSVC на
  образе runner'а), `scripts/package.ps1` пакует `MinecraftInGTA.zip`
  (GTA-файлы + mods jar'ы + install.ps1/install.bat + README.txt).

Локально в Git Bash прогнан `gta/fetch_deps.sh` — все URL рабочие
(dev-c.com требует browser headers — скрипт их шлёт).

## Решения по установке
- ReShade ставим как `ReShade64.asi` (GTA грузит системный dxgi.dll вперёд
  прокси — прокси в папке игры не работает).
- `install.ps1` (PS 5.1): сам ищет GTA V по libraryfolders.vdf/271590 и
  Minecraft-профиль; копирует файлы; всё заменённое бэкапит в
  `GTA\_passthrough_backup_<дата>\`; `dinput8.dll`/`ReShade64.asi` без `-Force`
  не заменяет, если они чужие; `ReShade.ini` пишет только если его нет;
  `-Remove` убирает только файлы мода (ScriptHookV/ASI-loader — с `-Force`).
- args.txt пишем как `-nobattleye -noBE\r\n` — те же 19 байт, что уже лежат в
  папке игры, чтобы установщик не видел «чужой» файл.

## Порядок запуска
MC (профиль 67) → GTA → Story Mode вручную → F7. Никогда не Online;
не кликать лендинг автоматически, пока человек за клавиатурой.

## Сборка в CI (готово)
- Пуш в `ladnojak-ship-it/9` (ветка main) → workflow `build`:
  - job `mc-mod`: ubuntu-latest + Temurin JDK 25 → `passthrough-0.1.0.jar`
    (Loom/Gradle) + `fabric-api.jar` (Modrinth, 26.3) → артефакт `mc-mod`.
  - job `gta`: windows-latest → `gta/fetch_deps.sh` (ScriptHookV 3889.0 +
    ReShade 6.8.0.2155) → `gta/build.bat` (MSVC с образа) → `MCPassthrough.asi`
    (352 КБ) → `scripts/package.ps1` → `MinecraftInGTA.zip` (7.1 МБ).
- Прогон 38764815591 — всё зелёное. Артефакт скачан в `out/pkg`.
- Правки по пути: URL Modrinth (urlencode + User-Agent), корень репы в
  package.ps1 (лишний Split-Path), поиск jar'а рекурсивно (upload-artifact
  сохраняет структуру `mc/build/libs/`).
- Содержимое пакета: GTA\ (asi, ScriptHookV.dll, dinput8.dll, ReShade64.asi,
  шейдер, args.txt 19 байт, ReShadePreset.ini, ReShade.ini), MINECRAFT\mods\
  (jar + fabric-api), install.ps1/install.bat, README.txt.

## Проверка в игре (сделано 2026-10-15)
- Установка: `install.ps1` в папку GTA (MCPassthrough.asi, ReShade64.asi,
  MCPassthrough.fx; dinput8.dll/ScriptHookV.dll/args.txt уже были побайтово те
  же — не тронуты; ReShade.ini пользователя сохранён) + jar'ы в mods instance 67.
- Minecraft: freesmlauncher.exe --launch 67; лог — mod loaded, world
  `passthrough` создан, HostLink listening 127.0.0.1:25599 (netstat подтвердил),
  хотбар выставлен командой (журнал latest.log).
- GTA: `um win launch --steam 271590`, ScriptHookV v3889.0, asiloader.load:
  MCPassthrough.asi + ReShade64.asi, ReShade.log: `Registered add-on
  "MCPassthrough"`, `connected to Minecraft's frame export`.
- Скриншоты (`um win shot --exe GTA5.exe`): на земле/на машине — чисто:
  Стив в Лос-Сантосе, хотбар внизу, окклюзия по глубине верная (Стив сидит на
  машине, закрывая её). В воздухе при быстром падении с большой высоты —
  смиринг блоков от репроекции (известный предел; poselag-тюнинг не проверен,
  кадр 21:12:00 пользователя).
- Игры закрыты пользователем.

## Дальше
- [x] разрешение пользователя на установку в папку игры и mods
- [x] установка (install.ps1) + запуск обоих + скриншоты (um win)
- [ ] (опц.) проверить poselag=1 в воздухе, поставить боки/TNT, мобы vs полиция
- [ ] (опц.) showcase-видео (um win record + um video)
- [ ] field note в kb (с разрешения человека)
