function fish_prompt
    set last_status $status
    set pwd (prompt_pwd)
    set host (hostname)
    set sep ""

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
    end

    if test $pwd != '~'
        set_color $fish_color_cwd
        printf ":%s" $pwd
        set_color normal
        set sep " "
    end

    set git (__fish_git_prompt "%s")
    if test $git != ''
        printf " %s" $git
        set sep " "
    end

    set_color normal
    if test $last_status -ne 0
        set_color brown
        printf "[$last_status]"
        set sep " "
    end

    set_color grey
    if test $fish_bind_mode != ''
        switch $fish_bind_mode
        case 'insert'
            set_color -o normal
        case 'visual'
            set_color -o brred
        end
    end
    printf "%s\$ " $sep

    set_color normal
end
