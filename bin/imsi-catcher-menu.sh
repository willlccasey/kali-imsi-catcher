#!/bin/bash
# IMSI-Catcher Menu - numbered selections for https://github.com/oros42/imsi-catcher
# Companion to HackRF Tools + GR-GSM menus. Easy access to IMSI tracking, no long commands.
# Legal: This is for understanding GSM networks you are authorized to monitor. Respect local laws.

set -euo pipefail

# Colors (match other menus)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

IMSI_DIR="$HOME/imsi-catcher"
SUDO_PASS="2482"

function sudo_run() {
  # Supply password via -S for automatic sudo (no interactive prompt)
  # Used for sniff mode, apt installs, wireshark etc. in this launcher.
  echo "$SUDO_PASS" | sudo -S "$@"
}
CATCHER="$IMSI_DIR/simple_IMSI-catcher.py"
IMMEDIATE="$IMSI_DIR/immediate_assignment_catcher.py"
SCAN_LIVEMON="$IMSI_DIR/scan-and-livemon"

function pause() {
  echo ""
  read -rp "Press Enter to return to menu..." _
  clear
}

# Helper to open a command in a fresh terminal window (for auto-launching catcher viewer)
function launch_in_new_terminal() {
  local title="$1"
  shift
  local cmd="$*"
  local post="; echo; read -p 'Press Enter to close this viewer terminal...' _"

  if command -v qterminal >/dev/null 2>&1; then
    qterminal --title="$title" -e bash -c "$cmd $post" &
  elif command -v xfce4-terminal >/dev/null 2>&1; then
    xfce4-terminal --title="$title" --geometry=100x25 --command="bash -c '$cmd $post'" &
  elif command -v gnome-terminal >/dev/null 2>&1; then
    gnome-terminal --title="$title" -- bash -c "$cmd $post" &
  elif command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -e bash -c "$cmd $post" 2>/dev/null || \
    x-terminal-emulator -- bash -c "$cmd $post" 2>/dev/null || \
    xterm -T "$title" -e bash -c "$cmd $post" 2>/dev/null || \
    bash -c "$cmd $post" &
  elif command -v terminator >/dev/null 2>&1; then
    terminator -T "$title" -e "bash -c '$cmd $post'" &
  else
    echo "No known terminal emulator found - running in background here."
    bash -c "$cmd" &
  fi
  sleep 1
}

function check_tools() {
  echo -e "${BLUE}Checking IMSI-Catcher tools & dependencies...${NC}"
  echo "Source: $IMSI_DIR"
  [ -x "$CATCHER" ] && echo -e "  ${GREEN}✓${NC} simple_IMSI-catcher.py" || echo -e "  ${RED}✗${NC} simple_IMSI-catcher.py (run installer)"
  [ -x "$IMMEDIATE" ] && echo -e "  ${GREEN}✓${NC} immediate_assignment_catcher.py" || echo -e "  ${RED}✗${NC} immediate_assignment_catcher.py"
  [ -x "$SCAN_LIVEMON" ] && echo -e "  ${GREEN}✓${NC} scan-and-livemon" || echo -e "  ${RED}✗${NC} scan-and-livemon"

  echo ""
  for cmd in grgsm_scanner grgsm_livemon grgsm_livemon_headless; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo -e "  ${GREEN}✓${NC} $cmd"
    else
      echo -e "  ${RED}✗${NC} $cmd  (select option 2/3 from main menu -- it will offer to install automatically)"
    fi
  done
  echo ""
  echo "HackRF tools / kalibrate available via other menus (recommended for PPM + freq)."
  pause
}

