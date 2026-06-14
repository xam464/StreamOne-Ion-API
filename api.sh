#!/bin/bash

# TD Synnex StreamOne Ion API Client
# Usage: ./api.sh [command] [options]
# 
# Commands:
#   customers    - List all customers/partners
#   products     - List available products
#   orders       - List recent orders
#   inventory    - Check product inventory
#   health       - Check API health/status
#   help         - Show this help message
#
# Requirements:
#   - .env file with TD_SYNNEX_API_KEY, TD_SYNNEX_API_SECRET, TD_SYNNEX_BASE_URL
#   - curl and jq (for JSON parsing)

set -o pipefail

# Load environment variables from .env
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
else
    echo "❌ Error: .env file not found!"
    echo "   Create a .env file with your credentials:"
    echo "   TD_SYNNEX_API_KEY=your_api_key"
    echo "   TD_SYNNEX_API_SECRET=your_api_secret"
    echo "   TD_SYNNEX_BASE_URL=https://www.tdsynnex.com/ion/api/v1"
    exit 1
fi

# Check for required variables
if [ -z "$TD_SYNNEX_API_KEY" ] || [ -z "$TD_SYNNEX_API_SECRET" ] || [ -z "$TD_SYNNEX_BASE_URL" ]; then
    echo "❌ Error: Missing required environment variables in .env"
    echo "   Check that TD_SYNNEX_API_KEY, TD_SYNNEX_API_SECRET, and TD_SYNNEX_BASE_URL are set"
    exit 1
fi

# Default headers for all requests
get_headers() {
    # Basic Auth: encode "key:secret" as base64
    local auth=$(printf "%s:%s" "${TD_SYNNEX_API_KEY}" "${TD_SYNNEX_API_SECRET}" | base64)
    echo -n "Authorization: Basic ${auth}\n"
    echo -n "Content-Type: application/json\n"
    echo -n "Accept: application/json"
}

# Make API request
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local url="${TD_SYNNEX_BASE_URL}/${endpoint}"
    
    echo "📡 Request: ${method} ${url}"
    
    if [ "$method" = "GET" ]; then
        curl -s -X GET "$url" -H "$(get_headers)" -w "\n%{http_code}" 2>&1
    elif [ "$method" = "POST" ]; then
        curl -s -X POST "$url" -H "$(get_headers)" -d "$data" -w "\n%{http_code}" 2>&1
    elif [ "$method" = "PUT" ]; then
        curl -s -X PUT "$url" -H "$(get_headers)" -d "$data" -w "\n%{http_code}" 2>&1
    elif [ "$method" = "DELETE" ]; then
        curl -s -X DELETE "$url" -H "$(get_headers)" -w "\n%{http_code}" 2>&1
    fi
}

# Parse response and handle errors
handle_response() {
    local response=$1
    local http_code=${response: -3}
    local body=${response%???}
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "✅ Success (${http_code})"
        if command -v jq &> /dev/null; then
            echo "$body" | jq '.'
        else
            echo "$body"
            echo ""
            echo "💡 Install jq for pretty JSON formatting: brew install jq"
        fi
    elif [ "$http_code" = "401" ]; then
        echo "❌ Unauthorized (401) - Invalid API key or secret"
        exit 1
    elif [ "$http_code" = "403" ]; then
        echo "❌ Forbidden (403) - Access denied"
        exit 1
    elif [ "$http_code" = "404" ]; then
        echo "❌ Not Found (404) - Endpoint does not exist"
        exit 1
    elif [ "$http_code" = "429" ]; then
        echo "❌ Rate Limited (429) - Too many requests"
        exit 1
    else
        echo "❌ Error (${http_code})"
        echo "$body"
        exit 1
    fi
}

