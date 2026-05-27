BEGIN;

-- Enable the PostGIS extension (requires superuser privileges)
CREATE EXTENSION IF NOT EXISTS postgis;

-- ==========================================
-- 1. DICTIONARY TABLES
-- ==========================================

CREATE TABLE CHAIN (
    chain_id VARCHAR(30) PRIMARY KEY,
    chain_name VARCHAR(30) NOT NULL,
    chain_type VARCHAR(30) NOT NULL
);

CREATE TABLE CITY (
    city_name VARCHAR(30) PRIMARY KEY,
    population INT NOT NULL,
    city_type VARCHAR(20) NOT NULL
);

-- ==========================================
-- 2. CORE ENTITIES
-- ==========================================

CREATE TABLE STORE (
    store_id VARCHAR(10) PRIMARY KEY,
    city_name VARCHAR(30) NOT NULL REFERENCES CITY(city_name) ON DELETE RESTRICT,
    -- PostGIS Point type using WGS84 (latitude/longitude in degrees, distances natively in meters)
    geom_location GEOGRAPHY(Point, 4326) NOT NULL,
    competition_radius_km NUMERIC(4,2) NULL, -- Primarily for your own stores,
    kpi_footfall INT NOT NULL,
    kpi_basket_size FLOAT NOT NULL,
    kpi_conversion_rate FLOAT NOT NULL,
    kpi_transactions INT NOT NULL,
    kpi_revenue NUMERIC(9,2) NOT NULL,
    kpi_margin_rate FLOAT NOT NULL, -- why not calculate it in a view instead of hardcoding
    kpi_margin NUMERIC(9,2) NOT NULL,
    kpi_competition_score FLOAT NOT NULL,
    kpi_mall_attractiveness_score FLOAT NOT NULL,
    sm_pieczywo FLOAT NOT NULL,
    sm_warzywa_i_owoce FLOAT NOT NULL,
    sm_slodycze_i_slone_przekaski FLOAT NOT NULL,
    sm_piwo FLOAT NOT NULL,
    sm_alkohole_mocne FLOAT NOT NULL,
    sm_papierosy FLOAT NOT NULL,
    sm_fast_food FLOAT NOT NULL,
    sm_woda_i_napoje_niealkoholowe FLOAT NOT NULL,
    sm_sery_i_wedliny FLOAT NOT NULL
);

CREATE TABLE COMPETITION (
    store_id VARCHAR(10) NOT NULL REFERENCES STORE(store_id) ON DELETE RESTRICT,
    competitor_id INT NOT NULL,
    chain_id VARCHAR(30) NOT NULL REFERENCES CHAIN(chain_id) ON DELETE RESTRICT,
    competitor_sales_area INT NOT NULL,
    distance_km NUMERIC(6,3) NOT NULL,
    PRIMARY KEY (store_id, competitor_id)
);

CREATE TABLE SHOPPING_MALL (
    store_id VARCHAR(10) NOT NULL REFERENCES STORE(store_id) ON DELETE RESTRICT,
    mall_id INT NOT NULL,
    mall_name VARCHAR(50) NOT NULL,
    distance_km NUMERIC(6,3) NOT NULL,
    PRIMARY KEY (store_id, mall_id)
);

-- ==========================================
-- 4. INDEXES
-- ==========================================

-- Standard indexes for rapid relational joins
CREATE INDEX idx_store_city ON STORE(city_name);
CREATE INDEX idx_competition_store ON COMPETITION(store_id);
CREATE INDEX idx_mall_store ON SHOPPING_MALL(store_id);
CREATE INDEX idx_store_spatial ON STORE USING GIST(geom_location);

-- ==========================================
-- 5. FILL TABLES WITH DATA FROM CSV FILES
-- ==========================================

--Dictionaries (Foreign Key targets)
COPY CHAIN (chain_id, chain_name, chain_type)
FROM '/data/chain.csv'
DELIMITER ',' CSV HEADER;

COPY CITY (city_name, population, city_type)
FROM '/data/city.csv'
DELIMITER ',' CSV HEADER;

-- Main Tables
COPY STORE (
    store_id, city_name, geom_location, competition_radius_km, 
    kpi_footfall, kpi_basket_size, kpi_conversion_rate, kpi_transactions, 
    kpi_revenue, kpi_margin_rate, kpi_margin, kpi_competition_score, 
    kpi_mall_attractiveness_score, sm_pieczywo, sm_warzywa_i_owoce, 
    sm_slodycze_i_slone_przekaski, sm_piwo, sm_alkohole_mocne, 
    sm_papierosy, sm_fast_food, sm_woda_i_napoje_niealkoholowe, sm_sery_i_wedliny
)
FROM '/data/store.csv'
DELIMITER ',' CSV HEADER;

-- Dependent Tables (Foreign Key sources)
COPY COMPETITION (store_id, competitor_id, chain_id, competitor_sales_area, distance_km)
FROM '/data/competition.csv'
DELIMITER ',' CSV HEADER;

COPY SHOPPING_MALL (store_id, mall_id, mall_name, distance_km)
FROM '/data/shopping_mall.csv'
DELIMITER ',' CSV HEADER;

COMMIT;
