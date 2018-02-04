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
log() {
    printf "[$(date '+%Y-%m-%d-%H-%M-%S')]: $* \n"
}
# A stupid log function, that print the given parameters in stdout (but add [INFO]- and a timestamp )
logInfo() {
    log "[INFO]- $* \n"
}
# A stupid log function, that print the given parameters in stdout (but add [WARN]- and a timestamp )
logWarn() {
    log "[WARN]- $* \n"
}


main() {
    initBestPractices
    logSetup
    log "Start Brother in Arm's project bootstrap\n"
}

# Don't run the main function if the this file is 'sourced', which is the case with bash_unit. So next line is a MUST for runnable script (not necessary for bash libraries)
# Inspired by https://github.com/progrium/bashstyle
[[ "$0" == "$BASH_SOURCE" ]] && main "$@"


### Test functions, designed to be run with bash_unit (https://github.com/pgrange/bash_unit)
# Called before all tests (only once)
setup_suite() {
    printf "setup_suite\n"
}

# Called before each test
setup() {
    printf "setup\n"
}

test_main() {
    main
    printf "LOGFILE: ${LOGFILE} \n"
    assert "test -f '${LOGFILE}'"
}

# Called after each test
teardown() {
    printf "teardown\n"
}

# Called after all tests (only once)
teardown_suite() {
    printf "teardown_suite\n"
}