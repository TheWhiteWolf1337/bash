#!/bin/bash

# Inspired By helmuthdu
  usage(){
    echo "Usage: bit [options]"
    echo "  --init                                              Autoconfigure git options"
    echo "  a, [add] <files> [--all]                            Add git files"
    echo "  c, [commit] <text> [--undo]                         Add git files"
    echo "  C, [cherry-pick] <number> <url> [branch]            Cherry-pick commit"
    echo "  b, [branch] feature|hotfix|<name>                   Add/Change Branch"
    echo "  d, [delete] <branch>                                Delete Branch"
    echo "  l, [log]                                            Display Log"
    echo "  m, [merge] feature|hotfix|<name> <commit>|<version> Merge branches"
		echo "  n, [new]                                            Add curent directory to a new Github Repository"
    echo "  p, [push] <branch>                                  Push files"
    echo "  P, [pull] <branch> [--force]                        Pull files"
    echo "  r, [release]                                        Merge unstable branch on master"
		echo "  u, [update]                                         Update current directory"
      return 1
    }
    case $1 in
      --init)
      local NAME=`git config --global user.name`
      local EMAIL=`git config --global user.email`
      local GITUSER=`git config --global github.user`
      local EDITOR=`git config --global core.editor`

      [[ -z $NAME ]] && read -p "Name: " NAME
      [[ -z $EMAIL ]] && read -p "Email: " EMAIL
      [[ -z $USER ]] && read -p "Username: " USER
      [[ -z $EDITOR ]] && read -p "Editor: " EDITOR

      git config --global user.name $NAME
      git config --global user.email $EMAIL
      git config --global github.user $USER
      git config --global color.ui true
      git config --global color.status auto
      git config --global color.branch auto
      git config --global color.diff auto
      git config --global diff.color true
      git config --global core.filemode true
      git config --global push.default matching
      git config --global core.editor $EDITOR
      git config --global format.signoff true
      git config --global alias.reset 'reset --soft HEAD^'
      git config --global alias.graph 'log --graph --oneline --decorate'
      git config --global alias.compare 'difftool --dir-diff HEAD^ HEAD'
      if which meld &>/dev/null; then
        git config --global diff.guitool meld
        git config --global merge.tool meld
      elif which kdiff3 &>/dev/null; then
        git config --global diff.guitool kdiff3
        git config --global merge.tool kdiff3
      fi
      git config --global --list
      ;;
    a | add)
      if [[ $2 == --all ]]; then
        git add -A
      else
        git add $2
      fi
      ;;
    b | branch )
      check_branch=`git branch | grep $2`
      case $2 in
        feature)
          check_unstable_branch=`git branch | grep unstable`
          if [[ -z $check_unstable_branch ]]; then
            echo "creating unstable branch..."
            git branch unstable
            git push origin unstable
          fi
          git checkout -b feature --track origin/unstable
          ;;
        hotfix)
          git checkout -b hotfix master
          ;;
        master)
          git checkout master
          ;;
        *)
          check_branch=`git branch | grep $2`
          if [[ -z $check_unstable_branch ]]; then
            echo "creating $2 branch..."
            git branch $2
            git push origin $2
          fi
          git checkout $2
          ;;
      esac
      ;;
    c | commit )
      if [[ $2 == --undo ]]; then
        git reset --soft HEAD^
      else
        git commit -am "$2"
      fi
      ;;
    C | cherry-pick )
      git checkout -b patch master
      git pull $2 $3
      git checkout master
      git cherry-pick $1
      git log
      git branch -D patch
      ;;
    d | delete)
      check_branch=`git branch | grep $2`
      if [[ -z $check_branch ]]; then
        echo "No branch founded."
      else
        git branch -D $2
        git push origin --delete $2
      fi
      ;;
    l | log )
      git log --graph --oneline --decorate
      ;;
    m | merge )
      check_branch=`git branch | grep $2`
      case $2 in
        --fix)
          git mergetool
          ;;
        feature)
          if [[ -n $check_branch ]]; then
            git checkout unstable
            git difftool -g -d unstable..feature
            git merge --no-ff feature
            git branch -d feature
            git commit -am "${3}"
          else
            echo "No unstable branch founded."
          fi
          ;;
        hotfix)
          if [[ -n $check_branch ]]; then
              # get upstream branch
            git checkout -b unstable origin
            git merge --no-ff hotfix
            git commit -am "hotfix: v${3}"
            # get master branch
            git checkout -b master origin
            git merge hotfix
            git commit -am "Hotfix: v${3}"
            git branch -d hotfix
            git tag -a $3 -m "Release: v${3}"
            git push --tags
          else
            echo "No hotfix branch founded."
          fi
          ;;
        *)
          if [[ -n $check_branch ]]; then
            git checkout -b master origin
            git difftool -g -d master..$2
            git merge --no-ff $2
            git branch -d $2
            git commit -am "${3}"
          else
            echo "No unstable branch founded."
          fi
          ;;
      esac
      ;;
    p | push )
      git push origin $2
      ;;
    P | pull )
      if [[ $2 == --force ]]; then
        git fetch --all
        git reset --hard origin/master
      else
        git pull origin $2
      fi
      ;;
    u | update )
      if [ "$2" != "" ]; then
        git add -A > /dev/null
        git commit -m "$2" > /dev/null
        gitout=$(git push origin master 2>&1)
        echo "$gitout" | tail -n4
      else
        git add -A > /dev/null
        git commit -m "Update" > /dev/null
        gitout=$(git push origin master 2>&1)
        echo "$gitout" | tail -n4
      fi
        ;;
    r | release )
      git checkout origin/master
      git merge --no-ff origin/unstable
      git branch -d unstable
      git tag -a $2 -m "Release: v${2}"
      git push --tags
      ;;
    n | new )
      if [ -d ".git" ]; then
          :
      else git init
      fi
      read -r -p "Do you want to use SSH on Github? [Y/n] " input
      case $input in
              [yY][eE][sS]|[yY])
          ssh="yes"
          ;;
              [nN][oO]|[nN])
          ssh="no"
          ;;
              *)
            echo "Invalid input..."
          exit 1
          ;;
      esac

      read -rep $'What shall the new repo be called? \n' REPO
      USER=$(cat ~/.gitconfig | grep name | cut -d ' ' -f3)
      curl -u $USER https://api.github.com/user/repos -d '{"name" : "'$REPO'"}'

      if [ -f "README.md" ]; then
        :
      else
        echo "<h1 align="center">$REPO</h1>
        <h3 align="center">This is a description of $REPO</h3>

        ## Features

        * Feature 1
        * Feature 2
        * Feature 3
        * Feature 4

        ## Usage

        \`\`\`
        Example code for $REPO
        \`\`\`
        ## Installation

        ### Prerequisites

        To build $REPO  from source, you need this, this, and this.

        #### Fedora / RHEL / etc.

        \`\`\`
        sudo dnf install this this this
        \`\`\`

        #### Ubuntu / Mint / Elementary / etc.

        \`\`\`
        sudo apt-get install this this this
        \`\`\`

        #### Arch Linux

        \`\`\`
        sudo pacman -S this this this
        yaourt -S this this this
        \`\`\`

        #### Void Linux

        \`\`\`
        sudo xbps-install this this this
        \`\`\`

        ### Building

        \`\`\`
        git clone https://github.com/$USER/$REPO.com
        cd $REPO
        mkdir build
        cd build
        cmake ..
        make
        sudo make install
        \`\`\`
        ## Goals
        - Goal 1
        - Goal 2

        ## Support

        | Thing 1 | Thing 2 | Thing 3 |
        |---------|---------|---------|
        | Item 1  | yes | no		  |
        | Item 2  | yes | no         |

        ## ToDos

        - [x] Accomplished Objective 1
        - [ ] Todo 1
        - [x] Accomplished Objective 2
        - [ ] Todo 2

        #### Warning
        **USE IT AT YOUR OWN RISK - YOU ARE RESPONSIBLE FOR BACKING UP AND RESTORING YOUR DATA**

        ## screenshot

        ![This is a screenshot of $REPO ](screenshot.png)

        Contributors and THANKS!
        ------------------------

        Thanks go to:

        * Everyone
        * That
        * Helped

        ## license

        This project is license used the MIT license. See [LICENSE](LICENSE) for more details." > README.md
      fi
      if [ "$ssh" == "yes" ]; then
        git remote add origin git@github.com:$USER/$REPO.git
      else
        git remote add origin https://github.com/$USER/$REPO.git
      fi
      git add -A
      git commit -m "First Commit"
      git push origin master
      ;;
    *)
      usage
  esac
