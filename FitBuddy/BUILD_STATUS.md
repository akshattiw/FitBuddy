# FitBuddy — Build Status & Architecture Roadmap

**Last Updated:** 2026-10-24 (Step 22C complete)  
**Project:** FitBuddy (Native iOS Fitness App with SwiftUI + FastAPI Backend)

---

## 1. Project Overview & Current Structure

FitBuddy features **reliable local persistence** and a unified central state architecture managed by `AppState`. All core user-generated data across all five tabs (UserProfile, WorkoutHistory, Nutrition/FoodLogs, CycleData/PeriodEntries/Symptoms, and RewardInventory/XP/Passes) is stored locally using atomic JSON serialization via `LocalFilePersistenceService`.

- **Step 22A:** Established the versioned JSON API contract (`API_CONTRACT.md`) and iOS configuration (`Utilities/AppBackendConfig.swift`).
- **Step 22B:** Implemented the standalone Python FastAPI backend in `backend/`, serving workout and nutrition recommendations via Groq.
- **Step 22C:** **Fully complete & verified**: implemented native iOS networking layer (`RecommendationAPIClient`, `RecommendationDTOs`, `RecommendationNetworkError`, `NetworkWorkoutRecommendationService`, `NetworkNutritionRecommendationService`), wired into `MyApp.swift`, verified with 17 unit tests and live end-to-end integration against the running FastAPI backend and Groq Cloud.

