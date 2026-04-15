# Production Plaid Configuration

This app is now set up to use a safer Plaid backend pattern:

- `client_id` stays on the backend
- `secret` stays on the backend
- `access_token` stays on the backend
- the Apple app should only receive a `link_token`, `item_id`, institution metadata, and transaction data

## Where to configure it

Create this file:

- `backend/.env`

You can start from:

- [backend/.env.example](/Users/nani/Documents/New%20project/backend/.env.example:1)

Recommended keys for limited production access:

```env
PLAID_ENV=production
PLAID_CLIENT_ID=your_client_id
PLAID_SECRET=your_secret
PLAID_PRODUCTS=transactions
PLAID_COUNTRY_CODES=US
PLAID_REDIRECT_URI=https://your-domain.com/plaid/
PLAID_WEBHOOK_URL=https://your-domain.com/api/plaid/webhook
PLAID_DATA_PATH=backend/data/plaid_items.json
PLAID_HOST=127.0.0.1
PLAID_PORT=8080
```

## Why these matter

- `PLAID_REDIRECT_URI`
  - Required for non-sandbox iOS Link flows
  - Must be registered in the Plaid Dashboard
  - Must match your app's Universal Link setup
- `PLAID_WEBHOOK_URL`
  - Recommended for transaction updates
  - Lets your backend react to Plaid transaction webhooks
- `PLAID_DATA_PATH`
  - Local storage location for linked Plaid Items during development

## Current backend endpoints

- `GET /health`
- `GET /api/plaid/items`
- `GET /plaid/link`
- `POST /api/plaid/link-token/create`
- `POST /api/plaid/item/public_token/exchange`
- `POST /api/plaid/transactions/sync`

## Secure flow

1. App asks backend for a `link_token`
2. App opens Plaid Link
3. Plaid Link returns a `public_token`
4. App sends `public_token` to backend
5. Backend exchanges it for an `access_token`
6. Backend stores the `access_token` under `backend/data/plaid_items.json`
7. App requests transaction sync by `item_id`

## Important note for your checking account

To connect your real checking account, we should use the real Plaid Link flow rather than the sandbox bootstrap button. The backend is now closer to that production-safe shape, but the Apple app still needs a LinkKit frontend integration for the actual user login flow.

## Mac-first validation flow

On macOS, the app now supports a browser-based Plaid Link entry:

1. Start the backend
2. Open the app
3. Go to `Transactions`
4. Click `Connect Checking Account`
5. Complete Plaid Link in your browser
6. Return to the app
7. Click `Refresh Linked Accounts`
8. Click `Sync Latest Account`

This keeps the real Plaid token exchange on the backend.
