# L1 · Build a Structured Development Loop

L1 turns a normal project into a project that a factory can work on. You are not running the multi-agent flow yet. You are creating the project context that later FormulaV2 lesson packs will read.

## Goal

By the end of L1, your project rig has:

- clear agent instructions
- a decision log
- a project manifest
- a registered Gas City city
- FormulaV2 enabled permanently

## 1. Create Project Instructions

In your project repo, create the instruction file your CLI agent uses:

```bash
cd /path/to/your-project
$EDITOR CLAUDE.md
```

If you use another agent that reads `AGENTS.md`, use that filename instead.

Include:

- project purpose
- tech stack
- build, test, lint, and format commands
- source layout
- coding standards
- review standards
- release criteria
- files or directories agents must not edit

## 2. Record Decisions

In this repo, create the L1 decision log:

```bash
cd /path/to/software-factory-intensive
mkdir -p activities/labs/L1
$EDITOR activities/labs/L1/DECISIONS.md
```

For every rule you add to the project instructions, write:

- date
- rule
- why it exists
- how to verify it later

## 3. Fill In The Project Manifest

Copy the template and fill in the sections the later factories need:

```bash
cp curriculum/PROJECT_MANIFEST_TEMPLATE.md my-factory/PROJECT_MANIFEST.md
$EDITOR my-factory/PROJECT_MANIFEST.md
```

Minimum sections:

- overview
- users
- tech stack
- project structure
- acceptance criteria style
- review standards
- release criteria

The Planner and Architect in L2 will use this file to ground their output.

## 4. Prepare The Gas City City

Create local runtime config:

```bash
cp my-factory/pack.toml.template my-factory/pack.toml
cp my-factory/city.toml.template my-factory/city.toml
```

Confirm `my-factory/city.toml` has FormulaV2 enabled:

```toml
[daemon]
formula_v2 = true
```

The default `my-factory/pack.toml` selects the first runnable lesson factory:

```toml
[defaults.rig.imports.factory]
source = "../packs/lessons/L2"
```

## 5. Register The City And Add The Rig

```bash
cd my-factory
gc register .
gc rig add /path/to/your-project
gc doctor --fix
gc status
```

This creates the project rig. Later labs keep using the same rig so artifacts accumulate naturally.

## 6. Sanity Check The Rig

From the project repo:

```bash
git status --short
```

Run the commands you wrote in the instruction file:

```bash
npm test
# or your project's equivalent
```

If a command fails, fix the command or document the correct one before moving on. Later agents will rely on these instructions.

## Exit Criteria

- [ ] `CLAUDE.md` or `AGENTS.md` exists in the project rig.
- [ ] `activities/labs/L1/DECISIONS.md` explains the instruction rules.
- [ ] `my-factory/PROJECT_MANIFEST.md` is filled in.
- [ ] `my-factory/city.toml` permanently enables FormulaV2.
- [ ] `my-factory/pack.toml` selects `../packs/lessons/L2` as `factory`.
- [ ] `gc status` shows your city and project rig.

## Next

In L2, you keep this same rig, sync it to the L2 factory pack, and sling one feature request to `factory.planner` on `mol-feature-intake`.
