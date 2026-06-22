from fastapi import FastAPI, HTTPException, Query
# from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Any
from database import db
from queries import similarity_query

app = FastAPI(title="Jabłuszko")

# Zdarzenia cyklu życia aplikacji (Lifespan)
@app.on_event("startup")
async def startup():
    await db.connect()

@app.on_event("shutdown")
async def shutdown():
    await db.disconnect()

@app.get("/api/all_db_stores")
async def get_all_stores_from_db():
    if not db.pool:
        raise HTTPException(status_code=500, detail="Brak połączenia z bazą danych")

    try:
        async with db.pool.acquire() as connection:
            query = "SELECT store_id FROM STORE ORDER BY store_id;"
            rows = await connection.fetch(query)

            # asyncpg zwraca obiekty typu Record, które łatwo rzutujemy na słownik Pythonowy
            return [row["store_id"] for row in rows]

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd bazy danych: {str(e)}")


@app.get("/api/similarity", response_model=List[Dict[str, Any]])
async def get_similar_stores(
        store_id: str = Query(..., description="ID sklepu, do którego szukamy podobnych (np. JBL221)"),
        n: int = Query(10, ge=1, le=50, description="Liczba podobnych sklepów do zwrócenia")
):
    """
    Zwraca 'n' najbardziej podobnych sklepów według otoczenia konkurencyjnego.
    """
    if not db.pool:
        raise HTTPException(status_code=500, detail="Brak połączenia z bazą danych")

    query = similarity_query(embedding_version='v_store_market_fingerprint')

    try:
        async with db.pool.acquire() as connection:
            rows = await connection.fetch(query, store_id, n)

            return [
                {
                    "store_id": row["lookalike_store_id"],
                    "city": row["lookalike_city"],
                    "kpi_revenue": row["benchmark_annual_revenue"],
                    "kpi_footfall": row["benchmark_annual_footfall"],
                    "kpi_basket_size": row["benchmark_basket_size"],
                    "similarity": row["similarity"],
                } for row in rows
            ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd podczas obliczania podobieństwa v1: {str(e)}")