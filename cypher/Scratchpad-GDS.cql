CALL gds.graph.list() yield graphName
UNWIND graphName AS name
CALL gds.graph.drop(name) YIELD graphName AS dropped
RETURN dropped;

CALL gds.graph.project(
    "opPointsSectionLength",
    "OperationalPoint",
    {
        SECTION: {properties: "sectionlength"}
    }
)
YIELD
 graphName AS graph, nodeProjection, nodeCount AS nodes, relationshipProjection, relationshipCount AS rels;



 CALL gds.graph.project(
    "opPointsTravelTime",
    "OperationalPoint",
    {
        SECTION: {properties: {traveltime:{defaultValue:20000}}}
    }
)
YIELD
 graphName AS graph, nodeProjection, nodeCount AS nodes, relationshipProjection, relationshipCount AS rels;


MATCH 
    (stockholm:OperationalPoint {name:'Stockholms central'}),
    (malmo:OperationalPoint {name:'Malmö central'})
WITH stockholm, malmo
CALL gds.shortestPath.dijkstra.stream('opPointsSectionLength',
{
    sourceNode: stockholm,
    targetNode: malmo,
    relationshipWeightProperty: 'sectionlength'
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs, path
RETURN
    index,
    gds.util.asNode(sourceNode).name AS sourceNodeName,
    gds.util.asNode(targetNode).name AS targetNodeName,
    totalCost,
    [nodeId IN nodeIds | gds.util.asNode(nodeId).name] AS nodeNames,
    costs,
    nodes(path) as path
ORDER BY index;

MATCH 
    (stockholm:OperationalPoint {name:'Stockholms central'}),
    (malmo:OperationalPoint {name:'Malmö central'})
WITH stockholm, malmo
CALL gds.shortestPath.dijkstra.stream('opPointsTravelTime',
{
    sourceNode: stockholm,
    targetNode: malmo,
    relationshipWeightProperty: 'traveltime'
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs, path
RETURN
    index,
    gds.util.asNode(sourceNode).name AS sourceNodeName,
    gds.util.asNode(targetNode).name AS targetNodeName,
    totalCost,
    [nodeId IN nodeIds | gds.util.asNode(nodeId).name] AS nodeNames,
    costs,
    nodes(path) as path
ORDER BY index;





MATCH 
    (stockholm:OperationalPoint {name:'Stockholms central'}),
    (malmo:OperationalPoint {name:'Malmö central'})
WITH stockholm, malmo
CALL gds.shortestPath.dijkstra.stream('opPointsTravelTime',
{
    sourceNode: stockholm,
    targetNode: malmo,
    relationshipWeightProperty: 'traveltime'
})
YIELD path AS travelTimePath
WITH travelTimePath, stockholm, malmo
CALL gds.shortestPath.dijkstra.stream('opPointsSectionLength',
{
    sourceNode: stockholm,
    targetNode: malmo,
    relationshipWeightProperty: 'sectionlength'
})
YIELD path AS sectionLengthPath
 RETURN travelTimePath, sectionLengthPath