### Directory Layout
```
kuch to hai/
├── AGENTS.md                                           # Permanent engineering guidelines and rules
├── BUILD_STATUS.md                                     # Project status tracker, interface log, and next steps
├── API_CONTRACT.md                                     # Versioned JSON API contract (v1) for backend endpoints
├── MyApp.swift                                         # Application entry point (@main App) wiring Network services
├── ContentView.swift                                   # Root container coordinating AppState, Onboarding, Profile & Tabs
├── AppTabBar.swift                                     # Custom pastel bottom bar supporting dynamic tab lists
├── UserProfile.swift                                   # Minimal profile model & observable UserProfileManager
├── HomeView.swift                                      # Today tab screen (workouts, active session, history recorder)
├── DietView.swift                                      # Diet tab screen (daily summary, macro rings, food log, suggestions)
├── CycleView.swift                                     # Cycle tab screen (cycle overview, period logging, symptoms, predictions)
├── StatsView.swift                                     # Stats tab screen powered by real WorkoutRecord history
├── RewardsView.swift                                   # Rewards tab screen with XP, streaks, monthly calendar & passes
├── Assets.xcassets/                                    # Asset catalog
├── Models/
│   ├── Exercise.swift                                  # Strongly typed Exercise model & fitness enums
│   ├── Workout.swift                                   # Recommended Workout routine model
│   ├── WorkoutRecord.swift                             # Model for recorded completed sessions
│   ├── FoodItem.swift                                  # Reusable food model, categories, serving units & data source
│   ├── FoodLog.swift                                   # User food log with immutable snapshot & consumed calculation
│   ├── NutritionSummary.swift                          # Daily intake aggregation & remaining targets calculation
│   ├── Symptom.swift                                   # CycleSymptomType, SymptomIntensity, LoggedSymptom
│   ├── CycleData.swift                                 # PeriodEntry, CyclePrediction, CycleData engine
│   └── Reward.swift                                    # RewardPassType, EarnedRewardPass, RewardInventoryState
├── Services/
│   ├── WorkoutRecommendationProviding.swift             # WorkoutRecommendationProviding protocol, WorkoutRecommendationInput
│   ├── MockWorkoutRecommendationService.swift          # Deterministic local mock workout engine (active fallback)
│   ├── WorkoutSessionTracker.swift                     # Observable active session state machine
│   ├── NutritionRecommendationProviding.swift          # NutritionRecommendationProviding protocol, FoodSuggestion, NutritionRecommendationInput
│   ├── MockNutritionRecommendationService.swift        # Deterministic local Indian food recommendation service (active fallback)
│   ├── RecommendationDTOs.swift                        # Strongly typed Encodable/Decodable DTOs matching API_CONTRACT.md
│   ├── RecommendationNetworkError.swift                # Typed, sanitized error enum (LocalizedError, Equatable)
│   ├── RecommendationAPIClient.swift                   # URLSession network client for workouts, nutrition, health
│   ├── NetworkWorkoutRecommendationService.swift       # Live workout service with tagged offline fallback
│   ├── NetworkNutritionRecommendationService.swift     # Live nutrition service with tagged offline fallback
│   ├── CycleDataManager.swift                          # Observable cycle tracking state manager
│   ├── WorkoutHistoryStore.swift                       # Shared observable store for completed workout records
│   ├── NutritionDataStore.swift                        # Shared observable store for food logs and macro targets
│   ├── MuscleEngagementService.swift                   # Set-weighted, time-decayed muscle load calculator
│   ├── RewardService.swift                             # Deterministic XP, streak & milestone pass logic
│   ├── RewardStore.swift                               # Observable reward inventory state manager
│   ├── LocalFilePersistenceService.swift               # Atomic JSON file persistence service & AppDataSnapshot
│   └── AppState.swift                                  # Central unified observable app state & coordinator
├── Views/
│   ├── MuscleMapView.swift                             # Reusable front & back body map component
│   ├── WeeklyComparisonView.swift                      # This week vs last week performance component
│   ├── WorkoutDetailView.swift                         # Sheet displaying routine exercises, instructions, reps/rest
│   ├── ActiveWorkoutView.swift                         # Fullscreen active session runner (timer, pause/resume, cancel)
│   ├── WorkoutSummaryView.swift                        # Completion celebration & actual session metrics sheet
│   ├── OnboardingView.swift                            # First-launch name and gender setup screen
│   └── ProfileView.swift                               # Decoupled Profile & Settings modal sheet
├── Utilities/
│   ├── AppColors.swift                                 # Centralized pastel & adaptive color tokens
│   ├── AppTheme.swift                                  # Typography, spacing, corner radius, & shadow definitions
│   └── AppBackendConfig.swift                          # Backend base URL configuration & security helpers (Step 22A/C)
├── Tests/
│   ├── NetworkRecommendationTests.swift                # 17 deterministic unit tests using MockURLProtocol
│   └── LiveIntegrationTest.swift                       # Standalone live integration test against running backend & Groq
├── backend/                                            # Python FastAPI AI Backend (Step 22B)
│   ├── main.py                                         # FastAPI app, endpoints, exception handlers, defensive coercions
│   ├── models.py                                       # Pydantic v2 schemas matching API_CONTRACT.md v1
│   ├── groq_client.py                                  # Groq SDK client wrapper, timeouts, error mapping, reset support
│   ├── prompts.py                                      # LLM system/user prompt builders injecting enum constraints
│   ├── test_backend.py                                 # 14 unit and integration tests (health, validation, errors, mock LLM)
│   ├── requirements.txt                                # Pinned dependencies
│   ├── .env.example                                    # Safe placeholder template for GROQ_API_KEY and GROQ_MODEL
│   ├── .gitignore                                      # Excludes .env, *.env, .venv, caches
│   └── README.md                                       # Architecture, setup, curl examples, testing, and iOS config
└── DesignReferences/                                   # UI/UX design mockups
    ├── today-screen.jpeg
    ├── diet-screen.jpeg
    ├── cycle-screen.jpeg
    ├── stats-screen.jpeg
    └── rewards-screen.jpeg
```

---

## 2. Completed Work

