function fish_prompt
    set last_status $status

    set_color $monokai_yellow
    printf '%s ' (date "+%d/%m")
    set_color $monokai_orange
    printf '%s ' (date "+%Hh%M")

    set_color $monokai_magenta
    printf '⚡%s ' (battery_prompt)

    if test (rbenv version-name) != 'system'
        set_color $monokai_lightgray -o
        printf '%s ' (rbenv version-name)
    end

    set_color $fish_color_cwd
    printf '%s' (prompt_pwd)

    set_color normal
    printf '%s' (__fish_git_prompt)

    if test $last_status -ne 0
        set_color $monokai_magenta
        printf " $last_status"
    end

    if test $fish_bind_mode != ''
        switch $fish_bind_mode
            case 'insert'
                set_color $monokai_lime
                printf " I"
            case 'default'
                set_color $monokai_lightgray
                printf " N"
        end
    end

    set_color normal
    printf ": "
end
