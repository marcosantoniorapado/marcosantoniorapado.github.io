# - Versão: 1.7
# - Autor: Marcos
# - 2023

# Definição de cores para o terminal
$corTitulo = "Yellow"
$corDestaque = "Cyan"
$corAlerta = "Red"

# Função para exibir mensagens com delay (efeito de digitação)
function Show-Message($message, $color="White", $delay=35) {
    foreach ($char in $message.ToCharArray()) {
        Write-Host -NoNewline -ForegroundColor $color $char
        Start-Sleep -Milliseconds $delay
    }
    Write-Host ""
}

# ASCII Art estilizado para o cabeçalho
Write-Host "
====================================" -ForegroundColor $corDestaque
Write-Host "       🚀 SCRIPT MARCOS v1.7      " -ForegroundColor $corTitulo
Write-Host "====================================" -ForegroundColor $corDestaque
Start-Sleep -Seconds 1

# Verifica se o script está rodando como administrador
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    
    Show-Message "🔄 Mudando para administrador..." $corDestaque
    Show-Message "⏳ Continuaremos em:" $corTitulo

    # Contagem regressiva estilizada
    $countdown = 3, 2, 1
    foreach ($num in $countdown) {
        Show-Message "➡️  $num" $corDestaque 40
        Start-Sleep -Seconds 1
    }
    
    # Reinicia o script como administrador
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Mensagem de sucesso ao rodar como administrador
Show-Message "✅ Script executado como administrador!" $corTitulo
Start-Sleep -Seconds 2

# Baixa o primeiro arquivo e executa
$officeUrl = "https://marcosantoniorapado.github.io//downloads/OfficeSetup.exe"
$officePath = "$env:TEMP\OfficeSetup.exe"
Show-Message "📥 Baixando OfficeSetup.exe..." $corDestaque

try {
    Invoke-WebRequest -Uri $officeUrl -OutFile $officePath -ErrorAction Stop
    Show-Message "✅ Download do Office concluído!" $corTitulo
    Start-Process -FilePath $officePath -Wait
    Show-Message "✅ Instalação concluída!" $corTitulo
} catch {
    Show-Message "❌ Erro ao baixar o Office. Verifique a conexão." $corAlerta
    Exit
}

# Após fechar o instalador, baixa o segundo script
$scriptUrl = "https://massgrave.dev/get"
Show-Message "📥 Baixando segundo script..." $corDestaque

try {
    $scriptContent = Invoke-RestMethod -Uri $scriptUrl -ErrorAction Stop
    Show-Message "✅ Download do segundo script realizado com sucesso!" $corTitulo
    Invoke-Expression -Command $scriptContent
} catch {
    Show-Message "❌ Erro ao baixar o segundo script. Verifique a conexão." $corAlerta
}

# Finaliza o script automaticamente após a execução
Show-Message "🔚 Finalizando o script..." $corDestaque
Start-Sleep -Seconds 1
exit
