#!/bin/bash
git clone git@github.com:IMSoP/my-settings ~/my-settings
for file in .ackrc .bashrc .gitconfig .screenrc .vimrc
do
    if [ -L ~/$file ]
    then
        echo -n "~/$file is already a symlink: "
        ls -l ~/$file
    elif [ -f ~/$file ]
    then
        mv --backup=numbered ~/$file ~/$file.backup
	ln -s ~/my-settings/linux-home/$file ~/$file
    else
	ln -s ~/my-settings/linux-home/$file ~/$file
    fi
done
echo
echo 'All done; run the following to load bash settings:'
echo '. ~/.bashrc'