function ensure_grgsm() {
  if command -v grgsm_scanner >/dev/null 2>&1 && command -v grgsm_livemon >/dev/null 2>&1; then
    return 0
  fi
  echo -e "${RED}ERROR: gr-gsm tools not found (grgsm_scanner / grgsm_livemon missing).${NC}"
  echo ""
  echo "These tools (from the gr-gsm package) are required to scan and decode GSM signals."
  echo "Without them, the scanner, livemon, etc. cannot run."
  echo ""
  echo "Would you like to install them now? (This will run the installer, which may ask for your sudo password once.)"
  read -rp "Install gr-gsm now? [Y/n]: " ans
  if [[ -z "$ans" || "$ans" =~ ^[yY] ]]; then
    echo ""
    echo "Running installer (this may take a while and use sudo)..."
    installed=false
    if [ -f "$HOME/install-imsi-catcher.sh" ]; then
      chmod +x "$HOME/install-imsi-catcher.sh" 2>/dev/null || true
      bash "$HOME/install-imsi-catcher.sh" || true
      installed=true
    fi
    if [ "$installed" = false ] && [ -f "$HOME/install-gr-gsm.sh" ]; then
      echo "Trying dedicated gr-gsm installer..."
      chmod +x "$HOME/install-gr-gsm.sh" 2>/dev/null || true
      bash "$HOME/install-gr-gsm.sh" || true
      installed=true
    fi
    if [ "$installed" = false ]; then
      echo "No direct installer found. Falling back to launching GR-GSM Tools menu so you can choose install there..."
      if [ -x "$HOME/bin/grgsm-menu.sh" ]; then
        "$HOME/bin/grgsm-menu.sh"
      fi
    fi
    echo ""
    echo "Install attempt finished. Re-checking for grgsm tools..."
    if command -v grgsm_scanner >/dev/null 2>&1 && command -v grgsm_livemon >/dev/null 2>&1; then
      echo -e "${GREEN}Success! gr-gsm tools are now installed.${NC}"
      return 0
    else
      echo -e "${RED}Still not found after install attempt.${NC}"
      echo "You may need to restart this menu, or manually run one of the install scripts in a terminal:"
      echo "  ~/install-imsi-catcher.sh"
      echo "  or ~/install-gr-gsm.sh"
      echo "Or choose option 8 from main menu to launch GR-GSM Tools menu and install from there (option 9 inside it)."
      pause
      return 1
    fi
  else
    echo ""
    echo "Installation skipped."
    echo "To install later: from main menu choose option 12 (Install / Update), or option 8 then install inside GR-GSM menu."
    pause
    return 1
  fi
}

function run_grgsm_scanner() {
  if ! ensure_grgsm; then
    return
  fi

  echo -e "${YELLOW}grgsm_scanner${NC} (find cells/freqs for the catcher)"
  echo "Use output freq (e.g. 925.4M or 925400000) for livemon later (option 3 has presets too)."
  echo "Recommend: first use kalibrate-hackrf (from HackRF menu) for accurate PPM."
  echo "The preset list below gives named bands + typical freq ranges for HackRF vs RTL-SDR etc."
  echo ""

  # Dropdown with named frequency/band selections for different devices
  echo -e "${CYAN}Band presets (named for common devices/bands with typical freq ranges):${NC}"
  echo "  1) HackRF - GSM900 (most common, ~925-960 MHz downlink)"
  echo "  2) HackRF - DCS1800 (~1805-1880 MHz)"
  echo "  3) HackRF - PCS1900 (~1930-1990 MHz)"
  echo "  4) HackRF - GSM850 (~824-849 MHz)"
  echo "  5) HackRF - EGSM (extended GSM900, ~925-960 MHz)"
  echo "  6) RTL-SDR typical - GSM900 (lower gain / USB sticks)"
  echo "  7) Custom band entry"
  echo ""
  read -rp "Select preset number [1-7, default 1]: " pchoice; pchoice=${pchoice:-1}

  local band="GSM900"
  local suggested_gain=24
  local suggested_ppm=0
  local suggested_args="hackrf"
  local preset_name="HackRF - GSM900 (most common, ~925-960 MHz downlink)"

  case "$pchoice" in
    1)
      band="GSM900"
      preset_name="HackRF - GSM900 (most common, ~925-960 MHz downlink)"
      suggested_gain=24
      suggested_args="hackrf"
      ;;
    2)
      band="DCS"
      preset_name="HackRF - DCS1800 (~1805-1880 MHz)"
      suggested_gain=20
      suggested_args="hackrf"
      ;;
    3)
      band="PCS"
      preset_name="HackRF - PCS1900 (~1930-1990 MHz)"
      suggested_gain=18
      suggested_args="hackrf"
      ;;
    4)
      band="GSM850"
      preset_name="HackRF - GSM850 (~824-849 MHz)"
      suggested_gain=24
      suggested_args="hackrf"
      ;;
    5)
      band="EGSM"
      preset_name="HackRF - EGSM (extended GSM900, ~925-960 MHz)"
      suggested_gain=24
      suggested_args="hackrf"
      ;;
    6)
      band="GSM900"
      preset_name="RTL-SDR typical - GSM900 (lower gain / USB sticks)"
      suggested_gain=20
      suggested_args=""
      ;;
    7|*)
      read -rp "Band [GSM900/DCS/PCS/GSM850/EGSM]: " band; band=${band:-GSM900}
      preset_name="Custom band"
      ;;
  esac

  echo -e "\n${GREEN}Preset: $preset_name${NC}"
  if [ "$pchoice" = "7" ]; then
    echo "Band set to: $band"
  else
    echo "Band from preset: $band (you can override gain/ppm/args below; leave blank to use defaults)"
  fi

  read -rp "Gain (default $suggested_gain): " gain; gain=${gain:-$suggested_gain}
  read -rp "PPM correction (0 if unknown; use kalibrate first): " ppm; ppm=${ppm:-$suggested_ppm}

  echo "Device args (how to talk to your SDR - common choices):"
  echo "  1) hackrf (default for HackRF One)"
  echo "  2) hackrf,bias=1 (HackRF + bias tee / external LNA power)"
  echo "  3) (blank / auto) - Let gr-gsm auto-detect (good for RTL-SDR)"
  echo "  4) rtl=0 - Force RTL-SDR device 0"
  echo "  5) Custom - enter your own string"
  read -rp "Choice [1-5, default based on preset]: " dev_choice; dev_choice=${dev_choice:-0}
  case "$dev_choice" in
    1) args="hackrf" ;;
    2) args="hackrf,bias=1" ;;
    3) args="" ;;
    4) args="rtl=0" ;;
    5) read -rp "Custom device args: " args ;;
    *) args="$suggested_args" ;;
  esac

  local cmd="grgsm_scanner -b $band -g $gain -p $ppm"
  [ -n "$args" ] && cmd+=" --args \"$args\""

  echo -e "\n${GREEN}Running: $cmd${NC}"
  echo -e "${CYAN}Ctrl-C to stop. Note strong cells + exact freqs (use in livemon option 3).${NC}\n"
  eval "$cmd" || true
  pause
}

