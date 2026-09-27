# New Factory Machine

Set up this Windows machine as a second software-factory host by following
[`../skills/factory-machine-bootstrap/SKILL.md`](../skills/factory-machine-bootstrap/SKILL.md).

Start in audit mode. Pause for the operator at every Windows administrator,
`sudo`, GitHub authentication, Claude authentication, or Codex authentication
step. Never copy credentials, agent transcripts, caches, `.gc/`, or local Dolt
directories from another machine.

After setup, use Beads as the shared work and memory system. Pull before choosing
work, claim before editing, and push the claim immediately. Git branches carry
code; the Dolt remote carries Beads state.
