#!/bin/bash
##
# This script is meant for quick & easy install via:
#   $ curl -fsSL https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.bash -o biarms-bootstrap.bash
#   $ bash biarms-bootstrap.bash
# One-liner alternative:
#   $ bash <(curl -fsSL https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.bash)
#
# NOTE: Make sure to verify the contents of the script
#       you downloaded matches the contents of entrypoint.bash
#       located at https://github.com/biarms/bootstrap
#       before executing.
##

declare ERR_UNSUPPORTED_OS=1
declare ERR_MISSING_LIB=2
declare ERR_INSUFFICIENT_PRIVILEGES=3
declare BIARMS_STACKS_FOLDER='biarms-stacks'

##
# Inspired by https://github.com/progrium/bashstyle.
# @param : none.
##
initBestPractices() {
    # Very basic debug mode
    [[ "$TRACE" ]] && set -x
    # Stop on error
    set -eo pipefail
}

##
# Log framework inspired from https://www.franzoni.eu/quick-log-for-bash-scripts-with-line-limit/.
# Set LOGFILE to the full path of your desired logfile; make sure
# you have write permissions there. set RETAIN_NUM_LINES to the
# maximum number of lines that should be retained at the beginning
# of your program execution.
# execute 'logsetup' once at the beginning of your script, then
# use 'log' how many times you like.
# @param : none.
##
logSetup() {
    LOGFILE=biarms-bootstrap-$(date '+%Y-%m-%d-%H-%M-%S').log
    RETAIN_NUM_LINES=10000
    TMP=$(tail -n $RETAIN_NUM_LINES $LOGFILE 2>/dev/null) && echo "${TMP}" > $LOGFILE
    exec > >(tee -a $LOGFILE)
    exec 2>&1
}
##
# A stupid log function, that print the given parameters in stdout (but add a timestamp)
# @param $1 (String) -> the message to log
##
log() {
    printf "[$(date '+%Y-%m-%d-%H-%M-%S')]-$* \n"
}
##
# A stupid log function, that print the given parameters in stdout (but add [INFO]- and a timestamp )
# @param $1 (String) -> the information message
##
logInfo() {
    log "[INFO ]: $*"
}
##
# A stupid log function, that print the given parameters in stdout (but add [WARN]- and a timestamp )
# @param $1 (String) -> the warning message
##
logWarn() {
    log "[WARN ]: $*"
}
##
# A stupid log function, that print the given parameters in stdout (but add [ERROR]- and a timestamp )
# @param $1 (String) -> the error message
##
logError() {
    log "[ERROR]: $*"
}
##
# A stupid log function, that print the given parameters in stdout (but add [FATAL]- and a timestamp )
# Then exist with the provided error code.
# @param $1 (int)    -> the exit error code
# @param $2 (String) -> the error message
##
logFatalError() {
    local errorCode=$1
    log "[FATAL]: A fatal error occurred. Error code: ${errorCode}"
    shift
    log "[FATAL]: $*"
    exit ${errorCode}
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
        logFatalError $ERR_MISSING_LIB "The tool '${binaryFile}' can't be found in the path. Are you sure your OS is officially supported ?"
    fi
}

##
# Get the linux distribution identifier (ie: ubuntu, redhat, etc.).
# @param : none
# Sample usage:
#    local dist="$(getDistribution)"
# Caution: using 'exit $errCode' statement in that type of 'method' may not have the expected behavior (because of caller's code).
# => Impossible to use 'logFatalError' method here !
##
getDistribution() {
	local dist=""
	# Every system that we officially support has /etc/os-release
	if [ -r /etc/os-release ]; then
		dist="$(. /etc/os-release && echo "$ID")"
    	dist="$(echo "$dist" | tr '[:upper:]' '[:lower:]')"
	fi
	echo "$dist"
}

##
# Currently, only basic checks are done. Will have to be improved in the future.
# @param : none
##
checkOSIsSupported() {
    local dist="$(getDistribution)"
	case "${dist}" in
		ubuntu)
		    ;;
		debian|raspbian)
		    ;;
	    *)
            logFatalError $ERR_UNSUPPORTED_OS "You're OS does not seams to be officially supported by this version of this script."
            ;;
    esac
    checkBinaryIsInThePath sudo
    checkBinaryIsInThePath apt-get
    set +e
    sudo ls > /dev/null
    local errorCode=$?
    set -e
    if [ $errorCode -ne 0 ]; then
        logFatalError $ERR_INSUFFICIENT_PRIVILEGES "Are your user registered as sudoers (in file /etc/sudoers) ?"
    fi
}

##
# Update the OS's packages. Needs an internet connection.
# @param : none
##
updateOS() {
    checkBinaryIsInThePath 'apt-get'
    sudo apt-get update
    sudo apt-get -y upgrade
}

##
# Install some packages needed by BIARMS tools. Needs an internet connection.
# @param : none
##
installNeededPackages() {
    checkBinaryIsInThePath 'apt-get'
    sudo apt-get -y install wget make git pwgen
}

##
# Install the latest 'docker-ce' package. Needs an internet connection.
# @param : none
##
installDocker() {
    if ! which docker > /dev/null; then
        checkBinaryIsInThePath 'curl'
        curl -fsSL get.docker.com | sh
    fi
    checkBinaryIsInThePath 'sudo'
    sudo usermod -aG docker "${USER}"
    checkBinaryIsInThePath 'docker'
    sudo docker version
    # The script was run twice and the swarm was already setup: OK: just ignore this pb (-> || true)
    sudo docker swarm init --advertise-addr $(hostname -i) || true
}

