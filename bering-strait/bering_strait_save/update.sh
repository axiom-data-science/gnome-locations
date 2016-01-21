#!/bin/bash

FAILS=0
LOC_NAME=bering-strait

#check for ncdump
command -v ncdump >/dev/null 2>&1 || { echo "ncdump is required but not installed (aptitude install -y netcdf-bin)" >&2; exit 1; }

truncate --size 0 stats.prom

metric ()
{
    # metric name, model name, value, additional labels*
    local ts=$(date +%s%3N)       # milliseconds since epoch
    local metric_name=$1
    local model_name=$2
    local value=$3
    shift 3

    # join additional labels
    if [[ $# -gt 0 ]]; then
        local IFS=","
        local additional=",$*"
    fi

    echo "axiom_uaadhs_gnomelocations_$metric_name{location=\"$LOC_NAME\",model=\"$model_name\"$additional} $value $ts" >>stats.prom
}

# Get GFS
START_GFS=$(date +%s%3N)
curl -k 'https://gnome.orr.noaa.gov/goods/currents/GFS/get_data' -H 'Host: gnome.orr.noaa.gov' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:40.0) Gecko/20100101 Firefox/40.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: http://gnome.orr.noaa.gov/goods/currents/GFS/get_data' -H 'Connection: keep-alive' --data 'dataset=Global_0p5deg&selected_file_url=http%3A%2F%2Fthredds.ucar.edu%2Fthredds%2FdodsC%2Fgrib%2FNCEP%2FGFS%2FGlobal_0p5deg%2Fbest&err_placeholder=&start_time=0&time_step=1&end_time=202&NorthLat=70.5&WestLon=175&xDateline=1&EastLon=-160&SouthLat=55.5&Stride=1&time_zone=0&submit=Get+Data' -o GFS_download.nc
END_GFS=$(date +%s%3N)

ncdump -h GFS_download.nc
NCD_C=$?
if [ $NCD_C -eq 0 ]; then
    mv GFS_download.nc GFS.nc
else
    echo "Problem downloading GFS files"
    let "FAILS += 1"
fi

# figure out extents of GFS
# GFS time units are "Hour since 2016-01-07 00:00:00" (date changes)
GFS_REF_TIME=$(ncdump -h GFS.nc | grep -Po "time:units = \"Hour since \K[^\"]+")
# should always be 0 but we'll humor it
GFS_LOWER_HRS=$(ncks -H -d time,0 -v time -s '%.0f' GFS.nc)
GFS_UPPER_HRS=$(ncks -H -d time,-1 -v time -s '%.0f' GFS.nc)

# convert to epoch
GFS_LOWER=$(date -d "$GFS_REF_TIME Z +$GFS_LOWER_HRS hours" -u +"%s")
GFS_UPPER=$(date -d "$GFS_REF_TIME Z +$GFS_UPPER_HRS hours" -u +"%s")

# metrics
metric last_succeeded_milliseconds GFS $(( $NCD_C == 0 ? $END_GFS : Nan ))
metric last_failed_milliseconds GFS $(( $NCD_C == 0 ? Nan : $END_GFS ))
metric download_total GFS $(( $NCD_C == 0 ? 1 : 0 )) 'code="success"'
metric download_total GFS $(( $NCD_C == 0 ? 0 : 1 )) 'code="failure"'
metric update_duration_milliseconds GFS $(( $END_GFS - $START_GFS ))
metric last_completed_milliseconds GFS $END_GFS
metric model_size_bytes GFS $(stat -c%s GFS.nc)
metric timerange_start_seconds GFS $GFS_LOWER
metric timerange_end_seconds GFS $GFS_UPPER

# Get HYCOM
START_HYCOM=$(date +%s%3N)
curl -k 'https://gnome.orr.noaa.gov/goods/currents/HYCOM/get_data' -H 'Host: gnome.orr.noaa.gov' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:40.0) Gecko/20100101 Firefox/40.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: http://gnome.orr.noaa.gov/goods/currents/HYCOM/get_data' -H 'Connection: keep-alive' --data 'dataset=&selected_file_url=http%3A%2F%2Ftds.hycom.org%2Fthredds%2FdodsC%2FGLBa0.08%2Flatest&err_placeholder=&start_time=0&time_step=1&end_time=9&NorthLat=70.5&WestLon=175&xDateline=1&EastLon=-160&SouthLat=55.5&Stride=1&time_zone=0&submit=Get+Data' -o HYCOM_download.nc
END_HYCOM=$(date +%s%3N)

ncdump -h HYCOM_download.nc
NCD_C=$?
if [ $NCD_C -eq 0 ]; then
    mv HYCOM_download.nc HYCOM.nc
else
    echo "Problem downloading HYCOM files"
    let "FAILS += 1"
fi

# figure out extents of HYCOM
# HYCOM time units are "days since 2000-12-31 00:00:00"
HYCOM_REF_TIME=$(ncdump -h HYCOM.nc | grep -Po "time:units = \"days since \K[^\"]+")
HYCOM_LOWER_DAYS=$(ncks -H -d time,0 -v time -s '%.0f' HYCOM.nc)
HYCOM_UPPER_DAYS=$(ncks -H -d time,-1 -v time -s '%.0f' HYCOM.nc)

# convert to epoch
HYCOM_LOWER=$(date -d "$HYCOM_REF_TIME Z +$HYCOM_LOWER_DAYS days" -u +"%s")
HYCOM_UPPER=$(date -d "$HYCOM_REF_TIME Z +$HYCOM_UPPER_DAYS days" -u +"%s")

metric last_succeeded_milliseconds HYCOM $(( $NCD_C == 0 ? $END_HYCOM : Nan ))
metric last_failed_milliseconds HYCOM $(( $NCD_C == 0 ? Nan : $END_HYCOM ))
metric download_total HYCOM $(( $NCD_C == 0 ? 1 : 0 )) 'code="success"'
metric download_total HYCOM $(( $NCD_C == 0 ? 0 : 1 )) 'code="failure"'
metric update_duration_milliseconds HYCOM $(( $END_HYCOM - $START_HYCOM ))
metric last_completed_milliseconds HYCOM $END_HYCOM
metric model_size_bytes GFS $(stat -c%s HYCOM.nc)
metric timerange_start_seconds HYCOM $HYCOM_LOWER
metric timerange_end_seconds HYCOM $HYCOM_UPPER

exit $FAILS

