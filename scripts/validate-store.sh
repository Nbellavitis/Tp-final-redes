#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [--url URL] [--host HOST]

Validates the deployed The Store UI through the K3s Ingress.

Options:
  --url URL    Base URL for the Ingress endpoint (default: http://192.168.56.10)
  --host HOST  Host header expected by the Ingress rule (default: localhost)
  -h, --help   Show this help

Environment:
  STORE_URL      Same as --url
  STORE_HOST     Same as --host
  CURL_TIMEOUT   Curl timeout in seconds (default: 20)
EOF
}

log() {
  printf '[store-validation] %s\n' "$1"
}

fail() {
  printf '[store-validation] ERROR: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file=$1
  local expected=$2

  if ! grep -Fq "$expected" "$file"; then
    fail "Expected '$expected' in $file"
  fi
}

get_page() {
  local path=$1
  local output=$2

  curl "${curl_args[@]}" -o "$output" "${STORE_URL}${path}"
}

post_form() {
  local path=$1
  local output=$2
  shift 2

  curl "${curl_args[@]}" -o "$output" "$@" "${STORE_URL}${path}"
}

STORE_URL=${STORE_URL:-http://192.168.56.10}
STORE_HOST=${STORE_HOST:-localhost}
CURL_TIMEOUT=${CURL_TIMEOUT:-20}
PRODUCT_ID=${PRODUCT_ID:-d27cf49f-b689-4a75-a249-d373e0330bb5}
PRODUCT_NAME=${PRODUCT_NAME:-The Quiet Quill}
CATALOG_PRODUCT=${CATALOG_PRODUCT:-Aqua Ace GT}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      STORE_URL=${2:-}
      shift 2
      ;;
    --host)
      STORE_HOST=${2:-}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

[[ -n "$STORE_URL" ]] || fail "--url cannot be empty"
[[ -n "$STORE_HOST" ]] || fail "--host cannot be empty"

STORE_URL=${STORE_URL%/}
cookie_jar=$(mktemp -t the-store-phase10.XXXXXX)
workspace=$(mktemp -d -t the-store-phase10.XXXXXX)
trap 'rm -rf "$workspace" "$cookie_jar"' EXIT

curl_args=(
  -fsS
  --max-time "$CURL_TIMEOUT"
  -H "Host: ${STORE_HOST}"
  -b "$cookie_jar"
  -c "$cookie_jar"
)

home_page="${workspace}/home.html"
catalog_page="${workspace}/catalog.html"
topology_page="${workspace}/topology.html"
product_page="${workspace}/product.html"
cart_page="${workspace}/cart.html"
checkout_page="${workspace}/checkout.html"
delivery_page="${workspace}/delivery.html"
payment_page="${workspace}/payment.html"
order_page="${workspace}/order.html"

log "Validating UI at ${STORE_URL} with Host: ${STORE_HOST}"

log "Checking home page"
get_page "/" "$home_page"
assert_contains "$home_page" "Secret Shop"

log "Checking service topology"
get_page "/topology" "$topology_page"
assert_contains "$topology_page" "Catalog"
assert_contains "$topology_page" "Carts"
assert_contains "$topology_page" "Checkout"
assert_contains "$topology_page" "Orders"
assert_contains "$topology_page" "http://catalog"
assert_contains "$topology_page" "http://carts"
assert_contains "$topology_page" "http://checkout"
assert_contains "$topology_page" "http://orders"

log "Checking catalog page"
get_page "/catalog" "$catalog_page"
assert_contains "$catalog_page" "$CATALOG_PRODUCT"
product_count=$(grep -c "product-card" "$catalog_page" || true)
if (( product_count < 6 )); then
  fail "Expected at least 6 products in catalog, found ${product_count}"
fi

log "Checking product detail"
get_page "/catalog/${PRODUCT_ID}" "$product_page"
assert_contains "$product_page" "$PRODUCT_NAME"
assert_contains "$product_page" "add-to-cart"

log "Adding product to cart"
post_form "/cart" "$cart_page" \
  -L \
  --data-urlencode "productId=${PRODUCT_ID}" \
  --data-urlencode "quantity=1"
assert_contains "$cart_page" "$PRODUCT_NAME"
assert_contains "$cart_page" '$150'

log "Starting checkout"
get_page "/checkout" "$checkout_page"
assert_contains "$checkout_page" "checkoutForm"

log "Submitting shipping information"
post_form "/checkout" "$delivery_page" \
  --data-urlencode "firstName=John" \
  --data-urlencode "lastName=Doe" \
  --data-urlencode "email=john_doe@example.com" \
  --data-urlencode "address1=100 Main Street" \
  --data-urlencode "streetAddress=100 Main Street" \
  --data-urlencode "city=Anytown" \
  --data-urlencode "state=CA" \
  --data-urlencode "zipCode=11111"
assert_contains "$delivery_page" "Priority Mail"
assert_contains "$delivery_page" '$10'

delivery_token=$(sed -n 's/.*value="\([^"]*\)".*/\1/p' "$delivery_page" | head -n 1)
[[ -n "$delivery_token" ]] || fail "Could not detect delivery token"

log "Selecting delivery method"
post_form "/checkout/delivery" "$payment_page" \
  --data-urlencode "token=${delivery_token}"
assert_contains "$payment_page" "cardHolder"
assert_contains "$payment_page" "cardNumber"

log "Submitting payment and checking order summary"
post_form "/checkout/payment" "$order_page" \
  --data-urlencode "cardHolder=John Doe" \
  --data-urlencode "cardNumber=1234567890123456" \
  --data-urlencode "expiryDate=01/35" \
  --data-urlencode "cvc=123"
assert_contains "$order_page" "Order ID"
assert_contains "$order_page" "$PRODUCT_NAME"
assert_contains "$order_page" '$150'
assert_contains "$order_page" '$10'
assert_contains "$order_page" '$5'
assert_contains "$order_page" '$165'

log "Functional validation completed successfully"
