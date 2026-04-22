@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

REM ============================================================
REM  SETUP NODE.JS PORTABLE + NPM GLOBAL + FIREBASE CLI
REM  Sin UAC - Instalacion por usuario
REM  v2.1 - Robusto con reintentos, logs y rollback
REM ============================================================

REM ---------- Configuracion centralizada ----------
set "NODE_VERSION=20.12.2"
set "NODE_ARCH=win-x64"
set "NODE_DIR=%USERPROFILE%\nodejs"
set "NODE_HOME=%NODE_DIR%\node-v%NODE_VERSION%-%NODE_ARCH%"
set "NODE_URL=https://nodejs.org/dist/v%NODE_VERSION%/node-v%NODE_VERSION%-%NODE_ARCH%.zip"
set "NPM_GLOBAL=%USERPROFILE%\npm-global"
set "NODE_ZIP=%NODE_DIR%\node.zip"
set "LOG_FILE=%TEMP%\setup_node_firebase.log"
set "MAX_RETRIES=3"

call :header
call :log "Inicio de instalacion. Log: %LOG_FILE%"
call :log "Node target: v%NODE_VERSION% | Arch: %NODE_ARCH%"
echo.

call :check_prereqs
if %errorlevel% neq 0 goto :fatal

call :step1_node
if %errorlevel% neq 0 goto :fatal

call :step2_path_node
if %errorlevel% neq 0 goto :fatal

call :step3_npm_global
if %errorlevel% neq 0 goto :fatal

call :step4_firebase
if %errorlevel% neq 0 goto :fatal

call :summary_ok
goto :eof


REM ================================================================
REM FUNCIONES
REM ================================================================

:header
cls
echo.
echo  =====================================================
echo   SETUP  NODE.JS + NPM + FIREBASE CLI  (sin UAC)
echo   Instalacion portable por usuario
echo  =====================================================
echo.
goto :eof

:log
echo [%time%] %~1 >> "%LOG_FILE%"
goto :eof

:print_step
echo  [%~1/4]  %~2
call :log "[PASO %~1/4] %~2"
goto :eof

:ok
echo         OK  %~1
call :log "[OK] %~1"
goto :eof

:warn
echo         AVISO: %~1
call :log "[AVISO] %~1"
goto :eof

:fail
echo.
echo  *** ERROR: %~1
echo  *** Log: %LOG_FILE%
echo.
call :log "[ERROR] %~1"
goto :eof


REM ================================================================
:check_prereqs
call :print_step "0" "Verificando prerequisitos..."

where curl.exe >nul 2>&1
if %errorlevel% neq 0 (
    call :fail "curl.exe no encontrado. Requiere Windows 10 1803+"
    exit /b 1
)
call :ok "curl disponible"

powershell -NoProfile -Command "exit 0" >nul 2>&1
if %errorlevel% neq 0 (
    call :fail "PowerShell no disponible"
    exit /b 1
)
call :ok "PowerShell disponible"

powershell -NoProfile -Command "try { (New-Object Net.WebClient).DownloadString('https://nodejs.org') | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if %errorlevel% neq 0 (
    call :fail "Sin conexion a nodejs.org. Verifica tu internet o proxy"
    exit /b 1
)
call :ok "Conexion a internet OK"
echo.
exit /b 0


REM ================================================================
:step1_node
call :print_step "1" "Instalando Node.js v%NODE_VERSION%..."

if exist "%NODE_HOME%\node.exe" (
    "%NODE_HOME%\node.exe" -v >nul 2>&1
    if !errorlevel! equ 0 (
        call :ok "Node.js ya instalado, omitiendo descarga"
        exit /b 0
    )
    call :warn "node.exe existe pero no responde, reinstalando..."
    rmdir /s /q "%NODE_HOME%" >nul 2>&1
)

if not exist "%NODE_DIR%" (
    mkdir "%NODE_DIR%" 2>nul
    if %errorlevel% neq 0 (
        call :fail "No se pudo crear %NODE_DIR%"
        exit /b 1
    )
)

