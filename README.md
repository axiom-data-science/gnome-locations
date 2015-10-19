A set of custom [Gnome](http://response.restoration.noaa.gov/oil-and-chemical-spills/oil-spills/response-tools/gnome.html)/[PyGnome](https://github.com/NOAA-ORR-ERD/PyGnome) locations created by [Axiom Data Science](http://axiomdatascience.com).


**Don't use Location Files to model real oil spills!** Take the [GNOME Learning the Basics Tour](http://response.restoration.noaa.gov/oil-and-chemical-spills/oil-spills/resources/gnome-users-manual-and-tour.html) to find out why not.

## Using Docker to update location files

The Dockerfile in this repository creates an image capable of updating locations via a recursive `update.sh`.

To build,

```sh
$ docker build -t gnome-locations-updater .
```

To run, use a volume mount (`-v`) in your run command to mount the location directories from the host machine:

```
$ docker run -it --rm \
  -v /home/dev/gnome-locations/bering-strait:/data/bering-strait \
  ...
  gnome-locations-updater
```

A script with these contents may be used as a cron script, such as `/etc/cron.daily/update-gnome-locations`.

