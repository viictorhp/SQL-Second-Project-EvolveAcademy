# Segundo proyecto Evolve Academy
Segundo proyecto realizado para el Máster de Data Science & IA de Evolve Academy. 
Proyecto de MySQL realizado en MySQL Workbench.

# Análisis de datos de Spotify con MySQL 🎵
Base de datos utilizada en este proyecto extraída de Kaggle:
[dataset](https://www.kaggle.com/datasets/maharshipandya/-spotify-tracks-dataset)
## Descripción
Este proyecto consiste en el diseño, implementación y explotación de una base de datos relacional en **MySQL** para analizar un dataset musical de Spotify con unos 114.000 registros.

El objetivo principal ha sido transformar datos crudos en información de valor siguiendo un flujo de trabajo profesional, desde la obtención y limpieza, pasando por el modelado de datos, hasta el análisis avanzado (EDA) para sacar algunas conclusiones relacionadas con el dataset.

## Estructura del Proyecto
- 01_spotify_schema.sql - Creación de la base de datos, creación de la tabla principal (fact_table) y de las 8 tablas de dimensiones (dim_table).
- 02_spotify_data.sql y 02.1_spotify_data.sql  — Carga de datos y limpieza. Establecimiento de relaciones PK (Primary Key), FK (Foreign Key) y Constraints.
- 03_eda.sql — Consultas, funciones, vistas y conclusiones.

## Diagrama E-R del modelo
![Diagrama del Proyecto](proyecto_spotify_model.png)

En el diagrama Entidad - Relación de este proyecto, se puede ver en forma de esquema de estrella; 
la tabla de hechos (fact_table), en mi caso fact_spotify_metrics, que es la tabla núcleo de mi proyecto, la cuál cuenta con todas las Foreign Keys y que "une" todas las tablas de dimensiones (dim_table) que aportan toda la información adicional.

También se puede ver la tabla usada como puente, que contiene todos los datos en crudo (staging_spotify) y las vistas usadas y creadas durante la realización del proyecto.
