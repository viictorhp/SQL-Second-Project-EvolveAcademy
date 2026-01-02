USE proyecto_spotify;

-- TABLA DE STAGING. Contiene todos los datos en crudo (tal y como están en el archivo CSV).
SELECT * FROM staging_spotify;

-- TABLA DE HECHOS (fact_table). Resultado de cruzar todos los datos (lo que he hecho en los archivos anteriores).
	-- Datos únicos, limpios y validados conectados con las tablas de dimensiones.
SELECT * FROM fact_spotify_metrics;

-- TABLAS DE DIMENSIONES
SELECT * FROM dim_album;
SELECT * FROM dim_artist;
SELECT * FROM dim_explicit;
SELECT * FROM dim_genre;
SELECT * FROM dim_key;
SELECT * FROM dim_mode;
SELECT * FROM dim_time_signature;
SELECT * FROM dim_track_info;

-- Antes de empezar a realizar queries voy a finalizar con la creación de las tablas realizando algunas nuevas modificaciones.
-- 1. Creo una nueva tabla de dimensiones con la variable "popularity"
DROP TABLE IF EXISTS dim_popularity;
CREATE TABLE dim_popularity (
    popularity_id INT AUTO_INCREMENT PRIMARY KEY,
    score INT UNIQUE,
    category VARCHAR(20) 
);

-- 1.1 Agrego valores únicos en esta nueva tabla de dimensiones
	-- Insert ignore: Inserta todos los datos ignorando si ocurre algún error (como algún dato duplicado), simplemente ignora esta fila y continúa.
INSERT IGNORE INTO dim_popularity (score, category)
SELECT DISTINCT popularity,
    CASE 
        WHEN popularity >= 80 THEN 'Top Hit'
        WHEN popularity BETWEEN 50 AND 79 THEN 'Popular'
        WHEN popularity BETWEEN 20 AND 49 THEN 'Normal'
        ELSE 'Niche / Low'
    END
FROM staging_spotify
ORDER BY popularity;

-- 1.2 Modificamos la fact table para que se añada esta nueva Foreign Key
ALTER TABLE fact_spotify_metrics ADD COLUMN popularity_id INT;

-- 1.3 Actualizo la Fact Table cruzando los datos
UPDATE fact_spotify_metrics f
JOIN dim_popularity p ON f.popularity = p.score
SET f.popularity_id = p.popularity_id;

-- 1.4 Limpio la columna "popularity" de la fact_table
ALTER TABLE fact_spotify_metrics DROP COLUMN popularity;

-- 1.5 Relacionamos la Foreign Key oficial
ALTER TABLE fact_spotify_metrics 
ADD CONSTRAINT fk_popularity FOREIGN KEY (popularity_id) REFERENCES dim_popularity(popularity_id);

SELECT * FROM dim_popularity;

-- 2. Añado nuevas variables a la tabla "dim_track_info" y elimino la variable "is_explicit" porque ya tenemos esta variable en una tabla de dimensiones aparte.
ALTER TABLE dim_track_info DROP COLUMN is_explicit;

-- Voy a añadir las variables "duration_ms" - duración de la canción en milisegundos, "danceability" - Valor entre 0 y 1 que mide cómo de óptima es una cacnión para que se pueda bailar y "energy" - Valor entre 0 y 1 que mide la intensidad y actividad de una canción.
ALTER TABLE dim_track_info 
ADD COLUMN duration_ms INT,
ADD COLUMN danceability DOUBLE,
ADD COLUMN energy DOUBLE;

-- Añadimos los datos de estas variables
UPDATE dim_track_info t
JOIN staging_spotify s ON t.track_spotify_id = s.track_id
SET 
    t.duration_ms = s.duration_ms,
    t.danceability = s.danceability,
    t.energy = s.energy;

-- 3. Elimino la tabla de dimensiones "dim_time_signature", ya que, me parece poco relevante y no la voy a utilizar.
-- 3.1 Eliminar la relación (Foreign Key)
ALTER TABLE fact_spotify_metrics DROP FOREIGN KEY fk_timesig;

-- 3.2 Elimino la columna de la Fact Table
ALTER TABLE fact_spotify_metrics DROP COLUMN time_sig_id;

-- 3.3 Elimino la Tabla de Dimensiones
DROP TABLE IF EXISTS dim_time_signature;

