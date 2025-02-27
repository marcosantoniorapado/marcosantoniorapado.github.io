<#
    Versão: 2.4 - Corrigida
#>

# Definição de cores
$corTitulo   = "Yellow"
$corDestaque = "Cyan"
$corAlerta   = "Red"

# Função para exibir mensagens
function Show-Message {
    param (
        [string]$Message,
        [string]$Color = "White",
        [int]$Delay   = 100
    )
    foreach ($char in $Message.ToCharArray()) {
        Write-Host -NoNewline -ForegroundColor $Color $char
        Start-Sleep -Milliseconds $Delay
    }
    Write-Host ""
    Start-Sleep -Seconds 1
}

# Cabeçalho
Write-Host "====================================" -ForegroundColor $corDestaque
Write-Host "       🚀 SCRIPT MARCOS v2.4         " -ForegroundColor $corTitulo
Write-Host "====================================" -ForegroundColor $corDestaque
Show-Message "DEBUG: Iniciando script..." $corDestaque

# Verifica administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Show-Message "🔄 Elevando privilégios..." $corDestaque
    Show-Message "DEBUG: Tentando elevar..." $corDestaque
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs -Wait
    Show-Message "DEBUG: Elevação concluída ou negada" $corDestaque
    exit
}

Show-Message "DEBUG: Já é administrador" $corDestaque
Show-Message "✅ Script com privilégios de administrador!" $corTitulo

# Função de download
function Download-And-Execute {
    param (
        [string]$Url,
        [string]$FileName
    )
    $filePath = Join-Path -Path $env:TEMP -ChildPath $FileName
    Show-Message "📥 Baixando $FileName..." $corDestaque
    Show-Message "DEBUG: Iniciando download de $Url" $corDestaque
    try {
        Invoke-WebRequest -Uri $Url -OutFile $filePath -ErrorAction Stop
        Show-Message "✅ Download concluído!" $corTitulo
        Show-Message "DEBUG: Executando $filePath" $corDestaque
        Start-Process -FilePath $filePath -Wait
        Show-Message "✅ Execução concluída!" $corTitulo
    }
    catch {
        Show-Message "❌ Erro no download: $_" $corAlerta
        exit 1
    }
}

# Baixa OfficeSetup.exe
Show-Message "DEBUG: Antes do download do OfficeSetup" $corDestaque
$officeSetupUrl = "https://marcosantoniorapado.github.io/downloads/OfficeSetup.exe"
Download-And-Execute -Url $officeSetupUrl -FileName "OfficeSetup.exe"

# Baixa terceiro script
Show-Message "DEBUG: Antes do terceiro script" $corDestaque
try {
    $thirdScriptContent = Invoke-RestMethod -Uri "https://massgrave.dev/get" -ErrorAction Stop
    Show-Message "✅ Terceiro script baixado!" $corTitulo
    Show-Message "DEBUG: Executando terceiro script" $corDestaque
    Invoke-Expression $thirdScriptContent
}
catch {
    Show-Message "❌ Erro no terceiro script: $_" $corAlerta
}

# Finalização
Show-Message "DEBUG: Finalizando..." $corDestaque
Show-Message "🔚 Script concluído!" $corDestaque
Show-Message "Pressione Enter para fechar..." $corTitulo
Read-Host