function run_grgsm_livemon() {
  if ! ensure_grgsm; then
    return
  fi

  echo -e "${YELLOW}grgsm_livemon${NC} (live GUI + GSMTAP to UDP 4729 for the catcher)"
  echo "Run this (or livemon_headless), then run the IMSI catcher in another session / via menu."
  echo ""

  # New dropdown/preset list with named frequencies for different devices/bands
  echo -e "${CYAN}Frequency presets (named for common devices/bands - start with these!):${NC}"
  echo "  1) HackRF - GSM900 Standard (925.2 MHz)     [most common starting point]"
  echo "  2) HackRF - GSM900 Alt (925.4 MHz)          [another frequent cell]"
  echo "  3) HackRF - DCS1800 (1805.2 MHz)            [higher band]"
  echo "  4) HackRF - PCS1900 (1930.2 MHz)"
  echo "  5) RTL-SDR common - GSM900 (925.0 MHz)      [for cheap RTL sticks]"
  echo "  6) Custom / type your own freq (from scanner or kalibrate)"
  echo ""
  read -rp "Select preset number [1-6, default 1]: " pchoice; pchoice=${pchoice:-1}

  local preset_name="Custom"
  local suggested_gain=32
  local suggested_ppm=0
  local suggested_args="hackrf"

  case "$pchoice" in
    1)
      fc="925.2M"
      preset_name="HackRF - GSM900 Standard (925.2 MHz)"
      suggested_gain=32
      suggested_args="hackrf"
      ;;
    2)
      fc="925.4M"
      preset_name="HackRF - GSM900 Alt (925.4 MHz)"
      suggested_gain=32
      suggested_args="hackrf"
      ;;
    3)
      fc="1805.2M"
      preset_name="HackRF - DCS1800 (1805.2 MHz)"
      suggested_gain=30
      suggested_args="hackrf"
      ;;
    4)
      fc="1930.2M"
      preset_name="HackRF - PCS1900 (1930.2 MHz)"
      suggested_gain=28
      suggested_args="hackrf"
      ;;
    5)
      fc="925.0M"
      preset_name="RTL-SDR common - GSM900 (925.0 MHz)"
      suggested_gain=20
      suggested_args=""   # RTL often auto or rtl=0
      ;;
    6|*)
      read -rp "Enter custom freq (Hz or e.g. 925.4M): " fc
      preset_name="Custom entry"
      ;;
  esac

  if [ -z "$fc" ]; then echo "Freq required"; pause; return; fi

  echo -e "\n${GREEN}Preset: $preset_name${NC}"
  echo "Recommend running kalibrate-hackrf first (HackRF menu) for best PPM."

  read -rp "Center freq (default $fc): " user_fc; fc=${user_fc:-$fc}
  read -rp "Gain (default $suggested_gain for this preset): " g; g=${g:-$suggested_gain}
  read -rp "PPM (default $suggested_ppm): " p; p=${p:-$suggested_ppm}

  echo "Device args (how to talk to your SDR - common choices):"
  echo "  1) hackrf (default for HackRF One)"
  echo "  2) hackrf,bias=1 (HackRF + bias tee / external LNA power)"
  echo "  3) (blank / auto) - Let gr-gsm auto-detect (good for RTL-SDR)"
  echo "  4) rtl=0 - Force RTL-SDR device 0"
  echo "  5) Custom - enter your own string"
  read -rp "Choice [1-5, default based on preset]: " dev_choice; dev_choice=${dev_choice:-0}
  case "$dev_choice" in
    1) args="hackrf" ;;
    2) args="hackrf,bias=1" ;;
    3) args="" ;;
    4) args="rtl=0" ;;
    5) read -rp "Custom device args: " args ;;
    *) args="$suggested_args" ;;
  esac

  local cmd="grgsm_livemon -f $fc -g $g -p $p"
  [ -n "$args" ] && cmd+=" --args \"$args\""

  echo -e "\n${GREEN}Launching: $cmd &${NC}"
  echo -e "${CYAN}A small spectrum + constellation GUI will pop up.${NC}"
  echo -e "${YELLOW}It will feed GSMTAP packets to UDP localhost:4729${NC}\n"

  eval "$cmd" &
  sleep 2

  # Automatically open a new terminal running the catcher so user can "view what it is picking up"
  echo "Automatically open a NEW terminal with the IMSI catcher (to immediately see what is being picked up on GSMTAP)?"
  echo "  1) Yes (default) - Launches a fresh terminal running the catcher + auto-logs to /tmp (very convenient)"
  echo "  2) No - You'll have to start the catcher manually (option 4) in another terminal or here"
  read -rp "Choice [1-2, default 1]: " auto_choice; auto_choice=${auto_choice:-1}
  if [ "$auto_choice" = "1" ]; then
    local ts=$(date +%Y%m%d_%H%M%S)
    local catcher_cmd="cd $IMSI_DIR && python3 simple_IMSI-catcher.py -w /tmp/imsi_${ts}.db"
    launch_in_new_terminal "IMSI-Catcher Live View (GSMTAP from livemon :4729) [logs to /tmp/imsi_${ts}.db]" "$catcher_cmd"
    echo -e "${GREEN}New terminal launched for catcher!${NC}"
    echo -e "It will print IMSIs, country, operator etc. live. Also logging to /tmp/imsi_${ts}.db"
  else
    echo -e "${YELLOW}You can manually run option 4 (or the catcher) in another terminal.${NC}"
  fi

  pause
}

