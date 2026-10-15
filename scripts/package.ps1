# Stages install package into dist/ and zips it as dist/MinecraftInGTA.zip
# Runs in the GitHub Actions windows job (and locally after a manual build).
# PowerShell 5.1 compatible; run from anywhere:  pwsh scripts\package.ps1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$gta = Join-Path $root 'gta'
$mc = Join-Path $root 'mc'
$dist = Join-Path $root 'dist'
$mcMods = Join-Path $root 'artifacts\mc-mod'   # downloaded by download-artifact

function Get-Prop($name) {
    $line = Select-String -Path (Join-Path $mc 'gradle.properties') -Pattern "^$name=(.+)$" | Select-Object -First 1
    if (-not $line) { throw "$name not found in mc/gradle.properties" }
    return $line.Matches[0].Groups[1].Value.Trim()
}

$ver = Get-Prop 'version'
$jar = Get-ChildItem $mcMods -Recurse -Filter "passthrough-$ver.jar" -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $jar) {
    $jar = Get-ChildItem $mcMods -Recurse -Filter 'passthrough-*.jar' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'sources|dev' } | Select-Object -First 1
}
if (-not $jar) { throw "no passthrough jar in $mcMods" }
$fabricApi = Get-ChildItem $mcMods -Recurse -Filter 'fabric-api.jar' -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $fabricApi) { throw "no fabric-api.jar in $mcMods" }
$jar = $jar.FullName

$stage = Join-Path $dist 'stage'
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
$stageGta = Join-Path $stage 'GTA'
$stageShaders = Join-Path $stageGta 'reshade-shaders\Shaders'
$stageMcMods = Join-Path $stage 'MINECRAFT\mods'
New-Item -ItemType Directory -Force -Path $stageShaders, $stageMcMods | Out-Null

# --- GTA V side (script + ReShade add-on + runtime, all fetched by gta/fetch_deps.sh)
$rt = Join-Path $gta 'third_party\runtime'
Copy-Item (Join-Path $rt 'ScriptHookV.dll') $stageGta
Copy-Item (Join-Path $rt 'dinput8.dll')    $stageGta
Copy-Item (Join-Path $gta 'build\MCPassthrough.asi') $stageGta
Copy-Item (Join-Path $rt 'ReShade64.dll') (Join-Path $stageGta 'ReShade64.asi')
Copy-Item (Join-Path $gta 'shaders\MCPassthrough.fx') $stageShaders
Copy-Item (Join-Path $gta 'third_party\ReShade.fxh')    $stageShaders
Copy-Item (Join-Path $gta 'third_party\ReShadeUI.fxh')  $stageShaders
Copy-Item $jar, $fabricApi.FullName $stageMcMods

# --- optional mods (installed with -WithSodium; the passthrough works without them)
# they arrive inside the downloaded mc-mod artifact as optional/*.jar
$optSrc = Join-Path $mcMods 'optional'
if (Test-Path $optSrc) {
    $stageOpt = Join-Path $stage 'MINECRAFT\mods-optional'
    New-Item -ItemType Directory -Force -Path $stageOpt | Out-Null
    Get-ChildItem $optSrc -Filter '*.jar' | Copy-Item -Destination $stageOpt
}

# --- the files install.sh would write: launch args, ReShade preset (ours), ReShade.ini (only if missing)
[System.IO.File]::WriteAllText((Join-Path $stageGta 'args.txt'), "-nobattleye -noBE`r`n")
[System.IO.File]::WriteAllText((Join-Path $stage 'README.txt'), (Get-Content (Join-Path $PSScriptRoot '..\README.txt') -Raw))
Copy-Item (Join-Path $PSScriptRoot '..\install.ps1') $stage
Copy-Item (Join-Path $PSScriptRoot '..\install.bat') $stage

$preset = "Techniques=MCPassthrough@MCPassthrough.fx`r`nTechniqueSorting=MCPassthrough@MCPassthrough.fx`r`n"
[System.IO.File]::WriteAllText((Join-Path $stageGta 'ReShadePreset.ini'), $preset)

$ini = @"
[GENERAL]
EffectSearchPaths=.\reshade-shaders\Shaders\
TextureSearchPaths=.\reshade-shaders\Textures\
PresetPath=.\ReShadePreset.ini
PreprocessorDefinitions=RESHADE_DEPTH_INPUT_IS_REVERSED=1,RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=0,RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=0,RESHADE_DEPTH_LINEARIZATION_FAR_PLANE=1000

[OVERLAY]
TutorialProgress=4
ShowClock=0
ShowFPS=0

[SCREENSHOT]
SavePath=.\
"@ -replace "`r?`n", "`r`n"
[System.IO.File]::WriteAllText((Join-Path $stageGta 'ReShade.ini'), $ini)

# --- zip
$zip = Join-Path $dist 'MinecraftInGTA.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
Get-Item $zip | ForEach-Object { "{0}  {1:N1} MB" -f $_.FullName, ($_.Length / 1MB) }
Get-ChildItem $stage -Recurse -File | ForEach-Object { "  " + $_.FullName.Substring($stage.Length + 1) }
