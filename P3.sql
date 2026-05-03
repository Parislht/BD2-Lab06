--2. Busquedas por Rango
SELECT "NOMBDIST", "NOMBPROV", geometry 
FROM distritos
WHERE geometry && ST_MakeEnvelope(-77.15, -12.15, -76.85, -11.85, 4326)
UNION ALL
SELECT 'ÁREA DE CONSULTA' AS "NOMBDIST", 'RECTÁNGULO' AS "NOMBPROV", ST_MakeEnvelope(-77.15, -12.15, -76.85, -11.85, 4326) AS geometry;


--3. Crear indice espacial GiST en la tabla centros_poblados
CREATE INDEX IF NOT EXISTS idx_ccpp_geometry_gist ON centros_poblados USING gist(geometry);

--3.1. Obtener los 5 centros poblados mas cercanos a Lima con distancia en metros
SELECT "NOM_POBLAD" AS nombre_ccpp, "PROV" AS provincia, 
       ROUND(ST_Distance(geometry, ST_SetSRID(ST_MakePoint(-77.0282, -12.0432), 4326)::geography)::numeric, 2) AS distancia_metros,
       geometry
FROM centros_poblados
ORDER BY geometry <-> ST_SetSRID(ST_MakePoint(-77.0282, -12.0432), 4326)::geography
LIMIT 5;

--4. Densidad de Centros Poblados por Distrito
SELECT 
    d."NOMBDIST" AS distrito,
    d."NOMBPROV" AS provincia,
    d."NOMBDEP" AS departamento,
    COUNT(cp."NOM_POBLAD") AS total_centros_poblados,
    ROUND((ST_Area(d.geometry::geography) / 1000000.0)::numeric, 2) AS area_km2,
    ROUND((COUNT(cp."NOM_POBLAD") / (ST_Area(d.geometry::geography) / 1000000.0))::numeric, 4) AS densidad
FROM distritos d
LEFT JOIN centros_poblados cp ON ST_Within(cp.geometry, d.geometry)
GROUP BY d."NOMBDIST", d."NOMBPROV", d."NOMBDEP", d.geometry
ORDER BY densidad DESC;









