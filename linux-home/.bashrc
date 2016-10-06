#
## Options which must be set only in interactive (or non-interactive) environment
#

case $- in
*i*)    # interactive mode only
	# show return status $? and number of jobs \j in prompt
	export PS1='$(RET=$?; if [ $RET == 0 ]; then echo "\[\033[1;30m\]$RET"; else echo "\[\033[0;31m\]$RET"; fi;) \[\033[1;32m\]\u@\h $(if [ "$PSWARN" ]; then echo "\[\033[1;31m\]$PSWARN"; fi;)\[\033[1;34m\]\w $(if [ \j != 0 ]; then echo "\[\033[0;33m\]\j \[\033[1;34m\]"; fi;)\$$(if [ $TERM = "screen" ]; then echo \$; fi;)\[\033[00m\] '
	export HISTCONTROL='ignoredups:erasedups'
	export HISTTIMEFORMAT='(%Y-%m-%d %H:%M:%S)  '

	stty stop '' # disable that annoying Ctrl-S
	stty start '' # in which case Ctrl-Q is kinda useless
	bind "set completion-ignore-case on" # Thanks Tristan
	
	# Weird hackaroo for "SSH here" Windows thingy
	if ( [ -e .nextdir.tmp ] )
	then
		cd `cat .nextdir.tmp`;
		rm -f ~/.nextdir.tmp;
	fi;
;;
*)      # non-interactive script
;;
esac

#
## Bash and environment setup
#

# Programmable completion
complete -A command man
complete -A command vman
complete -A command which

# Environment variables used by various commands
export PAGER='/usr/bin/less -FX'
export EDITOR='/usr/bin/vim'

# Pick up any commands in my home directory
[ -d ~/bin ] && PATH=$PATH:~/bin 

#
## A few abbrevs for common commands
#

# Standard safety trap
alias rm='rm -i '

alias grep='grep --color=auto '
alias mygrep='egrep --color=auto -i '
alias ls='ls --color=auto '
alias l='ls '
alias ll='ls -alh '
alias j='jobs'
alias h='history'
alias s='if [ $TERM != "screen" ]; then exec screen -xR; fi'
# like 'cat' for small files, 'less' for big ones
alias les='less -FX'
# I keep forgetting what this bloody command is called!
# alias ftp='ncftp'

alias today="date +'%Y-%m-%d'"

alias nononsense='egrep -v "nbproject|~\$|Thumbs.db|\.marks$|^\.#|^#.*#\$|\.swp|\.bak\$"'
alias leaders='sort | uniq -c | sort -n | tail '

