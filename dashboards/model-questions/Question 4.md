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

This query returns a path containing `nodes()` and `relationships()`, we're not interested in relationships in this case.

## Using `IS_NEAR`

When we loaded our data, (and when we talked about the model) we created an `IS_NEAR` relationship, which indicates which station is closest to a given POI. 

To do this we're going to use [Pattern Comprehension](https://neo4j.com/docs/cypher-manual/current/values-and-types/lists/#cypher-pattern-comprehension) on the [`nodes()`](https://neo4j.com/docs/cypher-manual/current/functions/list/#functions-nodes) function:

```cypher
WITH 
    [
        station IN nodes(shortest) 
        WHERE (station)-[:IS_NEAR]->(:POI) 
        | station
    ] AS stations
```

We loop through the results of the `nodes(shortest)` function selecting a variable named `station` - we then look specifically for the pattern `(station)-[:IS_NEAR]->(:POI)`, and finally, if the pattern `MATCH`es, select it into a list called `stations`:

```cypher
        | station
    ] AS stations
```

Once we have this list, we can [`UNWIND`](https://neo4j.com/docs/cypher-manual/current/clauses/unwind/) the `stations`, `MATCH` the `POI` and finally, `RETURN` the `station` name and POI description.

```cypher
MATCH 
    (malmo:OperationalPoint {name:'Malmö central'}),
    (paddington:OperationalPoint {name:'PAD London Paddington'})
WITH 
    malmo, paddington
MATCH shortest = shortestPath( (malmo)-[:SECTION*]-(paddington) )
WITH 
    [
        station IN nodes(shortest) 
        WHERE (station)-[:IS_NEAR]->(:POI) 
        | station
    ] AS stations
UNWIND stations AS station
MATCH (station)-[:IS_NEAR]->(p:POI)
RETURN station.name AS Station, p.description AS POI
```

---

## Using `Point` to choose the distance

We don't have to do this, as we've already established the `POI`s that are nearest to our route, but it doesn't include _all_ the POIs, and what if our clients want to be a bit adventurous and travel up to 5km from a station - after all - just being close doesn't mean the station is a good station to use - accessbility etc (which is not in our dataset) would be important.

In our query from the 'Introduction' we found the shortest path between Malmö Central and London Paddington. That path displayed on the query window looks good, but we need to extract those stations. 

For this query we're only interested in particular types of `OperationalPoint`s - as you can't get off at a `Switch`. The `OperationalPoint`s that we _are_ interested in are:

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
WITH [
        station IN nodes(shortest) WHERE 
            'SmallStation' IN labels(station) 
            OR 'Station' IN labels(station) 
            OR 'PassengerTerminal' IN labels(station) 
        | station
    ] AS stations
RETURN stations
```

To do this, we're going to use [List Comprehension](https://neo4j.com/docs/cypher-manual/current/values-and-types/lists/#cypher-list-comprehension) on the `nodes()` function:

```cypher
WITH [
        station IN nodes(shortest) WHERE 
            'SmallStation' IN labels(station) 
            OR 'Station' IN labels(station) 
            OR 'PassengerTerminal' IN labels(station) 
        | station
    ] AS stations
```

To explain, first we loop through the `nodes(shortest)` collection, 'selecting' a `station`.

```cypher
station IN nodes(shortest) 
```

We then use `WHERE` to apply our filters (using [`labels()`](https://neo4j.com/docs/cypher-manual/current/functions/list/#functions-labels)) to get just the type of `OperationalPoint`s we want.

We then select the `station` to output as a list that we will call `stations`:

```cypher
    | station 
] AS stations
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
WITH [
        station IN nodes(shortest) WHERE 
            'SmallStation' IN labels(station) 
            OR 'Station' IN labels(station) 
            OR 'PassengerTerminal' IN labels(station) 
        | station
    ] AS stations, radiusInMetres
UNWIND stations AS station
MATCH (poi:POI)
WHERE point.distance(poi.geolocation, station.geolocation) < radiusInMetres
RETURN 
    station.name AS Station,
    poi.description AS POI,
    round(point.distance(poi.geolocation, station.geolocation), 2) AS DistanceInMetres
ORDER BY DistanceInMetres
```

> _Why have you put `WITH 5000 AS radiusInMetres` at the top of the query? Why not at the place it's used?_
> This is a style choice, by having at the top it makes it clear it is 'changeable' - and means we can easily increase/decrease the size without having to hunt out 'magic numbers' in our codebase. Arguably in this case, as we're only using it once, we could ignore it, but in situations where a 'constant' is used in multiple places, this saves time when doing replacements.
>
> A side effect is that if we switch it out for a [parameter](https://neo4j.com/docs/cypher-manual/current/syntax/parameters/) it's a simple replacement.
