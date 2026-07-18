# Hosted launch runbook

Steps to turn app.sessy.do into the multi-tenant hosted edition. Maintainer-run; not part of the PR.

## Pre-deploy

1. **Verify the SES sending identity** for `MAILER_FROM_ADDRESS` (e.g. `hello@sessy.do`) and send a test email — magic codes and approval notices can't ship without it.
2. **Store SES sending credentials** in Kamal secrets (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) or attach a host IAM role.
3. **Set `MISSION_CONTROL_USERNAME` / `MISSION_CONTROL_PASSWORD`** on the hosted env. In hosted mode `/jobs` is locked with unguessable credentials until these are set.
4. **Set `APP_HOST=app.sessy.do`** so email links resolve.
5. Confirm `config/deploy.saas.yml` carries `builder.args.BUNDLE_GEMFILE: Gemfile.saas`.
6. **Rehearse the migration** against a copy of the production database (`bin/rails db:migrate` on the copy) and confirm every source ends up owned by the instance account with history intact.

## Deploy

7. `kamal deploy -c config/deploy.saas.yml`. The container runs the migration on boot: existing sources land in the auto-created **instance account**, already approved with unlimited retention, so **webhook ingest never pauses**.
   - Do not create sources during the deploy window — the old container can't satisfy the new `NOT NULL account_id`. Ingest (events/messages) is unaffected.

## Claim

8. `bin/rails "saas:claim[you@example.com]"` — attaches your user + owner membership to the instance account (which owns all migrated data). Idempotent.
9. Sign in at `app.sessy.do` with the magic code, confirm your sources and history are present and webhook URLs still work.

## Finalize

10. **Retire `HTTP_AUTH_USERNAME` / `HTTP_AUTH_PASSWORD`** from the hosted env last — magic-code auth has replaced them and the hosted app ignores them.

## Approving new signups

New accounts land pending. Approve from the console:

```ruby
Account.find_by!(name: "Casey's Sessy").approve!   # sends the approval email
```

## Abuse response

Approval is otherwise permanent; to cut off an abusive account:

```ruby
account = Account.find(...)
account.update!(approved_at: nil)   # re-gates the UI and stops webhook ingest (404s)
account.sources.destroy_all         # escalation: drop their sources entirely
```