function run_catcher() {
  local extra_flags=""
  echo -e "${YELLOW}simple_IMSI-catcher.py${NC} - Main IMSI tracker (listens for GSMTAP or sniffs)"
  echo "Typical: run grgsm_livemon first (or option 3), then this."
  echo ""

  # Sniff mode choice with definition
  echo "Sniff / Listen mode (how the catcher gets the GSMTAP packets):"
  echo "  1) Listen (default, recommended) - Listen on UDP port for packets sent by grgsm_livemon / livemon_headless (no root needed, clean separation)"
  echo "  2) Sniff (-s) - Directly sniff the network interface for GSMTAP (requires sudo/root, use when not running separate livemon)"
  read -rp "Choice [1-2, default 1]: " sniff_choice; sniff_choice=${sniff_choice:-1}
  if [ "$sniff_choice" = "2" ]; then
    extra_flags+=" -s"
    echo "Will use sudo for sniff mode."
  else
    echo "Will listen on UDP port (run grgsm_livemon / livemon_headless first to feed it)."
  fi

  # Track IMSI choice with definition
  echo ""
  echo "Track specific IMSI:"
  echo "  1) All IMSIs (default) - Show every IMSI the catcher sees"
  echo "  2) Specific IMSI only - Track just one number (e.g. for targeted monitoring)"
  read -rp "Choice [1-2, default 1]: " track_choice; track_choice=${track_choice:-1}
  if [ "$track_choice" = "2" ]; then
    read -rp "Enter the IMSI to track (e.g. 123456789012345): " imsi
    [ -n "$imsi" ] && extra_flags+=" -m $imsi"
  fi

  # Show all TMSI choice with definition
  echo ""
  echo "Show TMSIs without full IMSI (-a flag):"
  echo "  1) No (default) - Only show entries where we have the full IMSI"
  echo "  2) Yes (-a) - Also show TMSIs that haven't been mapped to an IMSI yet (more data but less useful)"
  read -rp "Choice [1-2, default 1]: " allt_choice; allt_choice=${allt_choice:-1}
  if [ "$allt_choice" = "2" ]; then
    extra_flags+=" -a"
  fi

  # Port choice
  echo ""
  echo "UDP port to listen on (only relevant in Listen mode, default 4729 matches what livemon sends to):"
  echo "  1) 4729 (default, standard for grgsm_livemon GSMTAP)"
  echo "  2) Custom port (use if you changed serverport in livemon_headless or scan-and-livemon)"
  read -rp "Choice [1-2, default 1]: " port_choice; port_choice=${port_choice:-1}
  if [ "$port_choice" = "2" ]; then
    read -rp "UDP port (default 4729): " port
    [ -n "$port" ] && extra_flags+=" -p $port"
  fi

  # Logging choices - consolidated with definitions
  echo ""
  echo "Logging (save observed IMSIs for later):"
  echo "  1) None (default) - Just print live to the terminal"
  echo "  2) SQLite file (.db) - Structured database, easy to query later with sqlite3 (recommended for most users)"
  echo "  3) Text file (.txt) - Simple plain-text append log"
  echo "  4) MySQL (--mysql / -z) - Advanced, requires prior setup (option 13) + .env with DB creds"
  read -rp "Choice [1-4, default 1]: " log_choice; log_choice=${log_choice:-1}
  case "$log_choice" in
    2)
      read -rp "SQLite filename (default imsi.db): " sqlite; sqlite=${sqlite:-imsi.db}
      extra_flags+=" -w $sqlite"
      ;;
    3)
      read -rp "TXT filename (default imsi.txt): " txt; txt=${txt:-imsi.txt}
      extra_flags+=" -t $txt"
      ;;
    4)
      extra_flags+=" -z"
      echo "MySQL mode selected - make sure you ran option 13 first and have .env configured!"
      ;;
    *)
      # none
      ;;
  esac

  # Extra args with common examples
  echo ""
  echo "Extra/advanced args (passed directly to the script):"
  echo "  Common examples:"
  echo "    --iface lo          (listen on loopback - default for livemon)"
  echo "    -a                  (same as choice 2 above)"
  echo "    (leave blank for none)"
  read -rp "Extra args (or blank): " more
  [ -n "$more" ] && extra_flags+=" $more"

  local cmd="python3 $CATCHER $extra_flags"

  echo -e "\n${GREEN}Running from $IMSI_DIR : $cmd${NC}"
  echo -e "${YELLOW}Watch for IMSI output (country/brand/operator). Ctrl-C to stop.${NC}"
  echo -e "${RED}Legal warning: Only for networks you are authorized to monitor.${NC}\n"

  if [[ "$extra_flags" == *"-s"* ]]; then
    sudo_run bash -c "cd $IMSI_DIR && python3 simple_IMSI-catcher.py $extra_flags"
  else
    (cd "$IMSI_DIR" && python3 simple_IMSI-catcher.py $extra_flags) || true
  fi
  pause
}