- [x] Inspected project workspace and confirmed architectural rules (AGENTS.md).
- [x] Designed and implemented `AppColors.swift`, `AppTheme.swift`.
- [x] Implemented all 5 tab screens: `HomeView`, `DietView`, `CycleView`, `StatsView`, `RewardsView`.
- [x] Implemented workout recommendation protocol, mock service, and full active workout flow.
- [x] Implemented nutrition models: `FoodItem`, `FoodLog`, `NutritionSummary`.
- [x] Implemented nutrition recommendation protocol and mock service.
- [x] Implemented cycle tracking: `CycleData`, `Symptom`, `CycleDataManager`, `CycleView`.
- [x] Implemented stats screen with `MuscleMapView`, `WeeklyComparisonView`, real workout data.
- [x] Implemented rewards system: XP, streaks, `RewardService`, `RewardStore`, `RewardsView`.
- [x] Implemented local persistence: `LocalFilePersistenceService`, `AppDataSnapshot`, `AppState`.
- [x] Implemented `OnboardingView` and decoupled `ProfileView`.
- [x] Verified native iOS type-check via `xcrun --sdk iphonesimulator swiftc -typecheck` across all project Swift files (exit code 0).
- [x] **Step 22A — Prepare iOS for AI integration:**
  - Audited recommendation protocols, input/output models, and injection points.
  - Created `Utilities/AppBackendConfig.swift`: configurable backend base URL resolved from environment variable → Info.plist → `http://127.0.0.1:8000`. Zero secrets in code.
  - Created `API_CONTRACT.md`: versioned JSON API contract (v1) for `POST /api/v1/workout/recommendations` and `POST /api/v1/nutrition/recommendations`.
- [x] **Step 22B — Python FastAPI AI Backend:**
  - Standalone FastAPI application in `backend/` with Pydantic request/response validation.
  - Pinned dependencies, `.gitignore` excluding `.env`, configurable model, and defensive normalizations.
  - 14 automated backend unit tests in `backend/test_backend.py` passing with exit code 0.
- [x] **Step 22C — Connect iOS App to AI Backend:**
  - Created `Services/RecommendationDTOs.swift`: Encodable request DTOs (`WorkoutRecommendationRequestDTO`, `NutritionRecommendationRequestDTO`) enforcing duration clamping (300–7200s), privacy gating, and Decodable response DTOs mapping to domain models.
  - Created `Services/RecommendationNetworkError.swift`: Strongly typed, sanitized error enum (`LocalizedError`, `Equatable`) with user-friendly descriptions.
  - Created `Services/RecommendationAPIClient.swift`: Reusable `URLSession` client with 30s timeout, ATS/HTTPS enforcement, status validation, and error decoding.
  - Created `Services/NetworkWorkoutRecommendationService.swift`: Conforms to `WorkoutRecommendationProviding` with tagged `[Offline Fallback]` fallback support.
  - Created `Services/NetworkNutritionRecommendationService.swift`: Conforms to `NutritionRecommendationProviding` with tagged `[Offline Fallback]` fallback support.
  - Updated `Utilities/AppBackendConfig.swift`: Added health endpoint, URL builders, and private LAN IP support (`192.168.x`, `10.x`, `172.16-31.x`, `.local`) for physical device testing.
  - Wired live services into `MyApp.swift` while preserving mock services for previews and fallback.
  - Created `Tests/NetworkRecommendationTests.swift`: 17 deterministic offline unit tests using `MockURLProtocol` (17/17 passing).
  - Created `Tests/LiveIntegrationTest.swift`: Verified live end-to-end communication with the running FastAPI backend and Groq LLM (health check, workout recommendation, nutrition recommendation all succeeded).
  - Verified full iOS typecheck passes: `xcrun --sdk iphonesimulator swiftc -typecheck` exit code 0 across all 41 project Swift files.

---

## 3. Step 22C Timeout Diagnosis & Resolution

### Root Cause
During early live testing, a timeout (`requestTimedOut`) was encountered due to a combination of factors:
1. **Groq Free Tier OTPM Limit:** On Groq's on-demand / free tier, the enforced limit is 1,000 output tokens per minute (OTPM). The initial backend configured `max_tokens=4096`, causing Groq to estimate the requested token budget as exceeding the limit and returning a rate-limit error (429).
2. **Sequential Requests Exceeding URLSession Budget:** Executing multiple back-to-back LLM calls within a single test case under free tier throttling exceeded `URLSession`'s 30-second request timeout.
3. **Model Availability:** Meta's legacy `llama3-8b-8192` was deprecated; the active supported model on the user's account is `qwen/qwen3.8-27b`.

