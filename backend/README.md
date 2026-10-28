# FitBuddy Backend

Secure Python FastAPI proxy between the FitBuddy iOS app and the Groq LLM API.  
The Groq API key **never** leaves this server.

## Architecture

```
iOS SwiftUI App
     │
     │  POST /api/v1/workout/recommendations
     │  POST /api/v1/nutrition/recommendations
     │  GET  /health (or /api/v1/health)
     ▼
FitBuddy FastAPI Backend  (this repo)
     │
     │  Groq Chat Completions (llama-3.1-8b-instant by default)
     ▼
Groq Cloud
```

## Requirements

- Python 3.9+
- A [Groq API key](https://console.groq.com/keys) (free tier is sufficient for development)

## Setup

### 1. Enter the project root

```bash
cd "kuch to hai"
```

### 2. Create and activate a virtual environment

```bash
python3 -m venv backend/.venv
source backend/.venv/bin/activate        # macOS / Linux
# backend\.venv\Scripts\activate         # Windows
```

### 3. Install dependencies

```bash
pip install -r backend/requirements.txt
```

### 4. Configure environment variables

```bash
cp backend/.env.example backend/.env
```

Open `backend/.env` and set your real Groq API key:

```
GROQ_API_KEY=gsk_your_real_key_here
```

> ⚠️ **Never commit `.env` to Git.** It is listed in `.gitignore`.

### 5. Start the development server

From the **project root**:

```bash
backend/.venv/bin/uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

The server will be available at `http://127.0.0.1:8000`.

Interactive API docs: `http://127.0.0.1:8000/docs`

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET`  | `/health` | Lightweight health check |
| `GET`  | `/api/v1/health` | Health check (versioned alias) |
| `POST` | `/api/v1/workout/recommendations` | Generate personalised workout routines |
| `POST` | `/api/v1/nutrition/recommendations` | Generate food suggestions |

Full request/response schemas: see [`API_CONTRACT.md`](../API_CONTRACT.md).

## Quick test with curl

**Health check:**
```bash
curl http://127.0.0.1:8000/health
```

**Workout recommendations:**
```bash
curl -s -X POST http://127.0.0.1:8000/api/v1/workout/recommendations \
  -H "Content-Type: application/json" \
  -d '{
    "user_name": "Priya",
    "gender": "Female",
    "fitness_goal": "General Fitness",
    "daily_mood": "Energized ⚡️",
    "available_equipment": ["None (Bodyweight)", "Yoga Mat"],
    "available_time_seconds": 1500,
    "recent_completed_workouts": []
  }' | python3 -m json.tool
```

**Nutrition recommendations:**
```bash
curl -s -X POST http://127.0.0.1:8000/api/v1/nutrition/recommendations \
  -H "Content-Type: application/json" \
  -d '{
    "user_name": "Priya",
    "fitness_goal": "Weight Loss",
    "daily_calorie_target": 2000,
    "daily_protein_target_grams": 140,
    "daily_carbohydrates_target_grams": 200,
    "daily_fat_target_grams": 65,
    "consumed_calories": 1100,
    "consumed_protein_grams": 60,
    "consumed_carbohydrates_grams": 120,
    "consumed_fat_grams": 28,
    "dietary_preferences": ["Vegetarian"],
    "target_meal_type": "Dinner",
    "budget_tier": "Budget Friendly",
    "available_ingredients": ["dal", "roti", "curd", "paneer"],
    "request_date": "2026-10-24"
  }' | python3 -m json.tool
```

## Running Automated Tests

Run the test suite from the project root:

```bash
backend/.venv/bin/python3 -m unittest backend.test_backend
```

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `GROQ_API_KEY` | **Yes** | — | Groq API secret key |
| `GROQ_MODEL` | No | `llama-3.1-8b-instant` | Groq model identifier |
| `GROQ_TIMEOUT_SECONDS` | No | `30.0` | Upstream request timeout in seconds |
| `PORT` | No | `8000` | Server bind port |
| `ALLOWED_ORIGINS` | No | — | Comma-separated CORS origins |

## iOS Configuration

In the FitBuddy iOS app, set the Xcode scheme environment variable:

```
FITBUDDY_BACKEND_BASE_URL = http://127.0.0.1:8000
```

`AppBackendConfig.currentBaseURL` will pick this up automatically.  
For production, use an HTTPS URL instead.

## Security Notes

- The `GROQ_API_KEY` is read **only** from the process environment or local `.env` — never from the iOS app, URL parameters, or request headers.
- `.env` is excluded from Git via `.gitignore`.
- HTTP is permitted only for `127.0.0.1` / `localhost`. Production deployments must use HTTPS (configure a reverse proxy).
- The iOS client connects to **this backend only** — it never calls Groq directly.
- Server logs omit personal user identifiers (such as user names and cycle symptoms) to preserve privacy.

## File Structure

```
backend/
├── main.py            # FastAPI app and route handlers
├── models.py          # Pydantic request/response models (mirrors API_CONTRACT.md)
├── groq_client.py     # Groq SDK wrapper with error handling and timeout
├── prompts.py         # Prompt builders for workout and nutrition
├── test_backend.py    # Comprehensive automated test suite
├── requirements.txt   # Pinned dependencies
├── .env.example       # Template — copy to .env and fill in your key
├── .gitignore         # Excludes .env and other secrets
└── README.md          # This file
```
