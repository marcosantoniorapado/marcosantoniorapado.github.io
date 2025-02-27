# - Versão: 1.4
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
Write-Host "       🚀 SCRIPT MARCOS v1.4      " -ForegroundColor $corTitulo
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
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

# Ajuste temporário da política de execução para evitar erros no Windows 11
$policy = Get-ExecutionPolicy
if ($policy -ne 'Bypass') {
    Show-Message "⚠️ Política de execução atual: $policy. Ajustando para permitir scripts..." $corAlerta
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}

# Mensagem de sucesso ao rodar como administrador
Show-Message "✅ Script executado como administrador!" $corTitulo
Start-Sleep -Seconds 2

# Executa o download do script sem repetir
$scriptUrl = "https://massgrave.dev/get"
$scriptContent = Invoke-RestMethod -Uri $scriptUrl

if ($scriptContent) {
    Show-Message "📥 Download do script realizado com sucesso!" $corDestaque
    Invoke-Expression -Command $scriptContent
} else {
    Show-Message "❌ Erro ao baixar o script. Verifique a conexão." $corAlerta
}

# Restaura a política de execução original
Set-ExecutionPolicy -Scope Process -ExecutionPolicy $policy -Force

# Finaliza o script automaticamente após a execução
Show-Message "🔚 Finalizando o script..." $corDestaque
Start-Sleep -Seconds 1
exit