### Fixes Applied
1. **Configurable Token Budget (`GROQ_MAX_TOKENS`):** In `backend/main.py`, made `max_tokens` configurable via `GROQ_MAX_TOKENS` defaulting to a safe `1000` tokens, preventing OTPM rejection.
2. **Separation of Concerns in Tests:** Unit tests in `Tests/NetworkRecommendationTests.swift` are strictly isolated using `MockURLProtocol` (17 tests, 0.015s, 0 network dependency). Live integration testing is housed in `Tests/LiveIntegrationTest.swift` with a 60-second timeout.
3. **Model Alignment:** Set `GROQ_MODEL=qwen/qwen3.8-27b` in the environment, confirming full JSON mode support.

---

## 4. Verification & Test Results

### 1. Swift Unit Test Suite (`Tests/NetworkRecommendationTests.swift`)
Run command:
```bash
swiftc -target arm64-apple-macos14.0 -parse-as-library Utilities/AppBackendConfig.swift UserProfile.swift Models/Exercise.swift Models/Workout.swift Models/FoodItem.swift Models/FoodLog.swift Models/NutritionSummary.swift Models/Symptom.swift Models/CycleData.swift Services/WorkoutRecommendationProviding.swift Services/MockWorkoutRecommendationService.swift Services/NutritionRecommendationProviding.swift Services/MockNutritionRecommendationService.swift Services/RecommendationDTOs.swift Services/RecommendationNetworkError.swift Services/RecommendationAPIClient.swift Services/NetworkWorkoutRecommendationService.swift Services/NetworkNutritionRecommendationService.swift Tests/NetworkRecommendationTests.swift -o Tests/network_tests_runner && ./Tests/network_tests_runner && rm -f Tests/network_tests_runner
```
- **Result:** **17 passed, 0 failed (100% pass rate)**.
- **Scenarios covered:**
  1. `testWorkoutRequestDTOEncoding`
  2. `testWorkoutRequestDTODurationClamping` (<300s $\to$ 300, >7200s $\to$ 7200)
  3. `testWorkoutRequestDTOCyclePrivacySafeguard` (male profiles never send cycle data)
  4. `testNutritionRequestDTOEncoding` (targets, remaining macros, ISO date)
  5. `testWorkoutResponseDTODecoding` (UUIDs, exercises, duration, calories, rationale)
  6. `testNutritionResponseDTODecoding` (food item, serving, estimated macros)
  7. `testBackendErrorResponseDecoding` (validation_error format)
  8. `testMockURLProtocolSuccessWorkout` (200 OK)
  9. `testMockURLProtocolSuccessNutrition` (200 OK)
  10. `testMockURLProtocolHTTP422ValidationError`
  11. `testMockURLProtocolHTTP503BusyError`
  12. `testMockURLProtocolTimeout`
  13. `testMockURLProtocolMalformedJSON`
  14. `testInsecureConnectionEnforcement` (HTTP rejected for public domains)
  15. `testNetworkWorkoutServiceFallbackActive` (fallback clearly marked `[Offline Fallback]`)
  16. `testNetworkWorkoutServiceThrowsWhenFallbackDisabled`
  17. `testNetworkNutritionServiceFallbackActive`

### 2. Live End-to-End Integration Test (`Tests/LiveIntegrationTest.swift`)
- **Backend Health Check:** `http://127.0.0.1:8000/health` $\to$ `200 OK` (`{"status":"ok","version":"1.0.0","groq_model":"qwen/qwen3.8-27b"}`)
- **Live Workout Recommendation:** Successfully returned live workout routine (`Energized Full Body Burn`, 15 mins, 3 exercises) from Groq Cloud.
- **Live Nutrition Recommendation:** Successfully returned 3 Indian food suggestions (`Moong Dal Tadka`, `Basmati Rice`, `Paneer Bhurji`) with accurate macros and rationales.
- **Result:** **PASSED**.

### 3. iOS Project Build Verification
- Command: `xcrun --sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios17.0-simulator *.swift Models/*.swift Services/*.swift Views/*.swift Utilities/*.swift`
- **Result:** **Exit code 0** (41 Swift files type-checked cleanly with 0 errors, 0 warnings).

---

## 5. How to Configure the Backend URL

### For iOS Simulator (Mac)
The default fallback URL is already configured for the simulator:
```
http://127.0.0.1:8000
```
In Xcode, you can set the scheme environment variable:
- Key: `FITBUDDY_BACKEND_BASE_URL`
- Value: `http://127.0.0.1:8000`

