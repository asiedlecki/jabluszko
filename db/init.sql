BEGIN;
CREATE EXTENSION IF NOT EXISTS vector;
-- Enable the PostGIS extension (requires superuser privileges)
CREATE EXTENSION IF NOT EXISTS postgis;

-- ==========================================
-- 1. DICTIONARY TABLES
-- ==========================================

CREATE TABLE CHAIN (
    chain_id VARCHAR(20) PRIMARY KEY,
    chain_name VARCHAR(30) NOT NULL,
    chain_type VARCHAR(30) NOT NULL -- e.g., 'discount', 'non_discount_chain', 'independent', 'drugstore'
);

CREATE TABLE CITY (
    city_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- city_id SERIAL PRIMARY KEY
    city_name VARCHAR(30) NOT NULL,
    population INT NOT NULL,
    city_type VARCHAR(20) NOT NULL -- e.g., 'duże miasto'
);

-- ==========================================
-- 2. CORE ENTITIES
-- ==========================================

CREATE TABLE STORE (
    store_id VARCHAR(10) PRIMARY KEY,
    chain_id VARCHAR(20) NOT NULL REFERENCES CHAIN(chain_id) ON DELETE RESTRICT,
    city_id INT NOT NULL REFERENCES CITY(city_id) ON DELETE RESTRICT,
    -- PostGIS Point type using WGS84 (latitude/longitude in degrees, distances natively in meters)
    geom_location GEOGRAPHY(Point, 4326) NOT NULL,
    sales_area_m2 INT NULL, -- NULL allowed as some competitor data might be unknown
    competition_radius_km NUMERIC(4,2) NULL -- Primarily for your own stores
);

CREATE TABLE SHOPPING_MALL (
    mall_id SERIAL PRIMARY KEY, -- mall_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mall_name VARCHAR(150) NOT NULL,
    geom_location GEOGRAPHY(Point, 4326) NOT NULL
);

-- ==========================================
-- 3. METRICS & PERFORMANCE (1:Many Slices)
-- ==========================================

CREATE TABLE SALES_MIX (
    store_id VARCHAR(10) REFERENCES STORE(store_id) ON DELETE CASCADE,
    product_category VARCHAR(30),
    share_percentage NUMERIC(5,2) NOT NULL CHECK (share_percentage >= 0 AND share_percentage <= 100),
    PRIMARY KEY (store_id, product_category)
);

CREATE TABLE KPIS (
    store_id VARCHAR(10) REFERENCES STORE(store_id) ON DELETE CASCADE,
    kpi_category VARCHAR(100),
    kpi_value NUMERIC(14,4) NOT NULL,
    PRIMARY KEY (store_id, kpi_category)
);

-- ==========================================
-- 4. THE SPEED DEMONS (Spatial Indexes)
-- ==========================================

-- These indexes create a rapid bounding-box grid over Poland.
-- Instead of calculating distances for every row, Postgres only calculates
-- distances for entities that share the same spatial grid boxes.
CREATE INDEX idx_store_spatial ON STORE USING GIST (geom_location);
CREATE INDEX idx_mall_spatial ON SHOPPING_MALL USING GIST (geom_location);

-- Standard indexes for rapid relational joins
CREATE INDEX idx_store_chain ON STORE(chain_id);
CREATE INDEX idx_store_city ON STORE(city_id);

-- ==========================================
-- 1. ŁADOWANIE SŁOWNIKA SIECI (CHAIN)
-- ==========================================
-- Nasza własna sieć sklepów, do której należą punkty z prefiksem JBL
INSERT INTO CHAIN (chain_id, chain_name, chain_type) VALUES
('JBL_INTERNAL', 'Jabłuszko', 'convenience_internal');


-- ==========================================
-- 2. ŁADOWANIE SŁOWNIKA MIAST (CITY)
-- ==========================================
-- Wykorzystujemy GENERATED ALWAYS AS IDENTITY, więc pomijamy kolumnę city_id.
-- Postgres sam nada im unikalne identyfikatory 1, 2, 3...
INSERT INTO CITY (city_name, population, city_type) VALUES
('Wrocław', 640000, 'duże miasto'),      -- dostanie ID: 1
('Gdynia', 246000, 'duże miasto'),       -- dostanie ID: 2
('Sosnowiec', 200000, 'duże miasto'),    -- dostanie ID: 3
('Kielce', 196000, 'duże miasto'),       -- dostanie ID: 4
('Poznań', 540000, 'duże miasto'),       -- dostanie ID: 5
('Lublin', 340000, 'duże miasto');       -- dostanie ID: 6


-- ==========================================
-- 3. ŁADOWANIE REKORDÓW SPATIAL (CORE ENTITIES)
-- ==========================================

