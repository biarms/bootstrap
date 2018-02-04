#!/bin/bash
# This script is meant for quick & easy install via:
#   $ curl -fsSL https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.bash -o biarms-bootstrap.bash
#   $ bash biarms-bootstrap.bash
# One line alternative:
#   $ bash <(curl -fsSL https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.bash)
#
# NOTE: Make sure to verify the contents of the script
#       you downloaded matches the contents of entrypoint.bash
#       located at https://github.com/biarms/bootstrap
#       before executing.
#

declare ERR_UNSUPPORTED_OS=1
declare ERR_MISSING_LIB=2
declare ERR_INSUFFICIENT_PRIVILEGES=3
declare BIARMS_STACKS_FOLDER='biarms-stacks'

# Inspired by https://github.com/progrium/bashstyle
initBestPractices() {
    # Very basic debug mode
    [[ "$TRACE" ]] && set -x
    # Stop on error
    set -eo pipefail
}

# Log framework inspired from https://www.franzoni.eu/quick-log-for-bash-scripts-with-line-limit/
#
# set LOGFILE to the full path of your desired logfile; make sure
# you have write permissions there. set RETAIN_NUM_LINES to the
# maximum number of lines that should be retained at the beginning
# of your program execution.
# execute 'logsetup' once at the beginning of your script, then
# use 'log' how many times you like.
logSetup() {
    LOGFILE=biarms-bootstrap-$(date '+%Y-%m-%d-%H-%M-%S').log
    RETAIN_NUM_LINES=10000
    TMP=$(tail -n $RETAIN_NUM_LINES $LOGFILE 2>/dev/null) && echo "${TMP}" > $LOGFILE
    exec > >(tee -a $LOGFILE)
    exec 2>&1
}
# A stupid log function, that print the given parameters in stdout (but add a timestamp)
# $1 (String) -> the message to log
log() {
    printf "[$(date '+%Y-%m-%d-%H-%M-%S')]-$* \n"
}
# A stupid log function, that print the given parameters in stdout (but add [INFO]- and a timestamp )
# $1 (String) -> the information message
logInfo() {
    log "[INFO ]: $*"
}
# A stupid log function, that print the given parameters in stdout (but add [WARN]- and a timestamp )
# $1 (String) -> the warning message
logWarn() {
    log "[WARN ]: $*"
}
# A stupid log function, that print the given parameters in stdout (but add [ERROR]- and a timestamp )
# $1 (String) -> the error message
logError() {
    log "[ERROR]: $*"
}
# A stupid log function, that print the given parameters in stdout (but add [FATAL]- and a timestamp )
# Then exist with the provided error code.
# $1 (int)    -> the exit error code
# $2 (String) -> the error message
logFatalError() {
    local errorCode=$1
    log "[FATAL]: A fatal error occurred. Error code: ${errorCode}"
    shift
    log "[FATAL]: $*"
    exit ${errorCode}
}

# Check that a binary is present in the path. Exit with error code ERR_MISSING_LIB otherwise.
# $1 -> the executable to find in the path.
# Sample usage:
#    checkBinaryIsInThePath wget
checkBinaryIsInThePath() {
    local binaryFile="$1"
    if ! which "${binaryFile}" > /dev/null; then
        logFatalError $ERR_MISSING_LIB "The tool '${binaryFile}' can't be found in the path. Are you sure your OS is officially supported ?"
    fi
}

# Get the linux distribution identifier (ie: ubuntu, redhat, etc.)
getDistribution() {
	local dist=""
	# Every system that we officially support has /etc/os-release
	if [ -r /etc/os-release ]; then
		dist="$(. /etc/os-release && echo "$ID")"
    	dist="$(echo "$dist" | tr '[:upper:]' '[:lower:]')"
	fi
	echo "$dist"
}

# Currently, only basic checks are done. Will have to be improved in the future.
checkOSIsSupported() {
    local dist="$(getDistribution)"
	case "${dist}" in
		ubuntu)
		    ;;
		debian|raspbian)
		    ;;
	    *)
            logFatalError $ERR_UNSUPPORTED_OS "Can't find the /etc/os-release file. Are you sure your OS is officially supported ?"
            ;;
    esac
    checkBinaryIsInThePath sudo
    checkBinaryIsInThePath apt-get
    set +e
    sudo ls > /dev/null
    local errorCode=$?
    set -e
    if [ $errorCode -ne 0 ]; then
        logFatalError $ERR_INSUFFICIENT_PRIVILEGES "Are your user a register as sudoered ? (See file /etc/sudoers)."
    fi
}

updateOS() {
    sudo apt-get update
    sudo apt-get -y upgrade
}

installNeededPackages() {
    sudo apt-get -y install wget make git
}

installDocker() {
    curl -fsSL get.docker.com | sh
    sudo usermod -aG docker "${USER}"
    sudo docker version
    sudo docker swarm init
}

checkoutBIARMSStackGitRepo() {
    git clone "https://github.com/biarms/arm-docker-stacks" "${BIARMS_STACKS_FOLDER}"
}

# Deploy an 'BIARMS' docker stack. Current implemention is using make:
# 1. We know that stacks are located as subfolder of the 'biarms-stacks' folder
# 2. We know that a Makefile is present in each sub-folder
# 3. We know that a 'deploy' make target exists
#
# $1 (String) -> the 'docker stack' identifier (which is the name of a sub-folder in arm-docker-stacks' git repo.
deployStack() {
    local stack_id="$1"
    pushd "${BIARMS_STACKS_FOLDER}/${stack_id}"
    make deploy
    popd
}

# In the future, we should here propose choice to the user. Currently, we have only one stack, so let's deploy it.
doBootStrap() {
    deployStack 'wordpress'
}

# The main entry point of this script.
main() {
    initBestPractices
    logSetup
    log "Start Brother in Arm's project bootstrap"
    checkOSIsSupported
    updateOS
    installNeededPackages
    installDocker
    checkoutBIARMSStackGitRepo
    doBootStrap
    log "Brother in Arm's project bootstrap completed"
}

# Don't run the main function if the this file is 'sourced', which is the case with bash_unit. So next line is a MUST for runnable script (not necessary for bash libraries)
# Inspired by https://github.com/progrium/bashstyle
[[ "$0" == "$BASH_SOURCE" ]] && main "$@"


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

# Called after each test
teardown() {
    printf "<==\n"
}

# Called after all tests (only once)
teardown_suite() {
    printf "<=\n"
}
