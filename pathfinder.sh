#!/bin/bash

# Version
VERSION="1.4"

# Colors
RED="\e[31m"
BLUE="\e[34m"
GREEN="\e[32m"
RESET="\e[0m"

# Defaults
FOLLOW="no"
HIDE_CODES=""
SUBNET=""
PORTS=""
KEYWORDS=""
THREADS=5
OUTPUT_FILE=""
WORDLIST_FILE=""
NMAP_TIMEOUT=""

# Version info
if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "pathfinder v$VERSION"
    exit 0
fi

# Help screen
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo -e "
\e[1mUsage:\e[0m
  ./pathfinder -s <subnet> -p <ports> -k <keywords> [options]

\e[1mRequired:\e[0m
  -s <subnet>           Subnet to scan (e.g. 192.168.1.0/24)
  -p <ports>            Comma-separated ports (e.g. 80,443,8080)
  -k <keywords>         Comma-separated paths to test (e.g. admin,login,test)
     OR
  -K <wordlist>         File with paths to test (one per line)

\e[1mOptional:\e[0m
  -t <threads>          Number of parallel threads (default: 5, max: 10)
  -o <file>             Save results to specified output file
  --hc <codes>          Hide specific HTTP status codes (e.g. 404,403)
  --follow              Follow redirects (30x) and show final destination
  --timeout <sec>       Set max timeout per host in seconds (for nmap)
  -v, --version         Show version information
  -h, --help            Show this help message

\e[1mExamples:\e[0m
  ./pathfinder -s 192.168.1.0/24 -p 80,443 -k admin,test
  ./pathfinder -s 10.0.0.0/24 -p 80 -K paths.txt --follow --hc 403,404 -o results.txt -t 10
  ./pathfinder -s 192.168.9.0/24 -p 80 --timeout 3 -k phpmyadmin
"
    exit 0
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s) SUBNET="$2"; shift 2 ;;
        -p) PORTS="$2"; shift 2 ;;
        -k) KEYWORDS="$2"; shift 2 ;;
        -K) WORDLIST_FILE="$2"; shift 2 ;;
        -t) THREADS="$2"; shift 2 ;;
        -o) OUTPUT_FILE="$2"; shift 2 ;;
        --hc) HIDE_CODES="$2"; shift 2 ;;
        --follow) FOLLOW="yes"; shift ;;
        --timeout) NMAP_TIMEOUT="$2"; shift 2 ;;
        *) echo -e "${RED}[!] Invalid argument: $1${RESET}"; exit 1 ;;
    esac
done

# Required check
if [[ -z "$SUBNET" || -z "$PORTS" || ( -z "$KEYWORDS" && -z "$WORDLIST_FILE" ) ]]; then
    echo -e "${RED}[!] Missing required arguments. Use -h for help.${RESET}"
    exit 1
fi

# Thread validation
if ! [[ "$THREADS" =~ ^[1-9]$|^10$ ]]; then
    echo -e "${RED}[!] Thread count must be between 1 and 10.${RESET}"
    exit 1
fi

IFS=',' read -ra PORT_ARRAY <<< "$PORTS"

# Build word list
WORD_ARRAY=()
if [[ -n "$KEYWORDS" ]]; then
    IFS=',' read -ra KWORDS <<< "$KEYWORDS"
    WORD_ARRAY+=("${KWORDS[@]}")
fi
if [[ -n "$WORDLIST_FILE" && -f "$WORDLIST_FILE" ]]; then
    while IFS= read -r line; do
        [[ -n "$line" ]] && WORD_ARRAY+=("$line")
    done < "$WORDLIST_FILE"
fi

declare -a TARGETS

# Nmap options
if [[ -n "$NMAP_TIMEOUT" ]]; then
    NMAP_OPTS="--host-timeout ${NMAP_TIMEOUT}s --max-retries 1 --max-rtt-timeout 300ms"
else
    NMAP_OPTS=""
fi

# Port scan
for PORT in "${PORT_ARRAY[@]}"; do
    echo "[*] Scanning subnet $SUBNET on port $PORT..."
    while read IP; do
        echo "[+] Open: $IP:$PORT"
        TARGETS+=("$IP:$PORT")
    done < <(nmap $NMAP_OPTS -p $PORT --open -oG - "$SUBNET" | awk '/Up$/{print $2}')
done

# Generate URLs
COMBOS=()
for TARGET in "${TARGETS[@]}"; do
    HOST=$(echo "$TARGET" | cut -d':' -f1)
    PORT=$(echo "$TARGET" | cut -d':' -f2)
    PROTO="http"
    [[ "$PORT" == "443" || "$PORT" == "8443" ]] && PROTO="https"

    for WORD in "${WORD_ARRAY[@]}"; do
        COMBOS+=("$PROTO://$HOST:$PORT/$WORD")
    done
done

# Fuzz function
fuzz_url() {
    local URL="$1"
    IFS=',' read -ra LOCAL_HC <<< "$HIDE_CODES"

    if [[ "$FOLLOW" == "yes" ]]; then
        OUTPUT=$(curl -k --max-time 10 -s -w "%{http_code} %{url_effective}" -o /dev/null -L "$URL")
        STATUS=$(echo "$OUTPUT" | cut -d' ' -f1)
        FINAL_URL=$(echo "$OUTPUT" | cut -d' ' -f2-)
        DISPLAY_URL="$FINAL_URL"
    else
        STATUS=$(curl -k --max-time 10 -s -o /dev/null -w "%{http_code}" "$URL")
        DISPLAY_URL="$URL"
    fi

    [[ "$STATUS" == "000" ]] && return

    for HC in "${LOCAL_HC[@]}"; do
        [[ "$STATUS" == "$HC" ]] && return
    done

    if [[ "$STATUS" =~ ^40 ]]; then COLOR=$RED
    elif [[ "$STATUS" =~ ^30 ]]; then COLOR=$BLUE
    elif [[ "$STATUS" =~ ^20 ]]; then COLOR=$GREEN
    else COLOR=$RESET
    fi

    OUTLINE="[+] $DISPLAY_URL -> $STATUS"
    echo -e "${COLOR}${OUTLINE}${RESET}"
    [[ -n "$OUTPUT_FILE" ]] && echo "$OUTLINE" >> "$OUTPUT_FILE"
}

# Export variables
export -f fuzz_url
export FOLLOW HIDE_CODES RED GREEN BLUE RESET OUTPUT_FILE

# Run in parallel
printf "%s\n" "${COMBOS[@]}" | xargs -n 1 -P "$THREADS" -I{} bash -c 'fuzz_url "$@"' _ {}
