# Windows and WSL preparation

Run the following in **Administrator PowerShell**. This is a human checkpoint:

```powershell
wsl --install -d Ubuntu
wsl --update
wsl --list --verbose
```

Restart Windows when requested. Launch Ubuntu, create the Linux user and
password, and confirm that `wsl --list --verbose` reports version 2. If it does
not, run `wsl --set-version Ubuntu 2` from Administrator PowerShell.

Inside Ubuntu, keep the repositories below the Linux home directory, such as
`~/aitinkering`. Do not put active Git, Dolt, or Gas City directories under
`/mnt/c`.

The WSL-side installer needs these human checkpoints:

1. Enter the Ubuntu password for `sudo apt-get`.
2. Complete `gh auth login`, then run `gh auth setup-git`.
3. Start `claude` and complete its account sign-in.
4. Start `codex` and complete its ChatGPT or API sign-in.
5. Confirm access to both private repositories before configuration begins.

The checked-in Homebrew formulas install the exact Gas City, Beads, and Dolt
versions recorded in `bootstrap/toolchain.env` and pin them against accidental
upgrade. Upgrade both machines deliberately and together; never let only one
host migrate the shared schema.

The standard installer may download a newer Gas City/Beads/Dolt set than
machine A currently uses. The version gate will stop in that case. Choose one
of these paths before opening either shared database:

- pin machine B to the versions in `bootstrap/toolchain.env`; or
- back up both stores, coordinate an upgrade on machine A and machine B, verify
  the same versions on both, and deliberately update `bootstrap/toolchain.env`.

Do not bypass the gate or let only one machine perform a Beads schema migration.

If Windows reports that virtualization is unavailable, the operator must enable
CPU virtualization in firmware and the Windows virtualization components before
continuing.

Authoritative references:

- Microsoft WSL installation: https://learn.microsoft.com/windows/wsl/install
- Gas City installation: https://github.com/gastownhall/gascity/blob/main/docs/getting-started/installation.md
- Claude Code setup: https://code.claude.com/docs/en/setup
- Codex CLI setup: https://developers.openai.com/codex/cli
