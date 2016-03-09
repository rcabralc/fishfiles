function fish_right_prompt
    set sep ""

    set rubyversion (rbenv version-name)
    if test $status -eq 0
        if test $rubyversion != 'system'
            set_color grey
            printf '%s ' $rubyversion
            set sep " "
        end
    else
        set_color -o red
        printf 'bad Ruby '
        set sep " "
    end
    set_color normal

    set_color bryellow
    printf "$sep%s" (date "+%d/%m")
    set_color normal
    set sep " "

    set_color brown
    printf "$sep%s" (date "+%Hh%M")
    set_color normal
    set sep " "

    set batteryprompt (battery_prompt)
    if test $status -eq 0
        set_color red
        printf "$sep⚡%s" $batteryprompt
        set_color normal
        set sep " "
    end
end
