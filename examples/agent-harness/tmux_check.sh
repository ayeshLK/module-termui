#!/bin/bash
# Runs the agent harness inside tmux and checks what the pane shows, as part of the terminal checks for a
# release (see CONTRIBUTING.md). Needs tmux and java on the PATH, and "bal build" run in this directory.
#
# Usage: ./tmux_check.sh [path to agent_harness.jar]
JAR=${1:-$(cd "$(dirname "$0")" && pwd)/target/bin/agent_harness.jar}
S=h
fails=0
ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1"; echo "$2" | tail -8 | sed 's/^/    | /'; fails=$((fails+1)); }
pane() { tmux capture-pane -p -t $S; }
rows() { pane | sed 's/[[:space:]]*$//'; }
wait_for() { for i in $(seq 1 100); do pane | grep -qF -- "$1" && return 0; sleep 0.2; done; return 1; }
check() { # name, command that succeeds when ok
  local name=$1; shift
  if "$@"; then ok "$name"; else bad "$name" "$(pane)"; fi
}
last_two() { local r; r=$(rows | sed '/^$/d' | tail -2); echo "$r"; }
input_at_bottom() { sleep 0.4; local h; h=$(tmux display -p -t $S '#{pane_height}'); local r; r=$(pane | sed -n "$((h-1))p;${h}p" | sed 's/[[:space:]]*$//'); echo "$r" | sed -n 1p | grep -q '^❯' && echo "$r" | sed -n 2p | grep -q 'dummy-agent-1'; }

tmux kill-server 2>/dev/null
export TERM=xterm-256color
tmux new-session -d -s $S -x 100 -y 40 "java -jar $JAR"
check "tmux: shows the banner and the prompt" wait_for "Welcome to Dummy Agent"
check "tmux: the input is on the bottom rows from the first frame" input_at_bottom
check "tmux: the banner is at the top, untouched" bash -c "tmux capture-pane -p -t $S | head -3 | grep -q '╭'"
tmux send-keys -t $S "ab" Left "X"; sleep 0.4
check "tmux: cursor keys edit in the middle of the input" bash -c "tmux capture-pane -p -t $S | grep -q '❯ aXb'"
tmux send-keys -t $S M-Enter "Y"; sleep 0.4
check "tmux: Alt+Enter starts a second line under the prompt" bash -c "tmux capture-pane -p -t $S | grep -q '^  Yb'"
tmux send-keys -t $S C-u BSpace C-u C-k; sleep 0.4
check "tmux: Ctrl+U, Ctrl+K and Backspace clear the input" bash -c "[ \"\$(tmux capture-pane -p -t $S | sed 's/[[:space:]]*\$//' | grep -c '^❯\$')\" -ge 1 ]"
tmux resize-window -t $S -x 60 -y 30; sleep 1.5
check "tmux: after a resize the input is on the bottom rows of the new size" input_at_bottom
tmux send-keys -t $S "fix the bug in the handler" Enter
check "tmux: asks before editing a file" wait_for "Allow Edit(src/handler.bal)?"
tmux send-keys -t $S y
check "tmux: asks before running a command" wait_for "Allow Bash(bal test)?"
tmux send-keys -t $S y
check "tmux: streams the final answer" wait_for "All 12 tests pass"
sleep 1
check "tmux: the input is on the bottom rows after the turn" input_at_bottom
tmux send-keys -t $S C-d
sleep 1.5
check "tmux: Ctrl+D quits and the pane ends" bash -c "! tmux has-session -t $S 2>/dev/null || [ \"\$(tmux list-panes -t $S -F '#{pane_dead}')\" = 1 ]"
[ $fails -eq 0 ] && echo "all checks passed" || echo "FAILED: $fails"
