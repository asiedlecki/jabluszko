from fastapi import FastAPI, HTTPException, Query
from contextlib import asynccontextmanager
# from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Any
from database import db
from queries import similarity_query, QUERY_STORE_DETAILS_QUERY


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()

    yield

    await db.disconnect()
app = FastAPI(title="Jabłuszko", lifespan=lifespan)

@app.get("/api/all_db_stores")
async def get_all_stores_from_db():
    if not db.pool:
        raise HTTPException(status_code=500, detail="Brak połączenia z bazą danych")

    try:
        async with db.pool.acquire() as connection:
            query = "SELECT store_id, city_name FROM STORE ORDER BY store_id;"
            rows = await connection.fetch(query)

            # asyncpg zwraca obiekty typu Record, które łatwo rzutujemy na słownik Pythonowy
            return [{"store_id": row["store_id"], "city_name": row["city_name"]} for row in rows]

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd bazy danych: {str(e)}")

async def fetch_similar_stores_data(
        store_id: str = Query(..., description="ID sklepu, do którego szukamy podobnych (np. JBL221)"),
        n: int = Query(10, ge=1, le=50, description="Liczba podobnych sklepów do zwrócenia"),
        embedding_version: str = Query(description="Typ wektorów do porównania")
):
    """
    Zwraca 'n' najbardziej podobnych sklepów według otoczenia konkurencyjnego.
    """
    if not db.pool:
        raise HTTPException(status_code=500, detail="Brak połączenia z bazą danych")

    query = similarity_query(embedding_version=embedding_version)

    try:
        async with db.pool.acquire() as connection:
            query_store = await connection.fetchrow(QUERY_STORE_DETAILS_QUERY, store_id)
            sim_stores = await connection.fetch(query, store_id, n)

            return {
    "data": {
        "query_store": {
            "store_id": query_store["store_id"],
            "city": query_store["city_name"],
            "population": query_store["population"],
            "kpi_footfall": query_store["kpi_footfall"],
            "kpi_basket_size": query_store["kpi_basket_size"],
            "kpi_conversion_rate": query_store["kpi_conversion_rate"],
            "kpi_transactions": query_store["kpi_transactions"],
            "kpi_revenue": query_store["kpi_revenue"],
            "kpi_margin_rate": query_store["kpi_margin_rate"],
            "kpi_margin": query_store["kpi_margin"],
            "kpi_competition_score": query_store["kpi_competition_score"],
            "kpi_mall_attractiveness_score": query_store["kpi_mall_attractiveness_score"],
            "sm_pieczywo": query_store["sm_pieczywo"],
            "sm_warzywa_i_owoce": query_store["sm_warzywa_i_owoce"],
            "sm_slodycze_i_slone_przekaski": query_store["sm_slodycze_i_slone_przekaski"],
            "sm_piwo": query_store["sm_piwo"],
            "sm_alkohole_mocne": query_store["sm_alkohole_mocne"],
            "sm_papierosy": query_store["sm_papierosy"],
            "sm_fast_food": query_store["sm_fast_food"],
            "sm_woda_i_napoje_niealkoholowe": query_store["sm_woda_i_napoje_niealkoholowe"],
            "sm_sery_i_wedliny": query_store["sm_sery_i_wedliny"]
        },
        "results": [
            {
                "store_id": store["store_id"],
                "city": store["city_name"],
                "kpi_footfall": store["kpi_footfall"],
                "kpi_basket_size": store["kpi_basket_size"],
                "kpi_conversion_rate": store["kpi_conversion_rate"],
                "kpi_transactions": store["kpi_transactions"],
                "kpi_revenue": store["kpi_revenue"],
                "kpi_margin_rate": store["kpi_margin_rate"],
                "kpi_margin": store["kpi_margin"],
                "kpi_competition_score": store["kpi_competition_score"],
                "kpi_mall_attractiveness_score": store["kpi_mall_attractiveness_score"],
                "sm_pieczywo": store["sm_pieczywo"],
                "sm_warzywa_i_owoce": store["sm_warzywa_i_owoce"],
                "sm_slodycze_i_slone_przekaski": store["sm_slodycze_i_slone_przekaski"],
                "sm_piwo": store["sm_piwo"],
                "sm_alkohole_mocne": store["sm_alkohole_mocne"],
                "sm_papierosy": store["sm_papierosy"],
                "sm_fast_food": store["sm_fast_food"],
                "sm_woda_i_napoje_niealkoholowe": store["sm_woda_i_napoje_niealkoholowe"],
                "sm_sery_i_wedliny": store["sm_sery_i_wedliny"],
                "similarity": store["similarity"],
            } for store in sim_stores
        ]
    }
}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd podczas obliczania podobieństwa v1: {str(e)}")

@app.get("/api/similar/market")
async def get_similar_market_stores(
        store_id: str = Query(..., description="ID sklepu, do którego szukamy podobnych (np. JBL221)"),
        n: int = Query(10, ge=1, le=50, description="Liczba podobnych sklepów do zwrócenia")):
    return await fetch_similar_stores_data(store_id=store_id, n=n, embedding_version="v_store_market_fingerprint")

@app.get("/api/similar/performance")
async def get_similar_performance_stores(
        store_id: str = Query(..., description="ID sklepu, do którego szukamy podobnych (np. JBL221)"),
        n: int = Query(10, ge=1, le=50, description="Liczba podobnych sklepów do zwrócenia")):
    return await fetch_similar_stores_data(store_id=store_id, n=n, embedding_version="v_store_complete_performance_fingerprint")