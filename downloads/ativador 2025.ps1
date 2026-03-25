<#
    Versão: 5.3 - Criado por Marcos
    Data: 24/03/2026

    Novidades da Versão 5.3:
    - NOVO: Função de limpeza de arquivos temporários (%TEMP%, C:\Windows\Temp, cache Windows Update).
    - NOVO: Relatório do sistema — versão Windows, ativação, CPU, RAM, disco, IP, nome da máquina.
    - NOVO: Envio de relatório resumido via Discord Webhook (dispara antes da Ativação, ou no fim).
    - REORDENAÇÃO: Ativação reposicionada para sempre ser o último processo automatizado.
    - CORREÇÃO: icacls com aspas corretas no argumento de permissão (OI)(CI).

    Como Usar:
    1. Execute com permissões de administrador (ou use o executar_como_admin.bat).
    2. Na GUI:
        - Preencha o nome do técnico.
        - Selecione as opções desejadas.
        - Clique em "Iniciar Instalação".
#>

#region Funções Principais e Configurações Iniciais

$corTitulo   = "Yellow"
$corDestaque = "Cyan"
$corAlerta   = "Red"
$corSucesso  = "Green"

# Webhook do Discord
$script:DiscordWebhook = "https://discord.com/api/webhooks/1479503482091339951/pQGSZpyo6yVCUSgLF2PdX9HRiDjMYmZxTa5-5PnqXT_izAEIOtJblUBh2H6SgONZlqt9"

# Log global da sessão
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

# ── Relatório do sistema ──────────────────────────────────────────────────────
function Get-SystemReport {
    param([string]$TechnicianName = "N/A")

    $os      = Get-CimInstance Win32_OperatingSystem
    $cpu     = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()
    $ramGB   = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $disk    = Get-PSDrive -Name C | Select-Object Used, Free
    $usedGB  = [math]::Round($disk.Used / 1GB, 1)
    $freeGB  = [math]::Round($disk.Free / 1GB, 1)
    $totalGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 1)
    $ip      = (Get-NetIPAddress -AddressFamily IPv4 |
                Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
                Select-Object -First 1).IPAddress
    $hostname = $env:COMPUTERNAME
    $winVer   = "$($os.Caption) (Build $($os.BuildNumber))"
    $edition  = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" `
                    -Name EditionID -ErrorAction SilentlyContinue).EditionID

    $activationStatus = try {
        $slmgr = cscript //nologo "$env:windir\System32\slmgr.vbs" /dli 2>&1
        if ($slmgr -match "Licensed") { "Ativado" } else { "Nao ativado" }
    } catch { "Indisponivel" }

    $now = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

    $report = @"
====================================================
  RELATORIO DO SISTEMA - NG Master
====================================================
  Tecnico     : $TechnicianName
  Data/Hora   : $now
----------------------------------------------------
  Computador  : $hostname
  IP Local    : $ip
  Windows     : $winVer
  Edicao      : $edition
  Ativacao    : $activationStatus
----------------------------------------------------
  CPU         : $cpu
  RAM Total   : $ramGB GB
  Disco C:    : $usedGB GB usados / $freeGB GB livres / $totalGB GB total
====================================================
"@
    return $report
}

# ── Envio para Discord ────────────────────────────────────────────────────────
function Send-DiscordReport {
    param([string]$TechnicianName = "N/A")

    try {
        $os       = Get-CimInstance Win32_OperatingSystem
        $hostname = $env:COMPUTERNAME
        $ip       = (Get-NetIPAddress -AddressFamily IPv4 |
                     Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
                     Select-Object -First 1).IPAddress
        $ramGB    = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $freeGB   = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 1)
        $now      = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

        $activationStatus = try {
            $slmgr = cscript //nologo "$env:windir\System32\slmgr.vbs" /dli 2>&1
            if ($slmgr -match "Licensed") { "Ativado" } else { "Nao ativado" }
        } catch { "Indisponivel" }

        $erros   = ($script:LogLines | Where-Object { $_ -match '\[ERRO\]' }).Count
        $erroTxt = if ($erros -gt 0) { "ATENCAO: $erros erro(s) registrado(s)" } else { "Sem erros" }

        $mensagem = "**Script Pos-Formatacao v5.3 - Concluido**`n" +
                    "Data: $now`n" +
                    "Tecnico: $TechnicianName`n`n" +
                    "**Maquina:** $hostname`n" +
                    "**IP:** $ip`n" +
                    "**Windows:** $($os.Caption)`n" +
                    "**RAM:** $ramGB GB  |  **Disco C livre:** $freeGB GB`n" +
                    "**Ativacao:** $activationStatus`n`n" +
                    $erroTxt

        $body = @{ content = $mensagem } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $script:DiscordWebhook -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
        Add-Log "Relatorio enviado para o Discord."
    } catch {
        Add-Log "Erro ao enviar para Discord: $_" "ERRO"
    }
}