-- Por último voy a asegurarme de no tener algunos valores atípicos
-- 1. Asegurar que la popularidad nunca sea negativa ni mayor a 100
ALTER TABLE dim_popularity
ADD CONSTRAINT chk_popularity_range CHECK (score BETWEEN 0 AND 100);
-- 2. Asegurar que la duración nunca sea negativa
ALTER TABLE dim_track_info
ADD CONSTRAINT chk_duration_positive CHECK (duration_ms >= 0);
-- 3. Asegurar que danceability es un ratio entre 0 y 1 (o un poco más según la escala, pero normalmente es 0-1)
ALTER TABLE dim_track_info
ADD CONSTRAINT chk_danceability_valid CHECK (danceability BETWEEN 0 AND 1);
-- 4. Asegurar que energy es un ratio entre 0 y 1
ALTER TABLE dim_track_info
ADD CONSTRAINT chk_energy_valid CHECK (energy BETWEEN 0 AND 1);

/* =====================================
   ANÁLISIS EDA
   ===================================== */

-- Canciones categorizadas según su éxito.
SELECT 
    dp.category AS nivel_exito,
    COUNT(*) AS total_canciones
FROM fact_spotify_metrics f
JOIN dim_popularity dp ON f.popularity_id = dp.popularity_id
GROUP BY dp.category;

-- Top hits ordenados por su score.
SELECT distinct
    dt.track_name,
    dp.score,
    dp.category
FROM fact_spotify_metrics f
JOIN dim_popularity dp ON f.popularity_id = dp.popularity_id
JOIN dim_track_info dt ON f.track_db_id = dt.track_db_id
WHERE dp.category = 'Top Hit'
ORDER BY dp.score DESC
LIMIT 10;

-- ¿Cuáles son los géneros más bailables y cuánto duran de media?
SELECT 
    g.genre_name,
    COUNT(f.track_db_id) as total_canciones,
    ROUND(AVG(t.danceability), 2) as bailabilidad_media,
    -- Convertimos milisegundos a minutos para que sea legible
    ROUND(AVG(t.duration_ms) / 60000, 2) as duracion_promedio_min
FROM fact_spotify_metrics f
JOIN dim_genre g ON f.genre_id = g.genre_id
JOIN dim_track_info t ON f.track_db_id = t.track_db_id
GROUP BY g.genre_name
ORDER BY bailabilidad_media DESC
LIMIT 10;

-- Canciones de artistas que sean "Super Estrellas" (artistas que tengan al menos una canción con popularidad > 90).
SELECT distinct
    a.artist_name,
    t.track_name,
    p.score as popularidad
FROM fact_spotify_metrics f
JOIN dim_artist a ON f.artist_id = a.artist_id
JOIN dim_track_info t ON f.track_db_id = t.track_db_id
JOIN dim_popularity p ON f.popularity_id = p.popularity_id
WHERE f.artist_id IN (
    -- Subconsulta: Obtener IDs de artistas con al menos un 'Top Hit' (>90)
    SELECT DISTINCT f2.artist_id 
    FROM fact_spotify_metrics f2
    JOIN dim_popularity p2 ON f2.popularity_id = p2.popularity_id
    WHERE p2.score > 90
)
ORDER BY p.score DESC
LIMIT 15;

-- Simulación de un reporte haciendo uso de los formatos de Fecha
SELECT 
    t.track_name,
    a.artist_name,
    -- Casteamos el tempo (double) a un entero sin decimales (CHAR)
    CAST(f.tempo AS UNSIGNED) as bpm_entero,
    -- Función de fecha: Agregamos la fecha y hora actual del reporte
    DATE_FORMAT(NOW(), '%d-%m-%Y %H:%i') as fecha_reporte,
    -- Calculamos minutos usando aritmética y CAST para decimales precisos
    CAST(t.duration_ms / 60000 AS DECIMAL(4,2)) as minutos_exactos
FROM fact_spotify_metrics f
JOIN dim_track_info t ON f.track_db_id = t.track_db_id
JOIN dim_artist a ON f.artist_id = a.artist_id
WHERE f.tempo > 150 -- Canciones rápidas
LIMIT 10;

-- Búsqueda de canciones para "Estudiar" (Baja energía, alta acústica y sin contenido explícito).
SELECT 
    t.track_name,
    a.artist_name,
    t.energy,
    f.acousticness
FROM fact_spotify_metrics f
JOIN dim_track_info t ON f.track_db_id = t.track_db_id
JOIN dim_artist a ON f.artist_id = a.artist_id
JOIN dim_explicit e ON f.explicit_id = e.explicit_id
WHERE 
    t.energy < 0.3                -- Poca energía
    AND f.acousticness > 0.8      -- Muy acústica
    AND e.explicit_val = 'False'  -- Sin contenido explícito
ORDER BY f.acousticness DESC
LIMIT 10;

