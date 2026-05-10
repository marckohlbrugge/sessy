# SES Security and Deliverability Best Practices

These practices help protect your SES reputation and keep Sessy event data healthy.

## Protect endpoints that can trigger emails

- Add rate limits on signup, password reset, magic link, contact, and invite endpoints.
- Add bot protection (for example Turnstile or reCAPTCHA) on public forms.
- Require explicit opt-in for newsletter-style flows.

Goal: prevent abuse that can cause bounce/complaint spikes.

## Keep bounce and complaint rates low

SES enforces strict thresholds. High rates can lead to throttling or account suspension.

- Do not repeatedly send to addresses that already bounced or complained.
- Maintain a suppression list in your app.
- Process bounce/complaint events quickly.

## Isolate projects where practical

If you run multiple products:

- Prefer separate configuration sets per project.
- Use separate IAM identities for sending credentials.
- Keep event routing explicit so each product has clear ownership.

## Verify DNS and authentication

For each sending domain:

- Domain identity verified.
- DKIM enabled and verified.
- SPF configured.
- DMARC configured.
- Optional custom `MAIL FROM` domain configured for stronger alignment.

## Secure your Sessy deployment

- Enable HTTPS.
- Protect the dashboard with authentication (`HTTP_AUTH_USERNAME` / `HTTP_AUTH_PASSWORD`) or your own auth layer.
- Keep webhook endpoint public only where required for SNS, while securing everything else.
- Keep dependencies and base images updated.

## Monitor continuously

- Watch bounce and complaint trends in Sessy.
- Alert when rates move outside normal ranges.
- Investigate unusual spikes quickly (list quality, abuse, bad imports, or integration bugs).

## Managed setup (future)

A managed Sessy experience can automate large parts of this checklist. Until then, this page acts as the operational baseline for self-hosted deployments.
