function ssh_agent --description 'launch the ssh-agent and add identities'
    command -v pass >/dev/null; or return
    command -v expect >/dev/null; or return

    set -q SSH_AGENT_PID
        and kill -0 $SSH_AGENT_PID 2>/dev/null
        and grep -q '^ssh-agent' /proc/$SSH_AGENT_PID/cmdline

    if test $status -ne 0
        set -Uxe SSH_AGENT_PID
        set -Uxe SSH_AUTH_SOCK
        eval (command ssh-agent -c | sed 's/setenv/set -Ux/') >/dev/null
        echo "ssh-agent has pid $SSH_AGENT_PID"
    end

    set -gxe SSH_ASKPASS
    for identity in (ls ~/.ssh/*.pub | sed 's/\.pub$//')
        set -l fingerprint (ssh-keygen -lf $identity | awk '{print $2}')
        if not ssh-add -l | grep -q $fingerprint
            set -l expect_file ~/.local/ps.expect
            set -l password (pass show ssh/(basename $identity) | head -n 1 | sed 's/\$/\\\\x24/g')
            echo "log_user 0" > $expect_file
            echo "spawn ssh-add -q $identity" >> $expect_file
            echo "expect \"Enter passphrase\"" >> $expect_file
            echo "send -- $password" >> $expect_file
            echo "send \r" >> $expect_file
            echo "expect eof" >> $expect_file
            echo "pass show ssh/$pwitem | head -n 1" | cat - >> ~/.local/bin/ps.sh
            expect $expect_file
            shred -u $expect_file
        end
    end
end
