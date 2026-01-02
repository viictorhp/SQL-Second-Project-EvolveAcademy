SHOW VARIABLES LIKE 'secure_file_priv';

USE proyecto_spotify;

-- 1. Limpiar la tabla por si acaso
TRUNCATE TABLE staging_spotify;

-- 2. Cargar con salto de línea '\n'
	-- Cargamos todos los datos del dataset extraído de Kaggle en formato "csv" y los añadimos a la tabla "staging_spotify"
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/dataset.csv' 
INTO TABLE staging_spotify 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'  -- Salto de línea
IGNORE 1 ROWS  -- Se salta la primera fila del archivo (el título de las columnas)
-- Orden de las columnas (variables) con "@dummy_id" para no guardar los índices del archivo CSV (ya tenemos nuestros propios índices)
(@dummy_id, track_id, artists, album_name, track_name, popularity, duration_ms, explicit, danceability, energy, key_val, loudness, mode_val, speechiness, acousticness, instrumentalness, liveness, valence, tempo, time_signature, track_genre);

-- 3. Verificación
SELECT COUNT(*) as total_filas FROM staging_spotify;
