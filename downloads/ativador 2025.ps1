<#
    Versão: 3.6 - Criado por Marcos
    Data: 21/03/2025

    Como Usar:
    Execute-o no PowerShell com permissões de administrador.
    Responda às perguntas pressionando "1" para "Sim" ou "2" para "Não".
    O script executará as tarefas automaticamente após a tecla ser pressionada.
#>

# Definição de cores
$corTitulo   = "Yellow"
$corDestaque = "Cyan"
$corAlerta   = "Red"

# Função para exibir mensagens
function Show-Message {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host -ForegroundColor $Color $Message
}

# Limpar a tela no início
Clear-Host

# Cabeçalho
Show-Message "====================================" $corDestaque
Show-Message "       🚀 SCRIPT MARCOS v3.6         " $corTitulo
Show-Message "       Criado por Marcos             " $corTitulo
Show-Message "====================================" $corDestaque

# Verifica se é administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Show-Message "🔄 Elevando privilégios..." $corDestaque
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs -Wait
    exit
}

Show-Message "✅ Script com privilégios de administrador!" $corTitulo

# Função genérica para baixar, executar e limpar
function Download-Execute-And-Clean {
    param (
        [string]$Url,
        [string]$FileName,
        [string]$ProcessName
    )

    $filePath = Join-Path -Path $env:TEMP -ChildPath $FileName
    Show-Message "📥 Baixando $FileName..." $corDestaque

    try {
        Invoke-WebRequest -Uri $Url -OutFile $filePath -ErrorAction Stop
        Show-Message "✅ Download concluído!" $corTitulo
        Show-Message "🔧 Executando $FileName..." $corDestaque
        Start-Process -FilePath $filePath -Wait

        # Fechar o processo se ainda estiver ativo
        if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
            Stop-Process -Name $ProcessName -Force
            Show-Message "🛑 Processo $ProcessName fechado." $corDestaque
        }

        Remove-Item -Path $filePath -Force
        Show-Message "🗑️ Arquivo removido." $corDestaque
    }
    catch {
        Show-Message "❌ Erro ao baixar ou executar $($FileName): $_" $corAlerta
    }
}

# Função para obter a escolha do usuário (1 ou 2) sem precisar de Enter
function Get-Choice {
    param (
        [string]$Prompt
    )
    Show-Message $Prompt $corDestaque
    while ($true) {
        $key = [System.Console]::ReadKey($true)
        if ($key.KeyChar -eq '1') {
            return '1'
        } elseif ($key.KeyChar -eq '2') {
            return '2'
        } else {
            Show-Message "❌ Opção inválida. Pressione 1 ou 2." $corAlerta
        }
    }
}

# Pergunta sobre o Office
Show-Message ""
$respostaOffice = Get-Choice "Deseja instalar o Office? (1 - Sim / 2 - Não)"
if ($respostaOffice -eq '1') {
    Download-Execute-And-Clean -Url "https://marcosantoniorapado.github.io/downloads/OfficeSetup.exe" -FileName "OfficeSetup.exe" -ProcessName "OfficeSetup"
} else {
    Show-Message "⏭️ Pulando instalação do Office." $corDestaque
}
Clear-Host

# Pergunta sobre o Ninite
Show-Message ""
$respostaNinite = Get-Choice "Deseja instalar AnyDesk, Chrome, Firefox e WinRAR via Ninite? (1 - Sim / 2 - Não)"
if ($respostaNinite -eq '1') {
    Download-Execute-And-Clean -Url "https://marcosantoniorapado.github.io/downloads/Ninite%20AnyDesk%20Chrome%20Firefox%20WinRAR%20Installer.exe" -FileName "NiniteInstaller.exe" -ProcessName "NiniteInstaller"
} else {
    Show-Message "⏭️ Pulando instalação via Ninite." $corDestaque
}
Clear-Host

# Pergunta sobre o Windows Utilitário
Show-Message ""
$respostaUtilitario = Get-Choice "Deseja baixar o Windows Utilitário? (1 - Sim / 2 - Não)"
if ($respostaUtilitario -eq '1') {
    Show-Message "📥 Baixando e executando Windows Utilitário..." $corDestaque
    $scriptUrl = "https://github.com/memstechtips/Winhance/raw/main/Winhance.ps1"
    $scriptPath = Join-Path -Path $env:TEMP -ChildPath "Winhance.ps1"
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -ErrorAction Stop
        Show-Message "✅ Download concluído!" $corTitulo
        Show-Message "🔧 Executando Windows Utilitário em um novo processo..." $corDestaque
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait
        Show-Message "✅ Windows Utilitário executado com sucesso!" $corTitulo
    } catch {
        Show-Message "❌ Erro ao baixar ou executar o Windows Utilitário: $_" $corAlerta
    } finally {
        if (Test-Path $scriptPath) {
            Remove-Item -Path $scriptPath -Force
            Show-Message "🗑️ Arquivo temporário removido." $corDestaque
        }
    }
} else {
    Show-Message "⏭️ Pulando Windows Utilitário." $corDestaque
}
Clear-Host

# Baixa e executa o segundo script
Show-Message ""
Show-Message "📥 Baixando segundo script..." $corDestaque
try {
    $secondScriptContent = Invoke-RestMethod -Uri "https://massgrave.dev/get" -ErrorAction Stop
    Show-Message "✅ Segundo script baixado!" $corTitulo
    Show-Message "🔧 Executando segundo script..." $corDestaque
    Invoke-Expression $secondScriptContent
    Show-Message "✅ Segundo script concluído!" $corTitulo
}
catch {
    Show-Message "❌ Erro no segundo script: $_" $corAlerta
}

# Finalização
Show-Message "🔚 Script concluído!" $corDestaque
Start-Sleep -Seconds 1
Clear-History
exit