# YouTube Downloader Program

## Fő funkciók

* Videó + hang letöltése
* Csak hang letöltése (mp3)
* Csak videó letöltése

## Technológiák

* Python
* PyQt5 (grafikus felület)
* yt-dlp (YouTube letöltés)

## Indítás

Futtasd a `run.sh` fájlt. Ez létrehoz egy virtuális környezetet (`.venv`), és oda telepíti a Python-csomagokat.
Ha a `.venv` már megvan, akkor nem telepít újra semmit.
Továbbra is érdemes a `run.sh`-val indítani, mert az aktiválja a virtuális környezetet, majd elindítja a `main.py`-t.

## Manuális indítás

Nyisd meg a terminált a projekt mappájában.
Írd be:

```
source .venv/bin/activate
```

Majd:

```
python main.py
```

## Információ

A `run.sh` Linuxra készült script, amely Debian-alapú rendszereken fut megfelelően (az `apt-get` miatt).
A Windowsra készült indítóscript várhatóan hamarosan elkészül.
