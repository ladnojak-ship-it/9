===============================================================================
 MINECRAFT В GTA V (passthrough) — краткая инструкция
===============================================================================

ВАЖНО: этот архив никуда не выкладывать — внутри ScriptHookV и ReShade,
скачанные со официальных сайтов при сборке в GitHub Actions. Только для
личного использования.

ЧТО НУЖНО
  - Windows, GTA V Legacy (Steam, сборка 3889), режим Story Mode
  - Minecraft Java 26.3 + Fabric Loader 0.19.5 (FreesmLauncher, профиль 67)

УСТАНОВКА (один шаг)
  1. Запустите install.bat. Он:
       - скопирует в папку GTA V: MCPassthrough.asi, ScriptHookV.dll,
         dinput8.dll (ASI-загрузчик), ReShade64.asi, шейдер MCPassthrough.fx
         и настройки ReShade;
       - положит в mods Minecraft: passthrough-*.jar и fabric-api-*.jar;
       - всё, что заменяет, сохранит в GTA\_passthrough_backup_<дата>\

     Если что-то не нашлось автоматически:
       install.bat -GtaDir "<папка с GTA5.exe>" -McDir "<папка minecraft профиля>"

ЗАПУСК
  1. Запустите Minecraft в профиле 67 (Fabric), окно оставьте открытым
     (мод сам создаст пустой креативный мир "passthrough").
  2. Запустите GTA V из Steam -> выберите Story Mode вручную. Никогда не Online.
  3. В игре появится сообщение "Minecraft passthrough connected".
  4. F7 — вкл/выкл накладку; F8 — выровнять землю.

УПРАВЛЕНИЕ
  ЛКМ — ломать/рубить, ПКМ — ставить блоки, стрелять, TNT
  Колесо и 1..9 — хотбар. Ходьба, вождение, камера — как в GTA, Minecraft
  повторяет камеру.
  Хотбар: жемчук эндера, меч, арбалет, лук, TNT, кресало, яйца криперов,
  блоки травы, фейерверки.

УДАЛЕНИЕ
  install.bat -Remove   (уберёт только наши файлы; загрузчики других модов
  вроде OpenIV не тронет; -Force уберёт ещё и ScriptHookV; заодно уберёт
  необязательные моды, которые ставили с -WithSodium)

ЕСЛИ БЛОКИ «ПЛЫВУТ» ПРИ БЫСТРОМ ДВИЖЕНИИ
  Кадр Minecraft каждый кадр перепроецируется на камеру GTA. Если Minecraft
  рисует медленнее GTA — блоки смирятся при резком движении. Поставьте Sodium
  (поднимает FPS Minecraft):
      install.bat -WithSodium
  Убрать: install.bat -Remove  или  удалить sodium-fabric-*.jar из mods.
