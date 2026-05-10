# AWS SES Setup for Sessy

This guide covers the recommended way to configure AWS SES so events flow into Sessy reliably.

If you already have a running Sessy instance, you can also open the in-app setup tab for a source and follow the short version there.

## 1) Request SES production access

New SES accounts start in sandbox mode. Request production access first.

- Sandbox limits sending to verified recipients only.
- Approval usually takes 24-48 hours.
- Region choice can affect approval speed. In practice, some people get approved faster in EU regions.
- You can still send to recipients globally after approval.

AWS CLI:

```bash
REGION="eu-west-1"

aws sesv2 put-account-details \
  --production-access-enabled \
  --mail-type TRANSACTIONAL \
  --use-case-description "Transactional email sending for app users who explicitly signed up." \
  --region "$REGION"
```

Verify:

```bash
aws ses get-account-sending-enabled --region "$REGION"
aws ses get-send-quota --region "$REGION"
```

## 2) Verify your sending domain

In AWS SES:

1. Add your domain identity.
2. Publish the SES TXT verification record in your DNS provider.
3. Enable DKIM and publish the 3 CNAME records.
4. Wait for verification status to show `Success`.

Recommended extras for deliverability:

- Configure a custom `MAIL FROM` domain.
- Add SPF and DMARC records for your domain.

AWS CLI:

```bash
REGION="eu-west-1"
DOMAIN="example.com"
MAIL_FROM_DOMAIN="mail.$DOMAIN"

# Create identity + get TXT token for DNS verification
aws ses verify-domain-identity --domain "$DOMAIN" --region "$REGION"
aws ses get-identity-verification-attributes --identities "$DOMAIN" --region "$REGION"

# Enable DKIM and fetch DKIM CNAME tokens
aws ses verify-domain-dkim --domain "$DOMAIN" --region "$REGION"
aws ses get-identity-dkim-attributes --identities "$DOMAIN" --region "$REGION"

# Optional but recommended: custom MAIL FROM
aws ses set-identity-mail-from-domain \
  --identity "$DOMAIN" \
  --mail-from-domain "$MAIL_FROM_DOMAIN" \
  --region "$REGION"
aws ses get-identity-mail-from-domain-attributes --identities "$DOMAIN" --region "$REGION"
```

## 3) Create a configuration set

In SES:

1. Go to Configuration sets.
2. Create a new set (for example `myapp-transactional`).
3. Keep defaults unless you have advanced requirements.

Sessy relies on this configuration set to receive lifecycle events (deliveries, bounces, complaints, opens, clicks, and more).

AWS CLI:

```bash
REGION="eu-west-1"
CONFIG_SET="myapp-transactional"

aws ses create-configuration-set \
  --configuration-set "{\"Name\": \"$CONFIG_SET\"}" \
  --region "$REGION"
```

Verify:

```bash
aws ses describe-configuration-set \
  --configuration-set-name "$CONFIG_SET" \
  --region "$REGION"
```

## 4) Create an SNS topic and webhook subscription

In AWS SNS:

1. Create a standard topic (not FIFO).
2. Create an HTTPS subscription to your Sessy webhook URL:
   - Format: `https://your-sessy-domain.com/webhooks/<source-token>`
3. Confirm the subscription.

In SES Configuration Set:

1. Add an event destination.
2. Destination type: SNS.
3. Select event types you want (typically all supported types).
4. Choose your topic.

AWS CLI:

```bash
REGION="eu-west-1"
CONFIG_SET="myapp-transactional"
TOPIC_NAME="sessy-events-myapp"
WEBHOOK_URL="https://your-sessy-domain.com/webhooks/<source-token>"
ACCOUNT_ID="123456789012"
TOPIC_ARN="arn:aws:sns:$REGION:$ACCOUNT_ID:$TOPIC_NAME"

# Create SNS topic
aws sns create-topic --name "$TOPIC_NAME" --region "$REGION"

# Subscribe Sessy webhook
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol https \
  --notification-endpoint "$WEBHOOK_URL" \
  --region "$REGION"

# Connect configuration set to SNS topic
aws ses create-configuration-set-event-destination \
  --configuration-set-name "$CONFIG_SET" \
  --event-destination "{
    \"Name\": \"sessy-events\",
    \"Enabled\": true,
    \"MatchingEventTypes\": [\"bounce\", \"click\", \"complaint\", \"delivery\", \"deliveryDelay\", \"open\", \"reject\", \"renderingFailure\", \"send\", \"subscription\"],
    \"SNSDestination\": { \"TopicARN\": \"$TOPIC_ARN\" }
  }" \
  --region "$REGION"
```

Verify:

```bash
aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --region "$REGION"
aws ses describe-configuration-set \
  --configuration-set-name "$CONFIG_SET" \
  --configuration-set-attribute-names eventDestinations \
  --region "$REGION"
```

## 5) Send with the configuration set enabled

Your app must send mail with the SES configuration set name.

For Rails mailers, this is usually done by setting the `X-SES-CONFIGURATION-SET` header globally in `ApplicationMailer` or per-message.

## 6) Verify end-to-end

After sending a test email through SES with the configuration set:

- Open your source in Sessy.
- Go to Activity.
- Confirm you see `Send` and follow-up events (`Delivery`, `Bounce`, etc.).

If no events appear:

- Re-check SNS subscription status.
- Re-check configuration set destination and event types.
- Confirm your app is actually sending with that configuration set.

Useful checks:

```bash
aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --region "$REGION"
aws ses describe-configuration-set \
  --configuration-set-name "$CONFIG_SET" \
  --configuration-set-attribute-names eventDestinations trackingOptions \
  --region "$REGION"
```

## Region and account notes

- SES region can matter for setup details and quotas.
- You can send email to global recipients regardless of your SES region.
- If a production access request is rejected in one region, trying a different region can work.

## Next step

After baseline setup works, review [SES Security and Deliverability Best Practices](ses-security-best-practices.md).
