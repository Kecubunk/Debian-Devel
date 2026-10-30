#!/bin/bash
#
#

# ---------------------------------------------------------------------------
# Color palette & UI helpers
# ---------------------------------------------------------------------------
R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'; B='\033[1;34m'
M='\033[1;35m'; C='\033[1;36m'; W='\033[1;37m'; D='\033[2m' 
BG_C='\033[48;5;236m'; N='\033[0m'

VERSION="1.0.0"
BUILD_DATE=$(date '+%Y-%m-%d %H:%M:%S')
TOTAL_STAGES=5

tty_print() { [ -t 1 ] && printf "$@" || true; }
_ok()   { tty_print "  ${G}[ ✔ ok ]${N}  %s\n" "$1"; }
_warn() { tty_print "  ${Y}[ ⚠ warn]${N}  %s\n" "$1"; }
_skip() { tty_print "  ${R}[ ↷ skip] ${N}%s\n" "$1"; }
_err()  { tty_print "  ${R}[ ✖ error] ${N}  %s\n" "$1"; }
_info() { tty_print "  ${C}[ i info]${N}  %s\n" "$1"; }
_sub()  { tty_print "  ${G}[ ▶ sub]${N}  %s\n" "$1"; }
_step() {
    tty_print "\n${Y}[Stage %s/%s]${N} ${W}%s${N}\n" "$1" "$TOTAL_STAGES" "$2"
    tty_print "${D}$(printf '═%.0s' $(seq 1 55))${N}\n"
}

banner(){
# ─── Banner ───────────────────────────────────────────────────────────────────
if [ -t 1 ] && [ -n "${TERM:-}" ]; then
    clear
fi
printf "\n"
printf "${C}  ╔══════════════════════════════════════════════════════════╗${N}\n"
printf "${C}  ║${N}                                                          ${C}║${N}\n"
printf "${C}  ║${N}  ${M} ██████╗ █████╗ ██████╗ ██████╗  ██████╗ ███╗   ██╗   ${N}  ${C}║${N}\n"
printf "${C}  ║${N}  ${M}██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔═══██╗████╗  ██║   ${N}  ${C}║${N}\n"
printf "${C}  ║${N}  ${M}██║     ███████║██████╔╝██████╔╝██║   ██║██╔██╗ ██║   ${N}  ${C}║${N}\n"
printf "${C}  ║${N}  ${M}██║     ██╔══██║██╔══██╗██╔══██╗██║   ██║██║╚██╗██║   ${N}  ${C}║${N}\n"
printf "${C}  ║${N}  ${M}╚██████╗██║  ██║██║  ██║██████╔╝╚██████╔╝██║ ╚████║   ${N}  ${C}║${N}\n"
printf "${C}  ║${N}  ${M} ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝╚═╝  ╚═══╝    ${N}  ${C}║${N}\n"
printf "${C}  ║${N}                                                          ${C}║${N}\n"
printf "${C}  ╠══════════════════════════════════════════════════════════╣${N}\n"
printf "${C}  ║${N}         ${W} C A R B O N - S C R I P T ($VERSION)${N}               ${C}║${N}\n"
printf "${C}  ║${N}  Host: $(hostname)${N}             Date: $(date '+%Y-%m-%d %H:%M:%S')${N}      ${C}║${N}\n"
printf "${C}  ║${N}  arch: $(dpkg --print-architecture 2>/dev/null || echo unknown)              Kernel: $(uname -r) ${N}  ${C}║${N}\n"
printf "${C}  ╚══════════════════════════════════════════════════════════╝${N}\n"
# ─── Banner ───────────────────────────────────────────────────────────────────
}

show_version() {
    printf "${W}%s${N} ${G}v%s${N}  ${D}(built %s)${N}\n" \
           "$SCRIPT_NAME" "$VERSION" "$BUILD_DATE"
}

show_info() {
    banner
    printf "  ${Y}Package  :${N} carbon-gnome\n"
    printf "  ${Y}Version  :${N} ${G}%s${N}\n" "$VERSION"
    printf "  ${Y}Build    :${N} %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    printf "  ${Y}Base     :${N} carbon-base\n"
    printf "\n"
    printf "  ${D}Extensions terinstall:${N}\n"
    _EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
    if [ -d "$_EXT_DIR" ]; then
        for _ext in "$_EXT_DIR"/*/; do
            [ -d "$_ext" ] || continue
            _meta="$_ext/metadata.json"
            _name="$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' \
                "$_meta" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"//')"
            printf "    ${D}%-45s${N} %s\n" "$(basename "$_ext")" "${_name:-}"
        done
    else
        printf "    ${D}Tidak ada extensions ditemukan di $_EXT_DIR${N}\n"
    fi
    printf "\n"
    printf "  ${D}Utilities:${N}\n"
    for _bin in carbon-gnome htop cava starship ; do
        if command -v "$_bin" >/dev/null 2>&1; then
            printf "    ${G}✔${N}  %-20s\n" "$_bin"
        else
            printf "    ${D}✗  %-20s (not found)${N}\n" "$_bin"
        fi
    done
    printf "\n"
}

depend(){
# Pastikan dijalankan sebagai root (sudo)
if [ "$EUID" -ne 0 ]; then
  echo "[-] Harap jalankan skrip ini dengan sudo atau sebagai root."
  exit 1
fi

_step "1" "Memeriksa ketersediaan paket"
# 1. Daftar Paket yang Akan Diperiksa & Diinstal
pkg=(
    "curl"
    "wget"
    "git"
    "python3"
    "python3-pip"
    "python3-venv"
    "python3-dev"
    "portaudio19-dev"
    "htop"
    "preload"
    "gamemode"
    "zram-tools"
    "earlyoom"
)

for p in "${pkg[@]}"; do
    # Periksa apakah paket sudah terinstal menggunakan dpkg-query
    if dpkg-query -W -f='${Status}\n' "$p" 2>/dev/null | grep -q "install ok installed"; then
        _skip "Paket '$p' sudah tersedia"
    else
        # Jika belum, instal paket
        apt install -y "$p"
        _ok "Paket '$p' Terinstall dengan baik"
    fi
done

_step "2" "Konfigurasi ZRAM-tools"
# 2. Konfigurasi ZRAM
cat << 'EOF' > /etc/default/zramswap
PERCENT=50
ALGO=zstd
PRIORITY=100
EOF
# Restart layanan zramswap
systemctl restart zramswap

_step "3" "Konfigurasi Earlyoom"
# 3. Konfigurasi Earlyoom
echo -e "\n[3/5] Mengonfigurasi Earlyoom..."
cat << 'EOF' > /etc/default/earlyoom
EARLYOOM_ARGS="-r 60 -m 10 -s 5 --avoid '(^|\/)(Xorg|wayland|gnome-shell|kwin|sddm|lightdm|kitty|bash|zsh)$'"
EOF

_step "4" "Konfigurasi Earlyoom"
# Aktifkan dan jalankan earlyoom
systemctl enable --now earlyoom
systemctl restart earlyoom

# 4. Verifikasi Status
_step "5" "Verifikasi Status"
echo "------------------------------------------"
echo "Status ZRAM (zramctl):"
zramctl
echo "------------------------------------------"
echo "Status Earlyoom:"
systemctl status earlyoom --no-pager | head -n 10
echo "=========================================="
_step "[5/5] Konfigurasi Earlyoom"
echo "Setup Selesai! Sistem Anda kini lebih optimal dan responsif."
}

bloatware(){
# Pastikan script dijalankan sebagai root/sudo
if [ "$EUID" -ne 0 ]; then
  echo "[-] Harap jalankan script ini dengan sudo atau sebagai root."
  exit 1
fi

# Daftar umum paket bloatware / aplikasi bawaan Debian GNOME
bloatware_pkg=(
    "gnome-games"
    "aisleriot"
    "five-or-more"
    "four-in-a-row"
    "gnome-chess"
    "gnome-klotski"
    "gnome-mahjongg"
    "gnome-mines"
    "gnome-nibbles"
    "gnome-robots"
    "gnome-sudoku"
    "gnome-taquin"
    "gnome-tetravex"
    "hitori"
    "iagno"
    "lightsoff"
    "quadrapassel"
    "swell-foop"
    "tali"
    "totem"
    "rhythmbox"
    "cheese"
    "gnome-documents"
    "totem-common"
    "orca"
    "speech-dispatcher"
    "transmission-gtk"
    "brasero"
)

echo "=================================================="
echo "   MEMERIKSA PAKET BLOATWARE DI DEBIAN GNOME"
echo "=================================================="
echo ""

# Array untuk menampung paket yang benar-benar terinstal di sistem
installed_bloat=()

for p in "${bloatware_pkg[@]}"; do
    if dpkg-query -W -f='${Status}\n' "$p" 2>/dev/null | grep -q "install ok installed"; then
        echo -e " [ ✖ ] \033[31m$p\033[0m (Terinstal)"
        installed_bloat+=("$p")
    else
        echo -e " [ ✔ ] \033[32m$p\033[0m (Tidak ada / Bersih)"
    fi
done

echo ""
echo "=================================================="

# Cek apakah ada paket terinstal yang ditemukan
if [ ${#installed_bloat[@]} -eq 0 ]; then
    echo "[ ✔ ] Tidak ada paket bloatware yang ditemukan. Sistem Anda sudah bersih!"
    exit 0
fi

echo "Daftar paket bloatware yang terdeteksi (${#installed_bloat[@]} paket):"
for i in "${!installed_bloat[@]}"; do
    echo "  $((i+1)). ${installed_bloat[$i]}"
done
echo "=================================================="

# Meminta konfirmasi pengguna untuk menghapus
read -p "Apakah Anda ingin menghapus semua paket di atas? (y/N): " choice

case "$choice" in 
  y|Y )
    echo ""
    echo "[+] Menghapus paket bloatware..."
    apt purge -y "${installed_bloat[@]}"
    
    echo "[+] Membersihkan sisa dependensi..."
    apt autoremove --purge -y
    
    echo "[ ✔ ] Pembersihan selesai!"
    ;;
  * )
    echo "[-] Penghapusan dibatalkan oleh pengguna."
    ;;
esac
}

opt(){

# Pastikan script utama dijalankan dengan root/sudo (untuk system-level services)
if [ "$EUID" -ne 0 ]; then
  echo "[-] Harap jalankan script ini dengan sudo atau sebagai root."
  exit 1
fi

BACKUP_FILE="/etc/debian_service_backup.txt"
USER_BACKUP_FILE="/tmp/debian_tracker_user_backup.txt"

# 1. Daftar system-level service non-esensial
services_to_disable=(
    "ModemManager.service"
    "avahi-daemon.service"
    "cups.service"
    "apport.service"
    "whoopsie.service"
    "PackageKit.service"
    "GeoClue.service"
)

# 2. Daftar tracker service (User-level)
tracker_services=(
    "tracker-store-3.service"
    "tracker-miner-fs-3.service"
    "tracker-extract-3.service"
    "tracker-miner-rss-3.service"
)

# Mendapatkan nama user non-root yang sedang aktif/login (untuk perintah --user)
TARGET_USER=$(logname 2>/dev/null || echo "$SUDO_USER")

echo "=========================================================="
echo "      OPTIMASI & MATIKAN BLOAT/TRACKER RAM DEBIAN"
echo "=========================================================="
echo ""
echo "Menu Pilihan:"
echo " 1. Nonaktifkan (Disable) Service & Tracker untuk hemat RAM"
echo " 2. Pulihkan (Enable kembali) Service & Tracker seperti semula"
echo " 3. Keluar"
echo ""
read -p "Pilih opsi (1/2/3): " choice

case "$choice" in
    1)
        echo ""
        echo "[+] Memeriksa dan menonaktifkan system-level service..."
        > "$BACKUP_FILE"
        
        disabled_count=0
        for svc in "${services_to_disable[@]}"; do
            if systemctl list-unit-files | grep -q "^$svc"; then
                if systemctl is-enabled "$svc" &>/dev/null; then
                    echo "    - Menonaktifkan system service: $svc"
                    systemctl stop "$svc"
                    systemctl disable "$svc"
                    echo "$svc" >> "$BACKUP_FILE"
                    ((disabled_count++))
                fi
            fi
        done

        echo ""
        echo "[+] Menonaktifkan GNOME Tracker (Pencarian & Indexing File)..."
        > "$USER_BACKUP_FILE"
        
        if [ -n "$TARGET_USER" ]; then
            # Menjalankan perintah systemctl --user atas nama user aktif
            for tsvc in "${tracker_services[@]}"; do
                if sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")" systemctl --user list-unit-files | grep -q "^$tsvc"; then
                    echo "    - Menonaktifkan tracker user service: $tsvc"
                    sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")" systemctl --user stop "$tsvc"
                    sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")" systemctl --user mask "$tsvc"
                    echo "$tsvc" >> "$USER_BACKUP_FILE"
                fi
            done
            # Mencegah tracker hidup kembali lewat dconf/gsettings
            sudo -u "$TARGET_USER" gsettings set org.freedesktop.Tracker3.Miner.Files enable-monitors false 2>/dev/null
        else
            echo "[-] Peringatan: Tidak dapat mendeteksi user aktif untuk mematikan tracker session."
        fi
        
        echo ""
        echo "=========================================================="
        echo " [ ✔ ] Berhasil menonaktifkan service & tracker!"
        echo " [ i ] Anda disarankan untuk melakukan reboot sistem."
        echo "=========================================================="
        ;;
        
    2)
        echo ""
        echo "[+] Memulihkan system-level service..."
        if [ -f "$BACKUP_FILE" ]; then
            while IFS= read -r svc; do
                if [ -n "$svc" ]; then
                    echo "    + Mengaktifkan kembali: $svc"
                    systemctl enable "$svc"
                    systemctl start "$svc"
                fi
            done < "$BACKUP_FILE"
            rm -f "$BACKUP_FILE"
        fi

        echo "[+] Memulihkan GNOME Tracker..."
        if [ -n "$TARGET_USER" ] && [ -f "$USER_BACKUP_FILE" ]; then
            while IFS= read -r tsvc; do
                if [ -n "$tsvc" ]; then
                    echo "    + Unmask & mengaktifkan tracker: $tsvc"
                    sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")" systemctl --user unmask "$tsvc"
                    sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")" systemctl --user enable "$tsvc"
                    sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")" systemctl --user start "$tsvc"
                fi
            done < "$USER_BACKUP_FILE"
            sudo -u "$TARGET_USER" gsettings set org.freedesktop.Tracker3.Miner.Files enable-monitors true 2>/dev/null
            rm -f "$USER_BACKUP_FILE"
        fi
        
        echo ""
        echo "=========================================================="
        echo " [ ✔ ] Semua service & tracker berhasil dipulihkan!"
        echo "=========================================================="
        ;;
        
    3)
        echo "Keluar dari script."
        exit 0
        ;;
        
    * )
        echo "[-] Pilihan tidak valid."
        exit 1
        ;;
esac

}


case "${1:-}" in
    -v|--version)
        show_version ;;
    --info|-i)
        show_info ;;
    --install)
        banner
        depend;;
    --clean)
      banner
      bloatware;;
    --optimized|-o)
      banner
      opt;;
    "")
        banner
        printf "  Usage: carbon-gnome [-v|--version] [--info|-i] [ --install ] [ --clean ]\n\n" ;;
    *)
        printf "Unknown option: %s\n" "$1" >&2
        exit 1 ;;
esac
