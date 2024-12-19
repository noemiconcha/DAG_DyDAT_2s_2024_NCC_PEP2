
------SOLO ZONAS PERMITIDAS-----------
-- Crea una nueva tabla que almacena las filas filtradas de la tabla entradas.prc
CREATE TABLE entradas.prc_filtradas AS
SELECT *
FROM entradas."prc"
WHERE "Comercio" = 1;





----IDENTIFICADOR PANADERIAS------

ALTER TABLE entradas."panaderias"
ADD COLUMN panaderia_id SERIAL PRIMARY KEY;

-- Agregar un identificador único a la capa de predios
ALTER TABLE entradas.predios_lf ADD COLUMN id SERIAL PRIMARY KEY;

-- Agregar un identificador único a la capa de manzanas
ALTER TABLE entradas.manzanas ADD COLUMN id SERIAL PRIMARY KEY;

ALTER TABLE entradas.predios_lf
ADD COLUMN manzana_id INT;
ALTER TABLE entradas.predios_lf
ADD COLUMN TOTAL_PERS FLOAT;
ALTER TABLE entradas.predios_lf
ADD COLUMN cantidad_personas FLOAT;




------------CANTIDAD DE PERSONAS ASIGNADAS A LOS PREDIOS-------------------------------
CREATE TABLE entradas."predios_manzanas" AS 
SELECT 
    predios.id AS predio_id,
    manzanas.id AS manzana_id,
    manzanas."TOTAL_PERS",
    (manzanas."TOTAL_PERS" / cantidad_predios) AS cantidad_personas
FROM 
    entradas.predios_lf AS predios
JOIN 
    entradas.manzanas AS manzanas
ON 
    ST_Intersects(predios.geometry, manzanas.geometry)
JOIN (
    SELECT 
        manzanas.id AS manzana_id,
        COUNT(predios.id) AS cantidad_predios
    FROM 
        entradas.predios_lf AS predios
    JOIN 
        entradas.manzanas AS manzanas
    ON 
        ST_Intersects(predios.geometry, manzanas.geometry)
    GROUP BY 
        manzanas.id
) AS predios_en_manzana
ON 
    manzanas.id = predios_en_manzana.manzana_id;


-- Realizar el JOIN y actualizar las columnas en predios_lf
UPDATE entradas.predios_lf
SET 
    manzana_id = predios_manzanas.manzana_id,
    TOTAL_PERS = predios_manzanas."TOTAL_PERS",
    cantidad_personas = predios_manzanas.cantidad_personas
FROM 
    entradas.predios_manzanas
WHERE 
    entradas.predios_lf.id = predios_manzanas.predio_id;

----CALCULO DE DISTANCIAS---------
ALTER TABLE entradas."predios_lf"
ADD COLUMN distancia_to_panaderia FLOAT;

UPDATE 
    entradas."predios_lf" AS predios
SET 
    distancia_to_panaderia = ST_Distance(
        ST_Transform(ST_Centroid(predios.geometry), 4326)::geography,
        ST_Transform(panaderias.geometry, 4326)::geography
    )
FROM 
    entradas."panaderias" AS panaderias ;

-- Agregar una nueva columna para almacenar el ID de la panadería más cercana---
ALTER TABLE entradas."predios_lf"
ADD COLUMN id_panaderia INT;

UPDATE 
    entradas."predios_lf" AS predio
SET 
    id_panaderia = (
        SELECT panaderia_id
        FROM (
            SELECT panaderia_id, ST_Distance(
                ST_Transform(ST_Centroid(predio.geometry), 4326)::geography,
                ST_Transform(panaderia.geometry, 4326)::geography
            ) AS distancia
            FROM entradas."panaderias" AS panaderia
        ) AS subquery
        WHERE subquery.distancia <= 1000 -- Ajustar según la distancia máxima deseada
        ORDER BY subquery.distancia
        LIMIT 1
    );



-- Agregar la columna en la tabla predios_lf
ALTER TABLE entradas.predios_lf
ADD COLUMN probabilidadhuff FLOAT;



---------- Modelo Huff-----------------
UPDATE entradas.predios_lf AS predios
SET probabilidadhuff = (
    -- Numerador: Puntación * total_pers / distancia^b
    (panaderia."Puntacion" * predios."total_pers") / POWER(predios.distancia_to_panaderia, 2)
    /
    -- Denominador: Suma global de la fórmula para todas las panaderías
    (
        SELECT SUM(p."Puntacion" * pr."total_pers" / POWER(pr.distancia_to_panaderia, 2))
        FROM entradas.predios_lf AS pr
        JOIN entradas.panaderias AS p
        ON pr.id_panaderia = p.panaderia_id
        WHERE pr.distancia_to_panaderia > 0  -- Evitar distancias nulas o cero
    )
)
FROM entradas.panaderias AS panaderia
WHERE predios.id_panaderia = panaderia.panaderia_id
  AND predios.distancia_to_panaderia > 0; -- Ignorar valores nulos o cero en distancia


-- Ordenar por probabilidad Huff -------
SELECT * FROM entradas.predios_lf
WHERE probabilidadhuff IS NOT NULL
ORDER BY probabilidadhuff DESC
LIMIT 25;


-- Crear una nueva tabla en el esquema 'salidas' con los datos calculados
CREATE TABLE salidas.predios_lf AS
SELECT 
    predios.id AS predio_id,
    predios.manzana_id,
    predios.id_panaderia,
    predios.total_pers,
    predios.cantidad_personas,
    predios.distancia_to_panaderia,
    predios.probabilidadhuff,
    predios.geometry  -- Mantener la geometría 
FROM 
    entradas.predios_lf AS predios
WHERE 
    probabilidadhuff IS NOT NULL -- Solo incluir predios con probabilidad válida
ORDER BY 
    probabilidadhuff DESC -- Ordenar por probabilidad descendente
LIMIT 25;

-------------------------------------------------------
-- Crear una tabla con los predios que intersectan los PRC filtrados

CREATE TABLE salidas.predios_con_comercio AS
SELECT 
    predios.*
FROM 
    entradas.predios_lf AS predios
JOIN 
    entradas.prc_filtradas AS prc
ON 
    ST_Intersects(predios.geometry, prc.geometry);

