# Videó letöltő program.

## Fő funkciók

* Videó + hang letöltése
* Csak hang letöltése (mp3)
* Csak videó letöltése
* Széleskörű weboldal támogatás (Youtube, Videa, stb.)

## Technológiák

* Python
* PyQt5 (grafikus felület)
* yt-dlp (YouTube letöltés)

## Indítás

Futtasd a `run.sh` fájlt. Ez létrehoz egy virtuális környezetet (`.venv`), és oda telepíti a Python-csomagokat.
Ha a `.venv` már megvan, akkor nem telepít újra semmit.
Továbbra is érdemes a `run.sh`-val indítani, mert az aktiválja a virtuális környezetet, majd elindítja a `main.py`-t.

## Manuális indítás (Csak Linux-on)

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

A `run.sh` Debian alapú rendszerekre definiált indító. A `run.ps1` Windows-ra definiált indító. Python és FFmpeg szükséges
a futtatáshoz. FFmpeg nélkül is fut, de azzal rakja össze a program a hangot és a videót. Anélkül csak videó vagy csak hang tölthető le.

FFmpeg telepítése linux Debian alapú rendszereken:

```
sudo apt update
```

```
sudo apt install ffmpeg
```

Teszt hogy települt e:

```
ffmpeg -version
```

Ha hibát dob, nem települt.
