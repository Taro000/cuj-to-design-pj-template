#!/bin/sh
# テンプレート（cuj-to-design-pj-template）から作ったリポジトリを初期化する。
# clone したら一度実行する。何度実行してもよい。
#   1. git hooks を有効にする
#   2. ラベルを作る（既にあれば色と説明を揃える）。初期化の前なら GitHub の既定ラベルを消す
#   3. main が無ければ stage から作る。既定ブランチを stage にし、マージ済みブランチの自動削除を有効にする
#   4. ファイルにリポジトリ名を埋め、README を書き換えて、stage 向けの PR を作る（テンプレート自身では行わない）
# 必要なもの: git、gh（gh auth login 済み）
set -eu

die() {
  echo "✋ $*" >&2
  exit 1
}

root=$(git rev-parse --show-toplevel)
cd "$root"

command -v gh >/dev/null 2>&1 || die "gh が見つかりません。https://cli.github.com/ から入れてください。"
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner) ||
  die "GitHub のリポジトリを特定できません。gh auth login と origin を確認してください。"
name=${repo#*/}
is_template=$(gh repo view "$repo" --json isTemplate -q .isTemplate)
echo "対象: $repo"

# リポジトリ名を埋めるファイル。{{REPO}} は owner/name、{{REPO_NAME}} は name に置き換える
files="CLAUDE.md .claude/rules/ai-workflow.md .github/claude-routine-prompt.md"
branch=chore/init-from-template
title="chore: テンプレートから初期化する"

# 初期化の PR がマージされるまで、origin/stage にはプレースホルダーとテンプレートの README が残っている
# （テンプレート自身では常に残っている）
git fetch -q origin stage
needs_init=false
# shellcheck disable=SC2086
git grep -qF '{{REPO' origin/stage -- $files && needs_init=true
git show origin/stage:README.md | grep -q '^<!-- template-readme' && needs_init=true

echo "== git hooks"
sh scripts/setup-git-hooks.sh
echo "  有効にしました"

echo "== ラベル"
while IFS='|' read -r label color description; do
  gh label create "$label" --repo "$repo" --color "$color" --description "$description" --force </dev/null >/dev/null
  echo "  $label"
done <<'EOF'
feature|1D76DB|[種別] 機能への変更（feature/*）
chore|8B949E|[種別] 機能に影響のない変更（chore/*）
fix|D73A4A|[種別] 不具合の修正（fix/*）
hotfix|B60205|[種別] 本番の緊急修正（hotfix/* → main）
release|006B75|[種別] リリース（stage → main）
未着手|EDEDED|[状態] 未着手
要件定義|FEF2C0|[状態] 要件定義
設計|F9D0C4|[状態] 設計
実装|FBCA04|[状態] 実装
Stg|C2E0C6|[状態] 検証リリース済
Prd|0E8A16|[状態] 本番リリース済
AI's Turn|8250DF|[AI] AIが作業できる・している状態
Human's Turn|F97316|[AI] 人間が作業できる・している状態
S|C5DEF5|[サイズ] 200行未満の変更
M|6CA0DC|[サイズ] 200行以上の変更
L|1F4E9C|[サイズ] 500行以上の変更
EOF
# GitHub がリポジトリを作るときに付ける既定のラベル。種別ラベルと役割が重なるので消す。
# 後から自分で作ったラベルを消さないよう、初期化の前にだけ行う
if [ "$needs_init" = true ]; then
  existing=$(gh label list --repo "$repo" --limit 200 --json name -q '.[].name')
  for label in bug documentation duplicate enhancement "good first issue" "help wanted" invalid question wontfix accessibility; do
    if printf '%s\n' "$existing" | grep -qxF "$label"; then
      gh label delete "$label" --repo "$repo" --yes </dev/null >/dev/null
      echo "  $label を消しました（GitHub の既定ラベル）"
    fi
  done
fi

echo "== ブランチと設定"
stage_sha=$(gh api "repos/$repo/git/ref/heads/stage" -q .object.sha 2>/dev/null) ||
  die "origin に stage ブランチがありません。"
if gh api "repos/$repo/git/ref/heads/main" --silent 2>/dev/null; then
  echo "  main: あり"
else
  gh api "repos/$repo/git/refs" -f ref=refs/heads/main -f sha="$stage_sha" --silent
  echo "  main: stage から作りました"
fi
gh api -X PATCH "repos/$repo" -f default_branch=stage -F delete_branch_on_merge=true --silent
echo "  既定ブランチ: stage / マージ済みブランチの自動削除: 有効"

if [ "$is_template" = true ]; then
  echo "== ファイル: テンプレート自身なので初期化しません"
  exit 0
fi

if [ "$needs_init" = false ]; then
  echo "== ファイル: 初期化済み"
  exit 0
fi

echo "== ファイル"
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "コミットしていない変更があります。片付けてから実行してください。"
fi
if git show-ref --verify --quiet "refs/heads/$branch"; then
  git switch -q "$branch"
else
  git switch -q --no-track -c "$branch" origin/stage
fi

for f in $files; do
  sed -e "s|{{REPO_NAME}}|$name|g" -e "s|{{REPO}}|$repo|g" "$f" >"$f.tmp"
  mv "$f.tmp" "$f"
done
if grep -q '^<!-- template-readme' README.md; then
  description=$(gh repo view "$repo" --json description -q .description)
  echo "# $name" >README.md
  if [ -n "$description" ]; then
    printf '\n%s\n' "$description" >>README.md
  fi
fi

# shellcheck disable=SC2086
git add -- $files README.md
if git diff --cached --quiet; then
  echo "  変更なし（コミット済み）"
else
  git commit -q -m "$title"
  echo "  $branch にコミットしました"
fi
git push -q -u origin "$branch"

if url=$(gh pr view "$branch" --repo "$repo" --json url,state -q 'select(.state == "OPEN") | .url' 2>/dev/null) && [ -n "$url" ]; then
  echo "  PR: ${url}（作成済み）"
else
  body=$(mktemp)
  cat >"$body" <<'EOF'
### 概要

テンプレート（cuj-to-design-pj-template）から作ったリポジトリを初期化する。`scripts/init-from-template.sh` が作った PR。

Issue: なし

### 変更内容

- `CLAUDE.md`・`.claude/rules/ai-workflow.md`・`.github/claude-routine-prompt.md` にリポジトリ名を埋めた
- `README.md` をこのリポジトリ用に書き換えた

### 成果物

なし

### 不安・判断に迷った点

- なし

### 未確定事項

- なし
EOF
  url=$(gh pr create --repo "$repo" --base stage --head "$branch" --title "$title" --body-file "$body")
  rm -f "$body"
  echo "  PR: $url"
fi

cat <<EOF

次にやること:
  1. PR を「Create a merge commit」でマージする: $url
  2. git switch stage && git pull
  3. 必要なら、AI への依頼の経路を設定する
     - Slack: Claude Code in Slack を入れ、チャンネルで @Claude に依頼する（.claude/rules/ai-workflow.md）
     - Dependabot の PR を AI に回す: .github/claude-routine-prompt.md の手順で Routine と secrets を設定する
EOF
