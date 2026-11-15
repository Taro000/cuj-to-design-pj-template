# 保護ブランチ: 直接のコミットと push を禁止し、PR のマージでのみ更新する。
PROTECTED_BRANCHES="stage main"

is_protected() {
  for b in $PROTECTED_BRANCHES; do
    [ "$1" = "$b" ] && return 0
  done
  return 1
}