set "DOWNLOAD_OK=0"
for /l %%i in (1,1,%MAX_RETRIES%) do (
    if !DOWNLOAD_OK! equ 0 (
        echo         Descargando, intento %%i de %MAX_RETRIES%...
        curl.exe -L --retry 3 --retry-delay 3 --connect-timeout 30 --progress-bar "%NODE_URL%" -o "%NODE_ZIP%" 2>>"%LOG_FILE%"
        if !errorlevel! equ 0 (
            set "DOWNLOAD_OK=1"
        ) else (
            call :warn "Descarga fallida en intento %%i"
            if exist "%NODE_ZIP%" del /f /q "%NODE_ZIP%"
            timeout /t 3 /nobreak >nul
        )
    )
)

if %DOWNLOAD_OK% equ 0 (
    call :fail "No se pudo descargar Node.js tras %MAX_RETRIES% intentos"
    exit /b 1
)
call :ok "Descarga completada"

powershell -NoProfile -Command "try { Add-Type -Assembly 'System.IO.Compression.FileSystem'; $z = [IO.Compression.ZipFile]::OpenRead('%NODE_ZIP%'); $c = $z.Entries.Count; $z.Dispose(); if ($c -lt 5) { exit 2 }; exit 0 } catch { exit 1 }" >nul 2>&1
if %errorlevel% neq 0 (
    del /f /q "%NODE_ZIP%" >nul 2>&1
    call :fail "ZIP descargado es invalido o esta corrupto"
    exit /b 1
)
call :ok "ZIP verificado"

echo         Extrayendo...
powershell -NoProfile -Command "Expand-Archive -Path '%NODE_ZIP%' -DestinationPath '%NODE_DIR%' -Force" 2>>"%LOG_FILE%"
if %errorlevel% neq 0 (
    call :fail "Error al extraer el ZIP"
    exit /b 1
)
del /f /q "%NODE_ZIP%" >nul 2>&1

if not exist "%NODE_HOME%\node.exe" (
    call :fail "node.exe no encontrado tras la extraccion en %NODE_HOME%"
    exit /b 1
)
call :ok "Node.js extraido correctamente"
echo.
exit /b 0


REM ================================================================
:step2_path_node
call :print_step "2" "Configurando PATH para Node.js..."

powershell -NoProfile -Command "$n = '%NODE_HOME%'; $cur = [Environment]::GetEnvironmentVariable('PATH','User'); $entries = $cur -split ';' | Where-Object { $_ -ne '' }; if ($entries -notcontains $n) { $new = ($entries + $n) -join ';'; [Environment]::SetEnvironmentVariable('PATH', $new, 'User') }" 2>>"%LOG_FILE%"

set "PATH=%NODE_HOME%;%PATH%"

"%NODE_HOME%\node.exe" -v >nul 2>&1
if %errorlevel% neq 0 (
    call :fail "node.exe no responde despues de configurar PATH"
    exit /b 1
)

set "NODE_VER_OUT="
for /f "usebackq" %%V in (`"%NODE_HOME%\node.exe" -v 2^>nul`) do set "NODE_VER_OUT=%%V"
call :ok "node %NODE_VER_OUT% activo"
echo.
exit /b 0


REM ================================================================
:step3_npm_global
call :print_step "3" "Configurando directorio npm global..."

if not exist "%NPM_GLOBAL%" (
    mkdir "%NPM_GLOBAL%" 2>nul
    if %errorlevel% neq 0 (
        call :fail "No se pudo crear %NPM_GLOBAL%"
        exit /b 1
    )
)

call "%NODE_HOME%\npm.cmd" config set prefix "%NPM_GLOBAL%" 2>>"%LOG_FILE%"
if %errorlevel% neq 0 (
    call :fail "npm config set prefix fallo"
    exit /b 1
)
call :ok "npm prefix configurado en %NPM_GLOBAL%"

