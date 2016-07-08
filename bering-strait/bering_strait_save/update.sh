#!/bin/bash

FAILS=0
LOC_NAME=bering-strait

# WORKAROUND: use system curl to avoid certificate problems with anaconda curl
# see https://github.com/conda/conda-recipes/issues/352 and http://stackoverflow.com/a/35956375/84732

#check for ncdump
command -v ncdump >/dev/null 2>&1 || { echo "ncdump is required but not installed (aptitude install -y netcdf-bin)" >&2; exit 1; }

truncate --size 0 stats.prom

metric ()
{
    # metric name, model name, value, additional labels*
    local metric_name=$1
    local model_name=$2
    local value=$3
    shift 3

    # join additional labels
    if [[ $# -gt 0 ]]; then
        local IFS=","
        local additional=",$*"
    fi

    echo "${PROM_METRIC_PREFIX}gnomelocations_$metric_name{location=\"$LOC_NAME\",model=\"$model_name\"$additional} $value" >>stats.prom
}

get_time_bounds ()
{
    # if $2/$3 are passed in, they are a lower/upper clamp on time value.
    # we use it to lock HYCOM down to the range provided by GFS, because HYCOM is too big most of the time, so we need to get an accurate subset
    local model=$1
    local sfu=_
    local dataset=_

    case $model in
        HYCOM)
            sfu=http://tds.hycom.org/thredds/dodsC/GLBa0.08/expt_91.2
            dataset=
            ;;
        GFS)
            sfu=http://thredds.ucar.edu/thredds/dodsC/grib/NCEP/GFS/Global_onedeg/best
            dataset=Global_onedeg
            ;;
    esac

    capdata=$(/usr/bin/curl -X POST -F "selected_file_url=$sfu" -F 'dataset=$dataset' https://gnome.orr.noaa.gov/goods/currents/$model/subset | hxnormalize -e -x | tee debug.html | hxselect "#start_time option" | hxpipe | tail -n+2)
    if [ $? -ne 0 ]
    then
        echo "(could not get $model bounds, using defaults)"
        return 1
    fi

    if (( $# > 2 )); then
        local OFFSETS=()
        local STAMPS=()

        while read -r -a arr
        do
            #echo "${arr[2]}"
            OFFSETS+=("${arr[2]}")

            read -r waste
            read -r ndate
            IFS=" " read -ra DATESPLIT <<< "$(echo ${ndate:1} | tr '\\n' ' ')"
            slime=$(date -d "${DATESPLIT[0]}" -u +"%s")
            read -r waste

            STAMPS+=("$slime")

        done <<< "$capdata"

        local UPPER=$((${#STAMPS[@]} - 1))

        LOW=0
        for i in $(seq 0 $UPPER); do
            if [[ "$2" -le "${STAMPS[$i]}" ]]; then
                LOW=$i
                break
            fi
        done

        HIGH=$UPPER
        for i in $(seq 0 $UPPER); do
            if [[ "$3" -le "${STAMPS[$i]}" ]]; then
                HIGH=$i
                break
            fi
        done

        START_TIMESTEP=${OFFSETS[$LOW]}
        END_TIMESTEP=${OFFSETS[$HIGH]}

    else
        bounds=($(echo "$capdata" | grep "value CDATA" | cut -d' ' -f 3))

        # make sure its an array of length > 1
        if [[ -n ${bounds[0]} && ${#bounds[@]} -gt 1 && -n ${bounds[${#bounds[@]} -1]} ]]; then
            START_TIMESTEP=${bounds[0]}
            END_TIMESTEP=${bounds[${#bounds[@]} - 1]}
        else
            echo "(could not get $model bounds, using defaults (2))"
            return 1
        fi
    fi
}

##############################################################################
# GFS
##############################################################################

# get timestep bounds for GFS
START_TIMESTEP=0
END_TIMESTEP=208
get_time_bounds GFS
echo "GFS Timesteps: $START_TIMESTEP - $END_TIMESTEP"

# Get GFS
START_GFS=$(date +%s%3N)
/usr/bin/curl -k 'https://gnome.orr.noaa.gov/goods/currents/GFS/get_data' -H 'Host: gnome.orr.noaa.gov' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:40.0) Gecko/20100101 Firefox/40.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: http://gnome.orr.noaa.gov/goods/currents/GFS/get_data' -H 'Connection: keep-alive' --data "dataset=Global_0p5deg&selected_file_url=http%3A%2F%2Fthredds.ucar.edu%2Fthredds%2FdodsC%2Fgrib%2FNCEP%2FGFS%2FGlobal_0p5deg%2Fbest&err_placeholder=&start_time=$START_TIMESTEP&time_step=1&end_time=$END_TIMESTEP&NorthLat=70.5&WestLon=175&xDateline=1&EastLon=-160&SouthLat=55.5&Stride=1&time_zone=0&submit=Get+Data" -o GFS_download.nc
END_GFS=$(date +%s%3N)

ncdump -h GFS_download.nc
NCD_C=$?
if [ $NCD_C -eq 0 ]; then
    mv GFS_download.nc GFS.nc
else
    echo "Problem downloading GFS files"
    file GFS_download.nc
    [ $(file --mime-type GFS_download.nc | cut -d':' -f2 | cut -d'/' -f1 | tr -d ' ') == "text" ] && cat GFS_download.nc
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

##############################################################################
# HYCOM
##############################################################################

# get timestep bounds for HYCOM
START_TIMESTEP=0
END_TIMESTEP=39
get_time_bounds HYCOM $GFS_LOWER $GFS_UPPER
echo "HYCOM Timesteps: $START_TIMESTEP - $END_TIMESTEP"

START_HYCOM=$(date +%s%3N)
/usr/bin/curl -k 'https://gnome.orr.noaa.gov/goods/currents/HYCOM/get_data' -H 'Origin: https://gnome.orr.noaa.gov' -H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.8' -H 'Upgrade-Insecure-Requests: 1' -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.28 Safari/537.36' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Cache-Control: max-age=0' -H 'Referer: https://gnome.orr.noaa.gov/goods/currents/HYCOM/get_data' -H 'Connection: keep-alive' --data "dataset=&selected_file_url=http%3A%2F%2Ftds.hycom.org%2Fthredds%2FdodsC%2FGLBa0.08%2Fexpt_91.2&err_placeholder=&start_time=$START_TIMESTEP&time_step=1&end_time=$END_TIMESTEP&NorthLat=70.5&WestLon=175&xDateline=1&EastLon=-160&SouthLat=55.5&Stride=1&time_zone=0&submit=Get+Data" --compressed -o HYCOM_download.nc
END_HYCOM=$(date +%s%3N)

ncdump -h HYCOM_download.nc
NCD_C=$?
if [ $NCD_C -eq 0 ]; then
    mv HYCOM_download.nc HYCOM.nc
else
    echo "Problem downloading HYCOM files"
    file HYCOM_download.nc
    [ $(file --mime-type HYCOM_download.nc | cut -d':' -f2 | cut -d'/' -f1 | tr -d ' ') == "text" ] && cat HYCOM_download.nc
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
metric model_size_bytes HYCOM $(stat -c%s HYCOM.nc)
metric timerange_start_seconds HYCOM $HYCOM_LOWER
metric timerange_end_seconds HYCOM $HYCOM_UPPER

exit $FAILS

