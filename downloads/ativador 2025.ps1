<#
    Versão: 5.1 - Criado por Marcos
    Data: 21/10/2025

    Novidades da Versão 5.1:
    - O Ponto de Restauração agora é criado no FINAL de todo o processo, garantindo que todas as instalações estejam incluídas.
    - A informação do técnico e a data da formatação agora são adicionadas ao campo "Modelo" para serem facilmente visíveis nas Propriedades do Sistema.
    - Adicionada uma checkbox dedicada para a criação do Ponto de Restauração nas "Ações Finais".

    Como Usar:
    1. Execute com permissões de administrador.
    2. Na GUI:
        - Preencha o nome do técnico.
        - Selecione as opções desejadas.
        - Clique em "Iniciar Instalação".
#>

#region Funções Principais e Configurações Iniciais
# ... (Nenhuma mudança nesta seção, o código é o mesmo da versão anterior)
# Definição de cores para o modo console
$corTitulo    = "Yellow"
$corDestaque  = "Cyan"
$corAlerta    = "Red"
$corSucesso   = "Green"

# Função para exibir mensagens no console
function Show-ConsoleMessage {
    param ([string]$Message, [string]$Color = "White")
    Write-Host -ForegroundColor $Color $Message
}

# Função genérica para baixar, executar e limpar
function Download-Execute-And-Clean {
    param (
        [string]$Url, [string]$FileName, [string]$ProcessName,
        [System.Windows.Forms.Label]$StatusLabel = $null, [System.Windows.Forms.ProgressBar]$ProgressBar = $null
    )
    $updateUI = { param($text, $progress) if ($StatusLabel) { $StatusLabel.Text = $text; $StatusLabel.Refresh() }; if ($ProgressBar) { $ProgressBar.Value = $progress } }
    try {
        $filePath = Join-Path -Path $env:TEMP -ChildPath $FileName
        & $updateUI "Baixando $FileName...", 20; Show-ConsoleMessage "📥 Baixando $FileName..." $corDestaque
        Invoke-WebRequest -Uri $Url -OutFile $filePath -ErrorAction Stop
        & $updateUI "Download de $FileName concluído!", 50; Show-ConsoleMessage "✅ Download concluído!" $corSucesso
        & $updateUI "Executando $FileName...", 70; Show-ConsoleMessage "🔧 Executando $FileName..." $corDestaque
        Start-Process -FilePath $filePath -Wait
        if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) { Stop-Process -Name $ProcessName -Force }
        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
        & $updateUI "$FileName instalado.", 100; Show-ConsoleMessage "🗑️ Arquivo temporário removido." $corDestaque
    } catch {
        & $updateUI "Erro ao processar $FileName.", 0; Show-ConsoleMessage "❌ Erro ao baixar ou executar $($FileName): $_" $corAlerta
    }
}

# Função para baixar arquivos para a Área de Trabalho
function Download-To-Desktop {
    param (
        [string]$Url, [string]$FileName,
        [System.Windows.Forms.Label]$StatusLabel = $null, [System.Windows.Forms.ProgressBar]$ProgressBar = $null
    )
    $updateUI = { param($text, $progress) if ($StatusLabel) { $StatusLabel.Text = $text; $StatusLabel.Refresh() }; if ($ProgressBar) { $ProgressBar.Value = $progress } }
    try {
        $desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
        $filePath = Join-Path -Path $desktopPath -ChildPath $FileName
        & $updateUI "Baixando $FileName para a Área de Trabalho...", 50; Show-ConsoleMessage "📥 Baixando $FileName..." $corDestaque
        Invoke-WebRequest -Uri $Url -OutFile $filePath -ErrorAction Stop
        & $updateUI "Download de $FileName concluído!", 100; Show-ConsoleMessage "✅ Download concluído!" $corSucesso
    } catch {
        & $updateUI "Erro ao baixar $FileName.", 0; Show-ConsoleMessage "❌ Erro ao baixar $($FileName): $_" $corAlerta
    }
}
#endregion

#region Interface Gráfica (Windows Forms)

