@echo off
setlocal EnableExtensions

title NG Master - Criar usuario oculto Print
color 0E

set "USUARIO=Print"
set "SENHA=1234"

:: Solicita privilegios de administrador
fltmc >nul 2>&1
if errorlevel 1 (
    echo.
    echo Solicitando permissao de administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cls
echo ============================================================
echo   NG MASTER - USUARIO PARA IMPRESSORA COMPARTILHADA
echo ============================================================
echo.
echo Usuario: %USUARIO%
echo Senha:   %SENHA%
echo.

:: Verifica se o usuario ja existe
net user "%USUARIO%" >nul 2>&1

if errorlevel 1 (
    echo Criando o usuario local "%USUARIO%"...
    net user "%USUARIO%" "%SENHA%" /add /active:yes /expires:never >nul 2>&1
) else (
    echo O usuario "%USUARIO%" ja existe. Atualizando a configuracao...
    net user "%USUARIO%" "%SENHA%" /active:yes /expires:never >nul 2>&1
)

if errorlevel 1 goto :ERRO_USUARIO

:: Mantem a senha sem expiracao, quando o recurso estiver disponivel
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "Try { Set-LocalUser -Name '%USUARIO%' -PasswordNeverExpires $true -ErrorAction Stop } Catch { }" >nul 2>&1

:: Oculta o usuario da tela de entrada do Windows
echo Ocultando o usuario da tela de entrada...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" ^
    /v "%USUARIO%" /t REG_DWORD /d 0 /f >nul 2>&1

if errorlevel 1 goto :ERRO_REGISTRO

echo.
echo ============================================================
echo   CONCLUIDO COM SUCESSO
echo ============================================================
echo.
echo O usuario local "%USUARIO%" foi criado ou atualizado.
echo Ele permanece ativo para acesso pela rede, mas fica oculto
echo da tela de entrada do Windows.
echo.
pause
exit /b 0

:ERRO_USUARIO
echo.
echo ERRO: Nao foi possivel criar ou atualizar o usuario "%USUARIO%".
echo A politica de senhas do Windows pode ter recusado a senha 1234.
echo.
pause
exit /b 1

:ERRO_REGISTRO
echo.
echo ERRO: O usuario foi configurado, mas nao foi possivel oculta-lo.
echo.
pause
exit /b 2
