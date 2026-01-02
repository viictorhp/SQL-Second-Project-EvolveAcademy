-- Este script llenará primero las 8 dimensiones y, finalmente, cruzará todo para llenar la tabla de hechos.
USE proyecto_spotify;

-- ----------------------------------------------------------------------------
-- A) AÑADIMOS DATOS A LAS TABLAS DE DIMENSIONES (Datos únicos)
-- ----------------------------------------------------------------------------

-- 1. Artistas
INSERT INTO dim_artist (artist_name)
SELECT DISTINCT artists 
FROM staging_spotify 
WHERE artists IS NOT NULL AND artists != '';

-- 2. Álbumes
INSERT INTO dim_album (album_name)
SELECT DISTINCT album_name 
FROM staging_spotify 
WHERE album_name IS NOT NULL;

-- 3. Géneros
INSERT INTO dim_genre (genre_name)
SELECT DISTINCT track_genre 
FROM staging_spotify 
WHERE track_genre IS NOT NULL;

-- 4. Pistas (Track Info)
INSERT INTO dim_track_info (track_spotify_id, track_name)
SELECT DISTINCT track_id, track_name 
FROM staging_spotify 
WHERE track_id IS NOT NULL;

-- 5. Key (Tonalidad)
INSERT INTO dim_key (key_id, key_name)
SELECT DISTINCT key_val, CONCAT('Key ', key_val) 
FROM staging_spotify 
ORDER BY key_val;

-- 6. Mode (Modalidad)
INSERT INTO dim_mode (mode_id, mode_desc)
SELECT DISTINCT mode_val, CASE WHEN mode_val = 1 THEN 'Major' ELSE 'Minor' END 
FROM staging_spotify;

-- 7. Time Signature (Compás)
INSERT INTO dim_time_signature (time_sig_id, description)
SELECT DISTINCT time_signature, CONCAT(time_signature, '/4') 
FROM staging_spotify 
ORDER BY time_signature;

-- 8. Contenido explícito
INSERT INTO dim_explicit (explicit_val)
SELECT DISTINCT explicit 
FROM staging_spotify;


-- ----------------------------------------------------------------------------
-- B) POBLAR LA TABLA DE HECHOS (El gran cruce de datos)
-- ----------------------------------------------------------------------------

INSERT INTO fact_spotify_metrics 
(
    artist_id, album_id, genre_id, track_db_id, explicit_id, key_id, mode_id, time_sig_id,
    popularity, duration_ms, danceability, energy, loudness, 
    speechiness, acousticness, instrumentalness, liveness, valence, tempo
)
SELECT 
    da.artist_id,
    dal.album_id,
    dg.genre_id,
    dt.track_db_id,
    de.explicit_id,
    dk.key_id,
    dm.mode_id,
    dts.time_sig_id,
    s.popularity,
    s.duration_ms,
    s.danceability,
    s.energy,
    s.loudness,
    s.speechiness,
    s.acousticness,
    s.instrumentalness,
    s.liveness,
    s.valence,
    s.tempo
FROM staging_spotify s
-- Hacemos INNER JOIN con las dimensiones para obtener los IDs numéricos (Foreign Keys)
INNER JOIN dim_artist da ON s.artists = da.artist_name
INNER JOIN dim_album dal ON s.album_name = dal.album_name
INNER JOIN dim_genre dg ON s.track_genre = dg.genre_name
INNER JOIN dim_track_info dt ON s.track_id = dt.track_spotify_id
INNER JOIN dim_explicit de ON s.explicit = de.explicit_val
-- Usamos LEFT JOIN en claves numéricas por si acaso algún dato vino nulo (aunque no debería)
LEFT JOIN dim_key dk ON s.key_val = dk.key_id
LEFT JOIN dim_mode dm ON s.mode_val = dm.mode_id
LEFT JOIN dim_time_signature dts ON s.time_signature = dts.time_sig_id;

-- Verificación final
SELECT COUNT(*) FROM fact_spotify_metrics;