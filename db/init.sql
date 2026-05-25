BEGIN;

-- Enable the PostGIS extension (requires superuser privileges)
CREATE EXTENSION IF NOT EXISTS postgis;

-- ==========================================
-- 1. DICTIONARY TABLES
-- ==========================================

CREATE TABLE CHAIN (
    chain_id VARCHAR(20) PRIMARY KEY,
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
    sales_area_m2 INT NULL, -- NULL allowed as some competitor data might be unknown
    competition_radius_km NUMERIC(4,2) NULL, -- Primarily for your own stores,
    footfall INT NOT NULL,
    basket_size FLOAT NOT NULL,
    conversion_rate FLOAT NOT NULL,
    transactions INT NOT NULL,
    revenue NUMERIC(9,2) NOT NULL,
    margin_rate FLOAT NOT NULL, -- why not calculate it in a view instead of hardcoding
    margin NUMERIC(9,2) NOT NULL,
    competition_score FLOAT NOT NULL,
    mall_attractiveness_score FLOAT NOT NULL,
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
    chain_id VARCHAR(20) NOT NULL REFERENCES CHAIN(chain_id) ON DELETE RESTRICT,
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
-- 1. DICTIONARY TABLES INSERTs
-- ==========================================

-- Populating CHAIN
INSERT INTO CHAIN (chain_id, chain_name, chain_type) VALUES
('biedronka', 'Biedronka', 'Discounter'),
('lidl', 'Lidl', 'Discounter'),
('zabka', 'Żabka', 'Convenience'),
('dino', 'Dino', 'Supermarket');

-- Populating CITY
INSERT INTO CITY (city_name, population, city_type) VALUES
('Warszawa', 1790000, 'Metropolis'),
('Kraków', 780000, 'Large City'),
('Poznań', 535000, 'Large City'),
('Wrocław', 640000, 'Large City');

-- ==========================================
-- 2. CORE ENTITIES INSERTs
-- ==========================================

-- Populating STORE (with PostGIS WGS84 geography points)
INSERT INTO STORE (
    store_id, city_name, geom_location, sales_area_m2, competition_radius_km, 
    footfall, basket_size, conversion_rate, transactions, revenue, margin_rate, margin, 
    competition_score, mall_attractiveness_score, 
    sm_pieczywo, sm_warzywa_i_owoce, sm_slodycze_i_slone_przekaski, sm_piwo, 
    sm_alkohole_mocne, sm_papierosy, sm_fast_food, sm_woda_i_napoje_niealkoholowe, sm_sery_i_wedliny
) VALUES
(
    'ST001', 
    'Poznań', 
    ST_SetSRID(ST_MakePoint(16.9252, 52.4064), 4326)::geography, -- Longitude, Latitude
    850, 
    2.50, 
    1200, 45.50, 0.65, 780, 35490.00, 0.24, 8517.60, 
    7.5, 4.2, 
    0.15, 0.12, 0.18, 0.10, 0.08, 0.07, 0.05, 0.15, 0.10
),
(
    'ST002', 
    'Warszawa', 
    ST_SetSRID(ST_MakePoint(21.0122, 52.2297), 4326)::geography, 
    1100, 
    1.80, 
    2100, 52.30, 0.72, 1512, 79077.60, 0.26, 20560.18, 
    8.9, 8.5, 
    0.12, 0.14, 0.15, 0.08, 0.09, 0.05, 0.12, 0.13, 0.12
);

-- Populating COMPETITION
INSERT INTO COMPETITION (store_id, competitor_id, chain_id, competitor_sales_area, distance_km) VALUES
('ST001', 101, 'biedronka', 900, 0.450),
('ST001', 102, 'zabka', 80, 0.120),
('ST002', 201, 'lidl', 1200, 1.150),
('ST002', 202, 'dino', 600, 2.400);

-- Populating SHOPPING_MALL
INSERT INTO SHOPPING_MALL (store_id, mall_id, mall_name, distance_km) VALUES
('ST001', 501, 'Posnania', 1.350),
('ST002', 502, 'Złote Tarasy', 0.250);

COMMIT;