-- ¿Las canciones con contenido explícito tienen mayor popularidad de media que las "limpias" (sin contenido explícito)?.
SELECT 
    de.explicit_val AS es_explicito,
    COUNT(f.track_db_id) AS cantidad_canciones,
    ROUND(AVG(dp.score), 2) AS popularidad_media
FROM fact_spotify_metrics f
JOIN dim_explicit de ON f.explicit_id = de.explicit_id
JOIN dim_popularity dp ON f.popularity_id = dp.popularity_id
JOIN dim_track_info dt ON f.track_db_id = dt.track_db_id
GROUP BY de.explicit_val;

-- ¿Cuál es la tonalidad (Key) más "triste"? - Buscamos qué nota musical se asocia con la positividad más baja.
SELECT 
    dk.key_name AS tonalidad,
    dm.mode_desc AS modalidad, -- Minor o Major
    ROUND(AVG(f.valence), 3) AS felicidad_promedio
FROM fact_spotify_metrics f
JOIN dim_key dk ON f.key_id = dk.key_id
JOIN dim_mode dm ON f.mode_id = dm.mode_id
GROUP BY dk.key_name, dm.mode_desc
ORDER BY felicidad_promedio ASC; -- Las más tristes primero

-- Top 10 Artistas más "versátiles" (con mayor variedad de géneros).
SELECT 
    da.artist_name,
    COUNT(DISTINCT f.genre_id) AS variedad_generos,
    COUNT(f.track_db_id) AS total_canciones_registradas
FROM fact_spotify_metrics f
JOIN dim_artist da ON f.artist_id = da.artist_id
GROUP BY da.artist_name
HAVING variedad_generos > 5 -- Que hayan tocado más de 5 géneros distintos
ORDER BY variedad_generos DESC, total_canciones_registradas DESC
LIMIT 10;

-- Canciones más enérgicas con respecto a la media.
SELECT 
    track_name,
    energy,
    -- Subconsulta
    (SELECT ROUND(AVG(energy), 3) FROM dim_track_info) as promedio_global
FROM dim_track_info 
WHERE energy > (SELECT AVG(energy) FROM dim_track_info)
ORDER BY energy DESC
LIMIT 10;

-- Géneros con popularidad media superior a 50.
SELECT * FROM (
    -- Subconsulta
    SELECT 
        dg.genre_name,
        ROUND(AVG(dp.score), 2) as popularidad_media
    FROM fact_spotify_metrics f
    JOIN dim_genre dg ON f.genre_id = dg.genre_id
    JOIN dim_popularity dp ON f.popularity_id = dp.popularity_id
    GROUP BY dg.genre_name
) AS tabla_resumen
WHERE popularidad_media > 50
ORDER BY popularidad_media DESC;

-- Top 3 canciones más populares de cada género musical.
SELECT * FROM (
	-- Subconsulta
    SELECT 
        dg.genre_name,
        dt.track_name,
        dp.score,
        -- Busca las tres mejores canciones (según el "score") ordenadas por género
        ROW_NUMBER() OVER(PARTITION BY dg.genre_name ORDER BY dp.score DESC) as ranking
    FROM fact_spotify_metrics f
    JOIN dim_genre dg ON f.genre_id = dg.genre_id
    JOIN dim_track_info dt ON f.track_db_id = dt.track_db_id
    JOIN dim_popularity dp ON f.popularity_id = dp.popularity_id
) AS ranking_table
WHERE ranking <= 3 -- Filtramos solo los 3 primeros de cada grupo
ORDER BY genre_name, ranking;

-- Comparamos la duración de cada canción con la duración media de ese mismo artista.
SELECT 
    da.artist_name,
    dt.track_name,
    dt.duration_ms,
    -- Calcula el promedio del artista en cada fila sin agrupar
    ROUND(AVG(dt.duration_ms) OVER(PARTITION BY da.artist_name)) as media_duracion_artista,
    -- Calculamos la diferencia
    dt.duration_ms - ROUND(AVG(dt.duration_ms) OVER(PARTITION BY da.artist_name)) as diferencia_ms
FROM fact_spotify_metrics f
JOIN dim_artist da ON f.artist_id = da.artist_id
JOIN dim_track_info dt ON f.track_db_id = dt.track_db_id;

/* =====================================
   FUNCIONES
   ===================================== */
   
-- Voy a crear una función que reciba el Tempo (BPM) y me diga si la canción es Lenta, Moderada o Rápida.
DROP FUNCTION IF EXISTS clasificar_bpm;

