# Where the seller app's contract lives

This app reads and writes a Firestore database it shares with the buyer app
(`ko`) and the backend + website (`kariakoonline_firebase`).

The contract — collection names, order field names, status enums, which
callables exist, and the query shapes the Firestore rules require — is
documented once, in the backend repo:

    kariakoonline_firebase/docs/marketplace_contract.md

Two things about this app in particular:

- It never writes to `order`. Fulfilment goes through the
  `updateSellerFulfillment` and `sellerReviewReturn` callables; the rules deny
  client writes on `order` outright.
- It reads orders as a collection group query on `sellerOwnerUid`, not on
  `sellerId`. Firestore checks rules against the query, and the rule for
  `seller_orders/{sellerId}/orders/*` keys off `sellerOwnerUid`. The same
  applies to `seller_payment_method`, which must be queried by `ownerUid`.
