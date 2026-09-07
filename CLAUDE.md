# Journalizer Web

Rails 8 SaaS for transcribing handwritten journal entries via OCR.

Production: <https://journalizer.blmc.dev>, on the `hetzner` box.

## Deployment

Push to GitHub (`origin main`). `.github/workflows/ci.yml` runs the tests, builds
`ghcr.io/henryaj/journalizer-web:latest`, then opens an SSH session to
`deploy@hetzner`, which runs a forced command that pulls the new image and
restarts the compose project at `/opt/journalizer-web`. The workflow fails if the
box doesn't report back the digest it just pushed.

```bash
git push origin main
```

The `heroku` git remote is dead — the app has no dynos and no database there.
Don't push to it.

Rollback (as root on the box). `deploy-app.sh` tags the outgoing image
`:previous` before every pull, so going back one deploy needs no registry
credential:

```bash
cd /opt/journalizer-web
docker tag ghcr.io/henryaj/journalizer-web:previous ghcr.io/henryaj/journalizer-web:latest
docker compose up -d
```

To go further back, pull the sha tag CI pushed alongside `:latest` and re-tag
that instead, or re-run the last good workflow run (`gh run rerun <id>`).

See `henryaj/hetzner-infra` for how the deploy plane is put together.

## Key Commands

Run as root on the box; `journalizer-web` is the web container.

```bash
# Add credits to a user
docker exec journalizer-web bundle exec rake 'admin:add_credits[email@example.com,10]'

# Set up Stripe products (one-time)
docker exec journalizer-web bundle exec rake admin:setup_stripe

# Logs
docker compose -f /opt/journalizer-web/docker-compose.yml logs -f web worker
```

## Environment Variables

Live in `/opt/journalizer-web/.env` on the box (root-owned, 0600), read by both
the `web` and `worker` containers. Not in git.

- `RAILS_MASTER_KEY` - decrypts `config/credentials.yml.enc`
- `DATABASE_URL`, `POSTGRES_PASSWORD` - the `journalizer-postgres` container
- `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL` - Solid Cache / Solid Queue. Must
  point at databases *distinct* from `DATABASE_URL`, otherwise `db:prepare`
  never loads `db/cache_schema.rb` / `db/queue_schema.rb` and the app boots with
  the solid_cache/solid_queue tables missing (see `config/database.yml`)
- `APP_HOST` - hostname used for mailer URLs (`journalizer.blmc.dev`)
- `STRIPE_SECRET_KEY` - Stripe API key
- `STRIPE_WEBHOOK_SECRET` - Stripe webhook signing secret
- `STRIPE_PRICE_10`, `STRIPE_PRICE_50`, `STRIPE_PRICE_100` - Stripe price IDs
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` - Google OAuth
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_BUCKET`, `AWS_REGION` - S3 storage
- `HANDWRITING_OCR_API_KEY` - HandwritingOCR.com API key
- `ANTHROPIC_API_KEY` - Claude API for post-processing
- `POSTMARK_API_TOKEN` - transactional email
- `SENTRY_DSN` - error tracking
- `ADMIN_EMAILS`, `ADMIN_STATS_EMAIL` - admin access and the weekly stats digest
