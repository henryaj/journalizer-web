# Journalizer

Turn handwritten journal pages into digital text with AI-powered transcription. Sync directly to your Obsidian vault.

**Use the hosted version:** [journalizer.app](https://journalizer.app)

## SaaS vs Self-Hosted

| Feature | SaaS (journalizer.app) | Self-Hosted |
|---------|------------------------|-------------|
| Setup time | Instant | 30-60 minutes |
| Maintenance | We handle it | You handle it |
| Cost | $0.10/page | Your API costs (~$0.02-0.05/page) |
| Data location | Our servers (auto-deleted after 30 days) | Your infrastructure |
| Payments | Built-in credit system | Optional (can disable) |
| Updates | Automatic | Manual git pull |

## Self-Hosting

### Requirements

- Ruby 3.4+
- PostgreSQL 14+
- Node.js 18+ (for asset compilation)

### External Services

You'll need accounts with:

- **[HandwritingOCR.com](https://handwritingocr.com)** - OCR API for transcription
- **[Anthropic](https://anthropic.com)** - Claude API for post-processing
- **AWS S3** (or compatible) - Image storage
- **Google Cloud** (optional) - OAuth sign-in
- **Stripe** (optional) - Payment processing

### Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/henryaj/journalizer-web.git
   cd journalizer-web
   ```

2. **Install dependencies**

   ```bash
   bundle install
   ```

3. **Configure environment variables**

   Copy the example env file and fill in your values:

   ```bash
   cp .env.example .env
   ```

   Required variables:

   ```bash
   # Database
   DATABASE_URL=postgres://user:pass@localhost/journalizer

   # OCR & AI
   HANDWRITING_OCR_API_KEY=your_key
   ANTHROPIC_API_KEY=your_key

   # Storage (S3 or compatible)
   AWS_ACCESS_KEY_ID=your_key
   AWS_SECRET_ACCESS_KEY=your_secret
   AWS_BUCKET=your_bucket
   AWS_REGION=us-east-1

   # OAuth (optional - for Google sign-in)
   GOOGLE_CLIENT_ID=your_client_id
   GOOGLE_CLIENT_SECRET=your_secret

   # Payments (optional - for credit system)
   STRIPE_SECRET_KEY=your_key
   STRIPE_WEBHOOK_SECRET=your_secret
   STRIPE_PRICE_10=price_xxx
   STRIPE_PRICE_50=price_xxx
   STRIPE_PRICE_100=price_xxx
   ```

4. **Set up encryption keys**

   Generate encryption keys for ActiveRecord encryption:

   ```bash
   bin/rails db:encryption:init
   ```

   Add the output to your credentials file:

   ```bash
   bin/rails credentials:edit
   ```

   Paste the generated keys:

   ```yaml
   active_record_encryption:
     primary_key: <generated_key>
     deterministic_key: <generated_key>
     key_derivation_salt: <generated_salt>
   ```

   **Important:** Save your `config/master.key` securely. You'll need it for deployment.

5. **Set up the database**

   ```bash
   bin/rails db:create db:migrate
   ```

6. **Start the server**

   ```bash
   bin/dev
   ```

   The app will be available at `http://localhost:3456`

### Admin Commands

```bash
# Add credits to a user (for testing or manual grants)
bin/rails 'admin:add_credits[email@example.com,10]'

# Set up Stripe products (if using payments)
bin/rails admin:setup_stripe
```

### Deployment

The app is designed to run on any platform that supports Rails:

- **Heroku** - `git push heroku main`
- **Render** - Connect your repo
- **Fly.io** - `fly launch`
- **Docker** - Dockerfile included
- **VPS** - Standard Rails deployment with Puma

**Required for deployment:** Set `RAILS_MASTER_KEY` environment variable to the contents of `config/master.key`.

### Encryption

Journal content and user data are encrypted at rest using ActiveRecord encryption. The following fields are encrypted:

- **JournalEntry**: `title`, `content`
- **JobPage**: `raw_ocr_text`
- **User**: `email_address`, `name`, `stripe_customer_id`
- **Session**: `ip_address`

Encryption keys are stored in Rails credentials (encrypted with `RAILS_MASTER_KEY`). Keep your master key secure - losing it means losing access to all encrypted data.

## Development

```bash
# Run the server
bin/dev

# Run tests
bin/rails test

# Run linter
bin/rubocop
```

## License

MIT
