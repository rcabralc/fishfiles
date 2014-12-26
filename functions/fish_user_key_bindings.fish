function fish_user_key_bindings
    fish_vi_key_bindings

    bind -M insert \ef accept-autosuggestion
    bind -M insert \ej accept-autosuggestion execute

    function vi-forward
        set cur_pos (commandline -C)
        set cmd (commandline | cut -b (math $cur_pos + 1)-)
        set offset (echo $cmd | grep --color=never -m1 -o -b -P "$argv[1]" | head -n1 | cut -d: -f1)
        if test -z $offset
            return
        end
        commandline -C (math $cur_pos + $offset)
    end

    function vi-backward
        set cur_pos (commandline -C)
        if test $cur_pos -eq 0
            return
        end
        # exclude current character.
        set cmd (commandline | cut -b -(math $cur_pos))
        set new_pos (echo $cmd | grep --color=never -o -b -P "$argv[1]" | tail -n1 | cut -d: -f1)
        if test -z $new_pos
            return
        end
        commandline -C $new_pos
    end

    function vi-next-word
        vi-forward "(?<=[^\w])\w|.\$"
    end

    function vi-prev-word
        vi-backward "(?<=[^\w])\w|^."
    end

    function vi-next-big-word
        vi-forward "(?<=\s)[^\s]|.\$"
    end

    function vi-prev-big-word
        vi-backward "(?<=\s)[^\s]|^."
    end

    function vi-word-end
        vi-forward "(?<=.)\w(?=[^\w])|.\$"
    end

    function vi-big-word-end
        vi-forward "(?<=.)[^\s](?=\s)|.\$"
    end

    bind w vi-next-word
    bind b vi-prev-word
    bind e vi-word-end
    bind W vi-next-big-word
    bind B vi-prev-big-word
    bind E vi-big-word-end
end
