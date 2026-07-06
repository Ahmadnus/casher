# Deployment & Handover Checklist

Consolidated steps to ship both projects to production after the full audit.

- **Backend (`casher`)** — Laravel API on cPanel
- **Flutter app (`untitled2`)** — Android POS client

Work top to bottom. Do the backend first, then the app.

---

## 0. Before you start

- [ ] Take a full backup of the production MySQL database (cPanel → Backups) **before** running any migration.
- [ ] Confirm AutoSSL is active for the API domain — open `https://casher.jiljam.com/up` in a browser; it must load over HTTPS. The app now talks to the API over `https://` only (Android blocks cleartext HTTP in release builds).

---

## 1. Backend — production config (`.env` on the server)

Edit the **server** `.env` (leave your local one as `local`):

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://casher.jiljam.com
LOG_LEVEL=error
```

Notes:
- This does **not** affect the cPanel Bearer-token workaround — the `X-Auth-Token` fallback lives in `AuthenticateWithToken` middleware, not `.env`.
- `APP_ENV=production` activates `URL::forceScheme('https')`.
- After caching config (step 3), any future `.env` change requires re-running `php artisan config:cache`.

---

## 2. Backend — upload changed files

Upload these (all changed/added during the audit):

**Services**
- `app/Services/InvoiceService.php`
- `app/Services/ReportService.php`
- `app/Services/CategoryService.php`

**Controllers**
- `app/Http/Controllers/Api/ReportController.php`

**Requests**
- `app/Http/Requests/Invoice/StoreInvoiceRequest.php`
- `app/Http/Requests/Employee/UpdateEmployeeRequest.php`
- `app/Http/Requests/Customer/StoreCustomerRequest.php`
- `app/Http/Requests/Customer/UpdateCustomerRequest.php`

**Models**
- `app/Models/Invoice.php`
- `app/Models/InvoiceItem.php`
- `app/Models/Category.php`
- `app/Models/MenuItem.php`

**Config / routes / seeders**
- `config/cors.php`
- `routes/api.php`
- `database/seeders/RolePermissionSeeder.php`

**Migrations (new)**
- `database/migrations/2026_07_06_000000_add_reporting_index_to_invoices_table.php`
- `database/migrations/2026_07_07_000000_add_idempotency_key_to_invoices_table.php`

---

## 3. Backend — run once on the server (cPanel terminal, project root)

```bash
php artisan down

php artisan migrate --force        # reporting index + idempotency_key column
php artisan db:seed --class=RolePermissionSeeder --force   # grants cashier invoices.update (safe: firstOrCreate/syncPermissions)
php artisan permission:cache-reset

php artisan optimize:clear         # wipe any stale dev caches
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

php artisan up
```

Verify:
- [ ] `GET https://casher.jiljam.com/api/reports/daily` with a valid token returns JSON containing a `by_order_type` key.
- [ ] The same URL **without** a token returns a JSON 401 (not an HTML error page) — confirms `APP_DEBUG=false` + JSON rendering.

---

## 4. Flutter app — build the release

From `untitled2`:

```powershell
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```

- Ship `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` to the client (keep `armeabi-v7a` for very old devices).
- For Play Store instead: `flutter build appbundle --release`.

Release signing (one time, if not already done):
- [ ] Create keystore: `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload` (run in `untitled2/android`).
- [ ] Create `untitled2/android/key.properties` with `storePassword`, `keyPassword`, `keyAlias=upload`, `storeFile=../upload-keystore.jks`.
- [ ] Keep the `.jks` file + passwords safe and OUT of git — losing them means the client can never ship an update under the same signature.

---

## 5. Required handover actions (or receipts/reports look wrong)

1. [ ] **Set restaurant identity in the app:** first login as admin → gear icon (top bar) → enter restaurant name, phone, address, receipt footer. Without this, receipts print the DB default (`config('app.name')` = "Laravel").
2. [ ] **Legacy unpaid invoices** — only if the DB has real completed sales saved before the pending/paid lifecycle change (they'd be excluded from reports). Confirm they were actually paid, then run once:
   ```sql
   UPDATE invoices SET status='paid', paid_at=created_at WHERE status='unpaid';
   ```
3. [ ] **Configure printers on each device:** printer settings screen → assign the cash printer and the invoice printer, run a test print for each.
4. [ ] **Enable a cPanel scheduled backup** for the database.

---

## 6. Smoke test on the RELEASE build (real device, not debug)

- [ ] Log in; confirm no login-screen flash on relaunch (session restores).
- [ ] Create one order of each type — delivery (with a zone), table (with number), takeaway — and confirm:
  - [ ] Delivery fee appears in the total and on the printed receipt.
  - [ ] Table number prints on the kitchen/cash slip.
  - [ ] Each lands in the **Pending Orders** queue, newest on top.
- [ ] Open a pending order → confirm payment (as a **cashier** account — verifies `invoices.update` was granted).
- [ ] Open **Reports** → today shows the sale; **مبيعات التوصيل** is non-zero for the delivery order.
- [ ] Open **Dashboard** (admin/manager) → KPIs and top sellers load.
- [ ] Double-tap the checkout button fast → only **one** invoice is created (idempotency).
- [ ] Turn on airplane mode → actions show Arabic error messages, no crash; recovers when back online.

---

## Reference — what changed in this audit (by area)

- **Auth/session:** no logout on transient network error at startup; no login-screen flash; removed default-credentials hint.
- **Menu/Categories:** block deleting a category with items; trash-aware slugs (no re-create 500); real delete success/failure; management screen shows unavailable items.
- **Customers:** invoices now find-or-create + link a customer by phone; phone lookup/autofill at checkout; soft-delete-aware unique phone.
- **Employees:** role dropdown driven by live roles (adds `waiter`, fixes edit crash); delete reports result.
- **Delivery Areas:** consolidated dialog; delete reports result; inactive areas visible in management.
- **Dashboard:** new screen (was unwired); removed wasteful pre-login request.
- **Settings/Printer:** receipts use real restaurant name/address/phone/footer, correct order-type label + table number, itemized delivery fee; new restaurant-settings screen.
- **Notifications:** left dormant (per decision); removed wasteful pre-login request; accurate unread count.
- **Security:** fixed self-service privilege escalation; invoice payment state machine (no double-pay / no reviving refunded); CORS locked down; rate limits confirmed.
- **Cross-cutting:** disposed leaked dialog controllers; idempotency-key guard against duplicate invoices.
- **Tests:** 0 → 24 backend tests (reports, security, category integrity, customer linking, idempotency).
