import os
import geopandas as gpd
from sqlalchemy import create_engine

# 1. CONFIGURACION DE RUTAS

#CREDENCIALES
DB_USER = "postgres"
DB_PASSWORD = "postgres"
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "ciudades"  

#RUTAS
RUTA_SHP = r"C:\Users\Paris Herrera\Desktop\utec\2026 - 1\BD2\Semana6\geodata\geodata\peru_centros_poblados\CCPP_IGN100K.shp"
RUTA_GEOJSON = r"C:\Users\Paris Herrera\Desktop\utec\2026 - 1\BD2\Semana6\geodata\geodata\peru_distritos\peru_distrital_simple.geojson"

# Crear motor de conexión mediante SQLAlchemy
engine = create_engine(f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}")

# 2. CARGA DEL SHAPEFILE (CENTROS POBLADOS DEL PERÚ)

if os.path.exists(RUTA_SHP):
    gdf_ccpp = gpd.read_file(RUTA_SHP)
    
    if gdf_ccpp.crs is None or gdf_ccpp.crs.to_epsg() != 4326:
        gdf_ccpp = gdf_ccpp.to_crs(epsg=4326)

    
    gdf_ccpp.to_postgis(
        name="centros_poblados", 
        con=engine, 
        if_exists="replace", 
        index=False
    )
else:
    print(f"Error: No se encontro Shapefile en: {RUTA_SHP}")




# 3. CARGA DEL GEOJSON (DISTRITOS DEL PERÚ)
if os.path.exists(RUTA_GEOJSON):
    gdf_distritos = gpd.read_file(RUTA_GEOJSON)
    
    if gdf_distritos.crs is None or gdf_distritos.crs.to_epsg() != 4326:
        gdf_distritos = gdf_distritos.to_crs(epsg=4326)

    
    gdf_distritos.to_postgis(
        name="distritos", 
        con=engine, 
        if_exists="replace", 
        index=False
    )
else:
    print(f"Error: No se encontro GeoJSON en: {RUTA_GEOJSON}")