DELIMITER $$
CREATE FUNCTION clasificar_bpm(bpm DOUBLE) 
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE categoria VARCHAR(20);
    
    IF bpm < 100 THEN
        SET categoria = 'Lento / Relax';
    ELSEIF bpm BETWEEN 100 AND 130 THEN
        SET categoria = 'Moderado / Pop';
    ELSE
        SET categoria = 'Rápido / Intenso';
    END IF;
    
    RETURN categoria;
END $$
DELIMITER ;

-- Prueba de la función:
SELECT 
    track_db_id, 
    tempo, 
    clasificar_bpm(tempo) as categoria_ritmo 
FROM fact_spotify_metrics;


-- Creo una nueva función que va a interpretar los decibelios de las canciones (variable loudness), para que se entienda mejor.
SELECT loudness FROM fact_spotify_metrics;

DROP FUNCTION IF EXISTS interpretar_volumen;

DELIMITER $$
CREATE FUNCTION interpretar_volumen(db DOUBLE) 
RETURNS VARCHAR(30)
DETERMINISTIC
BEGIN
    DECLARE descripcion VARCHAR(30);
    
    IF db > -5 THEN
        SET descripcion = 'Muy Ruidoso / Saturado';
    ELSEIF db BETWEEN -10 AND -5 THEN
        SET descripcion = 'Alto';
    ELSEIF db BETWEEN -20 AND -10 THEN
        SET descripcion = 'Dinámico / Suave';
    ELSE
        SET descripcion = 'Muy Silencioso';
    END IF;
    
    RETURN descripcion;
END$$
DELIMITER ;

-- Prueba de la función:
SELECT 
    track_db_id, 
    loudness, 
    interpretar_volumen(loudness) as nivel_volumen 
FROM fact_spotify_metrics
ORDER BY RAND() -- Esta función sirve para devolver valores aleatorios cada vez que ejecuto la query
LIMIT 5;

-- Creo una nueva función para modificar los datos de la variable (duration_ms) que vienen en milisegundos y transformarlos a minutos/segundos.
DROP FUNCTION IF EXISTS formater_tiempo;

DELIMITER $$
CREATE FUNCTION formater_tiempo(milisegundos INT) -- milisegundos es el input que recibe la función 
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE minutos INT;
    DECLARE segundos INT;
    DECLARE resultado VARCHAR(20);
    
    SET minutos = FLOOR(milisegundos / 60000); -- FLOOR redondeo hacia abajo
    SET segundos = (milisegundos % 60000) / 1000; -- (%) Módulo/Resto de la división
    
    SET resultado = CONCAT(minutos, 'm ', segundos, 's');
    RETURN resultado;
END$$
DELIMITER ;

-- Probamos la función:
SELECT formater_tiempo(230666) as duracion_legible;

/* =====================================
   VISTAS
   ===================================== */

-- Creo una primera vista para ver un "resumen" de los datos de cada artista.
CREATE OR REPLACE VIEW vista_perfil_artistas AS
SELECT 
    da.artist_name,
    COUNT(f.track_db_id) as total_tracks,
    -- Calculamos promedios de métricas que están en diferentes tablas
    ROUND(AVG(dp.score), 1) as media_popularidad,
    ROUND(AVG(dt.danceability), 2) as media_bailabilidad,
    ROUND(AVG(dt.energy), 2) as media_energia,
    -- Usamos MAX para saber cuál es su pico de éxito
    MAX(dp.score) as mejor_popularidad_historica
FROM fact_spotify_metrics f
JOIN dim_artist da ON f.artist_id = da.artist_id
JOIN dim_track_info dt ON f.track_db_id = dt.track_db_id
JOIN dim_popularity dp ON f.popularity_id = dp.popularity_id
GROUP BY da.artist_name;

-- Prueba de la vista: ¿Quiénes son los artistas más famosos con más de 10 canciones?
SELECT * FROM vista_perfil_artistas
WHERE total_tracks >= 10 
ORDER BY media_popularidad DESC 
LIMIT 10;

-- Creo una segunda vista con un análisis completo de todas las variables que tenemos.
CREATE OR REPLACE VIEW vista_analisis_completo AS
SELECT 
    dt.track_name,
    da.artist_name,
    dg.genre_name,
    dp.score as popularidad,
    dp.category as nivel_exito, -- Variable categórica de nuestra nueva tabla
    dt.duration_ms,
    dt.energy,
    dt.danceability,
    f.tempo,
    clasificar_bpm(f.tempo) as ritmo_desc -- Usamos nuestra función dentro de la vista