function Show-InstallerGUI {
    # Oculta a janela do console do PowerShell
    $kernel32 = Add-Type -memberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();' -name 'kernel32' -namespace 'Win32' -passThru
    $user32 = Add-Type -memberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);' -name 'user32' -namespace 'Win32' -passThru
    $consoleHandle = $kernel32::GetConsoleWindow(); if ($null -ne $consoleHandle) { $user32::ShowWindow($consoleHandle, 0) | Out-Null }

    # Carrega os assemblies necessários para a GUI
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Criação do formulário principal
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Script Pós-Formatação v5.1"
    $form.Size = New-Object System.Drawing.Size(420, 680) # Altura ajustada
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
    $font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Font = $font
    
    # GroupBox para Informações da Formatação
    $groupInfo = New-Object System.Windows.Forms.GroupBox
    $groupInfo.Location = New-Object System.Drawing.Point(10, 10)
    $groupInfo.Size = New-Object System.Drawing.Size(385, 90)
    $groupInfo.Text = "Informações da Formatação"
    $form.Controls.Add($groupInfo)

    $labelTechnician = New-Object System.Windows.Forms.Label
    $labelTechnician.Text = "Formatado por:"
    $labelTechnician.Location = New-Object System.Drawing.Point(20, 35)
    $labelTechnician.AutoSize = $true
    $groupInfo.Controls.Add($labelTechnician)

    $txtTechnician = New-Object System.Windows.Forms.TextBox
    $txtTechnician.Location = New-Object System.Drawing.Point(130, 32)
    $txtTechnician.Size = New-Object System.Drawing.Size(240, 25)
    $groupInfo.Controls.Add($txtTechnician)
    
    $chkApplyOemInfo = New-Object System.Windows.Forms.CheckBox
    $chkApplyOemInfo.Text = "Gravar informações de OEM e do técnico no Sistema"
    $chkApplyOemInfo.Location = New-Object System.Drawing.Point(20, 60)
    $chkApplyOemInfo.AutoSize = $true
    $chkApplyOemInfo.Checked = $true
    $groupInfo.Controls.Add($chkApplyOemInfo)

    # GroupBox para os programas
    $groupPrograms = New-Object System.Windows.Forms.GroupBox
    $groupPrograms.Location = New-Object System.Drawing.Point(10, 110)
    $groupPrograms.Size = New-Object System.Drawing.Size(385, 250)
    $groupPrograms.Text = "Selecionar Programas para Instalar/Baixar"
    $form.Controls.Add($groupPrograms)

    $chkSelectAll = New-Object System.Windows.Forms.CheckBox; $chkSelectAll.Text = "Selecionar/Desmarcar Todos"; $chkSelectAll.Location = New-Object System.Drawing.Point(20, 30); $chkSelectAll.AutoSize = $true
    $chkOffice = New-Object System.Windows.Forms.CheckBox; $chkOffice.Text = "Instalar Microsoft Office"; $chkOffice.Location = New-Object System.Drawing.Point(20, 60); $chkOffice.AutoSize = $true
    # ... outros checkboxes de programas ...
    $chkNinite = New-Object System.Windows.Forms.CheckBox; $chkNinite.Text = "Instalar (Ninite): AnyDesk, Chrome, Firefox, WinRAR"; $chkNinite.Location = New-Object System.Drawing.Point(20, 90); $chkNinite.AutoSize = $true
    $chkRustDesk = New-Object System.Windows.Forms.CheckBox; $chkRustDesk.Text = "Baixar RustDesk para a Área de Trabalho"; $chkRustDesk.Location = New-Object System.Drawing.Point(20, 120); $chkRustDesk.AutoSize = $true
    $chkDriverBooster = New-Object System.Windows.Forms.CheckBox; $chkDriverBooster.Text = "Baixar Driver Booster para a Área de Trabalho"; $chkDriverBooster.Location = New-Object System.Drawing.Point(20, 150); $chkDriverBooster.AutoSize = $true
    $chkUtilitario = New-Object System.Windows.Forms.CheckBox; $chkUtilitario.Text = "Executar Windows Utilitário (Winhance)"; $chkUtilitario.Location = New-Object System.Drawing.Point(20, 180); $chkUtilitario.AutoSize = $true
    $chkAtivacao = New-Object System.Windows.Forms.CheckBox; $chkAtivacao.Text = "Executar Programa de Ativação"; $chkAtivacao.Location = New-Object System.Drawing.Point(20, 210); $chkAtivacao.AutoSize = $true
    $groupPrograms.Controls.AddRange(@($chkSelectAll, $chkOffice, $chkNinite, $chkRustDesk, $chkDriverBooster, $chkUtilitario, $chkAtivacao))

    # GroupBox para as configurações de REDE
    $groupNetwork = New-Object System.Windows.Forms.GroupBox
    $groupNetwork.Location = New-Object System.Drawing.Point(10, 370)
    $groupNetwork.Size = New-Object System.Drawing.Size(385, 60)
    $groupNetwork.Text = "Configurações de Rede"
    $form.Controls.Add($groupNetwork)
    
    $chkRede = New-Object System.Windows.Forms.CheckBox; $chkRede.Text = "Ajustar SMB para compatibilidade (redes confiáveis)"; $chkRede.Location = New-Object System.Drawing.Point(20, 25); $chkRede.AutoSize = $true
    $groupNetwork.Controls.Add($chkRede)
    
    # GroupBox para ações pós-instalação
    $groupPost = New-Object System.Windows.Forms.GroupBox
    $groupPost.Location = New-Object System.Drawing.Point(10, 440)
    $groupPost.Size = New-Object System.Drawing.Size(385, 90) # Altura ajustada
    $groupPost.Text = "Ações Finais"
    $form.Controls.Add($groupPost)
    
    $chkMoveScript = New-Object System.Windows.Forms.CheckBox; $chkMoveScript.Text = "Salvar este script em C:\NG Master"; $chkMoveScript.Location = New-Object System.Drawing.Point(20, 25); $chkMoveScript.AutoSize = $true
    
    # ===== NOVO: Checkbox para Ponto de Restauração movido para cá =====
    $chkRestorePoint = New-Object System.Windows.Forms.CheckBox; $chkRestorePoint.Text = "Criar Ponto de Restauração ao final do processo"; $chkRestorePoint.Location = New-Object System.Drawing.Point(20, 55); $chkRestorePoint.AutoSize = $true; $chkRestorePoint.Checked = $true
    $groupPost.Controls.AddRange(@($chkMoveScript, $chkRestorePoint))

    # Ação do CheckBox "Selecionar Todos"
    $chkSelectAll.Add_Click({
        $isChecked = $chkSelectAll.Checked
        $chkApplyOemInfo.Checked = $isChecked
        $chkOffice.Checked = $isChecked; $chkNinite.Checked = $isChecked; $chkRustDesk.Checked = $isChecked; $chkDriverBooster.Checked = $isChecked; $chkUtilitario.Checked = $isChecked; $chkAtivacao.Checked = $isChecked
        $chkRede.Checked = $isChecked
        $chkMoveScript.Checked = $isChecked
        $chkRestorePoint.Checked = $isChecked # Adicionado ao "Selecionar Todos"
    })

    # Barra de Progresso e Status Label (posições Y ajustadas)
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 540)
    $progressBar.Size = New-Object System.Drawing.Size(385, 23)
    $form.Controls.Add($progressBar)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(10, 570)
    $statusLabel.Size = New-Object System.Drawing.Size(385, 20)
    $statusLabel.Text = "Aguardando início..."
    $form.Controls.Add($statusLabel)

    # Botão Iniciar (posição Y ajustada)
    $startButton = New-Object System.Windows.Forms.Button
    $startButton.Location = New-Object System.Drawing.Point(10, 600)
    $startButton.Size = New-Object System.Drawing.Size(385, 30)
    $startButton.Text = "Iniciar Instalação"
    $startButton.BackColor = [System.Drawing.Color]::PaleGreen
    
    # Ação do botão
    $startButton.Add_Click({
        $startButton.Enabled = $false; $startButton.Text = "Processando..."; $txtTechnician.Enabled = $false

        # Lógica para gravar informações de OEM e do técnico
        if ($chkApplyOemInfo.Checked) {
            $statusLabel.Text = "Gravando informações da formatação..."; $statusLabel.Refresh()
            $technicianName = if (-not [string]::IsNullOrWhiteSpace($txtTechnician.Text)) { $txtTechnician.Text } else { "N/A" }
            $installDate = Get-Date -Format "dd/MM/yyyy"
            
            # ===== MUDANÇA: Texto do modelo que será exibido nas Propriedades do Sistema =====
            $modelText = "Config. Padrão (Por: $($technicianName) em $($installDate))"
            
            $oemPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
            if (-not (Test-Path $oemPath)) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion" -Name "OEMInformation" -Force | Out-Null }
            
            # Grava as informações
            Set-Volume -DriveLetter C -NewFileSystemLabel "Sistema"
            New-ItemProperty -Path $oemPath -Name "Manufacturer" -Value "NG Master" -PropertyType String -Force
            New-ItemProperty -Path $oemPath -Name "Model" -Value $modelText -PropertyType String -Force # <-- Modelo modificado
            New-ItemProperty -Path $oemPath -Name "SupportURL" -Value "https://marcosantoniorapado.com.br" -PropertyType String -Force
            New-ItemProperty -Path $oemPath -Name "SupportHours" -Value "Seg a Sex - 8h às 18h" -PropertyType String -Force
            New-ItemProperty -Path $oemPath -Name "SupportPhone" -Value "(18) 997738569" -PropertyType String -Force
            New-ItemProperty -Path $oemPath -Name "Logo" -Value "C:\NG Master\logo.bmp" -PropertyType String -Force
            
            $statusLabel.Text = "Informações de OEM gravadas!"; $statusLabel.Refresh()
            Start-Sleep -Seconds 1
        }
        
        # Sequência de instalação de programas
        if ($chkOffice.Checked) { Download-Execute-And-Clean -Url "https://marcosantoniorapado.github.io/downloads/OfficeSetup.exe" -FileName "OfficeSetup.exe" -ProcessName "OfficeSetup" -StatusLabel $statusLabel -ProgressBar $progressBar }
        if ($chkNinite.Checked) { Download-Execute-And-Clean -Url "https://marcosantoniorapado.github.io/downloads/Ninite%20AnyDesk%20Chrome%20Firefox%20WinRAR%20Installer.exe" -FileName "NiniteInstaller.exe" -ProcessName "NiniteInstaller" -StatusLabel $statusLabel -ProgressBar $progressBar }
        if ($chkRustDesk.Checked) { Download-To-Desktop -Url "https://marcosantoniorapado.com.br/downloads/rustdesk-1.4.2-x86_64.exe" -FileName "rustdesk-1.4.2-x86_64.exe" -StatusLabel $statusLabel -ProgressBar $progressBar }
        if ($chkDriverBooster.Checked) { Download-To-Desktop -Url "https://marcosantoniorapado.com.br/downloads/driver_booster_setup.exe" -FileName "driver_booster_setup.exe" -StatusLabel $statusLabel -ProgressBar $progressBar }
        if ($chkUtilitario.Checked) {
            $statusLabel.Text = "Executando Windows Utilitário..."; $statusLabel.Refresh(); $scriptUrl = "https://github.com/memstechtips/Winhance/raw/main/Winhance.ps1"; $scriptPath = Join-Path $env:TEMP "Winhance.ps1"; Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath; Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait; Remove-Item $scriptPath -Force; $statusLabel.Text = "Windows Utilitário concluído."; $statusLabel.Refresh()
        }
        if ($chkRede.Checked) {
            $statusLabel.Text = "Aplicando configurações de REDE..."; $statusLabel.Refresh(); Set-SmbClientConfiguration -RequireSecuritySignature $false -Force | Out-Null; Set-SmbClientConfiguration -EnableInsecureGuestLogons $true -Force | Out-Null; $statusLabel.Text = "Configurações de REDE aplicadas."; $statusLabel.Refresh()
        }
        if ($chkAtivacao.Checked) {
            $statusLabel.Text = "Executando Programa de Ativação..."; $statusLabel.Refresh(); $scriptContent = Invoke-RestMethod -Uri "https://get.activated.win"; Invoke-Expression $scriptContent; $statusLabel.Text = "Programa de Ativação concluído."; $statusLabel.Refresh()
        }
        if ($chkMoveScript.Checked) {
            $statusLabel.Text = "Organizando script..."; $statusLabel.Refresh(); $destFolder = "C:\NG Master"; if (-not (Test-Path $destFolder)) { New-Item -Path $destFolder -ItemType Directory | Out-Null }; Copy-Item -Path $PSCommandPath -Destination $destFolder -Force; $statusLabel.Text = "Script salvo em $destFolder"; $statusLabel.Refresh()
        }

        # ===== MUDANÇA: Ponto de Restauração executado no FINAL =====
        if ($chkRestorePoint.Checked) {
            $statusLabel.Text = "Criando Ponto de Restauração final..."; $statusLabel.Refresh()
            Checkpoint-Computer -Description "Ponto de restauração pós-instalação de apps" -RestorePointType "MODIFY_SETTINGS"
            $statusLabel.Text = "Ponto de Restauração criado com sucesso!"; $statusLabel.Refresh()
            Start-Sleep -Seconds 1
        }

        $progressBar.Value = 100
        $statusLabel.Text = "Processo concluído!"
        $startButton.Text = "Finalizado"
        [System.Windows.Forms.MessageBox]::Show("Todas as tarefas selecionadas foram concluídas.", "Finalizado", "OK", "Information")
        $form.Close()
    })
    $form.Controls.Add($startButton)

    # Exibe o formulário
    $form.ShowDialog() | Out-Null
}
#endregion

