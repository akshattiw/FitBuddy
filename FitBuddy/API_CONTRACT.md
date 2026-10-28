# FitBuddy — Backend API Contract (v1)

**Version:** 1.0  
**Base URL (development):** `http://127.0.0.1:8000`  
**Base URL (production):** `https://<your-domain>` *(HTTPS required — configured via `FITBUDDY_BACKEND_BASE_URL`)*  
**Content-Type:** `application/json` for all request and response bodies  
**Authentication:** None in v1 (anonymous local device → backend). Add bearer token / device ID in v2 when required.

---

> [!IMPORTANT]
> The Groq API key must **never** exist in the iOS app bundle, Swift source files, or any Git-tracked configuration. It lives exclusively in the Python backend's environment variable `GROQ_API_KEY`. The iOS client only communicates with our FastAPI backend.

---

## Architecture

```
iOS SwiftUI App
     │
     │  POST /api/v1/workout/recommendations
     │  POST /api/v1/nutrition/recommendations
     ▼
FitBuddy FastAPI Backend  (Python)
     │
     │  Groq Chat Completions API
     ▼
Groq Cloud  (LLM inference)
```

---

## General Conventions

| Property | Value |
|---|---|
| Protocol | HTTPS in production; HTTP permitted for `127.0.0.1` / `localhost` only |
| Request format | JSON body |
| Response format | JSON body |
| Character encoding | UTF-8 |
| Timeout (recommended client) | 30 seconds |
| Error shape | `{ "error": "<message>", "code": "<machine_code>" }` |
| Success HTTP status | `200 OK` |
| Validation failure | `422 Unprocessable Entity` |
| Server error | `500 Internal Server Error` |

---

## Endpoint 1 — Workout Recommendations

### `POST /api/v1/workout/recommendations`

Generates personalised workout routine suggestions based on user context, available equipment, mood, and optional cycle data.

---

### Request Body

```json
{
  "user_name": "Priya",
  "gender": "Female",
  "fitness_goal": "General Fitness",
  "daily_mood": "Energized ⚡️",
  "available_equipment": ["None (Bodyweight)", "Yoga Mat"],
  "available_time_seconds": 1500,
  "recent_completed_workouts": ["Morning Yoga Flow", "Full Body Strength"],
  "cycle_phase": "Follicular Phase",
  "cycle_symptoms": ["Fatigue", "Cramps"]
}
```

#### Request Field Definitions

| Field | Type | Required | Source in App | Validation |
|---|---|---|---|---|
| `user_name` | `string` | Yes | `UserProfile.name` | 1–100 characters |
| `gender` | `string` | No | `UserProfile.gender?.rawValue` | One of: `"Female"`, `"Male"`, `"Other"`, `"Prefer not to say"` |
| `fitness_goal` | `string` | Yes | `FitnessGoal.rawValue` | One of: `"General Fitness"`, `"Build Strength"`, `"Improve Mobility"`, `"Stress Relief"`, `"Weight Loss"` |
| `daily_mood` | `string \| null` | No | `DailyMood.rawValue` | One of: `"Energized ⚡️"`, `"Feeling... 😊"`, `"Relaxed 😌"`, `"Tired 😴"`, or `null` |
| `available_equipment` | `string[]` | Yes | `EquipmentType.rawValue` array | Non-empty; values from equipment enum |
| `available_time_seconds` | `number` | Yes | `WorkoutRecommendationInput.availableTimeSeconds` | 300–7200 (5 min to 2 hr) |
| `recent_completed_workouts` | `string[]` | No | `WorkoutRecord.workoutName` (last 7 days) | Max 10 entries; each ≤ 100 chars |
| `cycle_phase` | `string \| null` | No | `CyclePhase.rawValue` (only when `allowWorkoutAdaptation == true`) | One of: `"Menstrual Phase"`, `"Follicular Phase"`, `"Ovulatory Phase"`, `"Luteal Phase"`, or `null` |
| `cycle_symptoms` | `string[]` | No | `CycleSymptomType.rawValue` array (only when `allowWorkoutAdaptation == true`) | Max 10 entries |

