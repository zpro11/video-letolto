[CmdletBinding()]
param()

function Letezik {
    param([string]$parancs)
    return (Get-Command $parancs -ErrorAction SilentlyContinue) -ne $null
}

$Grafikus = $false
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop | Out-Null
    $Grafikus = $true
} catch {
    $Grafikus = $false
}

function Informacio {
    param([string]$szoveg)
    if ($Grafikus) {
        [System.Windows.Forms.MessageBox]::Show($szoveg, 'Info', 'OK', 'Information') | Out-Null
    } else {
        Write-Host $szoveg
    }
}

function HibaUzenet {
    param([string]$szoveg)
    if ($Grafikus) {
        [System.Windows.Forms.MessageBox]::Show($szoveg, 'Hiba', 'OK', 'Error') | Out-Null
    } else {
        Write-Error $szoveg
    }
}

function Megerosit {
    param([string]$szoveg)
    if ($Grafikus) {
        $valasz = [System.Windows.Forms.MessageBox]::Show($szoveg, 'Megerősítés', 'YesNo', 'Question')
        return $valasz -eq 'Yes'
    } else {
        while ($true) {
            $r = Read-Host "$szoveg [y/N]"
            if ($r -match '^[Yy]') { return $true }
            if ($r -match '^[Nn]$' -or $r -eq '') { return $false }
        }
    }
}