# ── Limpeza de temporários ────────────────────────────────────────────────────
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

# ── Fila de impressão ─────────────────────────────────────────────────────────
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

# ── Download + execução genérica ──────────────────────────────────────────────
function Download-Execute-And-Clean {
    param (
        [string]$Url, [string]$FileName, [string]$ProcessName,
        [System.Windows.Forms.Label]$StatusLabel = $null,
        [System.Windows.Forms.ProgressBar]$ProgressBar = $null,
        [switch]$NoWait   # Dispara o processo e segue sem esperar ele fechar
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
            # Dispara e segue — a janela do instalador fica aberta em background
            Start-Process -FilePath $filePath -ErrorAction Stop
            Start-Sleep -Seconds 2
            & $updateUI "$FileName iniciado (continua em background).", 100
            Add-Log "$FileName iniciado — script continua sem aguardar conclusao."
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

# ── Download para Área de Trabalho ────────────────────────────────────────────
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

#region Interface Gráfica (Windows Forms)

function Show-InstallerGUI {
    $kernel32 = Add-Type -memberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();' -name 'kernel32' -namespace 'Win32' -passThru
    $user32   = Add-Type -memberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);' -name 'user32' -namespace 'Win32' -passThru
    $consoleHandle = $kernel32::GetConsoleWindow()
    if ($null -ne $consoleHandle) { $user32::ShowWindow($consoleHandle, 0) | Out-Null }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Layout em duas colunas
    # Coluna A (esquerda):  x=10,  largura=390  — Informacoes + Programas
    # Coluna B (direita):   x=410, largura=370  — Rede + Limpeza + Acoes Finais
    # Faixa inferior:       y=370, largura=total — Progresso + Status + Botao

    $form               = New-Object System.Windows.Forms.Form
    $form.Text          = "Script Pos-Formatacao v5.3"
    $form.Size          = New-Object System.Drawing.Size(810, 545)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox   = $false
    $form.Icon          = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
    $font               = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Font          = $font

    # ── COLUNA A — Informações da Formatação ──────────────────────────────
    $groupInfo          = New-Object System.Windows.Forms.GroupBox
    $groupInfo.Location = New-Object System.Drawing.Point(10, 10)
    $groupInfo.Size     = New-Object System.Drawing.Size(390, 90)
    $groupInfo.Text     = "Informacoes da Formatacao"
    $form.Controls.Add($groupInfo)

    $labelTechnician          = New-Object System.Windows.Forms.Label
    $labelTechnician.Text     = "Formatado por:"
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

    # ── COLUNA A — Programas ──────────────────────────────────────────────
    $groupPrograms          = New-Object System.Windows.Forms.GroupBox
    $groupPrograms.Location = New-Object System.Drawing.Point(10, 110)
    $groupPrograms.Size     = New-Object System.Drawing.Size(390, 245)
    $groupPrograms.Text     = "Selecionar Programas para Instalar/Baixar"
    $form.Controls.Add($groupPrograms)

    $chkSelectAll             = New-Object System.Windows.Forms.CheckBox; $chkSelectAll.Text     = "Selecionar/Desmarcar Todos";                          $chkSelectAll.Location     = New-Object System.Drawing.Point(20, 25);  $chkSelectAll.AutoSize = $true
    $chkOffice                = New-Object System.Windows.Forms.CheckBox; $chkOffice.Text        = "Instalar Microsoft Office";                            $chkOffice.Location        = New-Object System.Drawing.Point(20, 60);  $chkOffice.AutoSize = $true
    $chkNinite                = New-Object System.Windows.Forms.CheckBox; $chkNinite.Text        = "Instalar (Ninite): AnyDesk, Chrome, Firefox, WinRAR"; $chkNinite.Location        = New-Object System.Drawing.Point(20, 95);  $chkNinite.AutoSize = $true
    $chkRustDesk              = New-Object System.Windows.Forms.CheckBox; $chkRustDesk.Text      = "Baixar RustDesk para a Area de Trabalho";              $chkRustDesk.Location      = New-Object System.Drawing.Point(20, 130); $chkRustDesk.AutoSize = $true
    $chkDriverBooster         = New-Object System.Windows.Forms.CheckBox; $chkDriverBooster.Text = "Baixar Driver Booster para a Area de Trabalho";        $chkDriverBooster.Location = New-Object System.Drawing.Point(20, 165); $chkDriverBooster.AutoSize = $true
    $chkAtivacao              = New-Object System.Windows.Forms.CheckBox; $chkAtivacao.Text      = "Executar Programa de Ativacao (ultima etapa)";         $chkAtivacao.Location      = New-Object System.Drawing.Point(20, 205); $chkAtivacao.AutoSize = $true
    $groupPrograms.Controls.AddRange(@($chkSelectAll, $chkOffice, $chkNinite, $chkRustDesk, $chkDriverBooster, $chkAtivacao))

    # ── COLUNA B — Manutenção e Rede ──────────────────────────────────────
    $groupNetwork          = New-Object System.Windows.Forms.GroupBox
    $groupNetwork.Location = New-Object System.Drawing.Point(410, 10)
    $groupNetwork.Size     = New-Object System.Drawing.Size(370, 90)
    $groupNetwork.Text     = "Manutencao e Rede"
    $form.Controls.Add($groupNetwork)

    $chkRede                   = New-Object System.Windows.Forms.CheckBox
    $chkRede.Text              = "Ajustar SMB para compatibilidade (redes confiaveis)"
    $chkRede.Location          = New-Object System.Drawing.Point(15, 25)
    $chkRede.AutoSize          = $true
    $chkFilaImpressao          = New-Object System.Windows.Forms.CheckBox
    $chkFilaImpressao.Text     = "Limpar fila de impressao"
    $chkFilaImpressao.Location = New-Object System.Drawing.Point(15, 55)
    $chkFilaImpressao.AutoSize = $true
    $groupNetwork.Controls.AddRange(@($chkRede, $chkFilaImpressao))

    # ── COLUNA B — Limpeza e Diagnóstico ──────────────────────────────────
    $groupClean          = New-Object System.Windows.Forms.GroupBox
    $groupClean.Location = New-Object System.Drawing.Point(410, 110)
    $groupClean.Size     = New-Object System.Drawing.Size(370, 90)
    $groupClean.Text     = "Limpeza e Diagnostico"
    $form.Controls.Add($groupClean)

    $chkCleanTemp          = New-Object System.Windows.Forms.CheckBox
    $chkCleanTemp.Text     = "Limpar temporarios (%TEMP%, Windows\Temp, WU)"
    $chkCleanTemp.Location = New-Object System.Drawing.Point(15, 25)
    $chkCleanTemp.AutoSize = $true
    $chkSysReport          = New-Object System.Windows.Forms.CheckBox
    $chkSysReport.Text     = "Gerar relatorio do sistema + notificar Discord"
    $chkSysReport.Location = New-Object System.Drawing.Point(15, 55)
    $chkSysReport.AutoSize = $true
    $chkSysReport.Checked  = $true
    $groupClean.Controls.AddRange(@($chkCleanTemp, $chkSysReport))

    # ── COLUNA B — Ações Finais ───────────────────────────────────────────
    $groupPost          = New-Object System.Windows.Forms.GroupBox
    $groupPost.Location = New-Object System.Drawing.Point(410, 210)
    $groupPost.Size     = New-Object System.Drawing.Size(370, 145)
    $groupPost.Text     = "Acoes Finais"
    $form.Controls.Add($groupPost)

    $chkMoveScript          = New-Object System.Windows.Forms.CheckBox
    $chkMoveScript.Text     = "Salvar este script em C:\NG Master"
    $chkMoveScript.Location = New-Object System.Drawing.Point(15, 28)
    $chkMoveScript.AutoSize = $true
    $chkRestorePoint          = New-Object System.Windows.Forms.CheckBox
    $chkRestorePoint.Text     = "Criar Ponto de Restauracao ao final"
    $chkRestorePoint.Location = New-Object System.Drawing.Point(15, 63)
    $chkRestorePoint.AutoSize = $true
    $chkRestorePoint.Checked  = $true
    $chkSaveLog          = New-Object System.Windows.Forms.CheckBox
    $chkSaveLog.Text     = "Salvar log de metricas em C:\NG Master"
    $chkSaveLog.Location = New-Object System.Drawing.Point(15, 98)
    $chkSaveLog.AutoSize = $true
    $chkSaveLog.Checked  = $true
    $groupPost.Controls.AddRange(@($chkMoveScript, $chkRestorePoint, $chkSaveLog))

    # Ação do CheckBox "Selecionar Todos"
    $chkSelectAll.Add_Click({
        $isChecked = $chkSelectAll.Checked
        $chkApplyOemInfo.Checked  = $isChecked; $chkOffice.Checked = $isChecked; $chkNinite.Checked = $isChecked
        $chkRustDesk.Checked      = $isChecked; $chkDriverBooster.Checked = $isChecked; $chkAtivacao.Checked = $isChecked
        $chkRede.Checked          = $isChecked; $chkFilaImpressao.Checked = $isChecked
        $chkCleanTemp.Checked     = $isChecked; $chkSysReport.Checked = $isChecked
        $chkMoveScript.Checked    = $isChecked; $chkRestorePoint.Checked = $isChecked; $chkSaveLog.Checked = $isChecked
    })

    # ── Faixa inferior — Progresso, Status e Botão ────────────────────────
    $progressBar          = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 375)
    $progressBar.Size     = New-Object System.Drawing.Size(770, 23)
    $form.Controls.Add($progressBar)

    $statusLabel          = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(10, 405)
    $statusLabel.Size     = New-Object System.Drawing.Size(770, 20)
    $statusLabel.Text     = "Aguardando inicio..."
    $form.Controls.Add($statusLabel)

    # ── Botão Iniciar ─────────────────────────────────────────────────────
    $startButton           = New-Object System.Windows.Forms.Button
    $startButton.Location  = New-Object System.Drawing.Point(10, 430)
    $startButton.Size      = New-Object System.Drawing.Size(770, 30)
    $startButton.Text      = "Iniciar Instalacao"
    $startButton.BackColor = [System.Drawing.Color]::PaleGreen
    $form.Controls.Add($startButton)

    $startButton.Add_Click({
        $startButton.Enabled   = $false
        $startButton.Text      = "Processando..."
        $txtTechnician.Enabled = $false
        $script:LogLines.Clear()
        $sessionStart   = Get-Date
        $technicianName = if (-not [string]::IsNullOrWhiteSpace($txtTechnician.Text)) { $txtTechnician.Text } else { "N/A" }
        Add-Log "==== Sessao iniciada em $($sessionStart.ToString('dd/MM/yyyy HH:mm:ss')) ===="
        Add-Log "Tecnico: $technicianName"

        # ── OEM Info ──────────────────────────────────────────────────────
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
            New-ItemProperty -Path $oemPath -Name "Model"        -Value $modelText                           -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $oemPath -Name "SupportURL"   -Value "https://marcosantoniorapado.com.br" -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $oemPath -Name "SupportHours" -Value "Seg a Sex - 8h as 18h"             -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $oemPath -Name "SupportPhone" -Value "(18) 997738569"                     -PropertyType String -Force | Out-Null
            New-ItemProperty -Path $oemPath -Name "Logo"         -Value "C:\NG Master\logo.bmp"              -PropertyType String -Force | Out-Null
            Add-Log "OEM gravado: Tecnico=$technicianName, Data=$installDate"
            $statusLabel.Text = "Informacoes de OEM gravadas!"; $statusLabel.Refresh()
            Start-Sleep -Seconds 1
        }

        # ── Office ────────────────────────────────────────────────────────
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

        # ── Ninite ────────────────────────────────────────────────────────
        if ($chkNinite.Checked) {
            Download-Execute-And-Clean `
                -Url "https://marcosantoniorapado.github.io/downloads/Ninite%20AnyDesk%20Chrome%20Firefox%20WinRAR%20Installer.exe" `
                -FileName "NiniteInstaller.exe" -ProcessName "NiniteInstaller" `
                -StatusLabel $statusLabel -ProgressBar $progressBar -NoWait
        }

        # ── RustDesk ──────────────────────────────────────────────────────
        if ($chkRustDesk.Checked) {
            Download-To-Desktop -Url "https://marcosantoniorapado.com.br/downloads/rustdesk-1.4.2-x86_64.exe" `
                -FileName "rustdesk-1.4.2-x86_64.exe" -StatusLabel $statusLabel -ProgressBar $progressBar
        }

        # ── Driver Booster ────────────────────────────────────────────────
        if ($chkDriverBooster.Checked) {
            Download-To-Desktop -Url "https://marcosantoniorapado.com.br/downloads/driver_booster_setup.exe" `
                -FileName "driver_booster_setup.exe" -StatusLabel $statusLabel -ProgressBar $progressBar
        }

        # ── SMB / Rede ────────────────────────────────────────────────────
        if ($chkRede.Checked) {
            $statusLabel.Text = "Aplicando configuracoes de REDE..."; $statusLabel.Refresh()
            Add-Log "Aplicando ajustes SMB"
            Set-SmbClientConfiguration -RequireSecuritySignature $false -Force | Out-Null
            Set-SmbClientConfiguration -EnableInsecureGuestLogons $true  -Force | Out-Null
            Add-Log "SMB: RequireSecuritySignature=false, EnableInsecureGuestLogons=true"
            $statusLabel.Text = "Configuracoes de REDE aplicadas."; $statusLabel.Refresh()
        }

        # ── Fila de Impressão ─────────────────────────────────────────────
        if ($chkFilaImpressao.Checked) {
            $statusLabel.Text = "Limpando fila de impressao..."; $statusLabel.Refresh(); $progressBar.Value = 0
            if (Clear-PrintQueue -StatusLabel $statusLabel -ProgressBar $progressBar) {
                $statusLabel.Text = "Fila de impressao limpa."; $statusLabel.Refresh()
            } else {
                $statusLabel.Text = "Falha ao limpar a fila."; $statusLabel.Refresh()
            }
        }

        # ── Limpeza de Temporários ────────────────────────────────────────
        if ($chkCleanTemp.Checked) {
            $statusLabel.Text = "Limpando arquivos temporarios..."; $statusLabel.Refresh(); $progressBar.Value = 0
            Clear-TempFiles -StatusLabel $statusLabel -ProgressBar $progressBar
            $statusLabel.Text = "Temporarios removidos."; $statusLabel.Refresh()
        }

        # ── Relatório + Discord (SEMPRE antes da Ativação) ────────────────
        if ($chkSysReport.Checked) {
            $statusLabel.Text = "Gerando relatorio do sistema..."; $statusLabel.Refresh()
            Add-Log "Gerando relatorio do sistema"
            $destFolder = "C:\NG Master"
            if (-not (Test-Path $destFolder)) { New-Item -Path $destFolder -ItemType Directory | Out-Null }
            $reportText     = Get-SystemReport -TechnicianName $technicianName
            $reportFilePath = Join-Path $destFolder "relatorio_$((Get-Date -Format 'yyyyMMdd_HHmmss')).txt"
            $reportText | Out-File -FilePath $reportFilePath -Encoding UTF8
            Add-Log "Relatorio salvo em $reportFilePath"
            $statusLabel.Text = "Enviando notificacao para o Discord..."; $statusLabel.Refresh()
            Send-DiscordReport -TechnicianName $technicianName
            $statusLabel.Text = "Relatorio gerado e enviado."; $statusLabel.Refresh()
        }

        # ── Ativação (SEMPRE última etapa automatizada) ───────────────────
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

        # ── Salvar Script ─────────────────────────────────────────────────
        if ($chkMoveScript.Checked) {
            $statusLabel.Text = "Organizando script..."; $statusLabel.Refresh()
            $destFolder   = "C:\NG Master"
            if (-not (Test-Path $destFolder)) { New-Item -Path $destFolder -ItemType Directory | Out-Null }
            $scriptSource = $null
            if (-not [string]::IsNullOrWhiteSpace($PSCommandPath) -and (Test-Path $PSCommandPath)) {
                $scriptSource = $PSCommandPath
            }
            if (-not $scriptSource) {
                $candidate = Join-Path ([System.Environment]::GetFolderPath('UserProfile')) 'Downloads\ativador_2025.ps1'
                if (Test-Path $candidate) { $scriptSource = $candidate }
            }
            if ($scriptSource) {
                Copy-Item -Path $scriptSource -Destination $destFolder -Force
                Add-Log "Script copiado de '$scriptSource' para '$destFolder'"
                if ($scriptSource -like '*\Downloads\*') {
                    Remove-Item -Path $scriptSource -Force -ErrorAction SilentlyContinue
                    Add-Log "Script removido da pasta Downloads."
                }
                $statusLabel.Text = "Script salvo em $destFolder"; $statusLabel.Refresh()
            } else {
                Add-Log "Script nao encontrado para copia — salve manualmente em $destFolder." "AVISO"
                $statusLabel.Text = "Script nao encontrado para copia."; $statusLabel.Refresh()
            }
        }

        # ── Ponto de Restauração ──────────────────────────────────────────
        if ($chkRestorePoint.Checked) {
            $statusLabel.Text = "Criando Ponto de Restauracao..."; $statusLabel.Refresh()
            Add-Log "Criando ponto de restauracao"
            try {
                Checkpoint-Computer -Description "Ponto de restauracao pos-instalacao de apps" -RestorePointType "MODIFY_SETTINGS"
                Add-Log "Ponto de restauracao criado."
            } catch {
                Add-Log "Erro ao criar ponto de restauracao: $_" "ERRO"
            }
            Start-Sleep -Seconds 1
        }

        # ── Salvar Log ────────────────────────────────────────────────────
        if ($chkSaveLog.Checked) {
            $destFolder = "C:\NG Master"
            if (-not (Test-Path $destFolder)) { New-Item -Path $destFolder -ItemType Directory | Out-Null }
            $logFilePath = Join-Path $destFolder "log_$((Get-Date -Format 'yyyyMMdd_HHmmss')).txt"
            $sessionEnd  = Get-Date
            $duration    = ($sessionEnd - $sessionStart).ToString("hh\:mm\:ss")
            $errosCount  = ($script:LogLines | Where-Object { $_ -match '\[ERRO\]' }).Count
            $header = @"
====================================================
  LOG DE EXECUCAO - Script Pos-Formatacao v5.3
====================================================
  Tecnico   : $technicianName
  Inicio    : $($sessionStart.ToString('dd/MM/yyyy HH:mm:ss'))
  Fim       : $($sessionEnd.ToString('dd/MM/yyyy HH:mm:ss'))
  Duracao   : $duration
====================================================

"@
            $footer = "`n====================================================`n  Total de erros registrados: $errosCount`n====================================================`n"
            ($header + ($script:LogLines -join "`n") + $footer) | Out-File -FilePath $logFilePath -Encoding UTF8
            $statusLabel.Text = "Log salvo em $logFilePath"; $statusLabel.Refresh()
        }

        # ── Finalização ───────────────────────────────────────────────────
        $progressBar.Value = 100
        $statusLabel.Text  = "Processo concluido!"
        $startButton.Text  = "Finalizado"
        [System.Windows.Forms.MessageBox]::Show("Todas as tarefas selecionadas foram concluidas.", "Finalizado", "OK", "Information")
        $form.Close()
    })

    $form.ShowDialog() | Out-Null
}

