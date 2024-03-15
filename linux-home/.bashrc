#
## Options which must be set only in interactive (or non-interactive) environment
#

case $- in
*i*)    # interactive mode only
	# (everything)
;;
*)      # non-interactive script
	return 0;
;;
esac

export PROMPT_COMMAND=__update_prompt
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

FMT_BLACK="$(tput setaf 0)"
FMT_RED="$(tput setaf 1)"
FMT_GREEN="$(tput setaf 2)"
FMT_YELLOW="$(tput setaf 3)"
FMT_BLUE="$(tput setaf 4)"
FMT_MAGENTA="$(tput setaf 5)"
FMT_CYAN="$(tput setaf 6)"
FMT_WHITE="$(tput setaf 7)"
FMT_GRAY="$(tput setaf 8)"
FMT_BRIGHT="$(tput bold)"
FMT_UNDERLINE="$(tput sgr 0 1)"
FMT_INVERT="$(tput sgr 1 0)"
FMT_RESET="$(tput sgr0)"

if [ -e /usr/local/bin/aws ] && [ -f /var/lib/cloud/data/instance-id ]; then
	EC2_INSTANCE_NAME="$(/usr/local/bin/aws ec2 describe-tags \
		--filters "Name=resource-id,Values=$(</var/lib/cloud/data/instance-id)" \
		--query "Tags[?Key=='Name'].Value" \
		--output text \
	)"
fi

