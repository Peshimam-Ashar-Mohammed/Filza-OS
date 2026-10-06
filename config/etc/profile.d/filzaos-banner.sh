#!/bin/bash

if [[ $- == *i* ]]; then
    PURPLE='\033[38;5;141m'
    CYAN='\033[38;5;81m'
    WHITE='\033[97m'
    RESET='\033[0m'

    echo
    echo -e "${PURPLE}╔══════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║${WHITE}             FILZAOS                 ${PURPLE}║${RESET}"
    echo -e "${PURPLE}║${RESET}        Linux, Filza style.          ${PURPLE}║${RESET}"
    echo -e "${PURPLE}╠══════════════════════════════════════╣${RESET}"
    echo -e "${PURPLE}║${RESET} Type ${CYAN}filza-info${RESET} for system information. ${PURPLE}║${RESET}"
    echo -e "${PURPLE}╚══════════════════════════════════════╝${RESET}"
    echo
fi
