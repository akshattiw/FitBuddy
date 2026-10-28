"""
prompts.py — Structured prompt builders for FitBuddy AI recommendations.

Prompts instruct the LLM to return valid JSON matching the API contract schema.
All enum values are provided in the prompt to prevent hallucination.
"""

from __future__ import annotations

from .models import WorkoutRecommendationRequest, NutritionRecommendationRequest


# ─── Shared enum reference strings injected into every prompt ────────────────

WORKOUT_CATEGORY_VALUES = (
    '"Stretch & Mobility", "Full Body Strength", "Yoga & Flow", "Cardio & HIIT", "Active Recovery"'
)
DIFFICULTY_VALUES = '"Beginner", "Intermediate", "Advanced"'
EQUIPMENT_VALUES = (
    '"None (Bodyweight)", "Dumbbells", "Resistance Bands", "Yoga Mat", '
    '"Kettlebell", "Pull-up Bar", "Foam Roller"'
)
MUSCLE_GROUP_VALUES = (
    '"Chest", "Back", "Shoulders", "Biceps", "Triceps", "Core", '
    '"Quads", "Hamstrings", "Calves", "Glutes", "Full Body"'
)
MEAL_TYPE_VALUES = '"Breakfast", "Lunch", "Dinner", "Snack", "Post-Workout"'
SERVING_UNIT_VALUES = '"g", "ml", "piece", "cup", "tbsp", "tsp", "oz"'
FOOD_CATEGORY_VALUES = (
    '"Fruits", "Vegetables", "Meat & Poultry", "Seafood", "Grains & Pasta", '
    '"Dairy & Eggs", "Nuts & Legumes", "Beverages", "Snacks", "Prepared Meals"'
)


# ─── Workout prompt ───────────────────────────────────────────────────────────

WORKOUT_SYSTEM_PROMPT = """\
You are FitBuddy's fitness AI. You generate personalised workout recommendations.

STRICT RULES:
1. Respond ONLY with valid JSON. No markdown, no code fences, no extra text.
2. Always use the exact string values listed in the schema for every enum field.
3. Generate 2–3 distinct workout routines, each containing 3–6 exercises.
4. Respect the available equipment list — never suggest equipment not in that list.
5. Respect the available time — total estimated_duration_seconds must fit within available_time_seconds.
6. Each exercise must have either sets+repetitions OR duration_seconds (not both).
7. All strings must be honest and fitness-appropriate.

OUTPUT JSON SCHEMA (return this exact shape):
{
  "workouts": [
    {
      "id": "<uuid-v4>",
      "name": "<string>",
      "description": "<string>",
      "category": <one of: """ + WORKOUT_CATEGORY_VALUES + """>,
      "difficulty": <one of: """ + DIFFICULTY_VALUES + """>,
      "estimated_duration_seconds": <integer>,
      "estimated_calories": <integer>,
      "required_equipment": [<one or more of: """ + EQUIPMENT_VALUES + """>],
      "ai_recommendation_rationale": "<string — why this workout suits the user>",
      "exercises": [
        {
          "id": "<uuid-v4>",
          "name": "<string>",
          "description": "<one-sentence description>",
          "target_muscles": [<one or more of: """ + MUSCLE_GROUP_VALUES + """>],
          "equipment": <one of: """ + EQUIPMENT_VALUES + """>,
          "difficulty": <one of: """ + DIFFICULTY_VALUES + """>,
          "instructions": ["<step 1>", "<step 2>", "<step 3>"],
          "sets": <integer or null>,
          "repetitions": <integer or null>,
          "duration_seconds": <number or null>,
          "rest_interval_seconds": <number or null>,
          "form_notes": "<string or null>"
        }
      ]
    }
  ]
}
"""


def build_workout_user_message(req: WorkoutRecommendationRequest) -> str:
    """Build the user-turn content describing the specific user context."""
    mood_str     = req.daily_mood.value if req.daily_mood else "Not specified"
    gender_str   = req.gender.value if req.gender else "Not specified"
    cycle_str    = req.cycle_phase.value if req.cycle_phase else "N/A"
    symptoms_str = ", ".join(req.cycle_symptoms) if req.cycle_symptoms else "None"
    equipment_str = ", ".join(e.value for e in req.available_equipment)
    recent_str    = ", ".join(req.recent_completed_workouts) if req.recent_completed_workouts else "None"
    time_min      = int(req.available_time_seconds / 60)

    return f"""\
Generate personalised workout recommendations for this user:

User name: {req.user_name}
Gender: {gender_str}
Fitness goal: {req.fitness_goal.value}
Today's mood / energy: {mood_str}
Available equipment: {equipment_str}
Available time: {time_min} minutes ({int(req.available_time_seconds)} seconds)
Recent workouts (avoid repeating same muscles): {recent_str}
Cycle phase (if applicable): {cycle_str}
Current cycle symptoms (if applicable): {symptoms_str}

Important:
- Only use equipment from the Available equipment list above.
- If mood is Tired or cycle symptoms include Cramps/Fatigue, prefer lower-intensity options.
- If mood is Energized and goal is Build Strength, prefer higher-intensity routines.
- Ensure total estimated_duration_seconds across exercises fits within {int(req.available_time_seconds)} seconds.
- Generate 2–3 diverse workout options so the user can choose.
- Use real UUID v4 format for all id fields.
- Return only JSON, nothing else.
"""


