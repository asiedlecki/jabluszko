from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict
import asyncpg
from database import db

app = FastAPI(title="Jabłuszko")

# Zdarzenia cyklu życia aplikacji (Lifespan)
@app.on_event("startup")
async def startup():
    await db.connect()

@app.on_event("shutdown")
async def shutdown():
    await db.disconnect()

@app.get("/api/stores")
async def get_all_stores_from_db():
    if not db.pool:
        raise HTTPException(status_code=500, detail="Brak połączenia z bazą danych")

    try:
        async with db.pool.acquire() as connection:
            query = "SELECT store_id FROM STORE ORDER BY store_id;"
            rows = await connection.fetch(query)

            # asyncpg zwraca obiekty typu Record, które łatwo rzutujemy na słownik Pythonowy
            return [row["store_id"] for row in rows][-3:]

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd bazy danych: {str(e)}")

#
# @app.get("/items/{item_id}")
# async def read_item(item_id: int, q: str | None = None):
#     return {"item_id": item_id, "q": q}