##
# Checkout the source code of the 'arm-docker-stacks' github repository using 'git'. Needs an internet connection.
# Also expects that 'git' is installed.
# @param : none
##
checkoutBIARMSStackGitRepo() {
    checkBinaryIsInThePath 'git'
    if [ -d "${BIARMS_STACKS_FOLDER}" ]; then
        # If the folder exists, we assume it is our, and we updated it with git.
        # May fail is user change the contain of this folder: that's OK: he is not supposed to do that.
        pushd "${BIARMS_STACKS_FOLDER}"
        git pull
        popd
    else
        # otherwise, we create it
        git clone "https://github.com/biarms/arm-docker-stacks" "${BIARMS_STACKS_FOLDER}"
    fi
}

##
# Deploy an 'BIARMS' docker stack. Current implementation is using make:
# 1. We know that stacks are located as subfolder of the 'biarms-stacks' folder;
# 2. We know that a Makefile is present in each sub-folder;
# 3. We know that a 'deploy' make target exists.
#
# @param $1 (String) -> the 'docker stack' identifier (which is the name of a sub-folder in arm-docker-stacks' git repo.
##
deployStack() {
    local stack_id="$1"
    pushd "${BIARMS_STACKS_FOLDER}/${stack_id}"
    # Run deploy as 'root' to avoid the 'pi user is in docker group, but still don't have docker group rights' issue.
    sudo make deploy
    popd
}

##
# In the future, we should here propose choice to the user. Currently, we have only one stack, so let's deploy it.
# @param : none
##
doBootStrap() {
    deployStack 'infra'
    deployStack 'wordpress'
    deployStack 'gogs'
}

##
# Display information message about the URL to connect to.
# @param : none
##
doDisplayIP() {
    checkBinaryIsInThePath 'ip'
    local ip="$(ip route get 8.8.8.8 | head -1 | awk '{print $7}')"
    logInfo "To access the Docker Admin Portainer console, try to access to http://${ip}:9000/"
    logInfo "To access the WordPress web site, try to access to http://${ip}:8050/"
    logInfo "Alternative: http://$(hostname).local:9000/ may also works if you've correctly configure the zeroconf software on your network"
    logInfo "Other IP alternatives: $(hostname -i) or one of $(hostname -I)"
 }

##
# The main entry point of this script.
# [@param $1 (String)]: a (un-mandatory) method name: if provided, only this method will be called. Otherwise, the entire script
# will be executed. Could be useful for debugging and or recovery.
##
main() {
    local methodName="$1"
    initBestPractices
    logSetup
    logInfo "Start Brother in Arms' project bootstrap"
    if [[ "$methodName" == "" ]]; then
        checkOSIsSupported
        updateOS
        installNeededPackages
        installDocker
        checkoutBIARMSStackGitRepo
        # A workaround for the second known issue: finish the installation in a new session. But that's a mess at log level :(
        # sudo -u "$USER" "$(pwd)/$0" doBootStrap
        # -> Actually, it doesn't work...
        doBootStrap
        doDisplayIP
    else
        shift
        "$methodName" $*
    fi
    logInfo "Brother in Arms' project bootstrap completed"
}

### Test functions, designed to be run with bash_unit (https://github.com/pgrange/bash_unit)
# Called before all tests (only once)
setup_suite() {
    printf "=>\n"
}

# Called before each test
setup() {
    printf "==>\n"
}

test_logFramework() {
    initBestPractices
    logSetup
    log "Test log feature"
    logInfo "Test log feature - info"
    logWarn "Test log feature - warn"
    logError "Test log feature - error"
    printf "LOGFILE: ${LOGFILE} \n"
    assert "test -f '${LOGFILE}'"
}

test_checkBinaryIsInThePath() {
    assert_status_code 0 "checkBinaryIsInThePath curl"
    assert_status_code $ERR_MISSING_LIB "checkBinaryIsInThePath curlfg"
}

test_checkOSIsSupported() {
    assert_status_code 0 "checkOSIsSupported"
}

test_checkoutBIARMSStackGitRepo() {
    rm -rf "$BIARMS_STACKS_FOLDER" || true
    checkoutBIARMSStackGitRepo
    if [ ! -f "$BIARMS_STACKS_FOLDER/README.md" ]; then
        fail "File $BIARMS_STACKS_FOLDER/README.md doesn't exist"
    fi
    # rm "$BIARMS_STACKS_FOLDER/README.md"
    checkoutBIARMSStackGitRepo
    if [ ! -f "$BIARMS_STACKS_FOLDER/README.md" ]; then
        fail "File $BIARMS_STACKS_FOLDER/README.md doesn't exist"
    fi
    rm -rf "$BIARMS_STACKS_FOLDER" || true
}


# Called after each test
teardown() {
    printf "<==\n"
}

# Called after all tests (only once)
teardown_suite() {
    printf "<=\n"
}

# Always put the main method call at the end of the file so that we have some protection against only getting half the file during "bash <(curl)"
# Don't run the main function if the this file is 'sourced', which is the case with bash_unit.
# So next line is a MUST for runnable script (not necessary for bash libraries)
# Inspired by https://github.com/progrium/bashstyle
[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
