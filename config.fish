set -gx DEFAULT_USER "rcabralc"
set -gx DEFAULT_HOST "atrocious"

source ~/.config/fish/colors.fish

# Fish git prompt
set __fish_git_prompt_showdirtystate 'yes'
set __fish_git_prompt_showstashstate 'yes'
set __fish_git_prompt_showuntrackedfiles 'yes'
set __fish_git_prompt_showupstream 'yes'
set __fish_git_prompt_show_informative_status 'yes'

set __fish_git_prompt_color_branch grey
set __fish_git_prompt_char_stateseparator ''

set __fish_git_prompt_char_dirtystate '+'
set __fish_git_prompt_color_dirtystate red

set __fish_git_prompt_char_stagedstate '*'
set __fish_git_prompt_color_stagedstate green -o

set __fish_git_prompt_char_invalidstate '#'
set __fish_git_prompt_color_invalidstate red -o

set __fish_git_prompt_char_stashstate '$'
set __fish_git_prompt_color_stashstate brown -o

set __fish_git_prompt_char_untrackedfiles '…'
set __fish_git_prompt_color_untrackedfiles cyan

set __fish_git_prompt_char_upstream_equal '='
set __fish_git_prompt_char_upstream_behind '<'
set __fish_git_prompt_char_upstream_ahead '>'
set __fish_git_prompt_char_upstream_diverged '<>'

set __fish_git_prompt_char_cleanstate ''
set __fish_git_prompt_color_cleanstate green -o

# Install rbenv
if test ! -d ~/.rbenv
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    cd ~/.rbenv; and src/configure; and make -C src 2>/dev/null
end

# Basic environment vars
if test -d ~/go
  set -gx GOPATH ~/go
  set PATH ~/go/bin $PATH
end
set PATH ~/.local/bin ~/.rbenv/bin $PATH
set -gx EDITOR nvim
set -gx LESS FRX

set fish_key_bindings fish_user_key_bindings

status --is-interactive; and . (~/.rbenv/bin/rbenv init - | psub)

if status --is-interactive
    # This askpass program uses pass (which uses GPG) to get passwords.
    set -gx SSH_ASKPASS ~/.local/bin/askpass
    # SSH key management.  Using keychain to add the keys to start the agent
    # and add the keys.  If the agent already has been started, keychain does
    # nothing but returning success.  At this point, SSH_ASKPASS should already
    # be set to the askpass app.
    keychain --eval --agents ssh -Q --quiet ~/.ssh/id_ecdsa ~/.ssh/id_rsa | source
end

fish_vi_cursor auto
set -g fish_cursor_insert line blink

if which direnv >/dev/null 2>/dev/null
  eval (direnv hook fish)
end

# More configuration is placed in site/
mkdir -p ~/.config/fish/site
for f in ~/.config/fish/site/*.fish
    source $f
end

if test -z $SHELL
  set -gx SHELL (which fish)
end
