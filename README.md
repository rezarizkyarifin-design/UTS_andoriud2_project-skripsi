# SIAP — Sistem Informasi Arsip Peminjaman (Temporary Name for the Application)

A mobile application for managing the loan and return of physical land record documents (buku tanah, surat ukur, and warkah) at a land office (Kantor Pertanahan), built with Flutter and Supabase. SIAP digitizes what was previously a manual, paper-based logbook process into a role-based, auditable digital workflow — including a two-step approval process for loan requests, per-document-type intake forms, and QR/barcode tracking for every document loan.

This repository is a project developed for Kantor Pertanahan (BPN) Kota Cilegon, built to digitize the office's existing manual loan/return process.

---

## Project Status

**Current phase: Internal testing and debugging.**

The core feature set described below is functionally complete — authentication, a two-step loan approval workflow, document-type-specific loan intake, QR/barcode generation, scanning-based returns, loan history with full approval/rejection/extension attribution, bulk returns, an in-app notification indicator, and profile management are all implemented end-to-end against a live Supabase backend. The current focus is stabilizing the application ahead of handover and deployment at the office:

- Manually testing every user flow across both roles (pegawai and admin), including the newer approval/rejection/extension paths.
- Reproducing and fixing runtime errors surfaced during real device testing (see [Known Issues](#known-issues--current-debugging-focus)).
- Verifying that Supabase Row Level Security (RLS) policies behave correctly under each role, especially around who can approve/reject a loan request.
- Checking edge cases around stale local cache vs. live Supabase state (e.g., a document being returned, or a request being approved, from a second device while the first device is idle).
- General UI polish and consistency passes across pages that were built at different points in the project timeline.

Unlike earlier in the project, the data model **has** continued to evolve during this stabilization phase — several columns (loan-request approval/rejection attribution, extension-approval attribution) were added after the fact via incremental SQL migrations once gaps were found between what the Dart service layer already wrote and what the database actually had columns for. Migrations are tracked as standalone `.sql` files rather than a formal migration tool at this stage.

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Application Modules](#application-modules)
4. [Roles and Permissions](#roles-and-permissions)
5. [Loan Request Lifecycle](#loan-request-lifecycle)
6. [Data Model](#data-model)
7. [Tech Stack](#tech-stack)
8. [Architecture and Project Structure](#architecture-and-project-structure)
9. [Getting Started](#getting-started)
10. [Supabase Configuration](#supabase-configuration)
11. [Running the App](#running-the-app)
12. [Known Issues / Current Debugging Focus](#known-issues--current-debugging-focus)
13. [Roadmap](#roadmap)
14. [Design Notes](#design-notes)
15. [Project Context](#project-context)

---

## Overview

Land offices maintain physical land record documents that must periodically be checked out by staff — for verification, legal processing, dispute resolution, or administrative review — and later returned. Historically, this loan/return cycle has been tracked in a physical logbook, which makes it difficult to:

- Know at a glance which documents are currently on loan and to whom.
- Identify overdue loans.
- Search historical loan records by employee, kecamatan (district), kelurahan (sub-district/village), land right type, or document type.
- Enforce accountability for who is allowed to submit, approve, reject, edit, or delete loan records — and to know exactly who made each of those decisions after the fact.

SIAP addresses this by providing:

- A structured, document-type-aware digital form for recording a new loan — Buku Tanah, Surat Ukur, or Warkah each collect their own type-specific fields on top of the shared borrower/location/date fields.
- A two-step approval workflow: a request submitted by regular staff (pegawai) starts as **pending** and must be reviewed and approved (or rejected, with a reason) by an admin before it becomes an active loan; a request submitted directly by an admin is auto-approved.
- An admin-facing checklist (document found, condition acceptable, details match) captured at the moment a request is approved.
- An automatically generated QR code for each approved loan, which can be printed and physically attached to the document for fast identification during the return process.
- A camera-based scanner (with a gallery fallback) that reads the QR code and immediately looks up the associated loan record, cross-checked against the latest data from Supabase rather than a potentially stale local cache.
- A searchable, filterable history/archive view of every loan — including full attribution for who approved it, who rejected it (and why), who approved any extension, and who processed its return.
- A dedicated return workflow with both single-item and multi-select bulk return actions, plus staff-initiated extension requests that admins can approve or reject.
- An in-app notification indicator that surfaces pending approval requests, pending extension requests, and overdue loans.

## Key Features

- **Document-type-aware loan intake form** covering three document types with their own fields:
  - **Buku Tanah**: jenis hak, nomor hak, kelurahan, nama, seksi, and the other shared fields.
  - **Surat Ukur**: jenis surat ukur, nomor & tahun surat ukur, SU, GS (Gambar Situasi), plus jenis hak / nomor hak.
  - **Warkah**: jenis warkah, No. 208, and tahun.
  - Shared across all three: cascading location selection (kecamatan → kelurahan), purpose field, and date pickers with sane defaults (a seven-day loan period, non-backdating validation on the return date).
- **Two-step approval workflow for new loan requests** — a pegawai's submission enters a `Diajukan` (pending) state; an admin reviews it (optionally cross-checking the archive for the document's current availability) and either approves it via a checklist (document found / condition OK / details match) or rejects it with a stated reason. A request submitted directly by an admin skips this and is created as an active loan immediately.
- **Full decision attribution**, surfaced directly in History/Return, not just stored silently in the database: who approved a request, who rejected it and why, who most recently approved a return-date extension, and who processed the eventual return — each shown as its own line/row wherever the loan appears.
- **Duplicate-loan prevention** — the app checks whether a given nomor hak already has an active (not yet returned) loan before allowing a new one to be created.
- **QR code generation** for every approved loan, rendered on a printable label alongside the borrower's name, kelurahan, land right type/number, and the loan/return dates.
- **Native print support** for the generated QR label, plus the ability to save/share it as an image.
- **Camera-based QR/barcode scanning** with a live camera preview, scanning frame and animated scan line, torch toggle, gallery fallback, and a live-data refresh before evaluating a scanned code so results reflect Supabase's current state rather than a stale local snapshot. *(The precise role this page plays in confirming a return — vs. just looking up status — is still being verified; see [Known Issues](#known-issues--current-debugging-focus).)*
- **Loan history / archive** with:
  - Free-text search across borrower name, kecamatan, kelurahan, and nomor hak.
  - Filters for kecamatan, kelurahan, land right type, jenis dokumen (Buku Tanah / Surat Ukur / Warkah), and loan status.
  - A persistent search bar (and, on History, the status filter chips) that stays reachable while scrolling instead of disappearing, with a lightweight collapsing header for the stat panel above it.
  - Four distinct status states — `Diajukan` (pending approval), `Dipinjam` (on loan, or `Terlambat` if overdue), `Kembali` (returned), and `Ditolak` (rejected) — each with its own label and color, rather than collapsing pending/rejected requests into a generic "returned" appearance.
  - Pull-to-refresh and explicit error/retry handling for failed data loads.
- **Loan extension requests** — staff can request a new return date on an active loan; admins approve or reject the request, with the approving admin's name recorded and surfaced the same way as initial-approval attribution.
- **Return workflow** with a dedicated "active loans" view, single-item return marking, and multi-select bulk return with a success/failure summary.
- **In-app notification indicator** — a bell icon with a badge, computed from the current local loan cache rather than a persisted notifications table or a true push notification. It surfaces pending approval and extension requests to admins, as well as overdue loans. Because it's derived from the cache rather than pushed, it reflects new activity from *other* devices/sessions only after the local cache is refreshed (app open, pull-to-refresh, etc.) — see [Known Issues](#known-issues--current-debugging-focus).
- **Role-based access control** is enforced both in the UI (which actions are shown/enabled) and at the data layer via Supabase RLS, so that non-admin accounts cannot approve, reject, edit, or delete records even if they attempt to call the underlying service methods directly.
- **Authentication** via Supabase Auth, using a synthetic `username@siap.app` email scheme so staff can log in with a plain username rather than a real email address.
- **Self-service password change** from the profile page (chosen deliberately over an emailed reset link, since the synthetic login address is not a real, reachable inbox).
- **Editable display name and contact email** — `nama` (display name) and a separate, genuinely real `contactEmail` (used for actual notifications/contact, distinct from the synthetic login address) can both be edited from the profile page. The login username itself is not currently editable from the app UI.
- **Profile page** showing the logged-in user's name, contact email, jabatan (position), and role, with a logout confirmation step.
- **Custom animated splash screen**, sequenced so the native (pre-Flutter-frame) splash is only removed once the custom splash's own first frame has actually painted — avoiding a blank-screen gap or a flash of two splash screens overlapping.
- **Onboarding flow** that only shows once per install (or on every hot restart in debug builds, for easier testing), with double-back-to-exit protection on the app's terminal screens (Onboarding, Login, Home) so the hardware back button doesn't accidentally exit the app on a single press.
- **Consistent navigation shell** across the app: a bottom navigation bar (Beranda / Arsip / Kembali / Profil) with a centrally docked floating action button for Scan, plus a side drawer for additional navigation.

## Application Modules

| Module | File | Description |
|---|---|---|
| Onboarding | `onboarding_page.dart`* | First-run introduction slides, shown once per install. |
| Login | `login_page.dart`* | Custom-designed authentication screen with a government-document aesthetic. |
| Sign Up | `signup_page.dart` | Self-registration for staff accounts — always creates a `pegawai` account; admin accounts are provisioned separately, never through self-service sign-up. |
| Splash | `splash_page.dart` | Animated intro screen shown on every cold start, before routing to Onboarding/Login/Home. |
| Home / Dashboard | `home_page.dart`* | Landing screen after login; entry point to the loan form, the approval checklist for pending requests, notifications, and the navigation shell. |
| Loan Form | `form_page.dart` | Document-type-aware form for recording a new document loan (Buku Tanah / Surat Ukur / Warkah). |
| QR / Barcode Result | `barcode_page.dart` | Displays the generated QR code for a just-approved loan, with print and share-as-image actions. |
| Scan | `scan_page.dart` | Camera-based QR/barcode scanner. |
| History / Archive | `history_page.dart` | Full loan history with search, filters, and full approval/rejection/return/extension attribution. |
| Return | `return_page.dart` | Focused view of currently active loans, with single and bulk return actions, and extension requests. |
| Profile | `profile_page.dart` | Account information (editable name and contact email), password change, and logout. |

\* Referenced by other pages via named routes; not all were part of the file set most recently reviewed.

## Roles and Permissions

The application recognizes two roles, enforced through `AuthService` and mirrored by Supabase RLS policies:

| Capability | Pegawai (Staff) | Admin |
|---|:---:|:---:|
| Submit a new loan request | Yes (enters `Diajukan`, pending review) | Yes (auto-approved, no review step) |
| Approve / reject a pending loan request | — | Yes |
| View loan history | Yes | Yes |
| Search / filter history | Yes | Yes |
| Scan a document to view its status | Yes | Yes |
| Mark a document as returned | Yes | Yes |
| Bulk-mark documents as returned | Yes | Yes |
| Request a loan extension | Yes | — |
| Approve / reject an extension request | — | Yes |
| Edit an existing loan record | — | Yes |
| Delete a loan record | — | Yes |
| Change own password | Yes | Yes |
| Change own display name / contact email | Yes | Yes |

## Loan Request Lifecycle

```
Pegawai submits         Admin reviews via         Approved → Dipinjam ──► Kembali
  a new request    ──►   checklist (found /   ──►                          (return processed,
  (status: Diajukan)     condition / matches)                               attributed to
                                               ──► Rejected → Ditolak        the processing admin)
                                                    (reason + admin
                                                     recorded)

Admin submits a request directly ──► Dipinjam immediately (no Diajukan step, auto-approved)

Active loan (Dipinjam) ──► Pegawai requests an extension ──► Admin approves
                                                              (new tanggal_kembali applied,
                                                               approving admin recorded)
                                                          ──► Admin rejects
```

Every transition that involves an admin decision — initial approval, rejection, extension approval, and return processing — records which admin made that decision, and (for rejection) why. This attribution is a single most-recent slot per loan record rather than a full change log: if a loan is extended more than once, only the most recent extension's approver is retained.

## Data Model

The central entity is `Peminjaman` (loan record).

**Shared / core fields:**

| Field | Type | Description |
|---|---|---|
| `id` | uuid | Primary key. |
| `nama` | String | Name of the borrowing staff member. |
| `seksi` | String | Seksi / unit kerja (section or work unit) the borrower belongs to. |
| `kecamatan` | String | District where the land record is administratively located. |
| `kelurahan` | String | Sub-district/village within the selected kecamatan. |
| `jenisHak` | String | Type of land right (e.g., Hak Milik, Hak Guna Bangunan, Hak Pakai). |
| `noHak` | String | Land right number — the primary human-readable identifier encoded into the QR code. |
| `keperluan` | String | Free-text purpose/reason for the loan. |
| `tanggalPinjam` | DateTime | Loan start date. |
| `tanggalKembali` | DateTime | Expected/actual return date (also the field updated when an extension is approved). |
| `status` | String | One of `Diajukan` (pending approval), `Dipinjam` (on loan), `Kembali` (returned), `Ditolak` (rejected). Overdue is a derived state (`Dipinjam` + past `tanggalKembali`), not its own status value. |
| `jenisDokumen` | String | `Buku Tanah` \| `Surat Ukur` \| `Warkah`. Rows created before this field existed default to `Buku Tanah`. |
| `diampuOleh` | uuid | The staff member (pegawai) this loan is associated with/processed by. |

**Jenis Dokumen–specific fields** (only populated for the matching `jenisDokumen`):

| Field | Applies to | Description |
|---|---|---|
| `jenisSuratUkur`, `noTahunSuratUkur`, `su`, `gs` | Surat Ukur | Jenis surat ukur, nomor & tahun, SU, and GS (Gambar Situasi). |
| `jenisWarkah`, `no208`, `tahunWarkah` | Warkah | Jenis warkah, No. 208, and tahun. |

**Attribution fields** (each nullable — only set once the corresponding event has happened):

| Field | Set when | Description |
|---|---|---|
| `disetujuiOleh` / `disetujuiOlehNama` | Request approved | The admin who approved a `Diajukan` request. Null for admin-submitted (auto-approved) loans. |
| `ditolakOleh` / `ditolakOlehNama` / `alasanPenolakan` | Request rejected | The admin who rejected the request, and the stated reason. |
| `perpanjanganDisetujuiOleh` / `perpanjanganDisetujuiOlehNama` | Extension approved | The admin who most recently approved an extension on this loan (single slot, overwritten on a later extension). |
| `kembaliOleh` / `kembaliOlehNama` | Return processed | The admin/staff member who marked the document as returned. |

**Extension state machine fields:**

| Field | Description |
|---|---|
| `extensionStatus` | `Diajukan` while an extension request is pending review, otherwise null. |
| `requestedTanggalKembali` | The new return date being requested, while `extensionStatus` is pending. |
| `extensionReason` | Staff-provided reason for the extension request. |

Reference/lookup data (kecamatan and kelurahan lists, land right types, and seksi/unit kerja options) is centralized in a static `Data` class, covering the full administrative breakdown for the relevant municipality (Kota Cilegon): 8 kecamatan and 43 kelurahan.

**User profile (`AppUser` / `profiles` table):**

| Field | Type | Description |
|---|---|---|
| `id` | uuid | Matches the Supabase Auth user id. |
| `nama` | String | Display name — editable from Profile, unrelated to login. |
| `username` | String | The full synthetic login address (`<handle>@siap.app`) used for Supabase Auth sign-in — not the same as `contactEmail`, and not currently user-editable from the app. |
| `role` | enum | `admin` \| `pegawai`. |
| `jabatan` | String | Position/title. |
| `contactEmail` | String? | A real, separate contact email address — nullable, since not everyone will have filled theirs in yet. Editable from Profile. |

## Tech Stack

| Layer | Technology |
|---|---|
| Client framework | Flutter |
| Backend / database | Supabase (PostgreSQL, Auth, Row Level Security) |
| Authentication | Supabase Auth (synthetic `@siap.app` email scheme for username-based login) |
| QR code generation | `qr_flutter` |
| QR/barcode scanning | `mobile_scanner` |
| Image selection (gallery scan fallback) | `image_picker` |
| Printing | Native platform print dialog via a dedicated `PrintingService` |
| Typography | `google_fonts` |
| Native splash coordination | `flutter_native_splash` |
| Local persistence (cached session/profile) | `shared_preferences` |
| State management | `StatefulWidget` + `setState`, with a service-layer in-memory cache mirroring Supabase reads |
| Testing | `flutter_test` (widget tests for the loan form and profile page; unit tests for filter logic) |

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
│   ├── peminjaman.dart           # Loan record model (fields, copyWith, formatting/attribution helpers)
│   ├── app_user.dart             # Logged-in user/profile model (nama, username, contactEmail, role, jabatan)
│   └── user_roles.dart           # UserRole enum + display label
├── routes/
│   └── app_routes.dart           # Named route constants and transition builder
├── screens/
│   └── services/
│       ├── auth_service.dart         # Supabase auth wrapper, role checks, password/name/email change
│       └── peminjaman_service.dart   # CRUD against Supabase + in-memory cache, approval/rejection/
│                                     # extension workflow, bulk operations, notification-feed queries
├── services/
│   └── printing_service.dart     # Print-dialog and share-as-image logic for QR labels
├── widgets/
│   ├── app_drawer.dart               # Shared side navigation drawer
│   ├── app_bottom_nav.dart           # Shared bottom navigation bar
│   ├── app_scan_fab.dart             # Shared docked floating action button for the Scan screen
│   ├── app_top_bar.dart              # Shared top bar (menu, title, notification bell, profile menu)
│   ├── notification_bell.dart        # Badge + dropdown surfacing pending approvals/extensions/overdue loans
│   ├── animated_terrain_bg.dart      # Reusable drifting-blob/grid backdrop (Login/SignUp)
│   ├── back_to_home.dart             # Redirects the back button to Home from deep-linkable screens
│   ├── double_back_to_exit.dart      # "Press again to exit" handling for terminal screens
│   └── jenis_dokumen_breakdown.dart  # Document-type count breakdown widget
└── screens/
    ├── onboarding/
    ├── auth/                     # Login, Sign Up
    ├── splash/
    ├── home/
    └── peminjaman/
        ├── form_page.dart
        ├── barcode_page.dart
        ├── history_page.dart
        ├── return_page.dart
        ├── scan_page.dart
        └── profile_page.dart

test/
├── peminjaman_filter_test.dart   # Unit tests for search/jenis-dokumen/status filter logic
├── form_page_test.dart           # Widget tests for the loan intake form
└── profile_page_test.dart        # Widget tests for the profile page / change-password dialog
```

Design conventions applied consistently across pages:

- A shared color palette (`primaryGreen` `#1B4332`, `accentGreen` `#2D6A4F`, plus semantic colors for overdue/pending/rejected/error states) defined once and reused, rather than hardcoded per widget.
- A recurring page layout pattern: a rounded, gradient header with an overlapping floating search bar, a collapsing behavior that keeps the search bar (and, on History, the status filter chips) reachable while scrolling rather than hiding them outright, an optional inline error banner with retry, and a pull-to-refresh list.
- Reusable, section-based form styling (rounded white cards with an icon-labeled header, pill-shaped input fields with a leading icon, and consistent label typography) shared across the loan creation form and other structured forms.
- Defensive `mounted`/`context.mounted` checks before any `setState`, `Navigator`, or `ScaffoldMessenger` call that follows an `await`, to avoid acting on a disposed widget or torn-down route — including after dialog dismissal, where a naive immediate `Navigator.pop()` was found to race a still-attached text-selection toolbar overlay and trip a `'_dependents.isEmpty'` framework assertion (see [Known Issues](#known-issues--current-debugging-focus)).

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

- **Authentication** uses email/password sign-in under the hood, with usernames mapped to a synthetic `<username>@siap.app` address so staff never need a real email account to use the app. (An earlier `@siap.local` scheme was replaced — `.local` is an IANA special-use TLD that Supabase's email validator rejects.)
- **Row Level Security (RLS)** policies are expected to be configured on the loan records table so that:
  - Any authenticated user can read loan records and create new ones (as a `Diajukan` request for pegawai, or directly as `Dipinjam` for admin).
  - Only accounts with the admin role can approve/reject a pending request, approve/reject an extension request, update, or delete existing records.
  - Return operations (single and bulk) are permitted for authenticated staff, distinct from full record edits.
- **Schema migrations** are plain `.sql` files run manually against the Supabase SQL editor as gaps are found (most recently: adding the approval/rejection/extension-approval attribution columns referenced above). Each ends with `NOTIFY pgrst, 'reload schema';` so PostgREST picks up new columns immediately rather than waiting for its next automatic cache refresh.
- The client maintains an in-memory cache mirroring the last known Supabase state, primarily to keep list views (and the notification badge) responsive between explicit refreshes. Every screen that depends on cache freshness mattering (scanning, returning, approving, editing) explicitly calls a refresh against Supabase first rather than trusting the cache blindly — though this is a pull/refresh model, not real-time push (see [Known Issues](#known-issues--current-debugging-focus)).

## Running the App

```bash
flutter run
```

To target a specific device:

```bash
flutter devices
flutter run -d <device-id>
```

To run the test suite:

```bash
flutter test
```

For a release build:

```bash
flutter build apk --release
```

## Known Issues / Current Debugging Focus

These are the areas actively being tested and hardened at this stage of the project:

- **Dialog-dismiss crash (`'_dependents.isEmpty': is not true`).** Several profile-page dialogs (change username/name, change contact email, change password) could crash on dismissal — both via their own buttons and via tapping outside the dialog — because popping the route raced a still-attached text-selection toolbar overlay on the `TextField` inside it. Fixed by disabling the in-app selection toolbar (`contextMenuBuilder`) on those fields and disabling barrier-tap-to-dismiss (`barrierDismissible: false`) on any dialog containing a `TextField`, rather than trying to time-delay around the race.
- **History status mislabeling (fixed).** The status label/color helpers in History predated the four-state (`Diajukan`/`Dipinjam`/`Kembali`/`Ditolak`) workflow and treated anything that wasn't `Dipinjam` as `Kembali` — so a request that had never been approved *or* rejected displayed as if it had already been returned. Fixed by handling all four statuses explicitly.
- **Missing attribution columns (fixed via migration).** `PeminjamanService`'s approval/rejection/extension-approval methods wrote to database columns that didn't exist yet, surfacing as `PGRST204` errors (or, worse, silently discarding the data client-side) until the corresponding `ALTER TABLE` migrations were run.
- **Scan page's exact role is still being verified.** It's confirmed to look up a scanned document's current status against live Supabase data, but whether/how it factors into confirming a return (versus that happening solely through the Return page) hasn't been independently verified yet.
- **Test suite gap:** the test file at `test/return_page.dart` currently contains a duplicate of `form_page_test.dart`'s content — it tests `FormPage`, not `ReturnPage`. There is currently no real widget test coverage for the Return page.
- **Notification badge is cache-derived, not real-time.** It's recomputed from whatever is in the local `PeminjamanService` cache, not pushed from the server — a new request submitted from a different device/session won't show up in another admin's badge count until that admin's app refreshes (app open, pull-to-refresh, etc.), not the moment it's submitted.
- **Cache/live-data consistency** more broadly — scanning, returning, approving, and editing all explicitly refresh against Supabase first rather than trusting the cache, but coverage is still being verified across every entry point.
- **Silent failures / error surfacing.** Backend errors (including `PGRST116`, typically a query expected to match exactly one row but didn't) are being audited page by page to ensure they surface as a clear user-facing message rather than failing silently.
- **Double-submission protection.** Save/approve/reject/return/delete actions can be triggered more than once if a button is tapped multiple times before a request completes; guards are being audited across all mutating actions.
- **`mounted` safety.** Any code path where a widget can be disposed mid-request (most notably: logout, which wipes the navigation stack) is being reviewed to ensure a `mounted`/`context.mounted` check guards every subsequent `setState`, `Navigator`, or `ScaffoldMessenger` call.
- **Loading and empty states.** Every list-backed screen is being checked to distinguish "still loading," "loaded but empty," and "loaded but filtered to zero results," rather than collapsing them into one ambiguous state.
- **Cross-device/role testing.** Manual verification that RLS policies actually block disallowed operations at the database level, not just at the UI layer.

## Roadmap

Planned or under consideration for after the current stabilization pass:

- Resolve the Return page test-coverage gap (`test/return_page.dart` currently duplicates the form-page test).
- Independently confirm the Scan page's exact role in the return-confirmation flow, and adjust/document it accordingly.
- Consider Supabase Realtime for the notification badge, so a pending request or extension shows up for admins on other devices without requiring a manual refresh.
- Replace the Home page's placeholder carousel images with real photos of the archive room ("Ruang Arsip") — documents, shelving, and overall layout.
- Decide whether Profile belongs in the bottom navigation bar long-term, or should move elsewhere in the navigation shell.
- Formal automated end-to-end test coverage for the full loan lifecycle (submit → approve/reject → scan → return → extension), not just isolated widget/unit tests.
- Expanded reporting/export functionality for loan history (e.g., filtered exports for audits).
- Android release hardening and packaging documentation.

## Design Notes

The visual identity intentionally references the physical, official character of land administration documents:

- The login screen uses a warm parchment color palette, custom Bezier-curve clipped shapes, and a government-seal-inspired layout, built with `google_fonts` for typography.
- The rest of the app uses a calmer, more utilitarian green-based palette (`#1B4332` / `#2D6A4F`) intended to read as trustworthy and institutional without feeling heavy, with rounded cards and pill-shaped inputs to keep dense administrative forms approachable on a small screen.
- The custom splash screen extends this identity to the app's cold-start moment — a forest-dark background, a gold ring that draws itself in around a map icon, and the same typography as the rest of the app — sequenced to hand off cleanly from the platform's native splash screen with no visible gap or overlap.
- A single `design.md` specification (generated from an initial set of UI screenshots/mockups) served as the source of truth for spacing, color, and component conventions used throughout the rest of the implementation, which is why form-style pages intentionally share the same section-card and pill-input structure rather than diverging per screen.

## Project Context

This application was assigned as a project for Kantor Pertanahan (BPN) Kota Cilegon, with the goal of replacing the office's manual, paper-based loan logbook with a role-aware, auditable digital system. It builds on an earlier internship (PKL) project addressing the same problem domain for the same office, extended and hardened here — most recently with the two-step approval workflow, per-document-type intake, and fuller decision attribution — into a more complete, production-oriented application backed by Supabase.
