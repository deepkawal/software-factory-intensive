# Software Factory Intensive — Lab — L2

https://github.com/actual-software/software-factory-intensive

The L2 checkpoint is a self-contained v2 factory snapshot with just the
architect and planner packs (the two agents L2 teaches). It lives at
`activites/labs/L2/gascity/step_0/packs/`. Use it to:

- Reset to a known-good state if you've broken your main `my-factory/` factory.
- Run the L2 lab in isolation without touching your main factory's rigs/sessions.

The checkpoint has its own `pack.toml.template` + `city.toml.template` — the
runtime copies (`pack.toml`, `city.toml`) are gitignored so `gc register --name`
and `gc rig add` can mutate them without dirtying the checkpoint snapshot.

## Setup

### 1. Clone the repo (if you haven't already)

```bash
mkdir -p ~/Projects/actual-software
pushd ~/Projects/actual-software
git clone git@github.com:actual-software/software-factory-intensive.git
```

### 2. Prepare a test rig

```bash
mkdir -p ~/Projects/factory/lab_l2/l2-project
pushd ~/Projects/factory/lab_l2/l2-project
git init
touch README.md && git add -A && git commit -m "initial"
```

### 3. Copy the L2 checkpoint's templates to runtime files

```bash
cd ~/Projects/actual-software/software-factory-intensive/activites/labs/L2/gascity/step_0/packs
cp pack.toml.template pack.toml
cp city.toml.template city.toml
```

### 4. Register the L2 checkpoint factory and add the rig

```bash
gc register --name l2-step-0 .
gc rig add ~/Projects/factory/lab_l2/l2-project
bd config set types.custom "convoy"
(cd ~/Projects/factory/lab_l2/l2-project && bd config set types.custom "convoy")
```

### 5. Start the factory

```bash
gc restart
gc status
gc dashboard serve     # http://localhost:8080
```

Expected `gc doctor` output includes the two documented deprecation warnings
(`v2-default-rig-import-format`, `v2-workspace-name`) — these are tracked
upstream and can be ignored. See `my-factory/README.md` for details.

### 6. Kick off a task

```bash
cd ~/Projects/factory/lab_l2/l2-project
bd create --title "Plan user profile feature" --label needs-architecture
gc poke
```

Architect wakes, produces a plan, hands off via `gc all wake-downstream` to the
planner. Watch the dashboard.
