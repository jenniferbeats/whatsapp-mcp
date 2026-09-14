#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/bin" "$TMP/root/whatsapp-bridge/bin" "$TMP/root/store"
touch "$TMP/root/store/session.db"
printf '#!/bin/sh\nexit 0\n' > "$TMP/root/whatsapp-bridge/bin/whatsapp-bridge"
chmod 755 "$TMP/root/whatsapp-bridge/bin/whatsapp-bridge"

cat > "$TMP/bin/uname" <<'EOF'
#!/bin/sh
echo Darwin
EOF
cat > "$TMP/bin/id" <<'EOF'
#!/bin/sh
echo 501
EOF
cat > "$TMP/bin/launchctl" <<'EOF'
#!/bin/sh
echo "$*" >> "$FAKE_LAUNCHCTL_LOG"
case "$1" in
  bootout)
    echo 2 > "$FAKE_COUNTDOWN"
    exit 0
    ;;
  print)
    if [ -f "$FAKE_COUNTDOWN" ]; then
      n="$(cat "$FAKE_COUNTDOWN")"
      if [ "$n" -gt 0 ]; then
        echo $((n - 1)) > "$FAKE_COUNTDOWN"
        exit 0
      fi
      rm -f "$FAKE_COUNTDOWN" "$FAKE_STATE"
    fi
    [ -f "$FAKE_STATE" ]
    ;;
  bootstrap)
    [ ! -f "$FAKE_STATE" ] || exit 5
    touch "$FAKE_STATE"
    ;;
  load|list)
    exit 9
    ;;
esac
EOF
chmod 755 "$TMP/bin/"*

export HOME="$TMP/home"
export PATH="$TMP/bin:/usr/bin:/bin"
export WHATSAPP_MCP_ROOT="$TMP/root"
export FAKE_LAUNCHCTL_LOG="$TMP/launchctl.log"
export FAKE_COUNTDOWN="$TMP/countdown"
export FAKE_STATE="$TMP/active"
touch "$FAKE_STATE"

"$HERE/install-bridge-autostart.sh" --install >/dev/null
[[ -f "$FAKE_STATE" ]]
grep -q '^print gui/501/co.myceliumai.whatsapp-mcp.bridge$' "$FAKE_LAUNCHCTL_LOG"
grep -q '^bootstrap gui/501 ' "$FAKE_LAUNCHCTL_LOG"
! grep -Eq '^(load|list) ' "$FAKE_LAUNCHCTL_LOG"

: > "$FAKE_LAUNCHCTL_LOG"
"$HERE/install-bridge-autostart.sh" --status >/dev/null
grep -q '^print gui/501/co.myceliumai.whatsapp-mcp.bridge$' "$FAKE_LAUNCHCTL_LOG"
! grep -Eq '^list ' "$FAKE_LAUNCHCTL_LOG"
