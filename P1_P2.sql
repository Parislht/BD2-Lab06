--1.
CREATE EXTENSION postgis;

--2.
CREATE TABLE cities (
 id int PRIMARY KEY,
 name varchar(100),
 state_id INT,
 state_code varchar(10),
 state_name varchar(100),
 country_id INT,
 country_code varchar(10),
 country_name varchar(100),
 latitude DOUBLE PRECISION,
 longitude DOUBLE PRECISION,
 wikiDataId varchar(15)
);


--4.
ALTER TABLE cities ADD COLUMN ubicacion GEOGRAPHY(Point, 4326);
UPDATE cities SET ubicacion = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);


--5.
CREATE INDEX idx_cities_geom_gist ON cities USING GIST (ubicacion);

--6.
SELECT name, country_name,
 ST_Distance(c.ubicacion, qp.ubicacion) AS distance
FROM cities c,
 (SELECT ST_SetSRID(ST_MakePoint(-78.91667, -8.08333), 4326) AS ubicacion) qp
WHERE ST_DWithin(
 c.ubicacion,
 qp.ubicacion,
 10000 -- radio en metros
);


--7.
SELECT c.name, c.country_name,
 ST_Distance(c.ubicacion, qp.ubicacion) AS distance_meters
FROM cities c,
 (SELECT ST_SetSRID(ST_MakePoint(-78.91667, -8.08333)::geography, 4326) AS ubicacion)
qp
ORDER BY c.ubicacion <-> qp.ubicacion
LIMIT 5;

--8.
ALTER TABLE cities ADD COLUMN ubicacion2 GEOGRAPHY(Point, 4326);
UPDATE cities SET ubicacion2 = ubicacion;

-- 8.1 Busqueda por rango usando la columna con indice
EXPLAIN ANALYZE
SELECT name, country_name
FROM cities
WHERE ST_DWithin(ubicacion, ST_SetSRID(ST_MakePoint(-78.91667, -8.08333), 4326), 10000);

-- 8.2 Busqueda por rango usando la columna con indice
EXPLAIN ANALYZE
SELECT name, country_name
FROM cities
WHERE ST_DWithin(ubicacion2, ST_SetSRID(ST_MakePoint(-78.91667, -8.08333), 4326), 10000);


--8.3 Consultas de Vecinos Más Cercano con indice
EXPLAIN ANALYZE
SELECT name, country_name
FROM cities
ORDER BY ubicacion <-> ST_SetSRID(ST_MakePoint(-78.91667, -8.08333), 4326)::geography
LIMIT 5;

--8.4 Consultas de Vecinos Más Cercano con indice
EXPLAIN ANALYZE
SELECT name, country_name
FROM cities
ORDER BY ubicacion2 <-> ST_SetSRID(ST_MakePoint(-78.91667, -8.08333), 4326)::geography
LIMIT 5;



-- PARTE 2

-- 1. Consulta por Rango: Ciudades dentro del rectangulo delimitado
SELECT name, country_name
FROM cities
WHERE ST_Intersects(
    ubicacion, 
    ST_MakeEnvelope(-79.4742, -8.6159, -78.4742, -7.6159, 4326)::geography
);

-- 2. Top 10 ciudades mas cercanas a Lima con distancia en kilometros
SELECT name, country_name, 
       ROUND((ST_Distance(ubicacion, 
	   ST_SetSRID(ST_MakePoint(-77.0282, -12.0432), 4326)::geography) 
	   / 1000)::numeric, 2) 
	   AS distance_km
FROM cities
ORDER BY ubicacion <-> ST_SetSRID(ST_MakePoint(-77.0282, -12.0432), 4326)::geography
LIMIT 10;


--3.1 Crear indice Btree en la columna de nombre de ciudad para una busqueda mas eficiente
CREATE INDEX idx_cities_name_btree ON cities(name);

--3.2. Creacion de la funcion para buscar las N ciudades mas cercanas
CREATE OR REPLACE FUNCTION obtener_ciudades_cercanas(nombre_ciudad_origen VARCHAR, n INT)
RETURNS TABLE(
    ciudad_cercana VARCHAR, 
    pais_cercano VARCHAR, 
    distancia_km NUMERIC
) AS $$
DECLARE
    punto_referencia GEOGRAPHY;
BEGIN
    SELECT ubicacion INTO punto_referencia
    FROM cities
    WHERE name = nombre_ciudad_origen;

    RETURN QUERY
    SELECT c.name, c.country_name, 
           ROUND((ST_Distance(c.ubicacion, punto_referencia) / 1000.0)::numeric, 2)
    FROM cities c
    WHERE c.name <> nombre_ciudad_origen -- para descartar a la misma ciudad
    ORDER BY c.ubicacion <-> punto_referencia
    LIMIT n;
END;
$$ LANGUAGE plpgsql;

--3.3 Ejecuciones
SELECT * FROM obtener_ciudades_cercanas('Trujillo', 5);

SELECT * FROM obtener_ciudades_cercanas('Madrid', 10);



--4. Análisis de Rendimiento 

-- 4.1. Consulta KNN indexada (20k registros)
EXPLAIN ANALYZE
SELECT name, country_name
FROM (SELECT * FROM cities WHERE id <= 20000) AS muestra
ORDER BY ubicacion <-> ST_SetSRID(ST_MakePoint(-77.0282, -12.0432), 4326)::geography
LIMIT 10;
-- 4.2. Consulta KNN NO indexada (20k registros)
EXPLAIN ANALYZE
SELECT name, country_name
FROM (SELECT * FROM cities WHERE id <= 20000) AS muestra
ORDER BY ubicacion2 <-> ST_SetSRID(ST_MakePoint(-77.0282, -12.0432), 4326)::geography
LIMIT 10;



-- 4.3. Consulta KNN indexada (60k registros)
EXPLAIN ANALYZE
SELECT name, country_name
FROM (SELECT * FROM cities WHERE id <= 60000) AS muestra
ORDER BY ubicacion <-> ST_SetSRID(ST_MakePoint(-77.0282, -12.0432), 4326)::geography
LIMIT 10;
-- 4.4. Consulta KNN NO indexada (60k registros)
EXPLAIN ANALYZE
SELECT name, country_name
FROM (SELECT * FROM cities WHERE id <= 60000) AS muestra
ORDER BY ubicacion2 <-> ST_SetSRID(ST_MakePoint(-77.0282, -12.0432), 4326)::geography
LIMIT 10;


-- 4.5. Consulta KNN indexada (80k registros)
EXPLAIN ANALYZE
SELECT name, country_name
FROM (SELECT * FROM cities WHERE id <= 80000) AS muestra
ORDER BY ubicacion <-> ST_SetSRID(ST_MakePoint(-77.0282, -12.0432), 4326)::geography
LIMIT 10;
-- 4.6. Consulta KNN NO indexada (80k registros)
EXPLAIN ANALYZE
SELECT name, country_name
FROM (SELECT * FROM cities WHERE id <= 80000) AS muestra
ORDER BY ubicacion2 <-> ST_SetSRID(ST_MakePoint(-77.0282, -12.0432), 4326)::geography
LIMIT 10;




--5. Consulta para detectar ciudades aisladas a mas de 50 km de cualquier otra

SELECT c1.name, c1.country_name
FROM cities c1
CROSS JOIN LATERAL (
    SELECT c2.ubicacion
    FROM cities c2
    WHERE c1.id <> c2.id
    ORDER BY c1.ubicacion <-> c2.ubicacion
    LIMIT 1
) c2
WHERE NOT ST_DWithin(c1.ubicacion, c2.ubicacion, 50000);
