# Graph Summit 2025 - Workshop Digital Twin

This repository contains the material used during the **Graph Summit 2025 - Building a Graph Solution Workshops**.

The aim of the workshop is to provide a structured way to build a small Digital Twin Knowledge Graph. It answers questions from a business perspective and discusses how a Digital Twin graph could be extended for more insights and values.

It provides an environment for further experiments and can be used to show the value of Neo4j Graph Data Platform within your own organisation.

### Target Audience

The workshop is intended for those who:

- Are new to Graph Databases or Graph Analytics
- Have experience of Graph Databases or Graph Analytics who are looking for a different example of the value of Graph

---

## About the data

The data used describes a static rail network, consisting of **Sections** of lines and **Operational Points** (OP) that are connected to those Sections.

The dataset is freely available on the Register of Infrastructure (RINF) portal of the [European Union Agency for Railways](https://data-interop.era.europa.eu/) and can be downloaded from their webpage.

The format of the data has been converted to a Comma Seperated Values (`CSV`) format for expediency in the workshop.

### Operational Points

Operational Points are the start and end points of a Section.

There are many types of Operational Points, including:

- Stations
- Small Stations
- Passenger Stops
- Switches
- Junctions

Operational Points have the following properties:

- `id`: A unique identifier
- `name`: The name of the OP
- `extralabel`: The type of the OP
- `name`: The name of the OP
- `latitude`: The latitude of the OP
- `longtitude`: The longitude of the OP

### Sections

Sections are parts of the railway network and have a start and end point.

Sections have the following properties:

- `source`: start OP for this section
- `target`: end OP for this section
- `sectionlength`: the length in km of that section
- `trackspeed`: max speed allowed on that section

### Point of Interests (POI)

A point of interest (POI) is a specific point location that someone may find useful or interesting. For example, the Eiffel Tower, or Big Ben.

POIs have the following properties:

- `CITY`: City name at or close to the POI
- `POI_DESCRIPTION`: A short description of the POI
- `LINK_FOTO`: A URL to a POI Foto
- `LINK_WEBSITE`: A URL to a Website discussing POIs
- `LAT`: Latidude of the POI
- `LONG`: Longditude of the POI

> NOTE: POIs are not taken from the RINF portal

---

## Building the demo environment

The following high level steps are required, to build the demo environment (there is a [document](https://raw.githubusercontent.com/neo4j-field/gsummit2024/main/documents/Preparation%20for%20the%20Workshops%20-%202024.pdf) available as well):

1. Create a Neo4j Graph instance via any of:

   1. [Neo4j Aura](https://neo4j.com/cloud/aura-free/)
   2. [Neo4j Desktop](https://neo4j.com/download-center/)
      - If you are using Neo4j Desktop, you will need to ensure that APOC is added to any graph you create. Installation instructions can be found [here](https://neo4j.com/docs/desktop-manual/current/).
   3. [Neo4j Sandbox](https://sandbox.neo4j.com/) use a "Blank Sandbox"

2. Open Neo4j Browser and run the [`load-all-data.cypher`](https://raw.githubusercontent.com/neo4j-field/gsummit2024/main/cypher/load-all-data.cypher) script from the code directory above. You can copy & paste the complete code into the Neo4j Browser query window.

3. After the script has finished loading, you can check your data model. Run the command `CALL apoc.meta.subGraph({labels:['OperationalPoint', 'POI']})` in your Browser query window. It should look like the following (maybe yours is a bit more mixed up):

<img width="800" alt="Data Model - Digital Twin" src="https://raw.githubusercontent.com/neo4j-field/gsummit2024/main/images/Model.svg">

The model shows that we have an `OperationalPoint` Node that is connected to itself with a `SECTION` relationship. This means, `OperationalPoint`s are connected together and make up the rail network .

---

## Run some Cypher queries on your Graph

> You can find a copy of these queries in the [`all_queries.cypher`](https://raw.githubusercontent.com/neo4j-field/gsummit2024/main/cypher/all_queries.cypher) file.
>
> For the workshop we will be running through the contents of this readme.

All the queries are intended to be run in the Neo4j Browser query window. Please Copy & Paste them to execute them.

You might find the [Cypher Cheat Sheet](https://neo4j.com/docs/cypher-cheat-sheet/current/) useful, especially if you want to write your own queries, but it is not necessary for following the queries below.

---

## Simple Queries

This query will get `10` random `OperationalPoint` Nodes from the database, returning them to the browser.

```cypher
MATCH (op:OperationalPoint)
RETURN op
LIMIT 10;
```

This query will get `50` random `OperationalPoint` Nodes from the database, returning them to the browser.

```cypher
MATCH (op:OperationalPoint)
RETURN op
LIMIT 50;
```

If you are working in the EU Rail Network, the `id` property might be something you are familiar with, but the `name` property is the more friendly name. You can see if you double click on one of these, you _should_ find `SECTION` relationships joining the `OperationalPoint` to another. If it isn't - this is an indication of data quality. This might be something you would want to check on a regular basis, a query for orphaned nodes for example.

```cypher
MATCH (op:OperationalPoint)
WHERE NOT EXISTS ( (op)-[:SECTION]-() )
RETURN COUNT(op);
```

We don't want that kind of data in our Graph as it could cause problems when we want to do things like Community Detection, and keeping our data as clean as possible is a goal we should have.

```cypher
MATCH (op:OperationalPoint)
WHERE NOT EXISTS ( (op)-[:SECTION]-() )
DETACH DELETE op
```

We used something called `DETACH DELETE` here - the reason for this is that Neo4j doesn't allow for 'hanging' relationships - i.e. relationships that don't have a start or end point (or neither) - and by `DETACH` we are telling Neo4j to delete the relationships as well. If you didn't have `DETACH` you would get an error when Neo4j attempted to execute it.

So far we have only looked at how to query the Nodes, so let's run a query to find some `OperationalPoint`s _and_ the Relationships that connect them.

```cypher
MATCH path=(:OperationalPoint)--(:OperationalPoint)
RETURN path
LIMIT 100;
```

This query uses `--` to signify the relationship, and that means a couple of things:

- It is undirected - we don't mind which way the relationship goes
- It can be _any_ type - if we had Relationship types _other_ than `SECTION` between `OperationalPoint`s in our Graph we would return those as well

In order to make our query future proof, and more performant, we should add the type of the Relationship, and the Direction - `-[:SECTION]->` this helps in both senses as:

- The Type means that if in the future someone _does_ add a new relationship type, our query _still_ returns what we expect it to
- The Query Planner doesn't need to check every relationship coming from an `OperationalPoint` to see what is at the other end

```cypher
MATCH path=(:OperationalPoint)-[:SECTION]->(:OperationalPoint)
RETURN path
LIMIT 100;
```

## Filtering Queries

There are three broad ways to filter our queries:

- Inline property matching
- Inline `WHERE`
- `WHERE`

### Inline property matching

This is only useful for exact matching, i.e. the `id` _is_ `'SECst'` (for example).

```cypher
MATCH (op:OperationalPoint {id:'SECst'})
RETURN op;
```

### Inline `WHERE`

You can still do exact matching (as shown below), but by using `WHERE` you have the ability to also do things like:

- `CONTAINS`
- `STARTS WITH`
- `ENDS WITH`
- `>=`
- `<=`
- etc

```cypher
MATCH (op:OperationalPoint WHERE op.id='SECst')
RETURN op;
```

### WHERE

This is exactly the same (in terms of what you can do) as the 'Inline `WHERE`' clause, it's just at a different position in the query, and largely the choice of what you want to use is a personal one. They are _all_ equally performant.

```cypher
MATCH (op:OperationalPoint)
WHERE op.id='SECst'
RETURN op;
```

## Profiling

How do we _know_ they are all the same though? Neo4j & Cypher allow us to `PROFILE` or `EXPLAIN` our queries.

- `EXPLAIN` allows us to see what the Query Planner _thinks_ it will do, without executing the query - this is useful when we have a query that is maybe taking a long time to run and we want to see if there is a reason.
- `PROFILE` actually executes the query and returns back to us the plan that was _actually_ used, including the metrics of how much of the database was 'hit'

First we'll `EXPLAIN` our 'Inline property match' query:

```cypher
EXPLAIN
MATCH (op:OperationalPoint {id:'SECst'})
RETURN op;
```

We get a plan returned, saying we're doing a `NodeUniqueIndexSeek`, followed by a `ProduceResults` and then the result. There is no way to check the actual performance, as it hasn't actually run the query.

If we now `PROFILE` the same query:

```cypher
PROFILE
MATCH (op:OperationalPoint {id:'SECst'})
RETURN op;
```

We get the _same_ plan back, this time with the number of 'db hits' and if we look at the bottom left hand side of the query window, we should see something like:

`Cypher version: , planner: COST, runtime: PIPELINED. 5 total db hits in 2 ms.`

> ### Sidenote: What is a 'db hit'?
>
> A 'db hit' is an abstract metric to give you a comparative figure to see how one query compares to another.

Now, we can `PROFILE` our other filter queries to compare them, first the 'Inline `WHERE`'

```cypher
PROFILE
MATCH (op:OperationalPoint WHERE op.id='SECst')
RETURN op;
```

And then the other `WHERE`

```cypher
PROFILE
MATCH (op:OperationalPoint)
WHERE op.id='SECst'
RETURN op;
```

For all 3 you should see the _same_ plan and performance, which reinforces the view that you can choose whichever style suits you!

## Data Integrity

We already found, and dealt with orphaned (or disconnected) Nodes, but what if there are gaps in the networks that we need to fill. For example, the Channel Tunnel connects France to the UK, but if we run an exploratory query on our dataset:

```cypher
MATCH path=( (uk:UK)-[:SECTION]-(france:France) )
RETURN path
LIMIT 1
```

We get no results, as there is no way in our current data set to get from the UK to France.

This is a good example of **'Knowing your Domain'**, and investigating your dataset for problems from the context of your knowledge. 

In this query we take advantage of the fact that we have `BorderPoint`s and our Nodes have their Country as a label to find all the `BorderPoint`s in the UK, then all the `OperationalPoint`s in France and find the two that are closest together.

```cypher
MATCH path=( (uk:BorderPoint:UK)-[:SECTION]-(france:France) )
RETURN path
LIMIT 1
```

This query doesn't _necessarily_ generate the _right_ border crossing, but for the purposes of this workshop it is adequate. This is a point where Domain Knowledge would come in to play.

```cypher
MATCH
    (uk:UK:BorderPoint),
    (france:France)
WITH
    uk, france,
    point.distance(france.geolocation, uk.geolocation) as distance
ORDER by distance LIMIT 1
MERGE (france)-[:SECTION {sectionlength: distance/1000.0, curated: true}]->(uk);
```

## Adding properties globally

At the moment, we store the `sectionlength` (in KM) and `speed` (in KPH) properties on the `SECTION` relationship, we can use these together to work out the _best_ time we could take to cross this section on the fly:

```cypher
MATCH (s1:Station)-[s:SECTION]->(s2:Station)
WHERE
    NOT (s.speed IS NULL)
    AND NOT (s.sectionlength IS NULL )
WITH
    s1.name AS startName, s2.name AS endName,
    (s.sectionlength / s.speed) * 60 * 60 AS timeTakenInSeconds
    LIMIT 1
RETURN startName, endName, timeTakenInSeconds
```

But that's going to be inefficient, when we need to calculate a _lot_ of `SECTION`s on a route, so we can 'pre-calculate' across all our `SECTION` relationships that have the required properties:

```cypher
MATCH (:OperationalPoint)-[r:SECTION]->(:OperationalPoint)
WHERE
    r.speed IS NOT NULL
    AND r.sectionlength IS NOT NULL
SET r.traveltime = (r.sectionlength / r.speed) * 60 * 60
```

> **IMPORTANT** To be able to use the [NeoDash dashboard](https://raw.githubusercontent.com/neo4j-field/gsummit2024/main/dashboards/digital-twin_dashboard.json) in this repository fully, you will need to execute this query.

## Shortest Path Queries using different Shortest Path functions in Neo4j

In these queries, we're going to look at finding the Shortest Path from Stockholm to Malmö.

This query will find the shortest number of hops between `OperationalPoint`s, irregardless of the distance that would be travelled.

```cypher
// Cypher shortest path
MATCH
    (stockholm:OperationalPoint {name:'Stockholms central'}),
    (malmo:OperationalPoint {name:'Malmö central'})
WITH stockholm, malmo
MATCH path = shortestPath ( (malmo)-[:SECTION*]-(stockholm) )
RETURN path
```

This may not be suitable though, as we've not taken into account distance, nor speed - At a base level, we can use [APOC](https://neo4j.com/docs/apoc/current/) to take into account the `sectionlength` or indeed `traveltime`.

In this case we'll be using the [Dijkstra Shortest Path algorithm](https://neo4j.com/docs/apoc/current/overview/apoc.algo/apoc.algo.dijkstra/) to apply different weightings.

```cypher
// APOC Dijkstra shortest path with weight sectionlength
MATCH
    (stockholm:OperationalPoint {name:'Stockholms central'}),
    (malmo:OperationalPoint {name:'Malmö central'})
WITH stockholm, malmo
CALL apoc.algo.dijkstra(stockholm, malmo, 'SECTION', 'sectionlength') YIELD path, weight
RETURN length(path), weight;
```

```cypher
// APOC Dijkstra shortest path with weight traveltime
MATCH
    (stockholm:OperationalPoint {name:'Stockholms central'}),
    (malmo:OperationalPoint {name:'Malmö central'})
WITH stockholm, malmo
CALL apoc.algo.dijkstra(stockholm, malmo, 'SECTION', 'traveltime') YIELD path, weight
RETURN length(path), weight;
```

## NeoDash

Everything we've done so far has been within the development tooling of Neo4j, but for our product owners to see the benefits, we probably don't want to show a lot of Cypher.

From here, we're going to go to [NeoDash](dashboards/README.md) to take our model into something usable for those of us who don't want to code.

## Graph Data Science (GDS)

_Optional_: If you are running on an environment with GDS installed (Desktop, Sandbox etc) then you can also follow the [Graph Data Science](README.gds.md) content.
