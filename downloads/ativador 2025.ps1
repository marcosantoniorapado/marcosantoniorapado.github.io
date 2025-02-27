# - Versão: 1.2
# - Autor: Marcos
# - 2023

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    
    $prompt = " `
`
` 
Mudando para administrador. `  
`
E continuaremos em:"

    
    foreach ($char in $prompt.ToCharArray()) {
        Write-Host -NoNewline $char
        Start-Sleep -Milliseconds 35
    }
    
    Write-Host "     "
    
    $countdown = 3, 2, 1
    
    foreach ($num in $countdown) {
        $prompt = " $num"
        
        foreach ($char in $prompt.ToCharArray()) {
            Write-Host -NoNewline $char
            Start-Sleep -Milliseconds 40
        }
        
        Start-Sleep -Seconds 1
    }
    
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

# Script continua aqui depois de ser reiniciado como administrador

Write-Host "Script executado como administrador!"
Start-Sleep -Seconds 2

# Executa o link fornecido automaticamente
Invoke-Expression -Command (Invoke-RestMethod -Uri "https://massgrave.dev/get")


# Execute o link solicitado
irm https://massgrave.dev/get | iex
