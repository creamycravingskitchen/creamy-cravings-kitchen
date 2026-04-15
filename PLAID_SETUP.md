# Plaid Setup

This project now includes a lightweight local backend at `backend/plaid_server.py`.

## Why a backend is required

Plaid `client_id`, `secret`, and `access_token` should not live in the iPhone or Mac app. The backend owns:

- `/link/token/create`
- `/item/public_token/exchange`
- `/transactions/sync`

This matches Plaid's official API flow.

## Local sandbox setup

1. Get Sandbox credentials from the Plaid Dashboard.
2. Start the backend:

```bash
export PLAID_ENV=sandbox
export PLAID_CLIENT_ID=your_client_id
export PLAID_SECRET=your_secret
python3 backend/plaid_server.py
```

3. Open the app.
4. In `Transactions`, use `Check Backend` and then `Load Sandbox Transactions`.

## Sandbox behavior

- The backend now defaults to Plaid Sandbox institution `First Platypus Bank` (`ins_109508`)
- It uses sandbox test credentials `user_transactions_dynamic` and `pass_good`
- It also seeds a few custom sandbox transactions through Plaid's Sandbox API before syncing
- This is intentional because Sandbox transaction testing works best with Plaid's test institutions and users, not a real Bank of America institution search

## Current app behavior

- The app talks to `http://127.0.0.1:8080`
- `Load Sandbox Transactions` asks the backend to create a Sandbox Item and sync transactions
- The backend stores the `access_token` locally under `backend/data/plaid_items.json`
- The app only receives an `item_id` plus transaction data
- The imported transactions replace the sample feed in-app
- On macOS, `Connect Checking Account` opens a browser-based Plaid Link flow backed by your local server

## Next implementation steps

- Add Plaid LinkKit to the iOS target
- Use `/api/plaid/link-token/create` from the app
- Exchange the returned `public_token` through the backend
- Persist the Plaid `access_token` server-side in encrypted or secret-managed storage for deployed environments
- Use `/transactions/sync` for incremental refreshes
