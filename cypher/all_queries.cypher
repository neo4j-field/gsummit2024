//
// This file contains all queries of the README and some additional ones
// Be aware that some might change your data!
//

// Show Operation Point Names and limit the number of returned OPs to 10:
MATCH (opn:OperationalPointName) 
RETURN opn 
LIMIT 10;

// Show OPs and limit the number of returned sections to 50:
MATCH (op:OperationalPoint) 
RETURN op 
LIMIT 50;

// Find disconnected OperationalPoints
MATCH (op:OperationalPoint)
WHERE NOT EXISTS ( (op)-[:SECTION]-() )
RETURN COUNT(op);

// Clean them from the database.
MATCH (op:OperationalPoint)-[NAMED]->(opn:OperationalPointName)
WHERE NOT EXISTS ( (op)-[:SECTION]-() )
DETACH DELETE op, opn

// Show OperationalPoints and Sections
// First has no type or direction
MATCH path=(:OperationalPoint)--(:OperationalPoint) 
RETURN path 
LIMIT 100;

//Second defines type and direction, and should be preferred for performance / safety reasons
MATCH path=(:OperationalPoint)-[:SECTION]->(:OperationalPoint) 
RETURN path 
LIMIT 100;


// The three ways to filter our query
MATCH (op:OperationalPoint {id:'SECst'}) 
RETURN op;

MATCH (op:OperationalPoint WHERE op.id='SECst') 
RETURN op;

MATCH (op:OperationalPoint) 
WHERE op.id='SECst' 
RETURN op;

// Explain doesn't execute the query
EXPLAIN
MATCH (op:OperationalPoint {id:'SECst'}) 
RETURN op;

//Profiling our three filter queries to show they are the same performance
PROFILE
MATCH (op:OperationalPoint {id:'SECst'}) 
RETURN op;

PROFILE
MATCH (op:OperationalPoint WHERE op.id='SECst')
RETURN op;

PROFILE
MATCH (op:OperationalPoint) 
WHERE op.id='SECst' 
RETURN op;

// Query for Gaps in the Rail Network
MATCH path=( (uk:UK)-[:SECTION]-(france:France) )
RETURN path 
LIMIT 1

// Or other routes we know should exist:
MATCH 
    (:OperationalPointName {name:'Stockholms central'})<-[:NAMED]-(stockholm:OperationalPoint),
    (:OperationalPointName {name:'Berlin Hauptbahnhof - Lehrter Bahnhof'})<-[:NAMED]-(berlin:OperationalPoint)
WITH stockholm, berlin
MATCH p= ((stockholm)-[:SECTION]-(berlin))
RETURN p 
LIMIT 1

// Germany / Denmark Gap
MATCH 
    (germany:BorderPoint:Germany),
    (denmark:Denmark)
WITH 
    germany, denmark, 
    point.distance(germany.geolocation, denmark.geolocation) AS distance
ORDER BY distance LIMIT 1
MERGE (germany)-[:SECTION {sectionlength: distance/1000.0, curated: true}]->(denmark);

// Nyborg / Hjulby Gap
MATCH 
    (:OperationalPointName {name: 'Nyborg'})<-[:NAMED]-(nyborg:OperationalPoint),
    (:OperationalPointName {name: 'Hjulby'})<-[:NAMED]-(hjulby:OperationalPoint)-[:NAMED]->
MERGE (nyborg)-[:SECTION {sectionlength: point.distance(nyborg.geolocation, hjulby.geolocation)/1000.0, curated: true}]->(hjulby);

//UK / France Border Gap
MATCH 
    (uk:UK:BorderPoint),
    (france:France)
WITH 
    uk, france, 
    point.distance(france.geolocation, uk.geolocation) as distance
ORDER by distance LIMIT 1
MERGE (france)-[:SECTION {sectionlength: distance/1000.0, curated: true}]->(uk);


// Working out the travel time on a section dynamically:
MATCH (o1:OperationalPointName)<-[:NAMED]-(s1:Station)-[s:SECTION]->(s2:Station)-[:NAMED]->(o2:OperationalPointName)
WHERE 
    NOT (s.speed IS NULL) 
    AND NOT (s.sectionlength IS NULL )
