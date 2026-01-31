#!/bin/bash
SESSION="kyuu"
tmux new-session -d -s $SESSION
tmux rename-window -t 0 'vim'
tmux send-keys -t 'vim' 'vim .' C-m
tmux new-window -t $SESSION:1 -n 'bash'
tmux new-window -t $SESSION:2 -n 'language_server'
tmux send-keys -t 'language_server' './scripts/ls.sh' C-m

tmux attach-session -t $SESSION:0
