#!/bin/bash

# ==============================
# FilzaOS Terminal Environment
# ==============================

PURPLE='\[\e[38;5;141m\]'
LIGHT_PURPLE='\[\e[38;5;183m\]'
CYAN='\[\e[38;5;81m\]'
WHITE='\[\e[97m\]'
GRAY='\[\e[38;5;245m\]'
RESET='\[\e[0m\]'

# FilzaOS prompt
if [ "$EUID" -eq 0 ]; then
    PS1="${PURPLE}┌──[${WHITE}root${PURPLE}@${CYAN}filzaos${PURPLE}]${GRAY}─[\w]${RESET}\n${PURPLE}└─# ${RESET}"
else
    PS1="${PURPLE}┌──[${WHITE}\u${PURPLE}@${CYAN}filzaos${PURPLE}]${GRAY}─[\w]${RESET}\n${PURPLE}└─$ ${RESET}"
fi

# Useful aliases
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'

alias c='clear'
alias ports='ss -tuln'
alias myip='ip -brief addr'
alias routes='ip route'

# FilzaOS utilities
alias fsys='filza-sys'
alias fnet='filza-net'
alias finfo='filza-info'

# Terminal title
case "$TERM" in
    xterm*|rxvt*|alacritty*)
        PROMPT_COMMAND='printf "\033]0;FilzaOS Terminal\007"'
        ;;
esac
