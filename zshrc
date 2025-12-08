# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/granowski/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

if [[ `uname -s` -eq "NetBSD" ]]; then
  JAVA_HOME=/usr/pkg/java/openjdk21/
  export JAVA_HOME
  CVSEDITOR=vim
  CVS_RSH=ssh
  
  export CVSEDITOR
  export CVS_RSH=ssh
  
  export CVSROOT="anoncvs@anoncvs.NetBSD.org:/cvsroot"
  export CVS_RSH="ssh"

  PATH=$PATH:$JAVA_HOME/bin
  export PATH
fi

PS1='%D %* %y:%d %# '
