#!/usr/bin/env python3
"""Claude Code の PreToolUse(Bash) フック。

git hooks（.githooks/）で守っているブランチルールを、AI が迂回・違反しないようにする。
  - --no-verify による git hooks の迂回
  - core.hooksPath の変更による git hooks の無効化
  - stage / main への直接 push（git hooks が未導入でも止める）
"""

import json
import os
import re
import shlex
import subprocess
import sys

PROTECTED = {"stage", "main"}
HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_]\w*)\1[^\n]*\n(?:.*?\n)?[ \t]*\2[ \t]*(?=\n|$)", re.S)
REDIRECT = re.compile(r"^\d*[<>]")
GIT = re.compile(r"^\s*(?:\w+=\S*\s+)*git\b")
GIT_PUSH = re.compile(r"^\s*(?:\w+=\S*\s+)*git((?:\s+-[Cc]\s+\S+)*)\s+push\b(.*)$", re.S)
PUSH_OPTS_WITH_VALUE = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}


def deny(message: str) -> None:
    print(f"✋ {message}", file=sys.stderr)
    sys.exit(2)


def tokens(text: str) -> list:
    try:
        return shlex.split(text)
    except ValueError:
        return text.split()


def split_commands(command: str) -> list:
    """ヒアドキュメントの本文を除き、引用符の外にある ; & | 改行 でコマンドを分ける。"""
    command = HEREDOC.sub(lambda m: m.group(0).split("\n", 1)[0] + "\n", command)
    segments, buf, quote, depth, i = [], [], None, 0, 0
    while i < len(command):
        c = command[i]
        if c == "\\" and quote != "'":
            buf.append(command[i : i + 2])
            i += 2
            continue
        if quote == "'":
            quote = None if c == "'" else quote
        elif quote == '"':
            if command.startswith("$(", i):
                depth += 1
            elif c == ")" and depth:
                depth -= 1
            elif c == '"' and not depth:
                quote = None
        elif c in "'\"":
            quote = c
        elif c in ";|\n" or (c == "&" and not (buf and buf[-1] in "<>")):
            segments.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(c)
        i += 1
    segments.append("".join(buf))
    return segments


def current_branch(cwd: str) -> str:
    result = subprocess.run(
        ["git", "-C", cwd, "symbolic-ref", "--short", "-q", "HEAD"],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def push_targets(args: list, cwd: str) -> list:
    """git push の引数から、更新・削除されるリモートのブランチ名を返す。"""
    positional, skip = [], False
    for arg in args:
        if skip:
            skip = False
        elif arg in PUSH_OPTS_WITH_VALUE or REDIRECT.fullmatch(arg):
            skip = True  # 値を取るオプション、またはファイル名が続くリダイレクト
        elif not arg.startswith("-") and not REDIRECT.match(arg):
            positional.append(arg)

    refspecs = positional[1:]
    if not refspecs:
        return [] if "--tags" in args else [current_branch(cwd)]

    targets = []
    for spec in refspecs:
        spec = spec.lstrip("+")
        src, _, dst = spec.partition(":")
        dst = dst or src
        if dst == "HEAD":
            dst = current_branch(cwd)
        targets.append(dst.removeprefix("refs/heads/"))
    return targets


def main() -> None:
    payload = json.load(sys.stdin)
    command = payload.get("tool_input", {}).get("command", "")
    cwd = payload.get("cwd") or os.getcwd()

    for segment in split_commands(command):
        if not GIT.match(segment):
            continue
        words = tokens(segment)
        if "--no-verify" in words:
            deny("--no-verify は使えません。ブランチルールは git hooks で守っています。")
        if re.search(r"hookspath", segment, re.I) and "--get" not in words:
            deny("core.hooksPath は変更できません。ブランチルールは git hooks で守っています。")

        push = GIT_PUSH.match(segment)
        if not push:
            continue
        repo_dir = cwd
        opts = tokens(push.group(1))
        for i, opt in enumerate(opts[:-1]):
            if opt == "-C":
                repo_dir = os.path.join(repo_dir, opts[i + 1])
        for branch in push_targets(tokens(push.group(2)), repo_dir):
            if branch in PROTECTED:
                deny(f"{branch} への直接 push は禁止されています。作業ブランチから PR を作ってください。")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:  # フック自体の不具合でツール実行を止めない
        print(f"guard_git.py: {e}", file=sys.stderr)
        sys.exit(1)
