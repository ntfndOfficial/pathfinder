# pathfinder 🔍

**A fast, multithreaded HTTP(S) path discovery tool for internal subnets.**  
Written in pure Bash with support for CIDR-based port scanning, keyword/wordlist fuzzing, status code filtering, redirect following, and output logging.

---

## ✨ Features

- 🔍 CIDR-based host discovery using `nmap`
- 🌐 HTTP/HTTPS support with automatic protocol inference
- 🧠 Keyword and wordlist-based path fuzzing
- 🎯 Filter HTTP status codes (e.g. hide 403, 404)
- 🔁 Optional redirect following with final URL resolution
- ⚡ Multithreaded requests for speed (configurable)
- 🛡️ Built-in `curl --max-time` for fault-tolerance

---

## 📦 Requirements

- `bash`
- `nmap`
- `curl`
- GNU `xargs`, `awk`, `cut`

---

## 🧰 Usage

```bash
  ./pathfinder -s <subnet> -p <ports> -k <keywords> [options]

Required:
  -s <subnet>           Subnet to scan (e.g. 192.168.1.0/24)
  -p <ports>            Comma-separated ports (e.g. 80,443,8080)
  -k <keywords>         Comma-separated paths to test (e.g. admin,login,test)
     OR
  -K <wordlist>         File with paths to test (one per line)

Optional:
  -t <threads>          Number of parallel threads (default: 5, max: 10)
  -o <file>             Save results to specified output file
  --hc <codes>          Hide specific HTTP status codes (e.g. 404,403)
  --follow              Follow redirects (30x) and show final destination
  --timeout <sec>       Set max timeout per host in seconds (for nmap)
  -v, --version         Show version information
  -h, --help            Show this help message

# Scan subnet with basic keywords
./pathfinder -s 192.168.1.0/24 -p 80,443 -k admin,login,test

# Use a wordlist instead of keywords
./pathfinder -s 192.168.1.0/24 -p 80 -K wordlist.txt

# Filter 403 and 404 responses, follow redirects, multithreaded
./pathfinder -s 192.168.1.0/24 -p 80 -k admin --hc 403,404 --follow -t 10

# Save results to file
./pathfinder -s 192.168.1.0/24 -p 443 -k login --follow -o results.txt
