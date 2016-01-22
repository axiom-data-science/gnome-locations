#!/bin/bash

ALL_EXIT=0

metric_type ()
{
    # metric name, metric type
    local metric_name=$1
    local metric_type=$2
    echo "# TYPE ${PROM_METRIC_PREFIX}gnomelocations_$metric_name $metric_type" >>stats.prom
}

# prep metrics
truncate --size 0 stats.prom
metric_type last_succeeded_milliseconds gauge
metric_type last_failed_milliseconds gauge
metric_type last_completed_milliseconds gauge
metric_type download_total counter
metric_type update_duration_milliseconds gauge
metric_type model_size_bytes gauge
metric_type timerange_start_seconds gauge
metric_type timerange_end_seconds gauge

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
    cat $(dirname $d)/stats.prom >>stats.prom
done

if [ $# -gt 0 ];
then
    curl --data-binary @stats.prom $1
fi

exit $ALL_EXIT