# Silent Secure Shell
sssh() { ssh -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no' -o 'ConnectTimeout 5' -o 'PreferredAuthentications publickey' $* 2>/dev/null; }  

#
## Config management
#

# I'm always editting and reloading this file
alias confedit='vi ~/.bashrc'
alias confload='. ~/.bashrc'

# Keep config up to date on all servers
sync_config()
{ 
	for srv in $(cat ~/.ssh/config | plgrep '^host (.*)$' '$1');
	do 
		echo "Syncing to $srv...";

		if ( [ "$1" ] ); 
		then 
			scp -o 'ConnectTimeout 5' -o 'PreferredAuthentications publickey' "$1" $srv:"$1"; 
		else 
			scp -o 'ConnectTimeout 5' -o 'PreferredAuthentications publickey' ~/.bashrc ~/.vimrc ~/.screenrc $srv:; 
		fi; 
	done;
}

#
## General custom commands and canned one-liners
#

# Handy warnings in my PS1 prompt
warn() { [ "$1" ] && PSWARN="${PSWARN/$1 /}$1 "; }
nowarn() { [ "$1" ] && PSWARN="${PSWARN/$1 /}"; }

# Some list-building magic
remember() { eval "$1='${!1} $2'"; eval "$1='${!1## }'"; }
forget() { unset -v $1; }

# Pseudo-sudo, sudo voodoo, and "Only root can do that." "I *am* root!"
if $(which sudo &> /dev/null);
then 
	# sudo in use: expand aliases after it
	alias sudo='sudo ';
	alias iamroot='sudo $(fc -nl -1) ';
else 
	# No sudo: use su -c, which is sort of similar
	sudo() { echo -n 'Root '; su -c "$*"; };
	alias iamroot='echo -n "Root "; su -c "$(fc -nl -1)" ';
fi

# View man pages using VIM; not sure if I want it as default yet
alias vman="MANPAGER=\"col -b | view -c 'set ft=man nomod nolist' -\" man "

# Make folder happy for webserver
chapache() { chmod -R 770 $*; chgrp -R apache $*; }
chwww() { chmod -R 770 $*; chgrp -R www-data $*; }
suchwww() { sudo chmod -R 770 $*; sudo chgrp -R www-data $*; }
# View today's logs for a site (e.g. `logview NCL`, `logview NCL tailf`)
logview() { ${2:-less -FX} ~dev/apache/logs/$1/$(today).log; }
# View combined PHP logs for a site
phplogs() { for file in ~dev/apache/logs/$1/php_errors.log*; do zcat -f $file | tac; done | tac | ${2:-less -FX}; }
# Tokenize an apache log, and output named fields, conditionally
# e.g. logview NCLUK cat | apachegrep '$ip' | leaders
# e.g. logview NCLUK cat | apachegrep '$req -FROM- $referer' 'if $status == 500'
apachegrep()
{
	local pattern='^([0-9.]+) ([^]]+) (\[.+?\]) ("[^"]+") (\d{3}) (\d+|-) ("[^"]+"|[^ ]+) ("[^"]+")$';
	perl -ne "(\$ip,\$auth,\$time,\$req,\$status,\$size,\$referer,\$useragent)=m#$pattern#i;
	print ('$1' ? \"$1\\n\" : \$_) $2;";
}

alias xfer='mkdir ~/xfer/$(today); cd ~/xfer/$(today); start-ssh-agent;'

# Filter the logs from multi-process script like C2CRecon based on a set of current lock files
# e.g. logbylocks ~dev/scripts/_Logs/C2CRecon-RECONAMA.log /var/cwt/C2CRecon/locks/RECONAMA.SUMMARISE.COB_UPDATED.BATCH-
logbylocks()
{
	pidlist=$(for lockfile in $2*; do printf '|%5s' $(cat $lockfile); done)
	tail -f $1 | egrep "\\[[KP]ID (${pidlist:1})"
}

# Easier than re-typing the whole "mv" command
unmv() { mv $2 $1; }
# Mostly generalised version of above
undo() { $1 $3 $2 $4 $5 $6 $7 $8 $9; }

# A useful set of recurisive diff options (unidiff format, show new files, exclude cache directory)
alias diffsite="diff -urN -x'cache' -x'.svn'"
alias diffapp="diff -urN -x'.svn' "
# Compare live and staging gateway modules
diffmodule() { diff -urN ~dev/public/CWT/CustomerGateway-1.8/modules/$1-$2 ~dev/public/CWT/CustomerGateway-1.8-staging/modules/$1-$3 $4; }

# Compare the file listings of a directory on two servers (does NOT compare contents!)
# (Use "serverdiff dir srv1 srv2")
serverdiff () { diff -wu <(ssh $2 "find $1 | sort") <(ssh $3 "find $1 | sort"); }

# Convert Windows-y slashes to *nix-y ones [$1:the var /:substitute /:substitute all \\:a backslash, escaped /:end pattern /:replacement string]
slashes() { echo "${1//\\//}"; }
# The reverse; occasionally useful
# Confuses VIM's syntax highlighting, which is irritating # unslashes() { echo "${1//\//\\}"; }
# Go to a directory based on a Windows path, such as \\ho12\rowanc\development\...
wincd() { cd $(slashes ${1/#\\\\$(hostname)//home}); }
# As above, but just echo the path - use e.g. vi $(winpath '\\ho12\...\index.php')
winpath() { echo $(slashes ${1/#\\\\$(hostname)//home}); }
# Move to a directory with a similar name to the current one: e.g. `editdir 1.2 1.2-staging`
editdir() { cd ${PWD/$1/$2}; }

# Convert a Unix timestamp to something more readable
udate() { php -r "echo date('Y-m-d H:i:s', $1);"; echo; }

# Check which server a site's on (e.g. `checkserver designertravel.co.uk`)
whichserver() { ssh -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no' -o 'ConnectTimeout 5' -o 'PreferredAuthentications publickey' $1 'hostname' 2>/dev/null; }  

# grep -r on a SVN checkout returns lots of false positives in .svn control dirs; this doesn't
# alias cat-svn="find -name .svn -prune -o -type f -exec cat '{}' ';' "
# Just use `ack`!

# And talking of ack, turn ack results into vim commands
semivack() { ack $* | while read match; do echo "$match" | plgrep '^(.*?):(\d+)' 'vim $1 +$2'; done; }

# Better: turn ack results into vim *tabs*!
vack() { vim -s <(ack -m1 $* | plgrep '^(.*?):(\d+)' ':tabnew +$2 $1'; echo :tabfirst; echo :tabclose); }

# For the sake of portability, here's one with less dependencies
vgrep() { vim -s <(grep -R -H -n -m1 $* | grep -v '.svn' | sed 's/^\(.*\):\([0-9]\+\):.*$/:tabnew +\2 \1/';  echo :tabfirst; echo :tabclose); }

# And, generally, how to open several files in vim tabs:
vimtabs() { vim -s <(for file in "$@"; do echo ":tabnew $file"; done; echo :tabfirst; echo :tabclose); }

# An interactive Perl "shell"
alias iperl=$'perl -e \'$|=1; while(<>) {$COMMAND=$_; $_=$UNDERSCORE; $RESULT=eval $COMMAND; print STDERR $@; $UNDERSCORE=$_}\''

# Like grep, but using Perl; ... | plgrep regex [output]; e.g. `echo foo | plgrep 'f(.*)' '$1'` 
plgrep() { perl -ne "m#$1#i and print '$2' ? \"$2\\n\" : \$_;"; }
plgrepall() { perl -ne "@m = m#$1#gi and print (join '$2' ? \"$2\" : \"\\n\", @m) and print \"\\n\";"; }

# Send myself (or someone else) an e-mail from a pipe; e.g. `echo hello | phmail 'Note to self'`
phmail() { php -r 'mail($argv[1], $argv[2], file_get_contents("php://stdin"));' "${2:-$(whoami)+cmdline@clickwt.com}" "${1:-Command-Line Mail}"; }

# Grab a single column out of a CSV file, using PHP's fgetcsv() to parse the format
cutcsv() { php -r 'while($line = fgetcsv(STDIN)) { echo $line[$argv[1]], PHP_EOL; }' $1; }

# Quick'n'dirty XPath grep tool using PHP's SimpleXML - hey, it works!
xpath()
{
	php -r '
		array_shift ( $argv );
		if ( $argv[0] == "-t" )
		{
			array_shift($argv);
			$text_only = true;
		}
		$expression = $argv[0];

		$x=simplexml_load_file("php://stdin");
		$matches = $x->xpath($expression);
		
		if (! is_array($matches)) { die(1); }
		foreach($matches as $node)
		{
			if ( $text_only )
			{
				echo (string)$node, "\n";
			}
			else
			{
				echo $node->asXML(), "\n";
			}
		}
	' -- "$1" "$2" "$3" "$4";
}

# Highlight the given regex on stdin; if given, the second argument sets the colour 
highlight() {
	perl -pe "
		select((select(STDOUT), \$|=1)[0]); # Make STDOUT 'hot' so it can be attached to pipes without buffering
		\$red	 = \`tput setaf 1\`; 
		\$green	 = \`tput setaf 2\`; 
		\$yellow = \`tput setaf 3\`; 
		\$blue	 = \`tput setaf 4\`; 
		\$magenta= \`tput setaf 5\`; 
		\$cyan	 = \`tput setaf 6\`; 
		\$white	 = \`tput setaf 7\`;
		\$reset	 = \`bash -c \"echo -n -e '\\e[m'\"\`;
		s/($1)/\$${2:-green}\$1\$reset/gi"
}

# Find functions which aren't referenced anywhere else in the current directory (not 100% accurate!)
unused_funcs() {
	file="$1"; # optional: if not specified, matches will be listed with file names
	for file_line_func in $(ack --php 'function\s+([a-zA-Z0-9_]+)\(' --output='$1' $file); 
	do 
		func=$(echo $file_line_func | cut -d':' -f3); 
		if ([ $(ack --php "$func\\s*\\("| wc -l) -lt 2 ] );
		then 
			echo $file_line_func | cut -d':' -f1,3; 
		fi; 
	done 
}
unused_private_funcs() {
	file="$1"; # optional: if not specified, matches will be listed with file names
	for file_line_func in $(ack --php 'private(?:\s+static)?\s+function\s+([a-zA-Z0-9_]+)\(' --output='$1' $file); 
	do 
		func=$(echo $file_line_func | cut -d':' -f3); 
		if ([ $(ack --php "$func\\s*\\(" $file | wc -l) -lt 2 ] );
		then 
			echo $file_line_func | cut -d':' -f1,3; 
		fi; 
	done 
}

#
## Maths!
#

min() { php -r 'echo min(array_map("trim", file("php://stdin"))), PHP_EOL;'; }
max() { php -r 'echo max(array_map("trim", file("php://stdin"))), PHP_EOL;'; }
avg() { php -r '$lines=array_map("trim", file("php://stdin")); echo count($lines) ? (array_sum($lines) / count($lines)) : 0, PHP_EOL;'; }
# Standard Deviation - functions from http://php.net/manual/en/function.stats-standard-deviation.php
stdev() { php -r 'function sd_square($x, $mean) { return pow($x - $mean,2); } function sd($array) { return sqrt(array_sum(array_map("sd_square", $array, array_fill(0,count($array), (array_sum($array) / count($array)) ) ) ) / (count($array)-1) ); } echo sd( array_map("trim", file("php://stdin")) ), PHP_EOL;'; }

# Sort version numbers correctly
# vsort() { php -r '$lines = file("php://stdin"); usort($lines, "version_compare"); echo implode($lines, "");'; }
vsort() { 	
	php -r '
                $lines = file("php://stdin");
                usort($lines, "version_compare_plus");
                echo implode($lines, "");
                function version_compare_plus($a, $b)
                {
                        $a_parts=explode("-",trim($a));
                        $b_parts=explode("-",trim($b));
                        for($i=0; $i<max(count($a_parts),count($b_parts)); $i++)
                        {
                                // One part has less hyphens than the other
                                if ( $i >= count($a_parts) ) { return -1; }

                                if ( $i >= count($b_parts) ) { return +1; }

                                if (
                                        ctype_digit( $a_parts[$i]{0} )
                                        &&
                                        ctype_digit( $b_parts[$i]{0} )
                                )
                                {
                                        // Version numbers
                                        $cmp = version_compare($a_parts[$i], $b_parts[$i]);
                                }
                                else
                                {
                                        // Stringy bits
                                        $cmp = strcasecmp($a_parts[$i], $b_parts[$i]);
                                }

                                if ( $cmp !== 0 ) { return $cmp; }
                        }
                        return 0;
                }
	';
}

# Use the above to list versions of something somewhere
# e.g. vlist ~dev/public/_PHP/Common
vlist() { echo $1* | xargs -n1 | vsort; }

#
## SSH etc
#

# SSH Agent-on-demand [NB: stop-ssh-agent should be called in .bash_logout or agents will hang around]
if ( [ -e ~/.ssh/cwt.priv ] );
then
	alias start-ssh-agent='if [ ! "$SSH_AUTH_SOCK" ] || ! ls $SSH_AUTH_SOCK &>/dev/null; then eval `ssh-agent`; ssh-add ~/.ssh/cwt.priv; fi' 
	alias stop-ssh-agent='[ $SSH_AGENT_PID ] && eval `ssh-agent -k`'
	alias ssh='start-ssh-agent; ssh'
	alias scp='start-ssh-agent; scp'
	alias sftp='start-ssh-agent; sftp'
	alias svn='start-ssh-agent; svn'
fi;

# Forwarded ports for Postgres connectivity (unclaimed port range 99xx)
start-pg-tunnel ()
{
    if ( ! pgrep -f ":$1:$2.lon.cwtdigital.com:5432" > /dev/null ); then
        if ( [ ! $SSH_AGENT_PID ] || [ ! "$(ps h -p$SSH_AGENT_PID)" ] ); then
            eval `ssh-agent`;
            ssh-add;
        fi;
	setsid ssh -nNL *:$1:$2.lon.cwtdigital.com:5432 $2.lon.cwtdigital.com > /dev/null;
    fi
}
alias start-pg-tunnels='
start-pg-tunnel 9902 deimos;
start-pg-tunnel 9903 lapetus;
start-pg-tunnel 9904 puck;
start-pg-tunnel 9905 nemo;
start-pg-tunnel 9906 dysnomia;
start-pg-tunnel 9907 echion;
start-pg-tunnel 9908 elephenor;
start-pg-tunnel 9909 agamemnon;
start-pg-tunnel 9910 belinda;
start-pg-tunnel 9911 bianca;
start-pg-tunnel 9912 ferdinand;
start-pg-tunnel 9913 caliban;
start-pg-tunnel 9914 calypso;
start-pg-tunnel 9915 elara;
start-pg-tunnel 9916 prometheus;
start-pg-tunnel 9917 kari;
start-pg-tunnel 9918 prospero;
'

# Get all attachments to an intervals task
intervals_docs ()
{
    [ "$INTERVALS_SESSION" ] || read -p 'Intervals Session Cookie: ' INTERVALS_SESSION;
    local id=$(GET https://4ysvd7zytgs:X@api.myintervals.com/task/?localid=$1 | xpath -t '//id');
    GET https://4ysvd7zytgs:X@api.myintervals.com/document/?taskid=$id \
		| xpath -t '//versions//filename|//versions//versionid' \
		| INTERVALS_SESSION="$INTERVALS_SESSION" perl -ne 'chomp($_); if ( $id ) { system "wget --header=\"Cookie: PHPSESSID=$ENV{INTERVALS_SESSION}\" -nv https://clickwt.timetask.com/documents/open/$id/ -O \"$_\"\n"; $id = ""; } else { $id = $_; }';
}

#
## Useful for managing CWT stuff
#

diffvers() { diff -wur $1$2 $1$3 | less -EX; } #use: diffvers base_name ver1 ver2
lsvers() { ls -1 $1 | grep -o ^[^-]* | uniq | xargs -i@@ bash -c "echo -n '@@ {'; ls -1 $1 | grep '^@@-' | cut -d- -f2- | xargs -i[] echo -n ' [] '; echo \};"; }
#dovers() { $1 $2 `echo $2 | sed s/$3/$4/`; } #use: dovers cmd arg1 sub1 sub2  e.g. 'dovers cp GoaCancellations-1.1.2/includes/config.php 2 3'
dovers() { $1 $2$3 $2$4; }
topvers()  { ls -1 $1 | grep -o ^[^-]* | uniq | xargs -i@@ bash -c "ls -1 $1 | grep '@@' | tail -n 1"; } 

# Useful variables
export vhosts=~dev/apache/conf/vhosts.conf
export myhosts=~dev/apache/conf/users/$(whoami).conf
export sitehosts=~dev/apache/conf/sites

# Show used ports in file (or $vhosts if none given)
vhports() { _file=$vhosts; [ $1 ] && _file=$1; egrep -o 'Listen.*' $_file | sort -t' ' -k2n; } 

# Clear old-style _Cache folder
cacheclearold()
{
	if ( [ ! $1 ] )
	then
		echo "Please specify which cache dir to clear:";
		ls ~dev/public/_Cache;
	elif ( [ ! -d ~dev/public/_Cache/$1 ] ) 
	then 
		echo "Directory ~dev/public/_Cache/$1 not found; try one of these:"; 
		ls ~dev/public/_Cache;
	else 
		read -p "Delete all files under ~dev/public/_Cache/$1 ? [Y/N] " confirmed
		if ( [ $confirmed = 'Y' ] || [ $confirmed = 'y' ] )
		then
			find ~dev/public/_Cache/$1 -type f -exec rm -v {} ';'; 
		else
			echo 'Aborted.';
			echo 'You could do just one of these sub-dirs:';
			ls ~dev/public/_Cache/$1 
		fi;
	fi; 
}

# Clear new-style in-site cache folder (rather slowly)
cacheclear2()
{
	if ( [ ! $1 ] )
	then
		echo "Please specify which cache dir to clear:";
		find ~/development/cwt/sites -type d -name 'cache' -print -a -prune
	else
		dir=$(find ~/development/cwt -type d -name 'cache' -print -a -prune | grep $1)

		if ( [[ $(echo "$dir" | wc -l) > 1 ]] )
		then
			echo -e "Multiple caches matched $1:\n$dir"
		elif ( [ ! "$dir" -o ! -d "$dir" ] )
		then 
			echo "No cache matching $1 found; try one of these:"; 
			find ~/development/cwt/sites -name 'cache'
		else 
			read -p "Delete all files under $dir ? [Y/N] " confirmed
			if ( [ $confirmed = 'Y' ] || [ $confirmed = 'y' ] )
			then
				# find $dir -name '.svn' -prune -a ! -name '.svn' -o -type f -exec rm -fv {} ';'; 
				find "$dir" -name '.svn' -prune -o -type f -exec rm -fv '{}' ';';
			else
				echo 'Aborted.';
#				echo 'You could do just one of these sub-dirs:';
#				ls ~dev/public/_Cache/$1 
			fi;
		fi; 
	fi;
}

# Clear new-style in-site cache folder (in place, e.g. on live server)
cacheclearthis()
{
	if ( [ $(basename $(pwd)) != "cache" ] )
	then
		echo "The current directory is not called 'cache'!";
		return 1;
	else
		local dir=${1:-.};

		if ( [ ! "./$dir" -o ! -d "./$dir" ] )
		then 
			echo "No subdirectory matching $1 found; try one of these:"; 
			find . --maxdepth 3 type d -name '.svn' -prune -o ! -name '.svn' -type d -print
		else 
			read -p "Delete all files under $dir ? [Y/N] " confirmed
			if ( [ $confirmed = 'Y' ] || [ $confirmed = 'y' ] )
			then
				find "$dir" -name '.svn' -prune -o -type f -exec rm -fv '{}' ';';
			else
				echo 'Aborted.';
				echo 'You could do just one of these sub-dirs:';
				find "$dir" -maxdepth 3 -type d -name '.svn' -prune -o ! -name '.svn' -type d -print
			fi;
		fi; 
	fi;
}

# Because I don't have enough versions already...
cacheclear()
{
	local dir=$(readlink -f ${1:-.});

	if ( [ "$2" != '--force' ] && [[ ! "$dir" =~ cache ]] && [[ ! "$dir" =~ Cache ]] )
	then
		echo "The directory path '$dir' doesn't contain the word 'cache'! (Add --force if you meant to do this...)";
		return 1;
	else
		read -p "Delete all files under $dir ? [Y/N] " confirmed
		if ( [ $confirmed = 'Y' ] || [ $confirmed = 'y' ] )
		then
			find "$dir" -name '.svn' -prune -o -type f -exec rm -fv '{}' ';';
			return 0;
		else
			echo 'Aborted.';
			echo 'You could do just one of these sub-dirs:';
			find "$dir" -maxdepth 3 -type d -name '.svn' -prune -o ! -name '.svn' -type d -print;
			return 2;
		fi;
	fi;
}

# Alias and programmable completion for the Metadata Importer
# NOTE: this alias points at a particular version; if someone deploys a new version, it will either break, or run the wrong code!
if [ -f '/home/dev/scripts/MetadataImport-1.7.2/import.php' ]
then
	alias import='php /home/dev/scripts/MetadataImport-1.7.2/import.php';
else
	alias import='php /home/dev/scripts/MetadataImport-1.7.0/import.php';
fi;
_importcomplete() { COMPREPLY=($(compgen -W "--list --all -v -vv --verbose --debug --force-lock --fake $(import --list | sed -ne'2,$p' | cut -d' ' -f2)" -- "${COMP_WORDS[$COMP_CWORD]}")); }
complete -F _importcomplete import

# bumpdb()
# {
# 	createdb -U root -O postgres -E UNICODE -T $1 $2;
# 	vacuumdb -U root -z -d $2;
# }
bumpdb ()
{
    if ( [ -e $1.bak ] || [ -e $1.bak.fixed ] ); then
        echo Refusing to overwrite existing backup files;
        return 1;
    fi;
    pg_dump $1 -U root -f $1.bak;
    iconv -c -f UTF8 -t UTF8 -o $1.bak.fixed $1.bak;
    createdb -U root -O postgres -E UNICODE -T template1 $2;
    psql -U root $2 < $1.bak.fixed;
    vacuumdb -U root -z -d $2;
    rm -i $1.bak $1.bak.fixed
}

# Clear the DB cache for a C2C offer using the awesome power of iPHP (see SVN:scripts/iPHP)
c2c-uncache() { echo -e '@@common trunk \n @@db_select click2cruise \n @@db update amadeusoffers set lastupdated=0 where offerid =' $1 | i.php -s; }


#
## Subversion bits and tricks
#

# What's the newest revision in the repository?
svn_head() { svnlook youngest $SVNFSROOT; }

# How to test all the SVN craziness
svntest() { SVNROOT=svn+ssh://$(whoami)@svn.cwtdigital.com/home/dev/svn/test; SVNROOT_RO=$SVNROOT; SVNFSROOT=/home/dev/svn/test; SVNCHECKOUT=~/development/test; warn svntest; }
# BeanStalk
svntwick() { SVNROOT=https://click-with-technology-ltd.svn.beanstalkapp.com/twickenham; SVNROOT_RO=$SVNROOT; SVNFSROOT=''; SVNCHECKOUT=~/development/twickenham; warn twickenham; }
# svntest remains in effect until svnlive is run
svnlive() { SVNROOT=svn+ssh://$(whoami)@svn.cwtdigital.com/home/dev/svn/cwt; SVNROOT_RO=$SVNROOT; SVNFSROOT=/home/dev/svn/test; SVNCHECKOUT=~/development/cwt; nowarn svntest; nowarn twickenham; }

# Update working copy non-interactively, but highlight conflicts
# svnup() { svn up --accept postpone $1 | highlight '^[CE].+' red | highlight '^G.+' green; }

# Real-time watch of SVN commits
svnwatch()
{
	x=$[ $(svn_head) - 5 ];
	while(true)
	do
		x2=$(svn_head);
		if ( [[ $x -lt $x2 ]] ) 
		then
			svn log -v $SVNROOT -r$[$x+1]:$x2 --incremental;
			x=$x2;
		fi;
		sleep 5;
	done;
}

svnrev()
{
	local rev=$1; shift;
	svn log $SVNROOT -c$rev; echo; svn diff $SVNROOT -c$rev --diff-cmd=diff -x'-wu' $*;
}

# SVN statistical silliness
function highscores()
{
	clear;
	svn log -q $SVNROOT -r${1:-0}:${2:-HEAD} | grep -v 'neilk \| 2011-02' | plgrep '\| (\d{4}-\d{2}-\d{2})' '$1' | uniq -c | sort -rn | php -B $'
		$RED    = exec("tput setaf 1");
		$GREEN  = exec("tput setaf 2");
		$YELLOW = exec("tput setaf 3");
		$BLUE   = exec("tput setaf 4");
		$MAGENTA= exec("tput setaf 5");
		$CYAN   = exec("tput setaf 6");
		$WHITE  = exec("tput setaf 7");
		$BGRED  = exec("tput setab 1");
		$RESET  = exec("echo -ne \'\e[m\'");
	' -R $'
		list($n,$d)=preg_split(\'/\s+/\', trim($argn), 2);
		$ago=abs(intval( (strtotime($d) - time()) / (24*60*60) ));
		$weekday=date("D", strtotime($d));
		if ($prev && $n != $prev) { $rank++; printf("#%2d   %2d   %s\n", $rank, $prev, $line); $line=""; $line_length=0;} 
		if( $line_length > 8 ) { $d="+"; }
		if( $ago==0 ){ $d="$GREEN$d$RESET"; }
			elseif( $ago<=20 ){ $d="$CYAN$d$RESET"; }
			elseif( $ago<=100 ){ $d="$YELLOW$d$RESET"; }
		if( $weekday=="Sat" || $weekday=="Sun" ){ $d="$BGRED$d$RESET"; }
		$line.="$d "; $line_length++; $prev=$n;
	' -E '$rank++; printf("#%2d   %2d   %s\n", $rank, $n, $line);' | les;
}

# SVN deployment tools factored out to share around
[ -f ~/development/cwt/scripts/SVNTools/trunk/svntools.sh ] &&
	source ~/development/cwt/scripts/SVNTools/trunk/svntools.sh

[ -f ~dev/scripts/Robble/robble.sh ] &&
	source ~dev/scripts/Robble/robble.sh

# There's also some handy shell scripts in there
[ -d ~/development/cwt/scripts/SVNTools/trunk/ ] &&
	PATH=$PATH:~/development/cwt/scripts/SVNTools/trunk/

# When SVNTools loads, it resets to live mode, so make sure we're consistent
svnlive

