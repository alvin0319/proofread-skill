#!/usr/bin/env bash
set -euo pipefail

skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

instruction_files() {
  {
    echo "$HOME/.claude/CLAUDE.md"
    for path in "${paths[@]}"; do
      dir=$(dirname "$(realpath -- "$path")")
      while :; do
        for name in CLAUDE.md .claude/CLAUDE.md CLAUDE.local.md AGENTS.md AGENT.md; do
          echo "$dir/$name"
        done
        [ "$dir" != / ] || break
        dir=$(dirname "$dir")
      done
    done
  } | while read -r file; do
    if [ -f "$file" ]; then realpath -- "$file"; fi
  done | sort -u
}

build_message() {
  cat "$skill_dir/prompt.md"
  for file in "${instructions[@]}"; do
    printf '\n<instructions path="%s">\n' "$file"
    cat -- "$file"
    printf '\n</instructions>\n'
  done
  if [ -n "$context" ]; then
    printf '\n<context>\n%s\n</context>\n' "$context"
  fi
  printf '\n<scope>\n%s</scope>\n' "$scope"
  for path in "${paths[@]}"; do
    printf '\n=== FILE: %s\n' "$path"
    cat -n -- "$path"
  done
}

usage() {
  echo "usage: run.sh [--timeout <duration>] [--context <text>] <path>[:<ranges>] ..." >&2
  exit 2
}

timeout=9m
context=
while [ $# -gt 0 ]; do
  case $1 in
    --timeout) [ $# -ge 2 ] || usage; timeout=$2; shift 2 ;;
    --context) [ $# -ge 2 ] || usage; context=$2; shift 2 ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || usage

paths=()
scope=
for arg in "$@"; do
  path=$arg
  ranges=all
  if [[ $arg =~ ^(.+):([0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*)$ ]]; then
    path=${BASH_REMATCH[1]}
    ranges=${BASH_REMATCH[2]}
  fi
  if [ ! -f "$path" ]; then
    echo "run.sh: not a file: $path" >&2
    exit 2
  fi
  paths+=("$path")
  scope+="$path: $ranges"$'\n'
done
printf 'run.sh: scope\n%s' "$scope" >&2

mapfile -t instructions < <(instruction_files)
if [ ${#instructions[@]} -gt 0 ]; then
  printf 'run.sh: instructions\n' >&2
  printf '%s\n' "${instructions[@]}" >&2
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

before=$(sha256sum -- "${paths[@]}")
events=$(build_message \
  | jq -Rsc '{event: "user", message: {content: .}}' \
  | (cd "$workdir" && agy --input-format stream-json --output-format stream-json \
      --json-schema "$skill_dir/schema.json" --disable-slash-commands --print-timeout "$timeout"))
if [ "$(sha256sum -- "${paths[@]}")" != "$before" ]; then
  echo "run.sh: agy changed a scope file" >&2
  exit 1
fi

tools=$(jq -r 'select(.event == "step_update") | .step_update.tool_name // empty | select(. != "finish")' <<<"$events" | sort -u | paste -sd ' ')
[ -z "$tools" ] || echo "run.sh: agy used tools: $tools" >&2

result=$(jq -c 'select(.event == "result") | .result' <<<"$events")
if [ "$(jq -r '.status' <<<"$result")" != SUCCESS ] || [ "$(jq '.structured_output == null' <<<"$result")" != false ]; then
  echo "run.sh: agy returned no result" >&2
  jq -c '{status, error, denied_actions}' <<<"$result" >&2
  exit 1
fi
jq '.structured_output' <<<"$result"
