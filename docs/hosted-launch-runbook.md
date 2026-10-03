# Hosted launch runbook

Steps to turn app.sessy.do into the multi-tenant hosted edition. Maintainer-run; not part of the PR.

## Pre-deploy

1. **Verify the SES sending identity** for `MAILER_FROM_ADDRESS` (e.g. `hello@sessy.do`) and send a test email — magic codes and welcome emails can't ship without it.
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

## Setup nudge

`Sessy::Saas::SetupNudge.deliver_due` emails each hosted account once, two days after approval, if none of its sources has received an SES event yet (`sources.first_event_at`). The copy matches the stall point: no source, source without a confirmed SNS subscription, or SNS confirmed without events. Replies go to `ADMIN_EMAIL`. It runs from the `setup_nudge` entry in `config/recurring.yml` every day at 10:00 UTC, and the first run has no age cutoff, so it reaches every account that was already stalled.

**Preview before the first run.** The schedule ships with the code, so deploy it after 10:00 UTC and review the cohort in the console before the next morning:

```ruby
Sessy::Saas::SetupNudge.eligible_accounts.pluck(:name, :approved_at)
```

Every name on that list gets exactly one email. Check it against what you know: a real customer who went quiet long enough for retention to delete their events must already carry a hand-stamped `first_event_at` on a source (see the retention note below), and internal or test accounts you never want to nudge can be opted out by stamping them as already sent:

```ruby
Account.find_by!(name: "...").update!(setup_nudge_sent_at: Time.current)
```

`Sessy::Saas::SetupNudge.variant_for(account)` shows which copy an account would get. To hold the run entirely, remove the `setup_nudge` entry from `config/recurring.yml` before deploying; there is no runtime switch.

Retention note: `first_event_at` is stamped on ingest and was backfilled once from surviving messages and events. A source whose data had already aged out of retention when the backfill ran looks like it never received an event, so stamp it by hand (`source.update!(first_event_at: source.created_at)`) before the nudge is live.

## Publishing the Launch Stack template

The Setup page's Launch Stack button opens a CloudFormation quick-create form whose `templateURL` must be an S3 URL. The template is committed at `config/cloudformation/sessy-ses.yml` and runs inside customers' AWS accounts, so the bucket is a supply-chain surface: every published key is write-once and a changed template always ships under a new key.

One-time bucket setup (`sessy-cloudformation`, `us-east-1`; one bucket serves every stack region):

```bash
aws s3api create-bucket --bucket sessy-cloudformation --region us-east-1
aws s3api put-bucket-versioning --bucket sessy-cloudformation --versioning-configuration Status=Enabled
# Public reads of objects only; no public ACLs or listing.
aws s3api put-public-access-block --bucket sessy-cloudformation \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false
aws s3api put-bucket-policy --bucket sessy-cloudformation --policy '{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "PublicRead", "Effect": "Allow", "Principal": "*", "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::sessy-cloudformation/*" },
    { "Sid": "WriteOnce", "Effect": "Deny", "Principal": "*", "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::sessy-cloudformation/*",
      "Condition": { "Null": { "s3:if-none-match": "true" } } }
  ]
}'
```

The `WriteOnce` statement denies any `PutObject` that does not carry `If-None-Match: *`, so an existing key can never be overwritten, even by the account owner.

Publishing a version:

```bash
aws cloudformation validate-template --template-body file://config/cloudformation/sessy-ses.yml
aws s3api put-object --bucket sessy-cloudformation --key v1/sessy-ses.yml \
  --body config/cloudformation/sessy-ses.yml --content-type text/yaml --if-none-match '*'
shasum -a 256 config/cloudformation/sessy-ses.yml
```

Then:

1. Set `CLOUDFORMATION_TEMPLATE_URL` on the hosted env (or update the default in `config/application.rb`) to `https://sessy-cloudformation.s3.us-east-1.amazonaws.com/<key>`.
2. Record the digest in `PUBLISHED_TEMPLATE_SHA256` in `test/cloudformation_template_test.rb`. That test fails whenever the committed template drifts from the published one, and in CI it also fetches the published URL and compares digests, which is the check that notices a swapped object.
3. For a template change: bump the key (`v2/sessy-ses.yml`), publish, then repeat steps 1 and 2. Never delete or replace an old key while stacks may still reference it.

Before the first production launch, create one stack from the published URL in a sandbox account (Setup page → Launch Stack) and confirm: the stack reaches `CREATE_COMPLETE` with no capabilities prompt; the webhook receives and confirms the `SubscriptionConfirmation`; whether the quick-create form prefills a `NoEcho` parameter (if so, mark `WebhookUrl` as `NoEcho: true` in the next template version); and that the quick-create link survives the console sign-in redirect from a signed-out browser.

## Suspending accounts

Signups are approved on the spot: `Signup#complete` creates the account with `approved_at` set and a first source named "Production", redirects the user to that source's Setup page, and sends the welcome email with the same link. Nobody is pending any more; `approved_at` is now the suspension switch. The Stripe checkout with a free trial is the planned abuse control; until it ships, suspension is by hand.

With `ADMIN_EMAIL` set on the hosted env, each signup emails the operator an FYI linking to the admin account page (`/admin/approval?token=...`, a signed token valid for 30 days). That page has a **Suspend account** button: it nulls `approved_at`, so signed-in users see only the "this account is paused" page and the account's webhooks return 404, stopping ingest immediately. Nothing is deleted. **Restore account** on the same page sets `approved_at` again and re-sends the welcome email.

Console equivalents (also for links older than 30 days):

```ruby
account = Account.find_by!(name: "Casey's Sessy")
account.update!(approved_at: nil)   # suspend: paused page + webhooks 404
account.approve!                    # restore: re-sends the welcome email
account.sources.destroy_all         # escalation: drop their sources entirely
```

### One-off after deploying auto-approval

Accounts that signed up under manual approval and were never let in still have `approved_at: nil`, and nothing emails the operator about them any more. Under the old flow that same state also meant "suspended for abuse", so review the list before approving anything. In the production console right after the deploy:

```ruby
# 1. List the candidates: accounts with an owner but no approval.
pending = Account.where(approved_at: nil, instance: false).joins(:users).distinct
pending.each { |a| puts [ a.id, a.name, a.created_at.to_date, a.users.first.email_address ].join("  ") }

# 2. Approve the ones that were merely waiting; leave out any you suspended on purpose.
pending.where.not(id: [ ]).find_each(&:approve!)   # fill in the ids to skip
```

Each approved account gets the welcome email (with a sign-in link, since they have no source yet). Accounts with no users were abandoned mid-signup and stay as they are.
