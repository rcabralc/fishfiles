function dedup_path --description 'Workaround some $PATH entries being duplicated (I have no idea why)'
    set -l NEWPATH
    for p in $PATH
        if not contains $p $NEWPATH
            set NEWPATH $NEWPATH $p
        end
    end
    set PATH $NEWPATH
end
