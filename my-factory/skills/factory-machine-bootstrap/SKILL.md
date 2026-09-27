---
name: factory-machine-bootstrap
description: Bootstrap or audit a second Windows/WSL software-factory machine so it runs the same checked-in Gas City pack, Claude and Codex skills, and Beads/Dolt synchronization as the first machine. Use for new-machine setup, factory portability, dependency installation, shared Beads status, or configuration drift between factory hosts.
---

# Factory Machine Bootstrap

Build a fresh machine from repositories and remote state. Do not clone runtime
directories or credential stores from another host.

## Workflow

1. Read `references/windows-wsl.md` and `references/portable-state.md`.
2. Run `scripts/bootstrap-wsl-factory.sh check` first and report every missing
   prerequisite.
3. If WSL is absent, give the operator the Administrator PowerShell commands in
   the Windows reference and pause for the restart and Ubuntu account creation.
4. With operator approval, run `scripts/bootstrap-wsl-factory.sh install` from
   Ubuntu in WSL. It installs and pins the checked-in compatible toolchain.
   Pause for `sudo` and all browser/device authentication.
5. Clone both repositories with `gh repo clone`, never by copying an existing
   working directory.
6. Create a dedicated private Git repository for factory HQ Dolt state; do not
   reuse the course repository because its Dolt ref belongs to another tracker.
7. From the cloned `my-factory` directory, run
   `FACTORY_MACHINE_NAME=machine-b FACTORY_HQ_DOLT_REMOTE=<git+url> scripts/bootstrap-wsl-factory.sh configure`.
   Pass non-default repository locations through the documented environment
   variables. Review both Beads
   dry-run plans; only rerun with `FACTORY_ACCEPT_REMOTE_PLAN=yes` when both
   plans say they will recover existing remote history.
8. Satisfy the exact `bootstrap/toolchain.env` version gate. If the installer
   delivered newer versions, stop and either pin machine B or coordinate an
   upgrade of both hosts before opening the shared database.
9. On machine A, repair and publish both Dolt remotes using the audited commands
   in `references/portable-state.md`. Verify `refs/dolt/data` exists in both Git
   remotes before allowing machine B to continue.
   Configure `origin` from each repository's own Git remote; never invent a
   third-party database host.
10. Pull Beads state, compare a known issue on both hosts, then test the claim
   handshake in `references/portable-state.md`.
11. Keep machine B's rig suspended while running `gc lint`, `gc doctor`,
    `bd doctor`, and the skill's `verify` phase.
12. Run the bidirectional disposable-bead test, allocate a whole workflow lane
    to machine B, then explicitly resume its rig.
13. Report the human actions still required and the exact failed command for
    any blocked step.

## Safety rules

- Do not copy authentication files, API keys, `.env` files, raw agent sessions,
  caches, `.gc/`, `.beads/dolt/`, or `.beads/embeddeddolt/`.
- Do not use `.beads/issues.jsonl` or `bd import` for ordinary synchronization.
- Do not force-push either Git or Dolt during bootstrap.
- Keep repositories in the WSL Linux filesystem, not under `/mnt/c`, for normal
  filesystem semantics and performance.
- Stop before Windows administrator prompts, Linux `sudo`, and account sign-in;
  these require the operator.
- If a remote already contains Beads history, pull it. Never reinitialize or
  discard that history.
- Do not let one host migrate a shared Beads schema while the other host still
  runs an older client.

## Shared operating protocol

Every worker must use this sequence around a new assignment:

```bash
gc dolt pull
bd ready
bd show <id>
bd update <id> --claim
bd dolt commit -m "claim <id>"
gc dolt sync
```

Give each machine a stable, distinct `BEADS_ACTOR`. Do not let two controllers
consume the same unassigned ready queue. Allocate a whole top-level bead or
workflow lane, push that ownership, and only then resume the assigned rig.

Before closing work, pull again, resolve any ordinary Dolt merge, close the
bead, commit the Beads working set, and sync. The checked-in
`orders/beads-converge.toml` performs background convergence, but it does not
replace the immediate claim push that prevents duplicate work.

Use `bd remember` for durable knowledge needed by both machines. Treat local
Claude or Codex history as private machine state, not the factory database.
