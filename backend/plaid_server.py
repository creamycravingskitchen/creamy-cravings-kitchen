#!/usr/bin/env python3
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import date, timedelta
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import Request, urlopen
from pathlib import Path


def load_local_env():
    env_path = Path(__file__).with_name(".env")
    if not env_path.exists():
        return

    for line in env_path.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


load_local_env()


def plaid_base_url():
    environment = os.environ.get("PLAID_ENV", "sandbox").lower()
    if environment == "production":
        return "https://production.plaid.com"
    if environment == "development":
        return "https://development.plaid.com"
    return "https://sandbox.plaid.com"


def plaid_headers():
    return {
        "Content-Type": "application/json",
        "PLAID-CLIENT-ID": os.environ.get("PLAID_CLIENT_ID", ""),
        "PLAID-SECRET": os.environ.get("PLAID_SECRET", ""),
    }


def plaid_redirect_uri():
    return os.environ.get("PLAID_REDIRECT_URI")


def plaid_webhook_url():
    return os.environ.get("PLAID_WEBHOOK_URL")


def frontend_origin():
    return os.environ.get("PLAID_ALLOWED_ORIGIN", "*")


def plaid_data_path():
    return Path(os.environ.get("PLAID_DATA_PATH", "backend/data/plaid_items.json"))


def plaid_products():
    return [product.strip() for product in os.environ.get("PLAID_PRODUCTS", "transactions").split(",") if product.strip()]


def plaid_country_codes():
    return [code.strip() for code in os.environ.get("PLAID_COUNTRY_CODES", "US").split(",") if code.strip()]


def require_plaid_credentials():
    client_id = os.environ.get("PLAID_CLIENT_ID")
    secret = os.environ.get("PLAID_SECRET")
    if not client_id or not secret:
        raise ValueError("Set PLAID_CLIENT_ID and PLAID_SECRET before using the Plaid backend.")


def require_redirect_uri_for_non_sandbox():
    environment = os.environ.get("PLAID_ENV", "sandbox").lower()
    if environment != "sandbox" and not plaid_redirect_uri():
        raise ValueError("Set PLAID_REDIRECT_URI for development or production Link flows.")


def load_store():
    path = plaid_data_path()
    if not path.exists():
        return {"items": {}}
    return json.loads(path.read_text())


def save_store(store):
    path = plaid_data_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(store, indent=2))


def upsert_item(item_id, record):
    store = load_store()
    store.setdefault("items", {})[item_id] = record
    save_store(store)


def get_item_record(item_id):
    store = load_store()
    record = store.get("items", {}).get(item_id)
    if not record:
        raise ValueError(f"No stored Plaid item found for item_id '{item_id}'.")
    return record


def list_item_records():
    store = load_store()
    items = store.get("items", {})
    return [
        {
            "item_id": item_id,
            "institution_name": record.get("institution_name"),
            "created_at": record.get("created_at"),
            "last_cursor": record.get("cursor"),
        }
        for item_id, record in items.items()
    ]


def plaid_post(path, payload):
    body = json.dumps(payload).encode("utf-8")
    request = Request(
        f"{plaid_base_url()}{path}",
        data=body,
        headers=plaid_headers(),
        method="POST",
    )
    try:
        with urlopen(request) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        detail = error.read().decode("utf-8")
        raise ValueError(detail or str(error)) from error


def discover_institution():
    explicit = os.environ.get("PLAID_SANDBOX_INSTITUTION_ID")
    if explicit:
        return explicit, os.environ.get("PLAID_SANDBOX_INSTITUTION_NAME", "Configured Institution")

    if os.environ.get("PLAID_ENV", "sandbox").lower() == "sandbox":
        return "ins_109508", "First Platypus Bank"

    query = os.environ.get("PLAID_SANDBOX_INSTITUTION_QUERY", "Bank of America")
    response = plaid_post(
        "/institutions/search",
        {
            "query": query,
            "products": plaid_products(),
            "country_codes": plaid_country_codes(),
        },
    )
    institutions = response.get("institutions", [])
    if not institutions:
        raise ValueError(f"No institution found for query '{query}'.")

    institution = institutions[0]
    return institution["institution_id"], institution["name"]


def exchange_public_token(public_token):
    response = plaid_post("/item/public_token/exchange", {"public_token": public_token})
    return response["access_token"], response["item_id"]


def item_get(access_token):
    response = plaid_post("/item/get", {"access_token": access_token})
    return response.get("item", {})


def transactions_sync(access_token, cursor=None):
    payload = {"access_token": access_token}
    if cursor:
        payload["cursor"] = cursor

    added = []
    next_cursor = cursor
    has_more = True

    while has_more:
        if next_cursor:
            payload["cursor"] = next_cursor
        response = plaid_post("/transactions/sync", payload)
        added.extend(response.get("added", []))
        next_cursor = response.get("next_cursor")
        has_more = response.get("has_more", False)

    return {
        "transactions": [
            {
                "transaction_id": item.get("transaction_id"),
                "name": item.get("merchant_name") or item.get("name"),
                "date": item.get("authorized_date") or item.get("date"),
                "amount": item.get("amount"),
            }
            for item in added
        ],
        "cursor": next_cursor,
    }


