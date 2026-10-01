@echo off
@REM  # ------------------------------------- #
@REM  # --- Python .venv installer router --- #
@REM  # ------------------------------------- #
@REM
@REM  Caller sets SCRIPT_DIR first (no setlocal around the call, env changes must persist):
@REM    set "SCRIPT_DIR=%~dp0"
@REM    call submodules\mio-shell\windows\python\install_python_venv.bat <function> [args...]
@REM
@REM  Failing functions return errorlevel 1. Caller must propagate:
@REM    call ...install_python_venv.bat run_required 4 "label" python -m pip install x || exit /b 1

if "%~1"=="" (
    >&2 echo.
    >&2 echo install_python_venv.bat has to be called with 1st argument being function name.
    >&2 echo.
    exit /b 1
)

if not defined SCRIPT_DIR (
    >&2 echo.
    >&2 echo SCRIPT_DIR is NOT defined
    >&2 echo.
    exit /b 1
)

if not exist "%SCRIPT_DIR%" (
    >&2 echo.
    >&2 echo SCRIPT_DIR does not exist : "%SCRIPT_DIR%"
    >&2 echo.
    exit /b 1
)

if not "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR%\"

set "CALLING_SCRIPT_DIR=%SCRIPT_DIR%"
set "VENV_DIR=%CALLING_SCRIPT_DIR%.venv\"
set "INSTALL_LOGS_DIR=%CALLING_SCRIPT_DIR%.install_logs\"
set "ACTIVATE_SCRIPT=%VENV_DIR%Scripts\activate.bat"

where python >nul 2>&1
if errorlevel 1 (
    >&2 echo.
    >&2 echo python executable NOT Found! Cannot continue.
    >&2 echo.
    exit /b 1
)

@REM This routes the call to function
call :%*
exit /b %ERRORLEVEL%

@REM # ---------------------------------- #
@REM # --- Functions are defined here --- #
@REM # ---------------------------------- #

@REM run_required <enum> <label> <command...>
:run_required
call :_run required %*
exit /b %ERRORLEVEL%

@REM run_optional <enum> <label> <command...>
:run_optional
call :_run optional %*
exit /b %ERRORLEVEL%

@REM _run <required|optional> <enum> <label> <command...>
:_run
setlocal EnableDelayedExpansion
set "mode=%~1"
set "enum=%~2"
set "label=%~3"
shift & shift & shift
set "cmd="
:_run_args
if "%~1"=="" goto :_run_exec
set "cmd=!cmd! %1"
shift
goto :_run_args
:_run_exec
set "cmd=!cmd:~1!"
set "safe=!label: =_!"
set "safe=!safe:-=_!"
set "safe=!safe:.=_!"
set "log=%INSTALL_LOGS_DIR%!enum!_!safe!.log"
if not exist "%INSTALL_LOGS_DIR%" mkdir "%INSTALL_LOGS_DIR%"
echo.
echo   !label!
call !cmd! > "!log!" 2>&1
if errorlevel 1 goto :_run_failed
echo     DONE
exit /b 0
:_run_failed
if /i "!mode!"=="required" goto :_run_failed_required
echo     FAILED (optional)
echo     command  : !cmd!
echo     log file : !log!
exit /b 0
:_run_failed_required
>&2 echo     FAILED
>&2 echo     command  : !cmd!
>&2 echo     log file : !log!
>&2 echo.
exit /b 1

@REM print_python_env <label> <python>
:print_python_env
setlocal
set "label=%~1"
set "py=%~2"
set "pyver="
set "pypath="
set "pipver="
for /f "delims=" %%i in ('%py% --version 2^>^&1') do set "pyver=%%i"
for /f "delims=" %%i in ('where %py% 2^>nul') do if not defined pypath set "pypath=%%i"
for /f "delims=" %%i in ('%py% -m pip --version 2^>^&1') do set "pipver=%%i"
if not defined pipver set "pipver=pip not found"
echo.
echo   %label%
echo     Python Version : %pyver%
echo     Python Path    : %pypath%
echo     Pip Version    : %pipver%
exit /b 0

@REM print_python_packages <python>
:print_python_packages
echo.
echo   Local Pip Packages
echo.
%~1 -m pip list --local
exit /b 0

:remove_venv
if not exist "%VENV_DIR%" goto :remove_venv_logs
echo.
echo   Removing virtual environment at "%VENV_DIR%"
rd /s /q "%VENV_DIR%"
if exist "%VENV_DIR%" goto :remove_venv_failed
echo     DONE
:remove_venv_logs
if not exist "%INSTALL_LOGS_DIR%" goto :remove_venv_mkdir
echo.
echo   Removing .install_logs : "%INSTALL_LOGS_DIR%"
rd /s /q "%INSTALL_LOGS_DIR%"
echo     DONE
:remove_venv_mkdir
mkdir "%INSTALL_LOGS_DIR%"
exit /b 0
:remove_venv_failed
>&2 echo     FAILED
>&2 echo     Could not remove "%VENV_DIR%" ^(in use?^)
>&2 echo     Possible solutions:
>&2 echo     Try disabling "isort: Server Enabled" in VSCode settings
>&2 echo     Try closing all .py files in VSCode
>&2 echo.
exit /b 1

:prepare_native_python
call :run_optional 1 "Upgrading native pip" python -m pip install --upgrade pip
call :run_required 2 "Installing native virtualenv" python -m pip install virtualenv
exit /b %ERRORLEVEL%

@REM make_venv <python spec> : e.g. 3.12 (virtualenv resolves it, py launcher included)
:make_venv
call :run_required 3 "Making virtual environment" python -m virtualenv "%VENV_DIR:~0,-1%" --clear --copies --python=%~1
exit /b %ERRORLEVEL%

:activate_venv
echo.
echo   Activating "%VENV_DIR%"
if not exist "%ACTIVATE_SCRIPT%" goto :activate_venv_missing
call "%ACTIVATE_SCRIPT%"
if not defined VIRTUAL_ENV goto :activate_venv_unset
echo     DONE
exit /b 0
:activate_venv_missing
>&2 echo     FAILED
>&2 echo     "%ACTIVATE_SCRIPT%" does NOT exist.
>&2 echo.
exit /b 1
:activate_venv_unset
>&2 echo     FAILED
>&2 echo     VIRTUAL_ENV is not set after activating.
>&2 echo.
exit /b 1

:deactivate_venv
if not defined VIRTUAL_ENV exit /b 0
echo.
echo   Deactivating .venv : "%VIRTUAL_ENV%"
if exist "%VIRTUAL_ENV%\Scripts\deactivate.bat" call "%VIRTUAL_ENV%\Scripts\deactivate.bat"
set "VIRTUAL_ENV="
echo     DONE
exit /b 0