> **Privacy rule:** `cycle_phase` and `cycle_symptoms` must only be included when `CycleData.isTrackingEnabled == true` **and** `CycleData.allowWorkoutAdaptation == true` **and** `UserProfile.gender?.enablesCycleTracking == true`. This is enforced by `WorkoutRecommendationInput`'s initialiser guard.

---

### Response Body

```json
{
  "workouts": [
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "name": "Morning Energy Flow",
      "description": "A dynamic bodyweight session to match your energised mood.",
      "category": "Stretch & Mobility",
      "difficulty": "Beginner",
      "estimated_duration_seconds": 900,
      "estimated_calories": 110,
      "required_equipment": ["None (Bodyweight)", "Yoga Mat"],
      "ai_recommendation_rationale": "Matched to Energized mood and Follicular phase for optimal performance.",
      "exercises": [
        {
          "id": "b1a2c3d4-e5f6-7890-abcd-ef1234567890",
          "name": "Sun Salutation",
          "description": "Full-body flowing warm-up sequence.",
          "target_muscles": ["Full Body", "Core"],
          "equipment": "Yoga Mat",
          "difficulty": "Beginner",
          "instructions": [
            "Stand at top of mat with feet together.",
            "Inhale arms overhead, exhale fold forward."
          ],
          "sets": null,
          "repetitions": null,
          "duration_seconds": 120,
          "rest_interval_seconds": 15,
          "form_notes": "Keep your spine long throughout."
        }
      ]
    }
  ],
  "model_used": "llama3-8b-8192",
  "generated_at": "2026-10-24T03:00:00Z"
}
```

#### Response Field Definitions — Workout

| Field | Type | Maps to Swift model | Notes |
|---|---|---|---|
| `workouts` | `Workout[]` | `[Workout]` | Array; may be empty if no suitable match |
| `workouts[].id` | `string (UUID)` | `Workout.id` | Backend-generated stable UUID |
| `workouts[].name` | `string` | `Workout.name` | 1–120 chars |
| `workouts[].description` | `string` | `Workout.description` | |
| `workouts[].category` | `string` | `WorkoutCategory.rawValue` | One of category enum values |
| `workouts[].difficulty` | `string` | `FitnessDifficulty.rawValue` | `"Beginner"`, `"Intermediate"`, `"Advanced"` |
| `workouts[].estimated_duration_seconds` | `number` | `Workout.estimatedDurationSeconds` | Positive integer |
| `workouts[].estimated_calories` | `integer` | `Workout.estimatedCalories` | Clearly an estimate |
| `workouts[].required_equipment` | `string[]` | `Workout.requiredEquipment` | `EquipmentType.rawValue` values |
| `workouts[].ai_recommendation_rationale` | `string \| null` | `Workout.aiRecommendationRationale` | Human-readable explanation |
| `workouts[].exercises` | `Exercise[]` | `Workout.exercises` | |
| `exercises[].id` | `string (UUID)` | `Exercise.id` | |
| `exercises[].name` | `string` | `Exercise.name` | |
| `exercises[].description` | `string` | `Exercise.description` | |
| `exercises[].target_muscles` | `string[]` | `Exercise.targetMuscles` | `MuscleGroup.rawValue` values |
| `exercises[].equipment` | `string` | `Exercise.equipment` | `EquipmentType.rawValue` |
| `exercises[].difficulty` | `string` | `Exercise.difficulty` | |
| `exercises[].instructions` | `string[]` | `Exercise.instructions` | Ordered steps |
| `exercises[].sets` | `integer \| null` | `Exercise.sets` | |
| `exercises[].repetitions` | `integer \| null` | `Exercise.repetitions` | |
| `exercises[].duration_seconds` | `number \| null` | `Exercise.durationSeconds` | |
| `exercises[].rest_interval_seconds` | `number \| null` | `Exercise.restIntervalSeconds` | |
| `exercises[].form_notes` | `string \| null` | `Exercise.formNotes` | |
| `model_used` | `string` | — (metadata, not stored) | Groq model identifier |
| `generated_at` | `string (ISO 8601)` | — (metadata) | UTC timestamp |

