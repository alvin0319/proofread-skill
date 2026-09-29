---
name: proofread
description: Proofreads the text in a range the user specifies (files, directories, or line ranges) with Google Antigravity CLI (agy), as the last step of a task. agy only proposes changes; Claude applies the fixes with Edit and reports optional findings for the user to decide on. In code, only the text inside string literals changes. Use only when the user explicitly asks for it (/proofread, this skill by name, or proofreading with agy). Do not use it on your own initiative or for a general spelling request that does not ask for it. Run it after all other requested work is finished.
argument-hint: "<path[:lines]> ... [context]"
---

# Proofread with agy

agy (Google Antigravity CLI) proofreads the text in the range the user specifies. It does not edit files: `run.sh` sends it the files over stdin from an empty temporary directory, checks that the files did not change, and prints its suggestions and findings as JSON. You check them, apply the suggestions that pass with Edit, and report the findings for the user to decide on.

Arguments: $ARGUMENTS

## When to run

Run this only when the user explicitly asked for it: `/proofread`, this skill by name, or proofreading with agy. Never start it on your own.

Proofreading is the last step. Finish everything else in the user's request first, including any work the arguments ask for besides proofreading. Never proofread between steps.

## 1. Take the range

- Proofread exactly the range the user gave: files, directories, or line ranges such as `docs/guide.md:10-40`. Expand directories to the text files inside them, leaving out binary, lock, and generated files.
- If the user gave no range, ask for one. Do not pick a range yourself.
- Words in the request that describe the text instead of naming a path, such as its purpose, its readers, or names that are spelled as intended, are context for agy.

## 2. Run agy

```bash
bash "${CLAUDE_SKILL_DIR}/run.sh" --context "Setup guide for new server owners. NetherNet is a product name." docs/guide.md:10-40 src/messages.ts
```

A bare path covers the whole file, and `path:12-30,41` covers only those lines.

`--context <text>` before the paths is optional background for agy. Pass the user's context as they wrote it. If they gave none, write one or two sentences of facts you know from the task: what the text is for, who reads it, and names or terms the task introduced. State facts only, never what agy should flag or skip, because agy is there to give a second opinion. If you know nothing beyond the files, leave `--context` out.

`--timeout <duration>` before the paths is optional and sets agy's time limit as a Go duration such as `90s` or `15m`. The default is `9m`; use a longer one for a large range. A foreground Bash call cannot wait more than 10 minutes, so give it a 600000 ms timeout, and use `run_in_background` when the limit is over `9m`.

The script prints the scope it used on stderr. It also sends agy the user's instruction files so the corrections follow their text rules: `~/.claude/CLAUDE.md`, plus every `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, and `AGENT.md` in the directories above the proofread files. stderr lists those files as well.

On success it prints `{"suggestions": [...], "findings": [...]}` on stdout. Suggestions are errors to fix; findings are optional changes that are safe in context but not needed. Each item has `file`, `line`, `original` (the exact text to replace on that line), `corrected`, and `reason`.

The script exits non-zero with the reason on stderr when agy fails, returns no result, or changes a proofread file. Report the error and stop; do not proofread the text yourself instead. The one exception is a run that hit the time limit (agy prints `print timeout after <duration>` on stderr): rerun with a longer `--timeout`, or split the range into smaller runs.

If stderr says agy used tools, include that in the report.

## 3. Check each suggestion

Read the stated line of every suggestion and finding. An item passes only when all of these hold:

- The line is in the range, and `original` appears on it verbatim.
- In code, `original` is the text inside a human-facing string literal, not a comment, docstring, identifier, or other code. Keys, IDs, enum or protocol values, event names, URLs, paths, SQL, regexes, and strings that the code compares or looks up stay as they are.
- In prose, `original` is outside code blocks, inline code, URLs, and front matter, and `corrected` keeps the Markdown syntax and link targets.
- `corrected` keeps every placeholder, format specifier, escape sequence, and markup tag of `original` (`{name}`, `{{count}}`, `%d`, `${expr}`, `\n`, `\"`, `<b>`), plus its leading and trailing whitespace.
- In code, `corrected` is valid between the same delimiters: an added quote character that matches them is escaped.
- `corrected` is in the same language and breaks none of the text rules in the instruction files, such as a banned character or term.
- Every other copy of `original` in the project gets the same change from another item in the same list. Grep for it; a copy without one, such as a test that asserts the message or another locale file, fails the item.

Suggestions that fail are skipped and reported. Findings that fail are dropped.

## 4. Apply

Apply each passing suggestion with Edit, one at a time. Never apply a finding. Use enough of the line as `old_string` to make it unique, and change nothing outside `original`. Then run `git diff` on the touched files (or re-read the lines outside git) and confirm every change is inside the range, and in code, inside a string literal.

## 5. Report

Report in two sections, so the user can see why each change was made.

**Suggestions**: the changes you applied.

| Location | Before | After | Reason |
| --- | --- | --- | --- |
| `docs/guide.md:3` | how to instal the tool | how to install the tool | spelling |

Below the table, list each skipped suggestion with why it was skipped.

**Findings**: optional changes that are safe in context but not needed. They are not applied; the user decides.

| Location | Current | Possible change | Reason |
| --- | --- | --- | --- |

Keep each reason to a few words, and quote only the changed part of a long line. If a section is empty, say so in one line. End with the instruction files agy received and the context you sent, if any.
