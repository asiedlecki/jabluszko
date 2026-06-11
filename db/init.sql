BEGIN;

-- Enable the PostGIS extension (requires superuser privileges)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS vector;

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
    competition_radius_km NUMERIC(4,2) NULL,
    kpi_footfall INT NOT NULL,
    kpi_basket_size FLOAT NOT NULL,
    kpi_conversion_rate FLOAT NOT NULL,
    kpi_transactions INT NOT NULL,
    kpi_revenue NUMERIC(9,2) NOT NULL,
    kpi_margin_rate FLOAT NOT NULL, -- IDEA: Why not calculate it in a view instead of hardcoding
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
    mall_id INT NOT NULL, -- IDEA: We can get rid of mall_id, as mall_ids are totally made up
    mall_name VARCHAR(50) NOT NULL,
    distance_km NUMERIC(6,3) NOT NULL,
    PRIMARY KEY (store_id, mall_id) -- IDEA: Can be replaced with pair (store_id, mall_name)
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

-- =======================================
-- CREATE VECTORS
-- =======================================

CREATE OR REPLACE VIEW v_store_market_fingerprint AS
WITH raw_metrics AS (
    SELECT 
        s.store_id,
        c.population AS city_pop,
        s.kpi_competition_score AS comp_score,
        s.kpi_mall_attractiveness_score AS mall_score,
        -- Aggregate competitor data per store
        COALESCE(COUNT(comp.competitor_id), 0) AS comp_count,
        COALESCE(SUM(comp.competitor_sales_area), 0) AS total_comp_area,
        COALESCE(MIN(comp.distance_km), 10.0) AS closest_comp_dist, -- 10km max default if none (TBC)
		COALESCE(COUNT(*) FILTER (WHERE comp.distance_km < 0.2), 0) AS comp_count_200m_radius
    FROM STORE s
    JOIN CITY c ON s.city_name = c.city_name
    LEFT JOIN COMPETITION comp ON s.store_id = comp.store_id
    GROUP BY s.store_id, c.population, s.kpi_competition_score, s.kpi_mall_attractiveness_score
),
stats AS (
    -- Get Min/Max for Normalization
    SELECT 
        MIN(city_pop) as min_cp, MAX(city_pop) as max_cp,
        MIN(comp_count) as min_cc, MAX(comp_count) as max_cc,
        MIN(total_comp_area) as min_ca, MAX(total_comp_area) as max_ca,
        MIN(closest_comp_dist) as min_cd, MAX(closest_comp_dist) as max_cd,
		MIN(comp_count_200m_radius) as min_c200, MAX(comp_count_200m_radius) as max_c200
    FROM raw_metrics
),
normalized AS (
    SELECT 
        rm.store_id,
        -- Normalize all values between 0 and 1
        (rm.city_pop - s.min_cp) / NULLIF(s.max_cp - s.min_cp, 0) AS n_pop,
        rm.comp_score / 1.0 AS n_comp_score, -- Assuming scores are in range 0-1
        rm.mall_score / 1.0 AS n_mall_score,
        (rm.comp_count - s.min_cc) / NULLIF(s.max_cc - s.min_cc, 0) AS n_comp_count,
        (rm.total_comp_area - s.min_ca) / NULLIF(s.max_ca - s.min_ca, 0) AS n_comp_area,
        (rm.closest_comp_dist - s.min_cd) / NULLIF(s.max_cd - s.min_cd, 0) AS n_comp_dist,
		(rm.comp_count_200m_radius - s.min_c200) / NULLIF(s.max_c200 - s.min_c200, 0) AS n_comp_count_200m
    FROM raw_metrics rm, stats s
)
SELECT 
    store_id,
    -- Construct a 6-Dimensional Environmental Vector
    ARRAY[n_pop, n_comp_score, n_mall_score, n_comp_count, n_comp_area, n_comp_dist, n_comp_count_200m]::public.vector(7) AS vector
FROM normalized;

