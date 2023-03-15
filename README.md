# Graph Summit 2023 EMEA - Workshop Digital Twin

This repository contains the material used during the **Graph Summit 2023 - Building a Graph Solution Workshops**. 

The aim of the workshop is to provide a structured way to build a small Digital Twin Knowledge Graph. It answers questions from a business perspective and discusses how a Digital Twin graph could be extended for more insights and values.

It provides an environment for further experiments and can be used to show the value of Neo4j Graph Data Platform within your own organisation.

### Target Audience

The workshop is intended for those who:
* Are new to Graph Databases or Graph Analytics,
* Have experience of Graph Databases or Graph Analytics who are looking for a different example of the value of Graph,

---
## About the data

The data used describes a static rail network, consisting of **Sections** of lines and **Operational Points** (OP) that are connected to those Sections.

The dataset is freely available on the Register of Infrastructure (RINF) portal of the [European Union Agency for Railways](https://data-interop.era.europa.eu/) and can be downloaded from their webpage.

The format of the data has been converted to a Comma Seperated Values (`CSV`) format for expediency in the workshop.

### Operational Points
Operational Points are the start and end points of a Section. 

There are many types of Operational Points, including:
* Stations, 
* Small Stations, 
* Passenger Stops, 
* Switches, 
* Junctions,

Operational Points have the following properties:

- `id`: A unique identifier
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

The following high level steps are required, to build the demo environment:

1. Create a Neo4j Graph instance via any of:
    1. [Neo4j Desktop](https://neo4j.com/download-center/). 
        - If you are using Neo4j Desktop, you will need to ensure that both GDS and APOC are added to any graph you create. Installation instructions can be found [here](https://neo4j.com/docs/desktop-manual/current/).
    2. [Neo4j Sandbox](https://sandbox.neo4j.com/) use a "Blank Sandbox"

2. Open Neo4j Browser and run the [`load-all-data.cypher`](https://raw.githubusercontent.com/cskardon/gsummit2023/main/cypher/load-all-data.cypher) script from the code directory above. You can copy & paste the complete code into the Neo4j Browser query window.

3. After the script has finished loading, you can check your data model. Run the command `CALL db.schema.virtualization` in your Browser query window. It should look like the following (maybe yours is a bit more mixed up):

<img width="800" alt="Data Model - Digital Twin" src="https://github.com/neo4j-field/gsummit2023/blob/791e76740b212686b73230a1cdca851b643bfbe1/images/data-model-all_labels.png">

If you would hide all labels except the label "OperationalPoint" and "OperationalPointName" and "POI", you will see the basic data model that looks like this:

<img width="540" alt="Data Model - Digital Twin" src="https://github.com/neo4j-field/gsummit2023/blob/68b41bce4c3ecdd8c73da58f55b7c34790907f4d/images/data-model-with-poi.png">

As you can see now in the data model, there is a OperationalPoint label and it is connected to itself with a SECTION relationship. This means, OperationalPoints are connected together and make up the rail network (as in the real world). A station (or other Operational Units like Switches, Passenger Stop, etc.) are connected as a separate node by the "NAMED" relationship that represents their name, etc..

4. Now you can find certain queries in the `./code` directory in the file called `all_queries.cypher` or if you keep on reading. Try them out by cutting and pasting them into the Neo4j browser like shown below. We will also do that in the workshop!

---
## Run some Cypher queries on your Graph (database)

Let's start with some simple queries. Copy and Paste them into your Neo4j Browser in order to run them.

Show Operational Point Names and limit the number of returned OPs to 10:
```cypher
MATCH (op:OperationalPointName) RETURN op LIMIT 10;
```

Show OPs and limit the number of returned OPs to 50:
```cypher
MATCH (op:OperationalPoint) RETURN op LIMIT 50;
```

Show OperationalPoints and Sections, have a look how those two queries differ!
```cypher
MATCH path=(:OperationalPoint)--(:OperationalPoint) RETURN path LIMIT 100;

MATCH path=(:OperationalPoint)-[:SECTION]->(:OperationalPoint) RETURN path LIMIT 100;
```

using the WHERE clause in two different way:
```cypher
MATCH (op:OperationalPoint {id:'SECst'}) RETURN op;

MATCH (op:OperationalPoint) WHERE op.id='SECst' RETURN op;
```
You can start exploring the graph in Neo4j Browser by clicking on the returned node and then clicking on the graph symbol to extend the node and see attached nodes. Go for a couple of sections and see, where it goes to.

Profile and explain some of the queries to see their execution plans:
```cypher
EXPLAIN MATCH (op:OperationalPoint  {id:'DE000BL'}) RETURN op;

EXPLAIN MATCH (op:OperationalPoint) WHERE op.id='DE000BL' RETURN op;

PROFILE MATCH (op:OperationalPoint{id:'DE000BL'}) RETURN op;

PROFILE MATCH (op:OperationalPoint) WHERE op.id='DE000BL' RETURN op;
```

## Fixing some gaps

Before we move on running some more complex queries we figured, there are gaps in some of the sections in Denmark. Maybe otheres also have gaps, but we did not yet find them.

Trying to do a shortest Path between Stockholm and Berlin, did not work initially. With some trail and error wie figured, there were two gaps on the way from Stockholm (id: 'SECst') and Berlin Main Station (id: 'DE000BL'). The gaps were between Nyborg with id DK00039 and OP DK00200. 

A second gap we found at the Border from Denmark to Germany close to Flensburg. The BorderPoint did not have a connection to both railway networks of Denmark and Germany. We fixed that with the following queries:

Fixing the Gaps in Denmark:
```cypher
// DK00320 - German border
MATCH 
    (op1:OperationalPoint WHERE op1.id STARTS WITH 'DE')-[:SECTION]-(op2:OperationalPoint WHERE op2.id STARTS WITH 'EU'),
    (op3:OperationalPoint WHERE op3.id STARTS WITH 'DK')
WITH op2, op3, point.distance(op3.geolocation, op2.geolocation) AS distance
ORDER by distance LIMIT 1
MERGE (op3)-[:SECTION {sectionlength: distance/1000.0, curated: true}]->(op2);
```

```cypher
// DK00200 - Nyborg
MATCH 
    (op1:OperationalPoint WHERE op1.id = 'DK00200'),
    (op2:OperationalPoint)-[:NAMED]->(opn:OperationalPointName WHERE opn.name = "Nyborg")
MERGE (op1)-[:SECTION {sectionlength: point.distance(op1.geolocation, op2.geolocation)/1000.0, curated: true}]->(op2);
```

And also connect the UK via the channel:
```cypher
// EU00228 - FR0000016210 through the channel
MATCH 
    (op1:OperationalPoint WHERE op1.id STARTS WITH 'UK')-[:SECTION]-(op2:OperationalPoint WHERE op2.id STARTS WITH 'EU'),
    (op3:OperationalPoint WHERE op3.id STARTS WITH 'FR')
WITH op2, op3, point.distance(op3.geolocation, op2.geolocation) as distance
ORDER by distance LIMIT 1
MERGE (op3)-[:SECTION {sectionlength: distance/1000.0, curated: true}]->(op2);
```

What you will also recognize is, that there are parts not connected to the railway network. That might be privately used OPs and sections or it also could be an issue of missing data in the data sets of that particular country. This is a way to find them:

```cypher
// Find Operational Points not connected by Sections in Denmark
MATCH (dk:Denmark:OperationalPoint WHERE NOT EXISTS{(dk)-[:SECTION]-()})
RETURN dk
```

```
// Find Operational Points not connected by Sections over the whole dataset
MATCH (op:OperationalPoint WHERE NOT EXISTS{(op)-[:SECTION]-()})
RETURN op;
```

### Last thing before moving to path analysis

You can add a technical property to the SECTION relationships that calculates the time of travel on that section. It assumes, the train is going the max speed for that section. A query to add that is the following:

```cypher
// Set new traveltime parameter in seconds for a particular section --> requires speed and 
// sectionlength properties set on this section!
MATCH (:OperationalPoint)-[r:SECTION]->(:OperationalPoint)
WHERE 
    r.speed IS NOT NULL 
    AND r.sectionlength IS NOT NULL
WITH r, r.speed * (1000.0/3600.0) AS speed_ms
SET r.traveltime = r.sectionlength / speed_ms
RETURN count(*);
```
**IMPORTANT** the above query needs to run for the NeoDash Dashboard to run entirely!


### Shortest Path Queries using different Shortest Path functions in Neo4j

```cypher
// Cypher shortest path
MATCH sg=shortestPath( (op1:OperationalPoint WHERE op1.id = 'BEFBMZ')-[:SECTION*]-(op2:OperationalPoint WHERE op2.id = 'DE000BL') )
RETURN sg;
```


```cypher
// APOC Dijkstra shortest path with weight sectionlength
MATCH (n:OperationalPoint), (m:OperationalPoint)
WHERE n.id = "BEFBMZ" and m.id = "DE000BL"
WITH n,m
CALL apoc.algo.dijkstra(n, m, 'SECTION', 'sectionlength') YIELD path, weight
RETURN path, weight;
```

### Graph Data Science (GDS)

We will be projecting a graph into the GDS [Graph Catalog](https://neo4j.com/docs/graph-data-science/current/management-ops/graph-catalog-ops/) using [Native Projection](https://neo4j.com/docs/graph-data-science/current/management-ops/projections/graph-project/) 

If you want to ensure you have no existing projections you can run the following Cypher to clear your Graph Catalog:

```cypher
CALL gds.graph.list() YIELD graphName AS toDrop
CALL gds.graph.drop(toDrop) YIELD graphName
RETURN "Dropped " + graphName;
```

We will project a graph named 'OperationalPoints' into the Graph Catlog. We will take the `OperationalPoint` Node and the `SECTION` Relationship to form a monopartite graph:

```cypher
CALL gds.graph.project(
    'OperationalPoints',
    'OperationalPoint',
    {SECTION: {orientation: 'UNDIRECTED'}},
    {
        relationshipProperties: 'sectionlength'
    }
);
```

We can calculate the shortest path using GDS Dijkstra:

```cypher
MATCH (source:OperationalPoint WHERE source.id = 'BEFBMZ'), (target:OperationalPoint WHERE target.id = 'DE000BL')
CALL gds.shortestPath.dijkstra.stream('OperationalPoints', {
    sourceNode: source,
    targetNode: target,
    relationshipWeightProperty: 'sectionlength'
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs, path
RETURN *;
```

Now we use the Weakly Connected Components Algo to identify those nodes that are not well connected to the network:

```cypher
CALL gds.wcc.stream('OperationalPoints') YIELD nodeId, componentId
WITH collect(gds.util.asNode(nodeId).id) AS nodes, componentId
RETURN nodes, componentId 
ORDER BY size(nodes) ASC;
```

Matching a specific OperationalPoint  from the list above --> use the Neo4j browser output to check the network it is belonging to (see the README file for more information). You will figure out, that it is an isolated network of OperationalPoint s / stations / etc.:
```cypher
MATCH (op:OperationalPoint) WHERE op.id='BEFBMZ' RETURN op;
```

Use the betweenness centrality algo, to find out hot spots in terms of
sections running through a specific OperationalPoint .
```cypher
CALL gds.betweenness.stream('OperationalPoints')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).id AS id, score
ORDER BY score DESC;
```
There is much more you can do, using this data set. This is just a teaser and we hope you have some more queries you find and test.