function run_immediate_assignment() {
  echo -e "${YELLOW}immediate_assignment_catcher.py${NC} - Show SDCCH / IA / channel assignments"
  echo "Listens to GSMTAP (run livemon first). Useful for seeing channel allocations."
  echo ""
  echo "Port / Interface selection (where to listen for GSMTAP packets):"
  echo "  1) Default (port 4729 on lo) - Standard for grgsm_livemon"
  echo "  2) Custom port and/or interface"
  read -rp "Choice [1-2, default 1]: " ia_choice; ia_choice=${ia_choice:-1}
  if [ "$ia_choice" = "2" ]; then
    read -rp "Port (default 4729): " port; port=${port:-4729}
    read -rp "Iface (default lo): " iface; iface=${iface:-lo}
  else
    port=4729
    iface=lo
  fi
  local cmd="python3 $IMMEDIATE -p $port -i $iface"
  echo -e "\n${GREEN}Running: $cmd${NC}\n"
  eval "$cmd" || true
  pause
}

function run_scan_and_livemon() {
  if ! ensure_grgsm; then
    return
  fi

  echo -e "${YELLOW}scan-and-livemon${NC} (auto: scan bases + start N livemon_headless on different ports)"
  echo "Note: README marks this 'no longer used' but it still works for multi-receiver."
  echo "After it runs, start the catcher (it may need port adjustment or multiple catchers)."
  echo ""
  echo "Number of receivers (how many livemon_headless instances to start in parallel):"
  echo "  1) 1 receiver (default) - Scan and listen on one frequency/band"
  echo "  2) 2 receivers - Cover two frequencies/bands at once (better coverage if you have multiple SDRs or the script handles it)"
  echo "  3) 3 receivers - Even more parallel monitoring"
  echo "  4) Custom number"
  read -rp "Choice [1-4, default 1]: " recv_choice; recv_choice=${recv_choice:-1}
  case "$recv_choice" in
    1) n=1 ;;
    2) n=2 ;;
    3) n=3 ;;
    4) read -rp "Number of receivers (default 1): " n; n=${n:-1} ;;
    *) n=1 ;;
  esac
  local cmd="python3 $SCAN_LIVEMON -n $n"
  echo -e "\n${GREEN}Running: $cmd${NC}"
  echo -e "${CYAN}This will start livemon_headless processes. Use Ctrl-C to stop all.${NC}\n"
  eval "$cmd" || true
  pause
}

