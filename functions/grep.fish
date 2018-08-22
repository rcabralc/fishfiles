if not string match -e Android (uname -a) >/dev/null
    function grep
        command grep --color=auto $argv
    end
end
