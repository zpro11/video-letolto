#!/bin/bash

set -e

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if ! command_exists zenity; then
    if command_exists apt-get; then
        echo "Zenity nincs telepítve — telepítem apt-get-tel (sudo szükséges)..."
        sudo apt-get update && sudo apt-get install -y zenity || true
    fi
fi

#!/bin/bash

set -e

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Try to ensure zenity is present (optional GUI)
if ! command_exists zenity; then
    if command_exists apt-get; then
        echo "Zenity nincs telepítve — telepítem apt-get-tel (sudo szükséges)..."
        sudo apt-get update && sudo apt-get install -y zenity || true
    fi
fi

GUI=0
if command_exists zenity; then
    GUI=1
fi

gui_info() {
    if [ "$GUI" -eq 1 ]; then
        zenity --info --no-wrap --width=450 --text="$1"
    else
        echo "$1"
    fi
}

gui_error() {
    if [ "$GUI" -eq 1 ]; then
        zenity --error --no-wrap --width=450 --text="$1"
    else
        echo "ERROR: $1" >&2
    fi
}

gui_confirm() {
    if [ "$GUI" -eq 1 ]; then
        if zenity --question --no-wrap --width=450 --text="$1"; then
            return 0
        else
            return 1
        fi
    else
        while true; do
            read -p "$1 [y/N]: " yn
            case $yn in
                [Yy]*) return 0 ;;
                [Nn]*|"") return 1 ;;
            esac
        done
    fi
}

APT_PKGS=(python3 python3-venv python3-pip zenity)
PIP_PKGS=(pyqt5 yt-dlp)

MISSING_APT=()

for pkg in "${APT_PKGS[@]}"; do
    case "$pkg" in
        python3)
            if ! command_exists python3; then MISSING_APT+=("$pkg"); fi
            ;;
        python3-venv)
            if command_exists python3; then
                if ! python3 -c "import venv" >/dev/null 2>&1; then MISSING_APT+=("$pkg"); fi
            else
                MISSING_APT+=("$pkg")
            fi
            ;;
        python3-pip)
            if ! command_exists pip3 && ! python3 -m pip --version >/dev/null 2>&1; then MISSING_APT+=("$pkg"); fi
            ;;
        zenity)
            if ! command_exists zenity; then MISSING_APT+=("$pkg"); fi
            ;;
        *)
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then MISSING_APT+=("$pkg"); fi
            ;;
    esac
done

MISSING_PIP=()
if [ -d ".venv" ]; then
    # shellcheck disable=SC1091
    source .venv/bin/activate
    for p in "${PIP_PKGS[@]}"; do
        if ! python -m pip show "$p" >/dev/null 2>&1; then
            MISSING_PIP+=("$p")
        fi
    done
    deactivate >/dev/null 2>&1 || true
else
    MISSING_PIP=("${PIP_PKGS[@]}")
fi

