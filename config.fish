set -gx DEFAULT_USER "rcabralc"
set -gx DEFAULT_HOST "archrabl"
set -gx fish_greeting ''
set -gx GPG_TTY (tty)

source ~/.config/fish/colors.fish

# Install anyenv
if test ! -d ~/.anyenv
  git clone https://github.com/anyenv/anyenv ~/.anyenv
end

# # Install rbenv
# if test ! -d ~/.rbenv
#   git clone https://github.com/rbenv/rbenv.git ~/.rbenv
#   cd ~/.rbenv; and src/configure; and make -C src 2>/dev/null
#   git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
#   cd
# end
#
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

mkdir -p ~/.local/bin
set PATH ~/.local/bin $PATH
set -Ux fish_user_paths $HOME/.anyenv/bin $fish_user_paths
# test -x ~/.rbenv/bin; and set PATH ~/.rbenv/bin $PATH
set -gx EDITOR nvim

set fish_key_bindings fish_user_key_bindings
fish_vi_cursor auto
set -g fish_cursor_insert line blink

# status --is-interactive; and command -v rbenv >/dev/null;
# and source (~/.rbenv/bin/rbenv init - | psub)
#
if command -v direnv >/dev/null
  eval (direnv hook fish)
end

set -gx SHELL (command -v fish)

status --is-interactive; and ssh_agent

# More configuration is placed in site/
mkdir -p ~/.config/fish/site
for f in (find ~/.config/fish/site/ -type f -name '*.fish' | sort)
    source $f
end

dedup_path

status --is-interactive; and command -v anyenv >/dev/null;
and ~/.anyenv/bin/anyenv init - | source