powershell -NoProfile -Command "$ng = '%NPM_GLOBAL%'; $cur = [Environment]::GetEnvironmentVariable('PATH','User'); $entries = $cur -split ';' | Where-Object { $_ -ne '' }; if ($entries -notcontains $ng) { $new = ($entries + $ng) -join ';'; [Environment]::SetEnvironmentVariable('PATH', $new, 'User') }" 2>>"%LOG_FILE%"

set "PATH=%NPM_GLOBAL%;%PATH%"

set "NPM_VER_OUT="
for /f "usebackq" %%V in (`call "%NODE_HOME%\npm.cmd" -v 2^>nul`) do set "NPM_VER_OUT=%%V"
if "%NPM_VER_OUT%"=="" (
    call :fail "npm no responde"
    exit /b 1
)
call :ok "npm v%NPM_VER_OUT% OK"
echo.
exit /b 0


REM ================================================================
:step4_firebase
call :print_step "4" "Instalando Firebase CLI..."

if exist "%NPM_GLOBAL%\firebase.cmd" (
    "%NPM_GLOBAL%\firebase.cmd" --version >nul 2>&1
    if !errorlevel! equ 0 (
        call :ok "Firebase CLI ya instalado"
        echo.
        exit /b 0
    )
    call :warn "firebase.cmd existe pero falla, reinstalando..."
)

set "FIREBASE_OK=0"
for /l %%i in (1,1,%MAX_RETRIES%) do (
    if !FIREBASE_OK! equ 0 (
        echo         Instalando, intento %%i de %MAX_RETRIES%...
        call "%NODE_HOME%\npm.cmd" install -g firebase-tools 2>>"%LOG_FILE%"
        if !errorlevel! equ 0 (
            set "FIREBASE_OK=1"
        ) else (
            call :warn "npm install fallido en intento %%i"
            timeout /t 5 /nobreak >nul
        )
    )
)

if %FIREBASE_OK% equ 0 (
    call :fail "No se pudo instalar firebase-tools tras %MAX_RETRIES% intentos"
    exit /b 1
)

"%NPM_GLOBAL%\firebase.cmd" --version >nul 2>&1
if %errorlevel% neq 0 (
    call :fail "firebase CLI instalado pero no responde"
    exit /b 1
)

set "FB_VER_OUT="
for /f "usebackq" %%V in (`"%NPM_GLOBAL%\firebase.cmd" --version 2^>nul`) do set "FB_VER_OUT=%%V"
call :ok "Firebase CLI v%FB_VER_OUT% instalado"
echo.
exit /b 0


REM ================================================================
:summary_ok
echo.
echo  =====================================================
echo   INSTALACION COMPLETADA EXITOSAMENTE
echo  =====================================================

set "N=" & set "NP=" & set "FB="
for /f "usebackq" %%V in (`"%NODE_HOME%\node.exe" -v 2^>nul`) do set "N=%%V"
for /f "usebackq" %%V in (`call "%NODE_HOME%\npm.cmd" -v 2^>nul`) do set "NP=%%V"
for /f "usebackq" %%V in (`"%NPM_GLOBAL%\firebase.cmd" --version 2^>nul`) do set "FB=%%V"

echo   Node.js  : %N%
echo   npm      : v%NP%
echo   Firebase : v%FB%
echo.
echo   Directorios:
echo     Node   : %NODE_HOME%
echo     Global : %NPM_GLOBAL%
echo.
echo   PROXIMOS PASOS:
echo     1. Abre una nueva terminal (cmd o PowerShell)
echo     2. Ejecuta:  firebase login
echo     3. Ejecuta:  firebase init
echo.
echo   Log: %LOG_FILE%
echo  =====================================================
echo.
call :log "Instalacion completada sin errores"
pause
exit /b 0


REM ================================================================
:fatal
echo.
echo  *** INSTALACION ABORTADA - Revisa el log para detalles
echo  *** Log: %LOG_FILE%
echo.
call :log "Instalacion abortada"
pause
exit /b 1