def sync_transactions_for_item(item_id):
    record = get_item_record(item_id)
    sync = transactions_sync(record["access_token"], record.get("cursor"))
    record["cursor"] = sync["cursor"]
    upsert_item(item_id, record)
    return {
        "item_id": item_id,
        "institutionName": record.get("institution_name"),
        "transactions": sync["transactions"],
        "cursor": sync["cursor"],
    }


def html_response(title, body):
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title}</title>
  <style>
    body {{
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      background: linear-gradient(135deg, #f8f2eb, #ead9c4);
      color: #2b211c;
    }}
    main {{
      max-width: 760px;
      margin: 60px auto;
      padding: 32px;
      background: rgba(255,255,255,0.88);
      border-radius: 24px;
      box-shadow: 0 20px 60px rgba(59, 37, 21, 0.12);
    }}
    button {{
      border: 0;
      border-radius: 14px;
      padding: 14px 18px;
      background: #b34c23;
      color: white;
      font: inherit;
      font-weight: 700;
      cursor: pointer;
    }}
    .muted {{ color: #6c5545; }}
    .card {{
      margin-top: 18px;
      padding: 18px;
      background: #fff9f4;
      border-radius: 18px;
      border: 1px solid rgba(96, 69, 47, 0.1);
    }}
    code {{
      background: #f2e8dc;
      padding: 2px 6px;
      border-radius: 6px;
    }}
  </style>
  <script src="https://cdn.plaid.com/link/v2/stable/link-initialize.js"></script>
</head>
<body>
{body}
</body>
</html>"""


def create_sandbox_transactions(access_token):
    today = date.today()
    transactions = [
        {
            "amount": -1485.25,
            "date_posted": today.isoformat(),
            "date_transacted": today.isoformat(),
            "description": "Weekend Gelato Sales",
            "iso_currency_code": "USD",
        },
        {
            "amount": 276.40,
            "date_posted": (today - timedelta(days=1)).isoformat(),
            "date_transacted": (today - timedelta(days=1)).isoformat(),
            "description": "Dairy Supplier Expense",
            "iso_currency_code": "USD",
        },
        {
            "amount": -920.00,
            "date_posted": (today - timedelta(days=3)).isoformat(),
            "date_transacted": (today - timedelta(days=3)).isoformat(),
            "description": "Birthday Cake Order",
            "iso_currency_code": "USD",
        },
        {
            "amount": 118.65,
            "date_posted": (today - timedelta(days=4)).isoformat(),
            "date_transacted": (today - timedelta(days=4)).isoformat(),
            "description": "Packaging Expense",
            "iso_currency_code": "USD",
        },
    ]
    plaid_post(
        "/sandbox/transactions/create",
        {
            "access_token": access_token,
            "transactions": transactions,
        },
    )


class PlaidRequestHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._json(
                200,
                {
                    "configured": bool(os.environ.get("PLAID_CLIENT_ID") and os.environ.get("PLAID_SECRET")),
                    "environment": os.environ.get("PLAID_ENV", "sandbox"),
                    "products": plaid_products(),
                    "redirect_uri_configured": bool(plaid_redirect_uri()),
                    "webhook_url_configured": bool(plaid_webhook_url()),
                    "stored_items": len(list_item_records()),
                },
            )
            return

        if parsed.path == "/api/plaid/items":
            self._json(200, {"items": list_item_records()})
            return

        if parsed.path == "/plaid/link":
            require_plaid_credentials()
            require_redirect_uri_for_non_sandbox()
            page = html_response(
                "Connect Checking Account",
                f"""
                <main>
                  <p class="muted">Creamy Cravings Kitchen</p>
                  <h1>Connect your checking account</h1>
                  <p class="muted">This Mac-first flow opens Plaid Link in your browser. The backend keeps secrets and access tokens server-side.</p>
                  <div class="card">
                    <p><strong>Production note:</strong> institutions that require OAuth, including many large banks, need a working <code>PLAID_REDIRECT_URI</code> registered in the Plaid Dashboard.</p>
                  </div>
                  <div class="card">
                    <button id="connect">Open Plaid Link</button>
                    <p id="status" class="muted">Waiting to start…</p>
                  </div>
                </main>
                <script>
                  async function createLinkToken() {{
                    const response = await fetch('/api/plaid/link-token/create', {{
                      method: 'POST',
                      headers: {{ 'Content-Type': 'application/json' }},
                      body: JSON.stringify({{ client_name: 'Creamy Cravings Kitchen', client_user_id: 'mac-local-user' }})
                    }});
                    if (!response.ok) {{
                      throw new Error(await response.text());
                    }}
                    return response.json();
                  }}

                  async function exchangePublicToken(publicToken) {{
                    const response = await fetch('/api/plaid/item/public_token/exchange', {{
                      method: 'POST',
                      headers: {{ 'Content-Type': 'application/json' }},
                      body: JSON.stringify({{ public_token: publicToken }})
                    }});
                    if (!response.ok) {{
                      throw new Error(await response.text());
                    }}
                    return response.json();
                  }}

                  document.getElementById('connect').addEventListener('click', async () => {{
                    const status = document.getElementById('status');
                    status.textContent = 'Creating secure link token…';
                    try {{
                      const tokenResponse = await createLinkToken();
                      const handler = Plaid.create({{
                        token: tokenResponse.link_token,
                        onSuccess: async function(public_token, metadata) {{
                          status.textContent = 'Exchanging public token on backend…';
                          const exchange = await exchangePublicToken(public_token);
                          status.textContent = `Connected ${{exchange.institution_name || metadata.institution?.name || 'account'}}. Return to the app and click "Refresh Linked Accounts", then "Sync Latest Account".`;
                        }},
                        onExit: function(err) {{
                          status.textContent = err ? `Link exited: ${{err.display_message || err.error_message || 'Unknown error'}}` : 'Link closed.';
                        }}
                      }});
                      handler.open();
                    }} catch (error) {{
                      status.textContent = error.message;
                    }}
                  }});
                </script>
                """,
            )
            self._html(200, page)
            return

        self._json(404, {"error": "Not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        try:
            payload = self._body()
            require_plaid_credentials()

            if parsed.path == "/api/plaid/link-token/create":
                require_redirect_uri_for_non_sandbox()
                request_body = {
                    "client_name": payload.get("client_name", "Creamy Cravings Kitchen"),
                    "language": "en",
                    "country_codes": plaid_country_codes(),
                    "products": plaid_products(),
                    "user": {
                        "client_user_id": payload.get("client_user_id", "creamy-cravings-kitchen-user"),
                    },
                }
                redirect_uri = plaid_redirect_uri()
                webhook_url = plaid_webhook_url()
                if redirect_uri:
                    request_body["redirect_uri"] = redirect_uri
                if webhook_url:
                    request_body["webhook"] = webhook_url
                response = plaid_post(
                    "/link/token/create",
                    request_body,
                )
                self._json(200, response)
                return

            if parsed.path == "/api/plaid/item/public_token/exchange":
                access_token, item_id = exchange_public_token(payload["public_token"])
                item = item_get(access_token)
                record = {
                    "access_token": access_token,
                    "item_id": item_id,
                    "institution_id": item.get("institution_id"),
                    "institution_name": item.get("institution_name"),
                    "cursor": None,
                    "created_at": date.today().isoformat(),
                }
                upsert_item(item_id, record)
                self._json(
                    200,
                    {
                        "item_id": item_id,
                        "institution_name": record["institution_name"],
                    },
                )
                return

            if parsed.path == "/api/plaid/transactions/sync":
                if "item_id" in payload:
                    self._json(200, sync_transactions_for_item(payload["item_id"]))
                    return

                sync = transactions_sync(payload["access_token"], payload.get("cursor"))
                self._json(200, {"transactions": sync["transactions"], "cursor": sync["cursor"]})
                return

            if parsed.path == "/api/plaid/sandbox/bootstrap":
                institution_id, institution_name = discover_institution()
                public_token_response = plaid_post(
                    "/sandbox/public_token/create",
                    {
                        "institution_id": institution_id,
                        "initial_products": plaid_products(),
                        "options": {
                            "override_username": os.environ.get("PLAID_SANDBOX_USERNAME", "user_transactions_dynamic"),
                            "override_password": os.environ.get("PLAID_SANDBOX_PASSWORD", "pass_good"),
                        },
                    },
                )
                access_token, item_id = exchange_public_token(public_token_response["public_token"])
                create_sandbox_transactions(access_token)
                sync = transactions_sync(access_token)
                upsert_item(
                    item_id,
                    {
                        "access_token": access_token,
                        "item_id": item_id,
                        "institution_id": institution_id,
                        "institution_name": institution_name,
                        "cursor": sync["cursor"],
                        "created_at": date.today().isoformat(),
                    },
                )
                self._json(
                    200,
                    {
                        "institutionName": institution_name,
                        "itemId": item_id,
                        "transactions": sync["transactions"],
                    },
                )
                return

            self._json(404, {"error": "Not found"})
        except (ValueError, KeyError) as error:
            self._json(400, {"error": str(error)})
        except Exception as error:
            self._json(500, {"error": str(error)})

    def log_message(self, format, *args):
        return

    def _body(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def _json(self, status, payload):
        self.send_response(status)
        self._cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode("utf-8"))

    def _html(self, status, payload):
        self.send_response(status)
        self._cors_headers()
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(payload.encode("utf-8"))

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", frontend_origin())
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")


if __name__ == "__main__":
    host = os.environ.get("PLAID_HOST", "127.0.0.1")
    port = int(os.environ.get("PLAID_PORT", "8080"))
    server = HTTPServer((host, port), PlaidRequestHandler)
    print(f"Plaid backend listening on http://{host}:{port}")
    server.serve_forever()