CREATE OR REPLACE VIEW v_store_complete_performance_fingerprint AS
WITH stats AS (
    -- Step A: Gather min and max bounds for all KPI columns across the fleet
    SELECT
        MIN(sm_pieczywo) AS min_piecz, MAX(sm_pieczywo) AS max_piecz,
        MIN(sm_warzywa_i_owoce) AS min_warzyw, MAX(sm_warzywa_i_owoce) AS max_warzyw,
        MIN(sm_slodycze_i_slone_przekaski) AS min_slod, MAX(sm_slodycze_i_slone_przekaski) AS max_slod,
        MIN(sm_piwo) AS min_piwo, MAX(sm_piwo) AS max_piwo,
        MIN(sm_alkohole_mocne) AS min_alko, MAX(sm_alkohole_mocne) AS max_alko,
        MIN(sm_papierosy) AS min_papierosy, MAX(sm_papierosy) AS max_papierosy,
        MIN(sm_fast_food) AS min_fast, MAX(sm_fast_food) AS max_fast,
        MIN(sm_woda_i_napoje_niealkoholowe) AS min_woda, MAX(sm_woda_i_napoje_niealkoholowe) AS max_woda,
        MIN(sm_sery_i_wedliny) AS min_sery, MAX(sm_sery_i_wedliny) AS max_sery,
        MIN(kpi_footfall) AS min_ff, MAX(kpi_footfall) AS max_ff,
        MIN(kpi_basket_size) AS min_bs, MAX(kpi_basket_size) AS max_bs,
        MIN(kpi_conversion_rate) AS min_cr, MAX(kpi_conversion_rate) AS max_cr,
        MIN(kpi_transactions) AS min_tx, MAX(kpi_transactions) AS max_tx,
        MIN(kpi_revenue) AS min_rev, MAX(kpi_revenue) AS max_rev,
        MIN(kpi_margin_rate) AS min_mr, MAX(kpi_margin_rate) AS max_mr,
        MIN(kpi_margin) AS min_mrg, MAX(kpi_margin) AS max_mrg,
        MIN(kpi_competition_score) AS min_cs, MAX(kpi_competition_score) AS max_cs
    FROM STORE
),
normalized_profile AS (
    -- Step B: Keep product shares intact, apply Min-Max math to KPIs
    SELECT
        s.store_id,
        -- Dims 1-9 (Product Assortment)
        (s.sm_pieczywo - st.min_piecz) / NULLIF(st.max_piecz - st.min_piecz, 0) AS n_pieczywo,
        (s.sm_warzywa_i_owoce - st.min_warzyw) / NULLIF(st.max_warzyw - st.min_warzyw, 0) AS n_warzywa_i_owoce,
        (s.sm_slodycze_i_slone_przekaski - st.min_slod) / NULLIF(st.max_slod - st.min_slod, 0) AS n_slodycze_i_slone_przekaski,
        (s.sm_piwo - st.min_piwo) / NULLIF(st.max_piwo - st.min_piwo, 0) AS n_piwo,
        (s.sm_alkohole_mocne - st.min_alko) / NULLIF(st.max_alko - st.min_alko, 0) AS n_alkohole_mocne,
        (s.sm_papierosy - st.min_papierosy) / NULLIF(st.max_papierosy - st.min_papierosy, 0) AS n_papierosy,
        (s.sm_fast_food - st.min_fast) / NULLIF(st.max_fast - st.min_fast, 0) AS n_fast_food,
        (s.sm_woda_i_napoje_niealkoholowe - st.min_woda) / NULLIF(st.max_woda - st.min_woda, 0) AS n_woda_i_napoje_niealkoholowe,
        (s.sm_sery_i_wedliny - st.min_sery) / NULLIF(st.max_sery - st.min_sery, 0) AS n_sery_i_wedliny,
        -- Dims 10-17 (Normalized Performance Metrics)
        (s.kpi_footfall - st.min_ff) / NULLIF(st.max_ff - st.min_ff, 0) AS n_footfall,
        (s.kpi_basket_size - st.min_bs) / NULLIF(st.max_bs - st.min_bs, 0) AS n_basket,
        (s.kpi_conversion_rate - st.min_cr) / NULLIF(st.max_cr - st.min_cr, 0) AS n_conversion,
        (s.kpi_transactions - st.min_tx) / NULLIF(st.max_tx - st.min_tx, 0) AS n_tx,
        (s.kpi_revenue - st.min_rev) / NULLIF(st.max_rev - st.min_rev, 0) AS n_revenue,
        (s.kpi_margin_rate - st.min_mr) / NULLIF(st.max_mr - st.min_mr, 0) AS n_margin_rate,
        (s.kpi_margin - st.min_mrg) / NULLIF(st.max_mrg - st.min_mrg, 0) AS n_margin,
        (s.kpi_competition_score - st.min_cs) / NULLIF(st.max_cs - st.min_cs, 0) AS n_comp_score
    FROM STORE s, stats st
)
SELECT
    store_id,
    -- Construct the unified 17-Dimensional Performance Vector
    ARRAY[
        n_pieczywo, n_warzywa_i_owoce, n_slodycze_i_slone_przekaski,
        n_piwo, n_alkohole_mocne, n_papierosy, n_fast_food,
        n_woda_i_napoje_niealkoholowe, n_sery_i_wedliny,
        n_footfall, n_basket, n_conversion, n_tx,
        n_revenue, n_margin_rate, n_margin, n_comp_score
    ]::public.vector(17) AS vector
FROM normalized_profile;

COMMIT;