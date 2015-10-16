#!/bin/bash

# Get GFS
curl 'http://gnome.orr.noaa.gov/goods/currents/GFS/get_data' -H 'Host: gnome.orr.noaa.gov' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:41.0) Gecko/20100101 Firefox/41.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: http://gnome.orr.noaa.gov/goods/currents/GFS/get_data' -H 'Connection: keep-alive' --data 'dataset=Global_0p5deg&selected_file_url=http%3A%2F%2Fthredds.ucar.edu%2Fthredds%2FdodsC%2Fgrib%2FNCEP%2FGFS%2FGlobal_0p5deg%2Fbest&err_placeholder=&start_time=0&time_step=1&end_time=200&NorthLat=70.5&WestLon=-179.5&EastLon=-160&SouthLat=55.5&Stride=1&time_zone=0&submit=Get+Data' -o GFS_download.nc
ncdump -h GFS_download.nc
if [ $? -eq 0 ]; then
    mv GFS_download.nc GFS.nc
else
    echo "Problem downloading GFS files"
fi

# Get HYCOM
curl 'http://gnome.orr.noaa.gov/goods/currents/HYCOM/get_data' -H 'Host: gnome.orr.noaa.gov' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:41.0) Gecko/20100101 Firefox/41.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: http://gnome.orr.noaa.gov/goods/currents/HYCOM/get_data' -H 'Connection: keep-alive' --data 'dataset=&selected_file_url=http%3A%2F%2Ftds.hycom.org%2Fthredds%2FdodsC%2FGLBa0.08%2Flatest&err_placeholder=&start_time=0&time_step=1&end_time=9&NorthLat=70.5&WestLon=-179.5&EastLon=-160&SouthLat=55.5&Stride=1&time_zone=0&submit=Get+Data' -o HYCOM_download.nc
ncdump -h HYCOM_download.nc
if [ $? -eq 0 ]; then
    mv HYCOM_download.nc HYCOM.nc
else
    echo "Problem downloading HYCOM files"
fi
