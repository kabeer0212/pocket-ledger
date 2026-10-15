# Pocket Ledger — Shake-to-Log Expense App

**Pocket Ledger** is a mobile-first Progressive Web Application (PWA) designed for quick, tactile expense and income tracking. Built specifically for one-handed operation on mobile devices (optimized for Samsung Galaxy S24) and connects directly to a Google Sheets backend via a Google Apps Script Web App endpoint.

---

## Key Features

1. **Instant Logging (Physical Shake or Tap)**:
   - Built with the `DeviceMotionEvent` API to initiate an expense entry simply by shaking your phone.
   - Includes graceful fallback for browsers/platforms without motion sensor support.
   - iOS 13+ permission request flow handled seamlessly.
2. **5-Step Frictionless Flow**:
   - **Step 1: Amount**: High-contrast monospace display with large tactile numeric keypad and quick preset chips (+5, +10, +20, +50). Validates that amount > 0.
   - **Step 2: Category**: Tactile category grid with single-tap auto-advancing.
   - **Step 3: Type**: Large Expense / Income cards. **Expense is pre-selected by default** — simply tap Next to log as Expense.
   - **Step 4: Remark**: Optional description field with 1-tap quick suggestions from frequent items. Clean skip button (never sends "undefined" or null).
   - **Step 5: Review & Send**: Realistic perforated paper receipt preview showing amount, category, type, date, and remark.
3. **Stamped Confirmation & Undo**:
   - Animated rubber stamp badge (`LOGGED` in ink red or `QUEUED` in brass).
   - 5-second undo timer progress bar allows canceling or deleting accidental entries.
4. **Offline-Tolerant Queue & Background Replay**:
   - If network connection drops or Apps Script fails, entries are queued in `localStorage`.
   - Automatic background replay whenever device comes back online, plus a manual "Retry Sending Queue" button in Settings.
5. **Sheet Category Sync**:
   - Edit, reorder, add, or delete categories locally in Settings.
   - "Sync Categories from Sheet" button calls your Apps Script GET endpoint and non-destructively merges new categories without removing custom local categories.
6. **Local Running Balances & Frequent Items**:
   - Shows "Today's Expenses" and "This Month's Expenses" computed from locally logged entries.
   - Tracks your last 5 unique descriptions as one-tap quick-fill chips.
7. **PWA Standalone Installation**:
   - Complete `manifest.json`, Service Worker (`sw.js`), and high-resolution icons (192px and 512px maskable).
   - Opens in true full-screen mode on Android without address bar clutter.

---

## Data Model & Google Sheets Integration

Target Google Sheet Tab Name: `record`  
Columns:
- **B**: Description / Remark (`string`)
- **C**: Amount (`number`)
- **D**: Category (`string`)
- **E**: Type (`string`, "Expense" or "Income")
- **F**: Date (auto-filled by backend script)

Summary formulas reside in row 5 (`B5`: Total Income, `C5`: Total Expenses, `D5`: Remaining Balance). Row 7 contains headers, data starts row 8.

### Apps Script Contract

- **POST Request**:
  - `Content-Type`: `application/x-www-form-urlencoded`
  - Payload parameters:
    - `amount`: number as string (e.g. `"110"`)
    - `category`: string (e.g. `"Food"`)
    - `type`: string (`"Expense"` or `"Income"`)
    - `remark`: string (Description column; empty string `""` if blank)
  - Success response:
    ```json
    { "status": "success", "row": 49, "date": "2026-09-12", "amount": "110", "category": "Food", "description": "egg", "type": "Expense" }
    ```
- **GET Request**:
  - Responds with:
    ```json
    { "status": "success", "categories": ["Food", "Transportation", "Textbooks", ...] }
    ```

### Optional Apps Script Undo Handler
If you wish to enable row deletion from the 5-second Undo button on the frontend, add this branch to your Apps Script `doPost(e)`:
```javascript
if (e.parameter.action === 'delete' && e.parameter.row) {
  var row = parseInt(e.parameter.row, 10);
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('record');
  sheet.deleteRow(row);
  return ContentService.createTextOutput(JSON.stringify({ status: 'success', deletedRow: row }))
    .setMimeType(ContentService.MimeType.JSON);
}
```

---

## How to Host & Install on Samsung Galaxy S24

### Option A: Free Static Web Hosting (Recommended for PWA)

1. **GitHub Pages**:
   - Push the contents of `pocket-ledger/` to a GitHub repository.
   - Go to **Settings > Pages** and select `main` branch root.
   - Open the generated `https://<username>.github.io/<repo>/` on Chrome on your Samsung Galaxy S24.

2. **Vercel or Cloudflare Pages**:
   - Drag and drop the `pocket-ledger/` directory into Vercel or Cloudflare Pages.
   - Immediate HTTPS deployment.

3. **Local Network Testing (PowerShell)**:
   - Run in PowerShell:
     ```powershell
     powershell -ExecutionPolicy Bypass -File tests\mock-server.ps1 -Port 8899
     ```
   - Open `http://<YOUR_COMPUTER_IP>:8899` on your phone (ensure phone and PC are on the same Wi-Fi).

### Option B: Installing to Android Home Screen (Samsung Galaxy S24)

1. Open the hosted URL in **Google Chrome** or **Samsung Internet** on your Galaxy S24.
2. Tap the browser menu (three dots `⋮` in Chrome, or `☰` in Samsung Internet).
3. Tap **"Install app"** or **"Add to Home screen"**.
4. The **Pocket Ledger** icon with the vintage bound ledger badge will appear on your home screen.
5. Tap it to launch full-screen like a native Android application!

---

## Verification Test Results Summary

An automated end-to-end verification suite was created and executed in headless Edge against a local mock Google Apps Script Web App server. All 10 tests passed (100%):

| # | Test Case | Status | Verified Behavior |
|---|---|---|---|
| 1 | **Default Expense Flow** | **PASSED** | Untouched type submits as `"Expense"`, amount `"45"`, category `"Food"`, remark `"lunch egg"`. |
| 2 | **Explicit Income Flow** | **PASSED** | Selecting Income explicitly posts `type: "Income"`, amount `"1500"`, category `"Miscellaneous"`. |
| 3 | **Amount Validation** | **PASSED** | Both blank and `0` amount inputs are blocked with clear warning message and vibration. |
| 4 | **Remark Blank / Skipped** | **PASSED** | Skipping remark submits clean `""` (never `undefined` or `null`). |
| 5 | **Offline Queuing & Replay** | **PASSED** | Network disconnection queues entries with "QUEUED" stamp; automatically replays and clears queue when online resumes. |
| 6 | **Shake Detection & Fallback** | **PASSED** | Physical shake detection triggers amount screen; tap button functions seamlessly if motion sensors are absent. |
| 7 | **Category Management** | **PASSED** | Add ("Freelance"), reorder to top, delete ("Accessories") persist in storage and update the grid in real-time. |
| 8 | **Sheet Category Sync** | **PASSED** | GET sync performs non-destructive merge (adds new sheet categories while preserving user's custom categories). |
| 9 | **Galaxy S24 Viewport Fit** | **PASSED** | UI renders cleanly within 412px width with zero horizontal overflow, thumb-friendly keypad layout. |
| 10 | **Reload Persistence** | **PASSED** | Configured Apps Script URL and custom categories survive page reloads and browser restarts. |
