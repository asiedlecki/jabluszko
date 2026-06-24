from fastapi import FastAPI, HTTPException, Query
from contextlib import asynccontextmanager
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Any
from database import db
from queries import similarity_query, QUERY_STORE_DETAILS_QUERY


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()

    yield

    await db.disconnect()
app = FastAPI(title="Jabłuszko", lifespan=lifespan)

origins = [
    "http://localhost:5173",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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

            columns = [
                "kpi_footfall", "kpi_basket_size", "kpi_conversion_rate", "kpi_transactions",
                "kpi_revenue", "kpi_margin_rate", "kpi_margin", "kpi_competition_score",
                "kpi_mall_attractiveness_score", "sm_pieczywo", "sm_warzywa_i_owoce",
                "sm_slodycze_i_slone_przekaski", "sm_piwo", "sm_alkohole_mocne",
                "sm_papierosy", "sm_fast_food", "sm_woda_i_napoje_niealkoholowe", "sm_sery_i_wedliny"
            ]

            return {
                "data": {
                    "query_store": {
                        "store_id": query_store["store_id"],
                        "city": query_store["city_name"],
                        "population": query_store["population"],
                        **{col: query_store[col] for col in columns}
                    },
                    "results": [
                        {
                            "store_id": store["store_id"],
                            "city": store["city_name"],
                            "similarity": store["similarity"],
                            **{col: store[col] for col in columns}
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