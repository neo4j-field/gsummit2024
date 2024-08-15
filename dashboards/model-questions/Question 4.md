# Question 4: What POIs are along a route?

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

In this query we find the shortest path between Malmö Central and London Paddington. That path displayed on the query window looks good, but we need to extract those stations. 

A path contains `nodes()` and `relationships()`, we're not interested in relationships in this case, and we're also not interested in things like `Switch`es, as you can't get off the train at those points. The `OperationalPoint`s that we _are_ interested in are:

* `Station`
* `SmallStation`
* `PassengerTerminal`

First, let's get the nodes, and filter by their labels:

```cypher
MATCH 
    (malmo:OperationalPoint {name:'Malmö central'}),
    (paddington:OperationalPoint {name:'PAD London Paddington'})
WITH 
    malmo, paddington
MATCH shortest = shortestPath( (malmo)-[:SECTION*]-(paddington) )
WITH nodes(shortest) AS nodes
UNWIND nodes AS station
WITH station
WHERE 'SmallStation' IN labels(station) 
      OR 'Station' IN labels(station) 
      OR 'PassengerTerminal' IN labels(station) 
RETURN station
```

To do this, we first use the [`nodes()`](https://neo4j.com/docs/cypher-manual/current/functions/list/#functions-nodes) function to extract _all_ the nodes.

```cypher
WITH nodes(shortest) AS nodes
```

Then, because `nodes()` returns a list, we want to use [`UNWIND`](https://neo4j.com/docs/cypher-manual/current/clauses/unwind/#unwind-creating-nodes-from-a-list-parameter) to filter these `OperationalPoint`s:

```cypher
UNWIND nodes AS station
```

Now we're working on individual nodes, so we can apply our filters (using [`labels()`](https://neo4j.com/docs/cypher-manual/current/functions/list/#functions-labels)) to get just the type of `OperationalPoint`s we want.

```cypher
WITH station
WHERE 'SmallStation' IN labels(station) 
      OR 'Station' IN labels(station) 
      OR 'PassengerTerminal' IN labels(station) 
```

At this stage we have a collection of the places passengers could get on/off of the train.

Now we need to find Points of Interest (POI) near to those places. Luckily, our dataset included a [`Point`](https://neo4j.com/docs/cypher-manual/current/values-and-types/spatial/#spatial-values-point-type) location for each of our `OperationalPoint`s and indeed `POI`s, this is a Lat/Long value indicating the position on the planet.

If we combine that with the [`point.distance()`](https://neo4j.com/docs/cypher-manual/current/functions/spatial/#functions-distance) we can work out which POIs are near our stations on the route. The value returned from `point.distance()` is the distance in Metres between two points.

```cypher
//We get a POI
MATCH (poi:POI)
//And MATCH with it, WHERE it's within a given radius
WHERE point.distance(poi.geolocation, station.geolocation) < radiusInMetres
```

All together this gives us:

```cypher
//Let's find all POIs within a 5KM radius
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
      OR 'PassengerTerminal' IN labels(station) 
MATCH (poi:POI)
WHERE point.distance(poi.geolocation, station.geolocation) < radiusInMetres
RETURN 
    station.name AS Station,
    poi.description AS POI,
    point.distance(poi.geolocation, station.geolocation) AS DistanceInMetres
ORDER BY DistanceInMetres
```