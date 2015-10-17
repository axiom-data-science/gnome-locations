#!/bin/bash

for d in $(find -type f -name update.sh); do
    if [ "$d" = "$0" ];
    then
        continue
    fi

    pushd .
    cd $(dirname $d)
    echo "Running $(basename $d) from $(dirname $d)"
    bash $(basename $d)
    popd
done
