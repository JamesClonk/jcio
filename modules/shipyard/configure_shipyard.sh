#!/bin/bash
set -e
set -u

# usage check
if [ $# -ne 1 ]; then
	echo "usage: $0 <input-filename>"
	exit 1
fi

export INPUT_FILENAME=$1

# wait for shipyard to be ready
sleep 5
until nc -zvw 1 localhost 8080; do
	echo "."
	sleep 5
done

# configure shipyard
go build
./shipyard ${INPUT_FILENAME}
# TODO: prepackage binary, so golang installation and build step is not needed

exit 0
