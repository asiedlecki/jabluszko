FROM pgvector/pgvector:pg16

RUN apt-get update && \
    apt-get install -y postgis postgresql-16-postgis-3 && \
    rm -rf /var/lib/apt/lists/*

COPY init.sql /docker-entrypoint-initdb.d/
