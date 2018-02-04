#!/bin/sh
# This script is meant for quick & easy install via:
#   $ curl -fsSL https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.sh -o biarms-bootstrap.sh
#   $ sh biarms-bootstrap.sh
# One line alternative:
#   $ curl -fsSL https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.sh | sh
#
# NOTE: Make sure to verify the contents of the script
#       you downloaded matches the contents of entrypoint.bash
#       located at https://github.com/biarms/bootstrap
#       before executing.
#

printPrerequisitesThanExit() {
    echo "Unsupported OS: no bash/curl support."
    echo " Apparently, you don't have the bash shell installed or not curl installed, which are mandatory OS prerequisites."
    echo " Consider installing bash and curl manually, or consider to try with another OS."
    exit 1
}

main() {
    if which bash > /dev/null; then
        if which curl > /dev/null; then
            local url="https://raw.githubusercontent.com/biarms/bootstrap/master/entrypoint.bash"
            curl -fsSL "${url}" -o biarms-bootstrap.bash
            if [ $? -ne 0 ]; then
                echo "An error occurred when trying to download the '$url' URL."
                echo "Are you sure the network is OK ?"
                exit 2
            fi
            bash biarms-bootstrap.bash
        else
            printPrerequisitesThanExit
        fi
    else
        printPrerequisitesThanExit
    fi
}

# Always put the main method call at the end of the file so that we have some protection against only
# getting half the file during "curl | sh"
main