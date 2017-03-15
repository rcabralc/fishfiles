if test "$TERM" = 'linux'
    nvim +'redir! > /tmp/colors | silent! call rcabralc#print_colors(rcabralc#palette) | redir END | qall!'
    cat /tmp/colors | \
        grep -e . | \
        head -n 16 | \
        sed -n 's/\([0-9]\{1,\}\)\s#\([a-fA-F0-9]\{6\}\)/\1 \2/p' | \
        awk '$1 < 16 { printf "\033]P%X%s", $1, $2 }'
    rm /tmp/colors
    clear
    set -gx TERM xterm
end

# the default color
set fish_color_normal                           white

# the color for commands
set fish_color_command                          green

# the color for quoted blocks of text
set fish_color_quote                            bryellow

# the color for IO redirections
set fish_color_redirection                      brred

# the color for process separators like
# ';' and '&'
set fish_color_end                              red

# the color used to highlight potential
# errors
set fish_color_error                         -o red

# the color for regular command
# parameters
set fish_color_param                            cyan

# the color used for code comments
set fish_color_comment                          grey

# the color used to highlight matching
# parenthesis
set fish_color_match                            brown

# the color used to highlight history
# search matches
set fish_color_search_match --background=brgrey normal

# the color for parameter expansion
# operators like '*' and '~'
set fish_color_operator                         brown

# the color used to highlight character
# escapes like '\n' and '\x70'
set fish_color_escape                           brown

# the color used for the current
# working directory in the default
# prompt
set fish_color_cwd                              purple
set fish_color_cwd_root                         red

# Others
set fish_color_autosuggestion                   grey
set fish_color_user                             green
set fish_color_host                          -o cyan
set fish_color_status                           red

# Additionally, the following variables
# are available to change the
# highlighting in the completion pager:

# the color of the prefix string, i.e.
# the string that is to be completed
set fish_pager_color_prefix                     cyan

# the color of the completion itself
set fish_pager_color_completion                 normal

# the color of the completion
# description
set fish_pager_color_description                grey

# the color of the progress bar at the
# bottom left corner
set fish_pager_color_progress                   cyan

# `less' colors
set -gx LESS_TERMCAP_mb (printf '\e[1;31m')       # start blinking
set -gx LESS_TERMCAP_md (printf '\e[1;31m')       # start bold
set -gx LESS_TERMCAP_so (printf '\e[48;5;11;30m') # start standout-mode - info box
set -gx LESS_TERMCAP_us (printf '\e[1;32m')       # start underline
set -gx LESS_TERMCAP_me (printf '\e[0m')          # end mode
set -gx LESS_TERMCAP_se (printf '\e[0m')          # end standout-mode
set -gx LESS_TERMCAP_ue (printf '\e[0m')          # end underline
