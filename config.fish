set -gx DEFAULT_USER "rcabralc"
set -gx DEFAULT_HOST "atrocious"
set -gx fish_greeting ''

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
  git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
end

# Basic environment vars

if test -x "$HOME/go/bin" >/dev/null
  set -gx GOPATH ~/go
  set PATH ~/go/bin $PATH
end

if test -x "$HOME/.npm/bin" >/dev/null
  set PATH "$HOME/.npm/bin" $PATH
end

if test -x "$HOME/.cargo/bin" >/dev/null
  set PATH "$HOME/.cargo/bin" $PATH
end

if test -x "$HOME/.linuxbrew/bin" >/dev/null
  set PATH "$HOME/.linuxbrew/bin" $PATH
  set MANPATH "$HOME/.linuxbrew/share/man" $MANPATH
  set INFOPATH "$HOME/.linuxbrew/share/info" $INFOPATH
end

set PATH ~/.local/bin ~/.rbenv/bin $PATH
set -gx EDITOR nvim
set -gx LESS FRX

set fish_key_bindings fish_user_key_bindings
fish_vi_cursor auto
set -g fish_cursor_insert line blink

status --is-interactive; and . (~/.rbenv/bin/rbenv init - | psub)

if command -v direnv >/dev/null
  eval (direnv hook fish)
end

set -gx SHELL (command -v fish)

# SSH key management.
test -f ~/.local/bin/askpass; and \
  command -v pass >/dev/null; and \
  command -v keychain >/dev/null; and \
  status --is-interactive
if test $status -eq 0
  # This askpass program uses pass (which uses GPG) to get passwords.
  set -gx SSH_ASKPASS ~/.local/bin/askpass

  # SSH key management.  Using keychain to add the keys to start the agent
  # and add the keys.  If the agent already has been started, keychain does
  # nothing but returning success (but adds the requested keys).
  keychain --eval --agents ssh -Q --quiet id_rsa id_ecdsa | source
end

# More configuration is placed in site/
mkdir -p ~/.config/fish/site
for f in (find ~/.config/fish/site/ -type f -name '*.fish' | sort)
    source $f
end