### For Physical iPhone on Local Wi-Fi
1. Find your Mac's local IP address on Wi-Fi (e.g. `192.168.1.50` via `ipconfig getifaddr en0`).
2. Start the backend bound to `0.0.0.0`:
   ```bash
   backend/.venv/bin/uvicorn backend.main:app --host 0.0.0.0 --port 8000
   ```
3. In Xcode, edit your Scheme $\to$ Run $\to$ Arguments $\to$ Environment Variables:
   - Key: `FITBUDDY_BACKEND_BASE_URL`
   - Value: `http://192.168.1.50:8000`
*(Note: `AppBackendConfig.requiresSecureTransport` explicitly permits private LAN IPs for local testing without requiring HTTPS).*

### For Production
Deploy the backend behind HTTPS and set:
- Key: `FITBUDDY_BACKEND_BASE_URL`
- Value: `https://api.yourdomain.com`

---

## 6. How to Start the Backend Locally

```bash
# From workspace root
backend/.venv/bin/uvicorn main:app --app-dir backend --reload --host 127.0.0.1 --port 8000
```
- Health check: `http://127.0.0.1:8000/health`
- Swagger UI: `http://127.0.0.1:8000/docs`

---

## 7. Step 22D Verification & Fallback Resilience (Completed)

Step 22D completed end-to-end integration verification, offline resilience testing, and UI feedback enhancements:

1. **Full Workout Tracking Lifecycle with Live AI (`Step22DVerificationTest`)**:
   - Fetched live AI workout recommendation (`Dumbbell Power Builder`) generated by Groq via FastAPI.
   - Initialized and drove `WorkoutSessionTracker` through active exercise completion.
   - Finished session into a genuine `WorkoutRecord` and persisted it in `WorkoutHistoryStore`.
   - Verified that `RewardStore` correctly calculated and awarded 50 XP, updated user levels, and enforced streak idempotency (preventing duplicate awards on resync).

2. **Full Nutrition Lifecycle & Store Integration**:
   - Fetched live AI meal recommendations (`Toor Dal (Yellow Lentils)`, etc.) with contextual rationales.
   - Transformed recommendations into `FoodLog` entries and recorded them into `NutritionDataStore`.
   - Confirmed deterministic recalculation of daily consumed calories and macronutrient progress.

3. **Offline Fallback Resilience**:
   - Simulated an unreachable/offline backend server (`http://127.0.0.1:59999`).
   - With `enableOfflineFallback: true` (default in `MyApp.swift`), `NetworkWorkoutRecommendationService` and `NetworkNutritionRecommendationService` cleanly degraded to local mock recommendations with an explicit `[Offline Fallback]` prefix.
   - Enhanced `WorkoutDetailView.swift` to display AI rationales with distinct visual treatments: a sparkling mint badge for live AI insights and a subtle gray badge with `wifi.slash` for `[Offline Fallback]` routines.

4. **Strict Error Propagation**:
   - When `enableOfflineFallback: false` (strict mode), confirmed the client properly propagates typed `RecommendationNetworkError.connectivityFailed` errors for explicit UI retry handling.

5. **Test Results**:
   - `Tests/Step22DVerificationTest.swift`: **21 Passed, 0 Failed** (Exit code 0).
   - `Tests/NetworkRecommendationTests.swift`: **17 Passed, 0 Failed** (Exit code 0).
   - iOS 17.0 Simulator compilation: **Clean build, 0 errors** across all 41 Swift files.

---

## 8. Current Limitations & Blockers

- None blocking. Steps 22A, 22B, 22C, and 22D are completely implemented and verified.
- The AI backend is running and operational, capable of serving live inference with Groq or graceful offline fallback.

---

## 9. Next Steps & Recommendations

1. **Physical Device / TestFlight Testing**: Test on physical iOS device using LAN IP (`FITBUDDY_BACKEND_BASE_URL=http://<mac-ip>:8000`).
2. **Production Deployment**: Containerize FastAPI backend (`Dockerfile`), deploy to cloud provider behind HTTPS, and update base URL.
3. **App Store Readiness**: Final UI audit, VoiceOver accessibility checks, and App Store metadata preparation.

