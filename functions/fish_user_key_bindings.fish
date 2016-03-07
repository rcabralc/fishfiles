function fish_user_key_bindings
    fish_vi_key_bindings

    set -l next_word_start '(?<=[^\w])\w|.$'
    set -l prev_word_start '(?<=[^\w])\w|^.'
    set -l next_word_end   '(?<=.)\w(?=[^\w])|.$'
    set -l prev_word_end   '(?<=.)\w(?=[^\w])|^.'

    set -l next_bigword_start '(?<=\s)[^\s]|.$'
    set -l prev_bigword_start '(?<=\s)[^\s]|^.'
    set -l next_bigword_end   '(?<=.)[^\s](?=\s)|.$'
    set -l prev_bigword_end   '(?<=.)[^\s](?=\s)|^.'

    function __vi_forward_position
        set cur_pos (commandline -C)
        set cmd (commandline -b | cut -b (math $cur_pos + 1)-)
        set offset (echo $cmd | grep -m1 -o -b -P "$argv[1]" | head -n1 | cut -d: -f1)
        if test -z $offset
            set offset 0
        end
        printf (math $cur_pos + $offset)
    end

    function __vi_backward_position
        set cur_pos (commandline -C)
        if test $cur_pos -eq 0
            printf 0
            return
        end
        # exclude current character.
        set cmd (commandline -b | cut -b -(math $cur_pos))
        set new_pos (echo $cmd | grep -o -b -P "$argv[1]" | tail -n1 | cut -d: -f1)
        if test -z $new_pos
            set new_pos 0
        end
        printf $new_pos
    end

    function __vi_forward
        commandline -C (__vi_forward_position $argv[1])
    end

    function __vi_backward
        commandline -C (__vi_backward_position $argv[1])
    end

    function __vi_kill_forward
        set cur_pos (commandline -C)
        set final_pos (__vi_forward_position $argv[1])

        if test (count $argv) -gt 1
            set final_pos (math $final_pos + $argv[2])
        end

        if test $cur_pos -eq 0
            set before ""
        else
            set before (commandline | cut -b -(math $cur_pos))
        end

        set after (commandline | cut -b (math $final_pos + 1)-)
        commandline -r "$before$after"
        commandline -C $cur_pos
        commandline -f repaint
    end

    function __vi_kill_backward
        set cur_pos (commandline -C)
        set final_pos (__vi_backward_position $argv[1])

        if test $cur_pos -eq 0
            set before ""
        else
            set before (commandline | cut -b (math $cur_pos)-)
        end

        set after (commandline | cut -b -(math $final_pos + 1))
        commandline -r "$before$after"
        commandline -C $final_pos
        commandline -f repaint
    end

    bind w  "__vi_forward  '$next_word_start'"
    bind b  "__vi_backward '$prev_word_start'"
    bind e  "__vi_forward  '$next_word_end'"
    bind ge "__vi_backward '$prev_word_end'"

    bind W  "__vi_forward  '$next_bigword_start'"
    bind B  "__vi_backward '$prev_bigword_start'"
    bind E  "__vi_forward  '$next_bigword_end'"
    bind gE "__vi_backward '$prev_bigword_end'"

    bind dw "__vi_kill_forward '$next_word_start'"
    bind de "__vi_kill_forward '$next_word_end' 1"
    bind dW "__vi_kill_forward '$next_bigword_start'"
    bind dE "__vi_kill_forward '$next_bigword_end' 1"

    bind -m insert cw "__vi_kill_forward '$next_word_end' 1"
    bind -m insert ce "__vi_kill_forward '$next_word_end' 1"

    bind -M insert \cf forward-word
    bind -M insert \cl accept-autosuggestion
    bind -M insert \cj accept-autosuggestion end-of-line execute
end
