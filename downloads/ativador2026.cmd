@echo off
title Suporte Pos-Formatacao - NG Master v5.6
color 0F

:: 1. AUTO-ELEVACAO (Mantendo o terminal ativo para diagnosticos)
fltmc >nul 2>&1 || (
    echo Elevando para Administrador...
    powershell -Command "Start-Process cmd -ArgumentList '/c', '""%~f0""' -Verb RunAs"
    exit /b
)

:: 2. PREPARANDO A EXTRACAO DA INTERFACE
set "ARQUIVO_PS1=%TEMP%\interface_ng.ps1"
echo [1/2] Carregando o painel de suporte...

:: O fatiador do sistema corta tudo o que estiver abaixo da tag secreta.
:: Usando Encoding ASCII para evitar qualquer corrupcao de quebra de linha.
powershell -Command "$txt = Get-Content -LiteralPath '%~f0' -Raw; $codigo = ($txt -split '---INICIO_PS1---')[-1]; Set-Content -Path '%ARQUIVO_PS1%' -Value $codigo -Encoding ASCII"

echo [2/2] Iniciando interface visual...
echo ===================================================
echo.

:: 3. EXECUCAO DA INTERFACE
powershell -NoProfile -ExecutionPolicy Bypass -File "%ARQUIVO_PS1%"

echo.
echo ===================================================
echo [FIM] Processo finalizado na bancada.
pause

:: 4. LIMPEZA DOS TEMPORARIOS
if exist "%ARQUIVO_PS1%" del /f /q "%ARQUIVO_PS1%"
exit /b

:: --------------------------------------------------------------------
:: ---INICIO_PS1---
<#
    Versao: 5.5 - NG Master
    Base operacional preservada da versao 5.4.

    Funcoes herdadas:
    - NOVO: Funcao de limpeza de arquivos temporarios (%TEMP%, C:\Windows\Temp, cache Windows Update).
    - NOVO: Relatorio do sistema - versao Windows, ativacao, CPU, RAM, disco, IP, nome da maquina.
    - Discord opcional e independente dos relatorios locais.
    - REORDENACAO: Ativacao reposicionada para sempre ser o ultimo processo automatizado.
    - CORRECAO: icacls com aspas corretas no argumento de permissao (OI)(CI).
#>

#region Funcoes Principais e Configuracoes Iniciais

$corTitulo   = "Yellow"
$corDestaque = "Cyan"
$corAlerta   = "Red"
$corSucesso  = "Green"

# Webhook do Discord
$script:DiscordEncryptedPayload = 'TkdXMQzVxIhoe6WravixTfBAV1R47Ez0WRbbFaSCnOPmv6CIGv0RJCGJfvBL9V9bxrl4gkbRo9tt6WShbq8nxrAXid6hFx6KsIz+ntdO6CdHhz1YM3NTddUeAl+xj8BWLcZ2iNQ67WN8tG8vdYnu7RgOvlFZVXA5ljVgGr+hiMGn+xINFHL3TemMfSGPs1p2rmRztemjjPWIBDZsplV7FYLx82l0XLUDaG9hOKZpFk5OsEROgggONAah/MHVSuZHZ4N2Jw=='

# Log global da sessao
$script:LogLines = [System.Collections.Generic.List[string]]::new()

function Add-Log {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $line = "[$timestamp][$Type] $Message"
    $script:LogLines.Add($line)
    if ($Type -eq "ERRO") { Show-ConsoleMessage $line $corAlerta } else { Show-ConsoleMessage $line $corDestaque }
}

function Show-ConsoleMessage {
    param ([string]$Message, [string]$Color = "White")
    Write-Host -ForegroundColor $Color $Message
}

# -- Relatorio do sistema --
function Get-SystemReport {
    param([Parameter(Mandatory=$true)] $record)
    # O TXT utiliza exclusivamente o registro final ja capturado para HTML e Discord.
    # Nao consultar slmgr/IP/espaco em momentos diferentes: as leituras podem divergir.
    if ($null -eq $record -or $null -eq $record.Final) { throw 'Registro final indisponivel para o relatorio TXT.' }
    $snap=$record.Final
    $totalGB=[double]$snap.DriveTotalGB
    $freeGB=[double]$snap.DriveFreeGB
    $usedGB=[math]::Round([math]::Max(0, $totalGB-$freeGB),1)
    $edition=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name EditionID -ErrorAction SilentlyContinue).EditionID
    $report = "====================================================`r`n" +
              "  RELATORIO DO SISTEMA - NG Master`r`n" +
              "====================================================`r`n" +
              "  Servico     : $($record.ServiceId)`r`n" +
              "  Equipamento : $($record.MachineId)`r`n" +
              "  Tecnico     : $($record.Technician)`r`n" +
              "  Tipo        : $($record.Client.Kind)`r`n" +
              "  Inicio      : $($record.Started)`r`n" +
              "  Fim         : $($record.Finished)`r`n" +
              "  Duracao     : $($record.Duration)`r`n" +
              "----------------------------------------------------`r`n" +
              "  Computador  : $($snap.Computer)`r`n" +
              "  IP Local    : $($snap.IP)`r`n" +
              "  Windows     : $($snap.Windows) (Build $($snap.WindowsBuild))`r`n" +
              "  Edicao      : $edition`r`n" +
              "  Ativacao    : $($snap.WindowsLicense)`r`n" +
              "----------------------------------------------------`r`n" +
              "  CPU         : $($snap.Cpu)`r`n" +
              "  RAM Total   : $($snap.RamGB) GB`r`n" +
              "  Disco $($snap.Drive) - $usedGB GB usados / $freeGB GB livres / $totalGB GB total`r`n" +
              "===================================================="
    return $report
}

# -- Envio para Discord --
# -- Limpeza de temporarios --
function Clear-TempFiles {
    param(
        [System.Windows.Forms.Label]$StatusLabel = $null,
        [System.Windows.Forms.ProgressBar]$ProgressBar = $null
    )
    $updateUI = { param($text, $progress)
        if ($StatusLabel) { $StatusLabel.Text = $text; $StatusLabel.Refresh() }
        if ($ProgressBar) { $ProgressBar.Value = $progress }
    }

    $paths = @(
        $env:TEMP,
        "$env:windir\Temp",
        "$env:windir\SoftwareDistribution\Download"
    )

    $totalRemoved = 0
    $progress = 10

    foreach ($path in $paths) {
        & $updateUI "Limpando $path...", $progress
        Add-Log "Limpando $path"
        if (Test-Path $path) {
            $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                try {
                    Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction Stop
                    $totalRemoved++
                } catch { }
            }
        }
        $progress += 30
    }

    & $updateUI "Temporarios removidos.", 100
    Add-Log "Limpeza concluida. $totalRemoved item(s) removido(s)."
}

