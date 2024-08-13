# What POIs are along a route?

> Can we make revenue from referral commissions? Find busier routes during tourism season?

## Introduction

As we know from the [previous question](Question%203.md) - we don't have Route data, _but_ we do have `POI` (Point Of Interest) data and `Station` data, so what we can do is take a 'fake route' and see what POIs are on the 'route' and maybe see if we could sell some extra tickets.

We've seen how to query paths, which for the sake of this example, we can call routes:

```cypher
MATCH 
    (malmo:OperationalPoint {name:'Malmö central'}),
    (paddington:OperationalPoint {name:'PAD London Paddington'})
WITH 
    malmo, paddington
MATCH shortest = shortestPath( (malmo)-[:SECTION*]-(paddington) )
RETURN shortest
```

In this query we find the shortest path between Malmö Central and London Paddington. That path displayed on the query window looks good, but we need to extract those stations

WITH 5000 AS radiusInMetres
MATCH 
    (malmo:OperationalPoint {name:'Malmö central'}),
    (paddington:OperationalPoint {name:'PAD London Paddington'})
WITH 
    malmo, paddington, radiusInMetres
MATCH shortest = shortestPath( (malmo)-[:SECTION*]-(paddington) )
UNWIND nodes(shortest) AS station 
WITH station, radiusInMetres
WHERE 'SmallStation' IN labels(station) 
      OR 'Station' IN labels(station) 
MATCH (poi:POI)
WHERE point.distance(poi.geolocation, station.geolocation) < radiusInMetres
RETURN  station.name AS `Station Name`, poi.description AS `Point of Interest`, point.distance(poi.geolocation, station.geolocation) AS `Distance (m)`


```cypher
WITH 5000 AS radiusInMetres
MATCH 
  (paddington:OperationalPoint {name:'PAD London Paddington'})
MATCH (poi:POI)
WHERE point.distance(poi.geolocation, paddington.geolocation) < radiusInMetres
RETURN 
  poi.description AS Description, 
  point.distance(poi.geolocation, paddington.geolocation) AS `Distance (m)`
ORDER BY `Distance (m)` ASC
```


WITH 8000 AS radiusInMetres
MATCH 
    (malmo:OperationalPoint {name:'Malmö central'}),
    (paddington:OperationalPoint {name:'PAD London Paddington'})
WITH 
    malmo, paddington, radiusInMetres
MATCH shortest = shortestPath( (malmo)-[:SECTION*]-(paddington) )
UNWIND nodes(shortest) AS station 
WITH station, radiusInMetres
WHERE 'SmallStation' IN labels(station) 
      OR 'Station' IN labels(station) 
      OR 'PassengerTerminal' IN labels(station) 
MATCH (poi:POI)
WHERE point.distance(poi.geolocation, station.geolocation) < radiusInMetres
WITH 
    station.name AS Station,
    {`POI`: poi.description, Distance: point.distance(poi.geolocation, station.geolocation)} AS poi
RETURN Station, COLLECT(poi)


