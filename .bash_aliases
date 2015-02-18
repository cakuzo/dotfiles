# date format for file
fdate() {
  date +'%Y%m%d_%H%M%S'
}

fdateshort() {
  date +'%Y%m%d'
}

# colored man pages
man() {
  env LESS_TERMCAP_mb=$'\E[01;31m' \
  LESS_TERMCAP_md=$'\E[01;38;5;74m' \
  LESS_TERMCAP_me=$'\E[0m' \
  LESS_TERMCAP_se=$'\E[0m' \
  LESS_TERMCAP_so=$'\E[01;33;03;40m' \
  LESS_TERMCAP_ue=$'\E[0m' \
  LESS_TERMCAP_us=$'\E[04;38;5;146m' \
  man "$@"
}

# stderr echo
errout() {
  echo $@ >&2
}

# printable man pages
man2ps() {
  manpages="$@"
  args=$#
  processed=0
  manpage=""
  
  if [ $args -eq 0 ]; then 
    errout "need at least 1 argument" && return 1
  fi
  
  while [ $args -gt $processed ]; do
    if [ -f "$(man -w ${1})" ]; then 
      if [ ! -f "${1}.ps" ]; then
        zcat "$(man -w ${1})" | groff -man -Tps > ${1}.ps
        shift 
      else
        errout "${1}.ps already exists"
        shift
      fi
    fi 
    processed=$(($processed+1))
  done
}

# read man pages in PDF reader (evince)
niceman() {
  if [ -f "$(man -w ${1})" ]; then
    [ ! -f ${1}.ps ] && man2ps ${1} 
    evince ${1}.ps
  fi
}

# core
alias ll="ls -l --color=auto"
alias la="ls -la --color=auto"
alias ..="cd .."
alias ...="cd ../.."

# tmux 
alias tl="tmux ls"
alias ta="tmux attach -t"
alias tn="tmux new-session -s"

# vagrant
alias vup="vagrant up"
alias vssh="vagrant ssh"
alias vussh="vagrant up && ssh"
alias vhalt="vagrant halt"
alias vstat="vagrant global-status"
alias vdestroy="vagrant destroy"

# fun
alias please="sudo"

[ -f ~/.bash_aliases_for_work ] && source ~/.bash_aliases_for_work
