// 
// This file is to be executed in the Neo4j Browser
//


// WARNING! This will erase your database contents
MATCH (n)
DETACH DELETE n;

//WARNING! This will DROP all your indexes and constraints
CALL apoc.schema.assert({},{});

:param SectionPointDir => 'https://raw.githubusercontent.com/cskardon/gsummit2023/main/data/relationships';
:param filePOIs => 'https://raw.githubusercontent.com/cskardon/gsummit2023/main/data/POIs.csv';

CREATE CONSTRAINT uc_OperationPoint_id IF NOT EXISTS FOR (op:OperationPoint) REQUIRE (op.id) IS UNIQUE;

//
// Loading Operations Points from all available countries
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/cskardon/gsummit2023/main/data/nodes/OperationPoint_All.csv" AS row
WITH 
    trim(row.id) AS id,
    toFloat(row.latitude) AS latitude,
    toFloat(row.longitude) AS longitude,
    row.name AS name,
    [] + row.country + row.extralabel AS labels,
    row.country AS country
MERGE (op:OperationPoint {id: id})
ON CREATE SET
    op.geolocation = Point({latitude: latitude, longitude: longitude}),
    op.name = name
ON MATCH SET
    op.name = op.name + "/(" + country +") " + name
WITH op, labels
CALL apoc.create.addLabels( op, labels ) YIELD node
RETURN distinct "Complete"

//
// Chaining up sections
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/cskardon/gsummit2023/main/data/relationships/SECTION_ALL_Length.csv" AS row
WITH
    trim(row.source) AS source,
    trim(row.target) AS target,
    toFloat(row.sectionlength) AS length
MATCH (source:OperationPoint WHERE source.id = source)
MATCH (target:OperationPoint WHERE target.id = target)
MERGE (source)-[:SECTION {sectionlength: sectionlength}]->(target);

//
// Load Speed Data
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/cskardon/gsummit2023/main/data/relationships/SECTION_ALL_speed.csv" AS row
WITH
    trim(row.source) AS source,
    trim(row.target) AS target,
    toFloat(row.sectionspeed) AS speed
MATCH (:OperationPoint WHERE source.id = source)-[s:SECTION]->(:OperationPoint WHERE target.id = target)
SET s.speed = speed;


// Create one more index for the Operation Point name
CREATE INDEX index_OperationPointName_name IF NOT EXISTS FOR (opn:OperationPointName) ON (opn.name);

//
// Loading Point of Interest and matching the closest station automtically
// by finding the closest distance between geo point of the POI and the next
// available station / passenger stop geo point
//

LOAD CSV WITH HEADERS FROM $filePOIs AS line FIELDTERMINATOR ';'
WITH line.CITY AS city, line.POI_DESCRIPTION AS description, line.LINK_FOTO AS linkFoto, line.LINK_WEBSITE AS linkWeb, line.LAT AS lat, line.LONG AS long, line.SECRET AS secret
CREATE (po:POI {geolocation:point({latitude: toFloat(lat),longitude: toFloat(long)})})
SET po.description = description,
po.city = city,
po.linkWebSite = linkWeb,
po.linkFoto = linkFoto,
po.long = toFloat(long),
po.lat = toFloat(lat),
po.secret = toBoolean(secret);

MATCH (poi:POI)
MATCH (op:OperationPoint) 
WHERE "Station" IN labels(op) or "SmallStation" IN labels(op)
WITH poi, op, point.distance(poi.geolocation, op.geolocation) as distance
ORDER by distance
WITH poi, collect(op)[0] as closest
MERGE (closest)-[:IS_NEAR]->(poi);

// ==== DONE LOADING ====
