# Graph Data Science (GDS)

This file gives some advice on how to use GDS with the dataset.

> **NB** to use GDS you will need to be either using Sandbox OR Desktop environments, Aura Free will not allow access.

We will be projecting a graph into the GDS [Graph Catalog](https://neo4j.com/docs/graph-data-science/current/management-ops/graph-catalog-ops/) using [Native Projection](https://neo4j.com/docs/graph-data-science/current/management-ops/projections/graph-project/) 

If you want to ensure you have no existing projections you can run the following Cypher to clear your Graph Catalog:

```cypher
CALL gds.graph.list() YIELD graphName AS toDrop
CALL gds.graph.drop(toDrop) YIELD graphName
RETURN "Dropped " + graphName;
```

We will project a graph named 'OperationalPoints' into the Graph Catalog. We will take the `OperationalPoint` Nodes and the `SECTION` Relationships to form a monopartite graph:

```cypher
CALL gds.graph.project(
    'OperationalPoints',
    'OperationalPoint',
    {SECTION: {orientation: 'UNDIRECTED'}},
    {
        relationshipProperties: ['sectionlength', 'traveltime']
    }
);
```

### Path Finding

We can calculate the shortest path between two stations - for example, Malmö Central to Stockholm Central - using our `traveltime` relatonship weights and the [Dijkstra Source-Target Shortest Path](https://neo4j.com/docs/graph-data-science/current/algorithms/dijkstra-source-target/) algorithm from the GDS library.  Note that bad data in our dataset (such as `null` or `zero` relationship weights) can cause strange results when calculating weighted shortest paths.

```cypher
MATCH     
    (:OperationalPointName {name:'Stockholms central'})<-[:NAMED]-(stockholm:OperationalPoint),
    (:OperationalPointName {name:'Malmö central'})<-[:NAMED]-(malmo:OperationalPoint)
CALL gds.shortestPath.dijkstra.stream('OperationalPoints', {
    sourceNode: malmo,
    targetNode: stockholm,
    relationshipWeightProperty: 'traveltime'
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs, path
RETURN *;
```

Do we get the same result if we use the `sectionlength` relationship property as our weight instead of `traveltime` when computing the shortest path?

```cypher
MATCH     
    (:OperationalPointName {name:'Stockholms central'})<-[:NAMED]-(stockholm:OperationalPoint),
    (:OperationalPointName {name:'Malmö central'})<-[:NAMED]-(malmo:OperationalPoint)
CALL gds.shortestPath.dijkstra.stream('OperationalPoints', {
    sourceNode: malmo,
    targetNode: stockholm,
    relationshipWeightProperty: 'sectionlength'
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs, path
RETURN *;
```

### Community Detection

Now we use the [Weakly Connected Components](https://neo4j.com/docs/graph-data-science/current/algorithms/wcc/) algorithm in 'stream' mode to review `OperationalPoint`s that are _not_ well connected to the network:

```cypher
CALL gds.wcc.stream('OperationalPoints') YIELD nodeId, componentId
WITH collect(gds.util.asNode(nodeId).id) AS nodes, componentId
RETURN nodes, componentId 
ORDER BY size(nodes) ASC LIMIT 50;
```

We can also write the Weakly Connected Components `componentId` properties to the database so we can query and visualise them later:

```cypher
CALL gds.wcc.write('OperationalPoints', {writeProperty: 'componentId'});
```

We should index our new Weakly Connected Components `componentId` property, so that we can query with it in a performant way:

```cypher
CREATE INDEX index_OperationalPoint_componentid IF NOT EXISTS FOR (opn:OperationalPoint) ON (opn.componentId);
```

Let's find a specific `OperationalPoint` and view the other members of its community. You should see that it belongs to an isolated group of `OperationalPoint`s.

```cypher
MATCH (op:OperationalPoint {id: 'UKN4288'})
WITH op.componentId as component
MATCH path = (:OperationalPoint {componentId: component})-[:SECTION]->()
RETURN path
```

### Centrality

Using the [Degree Centrality](https://neo4j.com/docs/graph-data-science/current/algorithms/degree-centrality/) algorithm we can identify important nodes in the graph based on how many `SECTION` relationships they have.
Nodes with a high Degree Centrality score represent `OperationalPoint`s which are important transfer points in our network.

```cypher
CALL gds.degree.stream('OperationalPoints')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).id AS id, score
ORDER BY score DESC LIMIT 50;
```

We should write the Degree Centrality `degreeScore` properties to the database so we can query and visualise them later:

```cypher
CALL gds.degree.write('OperationalPoints', {writeProperty: 'degreeScore'})
```

Using the [Betweenness Centrality](https://neo4j.com/docs/graph-data-science/current/algorithms/betweenness-centrality/) algorithm we can identify important nodes in the graph by another metric - those nodes which sit on the shortest path between the most other nodes.

These nodes represent `OperationalPoint`s which many journeys are likely to pass through, and may act as 'bridge' nodes between different parts of the network.

```cypher
CALL gds.betweenness.stream('OperationalPoints')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).id AS id, score
ORDER BY score DESC LIMIT 50;
```

We should also write the Betweenness Centrality scores back to the database so we can query and visualise them later:

```cypher
CALL gds.betweenness.write('OperationalPoints', {writeProperty: 'betweennessScore'})
```

Let's also index our new Degree Centrality `degreeScore`and Betweenness Centrality `betweennessScore` properties, so that we can query using them in a performant way:

```cypher
CREATE INDEX index_OperationalPoint_degreeScore IF NOT EXISTS FOR (opn:OperationalPoint) ON (opn.degreeScore);
CREATE INDEX index_OperationalPoint_betweennessScore IF NOT EXISTS FOR (opn:OperationalPoint) ON (opn.betweennessScore);
```

### Tidy Up

Finally, it's best practice to remove your graph projections from memory when you're finished with them:

```cypher
CALL gds.graph.drop('OperationalPoints')
```