---

## Endpoint 2 — Nutrition Recommendations

### `POST /api/v1/nutrition/recommendations`

Generates personalised food suggestions based on remaining daily macro targets, dietary preferences, meal type, and user context.

---

### Request Body

```json
{
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
  "remaining_calories": 800.0,
  "remaining_protein_grams": 75.0,
  "remaining_carbohydrates_grams": 70.0,
  "remaining_fat_grams": 35.0,
  "dietary_preferences": ["Vegetarian"],
  "target_meal_type": "Dinner",
  "budget_tier": "Budget Friendly",
  "available_ingredients": ["dal", "roti", "curd"],
  "request_date": "2026-10-24"
}
```

#### Request Field Definitions

| Field | Type | Required | Source in App | Validation |
|---|---|---|---|---|
| `user_name` | `string` | Yes | `UserProfile.name` | 1–100 characters |
| `gender` | `string` | No | `UserProfile.gender?.rawValue` | One of gender enum values or omitted |
| `fitness_goal` | `string` | Yes | `FitnessGoal.rawValue` | One of fitness goal enum values |
| `daily_calorie_target` | `number` | Yes | `NutritionTargets.dailyCalorieTarget` | > 0 |
| `daily_protein_target_grams` | `number` | Yes | `NutritionTargets.proteinGramsTarget` | ≥ 0 |
| `daily_carbohydrates_target_grams` | `number` | Yes | `NutritionTargets.carbohydratesGramsTarget` | ≥ 0 |
| `daily_fat_target_grams` | `number` | Yes | `NutritionTargets.fatGramsTarget` | ≥ 0 |
| `consumed_calories` | `number` | No | `NutritionSummary.consumedCalories` | ≥ 0 |
| `consumed_protein_grams` | `number` | No | `NutritionSummary.consumedProteinGrams` | ≥ 0 |
| `consumed_carbohydrates_grams` | `number` | No | `NutritionSummary.consumedCarbohydratesGrams` | ≥ 0 |
| `consumed_fat_grams` | `number` | No | `NutritionSummary.consumedFatGrams` | ≥ 0 |
| `remaining_calories` | `number` | No | `NutritionSummary.remainingCalories` | ≥ 0 |
| `remaining_protein_grams` | `number` | No | `NutritionSummary.remainingProteinGrams` | ≥ 0 |
| `remaining_carbohydrates_grams` | `number` | No | `NutritionSummary.remainingCarbohydratesGrams` | ≥ 0 |
| `remaining_fat_grams` | `number` | No | `NutritionSummary.remainingFatGrams` | ≥ 0 |
| `dietary_preferences` | `string[]` | No | `DietaryPreference.rawValue` array | Values from `DietaryPreference` enum |
| `target_meal_type` | `string` | Yes | `MealType.rawValue` | One of: `"Breakfast"`, `"Lunch"`, `"Dinner"`, `"Snack"`, `"Post-Workout"` |
| `budget_tier` | `string` | No | `BudgetTier.rawValue` | One of: `"Budget Friendly"`, `"Moderate"`, `"Premium"` |
| `available_ingredients` | `string[]` | No | `NutritionRecommendationInput.availableIngredients` | Max 30 entries; each ≤ 60 chars |
| `request_date` | `string (YYYY-MM-DD)` | Yes | `NutritionRecommendationInput.date` | ISO 8601 date |

> **Privacy rule:** No cycle information is included in nutrition requests. Cycle data is never sent to the nutrition endpoint.

---

### Response Body