Push-Location -LiteralPath (Split-Path -LiteralPath $MyInvocation.MyCommand.Definition -Parent)
try {
    $Szukseges = @('python')
    $PipCsomagok = @('PyQt5','yt-dlp')

    $PythonParancs = $null
    if (Letezik 'py') {
        try {
            & py -3 --version > $null 2>&1
            $PythonParancs = 'py -3'
        } catch { }
    }
    if (-not $PythonParancs -and Letezik 'python') {
        try { & python --version > $null 2>&1; $PythonParancs = 'python' } catch { }
    }

    $HianyzoRendszer = @()
    if (-not $PythonParancs) { $HianyzoRendszer += 'python' }

    $HianyzoPip = @()
    if ($PythonParancs) {
        $VanVenv = $false
        try {
            & $PythonParancs -c "import venv" > $null 2>&1
            $VanVenv = $true
        } catch { $VanVenv = $false }
        if (-not $VanVenv) { $HianyzoRendszer += 'python-venv(modul)'; }

        $VanPip = $false
        try { & $PythonParancs -m pip --version > $null 2>&1; $VanPip = $true } catch { $VanPip = $false }
        if (-not $VanPip) { $HianyzoRendszer += 'pip' }
    }

    $HianyzoCsomagok = @()
    if (Test-Path -LiteralPath '.venv') {
        $VenvPython = Join-Path -Path (Get-Location) -ChildPath '.venv\Scripts\python.exe'
        if (Test-Path $VenvPython) {
            foreach ($p in $PipCsomagok) {
                $Megtalalt = $false
                try {
                    & "$VenvPython" -m pip show $p > $null 2>&1; $Megtalalt = ($LASTEXITCODE -eq 0)
                } catch { $Megtalalt = $false }
                if (-not $Megtalalt) { $HianyzoCsomagok += $p }
            }
        } else {
            $HianyzoCsomagok = $PipCsomagok.Clone()
        }
    } else {
        $HianyzoCsomagok = $PipCsomagok.Clone()
    }

    if ($HianyzoRendszer.Count -eq 0 -and $HianyzoCsomagok.Count -eq 0) {
    } else {
        $PipTemp = $null
        $PipBajtok = 0
        if ($HianyzoCsomagok.Count -gt 0 -and $PythonParancs) {
            try {
                $PipTemp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString()))
                foreach ($p in $HianyzoCsomagok) {
                    try { & $PythonParancs -m pip download --no-deps --dest $PipTemp.FullName $p > $null 2>&1 } catch { }
                }
                $files = Get-ChildItem -Path $PipTemp.FullName -Recurse -File -ErrorAction SilentlyContinue
                if ($files) { $PipBajtok = ($files | Measure-Object -Property Length -Sum).Sum }
            } catch { }
        }

        $MeretSzoveg = if ($PipBajtok -gt 0) { "{0:N1} MB" -f ($PipBajtok/1MB) } else { 'Ismeretlen (nem sikerült megbecsülni)' }

        $Uzenet = "Hiányzó rendszerkomponensek:\n$($HianyzoRendszer -join '\n')\n\nHiányzó pip csomagok:\n$($HianyzoCsomagok -join ', ')\n\nBecsült foglalás (pip csomagok): $MeretSzoveg\n\nTelepítse a hiányzó csomagokat? (A pip csomagok egy .venv virtuális környezetbe lesznek telepítve.)"

        if (-not (Megerosit $Uzenet)) {
            Informacio 'Művelet megszakítva.'
            if ($PipTemp) { Remove-Item -Recurse -Force $PipTemp.FullName -ErrorAction SilentlyContinue }
            Exit 0
        }

        if ($HianyzoRendszer.Count -gt 0) {
            if ($HianyzoRendszer -contains 'python') {
                if (Letezik 'winget') {
                    Informacio 'Python hiányzik — megpróbálom telepíteni a winget segítségével (admin jogosultságok szükségesek lehetnek)...'
                    try {
                        & winget install --id Python.Python.3 -e --source msstore
                    } catch {
                        HibaUzenet 'A winget telepítése/használata sikertelen volt. Kérem telepítse a Pythont kézzel: https://www.python.org/downloads/'
                        if ($PipTemp) { Remove-Item -Recurse -Force $PipTemp.FullName -ErrorAction SilentlyContinue }
                        Exit 1
                    }
                    if (Letezik 'py') { $PythonParancs = 'py -3' } elseif (Letezik 'python') { $PythonParancs = 'python' }
                } elseif (Letezik 'choco') {
                    Informacio 'Python hiányzik — megpróbálom telepíteni a Chocolatey segítségével (admin jogosultságok szükségesek)...'
                    try { & choco install -y python } catch { HibaUzenet 'Chocolatey telepítés sikertelen. Kérem telepítse a Pythont kézzel.'; if ($PipTemp) { Remove-Item -Recurse -Force $PipTemp.FullName -ErrorAction SilentlyContinue }; Exit 1 }
                    if (Letezik 'python') { $PythonParancs = 'python' }
                } else {
                    HibaUzenet 'A rendszer nem tudja automatikusan telepíteni a Pythont (winget vagy choco nincs). Kérjük telepítse kézzel: https://www.python.org/downloads/'
                    if ($PipTemp) { Remove-Item -Recurse -Force $PipTemp.FullName -ErrorAction SilentlyContinue }
                    Exit 1
                }
            }
        }

        if ($HianyzoCsomagok.Count -gt 0) {
            if (-not $PythonParancs) {
                HibaUzenet 'Nem található Python a pip csomagok telepítéséhez.'
                if ($PipTemp) { Remove-Item -Recurse -Force $PipTemp.FullName -ErrorAction SilentlyContinue }
                Exit 1
            }

            if (-not (Test-Path -LiteralPath '.venv')) {
                try {
                    & $PythonParancs -m venv .venv
                } catch {
                    HibaUzenet 'Sikertelen .venv létrehozása.'
                    if ($PipTemp) { Remove-Item -Recurse -Force $PipTemp.FullName -ErrorAction SilentlyContinue }
                    Exit 1
                }
            }

            $VenvPython = Join-Path -Path (Get-Location) -ChildPath '.venv\Scripts\python.exe'
            if (-not (Test-Path $VenvPython)) {
                HibaUzenet 'A .venv Python végrehajtható nem található.'
                if ($PipTemp) { Remove-Item -Recurse -Force $PipTemp.FullName -ErrorAction SilentlyContinue }
                Exit 1
            }

            try {
                & "$VenvPython" -m pip install --upgrade pip
                & "$VenvPython" -m pip install $HianyzoCsomagok
            } catch {
                HibaUzenet "Hiba történt a pip csomagok telepítése közben: $_"
                if ($PipTemp) { Remove-Item -Recurse -Force $PipTemp.FullName -ErrorAction SilentlyContinue }
                Exit 1
            }
        }

        if ($PipTemp) { Remove-Item -Recurse -Force $PipTemp.FullName -ErrorAction SilentlyContinue }
    }

    if (Test-Path -LiteralPath 'main.py') {
        $Futtato = $null
        if (Test-Path -LiteralPath '.venv\Scripts\python.exe') { $Futtato = Join-Path (Get-Location) '.venv\Scripts\python.exe' }
        elseif ($PythonParancs) { $Futtato = $PythonParancs }
        else { Informacio 'Nincs Python telepítve a main.py futtatásához.'; Exit 0 }

        try {
            if ($Futtato -eq 'py -3' -or $Futtato -eq 'python') {
                & $Futtato main.py
            } else {
                & "$Futtato" main.py
            }
        } catch {
            HibaUzenet "A main.py futtatása sikertelen: $_"
            Exit 1
        }
    } else {
        Informacio 'Nincs main.py fájl a jelenlegi könyvtárban.'
    }
} finally {
    Pop-Location
}
