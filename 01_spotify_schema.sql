-- ---------------------------------------------------------
-- PASO 1: CREACIÓN DE BASE DE DATOS Y TABLA STAGING
-- ---------------------------------------------------------
CREATE DATABASE IF NOT EXISTS proyecto_spotify;
USE proyecto_spotify;

-- 1. Tabla Staging (Para importar el CSV crudo)
-- Usamos TEXT para evitar errores de importación iniciales
DROP TABLE IF EXISTS staging_spotify;
CREATE TABLE staging_spotify (
    track_id VARCHAR(255),
    artists TEXT,
    album_name TEXT,
    track_name TEXT,
    popularity INT,
    duration_ms INT,
    explicit VARCHAR(10),
    danceability DOUBLE, -- Números decimales más precisos
    energy DOUBLE,
    key_val INT,
    loudness DOUBLE,
    mode_val INT,
    speechiness DOUBLE,
    acousticness DOUBLE,
    instrumentalness DOUBLE,
    liveness DOUBLE,
    valence DOUBLE,
    tempo DOUBLE,
    time_signature INT,
    track_genre VARCHAR(100)
); 
 
-- ---------------------------------------------------------
-- PASO 2: CREACIÓN DE LAS 8 TABLAS DE DIMENSIONES
-- ---------------------------------------------------------
-- Dimensión 1: Artistas
CREATE TABLE IF NOT EXISTS dim_artist (
    artist_id INT AUTO_INCREMENT PRIMARY KEY,
    artist_name TEXT NOT NULL,
    -- Aquí definimos la regla de unicidad sobre los primeros 300 caracteres, ya que, existen nombres de artistas (posiblemente colaboraciones) que superan los 255 caracteres.
    -- Por ello no uso VARCHAR y uso TEXT, pero sí quiero que me compruebe que los 300 primeros caracteres del artist_name son valores únicos.
    CONSTRAINT unique_artist_name UNIQUE (artist_name(300))
) COMMENT 'Dimensión que almacena los nombres de los artistas';

-- Dimensión 2: Álbumes
CREATE TABLE IF NOT EXISTS dim_album (
    album_id INT AUTO_INCREMENT PRIMARY KEY,
    album_name TEXT NOT NULL,
    CONSTRAINT unique_album_name UNIQUE (album_name(300))
) COMMENT 'Dimensión que almacena los nombres de los álbumes';

-- Dimensión 3: Géneros
CREATE TABLE IF NOT EXISTS dim_genre (
    genre_id INT AUTO_INCREMENT PRIMARY KEY,
    genre_name VARCHAR(255) UNIQUE NOT NULL
) COMMENT 'Clasificación de géneros musicales';

-- Dimensión 4: Información de la Pista (Nombre y si contiene contenido explícito)
CREATE TABLE IF NOT EXISTS dim_track_info (
    track_db_id INT AUTO_INCREMENT PRIMARY KEY,
    track_spotify_id VARCHAR(50) UNIQUE, -- El ID original de Spotify
    track_name TEXT,
    is_explicit BOOLEAN -- True (sí contiene contenido explícito) o False (no contiene contenido explícito)
) COMMENT 'Información descriptiva de la canción';

-- Dimensión 5: Tonalidad (Key) - Tabla estática explicativa
	-- Números del 0 al 11. Cada número corresponde a una de las 12 notas de la escala cromática.
CREATE TABLE IF NOT EXISTS dim_key (
    key_id INT PRIMARY KEY,
    key_name VARCHAR(10)
) COMMENT 'Escala musical (0=C, 1=C#, etc)';

-- Dimensión 6: Modalidad (Mode) - Tabla estática explicativa
CREATE TABLE IF NOT EXISTS dim_mode (
    mode_id INT PRIMARY KEY,
    mode_desc VARCHAR(10)
) COMMENT 'Modalidad de la canción (1=Mayor o 0=Menor)';

-- Dimensión 7: Compás (Time Signature)
CREATE TABLE IF NOT EXISTS dim_time_signature (
    time_sig_id INT PRIMARY KEY,
    description VARCHAR(20)
) COMMENT 'El compás de la canción (ej. 4/4)';

-- Dimensión 8: Contenido Explícito
CREATE TABLE IF NOT EXISTS dim_explicit (
    explicit_id INT AUTO_INCREMENT PRIMARY KEY,
    explicit_val VARCHAR(10) UNIQUE -- 'True' o 'False'
) COMMENT 'Indica si la canción tiene contenido explícito';

-- ---------------------------------------------------------
-- PASO 3: CREACIÓN DE LA TABLA DE HECHOS (FACT TABLE)
-- ---------------------------------------------------------
DROP TABLE IF EXISTS fact_spotify_metrics;

CREATE TABLE IF NOT EXISTS fact_spotify_metrics (
    fact_id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- CLAVES FORÁNEAS (Foreign Keys) que conectan con las 8 dimensiones
    artist_id INT,
    album_id INT,
    genre_id INT,
    track_db_id INT,
    explicit_id INT,
    key_id INT,
    mode_id INT,
    time_sig_id INT,
    
    -- MÉTRICAS (Facts) - Datos numéricos para el análisis
    popularity INT,
    duration_ms INT,
    danceability DOUBLE,
    energy DOUBLE,
    loudness DOUBLE,
    speechiness DOUBLE,
    acousticness DOUBLE,
    instrumentalness DOUBLE,
    liveness DOUBLE,
    valence DOUBLE,
    tempo DOUBLE,
    
    -- DEFINICIÓN DE RELACIONES (Constraints)
    CONSTRAINT fk_artist FOREIGN KEY (artist_id) REFERENCES dim_artist(artist_id),
    CONSTRAINT fk_album FOREIGN KEY (album_id) REFERENCES dim_album(album_id),
    CONSTRAINT fk_genre FOREIGN KEY (genre_id) REFERENCES dim_genre(genre_id),
    CONSTRAINT fk_track FOREIGN KEY (track_db_id) REFERENCES dim_track_info(track_db_id),
    CONSTRAINT fk_explicit FOREIGN KEY (explicit_id) REFERENCES dim_explicit(explicit_id),
    CONSTRAINT fk_key FOREIGN KEY (key_id) REFERENCES dim_key(key_id),
    CONSTRAINT fk_mode FOREIGN KEY (mode_id) REFERENCES dim_mode(mode_id),
    CONSTRAINT fk_timesig FOREIGN KEY (time_sig_id) REFERENCES dim_time_signature(time_sig_id)
) COMMENT 'Tabla central de hechos con métricas de audio y referencias a las dimensiones';