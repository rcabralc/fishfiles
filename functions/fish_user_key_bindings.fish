function fish_user_key_bindings
    fish_vi_key_bindings

    bind -M insert \ef accept-autosuggestion
    bind -M insert \ej accept-autosuggestion execute
end
