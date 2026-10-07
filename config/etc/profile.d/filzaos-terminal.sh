#!/usr/bin/env bash

# ============================================================
# FILZAOS TERMINAL
# ============================================================

export FILZAOS=1
export FILZAOS_VERSION="1.0.7"

if [[ $- == *i* ]]; then

    PS1='\[\e[38;5;141m\]┌──[\u@filzaos]─[\w]\n\[\e[38;5;93m\]└─$ \[\e[0m\]'

fi

export TERM=xterm-256color
