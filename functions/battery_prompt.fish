function battery_prompt
    function battery_is_charging
        test (acpi | grep -c '^Battery.*Charging') -gt 0
        return $status
    end

    function battery_is_discharging
        test (acpi | grep -c '^Battery.*Discharging') -gt 0
        return $status
    end

    function battery_pct_remaining
        echo (acpi | cut -f2 -d ',' | tr -cd '[:digit:]')
    end

    function battery_time_remaining
        echo (acpi | cut -f3 -d ',')
    end

    which acpi
    if test $status -ne 0
        return 1
    end

    if battery_is_discharging
        set -l b (battery_pct_remaining)

        if test $b -gt 50
            set color green
        else if test $b -gt 20
            set color brown
        else
            set color red
        end

        set_color $color
        printf "$b%%-%s" (battery_time_remaining)
    else if battery_is_charging
        set -l b (battery_pct_remaining)

        set_color green
        printf "$b%%"
    else
        set_color green
        printf "AC"
    end

    set_color normal
end