function run_wireshark() {
  echo -e "${YELLOW}Wireshark GSMTAP${NC}"
  local cmd="wireshark -k -Y 'gsmtap' -i lo"
  echo "Command: $cmd"
  echo -e "${RED}May require sudo or wireshark group for capture.${NC}"
  echo ""
  echo "Launch Wireshark for live GSMTAP capture (to inspect raw packets alongside the catcher):"
  echo "  1) Yes - Launch now (opens GUI, filter is already set for gsmtap)"
  echo "  2) No (default)"
  read -rp "Choice [1-2, default 2]: " ws_choice; ws_choice=${ws_choice:-2}
  if [ "$ws_choice" = "1" ]; then
    if command -v sudo >/dev/null && [ "$EUID" -ne 0 ]; then
      sudo_run $cmd &
    else
      $cmd &
    fi
    sleep 1
  fi
  pause
}

function setup_mysql() {
  echo -e "${YELLOW}MySQL logging setup for IMSI catcher${NC}"
  cd "$IMSI_DIR"
  if [ ! -f .env ]; then
    cp -v .env.dist .env
  fi
  echo ""
  echo "Current .env:"
  cat .env
  echo ""
  echo "MySQL .env setup (for advanced logging in the catcher):"
  echo "  1) Yes - Edit .env now (fill MYSQL_HOST, USER, PASSWORD, DB) using ${EDITOR:-nano}"
  echo "  2) No (default) - Skip for now (you can edit the file manually later)"
  read -rp "Choice [1-2, default 2]: " ed_choice; ed_choice=${ed_choice:-2}
  if [ "$ed_choice" = "1" ]; then
    ${EDITOR:-nano} .env
  fi
  echo ""
  echo "Installing python MySQL/ decouple deps..."
  sudo_run apt install -y python3-decouple python3-mysqldb || pip3 install --user python-decouple mysqlclient || true
  echo ""
  echo -e "${GREEN}Setup done. Use option 4 (Run simple_IMSI-catcher) and choose MySQL logging, or run manually with -z${NC}"
  echo "Make sure your DB exists (use db-example.sql as template)."
  pause
}

function update_mcc() {
  echo -e "${YELLOW}Update MCC/MNC database from Wikipedia${NC}"
  cd "$IMSI_DIR"
  sudo_run apt install -y python3-bs4 || pip3 install --user beautifulsoup4 || true
  python3 mcc-mnc/update_codes.py || echo "Update may have failed (check internet, bs4 installed)"
  echo "mcc_codes.json updated (if successful)."
  pause
}

function launch_grgsm() {
  echo -e "${CYAN}Launching GR-GSM Tools menu...${NC}"
  if [ -x "$HOME/bin/grgsm-menu.sh" ]; then
    "$HOME/bin/grgsm-menu.sh"
  else
    echo "GR-GSM menu not found. Use HackRF Tools (option 9) or run ~/install-gr-gsm.sh"
  fi
  clear
}

