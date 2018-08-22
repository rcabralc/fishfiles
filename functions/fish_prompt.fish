function fish_prompt
    set last_status $status
    set pwd (prompt_pwd)
    set host (hostname)
    set git ""
    set sep ""
    set pathprefix ""

    # Fish git prompt
    set -g __fish_git_prompt_showdirtystate 'yes'
    set -g __fish_git_prompt_showstashstate 'yes'
    set -g __fish_git_prompt_showuntrackedfiles 'yes'
    set -g __fish_git_prompt_showupstream 'yes'
    set -g __fish_git_prompt_show_informative_status 'yes'

    set -g __fish_git_prompt_color_branch grey
    set -g __fish_git_prompt_char_stateseparator ''

    set -g __fish_git_prompt_char_dirtystate '+'
    set -g __fish_git_prompt_color_dirtystate red

    set -g __fish_git_prompt_char_stagedstate '*'
    set -g __fish_git_prompt_color_stagedstate green -o

    set -g __fish_git_prompt_char_invalidstate '#'
    set -g __fish_git_prompt_color_invalidstate red -o

    set -g __fish_git_prompt_char_stashstate '$'
    set -g __fish_git_prompt_color_stashstate brown -o

    set -g __fish_git_prompt_char_untrackedfiles '…'
    set -g __fish_git_prompt_color_untrackedfiles cyan

    set -g __fish_git_prompt_char_upstream_equal ''
    set -g __fish_git_prompt_char_upstream_behind '<'
    set -g __fish_git_prompt_char_upstream_ahead '>'
    set -g __fish_git_prompt_char_upstream_diverged '<>'

    set -g __fish_git_prompt_char_cleanstate ''
    set -g __fish_git_prompt_color_cleanstate green -o

    if not string match -e Android (uname -a) >/dev/null
        set_color normal; printf $sep
        set_color brown
        printf "%s" (date "+%Hh%M")
        set sep " "

        if command -v rbenv >/dev/null
            set rubyversion (rbenv version-name)
            if test $status -eq 0
                if test $rubyversion != 'system'
                    set_color normal; printf $sep
                    set_color grey
                    printf "$rubyversion"
                    set sep " "
                end
            else
                set_color normal; printf $sep
                set_color -o red
                printf "bad Ruby" $sep
                set sep " "
            end
            set_color normal
        end

        if test $USER != $DEFAULT_USER
            set_color normal; printf $sep
            set_color $fish_color_user
            printf "%s" $USER
            test $host != $DEFAULT_HOST; and set sep "@"; or set sep " "
            set_color normal
        end

        if test $host != $DEFAULT_HOST
            set_color $fish_color_host
            printf "$sep%s" $host
            set_color normal
            set sep ":"
        end
    end

    if test $pwd != '~'
        set_color $fish_color_cwd
        printf "$sep$pwd"
        set_color normal
        set sep " "
    end

    if git rev-parse --show-toplevel 2>/dev/null 1>/dev/null
        set_color brown; printf "@"
        __fish_git_prompt "%s"
        set_color normal
        set sep " "
    end

    if test $last_status -ne 0
        set_color brown
        printf "[$last_status]"
        set_color normal
        set sep " "
    end

    set_color normal
    printf $sep
    if test $fish_bind_mode != ''
        switch $fish_bind_mode
            case default
                set_color brown
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
