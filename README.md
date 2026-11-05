# NET4207 Stock Inventory Manager (Flutter + Cloud Firestore)

| | |
|---|---|
| Student name | _fill in_ |
| Student ID | _fill in_ |
| Tutorial group | _fill in_ |
| GitHub repository | https://github.com/ajaynagarajan2005/net4207-stock-inventory-lab |
| Live app | https://net4207-stock-lab-an.web.app |

## Setup and run

- **Firebase project ID:** `net4207-stock-lab-an` (if you use the lecturer-provided project, update `lib/firebase_options.dart` and `.firebaserc`).
- **Packages:** `firebase_core`, `cloud_firestore`, `google_fonts` (Flutter 3.x, Dart 3.x).
- No passwords, service-account files or private keys are included. The web config in `firebase_options.dart` contains public client IDs only.

```bash
flutter pub get
flutter run -d chrome
```

Unit tests: `flutter test`. Deploy the Firestore rules: `firebase deploy --only firestore:rules`. Deploy the site: `flutter build web`, then `firebase deploy --only hosting`.

## Write-up

The app has a form and an inventory list. They sit side by side on desktop and switch with tabs on a phone. The form is a `Form` with a `GlobalKey<FormState>`. **Save Item** calls `validate()` first, so invalid input never reaches Firestore. Valid items are added to `stockItems` with an auto-generated ID. The button shows "Saving..." until Firestore acknowledges the write, and only then does the confirmation appear. If the write fails, an error message appears and the form keeps the entered values.

**Schema (`stockItems`):** `sku` String, `itemName` String, `category` String, `quantity` int, `unitPrice` number, `reorderLevel` int, `createdAt` server Timestamp. `updatedAt` is added when an item is edited.

**Validation:**
- SKU must be `STK-` plus three digits and must not already exist.
- Item name is trimmed and must be at least 3 characters.
- Category must be one of the four allowed values.
- Quantity and reorder level must be whole numbers, 0 or above.
- Price must be greater than RM 0.

`firestore.rules` enforces the same rules on the server.

**Search:** The list listens to a live Firestore snapshot, so it is still there after a reload. Keyword search is a partial, case-insensitive match on name OR SKU. It combines with AND with the category filter and the **Low stock only** filter (`quantity <= reorderLevel`). Results can be sorted by quantity in either direction, and also by name or price. **Clear filters** resets every control. The list has loading, empty, no-results and error states.

**Extra features:**
- A summary strip shows products, units, low-stock count and stock value. Clicking the low-stock count applies the low-stock filter.
- +/− buttons on each row restock or sell one unit, using an atomic `FieldValue.increment`.
- Items can be edited in a dialog.
- Delete asks for confirmation and offers Undo.

## Test log

| # | Input | Expected | Actual | Screenshot |
|---|---|---|---|---|
| 1 | Blank form; then `STK-101` (exists), `ab`, no category, qty `-2`, reorder `1.5`, price `0` | Inline errors, no write | Field-level errors for all six, including "SKU STK-101 already exists"; item count unchanged | `01`, `02` |
| 2 | Save STK-101, 102, 103 (lab data); reload the page | Three retrievable records | All three listed after reload with correct values | `00`, `08` |
| 3 | "mouse" + Electronics + Low stock | Only STK-103 | Only STK-103 (1 of 4) | `04` |
| 4 | "stk-102", All, all stock | Notebook appears | Only STK-102 Notebook | `12` |
| 5 | Sort by quantity, low to high | STK-103, STK-101, STK-102 | 103 (1), 101 (4), then 104 (10), 102 (25) | `06` |
| 6 | Clear filters after a combined search | Full list again | 4 of 4 shown, controls reset | `05` |
| 7 | Low stock only + "notebook" | No results message | "No matching items" with a Clear filters button | `13` |
| 8 | +1 / −1 on STK-101; edit, delete and undo a temporary STK-999 | Firestore updates | Units 40 → 41 → 40; STK-999 renamed, deleted, restored by Undo, then deleted | `03`, `07`, `09`–`11` |

Screenshots are in `docs/screenshots/`. Row 5 includes STK-104, an extra item added during testing.
