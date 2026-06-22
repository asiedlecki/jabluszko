def similarity_query(embedding_version: str) -> str:
    """
    Generuje zapytanie SQL dynamicznie wstrzykując nazwę kolumny wektora (v1 lub v2).
    Wartości (store_id, limit) jako bezpieczne placeholdery $1 i $2.
    """
    return f"""
        SELECT 
            prospective.store_id AS prospective_store_id,
            existing_store.store_id AS lookalike_store_id,
            existing_store.city_name AS lookalike_city,
            -- Pull real performance benchmarks from the matching active store
            existing_store.kpi_revenue AS benchmark_annual_revenue,
            existing_store.kpi_footfall AS benchmark_annual_footfall,
            existing_store.kpi_basket_size AS benchmark_basket_size,
            1 - (prospective.vector <-> lookalike.vector) AS similarity -- 1 for exactly the same stores, -1 for completely different stores
        FROM {embedding_version} prospective
        -- Self-join the view to match the new site against everything else
        JOIN {embedding_version} lookalike ON prospective.store_id != lookalike.store_id
        -- Join the raw STORE table to filter out other unlaunched stores and pull metrics
        JOIN STORE existing_store ON lookalike.store_id = existing_store.store_id
        WHERE prospective.store_id = $1 -- Store's ID
          AND existing_store.kpi_revenue > 0 -- Ensures we only compare against open, active stores
        ORDER BY similarity DESC
        LIMIT $2;
    """