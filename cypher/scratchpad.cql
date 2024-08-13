//Compare sectionlength vs. traveltime

MATCH 
    (stockholm:OperationalPoint {name:'Stockholms central'}),
    (malmo:OperationalPoint {name:'Malmö central'})
WITH stockholm, malmo

//sectionLength
CALL apoc.algo.dijkstra(stockholm, malmo, 'SECTION', 'sectionlength') YIELD path, weight
WITH 
    stockholm, malmo, 
    length(path) AS sectionLength_PathCount,
    weight AS sectionLength_Km, 
    reduce(time = 0, p IN relationships(path) | time + p.traveltime) AS sectionLength_Time

//traveltime
CALL apoc.algo.dijkstra(stockholm, malmo, 'SECTION', 'traveltime') YIELD path, weight
RETURN 
    sectionLength_PathCount, length(path) AS travelTime_PathCount,
    sectionLength_Km, reduce(distance = 0, p IN relationships(path) | distance + p.sectionlength) AS travelTime_Km,
    sectionLength_Time, weight AS travelTime_Time
       
       







//This is giving off results - traveltime is longer, and takes more time :/

//So this works...
//Which implies there's something else awry
CREATE (stockholm:OperationalPoint {name:'Stockholms central'})
CREATE (malmo:OperationalPoint {name:'Malmö central'})
CREATE (o1: OperationalPoint {name: 'Distance'})
CREATE (o2: OperationalPoint {name: 'Time'})

CREATE (stockholm)-[:SECTION {traveltime: 100, sectionlength: 1}]->(o1)-[:SECTION {traveltime: 200, sectionlength: 2}]->(malmo)
CREATE (stockholm)-[:SECTION {traveltime: 5, sectionlength:1000 }]->(o2)-[:SECTION {traveltime: 10, sectionlength: 2000}]->(malmo)