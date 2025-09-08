# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/granowski/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

#JAVA_HOME=/usr/local/openjdk17/
#export JAVA_HOME

PS1='%D %* %y:%d %# '

CVSEDITOR=vim
CVS_RSH=ssh

export CVSEDITOR
export CVS_RSH=ssh

#PATH=$PATH:/home/granowski/.local/share/gem/ruby/3.3/bin