# -- Fila de impressao --
function Clear-PrintQueue {
    param(
        [System.Windows.Forms.Label]$StatusLabel = $null,
        [System.Windows.Forms.ProgressBar]$ProgressBar = $null
    )
    $updateUI = { param($text, $progress)
        if ($StatusLabel) { $StatusLabel.Text = $text; $StatusLabel.Refresh() }
        if ($ProgressBar) { $ProgressBar.Value = $progress }
    }

    try {
        & $updateUI 'Cancelando jobs das impressoras...', 10
        Add-Log "Cancelando print jobs via Get-PrintJob"
        Get-Printer -ErrorAction SilentlyContinue | ForEach-Object {
            Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue |
                Remove-PrintJob -ErrorAction SilentlyContinue
        }

        & $updateUI 'Parando Spooler...', 25
        Add-Log "Parando servico Spooler"
        Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
        $attempts = 10
        while ($attempts -gt 0) {
            $svc = Get-Service -Name Spooler -ErrorAction SilentlyContinue
            if (-not $svc -or $svc.Status -eq 'Stopped') { break }
            Start-Sleep -Seconds 1
            $attempts--
        }

        & $updateUI 'Matando processos de impressao...', 40
        @('splwow64','printfilterpipelinesvc','spoolsv') | ForEach-Object {
            Get-Process -Name $_ -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }

        $spoolPaths = @(
            "$env:windir\System32\spool\PRINTERS",
            "$env:windir\SysWOW64\spool\PRINTERS"
        )
        $progress = 50
        foreach ($path in $spoolPaths) {
            & $updateUI "Zerando $path...", $progress
            if (Test-Path $path) {
                icacls.exe $path /grant "*S-1-1-0:(OI)(CI)F" /Q /C | Out-Null
                Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
            $progress += 15
        }

        & $updateUI 'Subindo Spooler...', 85
        Add-Log "Subindo servico Spooler"
        Start-Service -Name Spooler
        Start-Sleep -Seconds 2
        $svc = Get-Service -Name Spooler
        if ($svc.Status -ne 'Running') { throw 'Spooler nao subiu corretamente.' }

        & $updateUI 'Fila de impressao zerada.', 100
        Add-Log "Fila de impressao limpa com sucesso."
        return $true
    } catch {
        Add-Log "Erro ao limpar fila: $_" "ERRO"
        & $updateUI "Erro: $($_.Exception.Message)", 0
        return $false
    }
}

# -- Download e execucao generica --
function Download-Execute-And-Clean {
    param (
        [string]$Url, [string]$FileName, [string]$ProcessName,
        [System.Windows.Forms.Label]$StatusLabel = $null,
        [System.Windows.Forms.ProgressBar]$ProgressBar = $null,
        [switch]$NoWait
    )
    $updateUI = { param($text, $progress)
        if ($StatusLabel) { $StatusLabel.Text = $text; $StatusLabel.Refresh() }
        if ($ProgressBar) { $ProgressBar.Value = $progress }
    }
    try {
        $filePath = Join-Path -Path $env:TEMP -ChildPath $FileName
        & $updateUI "Baixando $FileName...", 20
        Add-Log "Baixando $FileName de $Url"
        Invoke-WebRequest -Uri $Url -OutFile $filePath -ErrorAction Stop
        & $updateUI "Executando $FileName...", 70
        Add-Log "Executando $FileName"

        if ($NoWait) {
            Start-Process -FilePath $filePath -ErrorAction Stop
            Start-Sleep -Seconds 2
            & $updateUI "$FileName iniciado (continua em background).", 100
            Add-Log "$FileName iniciado - script continua sem aguardar."
        } else {
            $proc = Start-Process -FilePath $filePath -PassThru -ErrorAction Stop
            while (-not $proc.HasExited) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 500
            }
            if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
                Stop-Process -Name $ProcessName -Force
            }
            Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
            & $updateUI "$FileName instalado.", 100
            Add-Log "$FileName instalado com sucesso."
        }
    } catch {
        & $updateUI "Erro ao processar $FileName.", 0
        Add-Log "Erro ao baixar/executar $($FileName): $_" "ERRO"
    }
}

# -- Download para Area de Trabalho --
function Download-To-Desktop {
    param (
        [string]$Url, [string]$FileName,
        [System.Windows.Forms.Label]$StatusLabel = $null,
        [System.Windows.Forms.ProgressBar]$ProgressBar = $null
    )
    $updateUI = { param($text, $progress)
        if ($StatusLabel) { $StatusLabel.Text = $text; $StatusLabel.Refresh() }
        if ($ProgressBar) { $ProgressBar.Value = $progress }
    }
    try {
        $desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
        $filePath    = Join-Path -Path $desktopPath -ChildPath $FileName
        & $updateUI "Baixando $FileName para a Area de Trabalho...", 50
        Add-Log "Baixando $FileName para Area de Trabalho"
        Invoke-WebRequest -Uri $Url -OutFile $filePath -ErrorAction Stop
        & $updateUI "Download de $FileName concluido!", 100
        Add-Log "$FileName salvo na Area de Trabalho."
    } catch {
        & $updateUI "Erro ao baixar $FileName.", 0
        Add-Log "Erro ao baixar $($FileName): $_" "ERRO"
    }
}

#endregion


# === NG Master v5.6: historico local, hardware, HTML e atendimento ===
$script:NGRoot = 'C:\NG Master'
$script:NGData = Join-Path $script:NGRoot 'Dados'
$script:NGServices = Join-Path $script:NGData 'Atendimentos'
$script:NGClient = @{ Name=''; Phone=''; Business=''; Asset=''; Reason=''; Kind='Formatacao'; ShowPhone=$false }

