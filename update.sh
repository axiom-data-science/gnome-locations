#!/bin/bash

ALL_EXIT=0

for d in $(find -type f -name update.sh); do
    if [ "$d" = "$0" ];
    then
        continue
    fi

    pushd .
    cd $(dirname $d)
    echo "Running $(basename $d) from $(dirname $d)"
    bash $(basename $d)
    let "ALL_EXIT=$ALL_EXIT || $?"
    popd
done

exit $ALL_EXIT

