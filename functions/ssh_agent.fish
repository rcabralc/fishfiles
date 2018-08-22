function ssh_agent --description 'launch the ssh-agent and add identities'
    command -v pass >/dev/null; or return

    # Un-shadow universal variables
    set -ge SSH_AGENT_PID
    set -ge SSH_AUTH_SOCK

    ssh-add -l >/dev/null 2>/dev/null
    # Agent is not running or is not accessible.
    test $status -eq 2; and eval (command ssh-agent -c | sed 's/setenv/set -Ux/')

    for identity in (ls ~/.ssh/*.pub | sed 's/\.pub$//')
        set -l fingerprint (ssh-keygen -lf $identity | awk '{print $2}')
        ssh-add -l | grep -q $fingerprint
            # pipe needed to remove terminal from ssh-add
            or echo ignored | \
                env SSH_ASKPASS=$HOME/.config/fish/bin/askpass DISPLAY= \
                ssh-add $identity \
                2>/dev/null
    end
end
