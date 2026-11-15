# Issue のルール

- 大きなタスクはサブタスクに分割する。
  - 目安: 1 つの PR の変更量が `L`（追加と削除の合計が 500 行以上。lockfile は数えない）になりそうなら分割する。
  - サブタスクは GitHub の sub-issue として親 Issue に紐づける。

    ```sh
    gh api repos/{owner}/{repo}/issues/<親の番号>/sub_issues \
      -F sub_issue_id="$(gh api repos/{owner}/{repo}/issues/<子の番号> --jq .id)"
    ```
