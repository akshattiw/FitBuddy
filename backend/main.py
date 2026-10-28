"""
main.py — FitBuddy FastAPI backend (v1).

Architecture:
  iOS SwiftUI App → POST /api/v1/workout/recommendations  ─┐
                  → POST /api/v1/nutrition/recommendations  ├→ Groq API
                  → GET  /api/v1/health (and /health)      ─┘

Security rules:
  - GROQ_API_KEY is read exclusively from environment variables or local .env.
  - This file contains zero API keys, tokens, or secrets.
  - HTTPS is required for production deployments (enforced via reverse proxy).
  - No user-identifiable personal data or API secrets are logged.
"""

from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from dotenv import load_dotenv
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

# Automatically load environment variables from .env if present
load_dotenv(override=True)

from .models import (
    WorkoutRecommendationRequest,
    WorkoutRecommendationResponse,
    WorkoutResponse,
    ExerciseResponse,
    NutritionRecommendationRequest,
    NutritionRecommendationResponse,
    FoodSuggestionResponse,
    FoodItemResponse,
    HealthResponse,
    ErrorResponse,
    NutritionDataSource,
    MealType,
    MuscleGroup,
    EquipmentType,
    FitnessDifficulty,
    WorkoutCategory,
    ServingUnit,
    FoodCategory,
)
from .groq_client import call_groq, current_model, GroqClientError, GroqParseError
from .prompts import (
    WORKOUT_SYSTEM_PROMPT,
    build_workout_user_message,
    NUTRITION_SYSTEM_PROMPT,
    build_nutrition_user_message,
)

# ─── Logging ──────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ─── App ──────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="FitBuddy AI Backend",
    description=(
        "Secure proxy between the FitBuddy iOS app and the Groq LLM API. "
        "The Groq API key never leaves this server."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ─── CORS ─────────────────────────────────────────────────────────────────────

_raw_origins = os.environ.get("ALLOWED_ORIGINS", "")
_allowed_origins = [o.strip() for o in _raw_origins.split(",") if o.strip()]

if _allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_allowed_origins,
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type"],
    )