FROM fact_spotify_metrics f
JOIN dim_track_info dt ON f.track_db_id = dt.track_db_id
JOIN dim_artist da ON f.artist_id = da.artist_id
JOIN dim_genre dg ON f.genre_id = dg.genre_id
JOIN dim_popularity dp ON f.popularity_id = dp.popularity_id;

-- Haciendo uso de la vista creada vemos todas las métricas de las canciones calificadas como "Top Hit".
SELECT * FROM vista_analisis_completo 	
WHERE nivel_exito = 'Top Hit' 
ORDER BY RAND()
LIMIT 10;


/* =====================================
   ALGUNAS CONCLUSIONES
   ===================================== */

-- 1. Encontrar a los artistas que no solo tienen una canción buena, sino que mantienen una calidad constante.
SELECT 
    artist_name,
    total_tracks,
    media_popularidad,
    media_energia,
    -- Calculamos un "Ratio de Eficiencia" (Popularidad por canción)
    ROUND(media_popularidad / 100, 2) AS indice_calidad
FROM vista_perfil_artistas
WHERE 
    total_tracks > 10         -- Filtramos artistas con trayectoria (más de 10 canciones)
    AND media_popularidad > 70 -- Solo artistas de alto rendimiento
ORDER BY media_popularidad DESC
LIMIT 10;
-- Validamos la consistencia de los artistas, artistas como Bad Bunny y Ariana Grande demuestran un gran promedio de popularidad con un número elevado de canciones.

-- 2. Determinamos si el ritmo (BPM) y la duración influyen en que una canción sea un "Top Hit".
SELECT 
    clasificar_bpm(f.tempo) AS ritmo,
    dp.category AS nivel_exito,
    COUNT(f.track_db_id) AS cantidad_canciones,
    -- Usamos la función para ver la duración promedio de forma legible
    formater_tiempo(AVG(dt.duration_ms)) AS duracion_promedio,
    ROUND(AVG(dt.danceability), 2) AS bailabilidad_media
FROM fact_spotify_metrics f
JOIN dim_track_info dt ON f.track_db_id = dt.track_db_id
JOIN dim_popularity dp ON f.popularity_id = dp.popularity_id
GROUP BY ritmo, nivel_exito
ORDER BY 
    nivel_exito = 'Top Hit' DESC, -- Ponemos los éxitos primero
    cantidad_canciones DESC;
-- Podemos observar que las canciones clasificadas como 'Moderado / Pop' tienen una mayor probabilidad de ser "Top Hits" si su duración ronda los 3 minutos y medio, mientras que las canciones "Lentas" tienden a ser menos bailables y populares.

-- 3. Reporte de Géneros Rentables
SELECT 
    dg.genre_name,
    COUNT(f.track_db_id) AS volumen_mercado, -- Cuántas canciones hay
    ROUND(AVG(dp.score), 1) AS popularidad_promedio,
    -- ¿Qué porcentaje de este género son éxitos rotundos?
    CONCAT(ROUND(SUM(CASE WHEN dp.category = 'Top Hit' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1), '%') AS tasa_de_exito
FROM fact_spotify_metrics f
JOIN dim_genre dg ON f.genre_id = dg.genre_id
JOIN dim_popularity dp ON f.popularity_id = dp.popularity_id
GROUP BY dg.genre_name
HAVING volumen_mercado > 100 -- Nos centramos en los géneros con gran volumen de canciones
ORDER BY tasa_de_exito DESC
LIMIT 10;
-- El género rock y latino presenta la mayor rentabilidad con una tasa de éxito de casi el 10%, lo que sugiere que invertir en producciones de este estilo tiene un menor riesgo.

-- 4. Reporte de las canciones 'Ruidosas' y 'Populares' (Top Hit), mostrando su duración formateada, nombre del artista y género
SELECT 
    dt.track_name,
    da.artist_name,
    dg.genre_name,
    -- Usamos algunas funciones creadas
    formater_tiempo(dt.duration_ms) AS duracion,
    interpretar_volumen(f.loudness) AS desc_volumen,
    dp.category AS categoria_exito
FROM fact_spotify_metrics f
JOIN dim_track_info dt ON f.track_db_id = dt.track_db_id
JOIN dim_artist da ON f.artist_id = da.artist_id
JOIN dim_genre dg ON f.genre_id = dg.genre_id
JOIN dim_popularity dp ON f.popularity_id = dp.popularity_id
WHERE 
    dp.category = 'Top Hit'
    AND f.loudness > -5 -- Filtramos por volumen alto
ORDER BY f.loudness DESC -- Ordenamos por las canciones más ruidosas primero.
LIMIT 20;
-- Vemos que aparecen algunas canciones muy famosas en los últimos años como "PUNTO 40" y "Levitating"









