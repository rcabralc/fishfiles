function fish_right_prompt
    if test (rbenv version-name) != 'system'
        set_color $monokai_lightgray -o
        printf '%s ' (rbenv version-name)
        set_color normal
    end

    set_color $monokai_yellow
    printf '%s ' (date "+%d/%m")
    set_color $monokai_orange
    printf '%s ' (date "+%Hh%M")
    set_color $monokai_magenta
    printf '⚡%s ' (battery_prompt)
end
