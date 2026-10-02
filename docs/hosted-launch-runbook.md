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

Before the first production launch, create one stack from the published URL in a sandbox account (Setup page → Launch Stack) and confirm: the stack reaches `CREATE_COMPLETE` with no capabilities prompt; the webhook receives and confirms the `SubscriptionConfirmation`; whether the quick-create form prefills a `NoEcho` parameter (if so, mark `WebhookUrl` as `NoEcho: true` in the next template version); whether event payloads include original email headers (the Setup page currently says this must be enabled in the console); and that the quick-create link survives the console sign-in redirect from a signed-out browser.

## Approving new signups

New accounts land pending. With `ADMIN_EMAIL` set on the hosted env, each signup emails the operator a one-click approval link (`/admin/approval?token=...`, a signed token valid for 30 days). Approving — via the link or the console — sends the user a welcome email with getting-started instructions.

Console fallback:

```ruby
Account.find_by!(name: "Casey's Sessy").approve!   # sends the approval email
```

To re-send the notification for every account still pending (signed up before `ADMIN_EMAIL` was set, or the email got lost):

```bash
kamal app exec -c config/deploy.saas.yml "bin/rails saas:notify_pending"
```

## Abuse response

Approval is otherwise permanent; to cut off an abusive account:

```ruby
account = Account.find(...)
account.update!(approved_at: nil)   # re-gates the UI and stops webhook ingest (404s)
account.sources.destroy_all         # escalation: drop their sources entirely
```
