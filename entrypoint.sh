#!/bin/sh
##
# This script is meant for quick & easy install via:
#   $ curl -fsSL https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.sh -o biarms-bootstrap.sh
#   $ sh biarms-bootstrap.sh
# One-liner alternative:
#   $ curl -fsSL https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.sh | sh
#
# NOTE: Make sure to verify the contents of the script
#       you downloaded matches the contents of entrypoint.sh
#       located at https://github.com/biarms/bootstrap
#       before executing.
##

declare ERR_MISSING_LIB=501
declare ERR_DOWNLOAD_ISSUE=401

##
# Print an error message and exit (if nor bash and curl are present in the path).
# @param $1 -> the executable not found in the path.
##
printPrerequisitesThanExit() {
    local binaryFile="$1"
    echo "Unsupported OS: no ${binaryFile} support."
    echo " Apparently, you don't have the ${binaryFile} tool installed, which is a mandatory prerequisites."
    echo " Consider installing ${binaryFile} manually, or consider to try with another OS."
    exit $ERR_MISSING_LIB
}

##
# Check that a binary is present in the path. Exit with error code ERR_MISSING_LIB otherwise.
# @param $1 -> the executable to find in the path.
# Sample usage:
#    checkBinaryIsInThePath 'wget'
##
checkBinaryIsInThePath() {
    local binaryFile="$1"
    if ! which "${binaryFile}" > /dev/null; then
        printPrerequisitesThanExit "${binaryFile}"
    fi
}

##
# Download a script from the bootstap github repo, and make the script executable.
# @param $1 -> the git branch to use (typically, 'master' or 'develop').
# @param $2 -> the script file name.
# @param $3 -> the target script file name.
# Sample usage:
#    downloadScript 'master' 'entrypoint.sh' 'biarms-bootstrap.sh'
##
downloadScript() {
    local branch="$1"
    local scriptFileName="$2"
    local targetScriptFileName="$3"
    local url="https://raw.githubusercontent.com/biarms/bootstrap/${branch}/${scriptFileName}"
    curl -fsSL "${url}" -o "${targetScriptFileName}"
    local errorCode=$?
    if [ $errorCode -ne 0 ]; then
        echo "An error occurred when trying to download the '$url' URL."
        if [ $errorCode -eq 22 ]; then
            echo "Are you sure the provided branch ('${branch}') is correct ?"
            exit $ERR_DOWNLOAD_ISSUE
        else
            echo "Are you sure the network is OK ? (curl error code: ${errorCode})"
            exit $ERR_DOWNLOAD_ISSUE
        fi
    fi
    chmod +x "${targetScriptFileName}"
}

##
# The main entry point of this script.
# [@param $1 (String)]: a (un-mandatory) git branch name (typically, 'master' or 'develop')
##
main() {
    local gitBranchName="${1}"
    if [[ "${gitBranchName}" == "" ]]; then
        gitBranchName="master"
    fi
    checkBinaryIsInThePath 'bash'
    checkBinaryIsInThePath 'curl'
    downloadScript "${gitBranchName}" "entrypoint.sh" "biarms-bootstrap.sh"
    downloadScript "${gitBranchName}" "entrypoint.bash" "biarms-bootstrap.bash"
    # Launch the newly downloaded script with bash:
    bash biarms-bootstrap.bash
}

# Always put the main method call at the end of the file so that we have some protection against only getting half the file during "curl | sh"
main "$1"