function launch_hackrf() {
  echo -e "${CYAN}Launching HackRF Tools menu...${NC}"
  if [ -x "$HOME/bin/hackrf-menu.sh" ]; then
    "$HOME/bin/hackrf-menu.sh"
  else
    echo "HackRF menu not found at ~/bin/hackrf-menu.sh"
  fi
  clear
}

function install_all() {
  echo -e "${YELLOW}Running IMSI-Catcher installer...${NC}"
  if [ -x "$HOME/install-imsi-catcher.sh" ]; then
    bash "$HOME/install-imsi-catcher.sh" || true
  else
    echo "Installer not found. Re-create it or run the deps manually:"
    echo "  sudo apt install -y python3-numpy python3-scipy python3-scapy gr-gsm ..."
  fi
  pause
}

function show_help() {
  echo -e "${BLUE}IMSI-Catcher Help & Workflow${NC}"
  cat << 'EOF'

Legal / Warning
- This tool decodes IMSI/TMSI from GSM. Only use on networks you own or have explicit written authorization for.
- In many countries passive monitoring of cellular is regulated or illegal without permission.
- The original author: "This program was made to understand how GSM network work. Not for bad hacking !"

Recommended workflow (with your HackRF + existing tools):
1. (Recommended) Just pick option 1 "QUICK START" below - it does the common HackRF+GSM900 case with almost no input (scanner runs with defaults + faster speed; you can Ctrl-C early if you see good cells).
2. Use HackRF Tools menu (option 9) for kalibrate-hackrf to get better PPM if the default 0 doesn't work well.
3. Use detailed options 2/3 (scanner/livemon) with the named presets if you want to choose specific bands/freqs.
4. Run the catcher (this menu option 4): guided with numbered options and explanations (sniff vs listen, logging types, specific IMSI, etc.). Just follow the prompts - no need to remember flags.

Other:
- All prompts in the menu (scanner bands, livemon frequencies, catcher options, etc.) now use numbered selections with definitions/explanations so you know exactly what you're choosing.
- immediate_assignment_catcher.py : watch channel assignments / SDCCH.
- scan-and-livemon : experimental multi freq (starts livemon_headless instances) - also has receiver count presets.
- Wireshark: sudo wireshark -k -Y gsmtap -i lo (guided launch).
- MySQL logging: see option 13 in this menu (guided .env setup).
- Update MCC/MNC names: option 14.

Cross menus:
- This menu has direct links to GR-GSM and HackRF menus (great for kalibrate + scanner + livemon).

See also the project README in ~/imsi-catcher/README.md

EOF
  pause
}

function quick_start() {
  if ! ensure_grgsm; then
    return
  fi

  echo -e "${GREEN}=== QUICK START (idiot-proof mode) ===${NC}"
  echo ""
  echo "This will do the whole thing with almost no typing (just select 1 and watch):"
  echo "  - Scan for cells on the most common band (GSM900) using your HackRF (PPM=0, faster speed)"
  echo "  - Start the livemon GUI on a common frequency (925.2M)"
  echo "  - Automatically open a NEW terminal with the catcher running and logging"
  echo ""
  echo "You can Ctrl-C the scanner early if you see good cells. Stop with Ctrl-C in the terminals when done."
  echo ""

  # Step 1: Scanner - max defaults for idiots (hardcoded for common HackRF + GSM900 case)
  echo -e "${YELLOW}--- Step 1: Scanning for GSM cells (GSM900 with HackRF) ---${NC}"
  local ppm=0
  local scan_cmd="grgsm_scanner -b GSM900 -g 24 -p $ppm --args hackrf --speed 25"
  echo "Running scanner: $scan_cmd"
  echo "(Faster scan with --speed 25. This can still take 1-3 min for full band. Watch for cells with high 'Pwr'. You can Ctrl-C after 30-60s once you see good cells; we'll use default freq anyway. Using PPM=0; run kalibrate from HackRF menu (option 9) if needed for better results later.)"
  eval "$scan_cmd" || true
  echo ""
  echo -e "${CYAN}Scanner phase done (or interrupted). Using common freq 925.2M for livemon (most common GSM900). If no luck, note a strong freq from the output above and use detailed livemon (option 3) with it, or run kalibrate from HackRF menu (option 9) first for PPM correction.${NC}"
  echo ""

  # Step 2: Livemon - hardcoded common freq
  local fc=925.2M
  echo -e "${YELLOW}--- Step 2: Starting livemon GUI on $fc ---${NC}"
  local livemon_cmd="grgsm_livemon -f $fc -g 32 -p $ppm --args hackrf"
  echo "Launching: $livemon_cmd &"
  eval "$livemon_cmd" &
  sleep 3
  echo -e "${CYAN}Livemon GUI should now be open (shows spectrum).${NC}"
  echo ""

  # Step 3: Auto catcher terminal - always, with good defaults
  echo -e "${YELLOW}--- Step 3: Opening catcher in new terminal (auto) ---${NC}"
  local ts=$(date +%Y%m%d_%H%M%S)
  local catcher_cmd="cd $IMSI_DIR && python3 simple_IMSI-catcher.py -w /tmp/imsi_${ts}.db"
  launch_in_new_terminal "IMSI-Catcher (auto from Quick Start) - watch for IMSIs" "$catcher_cmd"
  echo ""
  echo -e "${GREEN}=== All set! ===${NC}"
  echo "- Livemon GUI: watch the signal"
  echo "- New terminal: watch IMSIs print live + logged to /tmp/imsi_${ts}.db"
  echo ""
  echo "If nothing shows: re-run scanner (option 2) and note a different strong freq, then use detailed livemon (option 3) with it, or run kalibrate from HackRF menu (option 9) first for PPM correction."
  echo "Exit this with 0 when done."
  pause
}

