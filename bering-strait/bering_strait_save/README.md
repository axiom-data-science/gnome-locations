###Bering Strait

#### September 26th - October 4th


GFS winds downloaded using GOODS are not working in PyGnome for some reason.
If they start working, `Model.json` can be enhanced with them.


```json
{
    ...
    "movers": [
        ...
        {
            "obj_type": "gnome.movers.wind_movers.WindMover",
            "id": "WindMover_1.json"
        }
    ],
    "environment": [
        {
            "id": "Wind_1.json",
            "obj_type": "gnome.environment.wind.Wind",
        }
    ],
    ...
}
```
