#!/usr/bin/env bash
# stage / main に取り込み済みのブランチを、ローカルと origin の両方から削除する。
# マージコミット・squash・rebase のどの方法で取り込まれても検出する。
# 判定できないものや、まだ 1 つもコミットしていないブランチは残す（消し過ぎない側に倒す）。
#
# 手動で実行する: .githooks/lib/prune-merged.sh
# 無効にする:     SKIP_PRUNE_MERGED=1
set -u

[ "${SKIP_PRUNE_MERGED:-}" = 1 ] && exit 0
[ "${CLAUDE_CODE_REMOTE:-}" = true ] && exit 0 # クラウドセッションでは行わない

. "$(dirname "$0")/protected.sh"
remote=origin

git remote get-url "$remote" >/dev/null 2>&1 || exit 0
if ! git fetch --prune --quiet "$remote"; then
  echo "prune-merged: $remote から fetch できなかったため、削除をスキップします。" >&2
  exit 0
fi

targets=""
for b in $PROTECTED_BRANCHES; do
  if git rev-parse -q --verify "refs/remotes/$remote/$b" >/dev/null; then
    targets="$targets refs/remotes/$remote/$b"
  fi
done
[ -n "$targets" ] || exit 0

# 保護ブランチの first-parent 上にあるコミット。ここを指すブランチは「まだ何もしていない」とみなす
first_parents=$(for t in $targets; do git rev-list --first-parent "$t"; done)

# $1 の変更がすべて $2 に入っていれば 0
merged_into() {
  local tip=$1 target=$2 out base tmp
  # マージコミットで取り込み済み
  git merge-base --is-ancestor "$tip" "$target" && return 0
  # rebase マージで取り込み済み（全コミットと同じパッチが target にある）
  out=$(git cherry "$target" "$tip")
  if [ -n "$out" ] && ! printf '%s\n' "$out" | grep -q '^+'; then
    return 0
  fi
  # squash マージで取り込み済み（ブランチ全体の差分と同じパッチが target にある）
  base=$(git merge-base "$target" "$tip") || return 1
  tmp=$(git commit-tree "$tip^{tree}" -p "$base" -m prune-merged) || return 1
  git cherry "$target" "$tmp" | grep -q '^-'
}

is_merged() {
  local tip=$1 t
  printf '%s\n' "$first_parents" | grep -qx "$tip" && return 1
  for t in $targets; do
    merged_into "$tip" "$t" && return 0
  done
  return 1
}

current=$(git symbolic-ref --short -q HEAD || true)

git for-each-ref --format='%(refname) %(objectname)' refs/heads | while read -r ref tip; do
  name=${ref#refs/heads/}
  is_protected "$name" && continue
  [ "$name" = "$current" ] && continue
  if is_merged "$tip"; then
    git branch -q -D "$name" && echo "🧹 取り込み済みのブランチ $name を削除しました"
  fi
done

git for-each-ref --format='%(refname) %(objectname)' "refs/remotes/$remote" | while read -r ref tip; do
  name=${ref#"refs/remotes/$remote/"}
  [ "$name" = HEAD ] && continue
  is_protected "$name" && continue
  if is_merged "$tip"; then
    git push -q "$remote" --delete "$name" && echo "🧹 取り込み済みのブランチ $remote/$name を削除しました"
  fi
done

exit 0
