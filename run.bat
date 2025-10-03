@echo off
setlocal EnableDelayedExpansion

set "PIP_PKGS=PyQt5 yt-dlp"
set "PY_CMD="

py -3 --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "PY_CMD=py -3"
) else (
    python --version >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        set "PY_CMD=python"
    )
)

if "%PY_CMD%"=="" (
    echo ERROR: Nem talaltam Pythont. Kerem telepitse: https://www.python.org/downloads/
    exit /b 1
)

set "MISSING_PIP="
if exist ".venv" (
    if exist ".venv\Scripts\python.exe" (
        for %%p in (%PIP_PKGS%) do (
            .\.venv\Scripts\python.exe -m pip show %%p >nul 2>&1
            if errorlevel 1 (
                if "!MISSING_PIP!"=="" (set "MISSING_PIP=%%p") else (set "MISSING_PIP=!MISSING_PIP! %%p")
            )
        )
    ) else (
        set "MISSING_PIP=%PIP_PKGS%"
    )
) else (
    set "MISSING_PIP=%PIP_PKGS%"
)

if defined MISSING_PIP (
    echo Hianyzo pip csomagok: %MISSING_PIP%
    if not exist ".venv" (
        echo Leterehozom a .venv-et...
        %PY_CMD% -m venv .venv
        if errorlevel 1 (
            echo Sikertelen .venv letrehozas.
            exit /b 1
        )
    )

    set "VENV_PY=.venv\Scripts\python.exe"
    if not exist "%VENV_PY%" (
        echo A .venv Python vegrehajthato nem talalhato.
        exit /b 1
    )

    echo Frissitem a pip-et es telepitem a csomagokat...
    "%VENV_PY%" -m pip install --upgrade pip
    for %%p in (%MISSING_PIP%) do (
        "%VENV_PY%" -m pip install %%p
        if errorlevel 1 (
            echo Sikertelen telepites: %%p
            exit /b 1
        )
    )
)

if exist main.py (
    if exist ".venv\Scripts\python.exe" (
        .\.venv\Scripts\python.exe main.py
    ) else (
        %PY_CMD% main.py
    )
) else (
    echo Nincs main.py fajl a jelenlegi konyvtarban.
)

endlocal
