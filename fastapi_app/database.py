import os
import asyncpg

DB_URL = os.getenv("DATABASE_URL")

class Database:
    def __init__(self):
        self.pool = None

    async def connect(self):
        self.pool = await asyncpg.create_pool(DB_URL)

    async def disconnect(self):
        if self.pool:
            await self.pool.close()

db = Database()