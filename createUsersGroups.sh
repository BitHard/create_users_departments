#!/usr/bin/env bash
#
# Script name   : createUsersGroups.sh
# Description   : Create users, groups, work directories and access policies.
# Author        : BitHard
# Creation Date : 2025-04-05
# Version       : 0.1


# =========
# FUNCTIONS
# =========


# Verify if the user has root privileges for execute this script
function checkPrivileges() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "User hasn't root privileges." >&2
        exit 1
    fi
}


function getUsersGroupsList() {
    
}

# ====
# MAIN
# ====

checkPrivileges