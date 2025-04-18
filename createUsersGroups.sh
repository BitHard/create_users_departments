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
logFile="logFile-$(date +%Y-%m-%d).log"

# Text Output Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color (Default)

# Arrays
usersList=()              # Users list to be created. Param: USER
groupsList=()             # Groups list to be created. Param: GROUP
workDirectoriesList=()    # Workdirectories list to be created. Param: DIR
groupNameEntries=()       # Correlatinh users in GROUPS. Param: USERS_GROUP
permList=()
usersToGroup=()

# =========
# FUNCTIONS
# =========

# Timestamp
function timestamp() {
  date +"%Y-%m-%d %H:%M:%S.%N"
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
        logOk "\t + User '$user' removed."
    else
        logInfo "\t + Removing user: '$user'. User doesn't exist."
    fi
  done

}

# Check this function
# ===================
function removeGroups() {
  logInfo "Search and removing old groups..."  

  for currentGroup in "${groupsList[@]}"; do
    if getent group "$currentGroup" &> /dev/null; then
      if sudo groupdel "$currentGroup" &> /dev/null; then
        logOk "\t + Group '$currentGroup' removed." 
      else
        logFail "\t + Failed to remove group '$currentGroup'. It may be in use (e.g., primary group of a user)."
      fi
    else
      logInfo "\t + Group '$currentGroup' does not exist."
    fi
  done
}


function createUsers() {
  logInfo "Creating users..."  
  for user in "${usersList[@]}"; do
    if sudo useradd -m -s "/bin/bash" $user; then
        logOk "\t + User '$user' created."
    else
        logFail "\t + Error to create user '$user'."
    fi
  done
}

function createGroups() {
  logInfo "Creating groups..."  
  for currentGroup in "${groupsList[@]}"; do
    
    if sudo groupadd "$currentGroup"; then
        logOk "\t + Group '$currentGroup' created." 
    else
        logFail "\t + Error to create '$currentGroup'."
    fi
  done

}

function removeWorkDirectories() {
  logInfo "Cleaning old directories..."
  for directory in "${workDirectoriesList[@]}"; do
    if [[ -d "$directory" ]]; then
        logInfo "Cleaning directory '$directory'"
        [[ -n "$directory" ]] && rm -rf "$directory"
        logOk "\t + $directory : removed."
    else
        logInfo "\t + $directory : doesn't exist."
    fi
  done
}


function createWorkDirectories() {
  logInfo "Creating work directories..."  
  for directory in "${workDirectoriesList[@]}"; do
    if mkdir -p "$directory"; then
        logOk "\t + $directory created."
    else
        logFail "\t + Error to create directory '$directory'."
    fi
  done
}

function setPrimaryGroup() {
    logInfo "Set primaries groups for users."
    for currentGroup in "${usersToGroup[@]}"; do
        IFS=';' read -ra groupArray <<< "$currentGroup"

        IFS=',' usersInGroup="${groupArray[*]:1}"
        read -r -a primaryGroupUsers <<< "$usersToGroup"
    
        IFS=',' read -ra usersArray <<< "$usersInGroup"
        for currentUserSetPrimaryGroup in "${usersArray[@]}"; do          
          if sudo usermod -g "${groupArray[0]}" "${currentUserSetPrimaryGroup}" &>/dev/null; then
            logOk "\t + Set primary group ${groupArray[0]} to $currentUserSetPrimaryGroup"
          else
            logFail "\t + Error to set primary group ${groupArray[0]} for user $currentUserSetPrimaryGroup"
          fi          
        done

    done
}


function setPermissions() {
  logInfo "Setting permissions for the directories."
  for currentSetPermissions in "${permInfo[@]}"; do
    IFS=';' read -r directoryPath owner groupOwner permOwner permGroup permOthers <<< "$currentSetPermissions"

    # Change owner an group of directory
    if sudo chown "$owner":"$groupOwner" "$dirPath" &>/dev/null; then
      logOk "\t + Change $owner and $groupOwner for $directoryPath"
    else
      logFail "\t + Error in change permissions: $owner and $groupOwner for $directoryPath"
    fi
        
    # Set permission properties
    if sudo chmod u="$permOwner",g="$permGroup",o="$permOthers" "$directoryPath" $>/dev/null; then
      logOk "\t + Apply permission in $directoryPath → $permOwner/$permGroup/$permOthers"
    else
      logFail "\t + Error to apply permission in $directoryPath"
    fi
  done
}


function getConfigFileInformatio() {
  logInfo "Collecting users to create."
  logInfo "\t + USERS.: $usersList"
  logInfo "Collecting groups to create."
  logInfo "\t + GROUPS.: $groupsList"
  logInfo "Collecting work directories to create."
  logInfo "\t + DIR.: $workDirectoriesList"
  logInfo "Correlating groups and users."

  for currentSetUsers in "${usersToGroup[@]}"; do
    logInfo "\t + ${currentSetUsers%%;*}: ${currentSetUsers#*;}"
  done

  logInfo "Getting permissions to work directories."
  for currentSetPermissions in "${permInfo[@]}"; do
    logInfo "\t + ${currentSetPermissions%%;*}: ${currentSetPermissions#*;}"
  done
}

# ====
# MAIN
# ====

clear
checkPrivileges
logInfo "---------------------------------------------"
logInfo "Starting program $0"
logInfo "---------------------------------------------"
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
    workDirectoriesList+=(${cleanLine#DIR:});
  fi

  if [[ "$cleanLine" == USERS_GROUP:* ]]; then
    usersToGroup+=(${cleanLine#USERS_GROUP:})
  fi

  if [[ "$cleanLine" == PERM:* ]]; then
    permInfo+=(${cleanLine#PERM:})
  fi

done < "$sourceFile"

# Call functions

# Informations About File Config
getConfigFileInformatio

# Removing old users, groups and directories
removeUsers
removeGroups
removeWorkDirectories

createGroups
createUsers
createWorkDirectories

setPrimaryGroup
setPermissions