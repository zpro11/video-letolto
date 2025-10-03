[CmdletBinding()]
param()

function Letezik {
    param([string]$parancs)
    return $null -ne (Get-Command $parancs -ErrorAction SilentlyContinue)
}

$Grafikus = $false
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop | Out-Null
    $Grafikus = $true
} catch { }

function Informacio {
    param([string]$szoveg)
    if ($Grafikus) {
        [System.Windows.Forms.MessageBox]::Show(
            $szoveg, 'Info',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } else {
        Write-Host $szoveg
    }
}

function HibaUzenet {
    param([string]$szoveg)
    if ($Grafikus) {
        [System.Windows.Forms.MessageBox]::Show(
            $szoveg, 'Hiba',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } else {
        Write-Error $szoveg
    }
}

function Megerosit {
    param([string]$szoveg)
    if ($Grafikus) {
        $valasz = [System.Windows.Forms.MessageBox]::Show(
            $szoveg, 'Megerősítés',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        return $valasz -eq [System.Windows.Forms.DialogResult]::Yes
    } else {
        while ($true) {
            $r = Read-Host "$szoveg [y/N]"
            if ($r -match '^[Yy]') { return $true }
            if ($r -match '^[Nn]$' -or $r -eq '') { return $false }
        }
    }
}

Push-Location (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent)
try {
    $PipCsomagok = @('PyQt5','yt-dlp')

    $PythonParancs = "python"

    try { & $PythonParancs --version > $null 2>&1 } catch {
        HibaUzenet "Python nem található a PATH-ban!"
        Exit 1
    }

    $VanVenv = $false
    try { & $PythonParancs -c "import venv" > $null 2>&1; $VanVenv = $true } catch {
        $VanVenv = $false
    }
    if (-not $VanVenv) { $HianyzoRendszer += 'python-venv modul' }

    $VanPip = $false
    try { & $PythonParancs -m pip --version > $null 2>&1; $VanPip = $true } catch {
        $VanPip = $false
    }
    if (-not $VanPip) { $HianyzoRendszer += 'pip' }

    $HianyzoCsomagok = @()
    if (Test-Path '.venv\Scripts\python.exe') {
        $VenvPython = Join-Path (Get-Location) '.venv\Scripts\python.exe'
        foreach ($p in $PipCsomagok) {
            try {
                & "$VenvPython" -m pip show $p > $null 2>&1
                if ($LASTEXITCODE -ne 0) { $HianyzoCsomagok += $p }
            } catch { $HianyzoCsomagok += $p }
        }
    } else {
        $HianyzoCsomagok = $PipCsomagok.Clone()
    }

    if ($HianyzoRendszer.Count -eq 0 -and $HianyzoCsomagok.Count -eq 0) {
        if (Test-Path 'main.py') {
            $Futtato = if (Test-Path '.venv\Scripts\python.exe') {
                Join-Path (Get-Location) '.venv\Scripts\python.exe'
            } else { $PythonParancs }
            & "$Futtato" main.py
        } else {
            Informacio 'Nincs main.py a könyvtárban.'
        }
        Exit 0
    } else {
        $Uzenet = "Hiányzó rendszer komponensek:`n$($HianyzoRendszer -join '`n')`n`nHiányzó pip csomagok:`n$($HianyzoCsomagok -join ', ')`n`nTelepítsem most?"
        if (-not (Megerosit $Uzenet)) {
            Informacio 'Megszakítva.'
            Exit 0
        }

        if (-not (Test-Path '.venv')) {
            & $PythonParancs -m venv .venv
        }
        $VenvPython = Join-Path (Get-Location) '.venv\Scripts\python.exe'
        if (-not (Test-Path $VenvPython)) {
            HibaUzenet 'Nem találom a .venv python.exe fájlt.'
            Exit 1
        }

        & "$VenvPython" -m pip install --upgrade pip
        if ($HianyzoCsomagok.Count -gt 0) {
            & "$VenvPython" -m pip install $HianyzoCsomagok
        }
    }

    if (Test-Path 'main.py') {
        $Futtato = if (Test-Path '.venv\Scripts\python.exe') {
            Join-Path (Get-Location) '.venv\Scripts\python.exe'
        } else { $PythonParancs }
        & "$Futtato" main.py
    } else {
        Informacio 'Nincs main.py a könyvtárban.'
    }

} finally {
    Pop-Location
}
