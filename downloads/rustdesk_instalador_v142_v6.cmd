@echo off
mode con: cols=112 lines=36 >nul 2>nul
setlocal EnableExtensions
title NG Master - RustDesk NG - Instalador

:: ============================================================
::  NG Master - Instalador/Configurador RustDesk NG - v6
::  Execute somente em computador autorizado pelo cliente/responsavel.
::  Versao com fechamento automatico, logs padronizados e atalhos.
:: ============================================================

set "TEMP_PS1=%TEMP%\ngmaster_rustdesk_setup_v6_%RANDOM%%RANDOM%.ps1"

echo.
echo [1/3] Preparando script PowerShell temporario...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop'; $txt = Get-Content -LiteralPath '%~f0' -Raw; $marker = ':: ---INICIO_PS1---'; $idx = $txt.LastIndexOf($marker); if ($idx -lt 0) { throw 'Marcador PS1 nao encontrado.' }; $codigo = $txt.Substring($idx + $marker.Length).TrimStart([char]13,[char]10); Set-Content -LiteralPath '%TEMP_PS1%' -Value $codigo -Encoding UTF8"

if errorlevel 1 (
    echo.
    echo [ERRO] Nao foi possivel preparar o PowerShell temporario.
    pause
    exit /b 1
)

echo [2/3] Iniciando PowerShell com permissao de administrador...
echo [3/3] Ao finalizar, as janelas serao fechadas automaticamente.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS1%"

exit /b %errorlevel%

:: ---INICIO_PS1---
$ErrorActionPreference = 'Stop'


function Get-NgShortcutLocations {
    $paths = New-Object System.Collections.Generic.List[string]

    $candidates = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('CommonDesktopDirectory'),
        [Environment]::GetFolderPath('Programs'),
        [Environment]::GetFolderPath('CommonPrograms'),
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\OneDrive\Desktop",
        "$env:PUBLIC\Desktop",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    )

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        try {
            $full = [System.IO.Path]::GetFullPath($candidate)
            if ((Test-Path -LiteralPath $full) -and (-not $paths.Contains($full))) {
                [void]$paths.Add($full)
            }
        } catch {}
    }

    return $paths
}

function Update-RustDeskNgShortcuts {
    param([string]$RustDeskExe)

    Write-Log 'Ajustando atalhos do RustDesk para RustDesk NG...'

    if (-not (Test-Path -LiteralPath $RustDeskExe)) {
        Write-Log "RustDeskExe nao encontrado para criar atalho: $RustDeskExe"
        return
    }

    $shortcutDirs = Get-NgShortcutLocations
    $shell = New-Object -ComObject WScript.Shell

    foreach ($dir in $shortcutDirs) {
        try {
            # Remove atalhos antigos do RustDesk para evitar ficar "RustDesk" e "RustDesk NG" juntos.
            $oldLinks = Get-ChildItem -LiteralPath $dir -Filter '*RustDesk*.lnk' -ErrorAction SilentlyContinue
            foreach ($old in $oldLinks) {
                Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
            }

            $newLinkPath = Join-Path $dir 'RustDesk NG.lnk'
            $shortcut = $shell.CreateShortcut($newLinkPath)
            $shortcut.TargetPath = $RustDeskExe
            $shortcut.Arguments = ''
            $shortcut.WorkingDirectory = Split-Path -Parent $RustDeskExe
            $shortcut.IconLocation = "$RustDeskExe,0"
            $shortcut.Description = 'RustDesk NG Master'
            $shortcut.Save()

            Write-Log "Atalho criado/renomeado: $newLinkPath"
        }
        catch {
            Write-Log "Nao foi possivel ajustar atalho em ${dir}: $($_.Exception.Message)"
        }
    }
}

function Rename-RustDeskPortableIcons {
    # Caso exista um RustDesk portatil na area de trabalho, renomeia o arquivo visivel para RustDesk NG.exe.
    # Isso evita que o tecnico/cliente veja apenas "rustdesk-1.4.2-x86_64.exe" como icone solto.
    $desktopDirs = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('CommonDesktopDirectory'),
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\OneDrive\Desktop",
        "$env:PUBLIC\Desktop"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

    foreach ($dir in $desktopDirs) {
        try {
            $portableFiles = Get-ChildItem -LiteralPath $dir -File -Filter '*rustdesk*.exe' -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne 'RustDesk NG.exe' }

            foreach ($file in $portableFiles) {
                $target = Join-Path $dir 'RustDesk NG.exe'
                if (-not (Test-Path -LiteralPath $target)) {
                    Rename-Item -LiteralPath $file.FullName -NewName 'RustDesk NG.exe' -Force -ErrorAction SilentlyContinue
                    Write-Log "Arquivo portatil renomeado: $($file.FullName) -> $target"
                }
            }
        } catch {
            Write-Log "Nao foi possivel renomear RustDesk portatil em ${dir}: $($_.Exception.Message)"
        }
    }
}

