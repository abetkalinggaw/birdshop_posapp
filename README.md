# EX-SHA Bird Shop POS

Flutter Android POS with local staff login.

See [POS app flows and implementation status](pos-app-flows.md#implementation-status--2026-10-16) for the intended workflows, implemented features, remaining gaps, and suggested implementation order.

## Staff login

On a new device, create the first **Admin (Owner)** account using a name, unique username, gender, and six-digit PIN. Then sign in with the username and PIN. There are no default credentials.

Owners create staff accounts from **Akun → Kelola Pengguna → Tambah staff**. Usernames are case insensitive and allow 3–24 letters, numbers, dots, hyphens, or underscores. Owners can edit names, usernames, genders, phone numbers, roles, active status, and reset PINs. The current account cannot be disabled or demoted.

| Role | Access |
| --- | --- |
| Admin (Owner) | Checkout, product management, all transaction history, sales reports, staff management, account and shift controls |
| Cashier (Employee) | Checkout, own transaction history, own PIN and shift controls |

Both roles can change their own PIN with verification of the existing PIN. Five incorrect attempts lock login for one minute; the lock survives app restarts.

Standard login lasts **8 hours from sign-in**, including time while the app is closed. Reopening within that period restores the same active staff account without extending the deadline. Select **Tetap masuk di perangkat ini** on the login form to stay signed in until explicit logout. This option starts unchecked on each new login form; it never saves a plaintext PIN.

Expiry is enforced on startup, by a running timer, on app resume, and before protected operations. Expiry and logout clear the cart and protected navigation. Explicit logout removes the saved session before returning to login; if secure storage fails, it reports the failure and allows retry. Existing account data without a saved session still requires login. Deactivated or missing accounts and malformed sessions cannot be restored.

Accounts and salted PIN hashes are persisted with `flutter_secure_storage`. PINs use PBKDF2-HMAC-SHA256 with 600,000 iterations, calculated away from the UI isolate. Android backup is disabled to avoid restoring encrypted account data without its device keys. Keep the Owner's username and PIN; another active Admin can reset a forgotten PIN.

Authentication is local to this device. There is no backend login or account synchronization. The product catalog, stock, new sales, open shifts and closing summaries are stored locally. There is no server synchronization.

## Cashier shifts

Cashiers must open a shift before using the POS. Enter the counted **Modal awal kas** (zero is allowed), then choose **Buka Shift & Mulai**. Owners can browse management screens without a shift, but must open one before completing a sale. The Account screen offers the same opening action.

Each completed sale is saved with its shift ID and cashier identity. Cash sales increase expected drawer cash; QRIS and transfer totals are tracked separately. Expected cash is opening cash plus net cash sales, not the amount tendered before change. Shift totals and their sale records survive app closure and login changes. Stock is deducted only after the local sale/shift save succeeds.

From **Akun → Tutup Shift**, enter the actual cash counted in the drawer. The sheet shows expected cash and the shortage/overage immediately; a difference requires a note. Unpaid cart items must be completed or explicitly discarded before closing. Closing saves an immutable summary, with opening/closing times, opening cash, cash/non-cash sales, actual cash, difference, and transaction count. **Riwayat Shift** shows the signed-in operator's saved summaries.

A shift left open on a previous day must be reconciled before new sales. Logout or login expiry does not close it. Closed shifts cannot accept sales; open a new shift to continue. Unreadable shift data blocks sales and offers retry without deleting the ledger. Failed opening/closing saves retain the previous in-memory state; a failed sale save does not deduct stock or clear the cart.

Shift summaries are saved locally before printing. Owners can review all operators from **Akun → Kelola Shift · Semua Kasir**, filter by cashier, opening date, active/closed status or discrepancy, and inspect the saved summary and its sales. Active shifts are read-only; only the operator closes their own shift. Closed summaries offer **Cetak Ringkasan Shift**, using the existing Bluetooth printer selector and actual ESC/POS transport for 58/80 mm paper. Canceling printer selection sends nothing. Reprints are explicit; a successful send confirms transfer, not physical paper output.

## Persistent inventory

Product creation, edits, deletion, prices, tags, critical-stock limits and stock counts survive app restarts and login changes. Selected product photos are copied out of picker cache into app support files. Existing sale snapshots retain their photos after later product changes/deletion.

Inventory and shift/sale records share one versioned secure-storage snapshot: a sale and its stock deduction are saved in the same write. Failed saves preserve both old stock and the unpaid cart. Concurrent saves are blocked. Loading or unreadable business data blocks selling/editing and offers retry without clearing data. Refresh reloads local storage; it does not claim server synchronization. An empty saved catalog stays empty.

Existing shift-only storage migrates without changing historical shifts or sales. The catalog is initialized once from the existing sample products; edits/stock counts lost by earlier app versions cannot be reconstructed. Verify initial stock counts after upgrading. The current snapshot suits this local app; larger catalogs/history need a database. Photos and business data remain local to this installation, with no backup/export or remote synchronization.

## Automatic Staff IDs

Staff IDs are read-only and are never used to resolve a login. The format is `ROLE-GENDERSSSS`, without a dot: for example, `ADM-10001` is a male Admin with serial 0001; `CSH-20002` is a female Cashier with serial 0002.

| Field | Codes |
| --- | --- |
| Role | ADM = Admin (Owner); CSH = Cashier (Employee) |
| Gender | 0 = Belum diisi; 1 = Laki-laki; 2 = Perempuan; 3 = Lainnya |
| Serial | One shared, persistent counter across roles and genders; minimum four digits |

The serial increases only after a successful account save. Profile edits retain the serial while updating the role/gender prefix. An immutable internal account key links credentials, shifts, and transaction history, so username and profile edits do not change ownership.

Existing accounts migrate automatically: the previous login ID becomes the username, PIN hashes and cashier attribution stay unchanged, and gender starts as `Belum diisi`. Owners can then update the username and gender from **Edit akun**. Migration and serial allocation are saved together; a storage failure retains the original data for retry.

## Thermal receipts (Android)

1. Pair a **Bluetooth Classic ESC/POS** printer in Android's Bluetooth settings.
2. Tap **Cetak Struk** on transaction success or history to open **Pilih Printer** first. Printer settings are also available from **Akun → Kelola Printer**.
3. Grant **Nearby devices / Perangkat di sekitar**, choose **58 mm (384 dots)** or **80 mm (576 dots)**, and tap **Hubungkan**.
4. Tap **Lanjut Cetak Struk** after connecting. The receipt screen opens and starts one print automatically. Cancelling the picker sends nothing.
5. Use **Ulangi Cetak** for an explicit reprint. The gear opens Bluetooth settings, including **Tes Cetak** to check alignment. The selected device and paper width are remembered.

The app sends monochrome ESC/POS receipt data over Android RFCOMM. A successful send confirms data transfer, not paper output or paper availability. Failed writes may have printed part of a receipt: inspect the printer before manually reprinting. Print jobs are never retried automatically.

The invoice reveal follows native sent-byte progress, pauses with the transfer, and completes only after the write succeeds. It has no fixed playback duration. Bluetooth buffering means this measures transfer timing rather than exact paper-feed completion; exact physical synchronization requires printer-model-specific completion feedback. Reduced motion keeps the full receipt visible without changing job feedback.

BLE-only, USB, and Wi-Fi printers need different transports. Fixed 384/576-dot widths and buffer pacing must be checked on the actual model. No physical printer was available during development verification.

Protocol references: [Android Bluetooth connections](https://developer.android.com/develop/connectivity/bluetooth/connect-bluetooth-devices), [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions), [Epson ESC/POS raster command](https://download4.epson.biz/sec_pubs/pos/reference_en/escpos/gs_lv_0.html).

## Development

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```
