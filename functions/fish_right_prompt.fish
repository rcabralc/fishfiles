function fish_right_prompt
    set sep ""

    set batteryprompt (battery_prompt)
    if test $status -eq 0
        set_color brred
        printf "$sep%s" $batteryprompt
        set_color normal
        set sep " "
    end
end
