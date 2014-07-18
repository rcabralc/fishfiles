source ~/.config/fish/colors.fish

fish_vi_key_bindings

# Fish git prompt
set __fish_git_prompt_showdirtystate 'yes'
set __fish_git_prompt_showstashstate 'yes'
set __fish_git_prompt_showupstream 'yes'
set __fish_git_prompt_color_branch $monokai_cyan
set __fish_git_prompt_color_dirtystate $monokai_magenta
set __fish_git_prompt_color_stashstate $monokai_orange
set __fish_git_prompt_color_stagedstate $monokai_lime -o

# Status Chars
set __fish_git_prompt_char_dirtystate '+'
set __fish_git_prompt_char_stagedstate '*'
set __fish_git_prompt_char_stashstate '!'
set __fish_git_prompt_char_upstream_ahead '^'
set __fish_git_prompt_char_upstream_behind 'v'


# Basic environment vars
set PATH ~/.local/bin ~/.rbenv/bin ~/.gem/ruby/2.1.0/bin ~/bin $PATH
set -Ux EDITOR "gvim --nofork"
set -gx LESS=FRSX


# rbenv (must have its bin directory in PATH)
status --is-interactive; and source (rbenv init -|psub)


# SSH key management.  Using keychain to add the keys to start the agent and
# add the keys.  If the agent already has been started, keychain does nothing
# but returning success.  At this point, SSH_ASKPASS should already be set to
# the askpass app (ksshaskpass if logged in through KDE).
# Keychain generates ourput to Fish, but it expects SSH_AUTH_SOCK and
# SSH_AGEND_PID vars to be set (otherwise the sourced script fails silently).
set SSH_AUTH_SOCK placeholder
set SSH_AGEND_PID placeholder
source (/usr/bin/keychain --eval --agents ssh -Q --quiet ~/.ssh/id_ecdsa ~/.ssh/id_rsa ~/.ssh/tn_rsa ~/.ssh/github_rsa | psub)


# TMUX
if status --is-interactive
    if test -z $TMUX
        set -l id (tmux ls | grep -vm1 attached | cut -d: -f1)
        if test -z $id
            tmux new-session
        else
            tmux attach-session -t $id
        end
    end
end