```json
{
  "suggestions": [
    {
      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "food_item": {
        "id": "f1a2b3c4-d5e6-7890-abcd-ef0987654321",
        "name": "Masoor Dal",
        "item_description": "Red lentil curry, home-cooked",
        "serving_size": 200.0,
        "serving_unit": "g",
        "calories": 198.0,
        "protein_grams": 13.0,
        "carbohydrates_grams": 30.0,
        "fat_grams": 3.0,
        "fibre_grams": 8.0,
        "category": "Nuts & Legumes",
        "data_source": "AI Estimated",
        "icon_symbol": "🍲"
      },
      "suggested_quantity": 1.0,
      "target_meal_type": "Dinner",
      "estimated_calories": 198.0,
      "estimated_protein_grams": 13.0,
      "estimated_carbohydrates_grams": 30.0,
      "estimated_fat_grams": 3.0,
      "recommendation_rationale": "High protein, budget-friendly, and fits remaining macro gap of 75g protein."
    }
  ],
  "model_used": "llama3-8b-8192",
  "generated_at": "2026-10-24T03:00:00Z"
}
```

#### Response Field Definitions — Nutrition

| Field | Type | Maps to Swift model | Notes |
|---|---|---|---|
| `suggestions` | `FoodSuggestion[]` | `[FoodSuggestion]` | Array; may be empty |
| `suggestions[].id` | `string (UUID)` | `FoodSuggestion.id` | |
| `suggestions[].food_item` | `FoodItem object` | `FoodSuggestion.foodItem` | See food item fields below |
| `food_item.id` | `string (UUID)` | `FoodItem.id` | |
| `food_item.name` | `string` | `FoodItem.name` | |
| `food_item.item_description` | `string \| null` | `FoodItem.itemDescription` | |
| `food_item.serving_size` | `number` | `FoodItem.servingSize` | Positive number |
| `food_item.serving_unit` | `string` | `ServingUnit.rawValue` | One of: `"g"`, `"ml"`, `"piece"`, `"cup"`, `"tbsp"`, `"tsp"`, `"oz"` |
| `food_item.calories` | `number` | `FoodItem.calories` | Per serving size |
| `food_item.protein_grams` | `number` | `FoodItem.proteinGrams` | |
| `food_item.carbohydrates_grams` | `number` | `FoodItem.carbohydratesGrams` | |
| `food_item.fat_grams` | `number` | `FoodItem.fatGrams` | |
| `food_item.fibre_grams` | `number \| null` | `FoodItem.fibreGrams` | |
| `food_item.category` | `string \| null` | `FoodCategory.rawValue` | |
| `food_item.data_source` | `string` | `NutritionDataSource.rawValue` | Always `"AI Estimated"` for AI-generated items |
| `food_item.icon_symbol` | `string \| null` | `FoodItem.iconSymbol` | Emoji or asset key |
| `suggestions[].suggested_quantity` | `number` | `FoodSuggestion.suggestedQuantity` | Multiplier on serving size; > 0 |
| `suggestions[].target_meal_type` | `string` | `FoodSuggestion.targetMealType` | `MealType.rawValue` |
| `suggestions[].estimated_calories` | `number` | `FoodSuggestion.estimatedCalories` | `food_item.calories × suggested_quantity` |
| `suggestions[].estimated_protein_grams` | `number` | `FoodSuggestion.estimatedProteinGrams` | |
| `suggestions[].estimated_carbohydrates_grams` | `number` | `FoodSuggestion.estimatedCarbohydratesGrams` | |
| `suggestions[].estimated_fat_grams` | `number` | `FoodSuggestion.estimatedFatGrams` | |
| `suggestions[].recommendation_rationale` | `string` | `FoodSuggestion.recommendationRationale` | Human-readable explanation |
| `model_used` | `string` | — (metadata) | |
| `generated_at` | `string (ISO 8601)` | — (metadata) | UTC |

---

## Error Response

All error responses use this shape:

```json
{
  "error": "Human-readable description of the problem.",
  "code": "machine_readable_error_code"
}
```