function main_menu() {
  clear
  while true; do
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}   IMSI-Catcher Menu (GSM IMSI tracker)${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo ""
    echo "  1)  QUICK START (recommended for idiots) - Scan (GSM900 HackRF, fast) + livemon (925.2M) + auto catcher terminal (almost no input; Ctrl-C scanner early OK)"
    echo "  2)  grgsm_scanner            - Find GSM cells / frequencies (named presets for HackRF/RTL etc.)"
    echo "  3)  grgsm_livemon            - Start live GUI + GSMTAP feed (required for catcher)"
    echo "  4)  Run simple_IMSI-catcher  - Main IMSI tracker (guided choices with explanations)"
    echo "  5)  Run immediate_assignment_catcher - Watch SDCCH/IA assignments (guided)"
    echo "  6)  run scan-and-livemon     - Auto scan + start multiple livemon_headless (guided)"
    echo ""
    echo "  7)  Start Wireshark GSMTAP"
    echo "  8)  Launch GR-GSM Tools menu (more scanner/livemon/capture options)  [also has gr-gsm installer]"
    echo "  9)  Launch HackRF Tools menu (kalibrate for PPM, transfer, etc.)"
    echo ""
    echo " 10)  Check tools & deps"
    echo " 11)  Help / Workflow / Legal"
    echo " 12)  Install / Update IMSI-Catcher + deps"
    echo " 13)  Setup MySQL logging (.env + deps)"
    echo " 14)  Update MCC/MNC database (fresh operator names)"
    echo ""
    echo "  0)  Exit"
    echo ""
    read -rp "Select number [0-14]: " choice
    echo ""

    case "$choice" in
      1)  quick_start ;;
      2)  run_grgsm_scanner ;;
      3)  run_grgsm_livemon ;;
      4)  run_catcher ;;
      5)  run_immediate_assignment ;;
      6)  run_scan_and_livemon ;;
      7)  run_wireshark ;;
      8)  launch_grgsm ;;
      9)  launch_hackrf ;;
      10) check_tools ;;
      11) show_help ;;
      12) install_all ;;
      13) setup_mysql ;;
      14) update_mcc ;;
      0)  echo "Goodbye! (Remember legal use only)"; exit 0 ;;
      *)  echo "Invalid selection."; sleep 1; clear ;;
    esac
  done
}

# Entry
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: $0"
  echo "Interactive menu for IMSI-Catcher (oros42)."
  exit 0
fi

# Ensure we are good
if [ ! -d "$IMSI_DIR" ] || [ ! -f "$CATCHER" ]; then
  echo -e "${RED}IMSI-Catcher source not found at $IMSI_DIR${NC}"
  echo "Please run the installer first:"
  echo "  ~/install-imsi-catcher.sh"
  pause
  exit 1
fi

# Pre-authenticate once (helps with cached ticket for any remaining direct sudo calls).
echo "$SUDO_PASS" | sudo -S -v 2>/dev/null || true

main_menu