#endregion

#region Modo Console (Legado)

function Start-ConsoleMode {
    Clear-Host
    Show-ConsoleMessage "====================================" $corDestaque
    Show-ConsoleMessage "   SCRIPT MARCOS v5.3 (Console)   " $corTitulo
    Show-ConsoleMessage "====================================" $corDestaque

    function Get-Choice {
        param ([string]$Prompt)
        Write-Host -Object $Prompt -ForegroundColor $corDestaque -NoNewLine
        while ($true) {
            $key = [System.Console]::ReadKey($true)
            if ('1', '2' -contains $key.KeyChar) { Write-Host $key.KeyChar; return $key.KeyChar }
        }
    }

    if ((Get-Choice "Instalar Office? (1-S/2-N): ") -eq '1') {
        Download-Execute-And-Clean "https://marcosantoniorapado.github.io/downloads/OfficeSetup.exe" "OfficeSetup.exe" "OfficeSetup"
    }
    if ((Get-Choice "Instalar (Ninite)? (1-S/2-N): ") -eq '1') {
        Download-Execute-And-Clean "https://marcosantoniorapado.github.io/downloads/Ninite%20AnyDesk%20Chrome%20Firefox%20WinRAR%20Installer.exe" "NiniteInstaller.exe" "NiniteInstaller"
    }
    if ((Get-Choice "Limpar fila de impressao? (1-S/2-N): ") -eq '1') { Clear-PrintQueue }
    if ((Get-Choice "Limpar arquivos temporarios? (1-S/2-N): ") -eq '1') { Clear-TempFiles }
    if ((Get-Choice "Aplicar configuracoes de REDE (SMB)? (1-S/2-N): ") -eq '1') {
        Set-SmbClientConfiguration -RequireSecuritySignature $false -Force | Out-Null
        Set-SmbClientConfiguration -EnableInsecureGuestLogons $true  -Force | Out-Null
    }
    if ((Get-Choice "Gerar relatorio e notificar Discord? (1-S/2-N): ") -eq '1') {
        $tech   = Read-Host "Nome do tecnico"
        $dest   = "C:\NG Master"; if (-not (Test-Path $dest)) { New-Item -Path $dest -ItemType Directory | Out-Null }
        $report = Get-SystemReport -TechnicianName $tech
        $report | Out-File -FilePath (Join-Path $dest "relatorio_$((Get-Date -Format 'yyyyMMdd_HHmmss')).txt") -Encoding UTF8
        Send-DiscordReport -TechnicianName $tech
    }
    if ((Get-Choice "Executar Programa de Ativacao? (1-S/2-N): ") -eq '1') {
        Invoke-Expression (Invoke-RestMethod -Uri "https://get.activated.win")
    }
    if ((Get-Choice "Salvar script em C:\NG Master? (1-S/2-N): ") -eq '1') {
        $dest = "C:\NG Master"; if (-not (Test-Path $dest)) { New-Item -Path $dest -ItemType Directory | Out-Null }
        if (-not [string]::IsNullOrWhiteSpace($PSCommandPath) -and (Test-Path $PSCommandPath)) {
            Copy-Item -Path $PSCommandPath -Destination $dest -Force
        }
    }
    if ((Get-Choice "Criar Ponto de Restauracao? (1-S/2-N): ") -eq '1') {
        Checkpoint-Computer -Description "Ponto de restauracao pos-instalacao" -RestorePointType "MODIFY_SETTINGS"
    }

    Show-ConsoleMessage "Script (Modo Console) concluido!" $corSucesso
    Start-Sleep -Seconds 3
}

#endregion

#============================== PONTO DE ENTRADA ==============================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Show-ConsoleMessage "Elevando privilegios..." $corDestaque
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs -Wait
    exit
}

Add-Type -AssemblyName System.Windows.Forms
$choice = [System.Windows.Forms.MessageBox]::Show("Deseja usar a Interface Grafica (GUI) para a instalacao?", "Modo de Execucao", "YesNo", "Question")

if ($choice -eq "Yes") { Show-InstallerGUI } else { Start-ConsoleMode }

Clear-History
exit
