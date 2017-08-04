if test "$TERM" = 'linux'
    /bin/echo -e "
    \e]P2b2222
    \e]Pc05050
    \e]Pc0a763
    \e]Pf27349
    \e]P835069
    \e]Pc06372
    \e]P7baaaa
    \e]P795f5f
    \e]P483838
    \e]Pe65c5c
    \e]Pe6c973
    \e]Pf29779
    \e]P995c7a
    \e]Pe67386
    \e]P8fcccc
    \e]Pdbadad
    "
    # get rid of artifacts
    clear
end

# the default color
set fish_color_normal                            brwhite

# the color for commands
set fish_color_command                           green

# the color for quoted blocks of text
set fish_color_quote                             bryellow

# the color for IO redirections
set fish_color_redirection                       brred

# the color for process separators like
# ';' and '&'
set fish_color_end                               red

# the color used to highlight potential
# errors
set fish_color_error                          -o brred

# the color for regular command
# parameters
set fish_color_param                             cyan

# the color used for code comments
set fish_color_comment                           white

# the color used to highlight matching
# parenthesis
set fish_color_match                             yellow

# the color used to highlight history
# search matches
set fish_color_search_match --background=brblack normal

# the color for parameter expansion
# operators like '*' and '~'
set fish_color_operator                          yellow

# the color used to highlight character
# escapes like '\n' and '\x70'
set fish_color_escape                            yellow

# the color used for the current
# working directory in the default
# prompt
set fish_color_cwd                            -o magenta
set fish_color_cwd_root                          red

# Others
set fish_color_autosuggestion                    white
set fish_color_user                              yellow
set fish_color_host                           -o cyan
set fish_color_status                            red

# Additionally, the following variables
# are available to change the
# highlighting in the completion pager:

# the color of the prefix string, i.e.
# the string that is to be completed
set fish_pager_color_prefix                      cyan

# the color of the completion itself
set fish_pager_color_completion                  normal

# the color of the completion
# description
set fish_pager_color_description                 white

# the color of the progress bar at the
# bottom left corner
set fish_pager_color_progress                    cyan

# `less' colors
set -gx LESS_TERMCAP_mb (printf '\e[1;31m')       # start blinking
set -gx LESS_TERMCAP_md (printf '\e[1;31m')       # start bold
set -gx LESS_TERMCAP_so (printf '\e[48;5;11;30m') # start standout-mode - info box
set -gx LESS_TERMCAP_us (printf '\e[1;32m')       # start underline
set -gx LESS_TERMCAP_me (printf '\e[0m')          # end mode
set -gx LESS_TERMCAP_se (printf '\e[0m')          # end standout-mode
set -gx LESS_TERMCAP_ue (printf '\e[0m')          # end underline