if [ ${#MISSING_APT[@]} -eq 0 ] && [ ${#MISSING_PIP[@]} -eq 0 ]; then
    gui_info "Minden szükséges csomag telepítve van."
else
    total_kb=0
    apt_missing_list=""
    for pkg in "${MISSING_APT[@]}"; do
        apt_missing_list+="$pkg\n"
        if command_exists apt-cache; then
            size_kb=$(apt-cache show "$pkg" 2>/dev/null | awk -F: '/^Installed-Size:/{print $2; exit}' | tr -d ' '\n)
            if [ -n "$size_kb" ]; then
                total_kb=$((total_kb + size_kb))
            else
                size_bytes=$(apt-cache show "$pkg" 2>/dev/null | awk -F: '/^Size:/{print $2; exit}' | tr -d ' '\n)
                if [ -n "$size_bytes" ]; then
                    kb=$(( (size_bytes + 1023) / 1024 ))
                    total_kb=$((total_kb + kb))
                fi
            fi
        fi
    done

    pip_missing_list=""
    pip_temp_dir=""
    if [ ${#MISSING_PIP[@]} -gt 0 ]; then
        pip_missing_list="${MISSING_PIP[*]}"
        if command_exists pip3; then
            pip_temp_dir=$(mktemp -d)
            for p in "${MISSING_PIP[@]}"; do
                python3 -m pip download --no-deps --dest "$pip_temp_dir" "$p" >/dev/null 2>&1 || true
            done
            if [ -d "$pip_temp_dir" ]; then
                pip_bytes=$(du -sb "$pip_temp_dir" 2>/dev/null | cut -f1)
                if [ -n "$pip_bytes" ]; then
                    pip_kb=$(( (pip_bytes + 1023) / 1024 ))
                    total_kb=$((total_kb + pip_kb))
                fi
            fi
        fi
    fi

    if [ "$total_kb" -gt 0 ]; then
        total_mb=$(awk "BEGIN {printf \"%.1f\", $total_kb/1024}")
        size_text="$total_mb MB (kb: ${total_kb} KB)"
    else
        size_text="Ismeretlen (nem sikerült megbecsülni)"
    fi

    msg="Hiányzó apt csomagok:\n$apt_missing_list\n\nHiányzó pip csomagok:\n$pip_missing_list\n\nBecsült foglalás: $size_text\n\nTelepítse a hiányzó csomagokat? (A pip csomagok egy .venv virtuális környezetbe
lesznek telepítve, hogy könnyen törölhetőek legyenek, és ne zavarják a rendszert. Fontos: A run.sh nak
ugyanabban a mappában kell lennie mint a main.py. és a .venv et abban a mappában fogja létrehozni, ahol
a run.sh van.)"

    if ! gui_confirm "$msg"; then
        gui_info "Művelet megszakítva."
        [ -n "$pip_temp_dir" ] && rm -rf "$pip_temp_dir"
        exit 0
    fi

    if [ "$GUI" -eq 1 ]; then
        zenity --progress --pulsate --no-cancel --auto-close --width=500 --text="Telepítés folyamatban..." &
        ZENITY_PID=$!
    fi

    if [ ${#MISSING_APT[@]} -gt 0 ]; then
        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y "${MISSING_APT[@]}"
        else
            gui_error "Nincs apt-get, nem lehet automatikusan telepíteni az apt csomagokat."
            [ -n "$pip_temp_dir" ] && rm -rf "$pip_temp_dir"
            [ -n "$ZENITY_PID" ] && kill "$ZENITY_PID" 2>/dev/null || true
            exit 1
        fi
    fi

    if [ ${#MISSING_PIP[@]} -gt 0 ]; then
        if [ ! -d ".venv" ]; then
            python3 -m venv .venv
        fi
        # shellcheck disable=SC1091
        source .venv/bin/activate
        python -m pip install --upgrade pip
        python -m pip install "${MISSING_PIP[@]}"
        deactivate >/dev/null 2>&1 || true
    fi

    [ -n "$pip_temp_dir" ] && rm -rf "$pip_temp_dir"
    [ -n "$ZENITY_PID" ] && kill "$ZENITY_PID" 2>/dev/null || true
fi

# Launch main application (if present)
if [ -f "main.py" ]; then
    if [ -d ".venv" ]; then
        # shellcheck disable=SC1091
        source .venv/bin/activate
        python main.py
        deactivate >/dev/null 2>&1 || true
    else
        python3 main.py
    fi
else
    gui_info "Nincs main.py fájl a jelenlegi könyvtárban."
fi
                if [ ${#MISSING_APT[@]} -eq 0 ] && [ ${#MISSING_PIP[@]} -eq 0 ]; then
                    :
                else
                    total_kb=0
                    apt_missing_list=""
                    for pkg in "${MISSING_APT[@]}"; do
                        apt_missing_list+="$pkg\n"
                        if command_exists apt-cache; then
                            size_kb=$(apt-cache show "$pkg" 2>/dev/null | awk -F: '/^Installed-Size:/{print $2; exit}' | tr -d ' '\n)
                            if [ -n "$size_kb" ]; then
                                total_kb=$((total_kb + size_kb))
                            else
                                size_bytes=$(apt-cache show "$pkg" 2>/dev/null | awk -F: '/^Size:/{print $2; exit}' | tr -d ' '\n)
                                if [ -n "$size_bytes" ]; then
                                    kb=$(( (size_bytes + 1023) / 1024 ))
                                    total_kb=$((total_kb + kb))
                                fi
                            fi
                        fi
                    done

                    pip_missing_list=""
                    pip_temp_dir=""
                    if [ ${#MISSING_PIP[@]} -gt 0 ]; then
                        pip_missing_list="${MISSING_PIP[*]}"
                        if command_exists pip3; then
                            pip_temp_dir=$(mktemp -d)
                            for p in "${MISSING_PIP[@]}"; do
                                python3 -m pip download --no-deps --dest "$pip_temp_dir" "$p" >/dev/null 2>&1 || true
                            done
                            if [ -d "$pip_temp_dir" ]; then
                                pip_bytes=$(du -sb "$pip_temp_dir" 2>/dev/null | cut -f1)
                                if [ -n "$pip_bytes" ]; then
                                    pip_kb=$(( (pip_bytes + 1023) / 1024 ))
                                    total_kb=$((total_kb + pip_kb))
                                fi
                            fi
                        fi
                    fi

                    if [ "$total_kb" -gt 0 ]; then
                        total_mb=$(awk "BEGIN {printf \"%.1f\", $total_kb/1024}")
                        size_text="$total_mb MB (kb: ${total_kb} KB)"
                    else
                        size_text="Ismeretlen (nem sikerült megbecsülni)"
                    fi

                    msg="Hiányzó apt csomagok:\n$apt_missing_list\n\nHiányzó pip csomagok:\n$pip_missing_list\n\nBecsült foglalás: $size_text\n\nTelepítse a hiányzó csomagokat?"

                    if ! gui_confirm "$msg"; then
                        gui_info "Művelet megszakítva."
                        [ -n "$pip_temp_dir" ] && rm -rf "$pip_temp_dir"
                        exit 0
                    fi

                    if [ "$GUI" -eq 1 ]; then
                        zenity --progress --pulsate --no-cancel --auto-close --width=500 --text="Telepítés folyamatban..." &
                        ZENITY_PID=$!
                    fi

                    if [ ${#MISSING_APT[@]} -gt 0 ]; then
                        if command_exists apt-get; then
                            sudo apt-get update
                            sudo apt-get install -y "${MISSING_APT[@]}"
                        else
                            gui_error "Nincs apt-get, nem lehet automatikusan telepíteni az apt csomagokat."
                            [ -n "$pip_temp_dir" ] && rm -rf "$pip_temp_dir"
                            [ -n "$ZENITY_PID" ] && kill "$ZENITY_PID" 2>/dev/null || true
                            exit 1
                        fi
                    fi

                    if [ ${#MISSING_PIP[@]} -gt 0 ]; then
                        if [ ! -d ".venv" ]; then
                            python3 -m venv .venv
                        fi
                        source .venv/bin/activate
                        python -m pip install --upgrade pip
                        python -m pip install "${MISSING_PIP[@]}"
                        deactivate >/dev/null 2>&1 || true
                    fi

                    [ -n "$pip_temp_dir" ] && rm -rf "$pip_temp_dir"
                    [ -n "$ZENITY_PID" ] && kill "$ZENITY_PID" 2>/dev/null || true
                fi
