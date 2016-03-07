function fish_right_prompt
    if test (rbenv version-name) != 'system'
        set_color grey
        printf '%s ' (rbenv version-name)
        set_color normal
    end

    set_color bryellow
    printf '%s ' (date "+%d/%m")
    set_color normal
    set_color brown
    printf '%s ' (date "+%Hh%M")
    set_color normal
    set_color red
    printf '⚡%s ' (battery_prompt)
end
