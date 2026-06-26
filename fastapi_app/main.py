from fastapi import FastAPI, HTTPException, Query
from contextlib import asynccontextmanager
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Any
from database import db
from queries import similarity_query, QUERY_STORE_DETAILS_QUERY
import pandas as pd


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


async def fetch_similar_stores_profile_data(
        store_id: str = Query(..., description="ID sklepu, do którego szukamy podobnych (np. JBL221)"),
        n: int = Query(10, ge=1, le=50, description="Liczba podobnych sklepów do zwrócenia"),
        competition_summary: bool = False
):
    """
    Zwraca 'n' najbardziej podobnych sklepów według otoczenia konkurencyjnego.
    """
    if not db.pool:
        raise HTTPException(status_code=500, detail="Brak połączenia z bazą danych")

    query = similarity_query(competition_summary=competition_summary)

    try:
        async with db.pool.acquire() as connection:
            rows = await connection.fetch(query, store_id, n)            
            query_store = next((r for r in rows if r["store_id"] == store_id), None)
            similar_stores = [r for r in rows if r["store_id"] != store_id]

            return {
                "data": {
                    "query_store": dict(query_store) if query_store else None,
                    "results": [dict(r) for r in similar_stores]
                }
            }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd podczas obliczania podobieństwa v1: {str(e)}")


@app.get("/api/similar/profile/market")
async def get_profiles_of_similar_market_stores(
        store_id: str = Query(..., description="ID sklepu, do którego szukamy podobnych (np. JBL221)"),
        n: int = Query(10, ge=1, le=50, description="Liczba podobnych sklepów do zwrócenia")):
    return await fetch_similar_stores_profile_data(
        store_id=store_id,
        n=n,
        competition_summary=True
    )

@app.get("/api/similar/profile/performance")
async def get_profiles_of_similar_performance_stores(
        store_id: str = Query(..., description="ID sklepu, do którego szukamy podobnych (np. JBL221)"),
        n: int = Query(10, ge=1, le=50, description="Liczba podobnych sklepów do zwrócenia")):
    return await fetch_similar_stores_profile_data(
        store_id=store_id, 
        n=n, 
    )