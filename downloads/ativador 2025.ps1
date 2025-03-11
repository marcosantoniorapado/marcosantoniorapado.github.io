<#
    Versão: 3.0 - Criado por Marcos
    Data: 11/03/2025

    Como Usar:
    Execute-o no PowerShell com permissões de administrador.
    Responda às perguntas com "1" para "Sim" ou "2" para "Não".
    O script executará as tarefas automaticamente.
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
Show-Message "       🚀 SCRIPT MARCOS v3.0         " $corTitulo
Show-Message "       Criado por Marcos             " $corTitulo
Show-Message "====================================" $corDestaque

# Verifica se é administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Show-Message "🔄 Elevando privilégios..." $corDestaque
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs -Wait
    exit
}

Show-Message "✅ Script com privilégios de administrador!" $corTitulo

# Função para baixar, executar, fechar o processo e limpar
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
        Show-Message "❌ Erro ao baixar ou executar: $_" $corAlerta
        exit 1
    }
}

# Pergunta sobre o Office
Show-Message ""
Show-Message "Deseja instalar o Office? (1 - Sim / 2 - Não)" $corDestaque
$respostaOffice = Read-Host
if ($respostaOffice -eq "1") {
    $officeUrl = "https://marcosantoniorapado.github.io/downloads/OfficeSetup.exe"
    Download-Execute-And-Clean -Url $officeUrl -FileName "OfficeSetup.exe" -ProcessName "OfficeSetup"
} else {
    Show-Message "⏭️ Pulando instalação do Office." $corDestaque
}

# Pergunta sobre o Ninite
Show-Message ""
Show-Message "Deseja instalar AnyDesk, Chrome, Firefox e WinRAR via Ninite? (1 - Sim / 2 - Não)" $corDestaque
$respostaNinite = Read-Host
if ($respostaNinite -eq "1") {
    $niniteUrl = "https://marcosantoniorapado.github.io/downloads/Ninite%20AnyDesk%20Chrome%20Firefox%20WinRAR%20Installer.exe"
    Download-Execute-And-Clean -Url $niniteUrl -FileName "NiniteInstaller.exe" -ProcessName "NiniteInstaller"
} else {
    Show-Message "⏭️ Pulando instalação via Ninite." $corDestaque
}

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
Start-Sleep -Seconds 3
Clear-History
exit
