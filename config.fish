set -gx DEFAULT_USER "rcabralc"

source ~/.config/fish/colors.fish

# Fish git prompt
set __fish_git_prompt_showdirtystate 'yes'
set __fish_git_prompt_showstashstate 'yes'
set __fish_git_prompt_showuntrackedfiles 'yes'
set __fish_git_prompt_showupstream 'yes'
set __fish_git_prompt_show_informative_status 'yes'

set __fish_git_prompt_color_branch $monokai_lightgray
set __fish_git_prompt_char_stateseparator ''

set __fish_git_prompt_char_dirtystate '+'
set __fish_git_prompt_color_dirtystate $monokai_magenta

set __fish_git_prompt_char_stagedstate '*'
set __fish_git_prompt_color_stagedstate $monokai_lime -o

set __fish_git_prompt_char_invalidstate '#'
set __fish_git_prompt_color_invalidstate $monokai_magenta -o

set __fish_git_prompt_char_stashstate '$'
set __fish_git_prompt_color_stashstate $monokai_orange -o

set __fish_git_prompt_char_untrackedfiles '…'
set __fish_git_prompt_color_untrackedfiles $monokai_cyan

set __fish_git_prompt_char_upstream_equal '='
set __fish_git_prompt_char_upstream_behind '<'
set __fish_git_prompt_char_upstream_ahead '>'
set __fish_git_prompt_char_upstream_diverged '<>'

set __fish_git_prompt_char_cleanstate ''
set __fish_git_prompt_color_cleanstate $monokai_lime -o


# Basic environment vars
set PATH ~/.local/bin ~/.rbenv/bin ~/.gem/ruby/2.1.0/bin ~/bin $PATH
set -gx EDITOR "gvim --nofork"
set -gx LESS=FRX


# SSH key management.  Using keychain to add the keys to start the agent and
# add the keys.  If the agent already has been started, keychain does nothing
# but returning success.  At this point, SSH_ASKPASS should already be set to
# the askpass app (ksshaskpass if logged in through KDE).
# Keychain generates ourput to Fish, but it expects SSH_AUTH_SOCK and
# SSH_AGEND_PID vars to be set (otherwise the sourced script fails silently).
set SSH_AUTH_SOCK placeholder
set SSH_AGEND_PID placeholder
source (/usr/bin/keychain --eval --agents ssh -Q --quiet ~/.ssh/id_ecdsa ~/.ssh/id_rsa ~/.ssh/tn_rsa ~/.ssh/github_rsa | psub)


set fish_key_bindings fish_user_key_bindings

if status --is-interactive
    # rbenv (must have its bin directory in PATH)
    source (rbenv init - | psub)

    # TMUX
    if test -z $TMUX
        set -l id (tmux ls | grep -vm1 attached | cut -d: -f1)
        if test -z $id
            tmux new-session
        else
            tmux attach-session -t $id
        end
    end
end

# More configuration is placed in site/
mkdir -p ~/.config/fish/site
for f in (ls ~/.config/fish/site/*.fish)
    source $f
end