# ─── Nutrition prompt ─────────────────────────────────────────────────────────

NUTRITION_SYSTEM_PROMPT = """\
You are FitBuddy's nutrition AI. You suggest specific foods for Indian users based on remaining macro targets.

STRICT RULES:
1. Respond ONLY with valid JSON. No markdown, no code fences, no extra text.
2. Always use the exact string values listed in the schema for every enum field.
3. Generate 4–6 distinct food suggestions appropriate for the requested meal type.
4. Nutrition values must be realistic and correspond exactly to the serving size specified.
5. Prioritise affordable, readily available Indian foods (dal, roti, rice, curd, paneer, chana, eggs, etc.) unless dietary preferences exclude them.
6. Always set data_source to "AI Estimated" for all food items.
7. estimated_calories = food_item.calories × suggested_quantity (must be accurate).

OUTPUT JSON SCHEMA (return this exact shape):
{
  "suggestions": [
    {
      "id": "<uuid-v4>",
      "food_item": {
        "id": "<uuid-v4>",
        "name": "<string>",
        "item_description": "<string or null>",
        "serving_size": <number>,
        "serving_unit": <one of: """ + SERVING_UNIT_VALUES + """>,
        "calories": <number — per serving_size>,
        "protein_grams": <number — per serving_size>,
        "carbohydrates_grams": <number — per serving_size>,
        "fat_grams": <number — per serving_size>,
        "fibre_grams": <number or null>,
        "category": <one of: """ + FOOD_CATEGORY_VALUES + """>,
        "data_source": "AI Estimated",
        "icon_symbol": "<emoji string or null>"
      },
      "suggested_quantity": <number — multiplier on serving_size, e.g. 1.0 or 1.5>,
      "target_meal_type": <one of: """ + MEAL_TYPE_VALUES + """>,
      "estimated_calories": <food_item.calories × suggested_quantity>,
      "estimated_protein_grams": <food_item.protein_grams × suggested_quantity>,
      "estimated_carbohydrates_grams": <food_item.carbohydrates_grams × suggested_quantity>,
      "estimated_fat_grams": <food_item.fat_grams × suggested_quantity>,
      "recommendation_rationale": "<string — why this food fits remaining macros and preferences>"
    }
  ]
}
"""


def build_nutrition_user_message(req: NutritionRecommendationRequest) -> str:
    """Build the user-turn content describing the nutrition context."""
    gender_str   = req.gender.value if req.gender else "Not specified"
    prefs_str    = ", ".join(p.value for p in req.dietary_preferences) if req.dietary_preferences else "Omnivore"
    ingr_str     = ", ".join(req.available_ingredients) if req.available_ingredients else "None specified"

    return f"""\
Generate food suggestions for this user:

User name: {req.user_name}
Gender: {gender_str}
Fitness goal: {req.fitness_goal.value}
Target meal: {req.target_meal_type.value}
Budget: {req.budget_tier.value}
Dietary preferences / restrictions: {prefs_str}
Available ingredients on hand: {ingr_str}
Date: {req.request_date}

Daily targets:
  Calories:      {req.daily_calorie_target:.0f} kcal
  Protein:       {req.daily_protein_target_grams:.0f} g
  Carbohydrates: {req.daily_carbohydrates_target_grams:.0f} g
  Fat:           {req.daily_fat_target_grams:.0f} g

Already consumed today:
  Calories:      {req.consumed_calories:.0f} kcal
  Protein:       {req.consumed_protein_grams:.0f} g
  Carbohydrates: {req.consumed_carbohydrates_grams:.0f} g
  Fat:           {req.consumed_fat_grams:.0f} g

Remaining:
  Calories:      {req.remaining_calories:.0f} kcal
  Protein:       {req.remaining_protein_grams:.0f} g
  Carbohydrates: {req.remaining_carbohydrates_grams:.0f} g
  Fat:           {req.remaining_fat_grams:.0f} g

Important:
- Suggest foods that meaningfully contribute to remaining macros without exceeding them.
- Prioritise protein if remaining_protein_grams is more than 30% of the daily target.
- Respect all dietary preferences and restrictions strictly.
- Suggest realistic Indian home-cooking portions where applicable.
- Use real UUID v4 format for all id fields.
- All estimated_* fields must equal food_item value × suggested_quantity exactly.
- Return only JSON, nothing else.
"""
