# StreamOne Ion API — Shell Scripts

A collection of Bash scripts for interacting with the **TD Synnex StreamOne Ion API**. Use them to pull subscription data, pricing, and customer information and optionally export everything to CSV.

---

## Requirements

| Tool | Purpose |
|------|---------|
| `bash` | Run the scripts (pre-installed on macOS/Linux) |
| `curl` | Make HTTP requests (pre-installed on macOS/Linux) |
| `jq` | Parse JSON responses — **required** |

Install `jq` on macOS:

```bash
brew install jq
```

---

## Setup

1. Copy the sample environment file and fill in your credentials:

```bash
cp .env-sample .env
```

2. Edit `.env` with your TD Synnex credentials:

```env
TD_SYNNEX_API_KEY=""
TD_SYNNEX_API_SECRET=""
TD_SYNNEX_BASE_URL="https://ion.tdsynnex.com/api/v1"
TD_SYNNEX_ACCESS_TOKEN=""
TD_SYNNEX_REFRESH_TOKEN=""
TD_SYNNEX_ACCOUNT_ID=""
```

3. Make the scripts executable:

```bash
chmod +x *.sh
```

> **Note:** Never commit your `.env` file. It contains sensitive credentials and is excluded from version control.

---

## Scripts

### `get_products_simple.sh` — Subscription overview

Lists all subscriptions across all customers, showing status, quantity, price, cost, margin, currency, and renewal date.

```bash
# Print to terminal
./get_products_simple.sh

# Export to a timestamped CSV file
./get_products_simple.sh --csv

# Export to a specific CSV file
./get_products_simple.sh --csv my_report.csv
```

**Output columns:** Customer | Subscription | Status | Qty | Price | Cost | Margin | Currency | Renewal Date

This script uses the **v3 API** with OAuth Bearer tokens. If the access token is expired, it automatically refreshes it using the refresh token and updates `.env` in place.

---

### `api.sh` — General-purpose API client

A flexible client for exploring the API. Useful for ad-hoc queries and discovering available endpoints.

```bash
./api.sh customers          # List all customers/partners
./api.sh products           # List available products
./api.sh orders             # List recent orders
./api.sh inventory <SKU>    # Check inventory for a specific SKU
./api.sh health             # Check API connectivity
./api.sh get <path>         # Custom GET request to any endpoint
./api.sh help               # Show usage information
```

**Examples:**

```bash
./api.sh get customers
./api.sh get products?limit=10
./api.sh inventory MS-OFFICE-365-E3
```

This script uses **Basic Auth** (API key + secret) against the v1 API.

---

### `get_full_report.sh` — Customer cloud account summary

Lists all customers with their associated cloud accounts, providers, and price book IDs.

```bash
./get_full_report.sh
```

**Output columns:** Customer | Company | Product/Provider | Cloud Account ID | Price Book ID

---

### `get_customer_products.sh` — Customer products and pricing

Lists all products and their prices for each customer.

```bash
./get_customer_products.sh
```

**Output columns:** Customer | Product/Plan | Provider | Price | Currency

---

### `get_full_pricing.sh` — Detailed pricing per customer (one product per customer)

Lists each customer's cloud account with the first product and price from their assigned price book.

```bash
./get_full_pricing.sh
```

**Output columns:** Customer | Company | Provider | Cloud Account | Product | Price | Currency

---

### `get_full_pricing_all.sh` — Full pricing per customer (all products)

Same as `get_full_pricing.sh`, but lists **all** products from each customer's price book rather than just the first one.

```bash
./get_full_pricing_all.sh
```

**Output columns:** Customer | Company | Provider | Cloud Account | Product | Price | Currency

---

## Authentication

The scripts use two different authentication methods depending on which API version they target:

| Auth method | Used by | API version |
|-------------|---------|-------------|
| Basic Auth (key + secret) | `api.sh`, `get_full_report.sh`, `get_customer_products.sh`, `get_full_pricing.sh`, `get_full_pricing_all.sh` | v1 |
| OAuth Bearer token (with auto-refresh) | `get_products_simple.sh` | v3 |

For the v3 scripts, obtain an initial access token and refresh token from the TD Synnex developer portal and add them to `.env`. The scripts will keep them up to date automatically.

---

## Reference

- [TD Synnex StreamOne Ion SDK (Python)](https://github.com/techdata-cloudautomation/StreamOneIonSDKPython/tree/main)
- [StreamOne Ion Portal](https://ion.tdsynnex.com)