__update_prompt() {
	local RET=$?

	# Prefer EC2 name over local hostname where available
	local short_host="${EC2_INSTANCE_NAME:-$(hostname)}"

	# Update Window / Tab title
	echo -ne "\033]0;$(whoami)@${short_host}\a" 

	local git_branch=''
	if [ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" = "true" ];
	then
		# check for what branch we're on. (fast)
		#   if… HEAD isn’t a symbolic ref (typical branch),
		#   then… get a tracking remote branch or tag
		#   otherwise… get the short SHA for the latest commit
		#   lastly just give up.
		# TODO It would be useful to overload this for e.g. `git pr`
		git_branch="$( git symbolic-ref --quiet --short HEAD 2> /dev/null || git describe --all --exact-match HEAD 2> /dev/null || git rev-parse --short HEAD 2> /dev/null || echo '?' )"
	fi
	
# 	export PS1='$(RET=$?; if [ $RET == 0 ]; then echo "\[\033[1;30m\]$RET"; else echo "\[\033[0;31m\]$RET"; fi;) \[\033[1;32m\]\u@\h $(if [ "$PSWARN" ]; then echo "\[\033[1;31m\]$PSWARN"; fi;)\[\033[1;34m\]\w $(if [ \j != 0 ]; then echo "\[\033[0;33m\]\j \[\033[1;34m\]"; fi;)\$$(if [ $TERM = "screen" ]; then echo \$; fi;)\[\033[00m\] '

	local prompt="\[\033[1;32m\]\u@${short_host}\[\033[00m\]"
  	if [ $RET == 0 ];
  	then 
  		prompt="\[\033[1;30m\]$RET\[\033[00m\] $prompt"
  	else
  		prompt="\[\033[0;31m\]$RET\[\033[00m\] $prompt"
  	fi
  	if [ "$PSWARN" ];
  	then
  		prompt="$prompt \[\033[1;31m\]$PSWARN\[\033[00m\]"
  	fi
  	prompt="$prompt \[\033[1;34m\]\w\[\033[00m\]"
  	if [ "$git_branch" ];
  	then
  		prompt="$prompt \[\033[1;30m\]$git_branch\[\033[00m\]"
  	fi

  	# This one is inlined in prompt to get access to the \j magic for number of jobs
  	prompt="$prompt\$(if [ \j != 0 ]; then echo \" \[\033[0;33m\]\j\[\033[00m\]\"; fi)"

  	prompt="$prompt \[\033[1;34m\]\$\[\033[00m\] "
 
	export PS1="$prompt"
}

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


# which appears to be broken on this server :|
unalias which &>/dev/null

# vi and vim are bound to different versions
alias vi='vim'
alias view='vim -R'

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
# For long running commands: time it, and capture the output somewhere
t() { time $@ | tee /tmp/loshg; }
# I keep forgetting what this bloody command is called!
# alias ftp='ncftp'

alias today="date +'%Y-%m-%d'"

# make a directory and cd into it
mcd() { mkdir $1 && cd $1; }
alias mcdtoday='mcd $(today)'

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
suchapache() { sudo chmod -R 770 $*; sudo chgrp -R apache $*; }
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

# Convert a Unix timestamp to something more readable; or vice versa
udate() { php -r "date_default_timezone_set('UTC'); \$input = '$1'; if ( ctype_digit(\$input) ) { echo date('Y-m-d H:i:s', \$input); } else { echo strtotime(\$input); }"; echo; }

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
phmail() { php -r 'list($to, $subject) = $argv; if ( strpos($to, "@") === false ) { list($subject, $to) = $argv; }; mail($to, $subject, file_get_contents("php://stdin"));' "${2:-$(whoami)@holidaytaxis.com}" "${1:-Command-Line Mail}"; }

# Grab a single column out of a CSV file, using PHP's fgetcsv() to parse the format
cutcsv() { php -r 'while($line = fgetcsv(STDIN)) { echo $line[$argv[1]], PHP_EOL; }' $1; }

# I don't know what cut defaults to, but I always want it cut on space
alias cutsp='cut -d" "'

alias stripspace='sed "s/^\s\+//;s/\s\+$//"'
alias stripspaceandcomments='sed "s/^\s*#//;s/^\s\+//;s/\s\+$//"'

# Quick'n'dirty XPath grep tool using PHP's SimpleXML - hey, it works!
xpath ()
{
    php -r '
                array_shift ( $argv );
                if ( $argv[0] == "-t" )
                {
                        array_shift($argv);
                        $text_only = true;
                }
                $ns = array(
                        "soap" => "http://schemas.xmlsoap.org/soap/envelope/"
                );
                while ( $argv[0] == "-n" )
                {
                        array_shift($argv);
                        $ns[ array_shift($argv) ] = array_shift($argv);
                }
                $expression = $argv[0];

                $x=simplexml_load_file("php://stdin");

                foreach ( $ns as $prefix => $uri )
                {
                        $x->registerXpathNamespace($prefix, $uri);
                }

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
        ' -- "$@"
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
export myconf=~dev/apache/conf/users/$(whoami).conf
export myhosts=~dev/apache/conf/users/$(whoami)/

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

copybranch() { local who=$1; local what=$2; git remote add $who git@github.com:$who/htx.git; git fetch $who >/dev/null; git push origin $who/$what:refs/heads/$what; }
addremote() { local who=$1; git remote add $who git@github.com:$who/htx.git; git fetch $who; }

# set-test() { pushd ~/development/htx-test; git fetch origin; git checkout "origin/$1"; popd; }
# set-test2() { pushd ~/development/htx-test2; git fetch origin; git checkout "origin/$1"; popd; }

set-test-local() {
	pushd ~/development/htx-test$1 || return 1;
	git reset --hard;
	git fetch --prune local;
	git checkout "local/$2"; 
	composer install;
	popd;
	echo "$(date +'%Y-%m-%d %H:%M') *-htx-test$1-tomminsr.htxdev.com LOCAL:$2" | tee -a ~/development/test-history;
}
set-test-github() {
	pushd ~/development/htx-test$1 || return 1;
	git reset --hard;
	git fetch --prune github;
	git checkout "github/$2"; 
	composer install;
	popd;
	echo "$(date +'%Y-%m-%d %H:%M') *-htx-test$1-tomminsr.htxdev.com GITHUB:$2" | tee -a ~/development/test-history;
}
set-test-pr() {
	pushd ~/development/htx-test$1 || return 1;
	git reset --hard;
	git fetch github "pull/$2/head";
	git checkout FETCH_HEAD; 
	composer install;
	popd;
	echo "$(date +'%Y-%m-%d %H:%M') *-htx-test$1-tomminsr.htxdev.com PR#$2" | tee -a ~/development/test-history;
}
set-test-current() {
	set-test-local $1 $(git pwb)
}
alias list-test='for t in 1 2; do grep test$t ~/development/test-history | tail -n1; done'
alias test-list='for t in 1 2; do grep test$t ~/development/test-history | tail -n1; done'

git-out() {
	local to_sync=${1:-develop};
	git fetch --prune origin;
	git checkout $to_sync;
	git pull --ff-only origin $to_sync;
}
alias gs='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
gf() { git fetch --prune ${1:-origin}; }
git-hist() {
	git reflog | perl -nE '/checkout: moving from ([^ ]+)/ && say ++$x, ": ", $1;' | les
}
git-back() {
	local steps=${1:-1}
	local branch=$(git reflog | perl -nE '/checkout: moving from ([^ ]+)/ && say $1;' | head -n $steps | tail -n 1)
	git checkout $branch
}

# Enable XDebug for CLI scripts!
# export XDEBUG_CONFIG="default_enable=1 remote_enable=1 remote_port=9000 remote_connect_back=0 remote_autostart=1 remote_host=${SSH_CLIENT%% *}"
export XDEBUG_CONFIG="default_enable=1 remote_enable=1 remote_port=9042 remote_connect_back=0 remote_autostart=1 remote_host=localhost"


export htxdata=/home/dev/public/HTX/HolidayTaxisData

unit-test() {
	local suite=${1:-*};
	if [ ${#@} -gt 1 ];
	then
		local classes="${@:2}"
		local config="unit-tests/$suite/phpunit.xml"
		for class in $classes
		do
			vendor/bin/phpunit -c $config unit-tests/$suite/tests/$class
		done
	else
		for config in unit-tests/$suite/phpunit.xml
		do
			vendor/bin/phpunit -c $config 
		done
	fi
}


# Just for fun
taglist() {
	git fetch origin --tags;
	# git tag | grep -Eo '[0-9].*' | sort -V | perl -ne '($v,$s)=/(\d+\.\d+)(.*)/; $s = "-" unless $s; if ( $lastv eq $v ) { print ", $s"; } else { $lastv = $v; print "\n$v: $s"; }';
	git for-each-ref --format='%(refname:short) %(creatordate:short)' refs/tags | grep -v 'v\.' | grep -Eo '[0-9]+\.[0-9]+.*' | sort -V | perl -ne '($v,$s,$date)=/(\d+\.\d+)(.*?) (\d{4}-\d{2}-\d{2})/; $s = "-" unless $s; if ( $lastv eq $v ) { print ", $s"; } else { $lastv = $v; print "\n[$date] $v: $s"; }'
	echo;
}
# Alternative versions:
# git tag | grep -Eo '[0-9]+\.[0-9]+.*' | sort -V -k1 | perl -ne 'BEGIN { $lastv=""; }  END { print "\n"; } chomp; ($v1,$v2,$s)=split "\\."; $v = "$v1.$v2"; $s = "-" if $s eq ""; if ( $lastv eq $v ) { print ", $s"; } else { $lastv = $v; print "\n$v: $s"; }'
# git tag | plgrep '(\d+\.\d+)(.*)' '$1 $2' | sort -V -k1 | perl -ne 'BEGIN { $lastv=""; }  END { print "\n"; } ($v,$s)=split " ", $_; $s = "-" if $s eq ""; if ( $lastv eq $v ) { print ", $s"; } else { $lastv = $v; print "\n$v: $s"; }'

# Hunt for something in the logs of all the White Label servers, prepending appropriately
# param 1: grep term; param 2: optional date (default today)
wlgrep() { for ip in 192.168.202.{94,95,96,8}; do for site in Airport2Hotel Conxxe HolidayTaxis; do sssh $ip "zcat -f ~dev/apache/logs/$site/${2:-$(today)}.* | grep '$1'" | sed -e "s/^/$ip $site /"; done; done | sort -k6; }
# Ditto, but for Web Services
wsgrep() { for ip in 192.168.202.{92,97,93,5}; do for site in Conxxe HolidayTaxis; do sssh $ip "zcat -f ~dev/apache/logs/$site/${2:-$(today)}.* | grep '$1'; zcat -f /var/log/httpd/access_log* | grep '$1'" | sed -e "s/^/$ip $site /"; done; done | sort -k6; }


# Remind me that I've stashed
alias stash='git stash --include-untracked && warn stashed'
alias unstash='git stash pop --index && nowarn stashed'

tasklist() {	
	local base=${1:-master};
	local compare=${2:-develop};
	git fetch --prune origin --quiet;
	git log  --first-parent  --pretty='format:%s' "origin/$base..origin/$compare" | perl -nE '
		BEGIN {
			sub sortuniq {
				my %seen;
				return sort grep { !$seen{$_}++ } @_; 
			}
			my @tasks,@reverts,@misc,@prs;
		}
		chomp; 
		$line=$_; 
		if ($line =~ /^Merge pull request #(\d+) from (.*)/) {
			push @prs, $1;
			$line=$2;
		}
		@t = split "/", $line; 
		if ($t[$#t] =~ /^([A-Z0-9]{2,}-[0-9]+)/) { 
			$key=$1; 
			if($line =~ /revert/i) { 
				push @reverts, $key; 
			} else { 
				push @tasks, $key; 
			} 
		} else { 
			push @misc, $_; 
		} 
		END { 
			@tasks=sortuniq @tasks;
			@reverts=sortuniq @reverts;
			@prs=sortuniq @prs;
			@misc=sortuniq @misc;

			say $#prs+1, " PRs" if (@prs);
			say $#tasks+1, " TASKS: ", join ", ", @tasks if (@tasks);
			say $#reverts+1, " REVERTS: ", join ", ", @reverts if (@reverts);
			say $#misc+1, " OTHER: " if (@misc);
			say "- ", join "\n- ", @misc if (@misc); 
			say;
			say "JIRA LINK:";
			print "https://holidaytaxis.atlassian.net/issues/?jql=issueKey IN (", (join ",", @tasks), ")";
			print " and issueKey NOT IN (", (join ",", @reverts), ")" if (@reverts);
			say; 
			say "GITHUB LINK:";
			say "https://github.com/HolidayTaxis/htx/pulls?q=is:pr+", join "+", @prs;
			say;
		}
	'
}

# Multi Composer!
alias composer74='php7.4 $(which composer) '
alias composer80='php8.0 $(which composer) '
alias composer81='php8.1 $(which composer) '
alias composer82='php8.2 $(which composer) '
alias composer-self-update='sudo $(which composer) self-update'
