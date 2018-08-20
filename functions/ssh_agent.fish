function ssh_agent --description 'launch the ssh-agent and add identities'
    command -v pass >/dev/null; or return
    test -x ~/.local/bin/askpass; or return

    set -gx SSH_ASKPASS ~/.local/bin/askpass

    set -q SSH_AGENT_PID
        and kill -0 $SSH_AGENT_PID 2>/dev/null
        and grep -q '^ssh-agent' /proc/$SSH_AGENT_PID/cmdline

    if test $status -ne 0
        set -Uxe SSH_AGENT_PID
        set -Uxe SSH_AUTH_SOCK
        eval (command ssh-agent -c | sed 's/setenv/set -Ux/') >/dev/null
        echo "ssh-agent has pid $SSH_AGENT_PID"
    end

    for identity in (ls ~/.ssh/*.pub | sed 's/\.pub$//')
        set -l fingerprint (ssh-keygen -lf $identity | awk '{print $2}')
        ssh-add -l | grep -q $fingerprint; or ssh-add $identity >/dev/null
    end
end