# Mile One — Technical Implementation Plan

*Created 2026-05-29 | TDD-driven, adversarial-reviewed*

> **Note:** This directory replaces the monolithic `memory/mile-one-tech-plan.md` file. The original file is preserved but this split version is the preferred reference.

---

## Table of Contents

### Core Design

- [**Architecture, Project Structure & Tech Stack**](architecture.md) — Sections 1–3: Pattern overview, file layout, and technology choices (Swift 6, SwiftUI, SwiftData, MapKit, HealthKit)
- [**Data Models**](data-models.md) — Section 4: UserProfile, CompletedRun, GPSPoint, SavedRoute, Enums & Value Types
- [**Service Layer Design**](services.md) — Section 5: All protocols and service implementations (Location, HealthKit, AudioCoach, Route, DataStore, RunEngine, CalorieCalculator)
- [**Session Plan (Static Data)**](session-plan.md) — Section 6: Full 27-session interval table (Weeks 1–9, 3 sessions each)

### Implementation Phases

- [**Phase 1: Foundation**](phase-1-foundation.md) — Models, Data Store, Session Plans (~1 week) — includes sprint ordering rationale
- [**Phase 2: Run Engine**](phase-2-run-engine.md) — Run Engine + GPS + Background Execution (~1.5 weeks)
- [**Phase 3: Audio & UI**](phase-3-audio-ui.md) — Audio Coach + In-Run UI (~1 week)
- [**Phase 4: HealthKit**](phase-4-healthkit.md) — HealthKit Integration + Post-Run Flow (~1 week)
- [**Phase 5: Onboarding**](phase-5-onboarding.md) — Onboarding + Dashboard + Progress Tracking (~1 week)
- [**Phase 6: Route Planner**](phase-6-route-planner.md) — Route Planner with road-snap and free-draw modes (~1.5 weeks)
- [**Phase 7: History & Settings**](phase-7-history.md) — History + Settings + iCloud Sync (~1 week)
- [**Phase 8: Graduation**](phase-8-graduation.md) — Graduation + Free Run + Polish (~1 week)

### Testing

- [**Testing Strategy**](testing-strategy.md) — Testing pyramid, integration tests, UI tests, accessibility audits, GPX fixtures, Test Plan, on-device smoke checklist, code coverage targets

### Reference

- [**Known Limitations & Workarounds**](known-limitations.md) — Section 8: AVSpeechSynthesizer, location permissions, SwiftData quirks, GPS accuracy, battery
- [**Appendices**](appendices.md) — Info.plist keys, CloudKit configuration, test coverage summary (~71 tests)

### Requirements & Reviews

- [**Product Requirements**](requirements.md) — Full product requirements document
- [**Product Review #2**](reviews/product-review-2.md) — Second product review
- [**Tech Review #2**](reviews/tech-review-2.md) — Second technical review
