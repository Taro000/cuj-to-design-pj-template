# {{REPO_NAME}}

## ブランチ

- `stage`: デフォルトブランチ（検証環境）。通常の作業はここから切り、PR の base も `stage`。
- `main`: 本番。`stage` → `main` の PR でリリースする。マージ方法は必ず「Create a merge commit」（squash すると `stage` と `main` の履歴が分岐する）。
- 作業ブランチ名は `<種別>/<説明>`。種別は `feature` / `chore` / `fix` / `hotfix`。
  - 種別ラベルはブランチ名から自動で付く（`.github/labeler.yml`）。`claude/` など他のプレフィックスは使わない。
  - `hotfix/*` だけは `main` から切り、`main` に向けて PR を出す。リリース後は `main` を `stage` に取り込む。
- `main` と `stage` へ直接コミット・push しない（force push・削除も含む）。更新は PR のマージだけ。

### ブランチルールの仕組み（GitHub の機能に依存しない）

- `.githooks/` の git hooks で守る。clone したら `sh scripts/setup-git-hooks.sh` を一度実行する（Claude Code のセッションでは SessionStart フックが自動で実行する）。
  - `pre-commit`: `stage` / `main` 上でのコミットを拒否する
  - `pre-push`: `stage` / `main` への push（作成・更新・削除・force push）を拒否する
  - `post-merge` / `post-checkout`: `stage` / `main` で pull したときや切り替えたときに、取り込み済みのブランチをローカルと origin から削除する（`SKIP_PRUNE_MERGED=1` で無効、手動実行は `.githooks/lib/prune-merged.sh`）
- Claude Code では `.claude/hooks/guard_git.py` が、`--no-verify`、`core.hooksPath` の変更、`stage` / `main` への push を止める。

## ラベル

- 種別: `feature` / `chore` / `fix` / `hotfix` / `release`（PR に 1 つだけ）
- サイズ: `S` / `M` / `L`（PR に CI が自動で付ける。追加と削除の合計が 200 行未満 / 200 行以上 / 500 行以上。lockfile は数えない）
- 状態: `未着手` → `要件定義` → `設計` → `実装` → `Stg`（検証リリース済）→ `Prd`（本番リリース済）
- 手番: `AI's Turn`（AI が作業できる・している）/ `Human's Turn`（人間が作業できる・している）。排他。
  - 目印であり、付けても AI は起動しない。AI への依頼は Slack から行う（下記）。
  - AI が作業を終えた、または人間の判断が必要になったら、`Human's Turn` を付けて、何をしたか・何を判断してほしいかをコメントする。

## AI への依頼

- Slack のチャンネルで `@Claude` にメンションして依頼する。Claude Code のクラウドセッションで作業が始まり、結果は依頼したメッセージのスレッドに返る。
- Dependabot の PR だけは、Routine が自動で AI に回す（`.github/workflows/claude-cloud.yml`、`.github/claude-routine-prompt.md`）。
- AI の作業手順は `.claude/rules/ai-workflow.md`。

## リリース

- `main` への push ごとに、JST の日付タグ `YYYY-MM-DD` と GitHub Release が作られる（同日 2 回目以降は `YYYY-MM-DD.2`）。
- リリースノートは種別ラベルごとに見出しが分かれる（`.github/release.yml`）。
