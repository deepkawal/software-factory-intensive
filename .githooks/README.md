# Git hooks

Repo-local hooks that run the non-LLM test harnesses before a commit lands.

## Enable (once per clone)

```bash
git config core.hooksPath .githooks
```

That's it. No Python `pre-commit` tool, no `npm install`, no framework. Just bash + git.

## What runs

The `pre-commit` hook inspects `git diff --cached --name-only` and runs only the harnesses whose scope could be affected by the staged files:

| Harness | Runs when any of these are staged |
|---|---|
| `test-harness/migration-check.sh` | `packs/**`, `activites/*/*/gascity/step_0/packs/**`, `test-harness/**`, `.githooks/**` |
| `test-harness/behavioral-smoke.sh` | above, plus `my-factory/*.template`, `my-factory/.gitignore` |
| `test-harness/tutorial-check.sh` | above, plus `my-factory/README.md`, `activites/{workshops/W2,labs/L2}/README.md`, `installation.md` |

A commit touching only `curriculum/**` markdown or `plans/**` skips the harnesses entirely. A commit touching `packs/architect/pack.toml` runs all three (~3-5 min).

## What does NOT run pre-commit

`test-harness/tutorial-walkthrough.sh` — that harness requires live Claude authentication and burns real tokens. Run it manually before release cuts:

```bash
bash test-harness/tutorial-walkthrough.sh my-factory
```

See [`test-harness/README.md`](../test-harness/README.md) for the full testing story.

## Bypass

Standard git escape hatch:

```bash
git commit --no-verify
```

Use sparingly. If a harness is flaking repeatedly, fix the harness rather than routinely bypassing.

## Disable

```bash
git config --unset core.hooksPath
```
