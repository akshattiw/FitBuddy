"""
models.py — Pydantic v2 request and response models for the FitBuddy backend.

Every field name, type, and validation rule matches API_CONTRACT.md v1.
Swift enum rawValue strings are validated explicitly via Literal / Enum.
"""

from __future__ import annotations

from enum import Enum
from typing import Optional
from uuid import UUID, uuid4
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


# ─── Shared Enums (must match Swift rawValue strings exactly) ────────────────

class FitnessGoal(str, Enum):
    general_fitness   = "General Fitness"
    build_strength    = "Build Strength"
    improve_mobility  = "Improve Mobility"
    stress_relief     = "Stress Relief"
    weight_loss       = "Weight Loss"


class DailyMood(str, Enum):
    energized = "Energized ⚡️"
    happy     = "Feeling... 😊"
    relaxed   = "Relaxed 😌"
    tired     = "Tired 😴"


class EquipmentType(str, Enum):
    none             = "None (Bodyweight)"
    dumbbells        = "Dumbbells"
    resistance_bands = "Resistance Bands"
    yoga_mat         = "Yoga Mat"
    kettlebell       = "Kettlebell"
    pull_up_bar      = "Pull-up Bar"
    foam_roller      = "Foam Roller"


class CyclePhase(str, Enum):
    menstrual  = "Menstrual Phase"
    follicular = "Follicular Phase"
    ovulatory  = "Ovulatory Phase"
    luteal     = "Luteal Phase"


class WorkoutCategory(str, Enum):
    stretch   = "Stretch & Mobility"
    strength  = "Full Body Strength"
    yoga      = "Yoga & Flow"
    cardio    = "Cardio & HIIT"
    recovery  = "Active Recovery"


class FitnessDifficulty(str, Enum):
    beginner     = "Beginner"
    intermediate = "Intermediate"
    advanced     = "Advanced"


class MuscleGroup(str, Enum):
    chest      = "Chest"
    back       = "Back"
    shoulders  = "Shoulders"
    biceps     = "Biceps"
    triceps    = "Triceps"
    core       = "Core"
    quads      = "Quads"
    hamstrings = "Hamstrings"
    calves     = "Calves"
    glutes     = "Glutes"
    full_body  = "Full Body"


class DietaryPreference(str, Enum):
    omnivore      = "Omnivore"
    vegetarian    = "Vegetarian"
    vegan         = "Vegan"
    pescatarian   = "Pescatarian"
    keto          = "Ketogenic"
    low_carb      = "Low Carb"
    dairy_free    = "Dairy-Free"
    gluten_free   = "Gluten-Free"
    nut_free      = "Nut-Free"


class MealType(str, Enum):
    breakfast    = "Breakfast"
    lunch        = "Lunch"
    dinner       = "Dinner"
    snack        = "Snack"
    post_workout = "Post-Workout"


class BudgetTier(str, Enum):
    budget   = "Budget Friendly"
    moderate = "Moderate"
    premium  = "Premium"


class FoodCategory(str, Enum):
    fruits        = "Fruits"
    vegetables    = "Vegetables"
    poultry_meat  = "Meat & Poultry"
    seafood       = "Seafood"
    grains        = "Grains & Pasta"
    dairy         = "Dairy & Eggs"
    legumes_nuts  = "Nuts & Legumes"
    beverages     = "Beverages"
    snacks        = "Snacks"
    prepared      = "Prepared Meals"


class ServingUnit(str, Enum):
    grams       = "g"
    milliliters = "ml"
    piece       = "piece"
    cup         = "cup"
    tablespoon  = "tbsp"
    teaspoon    = "tsp"
    ounce       = "oz"


class NutritionDataSource(str, Enum):
    verified     = "Verified Database"
    ai_estimated = "AI Estimated"
    user_created = "User Created"


class UserGender(str, Enum):
    female          = "Female"
    male            = "Male"
    other           = "Other"
    prefer_not      = "Prefer not to say"


# ─── Endpoint 1: Workout Recommendations ─────────────────────────────────────

class WorkoutRecommendationRequest(BaseModel):
    """POST /api/v1/workout/recommendations — request body."""

    user_name: str = Field(..., min_length=1, max_length=100)
    gender: Optional[UserGender] = None
    fitness_goal: FitnessGoal
    daily_mood: Optional[DailyMood] = None
    available_equipment: list[EquipmentType] = Field(..., min_length=1)
    available_time_seconds: float = Field(..., ge=300, le=7200)
    recent_completed_workouts: list[str] = Field(default_factory=list, max_length=10)
    cycle_phase: Optional[CyclePhase] = None
    cycle_symptoms: list[str] = Field(default_factory=list, max_length=10)

    @field_validator("recent_completed_workouts", mode="before")
    @classmethod
    def validate_workout_names(cls, v: list) -> list:
        return [str(name)[:100] for name in v]

    @field_validator("cycle_symptoms", mode="before")
    @classmethod
    def validate_symptoms(cls, v: list) -> list:
        return [str(s)[:100] for s in v]


