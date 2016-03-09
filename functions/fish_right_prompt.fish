function fish_right_prompt
    set rubyversion (rbenv version-name)
    if test $status -eq 0
        if test $rubyversion != 'system'
            set_color grey
            printf '%s ' $rubyversion
        end
    else
        set_color -o red
        printf 'bad Ruby '
    end
    set_color normal

    set_color bryellow
    printf '%s ' (date "+%d/%m")
    set_color normal

    set_color brown
    printf '%s ' (date "+%Hh%M")
    set_color normal

    set_color red
    printf '⚡%s' (battery_prompt)
    set_color normal
end
