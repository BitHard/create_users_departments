#!/usr/bin/env bash
#
# Script name   : createUsersGroups.sh
# Description   : Create users, groups, work directories and access policies.
# Author        : BitHard
# Creation Date : 2025-04-05
# Version       : 0.1


# =========
# VARIABLES
# =========

sourceFile="users_and_groups_list.txt"
logFile="logFile-$(date +%Y-%m-%d).txt"

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Arrays
usersList=()
groupsList=()
workDirectoriesList=()
permList=()

groupName=""
usersToGroup=()

# =========
# FUNCTIONS
# =========

# Timestamp
function timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

# Log - Success
logOk() {
  local msg="$1"
  local colorMsg="$(timestamp) ${GREEN}[ OK ]${NC} $msg"
  local plainMsg="$(timestamp) [ OK ] $msg"
  
  echo -e "$colorMsg"
  echo -e "$plainMsg" >> "$logFile"
}

# Log - Error
logFail() {
  local msg="$1"
  local colorMsg="$(timestamp) ${RED}[FAIL]${NC} $msg"
  local plainMsg="$(timestamp) [FAIL] $msg"
  
  echo -e "$colorMsg"
  echo -e "$plainMsg" >> "$logFile"
}

# Log - Information
logInfo() {
  local msg="$1"
  local colorMsg="$(timestamp) ${YELLOW}[INFO]${NC} $msg"
  local plainMsg="$(timestamp) [INFO] $msg"
  
  echo -e "$colorMsg"
  echo -e "$plainMsg" >> "$logFile"
}

# Verify if the user has root privileges for execute this script
function checkPrivileges() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "User hasn't root privileges." >&2
        exit 1
    fi
}

function removeUsers() {
  logInfo "Search and removing users..."  
  for user in "${usersList[@]}"; do
    if userdel -r "$user" 2> /dev/null; then
        logOk "User '$user' removed."
    else
        logInfo "Removing user: '$user'. User doesn't exist."
    fi
  done

}

# Check this function
# ===================
function removeGroups() {
  logInfo "Search and removing old groups..."  
  for group in "${groupsList[@]}"; do
    usersInGroup=$(getent group "$group" | cut -d: -f4)
    usuarios_csv=$(echo "$linha" | cut -d: -f4)

    if userdel -r "$group" 2> /dev/null; then
        logOk "Group '$group' removed." 
    else
        logInfo "Removing group: '$group'. Group doesn't exist."
    fi
  done
}


function createUsers() {
  logInfo "Creating users..."  
  for user in "${usersList[@]}"; do
    if sudo useradd -m -s "/bin/bash" $user; then
        logOk "User '$user' created."
    else
        logFail "Error to create user '$user'."
    fi
  done
}

function createGroups() {
  logInfo "Creating groups..."  
  for group in "${groupsList[@]}"; do
    
    if sudo groupadd "$group"; then
        logOk "Group '$group' created." 
    else
        logFail "Error to create '$group'."
    fi
  done

}

function removeWorkDirectories() {
  logInfo "Cleaning old directories..."
  for directory in "${workDirectoriesList[@]}"; do
    if [[ -d "$directory" ]]; then
        logInfo "Cleaning directory '$directory'"
        [[ -n "$directory" ]] && rm -rf "$directory"
        logOk "Directory '$directory' removed."
    else
        logInfo "The directory '$directory' doesn't exist."
    fi
  done
}


function createWorkDirectories() {
  logInfo "Creating work directories..."  
  for directory in "${workDirectoriesList[@]}"; do
    if mkdir -p "$directory"; then
        logOk "Directory '$directory' created."
    else
        logFail "Error to create directory '$directory'."
    fi
  done
}

function setPrimaryGroup() {
    logInfo "Set primaries groups for users."
    for user in "${usersToGroup[@]}"; do
        if id "$user" &>/dev/null; then
            if sudo usermod -g "$groupName" "$user"; then
                logOk "User $user set in primary group $groupName."
            fi
        else
            logFail "User $user doesn't found."
        fi
    done
}


function setPermissions() {
  logInfo "Setting permissions for the directories."

}


# ====
# MAIN
# ====

clear
checkPrivileges

logInfo "Starting program $0"
logInfo "Reading file ['$sourceFile']"

while IFS= read -r line; do
  # Ignore blank lines or that begin with '#''
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  # Clean line read
  cleanLine="${line#"${line%%[![:space:]]*}"}"
  
  # Check if the line define an user
  if [[ "$cleanLine" == USER:* ]]; then
    usersList+=(${cleanLine#USER:})
  fi

  # Check if the line define a group
  if [[ "$cleanLine" == GROUP:* ]]; then
    groupsList+=(${cleanLine#GROUP:})
  fi

# Check if the line define a work directorie
  if [[ "$cleanLine" == DIR:* ]]; then
    workDirectoriesList+=(${cleanLine#DIR:})
  fi

  if [[ "$cleanLine" == USERS_GROUP:* ]]; then
    groupName=$(cut -d':' -f2 <<< "$cleanLine")
    usersToGroup=$(cut -d':' -f3 <<< "$cleanLine")
    IFS=',' read -r -a usersToGroup <<< "$usersToGroup"
  fi

  if [[ "$cleanLine" == PERM:* ]]; then
    permInfo=${cleanLine#PERM:}
    IFS=';' read -r dirPath owner group permUser permGroup permOthers <<< "$permInfo"

    # Change owner an group of directory
    chown "$owner":"$group" "$dirPath"
    logOk "Change $owner and $group for $dirPath"
        
    # Set permission properties
    chmod u="$permUser",g="$permGroup",o="$permOthers" "$dirPath"
    logOk "Permissões aplicadas em $dirPath → owner: $owner, group: $group, perms: $permUser/$permGroup/$permOthers"
  fi

done < "$sourceFile"


removeUsers
removeGroups
removeWorkDirectories

#createUsers
#createGroups
#createWorkDirectories

#setPrimaryGroup
#setPermissions