class ExerciseResponse(BaseModel):
    """Single exercise inside a recommended workout."""
    id: str = Field(default_factory=lambda: str(uuid4()))
    name: str
    description: str
    target_muscles: list[MuscleGroup]
    equipment: EquipmentType
    difficulty: FitnessDifficulty
    instructions: list[str]
    sets: Optional[int] = None
    repetitions: Optional[int] = None
    duration_seconds: Optional[float] = None
    rest_interval_seconds: Optional[float] = None
    form_notes: Optional[str] = None


class WorkoutResponse(BaseModel):
    """Single recommended workout routine."""
    id: str = Field(default_factory=lambda: str(uuid4()))
    name: str
    description: str
    category: WorkoutCategory
    difficulty: FitnessDifficulty
    estimated_duration_seconds: float
    estimated_calories: int
    required_equipment: list[EquipmentType]
    ai_recommendation_rationale: Optional[str] = None
    exercises: list[ExerciseResponse]


class WorkoutRecommendationResponse(BaseModel):
    """POST /api/v1/workout/recommendations — response body."""
    model_config = ConfigDict(protected_namespaces=())
    workouts: list[WorkoutResponse]
    model_used: str
    generated_at: str


# ─── Endpoint 2: Nutrition Recommendations ───────────────────────────────────

class NutritionRecommendationRequest(BaseModel):
    """POST /api/v1/nutrition/recommendations — request body."""

    user_name: str = Field(..., min_length=1, max_length=100)
    gender: Optional[UserGender] = None
    fitness_goal: FitnessGoal
    daily_calorie_target: float = Field(..., gt=0)
    daily_protein_target_grams: float = Field(..., ge=0)
    daily_carbohydrates_target_grams: float = Field(..., ge=0)
    daily_fat_target_grams: float = Field(..., ge=0)
    consumed_calories: Optional[float] = Field(default=0.0, ge=0)
    consumed_protein_grams: Optional[float] = Field(default=0.0, ge=0)
    consumed_carbohydrates_grams: Optional[float] = Field(default=0.0, ge=0)
    consumed_fat_grams: Optional[float] = Field(default=0.0, ge=0)
    remaining_calories: Optional[float] = Field(default=None, ge=0)
    remaining_protein_grams: Optional[float] = Field(default=None, ge=0)
    remaining_carbohydrates_grams: Optional[float] = Field(default=None, ge=0)
    remaining_fat_grams: Optional[float] = Field(default=None, ge=0)
    dietary_preferences: list[DietaryPreference] = Field(default_factory=lambda: [DietaryPreference.omnivore])
    target_meal_type: MealType
    budget_tier: BudgetTier = BudgetTier.moderate
    available_ingredients: list[str] = Field(default_factory=list, max_length=30)
    request_date: str = Field(...)  # ISO 8601 date YYYY-MM-DD

    @field_validator("available_ingredients", mode="before")
    @classmethod
    def validate_ingredients(cls, v: list) -> list:
        return [str(i)[:60] for i in v]

    @model_validator(mode="after")
    def compute_remaining(self) -> "NutritionRecommendationRequest":
        """Back-fill remaining fields if client didn't send them."""
        if self.remaining_calories is None:
            consumed = self.consumed_calories or 0.0
            self.remaining_calories = max(0.0, self.daily_calorie_target - consumed)
        if self.remaining_protein_grams is None:
            consumed = self.consumed_protein_grams or 0.0
            self.remaining_protein_grams = max(0.0, self.daily_protein_target_grams - consumed)
        if self.remaining_carbohydrates_grams is None:
            consumed = self.consumed_carbohydrates_grams or 0.0
            self.remaining_carbohydrates_grams = max(0.0, self.daily_carbohydrates_target_grams - consumed)
        if self.remaining_fat_grams is None:
            consumed = self.consumed_fat_grams or 0.0
            self.remaining_fat_grams = max(0.0, self.daily_fat_target_grams - consumed)
        return self


class FoodItemResponse(BaseModel):
    """Food item returned inside a nutrition suggestion."""
    id: str = Field(default_factory=lambda: str(uuid4()))
    name: str
    item_description: Optional[str] = None
    serving_size: float
    serving_unit: ServingUnit
    calories: float
    protein_grams: float
    carbohydrates_grams: float
    fat_grams: float
    fibre_grams: Optional[float] = None
    category: Optional[FoodCategory] = None
    data_source: NutritionDataSource = NutritionDataSource.ai_estimated
    icon_symbol: Optional[str] = None


class FoodSuggestionResponse(BaseModel):
    """Single food suggestion."""
    id: str = Field(default_factory=lambda: str(uuid4()))
    food_item: FoodItemResponse
    suggested_quantity: float = Field(..., gt=0)
    target_meal_type: MealType
    estimated_calories: float
    estimated_protein_grams: float
    estimated_carbohydrates_grams: float
    estimated_fat_grams: float
    recommendation_rationale: str


class NutritionRecommendationResponse(BaseModel):
    """POST /api/v1/nutrition/recommendations — response body."""
    model_config = ConfigDict(protected_namespaces=())
    suggestions: list[FoodSuggestionResponse]
    model_used: str
    generated_at: str


# ─── Health Check ─────────────────────────────────────────────────────────────

class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "1.0.0"
    groq_model: str


# ─── Error ───────────────────────────────────────────────────────────────────

class ErrorResponse(BaseModel):
    error: str
    code: str
