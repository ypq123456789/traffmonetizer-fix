#!/usr/bin/env bash
set -euo pipefail

script="${1:-deploy_tm.sh}"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

grep -q 'DOWNLOAD_PATH=' "$script" \
    || fail "deploy script should download tm_cli to a temporary path before replacing the live binary"

grep -Eq 'curl .*\$\{?DOWNLOAD_PATH\}?' "$script" \
    || fail "curl should write to the temporary download path"

if grep -Eq 'curl .*-o[[:space:]]+\$?BIN_PATH' "$script"; then
    fail "curl must not write directly to BIN_PATH while the old binary may still be running"
fi

grep -q 'mv -f' "$script" \
    || fail "validated download should replace BIN_PATH with mv -f"

grep -q 'kill -KILL' "$script" \
    || fail "cleanup should escalate stubborn tm_cli processes before replacing the binary"

grep -Eq 'rc-service .*(\$\{SERVICE_NAME\}|\$SERVICE_NAME|"[$]SERVICE_NAME").* start' "$script" \
    || fail "OpenRC start failures should stop deployment instead of reporting success"

printf 'deploy_tm static checks passed\n'
