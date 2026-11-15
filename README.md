<!-- template-readme: scripts/init-from-template.sh が、作ったリポジトリ用の README に置き換える -->
# cuj-to-design-pj-template

CUJ から品質要件（品質チェーン）と設計（設計チェーン）までを、Claude Code のスキルで進めるプロジェクトのテンプレート。

## 入っているもの

- `.claude/skills/`: スキル。取得元は `skills-lock.json`。
  - 品質チェーン: `cuj-to-quality-in-use` → `quality-in-use-to-functional-requirements` → `functional-requirements-to-product-quality` → `product-quality-to-slo`、要約ページの `quality-summary-html`
  - 設計チェーン: `requirements-to-architecture-drivers` → `architecture-drivers-to-architecture` → `architecture-to-technical-policy` → `architecture-to-high-level-design` → `high-level-design-to-detailed-design`、まとめて回す `design-chain`、レビューの `design-review`
  - `modern-web-guidance`
- ブランチ運用: `stage`（既定・検証）→ `main`（本番）。`.githooks/` と `.claude/hooks/guard_git.py` が、`stage` / `main` への直接のコミットと push を止める。
- `.github/`: PR・Issue のテンプレート、ブランチ名からの種別ラベルとサイズラベルの自動付与、日付タグでのリリース、Dependabot、Dependabot の PR を AI に回す Routine の起動
- AI の作業手順: `CLAUDE.md`、`.claude/rules/`
- 成果物の置き場 `docs/` は空で始まる。スキルが `docs/quality/` と `docs/design/` に書く。

## 使い方

1. GitHub で **Use this template** → **Create a new repository** を選ぶ。**Include all branches** はどちらでもよい（`main` が無ければ 2 で作る）。
2. clone して、初期化スクリプトを実行する。`gh auth login` を済ませておく。

   ```sh
   git clone https://github.com/<owner>/<repo>.git
   cd <repo>
   sh scripts/init-from-template.sh
   ```

   スクリプトは次のことをする。何度実行してもよい。
   - git hooks を有効にする
   - ラベルを作る（既にあれば色と説明を揃える）
   - `main` が無ければ `stage` から作り、既定ブランチを `stage` にし、マージ済みブランチの自動削除を有効にする
   - `CLAUDE.md`・`.claude/rules/ai-workflow.md`・`.github/claude-routine-prompt.md` にリポジトリ名を埋め、`README.md` を書き換えて、`chore/init-from-template` から `stage` 向けの PR を作る
3. その PR を **Create a merge commit** でマージする。
4. 必要なら、AI への依頼の経路を設定する。
   - Slack: Claude Code in Slack を入れ、チャンネルで `@Claude` に依頼する（`.claude/rules/ai-workflow.md`）。
   - Dependabot の PR を AI に回す: `.github/claude-routine-prompt.md` の手順で Routine を作り、Repository secrets を登録する。未設定の間、ワークフローは警告を出してスキップする。
5. パッケージマネージャーを導入したら、`.github/dependabot.yml` に ecosystem を足す。

## ライセンス

`modern-web-guidance` は GoogleChrome/modern-web-guidance のもので、Apache License 2.0 に従う（`THIRD_PARTY_NOTICES.md`）。
