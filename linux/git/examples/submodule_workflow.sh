
# Initial add
git submodule add https://github.com/MioPrint/mio-shell.git submodules/mio-shell
# + commit 

# Someone else clones your repo
git clone --recurse-submodules https://github.com/MioPrint/mio-shell.git
# or after a plain clone:
git submodule update --init --recursive

# Update the submodule to the latest commit on the tracked branch
git submodule update --remote submodules/mio-shell
# + commit 

# Pin to a specific commit (e.g. for a hotfix)
cd lib/shared
git checkout <sha>
# + commit

# Common gotcha
# If you add a submodule and then change its URL later (e.g. rename the repo), 
# you must run:
git submodule set-url submodules/mio-shell <new-url>
git submodule sync # propagate to all clones