| HTTP Status | `code` example | Meaning |
|---|---|---|
| `422` | `"validation_error"` | Missing or invalid field in request body |
| `500` | `"groq_api_error"` | Upstream Groq call failed or timed out |
| `500` | `"parse_error"` | Groq returned a non-parseable response |
| `503` | `"model_overloaded"` | Groq rate limit or overload; client should retry |

---

## Backend Environment Variables

The FastAPI backend requires the following environment variables. **None of these should exist in the iOS project.**

| Variable | Required | Description |
|---|---|---|
| `GROQ_API_KEY` | **Yes** | Groq API secret key — never committed to Git |
| `GROQ_MODEL` | No | Groq model identifier; default: `"llama3-8b-8192"` |
| `FITBUDDY_BACKEND_BASE_URL` | No (backend use only) | Base URL override; used on iOS client via scheme variable |
| `ALLOWED_ORIGINS` | No | Comma-separated CORS allowed origins for browser testing |
| `PORT` | No | Port to bind; default: `8000` |

> **Production requirement:** The backend must be deployed behind HTTPS. HTTP is only permitted at `127.0.0.1` / `localhost` for local developer testing. Set `FITBUDDY_BACKEND_BASE_URL` to an HTTPS URL in any staging or production environment.

---

## Enum Reference (Swift → JSON string mapping)

| Swift Enum | Values (JSON strings) |
|---|---|
| `FitnessGoal` | `"General Fitness"`, `"Build Strength"`, `"Improve Mobility"`, `"Stress Relief"`, `"Weight Loss"` |
| `DailyMood` | `"Energized ⚡️"`, `"Feeling... 😊"`, `"Relaxed 😌"`, `"Tired 😴"` |
| `EquipmentType` | `"None (Bodyweight)"`, `"Dumbbells"`, `"Resistance Bands"`, `"Yoga Mat"`, `"Kettlebell"`, `"Pull-up Bar"`, `"Foam Roller"` |
| `CyclePhase` | `"Menstrual Phase"`, `"Follicular Phase"`, `"Ovulatory Phase"`, `"Luteal Phase"` |
| `WorkoutCategory` | `"Stretch & Mobility"`, `"Full Body Strength"`, `"Yoga & Flow"`, `"Cardio & HIIT"`, `"Active Recovery"` |
| `FitnessDifficulty` | `"Beginner"`, `"Intermediate"`, `"Advanced"` |
| `MuscleGroup` | `"Chest"`, `"Back"`, `"Shoulders"`, `"Biceps"`, `"Triceps"`, `"Core"`, `"Quads"`, `"Hamstrings"`, `"Calves"`, `"Glutes"`, `"Full Body"` |
| `DietaryPreference` | `"Omnivore"`, `"Vegetarian"`, `"Vegan"`, `"Pescatarian"`, `"Ketogenic"`, `"Low Carb"`, `"Dairy-Free"`, `"Gluten-Free"`, `"Nut-Free"` |
| `MealType` | `"Breakfast"`, `"Lunch"`, `"Dinner"`, `"Snack"`, `"Post-Workout"` |
| `BudgetTier` | `"Budget Friendly"`, `"Moderate"`, `"Premium"` |
| `FoodCategory` | `"Fruits"`, `"Vegetables"`, `"Meat & Poultry"`, `"Seafood"`, `"Grains & Pasta"`, `"Dairy & Eggs"`, `"Nuts & Legumes"`, `"Beverages"`, `"Snacks"`, `"Prepared Meals"` |
| `ServingUnit` | `"g"`, `"ml"`, `"piece"`, `"cup"`, `"tbsp"`, `"tsp"`, `"oz"` |
| `NutritionDataSource` | `"Verified Database"`, `"AI Estimated"`, `"User Created"` |
| `UserGender` | `"Female"`, `"Male"`, `"Other"`, `"Prefer not to say"` |

---

## Health Check

### `GET /api/v1/health`

Returns the backend's operational status. No authentication required.

**Response:**
```json
{
  "status": "ok",
  "version": "1.0.0",
  "groq_model": "llama3-8b-8192"
}
```

---

*Last updated: Step 22A — 2026-10-24*