#region Modo Console (Legado)
# ... (Nenhuma mudança nesta seção, o modo console continua como estava)
function Start-ConsoleMode {
    Clear-Host; Show-ConsoleMessage "====================================" $corDestaque; Show-ConsoleMessage "     🚀 SCRIPT MARCOS v5.1 (Modo Console)     " $corTitulo; Show-ConsoleMessage "====================================" $corDestaque
    function Get-Choice { param ([string]$Prompt); Write-Host -Object $Prompt -ForegroundColor $corDestaque -NoNewLine; while ($true) { $key = [System.Console]::ReadKey($true); if ('1', '2' -contains $key.KeyChar) { Write-Host $key.KeyChar; return $key.KeyChar } } }
    if ((Get-Choice "Instalar Office? (1-S/2-N): ") -eq '1') { Download-Execute-And-Clean "https://marcosantoniorapado.github.io/downloads/OfficeSetup.exe" "OfficeSetup.exe" "OfficeSetup" }
    if ((Get-Choice "Instalar (Ninite)? (1-S/2-N): ") -eq '1') { Download-Execute-And-Clean "https://marcosantoniorapado.github.io/downloads/Ninite%20AnyDesk%20Chrome%20Firefox%20WinRAR%20Installer.exe" "NiniteInstaller.exe" "NiniteInstaller" }
    # ... outros prompts do modo console ...
    Show-ConsoleMessage "Aplicando configurações de REDE..." $corDestaque; Set-SmbClientConfiguration -RequireSecuritySignature $false -Force | Out-Null; Set-SmbClientConfiguration -EnableInsecureGuestLogons $true -Force | Out-Null
    Show-ConsoleMessage "Executando Programa de Ativação..." $corDestaque; Invoke-Expression (Invoke-RestMethod -Uri "https://get.activated.win")
    Show-ConsoleMessage "Salvando script em C:\NG Master..." $corDestaque; $destFolder = "C:\NG Master"; if (-not (Test-Path $destFolder)) { New-Item -Path $destFolder -ItemType Directory | Out-Null }; Copy-Item -Path $PSCommandPath -Destination $destFolder -Force
    Show-ConsoleMessage "Criando Ponto de Restauração..." $corDestaque; Checkpoint-Computer -Description "Ponto de restauração pós-instalação" -RestorePointType "MODIFY_SETTINGS"
    Show-ConsoleMessage "🔚 Script (Modo Console) concluído!" $corSucesso; Start-Sleep -Seconds 3
}
#endregion

#============================== PONTO DE ENTRADA DO SCRIPT ==============================

# Verifica se é administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Show-ConsoleMessage "🔄 Elevando privilégios..." $corDestaque
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs -Wait
    exit
}

# Escolha do modo de execução
Add-Type -AssemblyName System.Windows.Forms
$choice = [System.Windows.Forms.MessageBox]::Show("Deseja usar a Interface Gráfica (GUI) para a instalação?", "Modo de Execução", "YesNo", "Question")

if ($choice -eq "Yes") {
    Show-InstallerGUI
} else {
    Start-ConsoleMode
}

Clear-History
exit