# ─── Error Handlers ───────────────────────────────────────────────────────────

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """Format request validation errors to match the FitBuddy API contract error shape."""
    parts: list[str] = []
    for err in exc.errors():
        loc_parts = [str(l) for l in err.get("loc", []) if l != "body"]
        loc = " -> ".join(loc_parts)
        msg = err.get("msg", "invalid")
        parts.append(f"{loc}: {msg}" if loc else msg)
    summary = "; ".join(parts) if parts else "Invalid request body."
    logger.warning("Validation failure for %s %s: %s", request.method, request.url.path, summary)
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"error": f"Validation error: {summary}", "code": "validation_error"},
    )


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    """Format HTTP exceptions into contract error shape."""
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": str(exc.detail), "code": "http_error"},
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Catch-all for unhandled exceptions."""
    logger.exception("Unhandled error for %s %s: %s", request.method, request.url.path, exc)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"error": "An unexpected server error occurred.", "code": "internal_error"},
    )


# ─── Helpers & Defensive Coercions ───────────────────────────────────────────

def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def _ensure_uuid(value: str | None) -> str:
    """Return value if it looks like a valid UUID string, otherwise generate a fresh one."""
    if value and len(str(value).strip()) >= 32:
        return str(value).strip()
    return str(uuid4())


def _normalize_muscle(val: Any) -> str:
    s = str(val).strip()
    mapping = {
        "abs": "Core",
        "abdominals": "Core",
        "legs": "Quads",
        "leg": "Quads",
        "arms": "Biceps",
        "arm": "Biceps",
        "lats": "Back",
        "upper back": "Back",
        "lower back": "Back",
        "glute": "Glutes",
        "calf": "Calves",
        "hamstring": "Hamstrings",
        "quad": "Quads",
        "shoulder": "Shoulders",
    }
    lowered = s.lower()
    if lowered in mapping:
        return mapping[lowered]
    for mg in MuscleGroup:
        if mg.value.lower() == lowered:
            return mg.value
    return "Full Body"


def _normalize_equipment(val: Any) -> str:
    s = str(val).strip()
    lowered = s.lower()
    mapping = {
        "none": "None (Bodyweight)",
        "bodyweight": "None (Bodyweight)",
        "body weight": "None (Bodyweight)",
        "none (bodyweight)": "None (Bodyweight)",
        "dumbbell": "Dumbbells",
        "dumbbells": "Dumbbells",
        "band": "Resistance Bands",
        "bands": "Resistance Bands",
        "resistance band": "Resistance Bands",
        "resistance bands": "Resistance Bands",
        "mat": "Yoga Mat",
        "yoga mat": "Yoga Mat",
        "kettlebell": "Kettlebell",
        "kettlebells": "Kettlebell",
        "pull up bar": "Pull-up Bar",
        "pull-up bar": "Pull-up Bar",
        "pullup bar": "Pull-up Bar",
        "foam roller": "Foam Roller",
    }
    return mapping.get(lowered, "None (Bodyweight)")


def _normalize_difficulty(val: Any) -> str:
    s = str(val).strip().capitalize()
    if s in ("Beginner", "Intermediate", "Advanced"):
        return s
    return "Beginner"


def _normalize_workout_category(val: Any) -> str:
    s = str(val).strip()
    for cat in WorkoutCategory:
        if cat.value.lower() == s.lower():
            return cat.value
    return "Stretch & Mobility"


def _normalize_serving_unit(val: Any) -> str:
    s = str(val).strip().lower()
    mapping = {
        "g": "g",
        "gm": "g",
        "gms": "g",
        "gram": "g",
        "grams": "g",
        "ml": "ml",
        "milliliter": "ml",
        "milliliters": "ml",
        "piece": "piece",
        "pieces": "piece",
        "pc": "piece",
        "pcs": "piece",
        "cup": "cup",
        "cups": "cup",
        "tbsp": "tbsp",
        "tablespoon": "tbsp",
        "tablespoons": "tbsp",
        "tsp": "tsp",
        "teaspoon": "tsp",
        "teaspoons": "tsp",
        "oz": "oz",
        "ounce": "oz",
        "ounces": "oz",
    }
    return mapping.get(s, "g")


def _normalize_food_category(val: Any) -> str | None:
    if not val:
        return None
    s = str(val).strip().lower()
    mapping = {
        "fruits": "Fruits",
        "fruit": "Fruits",
        "vegetables": "Vegetables",
        "vegetable": "Vegetables",
        "veggies": "Vegetables",
        "meat": "Meat & Poultry",
        "poultry": "Meat & Poultry",
        "chicken": "Meat & Poultry",
        "meat & poultry": "Meat & Poultry",
        "seafood": "Seafood",
        "fish": "Seafood",
        "grains": "Grains & Pasta",
        "grain": "Grains & Pasta",
        "pasta": "Grains & Pasta",
        "rice": "Grains & Pasta",
        "grains & pasta": "Grains & Pasta",
        "dairy": "Dairy & Eggs",
        "eggs": "Dairy & Eggs",
        "egg": "Dairy & Eggs",
        "dairy & eggs": "Dairy & Eggs",
        "nuts": "Nuts & Legumes",
        "legumes": "Nuts & Legumes",
        "lentils": "Nuts & Legumes",
        "dal": "Nuts & Legumes",
        "pulses": "Nuts & Legumes",
        "nuts & legumes": "Nuts & Legumes",
        "beverages": "Beverages",
        "drink": "Beverages",
        "drinks": "Beverages",
        "snacks": "Snacks",
        "snack": "Snacks",
        "prepared meals": "Prepared Meals",
        "meal": "Prepared Meals",
        "prepared": "Prepared Meals",
    }
    return mapping.get(s, None)


def _parse_workout_response(raw: dict) -> list[WorkoutResponse]:
    """
    Convert raw LLM JSON dict into validated WorkoutResponse objects.
    Applies defensive coercions so minor LLM deviations don't crash the endpoint.
    """
    workouts_raw = raw.get("workouts", [])
    if not isinstance(workouts_raw, list):
        workouts_raw = []

    results: list[WorkoutResponse] = []
    for w in workouts_raw:
        if not isinstance(w, dict):
            continue
        exercises_raw = w.get("exercises", [])
        if not isinstance(exercises_raw, list):
            exercises_raw = []

        exercises: list[ExerciseResponse] = []
        for ex in exercises_raw:
            if not isinstance(ex, dict):
                continue
            try:
                # Target muscles normalization
                raw_muscles = ex.get("target_muscles", ["Full Body"])
                if isinstance(raw_muscles, str):
                    raw_muscles = [raw_muscles]
                muscles = [_normalize_muscle(m) for m in raw_muscles] or ["Full Body"]

                # Instructions normalization
                raw_inst = ex.get("instructions", [])
                if isinstance(raw_inst, str):
                    instructions = [raw_inst]
                elif isinstance(raw_inst, list):
                    instructions = [str(step) for step in raw_inst if str(step).strip()]
                else:
                    instructions = []
                if not instructions:
                    instructions = ["Perform exercise with controlled technique."]

                exercises.append(
                    ExerciseResponse(
                        id=_ensure_uuid(ex.get("id")),
                        name=str(ex.get("name", "Exercise")).strip() or "Exercise",
                        description=str(ex.get("description", "")).strip(),
                        target_muscles=muscles,
                        equipment=_normalize_equipment(ex.get("equipment")),
                        difficulty=_normalize_difficulty(ex.get("difficulty")),
                        instructions=instructions,
                        sets=int(ex["sets"]) if ex.get("sets") is not None else None,
                        repetitions=int(ex["repetitions"]) if ex.get("repetitions") is not None else None,
                        duration_seconds=float(ex["duration_seconds"]) if ex.get("duration_seconds") is not None else None,
                        rest_interval_seconds=float(ex["rest_interval_seconds"]) if ex.get("rest_interval_seconds") is not None else None,
                        form_notes=str(ex.get("form_notes")).strip() if ex.get("form_notes") else None,
                    )
                )
            except Exception as exc:
                logger.warning("Skipping malformed exercise: %s — %s", ex.get("name"), exc)

        try:
            req_eq_raw = w.get("required_equipment", ["None (Bodyweight)"])
            if isinstance(req_eq_raw, str):
                req_eq_raw = [req_eq_raw]
            eq_list = [_normalize_equipment(e) for e in req_eq_raw] or ["None (Bodyweight)"]

            duration = float(w.get("estimated_duration_seconds", 900))
            calories = int(w.get("estimated_calories", 0))
            if calories <= 0:
                # Reasonable approximation if LLM omitted: ~5-7 kcal per minute
                calories = max(30, int((duration / 60.0) * 6.0))

            results.append(
                WorkoutResponse(
                    id=_ensure_uuid(w.get("id")),
                    name=str(w.get("name", "Workout")).strip() or "Workout",
                    description=str(w.get("description", "")).strip(),
                    category=_normalize_workout_category(w.get("category")),
                    difficulty=_normalize_difficulty(w.get("difficulty")),
                    estimated_duration_seconds=duration,
                    estimated_calories=calories,
                    required_equipment=eq_list,
                    ai_recommendation_rationale=str(w.get("ai_recommendation_rationale", "")).strip() or None,
                    exercises=exercises,
                )
            )
        except Exception as exc:
            logger.warning("Skipping malformed workout: %s — %s", w.get("name"), exc)

    return results


def _parse_nutrition_response(raw: dict, meal_type: MealType) -> list[FoodSuggestionResponse]:
    """
    Convert raw LLM JSON dict into validated FoodSuggestionResponse objects.
    Applies defensive coercions so minor LLM deviations don't crash the endpoint.
    """
    suggestions_raw = raw.get("suggestions", [])
    if not isinstance(suggestions_raw, list):
        suggestions_raw = []

    results: list[FoodSuggestionResponse] = []
    for s in suggestions_raw:
        if not isinstance(s, dict):
            continue
        fi = s.get("food_item", {})
        if not isinstance(fi, dict):
            continue
        try:
            qty = float(s.get("suggested_quantity", 1.0))
            if qty <= 0:
                qty = 1.0

            calories = float(fi.get("calories", 0))
            protein = float(fi.get("protein_grams", 0))
            carbs = float(fi.get("carbohydrates_grams", 0))
            fat = float(fi.get("fat_grams", 0))

            raw_fibre = fi.get("fibre_grams")
            fibre = float(raw_fibre) if raw_fibre is not None else None

            food_item = FoodItemResponse(
                id=_ensure_uuid(fi.get("id")),
                name=str(fi.get("name", "Food")).strip() or "Food",
                item_description=str(fi.get("item_description")).strip() if fi.get("item_description") else None,
                serving_size=float(fi.get("serving_size", 100)),
                serving_unit=_normalize_serving_unit(fi.get("serving_unit")),
                calories=calories,
                protein_grams=protein,
                carbohydrates_grams=carbs,
                fat_grams=fat,
                fibre_grams=fibre,
                category=_normalize_food_category(fi.get("category")),
                data_source=NutritionDataSource.ai_estimated,
                icon_symbol=str(fi.get("icon_symbol")).strip() if fi.get("icon_symbol") else None,
            )

            # Accept meal type if valid, otherwise fallback to request target meal
            s_meal = s.get("target_meal_type")
            target_meal = meal_type
            if s_meal:
                for m in MealType:
                    if m.value.lower() == str(s_meal).strip().lower():
                        target_meal = m
                        break

            results.append(
                FoodSuggestionResponse(
                    id=_ensure_uuid(s.get("id")),
                    food_item=food_item,
                    suggested_quantity=qty,
                    target_meal_type=target_meal,
                    estimated_calories=round(calories * qty, 1),
                    estimated_protein_grams=round(protein * qty, 1),
                    estimated_carbohydrates_grams=round(carbs * qty, 1),
                    estimated_fat_grams=round(fat * qty, 1),
                    recommendation_rationale=str(s.get("recommendation_rationale", "")).strip() or "Fits target meal and nutritional profile.",
                )
            )
        except Exception as exc:
            logger.warning("Skipping malformed suggestion: %s — %s", fi.get("name"), exc)

    return results


# ─── Routes ───────────────────────────────────────────────────────────────────

@app.get(
    "/health",
    response_model=HealthResponse,
    summary="Lightweight health check",
    tags=["Health"],
)
@app.get(
    "/api/v1/health",
    response_model=HealthResponse,
    summary="Health check (API v1)",
    tags=["Health"],
)
async def health_check() -> HealthResponse:
    """Returns backend operational status and the active Groq model."""
    return HealthResponse(
        status="ok",
        version="1.0.0",
        groq_model=current_model(),
    )


@app.post(
    "/api/v1/workout/recommendations",
    response_model=WorkoutRecommendationResponse,
    summary="Generate personalised workout recommendations",
    tags=["Workout"],
    responses={
        422: {"model": ErrorResponse, "description": "Validation error in request body"},
        500: {"model": ErrorResponse, "description": "Groq API or parse error"},
        503: {"model": ErrorResponse, "description": "Groq model overloaded"},
    },
)
async def workout_recommendations(req: WorkoutRecommendationRequest) -> JSONResponse:
    """
    Generates personalised workout routines based on user context.
    Mood, equipment, cycle phase, and fitness goal all influence suggestions.
    """
    logger.info(
        "Workout recommendation request: goal=%s mood=%s equipment_count=%d duration_sec=%d",
        req.fitness_goal.value,
        req.daily_mood.value if req.daily_mood else "None",
        len(req.available_equipment),
        int(req.available_time_seconds),
    )

    max_tokens = int(os.environ.get("GROQ_MAX_TOKENS", "1000"))
    try:
        raw = call_groq(
            system_prompt=WORKOUT_SYSTEM_PROMPT,
            user_message=build_workout_user_message(req),
            max_tokens=max_tokens,
            temperature=0.75,
        )
    except GroqClientError as exc:
        http_status = 503 if exc.code == "model_overloaded" else 500
        return JSONResponse(
            status_code=http_status,
            content={"error": str(exc), "code": exc.code},
        )
    except GroqParseError as exc:
        logger.error("Parse error from LLM response: %s", exc)
        return JSONResponse(
            status_code=500,
            content={"error": str(exc), "code": exc.code},
        )

    workouts = _parse_workout_response(raw)
    if not workouts:
        logger.warning("LLM returned 0 parseable workouts")

    response = WorkoutRecommendationResponse(
        workouts=workouts,
        model_used=current_model(),
        generated_at=_now_iso(),
    )
    return JSONResponse(content=response.model_dump())


@app.post(
    "/api/v1/nutrition/recommendations",
    response_model=NutritionRecommendationResponse,
    summary="Generate personalised food suggestions",
    tags=["Nutrition"],
    responses={
        422: {"model": ErrorResponse, "description": "Validation error in request body"},
        500: {"model": ErrorResponse, "description": "Groq API or parse error"},
        503: {"model": ErrorResponse, "description": "Groq model overloaded"},
    },
)
async def nutrition_recommendations(req: NutritionRecommendationRequest) -> JSONResponse:
    """
    Generates food suggestions based on remaining macro budget and dietary preferences.
    Cycle data is never included in nutrition requests.
    """
    logger.info(
        "Nutrition recommendation request: goal=%s meal=%s remaining_cal=%.0f budget=%s",
        req.fitness_goal.value,
        req.target_meal_type.value,
        req.remaining_calories or 0,
        req.budget_tier.value,
    )

    max_tokens = int(os.environ.get("GROQ_MAX_TOKENS", "1000"))
    try:
        raw = call_groq(
            system_prompt=NUTRITION_SYSTEM_PROMPT,
            user_message=build_nutrition_user_message(req),
            max_tokens=max_tokens,
            temperature=0.65,
        )
    except GroqClientError as exc:
        http_status = 503 if exc.code == "model_overloaded" else 500
        return JSONResponse(
            status_code=http_status,
            content={"error": str(exc), "code": exc.code},
        )
    except GroqParseError as exc:
        logger.error("Parse error from LLM response: %s", exc)
        return JSONResponse(
            status_code=500,
            content={"error": str(exc), "code": exc.code},
        )

    suggestions = _parse_nutrition_response(raw, req.target_meal_type)
    if not suggestions:
        logger.warning("LLM returned 0 parseable suggestions")

    response = NutritionRecommendationResponse(
        suggestions=suggestions,
        model_used=current_model(),
        generated_at=_now_iso(),
    )
    return JSONResponse(content=response.model_dump())
