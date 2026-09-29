# proofread-skill

## What it is

A Claude Code skill that proofreads text with Google Antigravity CLI (`agy`). When your task is done, you tell Claude which files or lines to check. agy reviews the text, and Claude applies the fixes. It works on Markdown and other prose, and on the human-facing strings in source code, in any language.

## How to use it

You need Claude Code, `agy` (signed in), `jq`, and Node.js. It is tested on Linux.

agy uses its default model for the proofreading. Gemini models are recommended.

```bash
npx skills add alvin0319/proofread-skill -g -a claude-code --copy
```

Or with pnpm:

```bash
pnpm dlx skills add alvin0319/proofread-skill -g -a claude-code --copy
```

`--copy` installs it for Claude Code only, outside the shared `~/.agents/skills` folder that other agents read.

At the end of a task, tell Claude what to proofread:

```
/proofread docs/guide.md
/proofread docs/guide.md:10-40 src/messages.ts
/proofread docs/guide.md Setup guide for new server owners, in British English.
```

Text after the paths is context for agy, such as who reads the text or which names are spelled as intended. Without it, Claude adds a short context from what it knows about the task.

Asking in words works too, as long as you name the skill or agy: "proofread docs/guide.md with agy". Without a range, Claude asks for one. If the same message asks for other work, Claude does that first and proofreads last.

## What happens when you run it

- agy reads only the range you gave. It never edits your files.
- Suggestions are errors: spelling, grammar, spacing, and punctuation. Claude checks each one and applies it.
- Findings are optional rewording, such as a clearer sentence or consistent terms. Claude lists them and leaves the choice to you.
- Code, identifiers, comments, code blocks, URLs, keys, and placeholders such as `{name}` never change. In source code, only the text inside strings does.
- Wording rules in your `CLAUDE.md` and `AGENTS.md` files apply too.
- If a fix would break a match elsewhere, such as a test that checks the message, Claude skips it and says why.

Claude ends with a report like this:

**Suggestions**

| Location | Before | After | Reason |
| --- | --- | --- | --- |
| `docs/notes.md:6` | uploads the the build | uploads the build | duplicate word |

**Findings**

| Location | Current | Possible change | Reason |
| --- | --- | --- | --- |
| `docs/notes.md:5` | log in to the CLI | sign in to the CLI | matches "Sign in" on line 4 |

## Privacy

The text you proofread and your `CLAUDE.md` and `AGENTS.md` files, including `~/.claude/CLAUDE.md`, are sent to Google through agy. agy also keeps each run in its local history under `~/.gemini/antigravity-cli/`.

## License

[CC0 1.0 Universal](LICENSE)
