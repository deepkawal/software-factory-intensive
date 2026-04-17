# Software Factory Intensive — Workshop — W2

https://github.com/actual-software/software-factory-intensive

The W2 checkpoint is a self-contained v2 factory snapshot. It lives at
`activites/workshops/W2/gascity/step_0/packs/`. Use it to:

- Reset to a known-good state if you've broken your main `my-factory/` factory.
- Run the W2 walkthrough in isolation without touching your main factory's
  rigs/sessions.

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

### 2. Prepare a test rig (the "project" repo the factory operates on)

```bash
mkdir -p ~/Projects/factory/workshop_w2/w2-project
pushd ~/Projects/factory/workshop_w2/w2-project
git init
touch README.md && git add -A && git commit -m "initial"
```

### 3. Copy the W2 checkpoint's templates to runtime files

```bash
cd ~/Projects/actual-software/software-factory-intensive/activites/workshops/W2/gascity/step_0/packs
cp pack.toml.template pack.toml
cp city.toml.template city.toml
```

### 4. Register the W2 checkpoint factory and add the rig

```bash
# Use --name so the W2 city doesn't collide with your main my-factory/
gc register --name w2-step-0 .
gc rig add ~/Projects/factory/workshop_w2/w2-project
bd config set types.custom "convoy"
(cd ~/Projects/factory/workshop_w2/w2-project && bd config set types.custom "convoy")
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

### 6. Kick off a task to verify the factory

```bash
cd ~/Projects/factory/workshop_w2/w2-project
bd create --title "Create a script that prints hello world" --label needs-architecture
gc poke   # or wait for the 30s patrol tick
```

The architect wakes, picks up the bead, and hands off via `gc all
wake-downstream &`. Watch the dashboard as the bead flows through the agents.