WITH 
    o1.name AS startName, o2.name AS endName,
    (s.sectionlength / s.speed) * 60 * 60 AS timeTakenInSeconds
    LIMIT 1
RETURN startName, endName, timeTakenInSeconds


// Storing that on all the sections to reduce the need for calculations
MATCH (:OperationalPoint)-[r:SECTION]->(:OperationalPoint)
WHERE 
    r.speed IS NOT NULL 
    AND r.sectionlength IS NOT NULL
SET r.traveltime = (r.sectionlength / r.speed) * 60 * 60

// Now we can just do:
MATCH (o1:OperationalPointName)<-[:NAMED]-(s1:Station)-[s:SECTION]->(s2:Station)-[:NAMED]->(o2:OperationalPointName)
WHERE 
    NOT (s.speed IS NULL) 
    AND NOT (s.sectionlength IS NULL )
RETURN o1.name AS startName, o2.name AS endName, s.traveltime AS timeTakenInSeconds

// Shortest Path Queries using different Shortest Path functions in Neo4j

// Cypher shortest path
MATCH 
    (:OperationalPointName {name:'Bruxelles-Midi | Brussel-Zuid'})<-[:NAMED]-(brussels:OperationalPoint),
    (:OperationalPointName {name:'Berlin Hauptbahnhof - Lehrter Bahnhof'})<-[:NAMED]-(berlin:OperationalPoint)
WITH brussels, berlin
MATCH path = shortestPath ( (brussels)-[:SECTION*]-(berlin) )
RETURN path

// APOC Dijkstra shortest path with weight sectionlength
MATCH 
    (:OperationalPointName {name:'Bruxelles-Midi | Brussel-Zuid'})<-[:NAMED]-(brussels:OperationalPoint),
    (:OperationalPointName {name:'Berlin Hauptbahnhof - Lehrter Bahnhof'})<-[:NAMED]-(berlin:OperationalPoint)
WITH brussels, berlin
CALL apoc.algo.dijkstra(brussels, berlin, 'SECTION', 'sectionlength') YIELD path, weight
RETURN path, weight;

// ******************************************************************************************
// Graph Data Science (GDS)
//
// Project a graph named 'OperationalPoints' Graph into memory. 
// We only take the "OperationalPoint " Node and the "SECTION" relationship, creating
// a monopartite Graph in the Graph Catalog
// ******************************************************************************************

CALL gds.graph.list() YIELD graphName AS toDrop
CALL gds.graph.drop(toDrop) YIELD graphName
RETURN "Dropped " + graphName;
 
CALL gds.graph.project(
    'OperationalPoints',
    'OperationalPoint',
    {SECTION: {orientation: 'UNDIRECTED'}},
    {
        relationshipProperties: 'sectionlength'
  }
);

// Now we calculate the shortest path using GDS Dijkstra:
MATCH (source:OperationalPoint WHERE source.id = 'BEFBMZ'), (target:OperationalPoint WHERE target.id = 'DE000BL')
CALL gds.shortestPath.dijkstra.stream('OperationalPoints', {
    sourceNode: source,
    targetNode: target,
    relationshipWeightProperty: 'sectionlength'
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs, path
RETURN *;

// Now we use the Weakly Connected Components Algo
CALL gds.wcc.stream('OperationalPoints') YIELD nodeId, componentId
WITH collect(gds.util.asNode(nodeId).id) AS lista, componentId
RETURN lista,componentId order by size(lista) ASC;

// Matching a specific OperationalPoint  from the list above --> use the Neo4j browser output to check the network it is belonging to (see the README file for more information). You will figure out, that it is an isolated network of OperationalPoint s / stations / etc.:
MATCH (op:OperationalPoint) WHERE op.id='BEFBMZ' RETURN op;

// Use the betweenness centrality algo
CALL gds.betweenness.stream('OperationalPoints')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).id AS id, score
ORDER BY score DESC;