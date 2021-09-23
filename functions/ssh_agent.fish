function ssh_agent --description 'launch the ssh-agent and add identities'
    command -v pass >/dev/null; or return
    command -v ssh-agent >/dev/null; or return

    # ~/.ssh exists and is accessible.
    test -x ~/.ssh; or return

    # Un-shadow universal variables
    set -ge SSH_AGENT_PID
    set -ge SSH_AUTH_SOCK

    ssh-add -l >/dev/null 2>/dev/null
    # Agent is not running or is not accessible.
    test $status -eq 2; and eval (command ssh-agent -c | sed 's/setenv/set -Ux/')

    for identity in (find ~/.ssh/ -name '*.pub' | sed 's/\.pub$//')
        set -l fingerprint (ssh-keygen -lf $identity | awk '{print $2}')
        ssh-add -l | grep -q $fingerprint
            or pass show ssh/(basename $identity) | head -n 1 | \
                setsid ssh-add $identity \
                2>/dev/null
    end
end
