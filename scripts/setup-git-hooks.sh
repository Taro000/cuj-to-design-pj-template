#!/bin/sh
# .githooks/ を git hooks として有効にする。clone したら一度実行する。
# Claude Code のセッションでは SessionStart フックが自動で実行する（.claude/settings.json）。
set -eu

root=$(git rev-parse --show-toplevel)
git -C "$root" config core.hooksPath .githooks
chmod +x "$root"/.githooks/pre-* "$root"/.githooks/post-* "$root"/.githooks/lib/prune-merged.sh