function NG-EnsureFolders {
    foreach ($p in @($script:NGRoot, $script:NGData, $script:NGServices)) {
        if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force -ErrorAction Stop | Out-Null }
    }
}
function NG-SafeText([object]$value) {
    return [string]([System.Net.WebUtility]::HtmlEncode([string]$value))
}
function NG-Value([object]$v) {
    if ([string]::IsNullOrWhiteSpace([string]$v)) { return 'Nao informado' }
    return [string]$v
}
function NG-Trim([object]$v, [int]$max=110) {
    $t=([string]$v) -replace '[\r\n\x00-\x1f]',' '
    $t=$t -replace '@','[at]' # Evita mencoes indesejadas no Discord.
    if ($t.Length -gt $max) { return $t.Substring(0,$max) }
    return $t
}
function NG-ValidSerial([object]$v) {
    $t=([string]$v).Trim()
    if ($t -match '^(|0+|none|unknown|default string|to be filled by o\.e\.m\.|system serial number|not specified|not available)$') { return '' }
    return $t
}
function NG-WindowsLicense {
    try {
        $items=@(Get-CimInstance SoftwareLicensingProduct -ErrorAction Stop |
            Where-Object { $_.Name -like 'Windows*' -and $_.PartialProductKey })
        if(@($items | Where-Object { $_.LicenseStatus -eq 1 }).Count -gt 0){return 'Ativado'}
        if($items.Count -gt 0){return 'Nao ativado ou pendente de verificacao'}
        return 'Estado nao identificado'
    } catch {return 'Consulta indisponivel'}
}
function NG-Snapshot {
    $board=$null; $bios=$null; $disk=$null; $os=$null; $cpu=$null; $mem=$null; $computer=$null
    try {$board=Get-CimInstance Win32_BaseBoard -ErrorAction Stop | Select-Object -First 1} catch {}
    try {$bios=Get-CimInstance Win32_BIOS -ErrorAction Stop | Select-Object -First 1} catch {}
    try {$computer=Get-CimInstance Win32_ComputerSystem -ErrorAction Stop | Select-Object -First 1} catch {}
    try {$cpu=Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1} catch {}
    try {$os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop} catch {}
    try {$mem=Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop} catch {}
    try {
        $p=Get-Partition -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop
        $disk=$p | Get-Disk -ErrorAction Stop
    } catch {
        try {$disk=Get-CimInstance Win32_DiskDrive -ErrorAction Stop | Select-Object -First 1} catch {}
    }
    $volume=$null
    try {$volume=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop | Select-Object -First 1} catch {}
    $ips=@()
    try {$ips=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object {$_.IPAddress -notmatch '^(127\.|169\.254\.)'} | Select-Object -ExpandProperty IPAddress)} catch {}
    $memory=[math]::Round([double]$computer.TotalPhysicalMemory / 1GB,1)
    $free=if ($volume) {[math]::Round([double]$volume.FreeSpace / 1GB,1)} else {0}
    $total=if ($volume) {[math]::Round([double]$volume.Size / 1GB,1)} else {0}
    [pscustomobject]@{
        Captured=(Get-Date).ToString('o'); Computer=$env:COMPUTERNAME
        BoardMaker=NG-Value $board.Manufacturer; BoardModel=NG-Value $board.Product
        BoardSerial=NG-ValidSerial $board.SerialNumber; BiosSerial=NG-ValidSerial $bios.SerialNumber
        Cpu=NG-Value $cpu.Name; RamGB=$memory; RamModules=@($mem | ForEach-Object {"$([math]::Round([double]$_.Capacity/1GB,1)) GB $($_.Manufacturer) $($_.PartNumber)"})
        DiskModel=NG-Value $disk.Model; DiskSerial=NG-ValidSerial $disk.SerialNumber
        DiskGB=[math]::Round([double]$disk.Size / 1GB,1); DiskNumber=[string]$disk.Number
        Windows=NG-Value $os.Caption; WindowsBuild=[string]$os.BuildNumber; WindowsLicense=(NG-WindowsLicense)
        WindowsInstallDate=if($os -and $os.InstallDate){$os.InstallDate.ToString('o')}else{''}
        Drive=$env:SystemDrive; DriveTotalGB=$total; DriveFreeGB=$free
        IP=if($ips.Count){$ips -join ', '}else{'Sem IPv4 de rede informado'}
    }
}
function NG-ReadHistory {
    if(-not (Test-Path -LiteralPath $script:NGServices)){return @()}
    $entries=@(Get-ChildItem -LiteralPath $script:NGServices -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
    $result=@()
    foreach($entry in $entries) {
        try { $result+= (Get-Content -LiteralPath $entry.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop) }
        catch { Add-Log "Historico invalido: $($entry.Name)" 'AVISO' }
    }
    return $result
}
function NG-MachineId {
    NG-EnsureFolders
    $path=Join-Path $script:NGData 'equipamento.json'
    if (Test-Path -LiteralPath $path) {
        try {
            $id=(Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).MachineId
            if ($id -match '^NGM-[A-Fa-f0-9]{12}$') { return $id }
        } catch {}
    }
    $id='NGM-'+([guid]::NewGuid().ToString('N').Substring(0,12).ToUpperInvariant())
    [pscustomobject]@{MachineId=$id;Created=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
    return $id
}
function NG-Compare($previous, $current) {
    if (-not $previous) {return [pscustomobject]@{Color='cinza';Message='Primeiro registro disponivel; ainda nao ha comparacao.'}}
    $old=$previous.Final
    if (-not $old) { return [pscustomobject]@{Color='amarelo';Message='Registro anterior sem dados para comparacao.'} }
    $boardOld=NG-ValidSerial $old.BoardSerial; $boardNew=NG-ValidSerial $current.BoardSerial
    $diskOld=NG-ValidSerial $old.DiskSerial; $diskNew=NG-ValidSerial $current.DiskSerial
    $b=if($boardOld -and $boardNew){$boardOld -eq $boardNew}else{$null}
    $d=if($diskOld -and $diskNew){$diskOld -eq $diskNew}else{$null}
    if ($b -eq $true -and $d -eq $true){return [pscustomobject]@{Color='verde';Message='Placa-mae e disco do sistema correspondem ao registro anterior.'}}
    if ($b -eq $false -and $d -eq $false){return [pscustomobject]@{Color='vermelho';Message='Identificadores de placa-mae e disco diferem do registro anterior; conferir fisicamente.'}}
    if ($b -eq $false){return [pscustomobject]@{Color='amarelo';Message='Identificador da placa-mae mudou; verificar substituicao ou troca de equipamento.'}}
    if ($d -eq $false){return [pscustomobject]@{Color='amarelo';Message='Identificador do disco mudou; verificar substituicao ou clonagem.'}}
    return [pscustomobject]@{Color='amarelo';Message='Identificadores insuficientes para confirmar correspondencia fisica.'}
}
function NG-ReportHtml($record,$history) {
    $snap=$record.Final
    $result=NG-SafeText $record.Comparison.Message
    $statusUpper=([string]$record.Comparison.Color).ToUpperInvariant()
    $color=switch($record.Comparison.Color){'verde'{'#16794a'}'vermelho'{'#b42318'}'amarelo'{'#a35c06'}default{'#64748b'}}
    $client=NG-SafeText (NG-Value $record.Client.Name)
    $company=NG-SafeText (NG-Value $record.Client.Business)
    $phone=NG-SafeText (NG-Value $record.Client.Phone)
    $asset=NG-SafeText (NG-Value $record.Client.Asset)
    $reason=NG-SafeText (NG-Value $record.Client.Reason)
    $tech=NG-SafeText (NG-Value $record.Technician)
    $win=NG-SafeText $snap.Windows
    $cpu=NG-SafeText $snap.Cpu
    $board=NG-SafeText "$($snap.BoardMaker) $($snap.BoardModel)"
    $disk=NG-SafeText $snap.DiskModel
    $bs=NG-SafeText (NG-Value $snap.BoardSerial)
    $ds=NG-SafeText (NG-Value $snap.DiskSerial)
    $ram=NG-SafeText $snap.RamGB
    $total=[double]$snap.DriveTotalGB;$free=[double]$snap.DriveFreeGB
    $use=if ($total -gt 0) {[math]::Max(0,[math]::Min(100,[math]::Round((($total-$free)/$total)*100,0)))} else {0}
    $logHtml=($record.Log | ForEach-Object {"<li>$(NG-SafeText $_)</li>"}) -join "`n"
    $historyHtml=(@($history)+@($record) | Sort-Object ServiceId -Descending | Select-Object -First 20 | ForEach-Object {
        "<tr><td>$(NG-SafeText $_.ServiceId)</td><td>$(NG-SafeText $_.Started)</td><td>$(NG-SafeText $_.Technician)</td><td>$(NG-SafeText $_.Client.Kind)</td></tr>"
    }) -join "`n"
    return @"
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>NG Master - Relatorio tecnico</title><style>
:root{font-family:Segoe UI,Arial,sans-serif;color:#152234;background:#eff3f8}*{box-sizing:border-box}body{margin:0;padding:28px}
main{max-width:1080px;margin:auto}.hero{background:linear-gradient(120deg,#102c4b,#22649b);color:white;border-radius:18px;padding:28px}
h1{margin:4px 0 8px;font-size:30px}.sub{opacity:.82}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(245px,1fr));gap:14px;margin:18px 0}
.card{background:white;border:1px solid #dce4ed;border-radius:14px;padding:18px;box-shadow:0 3px 12px #132b4710}.card h2{font-size:17px;margin:0 0 12px;color:#17446b}
.info{margin:6px 0;overflow-wrap:anywhere}.muted{color:#64748b}.tag{display:inline-block;background:white;color:$color;padding:7px 12px;border-radius:999px;font-weight:700}
.track{background:#e2e8f0;height:12px;border-radius:9px;overflow:hidden}.fill{height:100%;background:#2788b6;width:$use%}
table{width:100%;border-collapse:collapse;display:block;overflow-x:auto}td,th{padding:9px 8px;border-bottom:1px solid #e4eaf1;text-align:left;white-space:nowrap}ul{padding-left:18px;max-height:260px;overflow:auto}li{margin:5px 0;overflow-wrap:anywhere}
@media print{body{padding:0;background:white}.card{box-shadow:none}}
</style></head><body><main>
<header class="hero"><div class="sub">NG MASTER INFORMATICA / RELATORIO TECNICO</div><h1>$(NG-SafeText $snap.Computer)</h1>
<div>Equipamento: $(NG-SafeText $record.MachineId) &nbsp; | &nbsp; Atendimento: $(NG-SafeText $record.ServiceId)</div>
<p><span class="tag">$(NG-SafeText $statusUpper) - $result</span></p></header>
<section class="grid"><article class="card"><h2>Atendimento</h2><p class="info">Tecnico: $tech</p><p class="info">Tipo: $(NG-SafeText $record.Client.Kind)</p><p class="info">Inicio: $(NG-SafeText $record.Started)</p><p class="info">Fim: $(NG-SafeText $record.Finished)</p><p class="info">Duracao: $(NG-SafeText $record.Duration)</p><p class="info">Motivo: $reason</p></article>
<article class="card"><h2>Cliente</h2><p class="info">Nome: $client</p><p class="info">Estabelecimento: $company</p><p class="info">Telefone: $phone</p><p class="info">Patrimonio: $asset</p></article>
<article class="card"><h2>Windows e hardware</h2><p class="info">Sistema: $win (build $(NG-SafeText $snap.WindowsBuild))</p><p class="info">CPU: $cpu</p><p class="info">RAM: $ram GB</p><p class="info">Estado Windows: $(NG-SafeText $snap.WindowsLicense)</p><p class="info">Placa-mae: $board</p><p class="info">Serial placa: $bs</p><p class="info">Disco: $disk ($(NG-SafeText $snap.DiskGB) GB)</p><p class="info">Serial disco: $ds</p></article>
<article class="card"><h2>Armazenamento e resultado</h2><p class="info">Unidade $(NG-SafeText $snap.Drive): $free GB livres de $total GB</p><div class="track"><div class="fill"></div></div>
<p class="muted">$use% ocupado</p><p class="info">Erros registrados: $(NG-SafeText $record.ErrorCount)</p><p class="info">Ponto de restauracao: $(NG-SafeText $record.RestorePoint)</p><p class="info">IPv4: $(NG-SafeText $snap.IP)</p></article></section>
<section class="card"><h2>Historico de atendimentos (ate 20)</h2><table><thead><tr><th>ID servico</th><th>Inicio</th><th>Tecnico</th><th>Tipo</th></tr></thead><tbody>$historyHtml</tbody></table></section>
<section class="card" style="margin-top:16px"><h2>Registro de operacoes</h2><ul>$logHtml</ul></section>
<p class="muted">Gerado localmente pelo NG Master. Identificadores podem estar ausentes ou ser copiados por clonagem; a comparacao nao prova a origem do equipamento. A data de execucao nao e necessariamente a data de formatacao.</p>
</main></body></html>
"@
}
function NG-SaveService($record,$history) {
    NG-EnsureFolders
    $json=Join-Path $script:NGServices ($record.ServiceId+'.json')
    ($record | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $json -Encoding UTF8 -ErrorAction Stop
    $html=Join-Path $script:NGRoot 'Relatorio_NGMaster.html'
    NG-ReportHtml $record $history | Set-Content -LiteralPath $html -Encoding UTF8 -ErrorAction Stop
    $archiveHtml=Join-Path $script:NGServices ($record.ServiceId+'.html')
    Copy-Item -LiteralPath $html -Destination $archiveHtml -ErrorAction Stop
    return $html
}
function NG-ShowClientDialog($owner) {
    $dialog=New-Object System.Windows.Forms.Form
    $dialog.Text='NG Master - Dados do cliente e do servico'
    $dialog.Size=New-Object System.Drawing.Size(510,470)
    $dialog.StartPosition='CenterParent';$dialog.FormBorderStyle='FixedDialog';$dialog.MaximizeBox=$false;$dialog.MinimizeBox=$false
    $dialog.Font=New-Object System.Drawing.Font('Segoe UI',10)
    $labels=@('Nome do cliente','Telefone','Estabelecimento / empresa','Numero de patrimonio','Motivo do atendimento')
    $keys=@('Name','Phone','Business','Asset','Reason');$boxes=@{}
    for($i=0;$i -lt $keys.Count;$i++){
        $lbl=New-Object System.Windows.Forms.Label;$lbl.Text=$labels[$i];$lbl.Location=New-Object System.Drawing.Point(15,(16+57*$i));$lbl.AutoSize=$true;$dialog.Controls.Add($lbl)
        $tb=New-Object System.Windows.Forms.TextBox;$tb.Location=New-Object System.Drawing.Point(15,(37+57*$i));$tb.Size=New-Object System.Drawing.Size(460,24);$tb.Text=[string]$script:NGClient[$keys[$i]]
        $dialog.Controls.Add($tb);$boxes[$keys[$i]]=$tb
    }
    $kind=New-Object System.Windows.Forms.ComboBox;$kind.DropDownStyle='DropDownList';$kind.Location=New-Object System.Drawing.Point(15,329);$kind.Width=460
    [void]$kind.Items.AddRange([object[]]@('Formatacao','Manutencao','Preparacao','Diagnostico'))
    $kind.SelectedItem=$script:NGClient.Kind;if($kind.SelectedIndex -lt 0){$kind.SelectedIndex=0};$dialog.Controls.Add($kind)
    $showPhone=New-Object System.Windows.Forms.CheckBox;$showPhone.Text='Incluir telefone na mensagem do Discord';$showPhone.Location=New-Object System.Drawing.Point(15,358)
    $showPhone.AutoSize=$true;$showPhone.Checked=[bool]$script:NGClient.ShowPhone;$dialog.Controls.Add($showPhone)
    $save=New-Object System.Windows.Forms.Button;$save.Text='Salvar dados';$save.Location=New-Object System.Drawing.Point(345,390);$save.Size=New-Object System.Drawing.Size(130,30);$dialog.Controls.Add($save)
    $save.Add_Click({foreach($key in $keys){$script:NGClient[$key]=$boxes[$key].Text.Trim()};$script:NGClient.Kind=[string]$kind.SelectedItem;$script:NGClient.ShowPhone=$showPhone.Checked;$dialog.DialogResult='OK';$dialog.Close()})
    [void]$dialog.ShowDialog($owner)
    $dialog.Dispose()
}
function NG-ShowHistory($owner) {
    try {
        $history=@(NG-ReadHistory);$machine='Sem cadastro local';$idPath=Join-Path $script:NGData 'equipamento.json'
        if(Test-Path -LiteralPath $idPath){try{$machine=(Get-Content -LiteralPath $idPath -Raw -Encoding UTF8 | ConvertFrom-Json).MachineId}catch{}}
        $now=NG-Snapshot
        $previous=if($history.Count){$history[-1]}else{$null}
        $compare=NG-Compare $previous $now
        $lines=@("ID local: $machine","Computador: $($now.Computer)","Placa-mae: $($now.BoardMaker) $($now.BoardModel)","Serial placa: $(NG-Value $now.BoardSerial)","Disco: $($now.DiskModel)","Serial disco: $(NG-Value $now.DiskSerial)","Comparacao ($($compare.Color)): $($compare.Message)","", "Atendimentos locais: $($history.Count)")
        foreach($item in @($history | Sort-Object ServiceId -Descending | Select-Object -First 15)) {$lines+="$($item.Started) | $($item.ServiceId) | $($item.Technician) | $($item.Client.Name)"}
        $win=New-Object System.Windows.Forms.Form;$win.Text='NG Master - Consulta / hardware';$win.Size=New-Object System.Drawing.Size(760,530);$win.StartPosition='CenterParent'
        $win.Font=New-Object System.Drawing.Font('Segoe UI',10)
        $tb=New-Object System.Windows.Forms.TextBox;$tb.Multiline=$true;$tb.ReadOnly=$true;$tb.ScrollBars='Vertical';$tb.Location=New-Object System.Drawing.Point(12,12);$tb.Size=New-Object System.Drawing.Size(720,425);$tb.Text=$lines -join [Environment]::NewLine;$win.Controls.Add($tb)
        $open=New-Object System.Windows.Forms.Button;$open.Text='Abrir relatorio HTML';$open.Location=New-Object System.Drawing.Point(12,445);$open.Size=New-Object System.Drawing.Size(180,30)
        $open.Add_Click({$p=Join-Path $script:NGRoot 'Relatorio_NGMaster.html';if(Test-Path $p){Start-Process -FilePath $p}else{[System.Windows.Forms.MessageBox]::Show('Nao ha relatorio HTML local ainda.','NG Master')|Out-Null}})
        $win.Controls.Add($open);[void]$win.ShowDialog($owner);$win.Dispose()
    } catch { [System.Windows.Forms.MessageBox]::Show("Nao foi possivel consultar o historico: $_",'NG Master')|Out-Null }
}
# Descriptografa exclusivamente na memoria; nao grava a URL ou a senha em arquivos.
# Formato NGW1: magic(4) + salt(16) + IV(16) + AES-CBC + HMAC-SHA256(32).
function NG-UnlockDiscord([string]$password) {
    if ([string]::IsNullOrEmpty($password) -or $script:DiscordEncryptedPayload -eq 'NG_DISCORD_PAYLOAD_A_CONFIGURAR') {
        throw 'Discord nao configurado ou senha nao informada.'
    }
    $raw=[Convert]::FromBase64String($script:DiscordEncryptedPayload)
    if ($raw.Length -lt 84 -or [Text.Encoding]::ASCII.GetString($raw,0,4) -ne 'NGW1') { throw 'Configuracao Discord invalida.' }
    $cipherLen=$raw.Length-36-32
    if ($cipherLen -lt 16 -or $cipherLen % 16 -ne 0) { throw 'Configuracao Discord invalida.' }
    $salt=New-Object byte[] 16;[Array]::Copy($raw,4,$salt,0,16)
    $iv=New-Object byte[] 16;[Array]::Copy($raw,20,$iv,0,16)
    $kdf=[System.Security.Cryptography.Rfc2898DeriveBytes]::new($password,$salt,150000)
    try {$keys=$kdf.GetBytes(64)} finally {$kdf.Dispose()}
    $aesKey=New-Object byte[] 32;[Array]::Copy($keys,0,$aesKey,0,32)
    $hmacKey=New-Object byte[] 32;[Array]::Copy($keys,32,$hmacKey,0,32)
    $macInput=New-Object byte[] (36+$cipherLen)
    [Array]::Copy($raw,0,$macInput,0,$macInput.Length)
    $hmac=[System.Security.Cryptography.HMACSHA256]::new($hmacKey)
    try {$expected=$hmac.ComputeHash($macInput)} finally {$hmac.Dispose()}
    $diff=0
    for($i=0;$i -lt 32;$i++){$diff=$diff -bor ([int]$expected[$i] -bxor [int]$raw[36+$cipherLen+$i])}
    if($diff -ne 0){throw 'Senha incorreta ou configuracao Discord alterada.'}
    $cipher=New-Object byte[] $cipherLen;[Array]::Copy($raw,36,$cipher,0,$cipherLen)
    $aes=[System.Security.Cryptography.Aes]::Create()
    $aes.Mode=[System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding=[System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.Key=$aesKey;$aes.IV=$iv
    $decryptor=$aes.CreateDecryptor()
    try {$plain=$decryptor.TransformFinalBlock($cipher,0,$cipher.Length)}
    finally {$decryptor.Dispose();$aes.Dispose()}
    $url=[Text.Encoding]::UTF8.GetString($plain)
    if($url -notmatch '^https://(?:discord\.com|discordapp\.com)/api/webhooks/[0-9]+/[A-Za-z0-9_-]+$') {throw 'Endereco Discord invalido.'}
    return $url
}

function NG-DiscordFinal($record, [string]$webhook) {
    $h=$record.Final;$c=$record.Client
    $errors=@($record.Log | Where-Object {$_ -match '\[ERRO\]'} | Select-Object -First 3 | ForEach-Object {NG-Trim $_ 145}) -join "`n"
    $tel=if($c.ShowPhone){NG-Trim (NG-Value $c.Phone) 30}else{'Oculto (relatorio local)'}
    $msg="**NG Master v5.6 - atendimento finalizado**`n"+
        "Servico: $(NG-Trim $record.ServiceId) | Equipamento: $(NG-Trim $record.MachineId)`n"+
        "Inicio: $(NG-Trim $record.Started) | Fim: $(NG-Trim $record.Finished) | Duracao: $(NG-Trim $record.Duration)`n"+
        "Tecnico: $(NG-Trim $record.Technician) | Tipo: $(NG-Trim $c.Kind)`n"+
        "Cliente: $(NG-Trim (NG-Value $c.Name)) | Empresa: $(NG-Trim (NG-Value $c.Business))`n"+
        "Telefone: $tel | Patrimonio: $(NG-Trim (NG-Value $c.Asset))`n"+
        "Motivo: $(NG-Trim (NG-Value $c.Reason) 100)`n"+
        "Maquina: $(NG-Trim $h.Computer) | Windows: $(NG-Trim $h.Windows)`n"+
        "Licenca Windows: $(NG-Trim $h.WindowsLicense 45)`n"+
        "CPU: $(NG-Trim $h.Cpu 75) | RAM: $($h.RamGB) GB`n"+
        "Placa: $(NG-Trim $h.BoardModel 60) | Serie placa: $(NG-Trim (NG-Value $h.BoardSerial) 38)`n"+
        "Disco: $(NG-Trim $h.DiskModel 60) | Serie disco: $(NG-Trim (NG-Value $h.DiskSerial) 38)`n"+
        "Disco C livre: $($h.DriveFreeGB) GB | IP: $(NG-Trim $h.IP 65)`n"+
        "Hardware: $($record.Comparison.Color) - $(NG-Trim $record.Comparison.Message 145)`n"+
        "Ponto de restauracao: $(NG-Trim $record.RestorePoint) | Erros: $($record.ErrorCount)"
    if($errors){$msg+="`nFalhas: $errors"}
    if($msg.Length -gt 1950){$msg=$msg.Substring(0,1947)+'...'}
    try {$body=@{content=$msg}|ConvertTo-Json -Compress;Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null;Add-Log 'Relatorio ampliado enviado para o Discord.'}
    catch {Add-Log 'Falha de rede ao enviar a notificacao ao Discord.' 'AVISO'}
}
function NG-Shutdown($mode,$time,$auxSelected) {
    if($mode -eq 'Manter ligado'){return}
    if($auxSelected){Add-Log 'Desligamento automatico ignorado: programa auxiliar foi selecionado.' 'AVISO';return}
    try {
        $seconds=60
        if($mode -eq 'No horario') {
            if($time -notmatch '^([01]\d|2[0-3]):[0-5]\d$'){throw 'Horario invalido (use HH:mm).'}
            $target=[datetime]::Today.AddHours([int]$time.Substring(0,2)).AddMinutes([int]$time.Substring(3,2))
            if($target -le (Get-Date)){throw 'Horario ja passou. Desligamento nao programado.'}
            $seconds=[math]::Max(60,[int][math]::Ceiling(($target-(Get-Date)).TotalSeconds))
        }
        & shutdown.exe /s /t $seconds /c 'NG Master - desligamento programado apos finalizar atendimento' | Out-Null
        if($LASTEXITCODE -ne 0){throw "shutdown.exe retornou codigo $LASTEXITCODE"}
        Add-Log "Desligamento programado para daqui a $seconds segundos. Para cancelar: shutdown /a"
    } catch { Add-Log "Nao foi possivel programar o desligamento: $_" 'ERRO' }
}
# === fim das funcoes da versao 5.5 ===

#region Interface Grafica (Windows Forms)

function Show-InstallerGUI {
    $kernel32 = Add-Type -memberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();' -name 'kernel32' -namespace 'Win32' -passThru
    $user32   = Add-Type -memberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);' -name 'user32' -namespace 'Win32' -passThru
    $consoleHandle = $kernel32::GetConsoleWindow()
    if ($null -ne $consoleHandle) { $user32::ShowWindow($consoleHandle, 0) | Out-Null }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form               = New-Object System.Windows.Forms.Form
    $form.Text          = "Script Pos-Formatacao v5.6"
    $form.Size          = New-Object System.Drawing.Size(810, 710)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox   = $false
    $form.Icon          = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
    $font               = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Font          = $font

    # -- COLUNA A - Informacoes --
    $groupInfo          = New-Object System.Windows.Forms.GroupBox
    $groupInfo.Location = New-Object System.Drawing.Point(10, 10)
    $groupInfo.Size     = New-Object System.Drawing.Size(390, 125)
    $groupInfo.Text     = "Informacoes do Atendimento"
    $form.Controls.Add($groupInfo)

    $labelTechnician          = New-Object System.Windows.Forms.Label
    $labelTechnician.Text     = "Tecnico:"
    $labelTechnician.Location = New-Object System.Drawing.Point(20, 35)
    $labelTechnician.AutoSize = $true
    $groupInfo.Controls.Add($labelTechnician)

    $txtTechnician          = New-Object System.Windows.Forms.TextBox
    $txtTechnician.Location = New-Object System.Drawing.Point(130, 32)
    $txtTechnician.Size     = New-Object System.Drawing.Size(245, 25)
    $groupInfo.Controls.Add($txtTechnician)

    $chkApplyOemInfo          = New-Object System.Windows.Forms.CheckBox
    $chkApplyOemInfo.Text     = "Gravar informacoes de OEM e do tecnico no Sistema"
    $chkApplyOemInfo.Location = New-Object System.Drawing.Point(20, 60)
    $chkApplyOemInfo.AutoSize = $true
    $chkApplyOemInfo.Checked  = $true
    $groupInfo.Controls.Add($chkApplyOemInfo)

    $btnClient=New-Object System.Windows.Forms.Button
    $btnClient.Text='Dados do cliente / patrimonio...'
    $btnClient.Location=New-Object System.Drawing.Point(20,89)
    $btnClient.Size=New-Object System.Drawing.Size(245,28)
    $groupInfo.Controls.Add($btnClient)
    $chkRequireClient=New-Object System.Windows.Forms.CheckBox
    $chkRequireClient.Text='Solicitar dados'
    $chkRequireClient.Location=New-Object System.Drawing.Point(273,91)
    $chkRequireClient.Size=New-Object System.Drawing.Size(115,26)
    $chkRequireClient.Checked=$true
    $groupInfo.Controls.Add($chkRequireClient)
    $btnClient.Add_Click({NG-ShowClientDialog $form})


    # -- COLUNA A - Programas --
    $groupPrograms          = New-Object System.Windows.Forms.GroupBox
    $groupPrograms.Location = New-Object System.Drawing.Point(10, 145)
    $groupPrograms.Size     = New-Object System.Drawing.Size(390, 245)
    $groupPrograms.Text     = "Selecionar Programas para Instalar/Baixar"
    $form.Controls.Add($groupPrograms)

    $chkSelectAll             = New-Object System.Windows.Forms.CheckBox; $chkSelectAll.Text     = "Selecionar/Desmarcar Todos";                          $chkSelectAll.Location     = New-Object System.Drawing.Point(20, 25);  $chkSelectAll.AutoSize = $true
    $chkOffice                = New-Object System.Windows.Forms.CheckBox; $chkOffice.Text        = "Instalar Microsoft Office";                             $chkOffice.Location        = New-Object System.Drawing.Point(20, 60);  $chkOffice.AutoSize = $true
    $chkNinite                = New-Object System.Windows.Forms.CheckBox; $chkNinite.Text        = "Instalar (Ninite): AnyDesk, Chrome, Firefox, WinRAR"; $chkNinite.Location        = New-Object System.Drawing.Point(20, 95);  $chkNinite.AutoSize = $true
    $chkRustDesk              = New-Object System.Windows.Forms.CheckBox; $chkRustDesk.Text      = "Baixar RustDesk para a Area de Trabalho";               $chkRustDesk.Location      = New-Object System.Drawing.Point(20, 130); $chkRustDesk.AutoSize = $true
    $chkDriverBooster         = New-Object System.Windows.Forms.CheckBox; $chkDriverBooster.Text = "Baixar Driver Booster para a Area de Trabalho";        $chkDriverBooster.Location = New-Object System.Drawing.Point(20, 165); $chkDriverBooster.AutoSize = $true
    $chkAtivacao              = New-Object System.Windows.Forms.CheckBox; $chkAtivacao.Text      = "Executar Programa de Ativacao (ultima etapa)";         $chkAtivacao.Location      = New-Object System.Drawing.Point(20, 205); $chkAtivacao.AutoSize = $true
    $groupPrograms.Controls.AddRange(@($chkSelectAll, $chkOffice, $chkNinite, $chkRustDesk, $chkDriverBooster, $chkAtivacao))

    # -- COLUNA B - Rede --
    $groupNetwork          = New-Object System.Windows.Forms.GroupBox
    $groupNetwork.Location = New-Object System.Drawing.Point(410, 10)
    $groupNetwork.Size     = New-Object System.Drawing.Size(370, 90)
    $groupNetwork.Text     = "Manutencao e Rede"
    $form.Controls.Add($groupNetwork)

    $chkRede                   = New-Object System.Windows.Forms.CheckBox
    $chkRede.Text              = "Ajustar SMB para compatibilidade (redes confiaveis)"
    $chkRede.Location          = New-Object System.Drawing.Point(15, 25)
    $chkRede.AutoSize          = $true
    $chkRede.Checked           = $true
    $chkFilaImpressao          = New-Object System.Windows.Forms.CheckBox
    $chkFilaImpressao.Text     = "Limpar fila de impressao"
    $chkFilaImpressao.Location = New-Object System.Drawing.Point(15, 55)
    $chkFilaImpressao.AutoSize = $true
    $groupNetwork.Controls.AddRange(@($chkRede, $chkFilaImpressao))

    # -- COLUNA B - Limpeza --
    $groupClean          = New-Object System.Windows.Forms.GroupBox
    $groupClean.Location = New-Object System.Drawing.Point(410, 110)
    $groupClean.Size     = New-Object System.Drawing.Size(370, 130)
    $groupClean.Text     = "Limpeza e Diagnostico"
    $form.Controls.Add($groupClean)

    $chkCleanTemp          = New-Object System.Windows.Forms.CheckBox
    $chkCleanTemp.Text     = "Limpar temporarios (%TEMP%, Windows\Temp, WU)"
    $chkCleanTemp.Location = New-Object System.Drawing.Point(15, 25)
    $chkCleanTemp.AutoSize = $true
    $chkSysReport          = New-Object System.Windows.Forms.CheckBox
    $chkSysReport.Text     = "Gerar relatorio do sistema (local)"
    $chkSysReport.Location = New-Object System.Drawing.Point(15, 55)
    $chkSysReport.AutoSize = $true
    $chkSysReport.Checked  = $true
    $chkDiscord=New-Object System.Windows.Forms.CheckBox
    $chkDiscord.Text='Notificar Discord'
    $chkDiscord.Location=New-Object System.Drawing.Point(15,88)
    $chkDiscord.Size=New-Object System.Drawing.Size(167,25)
    $chkDiscord.Checked=$false
    $txtDiscordPass=New-Object System.Windows.Forms.TextBox
    $txtDiscordPass.Location=New-Object System.Drawing.Point(187,88)
    $txtDiscordPass.Size=New-Object System.Drawing.Size(167,25)
    $txtDiscordPass.UseSystemPasswordChar=$true
    $txtDiscordPass.Enabled=$false
    $txtDiscordPass.MaxLength=128
    $chkDiscord.Add_CheckedChanged({
        $txtDiscordPass.Enabled=$chkDiscord.Checked
        if(-not $chkDiscord.Checked){$txtDiscordPass.Clear()}
    })
    $groupClean.Controls.AddRange(@($chkCleanTemp, $chkSysReport, $chkDiscord, $txtDiscordPass))

    # -- COLUNA B - Acoes Finais --
    $groupPost          = New-Object System.Windows.Forms.GroupBox
    $groupPost.Location = New-Object System.Drawing.Point(410, 250)
    $groupPost.Size     = New-Object System.Drawing.Size(370, 90)
    $groupPost.Text     = "Acoes Finais"
    $form.Controls.Add($groupPost)

    $chkRestorePoint          = New-Object System.Windows.Forms.CheckBox
    $chkRestorePoint.Text     = "Criar Ponto de Restauracao ao final"
    $chkRestorePoint.Location = New-Object System.Drawing.Point(15, 28)
    $chkRestorePoint.AutoSize = $true
    $chkRestorePoint.Checked  = $true
    $chkSaveLog          = New-Object System.Windows.Forms.CheckBox
    $chkSaveLog.Text     = "Salvar log de metricas em C:\NG Master"
    $chkSaveLog.Location = New-Object System.Drawing.Point(15, 57)
    $chkSaveLog.AutoSize = $true
    $chkSaveLog.Checked  = $true
    $groupPost.Controls.AddRange(@($chkRestorePoint, $chkSaveLog))

    $chkSelectAll.Add_Click({
        $isChecked = $chkSelectAll.Checked
        $chkApplyOemInfo.Checked  = $isChecked; $chkOffice.Checked = $isChecked; $chkNinite.Checked = $isChecked
        $chkRustDesk.Checked      = $isChecked; $chkDriverBooster.Checked = $isChecked; $chkAtivacao.Checked = $isChecked
        $chkRede.Checked          = $isChecked; $chkFilaImpressao.Checked = $isChecked
        $chkCleanTemp.Checked     = $isChecked; $chkSysReport.Checked = $isChecked; $chkDiscord.Checked = $isChecked
        $chkRestorePoint.Checked = $isChecked; $chkSaveLog.Checked = $isChecked
    })


    # -- Cronometro de atendimento (tempo entre inicio e finalizacao) --
    $groupClock=New-Object System.Windows.Forms.GroupBox
    $groupClock.Text='Tempo do atendimento'
    $groupClock.Location=New-Object System.Drawing.Point(410,350)
    $groupClock.Size=New-Object System.Drawing.Size(370,75)
    $form.Controls.Add($groupClock)
    $lblStart=New-Object System.Windows.Forms.Label
    $lblStart.Text='Inicio: --:--:--';$lblStart.Location=New-Object System.Drawing.Point(15,24)
    $lblStart.Size=New-Object System.Drawing.Size(330,19)
    $lblElapsed=New-Object System.Windows.Forms.Label
    $lblElapsed.Text='Decorrido: 00:00:00';$lblElapsed.Location=New-Object System.Drawing.Point(15,46)
    $lblElapsed.Size=New-Object System.Drawing.Size(330,19)
    $groupClock.Controls.AddRange(@($lblStart,$lblElapsed))
    $clockTimer=New-Object System.Windows.Forms.Timer
    $clockTimer.Interval=1000
    $clockTimer.Add_Tick({
        if($script:NGTimerStart){
            $elapsed=(Get-Date)-$script:NGTimerStart
            $lblElapsed.Text='Decorrido: '+ ('{0:00}:{1:00}:{2:00}' -f [math]::Floor($elapsed.TotalHours),$elapsed.Minutes,$elapsed.Seconds)
        }
    })

    # -- Ferramentas e desligamento (inativo por padrao) --
    $groupTools=New-Object System.Windows.Forms.GroupBox
    $groupTools.Text='Historico / Diagnostico e Finalizacao'
    $groupTools.Location=New-Object System.Drawing.Point(10,440)
    $groupTools.Size=New-Object System.Drawing.Size(770,102)
    $form.Controls.Add($groupTools)
    $btnHistory=New-Object System.Windows.Forms.Button
    $btnHistory.Text='Consultar historico e hardware'
    $btnHistory.Location=New-Object System.Drawing.Point(14,26)
    $btnHistory.Size=New-Object System.Drawing.Size(225,31)
    $groupTools.Controls.Add($btnHistory)
    $btnHistory.Add_Click({NG-ShowHistory $form})
    $lblShutdown=New-Object System.Windows.Forms.Label
    $lblShutdown.Text='Desligamento:'
    $lblShutdown.Location=New-Object System.Drawing.Point(257,33)
    $lblShutdown.AutoSize=$true;$groupTools.Controls.Add($lblShutdown)
    $cboShutdown=New-Object System.Windows.Forms.ComboBox
    $cboShutdown.DropDownStyle='DropDownList';$cboShutdown.Location=New-Object System.Drawing.Point(360,28)
    $cboShutdown.Size=New-Object System.Drawing.Size(168,25)
    [void]$cboShutdown.Items.AddRange([object[]]@('Manter ligado','Ao finalizar','No horario'))
    $cboShutdown.SelectedIndex=0;$groupTools.Controls.Add($cboShutdown)
    $txtShutdown=New-Object System.Windows.Forms.MaskedTextBox
    $txtShutdown.Mask='00:00';$txtShutdown.Text='19:00';$txtShutdown.Location=New-Object System.Drawing.Point(542,29)
    $txtShutdown.Size=New-Object System.Drawing.Size(55,25);$txtShutdown.Enabled=$false;$groupTools.Controls.Add($txtShutdown)
    $cboShutdown.Add_SelectedIndexChanged({$txtShutdown.Enabled=($cboShutdown.SelectedItem -eq 'No horario')})
    $lblAuxNote=New-Object System.Windows.Forms.Label
    $lblAuxNote.Text='Desligamento automatico nao sera executado se o programa auxiliar estiver selecionado.'
    $lblAuxNote.Location=New-Object System.Drawing.Point(14,67)
    $lblAuxNote.Size=New-Object System.Drawing.Size(730,25);$groupTools.Controls.Add($lblAuxNote)

    # -- Faixa inferior --
    $progressBar          = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 560)
    $progressBar.Size     = New-Object System.Drawing.Size(770, 23)
    $form.Controls.Add($progressBar)

    $statusLabel          = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(10, 590)
    $statusLabel.Size     = New-Object System.Drawing.Size(770, 20)
    $statusLabel.Text     = "Aguardando inicio..."
    $form.Controls.Add($statusLabel)

    # -- Botao Iniciar --
    $startButton           = New-Object System.Windows.Forms.Button
    $startButton.Location  = New-Object System.Drawing.Point(10, 616)
    $startButton.Size      = New-Object System.Drawing.Size(770, 30)
    $startButton.Text      = "Iniciar Instalacao"
    $startButton.BackColor = [System.Drawing.Color]::PaleGreen
    $form.Controls.Add($startButton)

    $startButton.Add_Click({
        if($chkRequireClient.Checked -and ([string]::IsNullOrWhiteSpace($script:NGClient.Name))) {
            [System.Windows.Forms.MessageBox]::Show('Informe o nome do cliente ou desmarque Solicitar dados.','NG Master - Identificacao') | Out-Null
            NG-ShowClientDialog $form
            if($chkRequireClient.Checked -and ([string]::IsNullOrWhiteSpace($script:NGClient.Name))){return}
        }
        if($cboShutdown.SelectedItem -eq 'No horario' -and $txtShutdown.Text -notmatch '^([01]\d|2[0-3]):[0-5]\d$'){
            [System.Windows.Forms.MessageBox]::Show('Informe um horario valido (HH:mm).','NG Master') | Out-Null;return
        }
        $startButton.Enabled   = $false
        $startButton.Text      = "Processando..."
        $txtTechnician.Enabled = $false
        $script:LogLines.Clear()
        $sessionStart   = Get-Date
        $script:NGTimerStart=$sessionStart
        $lblStart.Text="Inicio: $($sessionStart.ToString('HH:mm:ss'))"
        $lblElapsed.Text="Decorrido: 00:00:00"
        $clockTimer.Start()
        $technicianName = if (-not [string]::IsNullOrWhiteSpace($txtTechnician.Text)) { $txtTechnician.Text } else { "N/A" }
        Add-Log "==== Sessao iniciada em $($sessionStart.ToString('dd/MM/yyyy HH:mm:ss')) ===="
        Add-Log "Tecnico: $technicianName"
        $serviceId='OS-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+([guid]::NewGuid().ToString('N').Substring(0,6).ToUpperInvariant())
        try { $machineId=NG-MachineId; $past=@(NG-ReadHistory); $before=NG-Snapshot
              Add-Log "Atendimento $serviceId | Equipamento $machineId" }
        catch { $machineId='INDISPONIVEL';$past=@();$before=$null;Add-Log "Falha na identificacao inicial: $_" 'ERRO' }


        if ($chkApplyOemInfo.Checked) {
            $statusLabel.Text = "Gravando informacoes da formatacao..."; $statusLabel.Refresh()
            $installDate = Get-Date -Format "dd/MM/yyyy"
            $modelText   = "Config. Padrao (Por: $($technicianName) em $($installDate))"
            $oemPath     = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
            if (-not (Test-Path $oemPath)) {
                New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion" -Name "OEMInformation" -Force | Out-Null
            }
            Set-Volume -DriveLetter C -NewFileSystemLabel "Sistema" -ErrorAction SilentlyContinue
            New-ItemProperty -Path $oemPath -Name "Manufacturer" -Value "NG Master"                          -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $oemPath -Name "Model"        -Value $modelText                             -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $oemPath -Name "SupportURL"   -Value "https://marcosantoniorapado.com.br" -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $oemPath -Name "SupportHours" -Value "Seg a Sex - 8h as 18h"              -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $oemPath -Name "SupportPhone" -Value "(18) 997738569"                      -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $oemPath -Name "Logo"         -Value "C:\NG Master\logo.bmp"               -PropertyType String -Force | Out-Null
            Add-Log "OEM gravado: Tecnico=$technicianName, Data=$installDate"
            $statusLabel.Text = "Informacoes de OEM gravadas!"; $statusLabel.Refresh()
            Start-Sleep -Seconds 1
        }

        if ($chkOffice.Checked) {
            $statusLabel.Text = "Baixando Office..."; $statusLabel.Refresh(); $progressBar.Value = 20
            $filePath = Join-Path $env:TEMP "OfficeSetup.exe"
            try {
                Add-Log "Baixando Office"
                Invoke-WebRequest -Uri "https://marcosantoniorapado.github.io/downloads/OfficeSetup.exe" -OutFile $filePath -ErrorAction Stop
                $statusLabel.Text = "Executando Office..."; $statusLabel.Refresh(); $progressBar.Value = 60
                $proc = Start-Process -FilePath $filePath -PassThru -ErrorAction Stop
                while (-not $proc.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 500 }
                Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
                $statusLabel.Text = "Office instalado!"; $statusLabel.Refresh(); $progressBar.Value = 80
                Add-Log "Office instalado com sucesso."
            } catch {
                $statusLabel.Text = "Erro ao instalar Office."; $statusLabel.Refresh(); $progressBar.Value = 0
                Add-Log "Erro ao instalar Office: $_" "ERRO"
            }
        }

        if ($chkNinite.Checked) {
            Download-Execute-And-Clean `
                -Url "https://marcosantoniorapado.github.io/downloads/Ninite%20AnyDesk%20Chrome%20Firefox%20WinRAR%20Installer.exe" `
                -FileName "NiniteInstaller.exe" -ProcessName "NiniteInstaller" `
                -StatusLabel $statusLabel -ProgressBar $progressBar -NoWait
        }

        if ($chkRustDesk.Checked) {
            Download-To-Desktop -Url "https://marcosantoniorapado.com.br/downloads/rustdesk-1.4.2-x86_64.exe" `
                -FileName "rustdesk-1.4.2-x86_64.exe" -StatusLabel $statusLabel -ProgressBar $progressBar
        }

        if ($chkDriverBooster.Checked) {
            Download-To-Desktop -Url "https://marcosantoniorapado.com.br/downloads/driver_booster_setup.exe" `
                -FileName "driver_booster_setup.exe" -StatusLabel $statusLabel -ProgressBar $progressBar
        }

        if ($chkRede.Checked) {
            $statusLabel.Text = "Aplicando configuracoes de REDE..."; $statusLabel.Refresh()
            Add-Log "Aplicando ajustes SMB"
            Set-SmbClientConfiguration -RequireSecuritySignature $false -Force | Out-Null
            Set-SmbClientConfiguration -EnableInsecureGuestLogons $true  -Force | Out-Null
            Add-Log "SMB: RequireSecuritySignature=false, EnableInsecureGuestLogons=true"
            $statusLabel.Text = "Configuracoes de REDE aplicadas."; $statusLabel.Refresh()
        }

        if ($chkFilaImpressao.Checked) {
            $statusLabel.Text = "Limpando fila de impressao..."; $statusLabel.Refresh(); $progressBar.Value = 0
            if (Clear-PrintQueue -StatusLabel $statusLabel -ProgressBar $progressBar) {
                $statusLabel.Text = "Fila de impressao limpa."; $statusLabel.Refresh()
            } else {
                $statusLabel.Text = "Falha ao limpar a fila."; $statusLabel.Refresh()
            }
        }

        if ($chkCleanTemp.Checked) {
            $statusLabel.Text = "Limpando arquivos temporarios..."; $statusLabel.Refresh(); $progressBar.Value = 0
            Clear-TempFiles -StatusLabel $statusLabel -ProgressBar $progressBar
            $statusLabel.Text = "Temporarios removidos."; $statusLabel.Refresh()
        }

        # Relatorio final sera gerado depois do programa auxiliar e do ponto de restauracao.

        if ($chkAtivacao.Checked) {
            $statusLabel.Text = "Executando Programa de Ativacao..."; $statusLabel.Refresh()
            Add-Log "Iniciando ativacao via get.activated.win"
            try {
                $scriptContent = Invoke-RestMethod -Uri "https://get.activated.win"
                Invoke-Expression $scriptContent
                $statusLabel.Text = "Programa de Ativacao concluido."; $statusLabel.Refresh()
                Add-Log "Ativacao concluida."
            } catch {
                Add-Log "Erro na ativacao: $_" "ERRO"
            }
        }

        $restoreResult='Nao solicitado'
        if ($chkRestorePoint.Checked) {
            $statusLabel.Text = "Criando Ponto de Restauracao..."; $statusLabel.Refresh()
            Add-Log "Criando ponto de restauracao"
            try {
                Checkpoint-Computer -Description "Ponto de restauracao pos-instalacao de apps" -RestorePointType "MODIFY_SETTINGS"
                $restoreResult="Criacao solicitada sem erro"
                Add-Log "Ponto de restauracao criado."
            } catch {
                $restoreResult="Falha na criacao"
                Add-Log "Erro ao criar ponto de restauracao: $_" "ERRO"
            }
            Start-Sleep -Seconds 1
        }

        # Finalizacao documental: apos as tarefas, a etapa auxiliar e a coleta final.
        # A mesma hora de encerramento/duracao e usada em TXT, HTML, JSON, Discord e log.
        $statusLabel.Text='Registrando historico e relatorio HTML...';$statusLabel.Refresh()
        $reportSaved=$false
        $sessionEnd=$null
        $duration=$null
        $record=$null
        try {
            $after=NG-Snapshot
            $previous=if($past.Count){$past[-1]}else{$null}
            $comparison=NG-Compare $previous $after
            $sessionEnd=Get-Date
            $elapsed=$sessionEnd-$sessionStart
            $duration=('{0:00}:{1:00}:{2:00}' -f [math]::Floor($elapsed.TotalHours),$elapsed.Minutes,$elapsed.Seconds)
            $errorCount=@($script:LogLines | Where-Object {$_ -match '\[ERRO\]'}).Count
            $record=[pscustomobject]@{
                ServiceId=$serviceId;MachineId=$machineId;Technician=$technicianName
                Started=$sessionStart.ToString('dd/MM/yyyy HH:mm:ss');Finished=$sessionEnd.ToString('dd/MM/yyyy HH:mm:ss');Duration=$duration
                Client=[pscustomobject]@{Name=$script:NGClient.Name;Phone=$script:NGClient.Phone;Business=$script:NGClient.Business;Asset=$script:NGClient.Asset;Reason=$script:NGClient.Reason;Kind=$script:NGClient.Kind;ShowPhone=$script:NGClient.ShowPhone}
                Initial=$before;Final=$after;Comparison=$comparison;RestorePoint=$restoreResult
                ErrorCount=$errorCount;Log=@($script:LogLines.ToArray())
            }
            $outFile=NG-SaveService $record $past
            $reportSaved=$true
            Add-Log "Historico e HTML salvos: $outFile"
            if($chkSysReport.Checked){
                $reportText=Get-SystemReport -record $record
                $reportFilePath=Join-Path $script:NGRoot "relatorio_$((Get-Date -Format 'yyyyMMdd_HHmmss')).txt"
                $reportText | Out-File -FilePath $reportFilePath -Encoding UTF8
            }
            if($chkDiscord.Checked){
                try {
                    $webhook=NG-UnlockDiscord $txtDiscordPass.Text
                    NG-DiscordFinal $record $webhook
                } catch {
                    Add-Log 'Discord ignorado: senha incorreta, ausente ou webhook nao configurado.' 'AVISO'
                } finally {
                    $webhook=$null
                    $txtDiscordPass.Clear()
                }
            }
        } catch { Add-Log "Erro ao salvar historico/relatorio: $_" 'ERRO' }
        if ($null -eq $sessionEnd) {
            $sessionEnd=Get-Date
            $elapsed=$sessionEnd-$sessionStart
            $duration=('{0:00}:{1:00}:{2:00}' -f [math]::Floor($elapsed.TotalHours),$elapsed.Minutes,$elapsed.Seconds)
        }
        # O fim registrado acima e o fim das tarefas e da coleta final; os arquivos e a
        # notificacao sao gravados/enviados em seguida, sem mudar o horario historico.
        if ($chkSaveLog.Checked) {
            try {
                NG-EnsureFolders
                $logFilePath = Join-Path $script:NGRoot "log_$($sessionEnd.ToString('yyyyMMdd_HHmmss')).txt"
                $errosCount=@($script:LogLines | Where-Object {$_ -match '\[ERRO\]'}).Count
                $header = "====================================================`r`n" +
                          "  LOG DE EXECUCAO - Script Pos-Formatacao v5.6`r`n" +
                          "====================================================`r`n" +
                          "  Tecnico   : $technicianName`r`n" +
                          "  Inicio    : $($sessionStart.ToString('dd/MM/yyyy HH:mm:ss'))`r`n" +
                          "  Fim       : $($sessionEnd.ToString('dd/MM/yyyy HH:mm:ss'))`r`n" +
                          "  Duracao   : $duration`r`n" +
                          "====================================================`r`n`r`n"
                $footer = "`r`n====================================================`r`n  Total de erros registrados: $errosCount`r`n====================================================`r`n"
                ($header + ($script:LogLines -join "`r`n") + $footer) | Out-File -FilePath $logFilePath -Encoding UTF8
                $logPath=Join-Path $script:NGRoot "log_final_$((Get-Date -Format 'yyyyMMdd_HHmmss')).txt"
                $script:LogLines | Out-File -FilePath $logPath -Encoding UTF8
                $statusLabel.Text = "Log salvo em $logFilePath";$statusLabel.Refresh()
            } catch { Add-Log "Erro ao salvar log final: $_" 'ERRO' }
        }
        if($reportSaved){NG-Shutdown ([string]$cboShutdown.SelectedItem) $txtShutdown.Text $chkAtivacao.Checked}
        else{Add-Log "Desligamento cancelado: historico nao foi salvo." "AVISO"}

        $clockTimer.Stop()
        $lblElapsed.Text='Decorrido: '+$duration
        $script:NGTimerStart=$null
        $progressBar.Value = 100
        $statusLabel.Text  = "Processo concluido!"
        $startButton.Text  = "Finalizado"
        [System.Windows.Forms.MessageBox]::Show("Execucao finalizada. Consulte os logs e relatorio para resultados e possiveis falhas.", "Finalizado", "OK", "Information")
        $form.Close()
    })

    $form.ShowDialog() | Out-Null
}

#endregion

Show-InstallerGUI
