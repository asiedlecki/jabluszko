QUERY_STORE_DETAILS_QUERY = """
    SELECT 
        s.store_id,
        s.city_name,
        c.population,
        s.kpi_footfall,
        s.kpi_basket_size,
        s.kpi_conversion_rate,
        s.kpi_transactions,
        s.kpi_revenue,
        s.kpi_margin_rate, -- IDEA: Why not calculate it in a view instead of hardcoding
        s.kpi_margin,
        s.kpi_competition_score,
        s.kpi_mall_attractiveness_score,
        s.sm_pieczywo,
        s.sm_warzywa_i_owoce,
        s.sm_slodycze_i_slone_przekaski,
        s.sm_piwo,
        s.sm_alkohole_mocne,
        s.sm_papierosy,
        s.sm_fast_food,
        s.sm_woda_i_napoje_niealkoholowe,
        s.sm_sery_i_wedliny
    FROM STORE s
    LEFT JOIN CITY c ON c.city_name = s.city_name
    WHERE s.store_id = $1
"""

def similarity_query(embedding_version: str, competition_summary: bool=False) -> str:
    """
    Generuje zapytanie SQL dynamicznie podstawiając nazwę widoku z typem wektora.
    Wartości (store_id, limit) jako bezpieczne placeholdery $1 i $2.
    """
    if competition_summary:
        return f"""
                    SELECT 
                        existing_store.*,
                        1 - (prospective.vector <-> lookalike.vector) AS similarity -- 1 for exactly the same stores, -1 for completely different stores
                    FROM {embedding_version} prospective
                    -- Self-join the view to match the new site against everything else
                    JOIN {embedding_version} lookalike ON prospective.store_id != lookalike.store_id
                    -- Join the raw STORE table to filter out other unlaunched stores and pull metrics
                    JOIN v_store_competition_summary existing_store ON lookalike.store_id = existing_store.store_id
                    WHERE prospective.store_id = $1 -- Store's ID
--                       AND existing_store.kpi_revenue > 0 -- Ensures we only compare against open, active stores
                    ORDER BY similarity DESC
                    LIMIT $2;
                """
    else:
        return f"""
            SELECT 
                existing_store.store_id,
                existing_store.city_name,
                -- Pull real performance benchmarks from the matching active store
                existing_store.kpi_footfall,
                existing_store.kpi_basket_size,
                existing_store.kpi_conversion_rate,
                existing_store.kpi_transactions,
                existing_store.kpi_revenue,
                existing_store.kpi_margin_rate,
                existing_store.kpi_margin,
                existing_store.kpi_competition_score,
                existing_store.kpi_mall_attractiveness_score,
                existing_store.sm_pieczywo,
                existing_store.sm_warzywa_i_owoce,
                existing_store.sm_slodycze_i_slone_przekaski,
                existing_store.sm_piwo,
                existing_store.sm_alkohole_mocne,
                existing_store.sm_papierosy,
                existing_store.sm_fast_food,
                existing_store.sm_woda_i_napoje_niealkoholowe,
                existing_store.sm_sery_i_wedliny,
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