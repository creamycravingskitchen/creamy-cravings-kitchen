# Creamy Cravings Kitchen Product Context

This app is being built as a professional finance and operations tool for `Creamy Cravings Kitchen`.

## Current product scope

- `Upload Receipt`
  - Upload an image or PDF receipt
  - Capture a photo using camera on iPhone
  - Mac flow should support a polished receipt capture/import experience
- `Transactions`
  - Use Plaid to connect to a Bank of America checking account
  - Import transactions into the app
- `Sales`
  - Derive sales from imported transactions
  - Show sales date-wise
  - Group sales by month
  - Show complete sales for a given month
- `Expenses`
  - Derive expenses from imported transactions
  - Show expenses date-wise
  - Group expenses by month
  - Show complete expenses for a given month

## Product direction

- Remove generic starter content
- Keep the app professional from day one
- Future work should preserve this feature direction unless explicitly changed
- Plaid secrets must stay on a backend, not inside the Apple app
