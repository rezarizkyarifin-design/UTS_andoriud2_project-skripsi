# SIAP — Sistem Informasi Arsip Peminjaman (Temporary Name for the Application)

A mobile application for managing the loan and return of physical land record documents (buku tanah) at a land office (Kantor Pertanahan), built with Flutter and Supabase. SIAP digitizes what was previously a manual, paper-based logbook process into a role-based, auditable digital workflow with QR/barcode tracking for every document loan.

This repository is a project developed for Kantor Pertanahan (BPN) Kota Cilegon, built to digitize the office's existing manual loan/return process.

---

## Project Status

**Current phase: Internal testing and debugging.**

The core feature set described below is functionally complete — authentication, document loan creation, QR/barcode generation, scanning-based returns, loan history with admin editing, bulk returns, and profile management are all implemented end-to-end against a live Supabase backend. The current focus is stabilizing the application ahead of handover and deployment at the office:

- Manually testing every user flow across both roles (pegawai and admin).
- Reproducing and fixing runtime errors surfaced during real device testing (see [Known Issues](#known-issues--current-debugging-focus)).
- Verifying that Supabase Row Level Security (RLS) policies behave correctly under each role.
- Checking edge cases around stale local cache vs. live Supabase state (e.g., a document being returned from a second device while the first device is idle).
- General UI polish and consistency passes across pages that were built at different points in the project timeline.

No changes to the data model or backend schema are planned at this stage — remaining work is primarily about correctness, resilience, and edge-case handling in the existing feature set.

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Application Modules](#application-modules)
4. [Roles and Permissions](#roles-and-permissions)
5. [Data Model](#data-model)
6. [Tech Stack](#tech-stack)
7. [Architecture and Project Structure](#architecture-and-project-structure)
8. [Getting Started](#getting-started)
9. [Supabase Configuration](#supabase-configuration)
10. [Running the App](#running-the-app)
11. [Known Issues / Current Debugging Focus](#known-issues--current-debugging-focus)
12. [Roadmap](#roadmap)
13. [Design Notes](#design-notes)
14. [Project Context](#project-context)

---

## Overview

Land offices maintain physical land record documents that must periodically be checked out by staff — for verification, legal processing, dispute resolution, or administrative review — and later returned. Historically, this loan/return cycle has been tracked in a physical logbook, which makes it difficult to:

- Know at a glance which documents are currently on loan and to whom.
- Identify overdue loans.
- Search historical loan records by employee, kecamatan (district), kelurahan (sub-district/village), or land right type.
- Enforce accountability for who is allowed to approve, edit, or delete loan records.

SIAP addresses this by providing:

- A structured digital form for recording a new loan, covering the borrower's identity, the document's administrative location (kecamatan/kelurahan), the type of land right (jenis hak), the land right number (nomor hak), the purpose of the loan, and the loan/return dates.
- An automatically generated QR code for each loan, which can be printed and physically attached to the document (buku tanah) for fast identification during the return process.
- A camera-based scanner (with a gallery fallback) that reads the QR code and immediately looks up the associated loan record, cross-checked against the latest data from Supabase rather than a potentially stale local cache.
- A searchable, filterable history/archive view of every loan, with role-gated editing and deletion.
- A dedicated return workflow with both single-item and multi-select bulk return actions.
- A notification indicator summarizing overdue loans (for staff) or pending extension requests (for admins).

## Key Features

- **Digital loan intake form** with cascading location selection (kecamatan → kelurahan), land right type selection, land right number input, purpose field, and date pickers with sane defaults (a seven-day loan period, non-backdating validation on the return date).
- **Duplicate-loan prevention** — the app checks whether a given nomor hak already has an active (not yet returned) loan before allowing a new one to be created.
- **QR code generation** for every saved loan, rendered on a printable label alongside the borrower's name, kelurahan, land right type/number, and the loan/return dates.
- **Native print support** for the generated QR label, plus the ability to save/share it as an image.
- **Camera-based QR/barcode scanning** with:
  - Live camera preview with a scanning frame and animated scan line.
  - Torch (flashlight) toggle for low-light conditions.
  - Gallery image picker fallback for scanning a photographed barcode.
  - A live-data refresh before evaluating a scanned code, so results reflect the current state in Supabase rather than a stale local snapshot.
- **Loan history / archive** with:
  - Free-text search across borrower name, kecamatan, kelurahan, and nomor hak.
  - Filters for kecamatan, kelurahan, land right type, and loan status (active / returned).
  - Pull-to-refresh and explicit error/retry handling for failed data loads.
  - Relative and absolute date formatting for loan timestamps.
  - Visual status indicators (on loan, returned, overdue) with distinct colors.
- **Admin-only record editing** through a dedicated full-page editor covering every field the backend accepts (name, seksi/unit kerja, kecamatan, kelurahan, land right type, land right number, purpose, loan date, and return date) — not a partial edit of a subset of fields.
- **Admin-only record deletion**, with confirmation.
- **Return workflow** with:
  - A dedicated "active loans" view, separate from the full history.
  - Single-item return marking.
  - Multi-select mode for marking several documents as returned in one action, with a summary of how many succeeded versus failed.
- **Role-based access control** enforced both in the UI (which actions are shown/enabled) and at the data layer via Supabase RLS, so that non-admin accounts cannot approve, edit, or delete records even if they attempt to call the underlying service methods directly.
- **Authentication** via Supabase Auth, using a synthetic `username@siap.local` email scheme so staff can log in with a plain username rather than a real email address.
- **Self-service password change** from the profile page (chosen deliberately over an emailed reset link, since the synthetic email address is not a real, reachable inbox).
- **Profile page** showing the logged-in user's name, username, email, jabatan (position), and role, with a logout confirmation step.
- **Notification indicator** on the home page whose meaning adapts to role: for admins it reflects pending extension requests; for regular staff it reflects the count of their own unreturned/overdue loans.
- **Consistent navigation shell** across the app: a bottom navigation bar (Beranda / Arsip / Kembali / Profil) with a centrally docked floating action button for Scan, plus a side drawer for additional navigation.

## Application Modules

| Module | File | Description |
|---|---|---|
| Login | `login_page.dart`* | Custom-designed authentication screen with a government-document aesthetic. |
| Home / Dashboard | `home_page.dart`* | Landing screen after login; entry point to the loan form, notifications, and navigation shell. |
| Loan Form | `form_page.dart` | Structured form for recording a new document loan. |
| QR / Barcode Result | `barcode_page.dart` | Displays the generated QR code for a just-created loan, with print and share-as-image actions. |
| Scan | `scan_page.dart` | Camera-based QR/barcode scanner used to look up and process document returns. |
| History / Archive | `history_page.dart` | Full loan history with search, filters, and admin edit/delete actions. |
| Return | `return_page.dart` | Focused view of currently active loans, with single and bulk return actions. |
| Profile | `profile_page.dart` | Account information, password change, and logout. |

\* Referenced by other pages via named routes but not included in the current file set reviewed for this document.

## Roles and Permissions

The application recognizes two roles, enforced through `AuthService` and mirrored by Supabase RLS policies:

| Capability | Pegawai (Staff) | Admin |
|---|:---:|:---:|
| Create a new loan | Yes | Yes |
| View loan history | Yes | Yes |
| Search / filter history | Yes | Yes |
| Scan a document to view its status | Yes | Yes |
| Mark a document as returned | Yes | Yes |
| Bulk-mark documents as returned | Yes | Yes |
| Request a loan extension | Yes | — |
| Approve/review extension requests | — | Yes |
| Edit an existing loan record | — | Yes |
| Delete a loan record | — | Yes |
| Change own password | Yes | Yes |

## Data Model

The central entity is `Peminjaman` (loan record). Based on the fields consistently read and written across the form, history, edit, and printing flows:

| Field | Type | Description |
|---|---|---|
| `nama` | String | Name of the borrowing staff member. |
| `seksi` | String | Seksi / unit kerja (section or work unit) the borrower belongs to. |
| `kecamatan` | String | District where the land record is administratively located. |
| `kelurahan` | String | Sub-district/village within the selected kecamatan. |
| `jenisHak` | String | Type of land right (e.g., Hak Milik, Hak Guna Bangunan, etc., per office-defined categories). |
| `noHak` | String | Land right number — the primary human-readable identifier encoded into the QR code. |
| `keperluan` | String | Free-text purpose/reason for the loan. |
| `tanggalPinjam` | DateTime | Loan start date. |
| `tanggalKembali` | DateTime | Expected/actual return date. |
| `status` | String | `Dipinjam` (on loan) or returned; derived overdue state is computed from `tanggalKembali` vs. the current date. |

Reference/lookup data (kecamatan and kelurahan lists, land right types, and seksi/unit kerja options) is centralized in a static `Data` class, covering the full administrative breakdown for the relevant municipality (Kota Cilegon): 8 kecamatan and 43 kelurahan.

## Tech Stack

| Layer | Technology |
|---|---|
| Client framework | Flutter |
| Backend / database | Supabase (PostgreSQL, Auth, Row Level Security) |
| Authentication | Supabase Auth (synthetic email scheme for username-based login) |
| QR code generation | `qr_flutter` |
| QR/barcode scanning | `mobile_scanner` |
| Image selection (gallery scan fallback) | `image_picker` |
| Printing | Native platform print dialog via a dedicated `PrintingService` |
| State management | `StatefulWidget` + `setState`, with a service-layer in-memory cache mirroring Supabase reads |

## Architecture and Project Structure

The codebase follows a conventional feature/layer split within `lib/`:

```
lib/
├── core/
│   └── theme/
│       └── app_theme.dart        # Centralized color palette and shared style constants
├── data/
│   └── data.dart                 # Static reference data: kecamatan, kelurahan, jenisHak, seksi
├── models/
│   ├── peminjaman.dart           # Loan record model (fields, copyWith, formatting helpers)
│   └── user_roles.dart           # User/role model (role, label, jabatan, etc.)
├── routes/
│   └── app_routes.dart           # Named route constants (login, home, history, returnPage, scan, barcode, profile)
├── services/
│   ├── auth_service.dart         # Supabase auth wrapper, role checks, password change
│   ├── peminjaman_service.dart   # CRUD against Supabase + in-memory cache, bulk operations, queries
│   └── printing_service.dart     # Print-dialog and share-as-image logic for QR labels
├── widgets/
│   ├── app_drawer.dart           # Shared side navigation drawer
│   ├── app_bottom_nav.dart       # Shared bottom navigation bar
│   └── app_scan_fab.dart         # Shared docked floating action button for the Scan screen
└── pages/
    ├── auth/                     # Login
    ├── home/                     # Dashboard
    ├── peminjaman/
    │   ├── form_page.dart
    │   ├── barcode_page.dart
    │   ├── history_page.dart
    │   ├── return_page.dart
    │   ├── scan_page.dart
    |   └── profile_page.dart
```

Design conventions applied consistently across pages:

- A shared color palette (`_primaryGreen` `#1B4332`, `_accentGreen` `#2D6A4F`, plus semantic colors for overdue/error states) defined once and reused, rather than hardcoded per widget.
- A recurring page layout pattern: a rounded, gradient header with an overlapping floating search bar, followed by filter chips, an optional inline error banner with retry, and a pull-to-refresh list.
- Reusable, section-based form styling (rounded white cards with an icon-labeled header, pill-shaped input fields with a leading icon, and consistent label typography) used by both the loan creation form and the loan editing screen, so that creating and editing a record feel like the same product rather than two different UIs bolted together.
- Defensive `mounted` checks before any `setState` or `ScaffoldMessenger` call that follows an `await`, to avoid calling into a disposed widget after navigation (e.g., a logout that clears the navigation stack while a request is still in flight).

## Getting Started

### Prerequisites

- Flutter SDK (stable channel)
- A Supabase project (URL and anon key)
- Android Studio / Xcode (or equivalent) for building to a physical device or emulator — camera access is required for the scanning feature, so a physical device is strongly recommended over an emulator for that flow.

### Installation

```bash
git clone <repository-url>
cd projeck_skripsi
flutter pub get
```

### Environment Configuration

The app expects Supabase credentials to be available at startup (via whichever mechanism is wired into the project's entry point — e.g., `--dart-define`, an `.env` file loaded before `Supabase.initialize`, or a checked-in config file excluded from version control). At minimum, the following values are required:

```
SUPABASE_URL=<your-supabase-project-url>
SUPABASE_ANON_KEY=<your-supabase-anon-key>
```

Do not commit real Supabase credentials to the repository.

## Supabase Configuration

The backend relies on Supabase for both data storage and authentication:

- **Authentication** uses email/password sign-in under the hood, with usernames mapped to a synthetic `username@siap.local` address so staff never need a real email account to use the app.
- **Row Level Security (RLS)** policies are expected to be configured on the loan records table so that:
  - Any authenticated user can read loan records and create new ones.
  - Only accounts with the admin role can update or delete existing records.
  - Return operations (single and bulk) are permitted for authenticated staff, distinct from full record edits.
- The client maintains an in-memory cache mirroring the last known Supabase state, primarily to keep list views responsive between explicit refreshes. Every screen that depends on cache freshness mattering (scanning, returning, editing) explicitly calls a refresh against Supabase first rather than trusting the cache blindly.

## Running the App

```bash
flutter run
```

To target a specific device:

```bash
flutter devices
flutter run -d <device-id>
```

For a release build:

```bash
flutter build apk --release
```

## Known Issues / Current Debugging Focus

These are the areas actively being tested and hardened at this stage of the project:

- **Cache/live-data consistency.** Several flows (scanning a document, opening the return screen, opening the history screen) were previously vulnerable to acting on stale local data when a record had been changed from another device or session. Explicit `refresh()` calls before critical reads (e.g., before evaluating a scanned QR code) have been added, but coverage is still being verified across every entry point.
- **Silent failures / error surfacing.** Backend errors (including cases surfaced as Supabase's `PGRST116`, typically indicating a query expected to match exactly one row but did not) previously failed without clear user-facing feedback in some flows. Try/catch coverage with explicit snackbar error messages has been added incrementally and is being verified page by page.
- **Double-submission protection.** Save/return/delete actions can be triggered more than once if a user taps a button multiple times before a request completes; guards (disabling buttons and showing loading state during in-flight requests) are being audited across all mutating actions.
- **`mounted` safety.** Any code path where a widget can be disposed mid-request (most notably: logging out, which wipes the navigation stack via `pushNamedAndRemoveUntil`, while an unrelated request from a previous screen is still awaiting a response) is being reviewed to ensure a `mounted` check guards every subsequent `setState` or `ScaffoldMessenger` call.
- **Loading and empty states.** Every list-backed screen (history, return, and by extension any future report views) is being checked to ensure it correctly distinguishes between "still loading," "loaded but empty," and "loaded but filtered to zero results," rather than collapsing them into one ambiguous state.
- **Cross-device/role testing.** Manual verification that RLS policies actually block disallowed operations at the database level, not just at the UI layer (i.e., confirming that a non-admin account cannot successfully call an edit/delete operation even by bypassing the UI).

## Roadmap

Planned or under consideration for after the current stabilization pass:

- Formal automated end-to-end test coverage for the core loan lifecycle (create, scan, return, edit, delete).
- Expanded reporting/export functionality for loan history (e.g., filtered exports for audits).
- Push or in-app notifications for loans approaching their return deadline, beyond the current in-app badge count.
- Android release hardening and packaging documentation.

## Design Notes

The visual identity intentionally references the physical, official character of land administration documents:

- The login screen uses a warm parchment color palette, custom Bezier-curve clipped shapes, and a government-seal-inspired layout, built with `google_fonts` for typography.
- The rest of the app uses a calmer, more utilitarian green-based palette (`#1B4332` / `#2D6A4F`) intended to read as trustworthy and institutional without feeling heavy, with rounded cards and pill-shaped inputs to keep dense administrative forms approachable on a small screen.
- A single `design.md` specification (generated from an initial set of UI screenshots/mockups) served as the source of truth for spacing, color, and component conventions used throughout the rest of the implementation, which is why form-style pages (loan creation and loan editing) intentionally share the same section-card and pill-input structure rather than diverging per screen.

## Project Context

This application was assigned as a project for Kantor Pertanahan (BPN) Kota Cilegon, with the goal of replacing the office's manual, paper-based loan logbook with a role-aware, auditable digital system. It builds on an earlier internship (PKL) project addressing the same problem domain for the same office, extended and hardened here into a more complete, production-oriented application backed by Supabase.
