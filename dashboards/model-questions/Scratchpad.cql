// Cypher shortest path
MATCH
  (v:OperationalPoint {name:'VALLECAS A.V.'},
  (r:OperationalPoint {name:'RICLA-A.V.'})
WITH v,r
MATCH path = (v)(
  (a)--(b)
   WHERE point.distance(b.geolocation, v.geolocation) < 300000
  )*(r)
RETURN path
LIMIT 1


MATCH 
    (:Person)-[:SENDS]->(:Email)-[:TO|CC|BCC]->(recipient:Person)
RETURN 
    recipient