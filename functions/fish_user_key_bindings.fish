function fish_user_key_bindings
    fish_vi_key_bindings

    bind -M insert \cp up-or-search
    bind -M insert \cn down-or-search

    bind -M insert \co complete
    bind -M insert \t accept-autosuggestion end-of-line
    bind -M insert \cf forward-word
end