try {
    $host.UI.RawUI.WindowTitle = 'NG Master - RustDesk NG - Instalador'
    $raw = $host.UI.RawUI
    $buffer = $raw.BufferSize
    if ($buffer.Width -lt 112) { $buffer.Width = 112 }
    if ($buffer.Height -lt 1000) { $buffer.Height = 1000 }
    $raw.BufferSize = $buffer

    $window = $raw.WindowSize
    $window.Width = [Math]::Min(112, $raw.MaxPhysicalWindowSize.Width)
    $window.Height = [Math]::Min(36, $raw.MaxPhysicalWindowSize.Height)
    $raw.WindowSize = $window
} catch {}


# ============================================================
# NG Master - RustDesk NG - Instalador v3
# ============================================================

$NgServerHost = 'rustdesk.ngmaster.com.br'
$NgServerKey  = 'C3ExT55C57xcnUHWqmoW0yKb8gi2l3wimfsYNKflhEg='
$RustDeskDownloadUrl = 'https://marcosantoniorapado.com.br/downloads/rustdesk-1.4.2-x86_64.exe'

# Cole aqui a string oficial exportada em:
# RustDesk > Settings > Network > Export Server Config
# Se ficar vazio, o script usa o fallback gravando o RustDesk2.toml.
$RustDeskConfigString = ''

$BaseDir     = 'C:\NG Master\RustDesk'
$DownloadDir = Join-Path $BaseDir 'Downloads'
$LogDir      = Join-Path $BaseDir 'Logs'
$ReportPath  = Join-Path $BaseDir 'ACESSO-RUSTDESK-NGMASTER.txt'
$Stamp       = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogPath     = Join-Path $LogDir "rustdesk_instalacao_v4_$Stamp.log"

New-Item -ItemType Directory -Force -Path $BaseDir, $DownloadDir, $LogDir | Out-Null

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Pause-Final {
    param(
        [int]$Seconds = 8
    )

    Write-Host ''
    Write-Host '============================================================'
    Write-Host 'Procedimento finalizado.'
    Write-Host "Log salvo em: $LogPath"
    Write-Host "Relatorio salvo em: $ReportPath"
    Write-Host ''
    Write-Host "Fechando automaticamente em $Seconds segundos..."
    Write-Host '============================================================'

    Start-Sleep -Seconds $Seconds
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-InstalledRustDeskExe {
    $paths = @(
        "$env:ProgramFiles\RustDesk\rustdesk.exe",
        "${env:ProgramFiles(x86)}\RustDesk\rustdesk.exe"
    )

    foreach ($path in $paths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return (Resolve-Path -LiteralPath $path).Path
        }
    }

    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($root in $uninstallRoots) {
        $apps = Get-ItemProperty $root -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like '*RustDesk*'
        }

        foreach ($app in $apps) {
            if ($app.InstallLocation) {
                $candidate = Join-Path $app.InstallLocation 'rustdesk.exe'
                if (Test-Path -LiteralPath $candidate) {
                    return (Resolve-Path -LiteralPath $candidate).Path
                }
            }
        }
    }

    return $null
}

function Find-PortableOrInstallerRustDesk {
    $searchRoots = New-Object System.Collections.Generic.List[string]

    $basicRoots = @(
        "$env:USERPROFILE\Desktop",
        "$env:PUBLIC\Desktop",
        "$env:USERPROFILE\Downloads",
        $DownloadDir
    )

    foreach ($r in $basicRoots) {
        if ($r -and (Test-Path -LiteralPath $r)) { [void]$searchRoots.Add($r) }
    }

    try {
        Get-ChildItem -LiteralPath 'C:\Users' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($sub in @('Desktop','Downloads')) {
                $p = Join-Path $_.FullName $sub
                if (Test-Path -LiteralPath $p) { [void]$searchRoots.Add($p) }
            }
        }
    } catch {}

    $files = foreach ($root in ($searchRoots | Select-Object -Unique)) {
        Get-ChildItem -LiteralPath $root -Filter '*rustdesk*.exe' -File -ErrorAction SilentlyContinue
    }

    $selected = $files |
        Where-Object { $_.Length -gt 5MB } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($selected) { return $selected.FullName }
    return $null
}

