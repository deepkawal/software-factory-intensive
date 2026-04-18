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
                                                                                                                                                                                                                                                                                                             
  1. Check what the architect's hook sees right now:                                                                                                                                                                                                                                                         
  gc hook --city ~/Projects/factory/workshop_w3/w3-gc-factory w3-project/architect                                                                                                                                                                                                                           
                                                                                                                                                                                                                                                                                                             
  For continuous monitoring, you could re-run #2 periodically. When wp-964 moves from open to in_progress, the architect has claimed it.                                                                                                                                                                     
                                                                                                                                                                                                                                                                                                             
❯ how must time will need to wait until cache-reconcile race  resolves                                                                                                                                                                                                                                       
                           




So is it a nudge to wake?                                                                                                                                                                                                                                                                                  

⏺ Bash(gc session nudge w3-project/architect "You have pending work. Run gc hook w3-project/architect and act on it." --city ~/Projects/factory/workshop_w3/w3-gc-facto…)
  ⎿  2026/04/18 11:01:13 city pack "packs/actual/all": not found, skipping: loading pack.toml: open /Users/david_miura_actual_ai/Projects/actual-software/software-factory-intensive/packs/actual/all/pack.toml: no such file or directory
     2026/04/18 11:01:13 tmux state cache: refreshed 2 sessions in 4.597458ms
     Queued nudge for w3-project/architect

  Bash(sleep 15 && gc status --city ~/Projects/factory/workshop_w3/w3-gc-factory 2>&1 | grep -E "architect|agents running")
  ⎿  Running… (6s · timeout 25s)                                             
     (ctrl+b to run in background)
                                    


                                    npm run build

> w3-project@0.1.0 build
> next build

▲ Next.js 16.2.4 (Turbopack)

  Creating an optimized production build ...
✓ Compiled successfully in 747ms
✓ Finished TypeScript in 564ms    
✓ Collecting page data using 4 workers in 115ms    
✓ Generating static pages using 4 workers (3/3) in 121ms
✓ Finalizing page optimization in 60ms    

Route (app)
┌ ○ /
└ ○ /_not-found


○  (Static)  prerendered as static content

david_miura_actual_ai@MacBook-Pro w3-project % npx serve out -p 3001      
Need to install the following packages:
serve@14.2.6
Ok to proceed? (y) 


   ┌───────────────────────────────────────────┐
   │                                           │
   │   Serving!                                │
   │                                           │
   │   - Local:    http://localhost:3001       │
   │   - Network:  http://192.168.0.137:3001   │
   │                                           │
   │   Copied local address to clipboard!      │
   │                                           │
   └───────────────────────────────────────────┘

 HTTP  4/18/2026 11:13:24 AM ::1 GET /
 HTTP  4/18/2026 11:13:24 AM ::1 Returned 200 in 7 ms
 HTTP  4/18/2026 11:13:24 AM ::1 GET /_next/static/chunks/0smyhm2bkccm_.css
 HTTP  4/18/2026 11:13:24 AM ::1 Returned 200 in 1 ms
 HTTP  4/18/2026 11:13:24 AM ::1 GET /_next/static/chunks/15xrurgzs99gv.js
 HTTP  4/18/2026 11:13:24 AM ::1 GET /_next/static/chunks/06~f4cvc3b8e~.js
 HTTP  4/18/2026 11:13:24 AM ::1 GET /_next/static/chunks/0n~dq4kpx9xxx.js
 HTTP  4/18/2026 11:13:24 AM ::1 GET /_next/static/chunks/turbopack-0_jpvw_cy-fw_.js
 HTTP  4/18/2026 11:13:24 AM ::1 GET /_next/static/chunks/0dbhjjzl8qfwv.js
 HTTP  4/18/2026 11:13:24 AM ::1 Returned 200 in 2 ms
 HTTP  4/18/2026 11:13:24 AM ::1 Returned 200 in 1 ms
 HTTP  4/18/2026 11:13:24 AM ::1 Returned 200 in 2 ms
 HTTP  4/18/2026 11:13:24 AM ::1 Returned 200 in 3 ms
 HTTP  4/18/2026 11:13:24 AM ::1 Returned 200 in 4 ms
 HTTP  4/18/2026 11:13:24 AM ::1 GET /favicon.ico
 HTTP  4/18/2026 11:13:24 AM ::1 Returned 404 in 1 ms
 HTTP  4/18/2026 11:13:28 AM ::1 GET /
 HTTP  4/18/2026 11:13:28 AM ::1 Returned 200 in 2 ms
 HTTP  4/18/2026 11:13:28 AM ::1 GET /_next/static/chunks/0smyhm2bkccm_.css
 HTTP  4/18/2026 11:13:28 AM ::1 Returned 304 in 1 ms
 HTTP  4/18/2026 11:13:28 AM ::1 GET /_next/static/chunks/06~f4cvc3b8e~.js
 HTTP  4/18/2026 11:13:28 AM ::1 GET /_next/static/chunks/0n~dq4kpx9xxx.js
 HTTP  4/18/2026 11:13:28 AM ::1 Returned 304 in 0 ms
 HTTP  4/18/2026 11:13:28 AM ::1 GET /_next/static/chunks/turbopack-0_jpvw_cy-fw_.js
 HTTP  4/18/2026 11:13:28 AM ::1 Returned 304 in 0 ms
 HTTP  4/18/2026 11:13:28 AM ::1 GET /_next/static/chunks/0dbhjjzl8qfwv.js
 HTTP  4/18/2026 11:13:28 AM ::1 Returned 304 in 1 ms
 HTTP  4/18/2026 11:13:28 AM ::1 Returned 304 in 0 ms

 