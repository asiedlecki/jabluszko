## Spin Up The Docker Image
```bash
   docker compose up -d --build --force-recreate
```
## Unmount The Docker Image Along With All Volumes
```bash
   docker compose down -v
```

## Enter pgAdmin
http://localhost:5050/login (Credentials are stored in the .env file.)
Add New Server with user credentials from the .env file.

## Example queries
### Predicting Sales for a New Store (Rollout)
```sql
-- Based on context & competition embedding
-- find best 3 matches
SELECT 
    v.store_id,
    actual_store.kpi_revenue AS historical_annual_revenue,
    actual_store.kpi_footfall AS expected_footfall,
    -- Euclidean distance: closer to 0 means a more identical competitive environment
    (v.market_vector <-> '[0.45, 0.70, 0.20, 0.30, 0.55, 0.12, 0.4]'::vector) AS environmental_distance
FROM v_store_market_fingerprint v
JOIN STORE actual_store ON v.store_id = actual_store.store_id
ORDER BY environmental_distance ASC
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
   

