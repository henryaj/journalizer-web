# Journalizer Web

Rails 8 SaaS for transcribing handwritten journal entries via OCR.

## Deployment

Push to GitHub (`origin main`) - Heroku auto-deploys from the `main` branch.

```bash
git push origin main
```

Do NOT push directly to Heroku.

## Key Commands

```bash
# Add credits to a user
heroku run rake 'admin:add_credits[email@example.com,10]'

# Set up Stripe products (one-time)
heroku run rake admin:setup_stripe
```

## Environment Variables (Heroku)

- `STRIPE_SECRET_KEY` - Stripe API key
- `STRIPE_WEBHOOK_SECRET` - Stripe webhook signing secret
- `STRIPE_PRICE_10`, `STRIPE_PRICE_50`, `STRIPE_PRICE_100` - Stripe price IDs
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` - Google OAuth
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_BUCKET`, `AWS_REGION` - S3 storage
- `HANDWRITING_OCR_API_KEY` - HandwritingOCR.com API key
- `ANTHROPIC_API_KEY` - Claude API for post-processing
