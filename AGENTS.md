# AGENTS.md

This file provides guidance to AI coding agents when working with this repository.

## What is Sessy?

Sessy is an open-source email observability tool for AWS SES. It receives SNS webhook notifications from SES and displays email events (deliveries, bounces, complaints, opens, clicks) in a web interface. Inspired by 37signals' Fizzy.

## Commands

```bash
bin/setup              # Install deps, prepare database, start dev server
bin/dev                # Start development server (uses Procfile.dev)
bin/rails test         # Run all tests
bin/rails test test/models/event_searchable_test.rb  # Run single test file
bin/rails test test/models/event_searchable_test.rb:6  # Run single test method
bin/rails test:system  # Run system tests
bin/rubocop            # Lint (uses rubocop-rails-omakase)
bin/brakeman           # Security scan
bin/bundler-audit      # Gem vulnerability scan
bin/importmap audit    # JS dependency scan
```

## Database

Sessy supports both SQLite and PostgreSQL. The adapter is selected via:
- `DATABASE_ADAPTER` env var (`sqlite` or `postgresql`)
- Auto-detected from `DATABASE_URL` if it starts with `postgres`
- Defaults to SQLite

Config files: `config/database.sqlite.yml` and `config/database.postgresql.yml`

Git worktrees get isolated databases automatically via `config/git_worktree.rb` (appends worktree name as suffix).

## Architecture

### Core Domain Models

- **Source** - Represents an SES configuration set (e.g., "BetaList", "WIP"). Has a unique `token` used in webhook URLs. Includes retention policy for auto-deleting old data.
- **Message** - An email sent via SES, identified by `ses_message_id`. Stores subject, sender, and mail metadata.
- **Event** - A single SES event (Send, Delivery, Bounce, Complaint, etc.) for a specific recipient. Multiple events per message.
- **Webhook** - Raw SNS webhook payload, used for idempotent processing.
- **EventPayload** - Plain Ruby object that parses SES event JSON payloads.

### Data Flow

1. AWS SES sends SNS notification to `POST /webhooks/:source_token`
2. `WebhooksController` verifies SNS signature, creates `Webhook` record
3. `Webhook.process` parses the notification and calls `Event.ingest`
4. `Event::SnsIngestible` finds/creates `Message`, then creates `Event` records for each recipient

### Key Concerns

- `Event::SnsIngestible` - Ingests events from SNS payloads
- `Event::Filterable` - Date range and event type filtering scopes
- `Event::Searchable` - Search by recipient email or subject
- `Source::RetentionPolicy` - Auto-delete events older than N days
- `Authentication` - Optional HTTP Basic Auth via `HTTP_AUTH_USERNAME`/`HTTP_AUTH_PASSWORD` env vars

### Background Jobs

Uses Solid Queue. Recurring jobs defined in `config/recurring.yml`:
- `DeleteExpiredDataJob` - Runs daily, deletes messages/events past retention period

## Testing

Uses Minitest. Tests run in parallel. Fixtures in `test/fixtures/`.

CI runs tests against both SQLite and PostgreSQL via matrix strategy, plus one SaaS-mode leg (PostgreSQL).

## SaaS Mode

The `saas/` directory holds `sessy-saas`, a companion Rails engine for the hosted version of Sessy. It is loaded only when bundling with `Gemfile.saas`; the default `Gemfile` ignores it entirely, so open-source installs carry no hosted-only code. `Sessy.saas?` reports at runtime whether the engine is loaded.

`SESSY_MODE=saas` selects `Gemfile.saas` in the pre-boot entry points (`config/boot.rb`, `bin/setup`, `bin/ci`):

```bash
SESSY_MODE=saas bin/setup            # set up with the SaaS bundle
SESSY_MODE=saas bin/rails test test saas/test  # core + engine suites in SaaS mode
SESSY_MODE=saas bin/ci               # full local pipeline in SaaS mode
```

`Gemfile.saas.lock` must stay in sync with `Gemfile.lock`; run `bin/bundle-drift` to check and repair after changing the Gemfile.

Contributor policy: if the SaaS CI leg fails on an external contribution, fixing it is the maintainer's responsibility, not the contributor's.

## Event Types

SES event types handled: Send, Delivery, Bounce (with subtypes: Permanent, Transient, Undetermined), Complaint, DeliveryDelay, Subscription, Reject, Rendering Failure.
