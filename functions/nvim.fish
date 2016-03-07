function nvim --wraps=nvim
    if test -z $NVIM_LISTEN_ADDRESS
        command nvim $argv
    else
        if test -z $argv
            nvr -c new
        else
            nvr $argv
        end
    end
end
