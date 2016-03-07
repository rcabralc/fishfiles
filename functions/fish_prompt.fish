function fish_prompt
    set last_status $status
    set pwd (prompt_pwd)

    if test $USER != $DEFAULT_USER
        set_color brown
        printf '%s' (echo $USER)
        set_color normal

        set_color normal
        printf "@%s:" (hostname)
        set_color normal
    end

    if test $pwd != '~'
        set_color $fish_color_cwd
        printf "%s " $pwd
        set_color normal
    end

    printf "%s" (__fish_git_prompt "%s ")

    set_color normal
    if test $last_status -ne 0
        set_color brown
        printf "[$last_status] "
    end

    set_color grey
    if test $fish_bind_mode != ''
        switch $fish_bind_mode
        case 'insert'
            set_color normal -o
        case 'visual'
            set_color red -o
        end
    end
    printf "\$ "

    set_color normal
end