# Show help
show_help() {
    echo "TD Synnex StreamOne Ion API Client"
    echo "===================================="
    echo ""
    echo "Usage: ./api.sh [command] [options]"
    echo ""
    echo "Commands:"
    echo "  customers    List all customers/partners"
    echo "  products     List available products"
    echo "  orders       List recent orders"
    echo "  inventory    Check product inventory"
    echo "  health       Check API health/status"
    echo "  get [path]   Custom GET request"
    echo "  help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./api.sh customers"
    echo "  ./api.sh get customers"
    echo "  ./api.sh get products?limit=10"
    echo ""
    echo "Requirements:"
    echo "  - .env file with credentials"
    echo "  - curl (usually pre-installed)"
    echo "  - jq (recommended for JSON formatting)"
}

# Command: Get customers
cmd_customers() {
    echo "🔍 Fetching customers..."
    local response
    
    # Try common endpoint patterns
    for endpoint in "customers" "partners/customers" "resellers" "partners" "accounts"; do
        response=$(api_request GET "$endpoint")
        local http_code=${response: -3}
        
        if [ "$http_code" = "200" ]; then
            handle_response "$response"
            return 0
        fi
    done
    
    echo "❌ Could not find customer endpoint. Available endpoints might be different."
    echo "   Try: ./api.sh get [endpoint]"
    exit 1
}

# Command: Get products
cmd_products() {
    local limit=${1:-100}
    echo "🔍 Fetching products (limit: ${limit})..."
    local response
    
    for endpoint in "products" "catalog" "catalog/products"; do
        response=$(api_request GET "$endpoint?limit=${limit}")
        local http_code=${response: -3}
        
        if [ "$http_code" = "200" ]; then
            handle_response "$response"
            return 0
        fi
    done
    
    echo "❌ Could not find products endpoint."
    exit 1
}

# Command: Get orders
cmd_orders() {
    local limit=${1:-50}
    echo "🔍 Fetching orders (limit: ${limit})..."
    local response
    
    for endpoint in "orders" "purchases" "transactions"; do
        response=$(api_request GET "$endpoint?limit=${limit}")
        local http_code=${response: -3}
        
        if [ "$http_code" = "200" ]; then
            handle_response "$response"
            return 0
        fi
    done
    
    echo "❌ Could not find orders endpoint."
    exit 1
}

# Command: Check inventory
cmd_inventory() {
    local sku=$1
    if [ -z "$sku" ]; then
        echo "Usage: ./api.sh inventory [SKU]"
        exit 1
    fi
    echo "🔍 Checking inventory for SKU: ${sku}"
    local response
    
    for endpoint in "inventory/${sku}" "products/${sku}/inventory" "availability/${sku}"; do
        response=$(api_request GET "$endpoint")
        local http_code=${response: -3}
        
        if [ "$http_code" = "200" ]; then
            handle_response "$response"
            return 0
        fi
    done
    
    echo "❌ Could not find inventory endpoint for SKU: ${sku}"
    exit 1
}

# Command: Health check
cmd_health() {
    echo "🔍 Checking API health..."
    local response
    
    for endpoint in "health" "status" "ping"; do
        response=$(api_request GET "$endpoint")
        local http_code=${response: -3}
        
        if [ "$http_code" = "200" ]; then
            handle_response "$response"
            return 0
        fi
    done
    
    echo "✅ API is accessible (base URL valid)"
}

# Command: Custom GET request
cmd_get() {
    if [ -z "$1" ]; then
        echo "Usage: ./api.sh get [path]"
        echo "Example: ./api.sh get customers"
        echo "Example: ./api.sh get products?limit=10"
        exit 1
    fi
    echo "🔍 Custom GET request to: $1"
    local response
    response=$(api_request GET "$1")
    handle_response "$response"
}

# Main execution
case "$1" in
    customers)
        cmd_customers
        ;;
    products)
        cmd_products "$2"
        ;;
    orders)
        cmd_orders "$2"
        ;;
    inventory)
        cmd_inventory "$2"
        ;;
    health)
        cmd_health
        ;;
    get)
        shift
        cmd_get "$@"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
