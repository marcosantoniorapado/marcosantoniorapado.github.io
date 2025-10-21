<#
    Versão: 4.1 - Criado por Marcos (GUI aprimorada com "Selecionar Todos" e ocultação do console)
    Data: 21/10/2025

    Como Usar:
    1. Execute-o no PowerShell com permissões de administrador.
    2. Escolha entre a Interface Gráfica (GUI) ou o Modo Console.
    3. Na GUI:
        - Marque os programas e ações desejados (use "Selecionar Todos" para agilizar).
        - Clique em "Iniciar Instalação".
        - Acompanhe o progresso e aguarde a finalização.
#>

#region Funções Principais e Configurações Iniciais

# Definição de cores para o modo console
$corTitulo    = "Yellow"
$corDestaque  = "Cyan"
$corAlerta    = "Red"
$corSucesso   = "Green"

# Função para exibir mensagens no console
function Show-ConsoleMessage {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host -ForegroundColor $Color $Message
}

# Função genérica para baixar, executar e limpar (usada por ambos os modos)
function Download-Execute-And-Clean {
    param (
        [string]$Url,
        [string]$FileName,
        [string]$ProcessName,
        [System.Windows.Forms.Label]$StatusLabel = $null,
        [System.Windows.Forms.ProgressBar]$ProgressBar = $null
    )
    $updateUI = { param($text, $progress) if ($StatusLabel) { $StatusLabel.Text = $text; $StatusLabel.Refresh() }; if ($ProgressBar) { $ProgressBar.Value = $progress } }

    try {
        $filePath = Join-Path -Path $env:TEMP -ChildPath $FileName
        & $updateUI "Baixando $FileName...", 20
        Show-ConsoleMessage "📥 Baixando $FileName..." $corDestaque

        Invoke-WebRequest -Uri $Url -OutFile $filePath -ErrorAction Stop
        & $updateUI "Download de $FileName concluído!", 50
        Show-ConsoleMessage "✅ Download concluído!" $corSucesso

        & $updateUI "Executando $FileName...", 70
        Show-ConsoleMessage "🔧 Executando $FileName..." $corDestaque
        Start-Process -FilePath $filePath -Wait

        if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
            Stop-Process -Name $ProcessName -Force
        }

        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
        & $updateUI "$FileName instalado.", 100
        Show-ConsoleMessage "🗑️ Arquivo temporário removido." $corDestaque
    }
    catch {
        & $updateUI "Erro ao processar $FileName.", 0
        Show-ConsoleMessage "❌ Erro ao baixar ou executar $($FileName): $_" $corAlerta
    }
}

# Função para baixar arquivos para a Área de Trabalho (usada por ambos os modos)
function Download-To-Desktop {
    param (
        [string]$Url,
        [string]$FileName,
        [System.Windows.Forms.Label]$StatusLabel = $null,
        [System.Windows.Forms.ProgressBar]$ProgressBar = $null
    )
    $updateUI = { param($text, $progress) if ($StatusLabel) { $StatusLabel.Text = $text; $StatusLabel.Refresh() }; if ($ProgressBar) { $ProgressBar.Value = $progress } }
    
    try {
        $desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
        $filePath = Join-Path -Path $desktopPath -ChildPath $FileName
        
        & $updateUI "Baixando $FileName para a Área de Trabalho...", 50
        Show-ConsoleMessage "📥 Baixando $FileName para a Área de Trabalho..." $corDestaque

        Invoke-WebRequest -Uri $Url -OutFile $filePath -ErrorAction Stop
        & $updateUI "Download de $FileName concluído!", 100
        Show-ConsoleMessage "✅ Download de $FileName concluído!" $corSucesso
        Show-ConsoleMessage "📂 Salvo em: $filePath" $corDestaque
    }
    catch {
        & $updateUI "Erro ao baixar $FileName.", 0
        Show-ConsoleMessage "❌ Erro ao baixar $($FileName): $_" $corAlerta
    }
}
#endregion

#region Interface Gráfica (Windows Forms)