function Stop-RustDeskSafe {
    Write-Log 'Fechando processos RustDesk, se estiverem abertos...'
    Get-Process -Name 'RustDesk','rustdesk' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Get-RustDeskService {
    Get-Service -Name 'RustDesk','Rustdesk' -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Install-RustDeskFromExe {
    param([string]$InstallerPath)

    Write-Log "Executando instalacao silenciosa: $InstallerPath"
    Write-Log 'Obs.: seguindo o padrao oficial, o processo e iniciado e aguardamos a instalacao concluir.'

    $p = Start-Process -FilePath $InstallerPath -ArgumentList '--silent-install' -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 30

    $exe = $null
    for ($i = 1; $i -le 18; $i++) {
        $exe = Get-InstalledRustDeskExe
        if ($exe) { break }
        Write-Log "Aguardando instalacao aparecer em Program Files... tentativa $i/18"
        Start-Sleep -Seconds 5
    }

    if (-not $exe) {
        try {
            if ($p -and -not $p.HasExited) {
                Write-Log 'Instalador ainda aberto apos espera. Encerrando processo para evitar travamento.'
                $p | Stop-Process -Force -ErrorAction SilentlyContinue
            }
        } catch {}
        throw 'RustDesk nao apareceu como instalado em Program Files. O instalador pode ter falhado ou esta versao pode ser somente portatil.'
    }

    Write-Log "RustDesk instalado encontrado em: $exe"
    return $exe
}

function Download-RustDeskInstaller {
    $out = Join-Path $DownloadDir 'rustdesk-1.4.2-x86_64.exe'
    Write-Log "Baixando RustDesk do site informado: $RustDeskDownloadUrl"
    Invoke-WebRequest -Uri $RustDeskDownloadUrl -OutFile $out -UseBasicParsing
    if (-not (Test-Path -LiteralPath $out)) { throw 'Download nao gerou arquivo.' }
    if ((Get-Item -LiteralPath $out).Length -lt 5MB) { throw 'Arquivo baixado parece pequeno demais. Verifique o link.' }
    Write-Log "Download concluido: $out"
    return $out
}

function Write-RustDeskTomlConfig {
    $toml = @"
rendezvous_server = '$NgServerHost:21116'
serial = 0

[options]
custom-rendezvous-server = '$NgServerHost'
relay-server = '$NgServerHost'
key = '$NgServerKey'
"@

    $paths = @(
        (Join-Path $env:APPDATA 'RustDesk\config\RustDesk2.toml'),
        'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml'
    )

    foreach ($cfgPath in $paths) {
        $dir = Split-Path -Parent $cfgPath
        New-Item -ItemType Directory -Force -Path $dir | Out-Null

        if (Test-Path -LiteralPath $cfgPath) {
            $backup = "$cfgPath.bak_$Stamp"
            Copy-Item -LiteralPath $cfgPath -Destination $backup -Force
            Write-Log "Backup criado: $backup"
        }

        Set-Content -LiteralPath $cfgPath -Value $toml -Encoding UTF8
        Write-Log "Configuracao TOML aplicada em: $cfgPath"
    }
}

function New-RandomPassword {
    $chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%*-_'.ToCharArray()
    -join (1..16 | ForEach-Object { $chars | Get-Random })
}

function Test-NgPorts {
    foreach ($port in @(21115,21116,21117)) {
        try {
            $ok = Test-NetConnection -ComputerName $NgServerHost -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
            $status = if ($ok) { 'OK' } else { 'FALHOU' }
            Write-Log "Porta TCP ${port}: $status"
        } catch {
            Write-Log "Porta TCP ${port}: nao testada ($($_.Exception.Message))"
        }
    }
}

try {
    Write-Log 'Iniciando instalador/configurador RustDesk NG Master em v5.'
    Write-Log "Usuario: $env:USERNAME"
    Write-Log "Computador: $env:COMPUTERNAME"
    Write-Log "Servidor NG Master: $NgServerHost"

    if (-not (Test-IsAdmin)) {
        Write-Log 'Permissao de administrador nao detectada. Solicitando elevacao...'
        Start-Process -FilePath 'PowerShell.exe' -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit 0
    }

    Stop-RustDeskSafe

    $RustDeskExe = Get-InstalledRustDeskExe

    if ($RustDeskExe) {
        Write-Log "RustDesk instalado encontrado: $RustDeskExe"
    } else {
        $localInstaller = Find-PortableOrInstallerRustDesk
        if ($localInstaller) {
            Write-Log "RustDesk encontrado na area de trabalho/downloads: $localInstaller"
            Write-Log 'Ele sera usado como instalador local antes de tentar baixar do site.'
            $RustDeskExe = Install-RustDeskFromExe -InstallerPath $localInstaller
        } else {
            Write-Log 'RustDesk nao encontrado instalado nem na area de trabalho/downloads.'
            $downloaded = Download-RustDeskInstaller
            $RustDeskExe = Install-RustDeskFromExe -InstallerPath $downloaded
        }
    }

    Stop-RustDeskSafe

    $svc = Get-RustDeskService
    if (-not $svc) {
        Write-Log 'Servico RustDesk nao encontrado. Instalando servico...'
        Start-Process -FilePath $RustDeskExe -ArgumentList '--install-service' -WindowStyle Hidden
        Start-Sleep -Seconds 20
        $svc = Get-RustDeskService
    }

    if ($svc) {
        try {
            Write-Log "Servico encontrado: $($svc.Name) / Status: $($svc.Status)"
            if ($svc.Status -eq 'Running') {
                Write-Log 'Parando servico para aplicar configuracao...'
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
            }
        } catch {
            Write-Log "Aviso ao parar servico: $($_.Exception.Message)"
        }
    } else {
        Write-Log 'Aviso: servico RustDesk ainda nao apareceu. Continuando configuracao do usuario e LocalService.'
    }

    if ($RustDeskConfigString.Trim().Length -gt 0) {
        Write-Log 'Aplicando config string oficial do RustDesk...'
        & $RustDeskExe --config $RustDeskConfigString | Out-Null
        Start-Sleep -Seconds 2
    } else {
        Write-Log 'Config string oficial vazia. Aplicando fallback por RustDesk2.toml.'
    }

    Write-RustDeskTomlConfig

    $RustDeskPassword = New-RandomPassword

    if ($svc) {
        Write-Log 'Iniciando servico RustDesk...'
        Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 8
    } else {
        Write-Log 'Tentando instalar/iniciar servico novamente...'
        Start-Process -FilePath $RustDeskExe -ArgumentList '--install-service' -WindowStyle Hidden
        Start-Sleep -Seconds 15
        $svc = Get-RustDeskService
        if ($svc) {
            Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 8
        }
    }

    Write-Log 'Definindo senha permanente aleatoria desta maquina...'
    & $RustDeskExe --password $RustDeskPassword | Out-Null
    Start-Sleep -Seconds 3

    $RustDeskId = ''
    for ($i = 1; $i -le 10; $i++) {
        try {
            $RustDeskId = (& $RustDeskExe --get-id 2>$null | Select-Object -First 1).Trim()
        } catch {}
        if ($RustDeskId) { break }
        Write-Log "Aguardando ID RustDesk... tentativa $i/10"
        Start-Sleep -Seconds 3
    }

    if (-not $RustDeskId) { $RustDeskId = 'NAO FOI POSSIVEL LER O ID - abrir RustDesk e conferir manualmente' }

    Update-RustDeskNgShortcuts -RustDeskExe $RustDeskExe
    Rename-RustDeskPortableIcons

    # Alguns instaladores criam o atalho "RustDesk" alguns segundos depois.
    # Por isso repetimos o ajuste no final para garantir que fique "RustDesk NG".
    Start-Sleep -Seconds 3
    Update-RustDeskNgShortcuts -RustDeskExe $RustDeskExe
    Rename-RustDeskPortableIcons

    Test-NgPorts

    $report = @"
NG Master - Acesso RustDesk

Computador: $env:COMPUTERNAME
Usuario Windows: $env:USERNAME
ID RustDesk: $RustDeskId
Senha RustDesk: $RustDeskPassword
Servidor ID: $NgServerHost
Servidor Relay: $NgServerHost
Key: $NgServerKey
RustDesk EXE: $RustDeskExe
Data/Hora: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')

Observacao:
Este acesso deve ser usado somente com autorizacao do cliente/responsavel.
"@

    Set-Content -LiteralPath $ReportPath -Value $report -Encoding UTF8
    Write-Log "Relatorio gerado: $ReportPath"

    Write-Host ''
    Write-Host '================ RESULTADO ================='
    Write-Host "ID RustDesk: $RustDeskId"
    Write-Host "Senha: $RustDeskPassword"
    Write-Host "Relatorio: $ReportPath"
    Write-Host '============================================'
    Write-Host ''

    Pause-Final
    exit 0
}
catch {
    Write-Host ''
    Write-Host '================ ERRO ENCONTRADO ================'
    Write-Host $_.Exception.Message
    Write-Host ''
    Write-Host 'Detalhes:'
    Write-Host $_.ScriptStackTrace
    Write-Host '================================================='

    try {
        Write-Log "ERRO: $($_.Exception.Message)"
        Write-Log "STACK: $($_.ScriptStackTrace)"
    } catch {}

    Pause-Final -Seconds 15
    exit 1
}
