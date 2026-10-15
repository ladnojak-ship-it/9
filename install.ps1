#Requires -Version 5.1
<#
.SYNOPSIS
  Installs (or removes) the Minecraft-in-GTA passthrough on this PC.

.DESCRIPTION
  Copies the GTA V plugin, ReShade add-on and its shader into the GTA V Legacy
  folder, and the Fabric mod jars into a Minecraft game directory.
  Every file it replaces is first copied into GTA\_passthrough_backup_<timestamp>\.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File install.ps1
.EXAMPLE
  install.bat -GtaDir "D:\SteamLibrary\steamapps\common\Grand Theft Auto V" -McDir "C:\Users\me\AppData\Roaming\FreesmLauncher\instances\67\minecraft"
.EXAMPLE
  install.bat -WithSodium    # also installs Sodium (raises Minecraft's FPS -> fewer artifacts)
#>
[CmdletBinding()]
param(
  [string]$GtaDir,
  [string]$McDir,
  [switch]$Force,
  [switch]$WithSodium,
  [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

# ---------------------------------------------------------------- detection
function Test-Dir([string]$p) { return ($p -and (Test-Path $p)) }

function Find-GtaDir {
  if ((Test-Dir $GtaDir) -and (Test-Path (Join-Path $GtaDir 'GTA5.exe'))) { return (Resolve-Path $GtaDir).Path }
  $roots = @(
    'D:\SteamLibrary\steamapps',
    'C:\SteamLibrary\steamapps',
    'E:\SteamLibrary\steamapps',
    "${env:ProgramFiles(x86)}\Steam\steamapps",
    "$env:ProgramFiles\Steam\steamapps",
    'D:\Steam\steamapps',
    'C:\Steam\steamapps'
  )
  $libs = @()
  foreach ($r in $roots) {
    if (Test-Path $r) { $libs += $r }
    $vdf = Join-Path $r 'libraryfolders.vdf'
    if (Test-Path $vdf) {
      $m = Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches
      foreach ($x in $m) { foreach ($g in $x.Matches) { $libs += ($g.Groups[1].Value -replace '\\\\', '\') } }
    }
  }
  foreach ($lib in ($libs | Select-Object -Unique)) {
    $acf = Join-Path $lib 'appmanifest_271590.acf'
    if (Test-Path $acf) {
      $dir = Select-String -Path $acf -Pattern '"installdir"\s+"([^"]+)"' | Select-Object -First 1
      if ($dir) {
        $cand = Join-Path $lib (Join-Path 'common' $dir.Matches[0].Groups[1].Value)
        if (Test-Path (Join-Path $cand 'GTA5.exe')) { return (Resolve-Path $cand).Path }
      }
    }
    foreach ($name in @('Grand Theft Auto V')) {
      $cand = Join-Path $lib (Join-Path 'common' $name)
      if (Test-Path (Join-Path $cand 'GTA5.exe')) { return (Resolve-Path $cand).Path }
    }
  }
  return $null
}

function Find-McDir {
  if (Test-Dir $McDir) { return (Resolve-Path $McDir).Path }
  $found = @()
  foreach ($base in @("$env:APPDATA\FreesmLauncher\instances", "$env:APPDATA\.minecraft",
                      "$env:APPDATA\PrismLauncher\instances", "$env:APPDATA\com.modrinth.theseus\profiles")) {
    if (-not (Test-Path $base)) { continue }
    if ($base -like '*instances' -or $base -like '*profiles') {
      $found += Get-ChildItem $base -Directory | ForEach-Object { Join-Path $_.FullName 'minecraft' } |
        Where-Object { Test-Path (Join-Path $_ 'mods') }
    } elseif (Test-Path (Join-Path $base 'mods')) {
      $found += $base
    }
  }
  $found = $found | Select-Object -Unique
  if ($found.Count -eq 1) { return (Resolve-Path $found[0]).Path }
  return $null
}

$gta = Find-GtaDir
if (-not $gta) {
  Write-Host "GTA V Legacy not found. Pass the folder with GTA5.exe:  install.ps1 -GtaDir <path>" -ForegroundColor Red
  exit 1
}
$mc = Find-McDir
if (-not $mc) {
  Write-Host "No Minecraft game directory found. Pass one:  install.ps1 -McDir <path-to-minecraft>" -ForegroundColor Red
  exit 1
}

$srcGta = Join-Path $here 'GTA'
if (-not (Test-Path $srcGta)) { Write-Host "Run this from the unzipped MinecraftInGTA folder (missing GTA\)." -ForegroundColor Red; exit 1 }

function Get-Hash([string]$p) {
  if (-not (Test-Path $p)) { return $null }
  return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
}

# ours: (relative path, mode). mode: always = overwrite, ours2 = reconcile quietly, careful = keep unless -Force
$files = @(
  @{ r = 'MCPassthrough.asi';                       mode = 'always'  },
  @{ r = 'ReShadePreset.ini';                       mode = 'always'  },
  @{ r = 'ReShade64.asi';                           mode = 'careful' },
  @{ r = 'dinput8.dll';                             mode = 'careful' },
  @{ r = 'args.txt';                                mode = 'args'    },
  @{ r = 'ScriptHookV.dll';                         mode = 'always'  },
  @{ r = 'reshade-shaders\Shaders\MCPassthrough.fx'; mode = 'always'  },
  @{ r = 'reshade-shaders\Shaders\ReShade.fxh';      mode = 'always'  },
  @{ r = 'reshade-shaders\Shaders\ReShadeUI.fxh';    mode = 'always'  }
)

if ($Remove) {
  Write-Host "Removing the passthrough from $gta (other mods' loaders are left alone; -Force also removes ScriptHookV + its ASI loader)" -ForegroundColor Yellow
  $mine = @('MCPassthrough.asi', 'ReShade64.asi', 'args.txt', 'ReShadePreset.ini',
            'reshade-shaders\Shaders\MCPassthrough.fx', 'reshade-shaders\Shaders\ReShade.fxh', 'reshade-shaders\Shaders\ReShadeUI.fxh')
  if ($Force) { $mine += @('ScriptHookV.dll', 'dinput8.dll') }
  foreach ($r in $mine) {
    $p = Join-Path $gta $r
    if (Test-Path $p) { Remove-Item -LiteralPath $p -Force; Write-Host "  removed $r" }
  }
  Remove-Item (Join-Path $gta 'reshade-shaders\Shaders') -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $gta 'reshade-shaders') -ErrorAction SilentlyContinue
  # optional mods this installer copied (Sodium and friends), installed with -WithSodium
  if (Test-Path (Join-Path $here 'MINECRAFT\mods-optional')) {
    foreach ($jar in (Get-ChildItem (Join-Path $here 'MINECRAFT\mods-optional') -Filter *.jar)) {
      $p = Join-Path (Join-Path $mc 'mods') $jar.Name
      if (Test-Path $p) { Remove-Item -LiteralPath $p -Force; Write-Host "  removed minecraft mod: $($jar.Name)" }
    }
  }
  Write-Host "Done." -ForegroundColor Green
  exit 0
}

$backup = $null
$replaced = @()
$skipped = @()
foreach ($f in $files) {
  $src = Join-Path $srcGta $f.r
  if (-not (Test-Path $src)) { throw "package is incomplete: GTA\$($f.r) is missing" }
  $dst = Join-Path $gta $f.r
  $do = $true
  if ((Get-Hash $src) -eq (Get-Hash $dst)) { $do = $false }   # already installed, byte for byte
  if ($do -and $f.mode -eq 'careful' -and (Test-Path $dst)) {
    $do = $false
    if ($Force) { $do = $true } else { $skipped += $f.r }
  }
  if ($do -and $f.mode -eq 'args' -and (Test-Path $dst)) {
    $old = [System.IO.File]::ReadAllText($dst).Trim()
    $new = [System.IO.File]::ReadAllText($src).Trim()
    if ($old -ne $new) { if ($Force) { $do = $true } else { $do = $false; $skipped += $f.r } }
  }
  if (-not $do) { continue }
  if (Test-Path $dst) {
    if (-not $backup) {
      $backup = Join-Path $gta ("_passthrough_backup_{0:yyyyMMdd_HHmmss}" -f (Get-Date))
      New-Item -ItemType Directory -Path $backup | Out-Null
    }
    $bd = Join-Path $backup $f.r
    New-Item -ItemType Directory -Force -Path (Split-Path $bd) | Out-Null
    Copy-Item -LiteralPath $dst -Destination $bd -Force
  }
  $dd = Split-Path $dst
  if (-not (Test-Path $dd)) { New-Item -ItemType Directory -Force -Path $dd | Out-Null }
  Copy-Item -LiteralPath $src -Destination $dst -Force
  $replaced += $f.r
}
# ReShade.ini only if you don't already have one (yours wins: it holds your overlay settings)
if (-not (Test-Path (Join-Path $gta 'ReShade.ini'))) {
  Copy-Item -LiteralPath (Join-Path $srcGta 'ReShade.ini') -Destination (Join-Path $gta 'ReShade.ini')
  $replaced += 'ReShade.ini (new)'
}

# ---------------------------------------------------------------- Minecraft
$mcMods = Join-Path $mc 'mods'
New-Item -ItemType Directory -Force -Path $mcMods | Out-Null
foreach ($jar in (Get-ChildItem (Join-Path $here 'MINECRAFT\mods') -Filter *.jar)) {
  $dst = Join-Path $mcMods $jar.Name
  if ((Test-Path $dst) -and ((Get-Hash $dst) -ne (Get-Hash $jar.FullName))) {
    if (-not $backup) {
      $backup = Join-Path $gta ("_passthrough_backup_{0:yyyyMMdd_HHmmss}" -f (Get-Date))
      New-Item -ItemType Directory -Force -Path $backup | Out-Null
    }
    Copy-Item -LiteralPath $dst -Destination (Join-Path $backup ("minecraft-mods_" + $jar.Name)) -Force
  }
  Copy-Item -LiteralPath $jar.FullName -Destination $dst -Force
  Write-Host "  minecraft mod: $($jar.Name)"
}

# ---------------------------------------------------------------- optional Minecraft mods
# Sodium raises Minecraft's frame rate: the compositor re-projects each GTA frame from the
# newest Minecraft frame, so a Minecraft that runs much slower than GTA is what smears blocks
# when the camera moves fast. The passthrough works without it; install with -WithSodium.
$optDir = Join-Path $here 'MINECRAFT\mods-optional'
$optInstalled = @()
if ($WithSodium -and (Test-Path $optDir)) {
  foreach ($jar in (Get-ChildItem $optDir -Filter *.jar)) {
    $dst = Join-Path $mcMods $jar.Name
    if ((Test-Path $dst) -and ((Get-Hash $dst) -ne (Get-Hash $jar.FullName))) {
      if (-not $backup) {
        $backup = Join-Path $gta ("_passthrough_backup_{0:yyyyMMdd_HHmmss}" -f (Get-Date))
        New-Item -ItemType Directory -Force -Path $backup | Out-Null
      }
      Copy-Item -LiteralPath $dst -Destination (Join-Path $backup ("minecraft-mods_" + $jar.Name)) -Force
    }
    Copy-Item -LiteralPath $jar.FullName -Destination $dst -Force
    Write-Host "  minecraft mod (optional): $($jar.Name)"
    $optInstalled += $jar.Name
  }
} elseif (Test-Path $optDir) {
  Write-Host ""
  Write-Host "Optional mods available (help when blocks smear during fast motion):" -ForegroundColor Yellow
  foreach ($jar in (Get-ChildItem $optDir -Filter *.jar)) { Write-Host "    $($jar.Name)   (install.bat -WithSodium)" }
}

# ---------------------------------------------------------------- summary
Write-Host ""
Write-Host "Installed into $gta" -ForegroundColor Green
foreach ($r in $replaced) { Write-Host "  + $r" }
if ($skipped.Count) {
  Write-Host ""
  Write-Host "Kept what was already there (run with -Force to replace):" -ForegroundColor Yellow
  foreach ($s in $skipped) { Write-Host "  ? $s" }
}
if ($backup) { Write-Host "Backups of replaced files: $backup" }
Write-Host ""
Write-Host "Next: 1) start Minecraft in the '$mc' profile and leave it running;"
Write-Host "      2) start GTA V from Steam and pick Story Mode by hand (never Online);"
Write-Host "      3) press F7 in GTA to switch the passthrough on."
