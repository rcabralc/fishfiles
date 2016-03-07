function man
    set -lx LESS_TERMCAP_mb (printf '\e[1;31m')     # start blinking
    set -lx LESS_TERMCAP_md (printf '\e[1;31m')     # start bold
    set -lx LESS_TERMCAP_me (printf '\e[0m')        # end mode
    set -lx LESS_TERMCAP_se (printf '\e[0m')        # end standout-mode
    set -lx LESS_TERMCAP_so (printf '\e[1;45;30m')  # start standout-mode - info box
    set -lx LESS_TERMCAP_ue (printf '\e[0m')        # end underline
    set -lx LESS_TERMCAP_us (printf '\e[1;32m')     # start underline
    command man $argv
end
