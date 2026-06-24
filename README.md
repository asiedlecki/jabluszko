# Store Similarity Finder

An AI-powered backend service built with **FastAPI** and **PostgreSQL** designed to identify and analyze lookalike retail stores based on two distinct operational dimensions:

* **Competitive Landscape:** Finds stores operating in similar market environments and facing comparable competitor profiles.
* **Performance Metrics:** Matches stores with similar financial and operational health, analyzing data points such as sales volume, profit margins, and more.

By leveraging **vector embeddings** and **Euclidean distance ($L_2$ distance)** calculations directly within the database, the system provides high-performance, multi-dimensional similarity mapping to help businesses benchmark performance, optimize strategies, and discover market insights.

### Key Tech Stack
* **Framework:** FastAPI (Python)
* **Database:** PostgreSQL (with vector similarity search)
* **Methodology:** Vector Embeddings & Euclidean Distance Metrics

## Spin Up The Docker Image
```bash
   docker compose up -d --build --force-recreate
```
## Unmount The Docker Image Along With All Volumes
```bash
   docker compose down -v
```

## Test API endpoints
http://localhost:8000/docs

## Enter pgAdmin
http://localhost:5050/login (Credentials are stored in the .env file.)
Authenticate in the Local server with user credentials from the .env file.

## Vector views
- v_store_market_fingerprint - competition vector, for screening stores for most similar stores in terms of environment and competition,
- v_store_complete_performance_fingerprint - performance vector, for screening stores for most similar stores in terms of performance and sales mix.

## Example queries
### Predicting Sales for a New Store (Rollout)

Based on context & competition embedding find best 3 matches.
Vector's components (normalized): 
1. city population,
2. competition score,
3. mall score,
4. competition count,
5. min_competition_sales_area, 
6. median_competition_sales_area, 
7. max_competition_sales_area, 
8. closest competitor distance, 
9. count of competitors in 200 m radius
#### Option 1: Vector components provided manually.
For testing - unrealistic in real life scenario.
```sql
SELECT 
    v.store_id,
    actual_store.kpi_revenue AS historical_annual_revenue,
    actual_store.kpi_footfall AS expected_footfall,
    -- Euclidean distance: closer to 0 means a more identical competitive environment
    (v.vector <-> '[0.45, 0.70, 0.20, 0.30, 0.25, 0.55, 0.7, 0.12, 0.4]'::vector) AS environmental_distance
FROM v_store_market_fingerprint v
JOIN STORE actual_store ON v.store_id = actual_store.store_id
ORDER BY environmental_distance ASC
LIMIT 3;
```
#### Option 2: Vector components pre-calculated in a view.
```sql
SELECT 
    prospective.store_id AS prospective_store_id,
    existing_store.store_id AS lookalike_store_id,
    existing_store.city_name AS lookalike_city,
    -- Pull real performance benchmarks from the matching active store
    existing_store.kpi_revenue AS benchmark_annual_revenue,
    existing_store.kpi_footfall AS benchmark_annual_footfall,
    existing_store.kpi_basket_size AS benchmark_basket_size,
    1 - (prospective.vector <-> lookalike.vector) AS similarity -- 1 for exactly the same stores, -1 for completely different stores
FROM v_store_market_fingerprint prospective
-- Self-join the view to match the new site against everything else
JOIN v_store_market_fingerprint lookalike ON prospective.store_id != lookalike.store_id
-- Join the raw STORE table to filter out other unlaunched stores and pull metrics
JOIN STORE existing_store ON lookalike.store_id = existing_store.store_id
WHERE prospective.store_id = 'JBL001'           -- Store's ID
  AND existing_store.kpi_revenue > 0            -- Ensures we only compare against open, active stores
ORDER BY similarity DESC
LIMIT 3;
```

## Local Python Development Setup

Follow these steps to set up your local virtual environment:

1. **Install Poetry** on your system if you haven't already.
2. **Configure Poetry** to install the virtual environment within the project folder:
```bash
   conda deactivate # if necessary
   poetry config virtualenvs.in-project true
   poetry install
   env activate
```
---

3. Daily Team Workflow

Keep these two habits in mind as a team to prevent environment drifting:

* **When adding new packages:** Anyone on the team who wants to install a new library must run `poetry add <package>`. They should then commit the updated `pyproject.toml` and `poetry.lock` files together.
* **When pulling code changes:** Whenever a teammate pulls changes from Git (`git pull`) and notices that `poetry.lock` has changed, they just need to run `poetry install`. Poetry will instantly sync their local `.venv` to match the repository.
   

