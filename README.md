<h2 align="center">
  <img width="200" src="https://upload.wikimedia.org/wikipedia/commons/d/d9/Usach_P1.png" alt="logo Usach">
<p>Universidad de Santiago de Chile
<p>Facultad de Ingeniería
<p>Departamento de Ingeniería Geoespacial
<p> Alumna: Noemi Concha Carrillo

</h2>
<h1>

# DAG_DyDAT_2s_2024_NCC_PEP2
## Aplicación de Modelo Huff , para Panaderias en Comuna de La Florida.

## Descripción 📋
Este proyecto utiliza datos espaciales para analizar las proximidades entre los predios en la Comuna de la Florida y las panaderías, así como para calcular una probabilidad de preferencia comercial basada en la distancia y otros factores. Se realiza un análisis espacial para identificar qué cuales son los principales predios, donde resulta conveniente la instalación de una Panaderia basado en su competencia.
El calculó de este incluye geoprocesos , además de la normativa aplicada a la Zonificación de la Comuna.


## Requisitos 🛠️

[Para la utilización del Codigo es necesario constar con las siguientes librerias](Requerimientos.txt) 

Además de Agregar la siguiente linea de codigo en PgAdmin "create extension postgis", antes de ejecutar el Script Python 



## Credenciales 🔑

Antes de Ejecutar el Script es necesario modificar las credenciales asociadas al codigo, estas deben ser modificadas en relación a:
 1. Base de datos en PgAdmin, el cual en el codigo lleva el nombre de dbname, tal como se muestra, el cual tiene asignado "pep", debe ser modificado con el nombre que le de el usuario a su base de datos en PGadmin cuando lo utilice.
 2. Mismo Proceso se repite para el user y password, el usuario debe poner sus credenciales tal como se muestra en el codigo.
 3. Es necesario que de igual manera modifique la funcion motor = create_engine( "postgresql+psycopg2://postgres:postgres@localhost/pep"), con las credenciales.
        

## 1. Configuración de Conexión a la Base de Datos


```python
def conectar_bd():
    try:
        conexion = psycopg2.connect(
            dbname="pep",
            user="postgres", 
            password="postgres"
        )
        print("Conexión a la base de datos exitosa")
        return conexion
    except Exception as e:
        print(f"Error al conectar a la base de datos: {e}")
        exit()


# Crear el motor de SQLAlchemy para cargar datos
def crear_motor_sqlalchemy():
    try:
        motor = create_engine(
            "postgresql+psycopg2://postgres:postgres@localhost/pep"
        )
        return motor
    except Exception as e:
        print(f"Error al crear el motor de conexión SQLAlchemy: {e}")
        exit()
```

## Capas que utiliza el Script 🗺️

La carpeta donde se encuentran los archivo cuenta con un total de 4 SHP:
1. PRC de la Comuna (Type: Polygon)
2. Predios Comunales (Type: Polygon)
3. Panaderias (Type: Point)
4. Manzanas Censales (Type: Polygon)

Los cuales son necesarios para, la utilización del Script, estos son llamados mediante la función

```python

def poblar_datos_desde_shp(conexion, motor, archivo_shp, esquema, tabla):
    try:
        # Habilitar PostGIS
        habilitar_postgis(conexion)
        
        # Leer el shapefile usando geopandas
        gdf = gpd.read_file(archivo_shp, encoding='latin1')
        
        # Limpiar columnas y valores con caracteres problemáticos
        gdf.columns = gdf.columns.str.encode('latin1', 'ignore').str.decode('utf-8')
        for col in gdf.select_dtypes(include=['object']).columns:
            gdf[col] = gdf[col].str.encode('latin1', 'ignore').str.decode('utf-8')
        
        # Verificar el sistema de coordenadas
        if gdf.crs is None or gdf.crs.to_epsg() != 4326:
            print("Reproyectando datos a EPSG:4326")
            gdf = gdf.to_crs(epsg=4326)
        
        # Crear la tabla en la base de datos con SQLAlchemy
        nombre_tabla = f"{esquema}.{tabla}"
        print(f"Poblando datos en la tabla {nombre_tabla}...")
        gdf.to_postgis(name=tabla, con=motor, schema=esquema, if_exists='replace')
        print(f"Datos poblaron correctamente en la tabla {nombre_tabla}")
    except Exception as e:
        print(f"Error al poblar datos desde shapefile: {e}")

```
Y se encuentran al final del codigo en el menu, el cual permite llamar todas la funciones anteriores.

## Aplicación del SQL

1. Al comenzar la aplicación del Script, este genera una nueva tabla la cual genera solo las zonas del PRC donde se pueden instalar comercio.
   
2. Luego genera una identificación unica a las panaderias, predios y manzanas, esto con el fin de luego generar join entre ellas.
   
3. Asignación de Personas a predios, se genera una formula para la asignación con el fin de dividir la población equitativamente en relación a la cantidad de predios que caen en cada manzana, este valor es aproximado.

4. Calculó de distancias entre panaderias y predios, y asignación de id a la capa de predios, con el fin de poder traer la información que presenta la capa de Panaderias

5. Aplicación de Modelo huff
   La aplicación del Modelo Huff fue modificada con el fin, de utilizar  la puntación que presenta cada panaderia, la población aledaña y la distancia al cuadrado.

   El cálculo de la probabilidad para cada predio se realiza mediante la siguiente fórmula:
   ![image](https://github.com/user-attachments/assets/e9abc94f-ddf8-47ab-bf5d-47780d060e76)
6. Se genera una nueva tabla solo con los resultados obtenidos, la cual se almacena en el Esquema Salidas
7. Finalmente se aplica un intersect con las Zonas del PRC que, donde solo se puede instalar comercio y queda la columna modelohuff, el cual contiene las probabilidades, esta de igual manera esta en el esquema salida con el nombre de predios_con_comercio

## Importante
[Debido al peso que presenta el archivo, la carpeta con todos los datos quedó en el siguiente Link] (https://drive.google.com/drive/folders/1nB9rbREdR0mGPzWgQU63G_vsf6LZW0I5?usp=drive_link=






