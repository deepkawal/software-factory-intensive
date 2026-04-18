# Start Here

### For Claude Code

```bash
# Option 1: Symlink into user-level skills (available in all projects)
ln -s "$(pwd)/skills/factory-activity-agent" ~/.claude/skills/factory-activity-agent

# Option 2: Symlink into project-level skills (this project only)
mkdir -p .claude/skills
ln -s "$(pwd)/skills/factory-activity-agent" .claude/skills/factory-activity-agent

# Option 3: Copy into user-level skills
cp -r skills/factory-activity-agent ~/.claude/skills/factory-activity-agent
```

### For Codex

```bash
mkdir -p ~/.codex/skills
cp -r skills/factory-activity-agent ~/.codex/skills/factory-activity-agent
```





No --label flag on gc sling.
                                                                                                                                                                                                                                                            
  The difference:                                                 
                                                                                                                                                                                                                                                            
  ┌───────────────┬─────────────────────────┬───────────────┐                                                                                                                                                                                               
  │               │        gc sling         │ gc bd create  │                                                                                                                                                                                               
  ├───────────────┼─────────────────────────┼───────────────┤                                                                                                                                                                                               
  │ Creates bead  │ Yes (from text)         │ Yes           │     
  ├───────────────┼─────────────────────────┼───────────────┤
  │ Adds label    │ No                      │ Yes (--label) │                                                                                                                                                                                               
  ├───────────────┼─────────────────────────┼───────────────┤
  │ Nudges agent  │ Yes (routes + notifies) │ No            │                                                                                                                                                                                               
  ├───────────────┼─────────────────────────┼───────────────┤                                                                                                                                                                                               
  │ Spawns convoy │ Yes (auto)              │ No            │
  └───────────────┴─────────────────────────┴───────────────┘                                                                                                                                                                                               
                                                                  
  So they're complementary. The cleanest workflow is:                                                                                                                                                                                                       
                                                                  
  # Create with label, then sling                                                                                                                                                                                                                           
  gc bd create "Create a SPA nextjs site" --label needs-architecture --silent | xargs gc sling w3-project/architect
                                                                                                                                                                                                                                                            
  Or just create with the label and let the architect's polling loop find it naturally (no sling needed):                                                                                                                                                   
                                                                                                                                                                                                                                                            
  gc bd create "Create a SPA nextjs site" --label needs-architecture               









  From the project directory:

  cd ~/Projects/factory/workshop_w3/w3-project
  gc sling w3-project/architect "Create a hello world index.html"

  Or from anywhere with --city:

  gc sling w3-project/architect "Create a hello world index.html" --city ~/Projects/factory/workshop_w3/w3-gc-factory

  Then verify pickup:

  gc bd --rig w3-project list
  gc events --city ~/Projects/factory/workshop_w3/w3-gc-factory | grep architect | tail -5





  Three ways to monitor:
                                                                                                                                                                                                                                                                                                             
  1. Watch events in real-time:                                                                                                                                                                                                                                                                              
  gc events --city ~/Projects/factory/workshop_w3/w3-gc-factory | grep "wp-"
                                                                                                                                                                                                                                                                                                             
  2. Check project bead status:                                                                                                                                                                                                                                                                              
  gc bd --rig w3-project list --status=all
                                                                                                                                                                                                                                                                                                             
  3. Check what the architect's hook sees right now:                                                                                                                                                                                                                                                         
  gc hook --city ~/Projects/factory/workshop_w3/w3-gc-factory w3-project/architect                                                                                                                                                                                                                           
                                                                                                                                                                                                                                                                                                             
  For continuous monitoring, you could re-run #2 periodically. When wp-964 moves from open to in_progress, the architect has claimed it.                                                                                                                                                                     
                                                                                                                                                                                                                                                                                                             
❯ how must time will need to wait until cache-reconcile race  resolves                                                                                                                                                                                                                                       
                           


