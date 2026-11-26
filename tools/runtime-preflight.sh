#!/system/bin/sh
# Safe Android/Termux runtime preflight.
# Read-only: no installs, network requests, credential reads, or settings changes.

set -u

section() { printf '\n== %s ==\n' "$1"; }
value() {
  label="$1"; val="$2"
  [ -n "$val" ] || val="unavailable"
  printf '%s: %s\n' "$label" "$val"
}
prop() {
  key="$1"
  if command -v getprop >/dev/null 2>&1; then getprop "$key" 2>/dev/null | head -n 1; fi
}

section "Device"
value "Manufacturer" "$(prop ro.product.manufacturer)"
value "Model" "$(prop ro.product.model)"
value "Android release" "$(prop ro.build.version.release)"
value "Android SDK" "$(prop ro.build.version.sdk)"
value "Primary ABI" "$(prop ro.product.cpu.abi)"
value "Secondary ABI" "$(prop ro.product.cpu.abi2)"
value "Kernel" "$(uname -sr 2>/dev/null)"
value "Machine architecture" "$(uname -m 2>/dev/null)"

section "CPU"
if [ -r /proc/cpuinfo ]; then
  cores="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || true)"
  value "Logical CPU entries" "$cores"
  freqs="$(grep -m 8 'cpu MHz' /proc/cpuinfo 2>/dev/null | sed 's/^[[:space:]]*//' | tr '\n' ';')"
  value "Readable CPU frequencies" "$freqs"
else
  value "CPU info" "unavailable"
fi

section "Memory"
if [ -r /proc/meminfo ]; then
  grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo 2>/dev/null
else
  value "Memory info" "unavailable"
fi

section "Storage"
if command -v df >/dev/null 2>&1; then
  df -h "$HOME" 2>/dev/null | tail -n 1
  df -h /data 2>/dev/null | tail -n 1
else
  value "Disk usage" "df unavailable"
fi

section "Battery"
if command -v dumpsys >/dev/null 2>&1; then
  battery="$(dumpsys battery 2>/dev/null)"
  printf '%s\n' "$battery" | grep -E 'level:|status:|temperature:|powered:' | head -n 8
else
  value "Battery data" "dumpsys unavailable in this environment"
fi

section "Runtime utilities"
for cmd in termux-info proot python python3 node git curl openssl jq; do
  if command -v "$cmd" >/dev/null 2>&1; then
    path="$(command -v "$cmd" 2>/dev/null)"
    ver="present"
    case "$cmd" in
      python|python3) ver="$("$cmd" --version 2>&1 | head -n 1)" ;;
      node) ver="$(node --version 2>&1 | head -n 1)" ;;
      git) ver="$(git --version 2>&1 | head -n 1)" ;;
      curl) ver="$(curl --version 2>&1 | head -n 1)" ;;
      openssl) ver="$(openssl version 2>&1 | head -n 1)" ;;
      jq) ver="$(jq --version 2>&1 | head -n 1)" ;;
    esac
    printf '%s: %s (%s)\n' "$cmd" "$ver" "$path"
  else
    printf '%s: absent\n' "$cmd"
  fi
done

section "Privacy"
printf '%s\n' "This report does not intentionally collect serial numbers, IP addresses, account IDs, file listings, or credentials."
printf '%s\n' "Review the output before sharing it. Fields marked unavailable are not automatic failures."

section "End"
printf '%s\n' "Preflight complete. No packages were installed and no device settings were changed."
