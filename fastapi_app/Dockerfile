FROM python:3.12

# Set environment variables for Poetry and Python
ENV PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PYTHONUNBUFFERED=1 \
    POETRY_VERSION=2.4.1 \
    POETRY_VIRTUALENVS_CREATE=false \
    POETRY_NO_INTERACTION=1

# Install system dependencies & Poetry
RUN apt-get update && apt-get install -y curl \
    && curl -sSL https://install.python-poetry.org | python3 - \
    && apt-get clean

# Add Poetry to PATH
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app/fastapi_app

# 1. Copy the config files right from the root context
COPY pyproject.toml poetry.lock* ./

# Install dependencies
RUN poetry install --no-root --no-directory

# 2. Copy the application scripts from the fastapi_app folder into the container
COPY ./fastapi_app/main.py ./fastapi_app/database.py ./

EXPOSE 8000

# Start Uvicorn looking for main.py directly in /app
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]