function fish_prompt
    set last_status $status
    set pwd (prompt_pwd)
    set host (hostname)
    set git ""
    set sep ""
    set pathprefix ""

    if test $USER != $DEFAULT_USER
        set_color brown
        printf "%s" (echo $USER)
        set_color normal
        set sep " "
    end

    if test $host != $DEFAULT_HOST
        set_color brcyan
        printf "@%s" (hostname)
        set_color normal
        set sep " "
        set pathprefix ":"
    end

    if test $pwd != '~'
        set_color $fish_color_cwd
        printf "%s%s" $pathprefix $pwd
        set_color normal
        set sep " "
    end

    if git rev-parse --show-toplevel 2>/dev/null 1>/dev/null
        printf " %s" (__fish_git_prompt "%s")
        set sep " "
    end

    set_color normal
    if test $last_status -ne 0
        set_color brown
        printf "[$last_status]"
        set sep " "
    end

    set_color normal
    printf "%s" $sep
    if test $fish_bind_mode != ''
        switch $fish_bind_mode
            case default
                set_color --bold brred
            case insert
                set_color --bold brgreen
            case visual
                set_color --bold brmagenta
        end
    end
    printf "\$"

    set_color normal
    printf " "
end
