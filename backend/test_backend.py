"""
test_backend.py — Comprehensive automated test suite for FitBuddy FastAPI backend.

Tests run offline without needing a real Groq API key:
- Health check endpoints (/health and /api/v1/health)
- Validation failure shapes (HTTP 422 with {error, code: "validation_error"})
- Missing API key error handling (HTTP 500 with {code: "missing_api_key"})
- Mocked upstream Groq LLM responses for workout recommendations (HTTP 200)
- Mocked upstream Groq LLM responses for nutrition recommendations (HTTP 200)
- Defensive parsing & normalization of LLM minor variations
- Error mapping (rate limit -> 503, timeout -> 500, parse failure -> 500)
"""

import os
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

# Ensure GROQ_API_KEY is not set by default during unit tests
os.environ.pop("GROQ_API_KEY", None)

from backend.main import app
from backend.groq_client import GroqClientError, GroqParseError, reset_client


class TestFitBuddyBackend(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)
        reset_client()

    def tearDown(self):
        reset_client()

    # ─── 1. Health Check Tests ────────────────────────────────────────────────

    def test_health_check_lightweight(self):
        res = self.client.get("/health")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["status"], "ok")
        self.assertEqual(data["version"], "1.0.0")
        self.assertIn("groq_model", data)

    def test_health_check_v1(self):
        res = self.client.get("/api/v1/health")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["status"], "ok")
        self.assertEqual(data["version"], "1.0.0")
        self.assertIn("groq_model", data)

    # ─── 2. Validation & Error Shape Tests ────────────────────────────────────

    def test_workout_validation_empty_body(self):
        res = self.client.post("/api/v1/workout/recommendations", json={})
        self.assertEqual(res.status_code, 422)
        data = res.json()
        self.assertIn("error", data)
        self.assertEqual(data["code"], "validation_error")
        self.assertIn("Validation error:", data["error"])

    def test_workout_validation_invalid_duration(self):
        res = self.client.post(
            "/api/v1/workout/recommendations",
            json={
                "user_name": "Priya",
                "fitness_goal": "General Fitness",
                "available_equipment": ["Yoga Mat"],
                "available_time_seconds": 120,  # Minimum allowed is 300
            },
        )
        self.assertEqual(res.status_code, 422)
        data = res.json()
        self.assertEqual(data["code"], "validation_error")

    def test_nutrition_validation_empty_body(self):
        res = self.client.post("/api/v1/nutrition/recommendations", json={})
        self.assertEqual(res.status_code, 422)
        data = res.json()
        self.assertIn("error", data)
        self.assertEqual(data["code"], "validation_error")

    def test_nutrition_validation_invalid_calories(self):
        res = self.client.post(
            "/api/v1/nutrition/recommendations",
            json={
                "user_name": "Priya",
                "fitness_goal": "Weight Loss",
                "daily_calorie_target": -100,  # Must be > 0
                "daily_protein_target_grams": 100,
                "daily_carbohydrates_target_grams": 150,
                "daily_fat_target_grams": 50,
                "target_meal_type": "Dinner",
                "request_date": "2026-10-24",
            },
        )
        self.assertEqual(res.status_code, 422)
        data = res.json()
        self.assertEqual(data["code"], "validation_error")

    # ─── 3. Missing API Key Tests ─────────────────────────────────────────────

    def test_workout_missing_api_key(self):
        with patch.dict(os.environ, {}, clear=True):
            reset_client()
            payload = {
                "user_name": "Priya",
                "fitness_goal": "General Fitness",
                "available_equipment": ["None (Bodyweight)"],
                "available_time_seconds": 900,
            }
            res = self.client.post("/api/v1/workout/recommendations", json=payload)
            self.assertEqual(res.status_code, 500)
            data = res.json()
            self.assertEqual(data["code"], "missing_api_key")
            self.assertIn("GROQ_API_KEY environment variable is not set", data["error"])

    def test_nutrition_missing_api_key(self):
        with patch.dict(os.environ, {}, clear=True):
            reset_client()
            payload = {
                "user_name": "Priya",
                "fitness_goal": "Weight Loss",
                "daily_calorie_target": 2000,
                "daily_protein_target_grams": 140,
                "daily_carbohydrates_target_grams": 200,
                "daily_fat_target_grams": 65,
                "target_meal_type": "Dinner",
                "request_date": "2026-10-24",
            }
            res = self.client.post("/api/v1/nutrition/recommendations", json=payload)
            self.assertEqual(res.status_code, 500)
            data = res.json()
            self.assertEqual(data["code"], "missing_api_key")

    # ─── 4. Mocked LLM Success Tests ──────────────────────────────────────────

    @patch("backend.main.call_groq")
    def test_workout_recommendations_mocked_success(self, mock_call_groq):
        mock_call_groq.return_value = {
            "workouts": [
                {
                    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                    "name": "Morning Energy Flow",
                    "description": "Dynamic flow matching energised mood.",
                    "category": "Stretch & Mobility",
                    "difficulty": "Beginner",
                    "estimated_duration_seconds": 900,
                    "estimated_calories": 110,
                    "required_equipment": ["None (Bodyweight)", "Yoga Mat"],
                    "ai_recommendation_rationale": "Suited to Energized mood.",
                    "exercises": [
                        {
                            "id": "b1a2c3d4-e5f6-7890-abcd-ef1234567890",
                            "name": "Sun Salutation",
                            "description": "Flowing warm-up sequence.",
                            "target_muscles": ["Full Body", "Core"],
                            "equipment": "Yoga Mat",
                            "difficulty": "Beginner",
                            "instructions": [
                                "Stand at top of mat.",
                                "Inhale arms up, fold forward.",
                            ],
                            "sets": None,
                            "repetitions": None,
                            "duration_seconds": 120,
                            "rest_interval_seconds": 15,
                            "form_notes": "Keep spine long.",
                        }
                    ],
                }
            ]
        }

        payload = {
            "user_name": "Priya",
            "gender": "Female",
            "fitness_goal": "General Fitness",
            "daily_mood": "Energized ⚡️",
            "available_equipment": ["None (Bodyweight)", "Yoga Mat"],
            "available_time_seconds": 1500,
            "recent_completed_workouts": ["Morning Yoga Flow"],
            "cycle_phase": "Follicular Phase",
            "cycle_symptoms": ["Fatigue"],
        }
        res = self.client.post("/api/v1/workout/recommendations", json=payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("workouts", data)
        self.assertEqual(len(data["workouts"]), 1)
        workout = data["workouts"][0]
        self.assertEqual(workout["name"], "Morning Energy Flow")
        self.assertEqual(workout["category"], "Stretch & Mobility")
        self.assertEqual(workout["difficulty"], "Beginner")
        self.assertEqual(len(workout["exercises"]), 1)
        ex = workout["exercises"][0]
        self.assertEqual(ex["name"], "Sun Salutation")
        self.assertEqual(ex["target_muscles"], ["Full Body", "Core"])
        self.assertEqual(ex["equipment"], "Yoga Mat")
        self.assertIn("model_used", data)
        self.assertIn("generated_at", data)

    @patch("backend.main.call_groq")
    def test_nutrition_recommendations_mocked_success(self, mock_call_groq):
        mock_call_groq.return_value = {
            "suggestions": [
                {
                    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                    "food_item": {
                        "id": "f1a2b3c4-d5e6-7890-abcd-ef0987654321",
                        "name": "Masoor Dal",
                        "item_description": "Home-cooked red lentil curry",
                        "serving_size": 200.0,
                        "serving_unit": "g",
                        "calories": 198.0,
                        "protein_grams": 13.0,
                        "carbohydrates_grams": 30.0,
                        "fat_grams": 3.0,
                        "fibre_grams": 8.0,
                        "category": "Nuts & Legumes",
                        "data_source": "AI Estimated",
                        "icon_symbol": "🍲",
                    },
                    "suggested_quantity": 1.5,
                    "target_meal_type": "Dinner",
                    "estimated_calories": 297.0,
                    "estimated_protein_grams": 19.5,
                    "estimated_carbohydrates_grams": 45.0,
                    "estimated_fat_grams": 4.5,
                    "recommendation_rationale": "High protein, budget friendly dinner.",
                }
            ]
        }

        payload = {
            "user_name": "Priya",
            "gender": "Female",
            "fitness_goal": "Weight Loss",
            "daily_calorie_target": 2000.0,
            "daily_protein_target_grams": 140.0,
            "daily_carbohydrates_target_grams": 200.0,
            "daily_fat_target_grams": 65.0,
            "consumed_calories": 1200.0,
            "consumed_protein_grams": 65.0,
            "consumed_carbohydrates_grams": 130.0,
            "consumed_fat_grams": 30.0,
            "dietary_preferences": ["Vegetarian"],
            "target_meal_type": "Dinner",
            "budget_tier": "Budget Friendly",
            "available_ingredients": ["dal", "roti", "curd"],
            "request_date": "2026-10-24",
        }
        res = self.client.post("/api/v1/nutrition/recommendations", json=payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("suggestions", data)
        self.assertEqual(len(data["suggestions"]), 1)
        sug = data["suggestions"][0]
        self.assertEqual(sug["food_item"]["name"], "Masoor Dal")
        self.assertEqual(sug["food_item"]["data_source"], "AI Estimated")
        self.assertEqual(sug["food_item"]["serving_unit"], "g")
        self.assertEqual(sug["suggested_quantity"], 1.5)
        self.assertEqual(sug["estimated_calories"], 297.0)
        self.assertEqual(sug["estimated_protein_grams"], 19.5)

    # ─── 5. Defensive Parsing & Normalization Tests ───────────────────────────

    @patch("backend.main.call_groq")
    def test_defensive_workout_coercion(self, mock_call_groq):
        # LLM returns variations: "Abs" for muscle, "Bodyweight" for equipment,
        # string for instructions, omitted calories
        mock_call_groq.return_value = {
            "workouts": [
                {
                    "name": "Core Blast",
                    "description": "Short core burner.",
                    "category": "Stretch & Mobility",
                    "difficulty": "beginner",  # Lowercase
                    "estimated_duration_seconds": 600,
                    "estimated_calories": 0,  # Zero -> should approximate
                    "required_equipment": "Bodyweight",  # String instead of list
                    "exercises": [
                        {
                            "name": "Plank",
                            "target_muscles": ["Abs"],  # "Abs" -> "Core"
                            "equipment": "Bodyweight",  # "Bodyweight" -> "None (Bodyweight)"
                            "difficulty": "beginner",
                            "instructions": "Hold a steady plank position.",  # String instead of list
                            "duration_seconds": 60,
                        }
                    ],
                }
            ]
        }

        payload = {
            "user_name": "Priya",
            "fitness_goal": "Build Strength",
            "available_equipment": ["None (Bodyweight)"],
            "available_time_seconds": 600,
        }
        res = self.client.post("/api/v1/workout/recommendations", json=payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        workout = data["workouts"][0]
        self.assertEqual(workout["difficulty"], "Beginner")
        self.assertGreater(workout["estimated_calories"], 0)
        self.assertEqual(workout["required_equipment"], ["None (Bodyweight)"])
        ex = workout["exercises"][0]
        self.assertEqual(ex["target_muscles"], ["Core"])
        self.assertEqual(ex["equipment"], "None (Bodyweight)")
        self.assertEqual(ex["difficulty"], "Beginner")
        self.assertIsInstance(ex["instructions"], list)

    # ─── 6. Upstream Error Handling Tests ────────────────────────────────────

    @patch("backend.main.call_groq")
    def test_groq_rate_limit_mapping(self, mock_call_groq):
        mock_call_groq.side_effect = GroqClientError(
            "Rate limit reached for requests per minute", code="model_overloaded"
        )
        payload = {
            "user_name": "Priya",
            "fitness_goal": "General Fitness",
            "available_equipment": ["None (Bodyweight)"],
            "available_time_seconds": 900,
        }
        res = self.client.post("/api/v1/workout/recommendations", json=payload)
        self.assertEqual(res.status_code, 503)
        data = res.json()
        self.assertEqual(data["code"], "model_overloaded")

    @patch("backend.main.call_groq")
    def test_groq_timeout_mapping(self, mock_call_groq):
        mock_call_groq.side_effect = GroqClientError(
            "Groq request timed out.", code="groq_api_error"
        )
        payload = {
            "user_name": "Priya",
            "fitness_goal": "General Fitness",
            "available_equipment": ["None (Bodyweight)"],
            "available_time_seconds": 900,
        }
        res = self.client.post("/api/v1/workout/recommendations", json=payload)
        self.assertEqual(res.status_code, 500)
        data = res.json()
        self.assertEqual(data["code"], "groq_api_error")

    @patch("backend.main.call_groq")
    def test_groq_parse_error_mapping(self, mock_call_groq):
        mock_call_groq.side_effect = GroqParseError("LLM returned non-JSON content", raw="bad")
        payload = {
            "user_name": "Priya",
            "fitness_goal": "General Fitness",
            "available_equipment": ["None (Bodyweight)"],
            "available_time_seconds": 900,
        }
        res = self.client.post("/api/v1/workout/recommendations", json=payload)
        self.assertEqual(res.status_code, 500)
        data = res.json()
        self.assertEqual(data["code"], "parse_error")


if __name__ == "__main__":
    unittest.main()