-- A. SKLEPY (STORE)
-- Wykorzystujemy funkcję ST_MakePoint(longitude, latitude) w standardzie WGS 84 (SRID 4326)
-- i rzutujemy ją na typ GEOGRAPHY, aby współrzędne odzwierciedlały krzywiznę Ziemi.
-- Mapujemy city_id na podstawie słownika powyżej.
INSERT INTO STORE (store_id, chain_id, city_id, geom_location, sales_area_m2, competition_radius_km) VALUES
('JBL001', 'JBL_INTERNAL', 1, ST_SetSRID(ST_MakePoint(16.991039, 51.085388), 4326)::geography, NULL, 1.45),
('JBL002', 'JBL_INTERNAL', 2, ST_SetSRID(ST_MakePoint(18.564785, 54.546500), 4326)::geography, NULL, 1.46),
('JBL003', 'JBL_INTERNAL', 1, ST_SetSRID(ST_MakePoint(17.075590, 51.087729), 4326)::geography, NULL, 2.28),
('JBL004', 'JBL_INTERNAL', 3, ST_SetSRID(ST_MakePoint(19.092530, 50.277510), 4326)::geography, NULL, 2.73),
('JBL005', 'JBL_INTERNAL', 4, ST_SetSRID(ST_MakePoint(20.628885, 50.901372), 4326)::geography, NULL, 1.31),
('JBL006', 'JBL_INTERNAL', 5, ST_SetSRID(ST_MakePoint(16.929759, 52.439860), 4326)::geography, NULL, 2.17),
('JBL007', 'JBL_INTERNAL', 6, ST_SetSRID(ST_MakePoint(22.534557, 51.296253), 4326)::geography, NULL, 1.53);

-- B. GALERIE HANDLOWE (SHOPPING_MALL)
-- Unikalne galerie wyciągnięte z obiektów w JSON (np. przypisane przy JBL002, JBL005, JBL006, JBL007).
-- Ponieważ odrzuciliśmy tabele relacyjne, lokalizacje galerii podajemy wprost jako punkty geograficzne.
-- Przypisujemy im współrzędne poglądowe/zbliżone do rynków miast, w których występują w datasetu:
INSERT INTO SHOPPING_MALL (mall_name, geom_location) VALUES
('Galeria Pestka',       ST_SetSRID(ST_MakePoint(16.9310, 52.4350), 4326)::geography),
('Galeria Młociny',      ST_SetSRID(ST_MakePoint(20.9300, 52.2900), 4326)::geography),
('Galeria Echo',         ST_SetSRID(ST_MakePoint(20.6400, 50.8800), 4326)::geography),
('Arkadia',              ST_SetSRID(ST_MakePoint(20.9840, 52.2560), 4326)::geography),
('Galeria Dominikańska',  ST_SetSRID(ST_MakePoint(17.0390, 51.1080), 4326)::geography);


-- ==========================================
-- 4. STRUKTURA SPRZEDAŻY (SALES_MIX) - Relacja 1:Wiele
-- ==========================================
-- Rozbicie udziałów procentowych kategorii produktowych per sklep.
INSERT INTO SALES_MIX (store_id, product_category, share_percentage) VALUES
-- JBL001
('JBL001', 'pieczywo', 11.97),
('JBL001', 'warzywa i owoce', 14.01),
('JBL001', 'słodycze i słone przekąski', 11.32),
('JBL001', 'piwo', 9.26),
('JBL001', 'alkohole mocne', 6.82),
('JBL001', 'papierosy', 11.54),
('JBL001', 'fast food', 21.26),
('JBL001', 'woda i napoje niealkoholowe', 8.87),
('JBL001', 'sery i wędliny', 4.95),
-- JBL002
('JBL002', 'pieczywo', 7.47),
('JBL002', 'warzywa i owoce', 12.46),
('JBL002', 'słodycze i słone przekąski', 8.45),
('JBL002', 'piwo', 12.09),
('JBL002', 'alkohole mocne', 13.20),
('JBL002', 'papierosy', 10.79),
('JBL002', 'fast food', 20.87),
('JBL002', 'woda i napoje niealkoholowe', 7.19),
('JBL002', 'sery i wędliny', 7.48),
-- JBL005
('JBL005', 'pieczywo', 8.97),
('JBL005', 'warzywa i owoce', 24.76),
('JBL005', 'słodycze i słone przekąski', 14.44),
('JBL005', 'piwo', 6.03),
('JBL005', 'alkohole mocne', 2.31),
('JBL005', 'papierosy', 8.07),
('JBL005', 'fast food', 24.07),
('JBL005', 'woda i napoje niealkoholowe', 6.41),
('JBL005', 'sery i wędliny', 4.94);


-- ==========================================
-- 5. METRYKI (KPIS) - Relacja 1:Wiele (EAV/Slices)
-- ==========================================
-- Wrzucamy kluczowe wskaźniki wydajnościowe dla każdego punktu.
INSERT INTO KPIS (store_id, kpi_category, kpi_value) VALUES
-- JBL001
('JBL001', 'footfall', 5877.0000),
('JBL001', 'basket_size', 51.4800),
('JBL001', 'conversion_rate', 0.2020),
('JBL001', 'transactions', 1187.0000),
('JBL001', 'revenue', 61106.7600),
('JBL001', 'margin', 5560.7200),
('JBL001', 'competition_score', 0.2160),
-- JBL002
('JBL002', 'footfall', 2354.0000),
('JBL002', 'basket_size', 61.8700),
('JBL002', 'conversion_rate', 0.2800),
('JBL002', 'transactions', 659.0000),
('JBL002', 'revenue', 40772.3300),
('JBL002', 'margin', 3302.5600),
('JBL002', 'competition_score', 0.4420),
-- JBL005
('JBL005', 'footfall', 2816.0000),
('JBL005', 'basket_size', 46.2200),
('JBL005', 'conversion_rate', 0.2340),
('JBL005', 'transactions', 659.0000),
('JBL005', 'revenue', 30458.9800),
('JBL005', 'margin', 2558.5500),
('JBL005', 'competition_score', 0.0140);

COMMIT;