function Show-InstallerGUI {
    # Oculta a janela do console do PowerShell
    $kernel32 = Add-Type -memberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();' -name 'kernel32' -namespace 'Win32' -passThru
    $user32 = Add-Type -memberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);' -name 'user32' -namespace 'Win32' -passThru
    $consoleHandle = $kernel32::GetConsoleWindow()
    if ($null -ne $consoleHandle) { $user32::ShowWindow($consoleHandle, 0) | Out-Null }

    # Carrega os assemblies necessários para a GUI
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Criação do formulário principal
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Script Marcos v4.1"
    $form.Size = New-Object System.Drawing.Size(400, 550)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")

    # Fonte padrão
    $font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Font = $font

    # GroupBox para os programas
    $groupPrograms = New-Object System.Windows.Forms.GroupBox
    $groupPrograms.Location = New-Object System.Drawing.Point(10, 10)
    $groupPrograms.Size = New-Object System.Drawing.Size(365, 250)
    $groupPrograms.Text = "Selecionar Programas para Instalar/Baixar"
    $form.Controls.Add($groupPrograms)

    # CheckBoxes para os programas
    $chkSelectAll = New-Object System.Windows.Forms.CheckBox; $chkSelectAll.Text = "Selecionar/Desmarcar Todos"; $chkSelectAll.Location = New-Object System.Drawing.Point(20, 30); $chkSelectAll.AutoSize = $true
    $chkOffice = New-Object System.Windows.Forms.CheckBox; $chkOffice.Text = "Instalar Microsoft Office"; $chkOffice.Location = New-Object System.Drawing.Point(20, 60); $chkOffice.AutoSize = $true
    $chkNinite = New-Object System.Windows.Forms.CheckBox; $chkNinite.Text = "Instalar (Ninite): AnyDesk, Chrome, Firefox, WinRAR"; $chkNinite.Location = New-Object System.Drawing.Point(20, 90); $chkNinite.AutoSize = $true
    $chkRustDesk = New-Object System.Windows.Forms.CheckBox; $chkRustDesk.Text = "Baixar RustDesk para a Área de Trabalho"; $chkRustDesk.Location = New-Object System.Drawing.Point(20, 120); $chkRustDesk.AutoSize = $true
    $chkDriverBooster = New-Object System.Windows.Forms.CheckBox; $chkDriverBooster.Text = "Baixar Driver Booster para a Área de Trabalho"; $chkDriverBooster.Location = New-Object System.Drawing.Point(20, 150); $chkDriverBooster.AutoSize = $true
    $chkUtilitario = New-Object System.Windows.Forms.CheckBox; $chkUtilitario.Text = "Executar Windows Utilitário (Winhance)"; $chkUtilitario.Location = New-Object System.Drawing.Point(20, 180); $chkUtilitario.AutoSize = $true
    $chkAtivacao = New-Object System.Windows.Forms.CheckBox; $chkAtivacao.Text = "Executar Programa de Ativação"; $chkAtivacao.Location = New-Object System.Drawing.Point(20, 210); $chkAtivacao.AutoSize = $true
    $groupPrograms.Controls.AddRange(@($chkSelectAll, $chkOffice, $chkNinite, $chkRustDesk, $chkDriverBooster, $chkUtilitario, $chkAtivacao))

    # GroupBox para as configurações de REDE
    $groupNetwork = New-Object System.Windows.Forms.GroupBox
    $groupNetwork.Location = New-Object System.Drawing.Point(10, 270)
    $groupNetwork.Size = New-Object System.Drawing.Size(365, 60)
    $groupNetwork.Text = "Configurações de Rede"
    $form.Controls.Add($groupNetwork)
    
    $chkRede = New-Object System.Windows.Forms.CheckBox; $chkRede.Text = "Ajustar SMB para compatibilidade (redes confiáveis)"; $chkRede.Location = New-Object System.Drawing.Point(20, 25); $chkRede.AutoSize = $true
    $groupNetwork.Controls.Add($chkRede)
    
    # GroupBox para ações pós-instalação
    $groupPost = New-Object System.Windows.Forms.GroupBox
    $groupPost.Location = New-Object System.Drawing.Point(10, 340)
    $groupPost.Size = New-Object System.Drawing.Size(365, 60)
    $groupPost.Text = "Ações Finais"
    $form.Controls.Add($groupPost)
    
    $chkMoveScript = New-Object System.Windows.Forms.CheckBox; $chkMoveScript.Text = "Salvar este script em C:\NG Master"; $chkMoveScript.Location = New-Object System.Drawing.Point(20, 25); $chkMoveScript.AutoSize = $true
    $groupPost.Controls.Add($chkMoveScript)

    # Ação do CheckBox "Selecionar Todos"
    $chkSelectAll.Add_Click({
        $isChecked = $chkSelectAll.Checked
        $chkOffice.Checked = $isChecked
        $chkNinite.Checked = $isChecked
        $chkRustDesk.Checked = $isChecked
        $chkDriverBooster.Checked = $isChecked
        $chkUtilitario.Checked = $isChecked
        $chkAtivacao.Checked = $isChecked
        $chkRede.Checked = $isChecked
        $chkMoveScript.Checked = $isChecked
    })

    # Barra de Progresso
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 410)
    $progressBar.Size = New-Object System.Drawing.Size(365, 23)
    $form.Controls.Add($progressBar)

    # Label de Status
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(10, 440)
    $statusLabel.Size = New-Object System.Drawing.Size(365, 20)
    $statusLabel.Text = "Aguardando início..."
    $form.Controls.Add($statusLabel)

    # Botão Iniciar
    $startButton = New-Object System.Windows.Forms.Button
    $startButton.Location = New-Object System.Drawing.Point(10, 470)
    $startButton.Size = New-Object System.Drawing.Size(365, 30)
    $startButton.Text = "Iniciar Instalação"
    $startButton.BackColor = [System.Drawing.Color]::PaleGreen
    
    # Ação do botão
    $startButton.Add_Click({
        $startButton.Enabled = $false
        $startButton.Text = "Processando..."
        
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
function Start-ConsoleMode {
    Clear-Host
    Show-ConsoleMessage "====================================" $corDestaque
    Show-ConsoleMessage "     🚀 SCRIPT MARCOS v4.1 (Modo Console)     " $corTitulo
    Show-ConsoleMessage "====================================" $corDestaque
    
    function Get-Choice {
        param ([string]$Prompt)
        Write-Host -Object $Prompt -ForegroundColor $corDestaque -NoNewLine
        while ($true) { $key = [System.Console]::ReadKey($true); if ('1', '2' -contains $key.KeyChar) { Write-Host $key.KeyChar; return $key.KeyChar } }
    }

    if ((Get-Choice "Deseja instalar o Office? (1-Sim/2-Não): ") -eq '1') { Download-Execute-And-Clean "https://marcosantoniorapado.github.io/downloads/OfficeSetup.exe" "OfficeSetup.exe" "OfficeSetup" }
    if ((Get-Choice "Instalar (Ninite)? (1-Sim/2-Não): ") -eq '1') { Download-Execute-And-Clean "https://marcosantoniorapado.github.io/downloads/Ninite%20AnyDesk%20Chrome%20Firefox%20WinRAR%20Installer.exe" "NiniteInstaller.exe" "NiniteInstaller" }
    if ((Get-Choice "Baixar RustDesk? (1-Sim/2-Não): ") -eq '1') { Download-To-Desktop "https://marcosantoniorapado.com.br/downloads/rustdesk-1.4.2-x86_64.exe" "rustdesk-1.4.2-x86_64.exe" }
    if ((Get-Choice "Baixar Driver Booster? (1-Sim/2-Não): ") -eq '1') { Download-To-Desktop "https://marcosantoniorapado.com.br/downloads/driver_booster_setup.exe" "driver_booster_setup.exe" }
    if ((Get-Choice "Executar Windows Utilitário? (1-Sim/2-Não): ") -eq '1') { $scriptUrl = "https://github.com/memstechtips/Winhance/raw/main/Winhance.ps1"; $scriptPath = Join-Path $env:TEMP "Winhance.ps1"; Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath; Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait; Remove-Item $scriptPath -Force }
    if ((Get-Choice "Ajustar SMB para compatibilidade? (1-Sim/2-Não): ") -eq '1') { Set-SmbClientConfiguration -RequireSecuritySignature $false -Force | Out-Null; Set-SmbClientConfiguration -EnableInsecureGuestLogons $true -Force | Out-Null }
    if ((Get-Choice "Executar Programa de Ativação? (1-Sim/2-Não): ") -eq '1') { $scriptContent = Invoke-RestMethod -Uri "https://get.activated.win"; Invoke-Expression $scriptContent }
    if ((Get-Choice "Salvar script em C:\NG Master? (1-Sim/2-Não): ") -eq '1') { $destFolder = "C:\NG Master"; if (-not (Test-Path $destFolder)) { New-Item -Path $destFolder -ItemType Directory | Out-Null }; Copy-Item -Path $PSCommandPath -Destination $destFolder -Force }
    
    Show-ConsoleMessage "🔚 Script (Modo Console) concluído!" $corSucesso
    Start-Sleep -Seconds 3
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
$choice = [System.Windows.Forms.MessageBox]::Show("Deseja usar a nova Interface Gráfica (GUI) para a instalação?", "Modo de Execução", "YesNo", "Question")

if ($choice -eq "Yes") {
    Show-InstallerGUI
} else {
    Start-ConsoleMode
}

Clear-History
exit

