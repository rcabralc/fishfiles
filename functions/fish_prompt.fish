function fish_prompt
    set last_status $status

    set_color $monokai_orange
    printf '%s' (echo $USER)
    set_color normal

    set_color $monokai_white
    printf '@%s' (hostname)
    set_color normal

    set_color $fish_color_cwd
    printf '%s' (prompt_pwd)
    set_color normal

    printf '%s' (__fish_git_prompt " %s")

    if test $last_status -ne 0
        set_color $monokai_magenta
        printf " $last_status"
    end

    set_color $monokai_lightgray -o
    if test $fish_bind_mode != ''
        switch $fish_bind_mode
            case 'insert'
                set_color $monokai_white -o
            case 'visual'
                set_color $monokai_magenta -o
        end
    end
    printf "%% "

    set_color normal
end
