# Seller App Playbook — ko_seller

**Author: Claude Ai** · Last updated: 2026-09-21

The Kariakoo Sellers Flutter app: phone-OTP sign-in, listings, orders,
fulfilment, stock, payouts, buyer chat and notifications. It shares one
Firestore database with the buyer app (`ko`) and the backend
(`kariakoonline_firebase`).

The cross-repo contract lives at
`kariakoonline_firebase/docs/marketplace_contract.md`. Read it before changing
any collection name, field name or status string. A local summary is in
[`docs/contract.md`](docs/contract.md).

---

## 1. Two rules that are not obvious

**This app never writes to `order`.** Firestore rules deny it outright.
Fulfilment goes through the `updateSellerFulfillment` and `sellerReviewReturn`
callables, which enforce the escrow state machine — most importantly that
nothing ships before escrow is funded.

**Queries must match what the rules key off.** Firestore evaluates security
rules *against the query*, not against the documents it would return. A rule
keyed on a field the query does not constrain is rejected before it runs:

| Collection | Query by | Not by |
| --- | --- | --- |
| `seller_orders/*/orders` (collection group) | `sellerOwnerUid` | `sellerId` |
| `seller_payment_method` | `ownerUid` | `sellerid` |
| `payouts` | `sellerOwnerUid` | `sellerId` |

Filtering by the seller id looks more natural and fails with a bare
`permission-denied`. This has now caused two separate outages.

---

## 2. How an order reaches this app

The seller app never reads `order`. A Cloud Function
(`syncSellerOrderProjection`) fans each order out to
`seller_orders/{sellerId}/orders/{projectionId}`, one document per line item,
each carrying `sellerOwnerUid` plus a `rawOrder` / `rawItem` snapshot.
`MarketplaceOrderService` reads those through a collection-group query.

```
order (backend-owned)
  └─ syncSellerOrderProjection
       └─ seller_orders/{sellerId}/orders/*     ← this app reads here
            └─ updateSellerFulfillment (callable) → writes back to order
```

`SellerOrder.id` is `"{orderDocumentId}:{productId}"`, because one order can
appear as several rows. **Every callable needs `orderDocumentId`, not that
composite id** — `OrderProvider._runOrderAction` resolves it. Do not pass
`order.id` to a service method directly.

---

## 3. Listing lifecycle

A seller writes `draft`, `submitted` or `archived` — never `approved`. Only the
`reviewProductSubmission` admin callable publishes, from the ops console at
`/admin.html`.

- **Content edits** (name, description, price, images) send an approved listing
  back to `submitted`. This is deliberate: otherwise an approved listing could
  be swapped for anything after review.
- **Stock and availability** change in place, so managing inventory does not
  cost a seller their slot in the catalogue. The rules pin this to a fixed set
  of keys — `stock`, `color`, `availability`, `allowNegotiation`, `min_order`,
  `wholesaleMinQty`, `updatedAt`. Adding a field to `updateStock` without
  adding it to the rule silently breaks stock updates on live listings.

A listing is visible to buyers only when
`approved == true && availability == true && isDemo != true`.

---

## 4. Store identity

`seller.ownerUid` is **immutable from the client**. A seller signing in on a
new device with the same phone number is linked by the `claimSellerProfile`
callable, which verifies `auth.token.phone_number` against the store's `phone`
server-side and then rewrites that store's products and order projections to
the new uid.

`SellerProfileService.syncSellerByPhone` calls it automatically and surfaces
`SellerProfileException` when the phone does not match. Writing `ownerUid`
directly from the app is denied.

---

## 5. Running it

```bash
flutter pub get
flutter run                 # needs a device with Google Play services for FCM
flutter analyze             # expect 0 errors; the info-level lints are pre-existing
```

Phone OTP will not deliver to an emulator without a Firebase test number
(Authentication → Sign-in method → Phone → test numbers).

---

## 6. What changed on 2026-09-21

### `lib/services/seller_payment_method_service.dart`

`fetchPaymentChannels` queried `where('sellerid', ...)` while the Firestore
rule keys on `ownerUid`, so the query was rejected before it ran and **payout
accounts never loaded**. Now queries by `ownerUid` and filters to the current
store client-side (one account can own more than one store).

This also fixed `setPrimaryChannel`, which reads through the same method.

### `lib/services/seller_profile_service.dart`

`_refreshSellerOwnership` used to write `ownerUid` straight to the seller
document. With the old rules that meant **any signed-in user could take over
any store** found by phone number. It now calls the `claimSellerProfile`
callable and throws `SellerProfileException` with a readable message when the
store belongs to a different phone number.

### `lib/screen/home.dart`

- **"Make Primary" was a no-op** — `onPressed: () {}`. Wired to
  `AuthProvider.setPrimaryChannel`, disabled on the channel that is already
  primary, with success and failure feedback.
- The Payments sheet was a static explainer. It now opens a draggable sheet
  with a **live settlements list** above the flow steps, showing what the
  marketplace owes for each released order, the commission taken, the payout
  destination, and the transfer reference once settled.

### New files

| File | Purpose |
| --- | --- |
| `lib/model/seller_payout.dart` | `payouts` ledger row: gross, commission, net, status, destination |
| `lib/services/seller_payout_service.dart` | streams the seller's own payouts, filtered by `sellerOwnerUid` |
| `docs/contract.md` | pointer to the cross-repo contract and the two query rules above |

### Unblocked by backend changes in the same batch

These needed no code change here, but the app was broken until the backend
shipped:

- **Sellers could not see a single order.** `seller_orders/*/orders` had no
  Firestore rule, so every collection-group read fell through to an admin-only
  catch-all. The rule now grants read on `sellerOwnerUid`.
- **Creating a listing was denied.** The product rule compared
  `reviewedBy`/`reviewedAt`/`rejectionReason` against `null`, but this app
  never writes those keys, and reading a missing key errors in rules.
- **Stock could not be changed on any approved listing.**
- **Push notifications never arrived** — the backend called
  `sendEachForMulticast`, which does not exist in the firebase-admin version
  that was deployed.

---

## 7. When something breaks

| Symptom | Cause to check first |
| --- | --- |
| Order list empty, no error | the `orders` collection-group index is still building, or the seller doc has no `ownerUid` — sign out and in to re-run the claim |
| `permission-denied` on a list screen | a query filtering on a field the rule does not key off (§1) |
| Saving a product fails | the moderation fields are not one of draft / submitted / archived, or `seller.ownerUid` does not match |
| Stock update fails on a live listing | a key outside the allowed inventory set was included in the write |
| Fulfilment button errors "Wait for escrow funding" | correct — the order is not `escrow_held` yet. Never ship before it is. |
| No notifications | the token is registered on `seller.fcmTokens`; confirm the doc id is right and notifications are permitted on the device |

Order actions surface their reason through `OrderProvider.lastError`; show it
rather than a generic failure, since the callables return messages written for
sellers.
