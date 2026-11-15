# PR・Issue 本文のルール

`gh pr create --body` / `gh issue create --body`、GitHub MCP、API で PR・Issue を作ると、GitHub のテンプレートは適用されない。本文は自分でテンプレートに沿って書く。

- テンプレート
  - PR: `.github/pull_request_template.md`
  - Issue: `.github/ISSUE_TEMPLATE/task.md`（先頭の `---` で囲まれた front matter は本文に含めない）
- 作る前にテンプレートを読み、見出しをすべて同じ順番・同じ表記で残す。見出しを削除・並べ替え・言い換えしない。
- 書くことが無い見出しも消さず、「なし」と書く。
- PR の `Issue: close #0000` は対応する Issue の番号に置き換える。Issue が無ければ `Issue: なし` と書く。
- Issue の受け入れ条件はチェックリスト（`- [ ] `）で書く。
- テンプレートに無い追記（`🤖 Generated with ...` などの署名）は、最後の見出しの内容の後ろに置く。
- `gh` を使うときは、本文をファイルに書いて `--body-file` で渡す。`--body` に直接書くと、シェルのクォートやバッククォートで本文が崩れることがある。

  ```sh
  gh pr create --base stage --title "<種別>: <説明>" --body-file <本文のファイル>
  gh issue create --title "<説明>" --body-file <本文のファイル>
  ```

  クラウドセッションでは `gh pr` / `gh issue` が使えない（GraphQL がプロキシに拒否される）。`gh api` で作る（`ai-workflow.md`）。

- 本文を後から更新するとき（`gh pr edit` / `gh issue edit` など）も、この構成を保つ。
