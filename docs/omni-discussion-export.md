# Omni App Discussion Export

Date: 2026-05-25

## Current Project

Flutter app:

```txt
C:\Projects\omni_app
```

Main app code is still intentionally in:

```txt
lib/main.dart
```

We discussed modularization, but decided not to split the Flutter code for now.

## Original Scanner Issues

The app originally called `availableCameras()` before `runApp()`, which could crash before UI appeared if camera access failed.

Implemented safer startup:

```txt
availableCameras() runs inside try/catch
If camera unavailable, app shows fallback UI instead of crashing
```

## QR Scanner UI

Implemented:

```txt
Camera preview
Blur only outside scanner square
Clear camera inside scanner square
Purple QR scanner corners
Upload QR / Torch / Omni action buttons
```

## Omni Scanner Page

Instead of showing the old Omni bottom sheet directly, `Omni` now opens a new scanner page.

Implemented:

```txt
Scan & Shop screen
Camera preview without outside blur
Scanner square corners in dark plum #360816
Gallery / Click / Barcode buttons
Custom barcode icon
Back arrow to QR scanner
```

The old bottom sheet was restored later, but now it opens when tapping `Click` on the Omni screen.

## White Flash Transition

To reduce route transition flash, navigation to Omni uses zero-duration route transitions:

```txt
transitionDuration: Duration.zero
reverseTransitionDuration: Duration.zero
```

If camera texture flicker remains later, the stronger solution is a single-screen mode switch instead of pushing a second route.

## Visual Search Backend Decision

Bing Visual Search was discontinued, so we replaced the plan with:

```txt
Flutter camera capture
-> local Node.js backend
-> Supabase Storage temporary upload
-> SerpApi Google Lens
-> normalized product response
-> Flutter result UI
```

Backend location:

```txt
backend/
```

Key backend files:

```txt
backend/server.js
backend/package.json
backend/.env.example
backend/config/categories.js
backend/config/domainMap.js
```

Secrets are stored only in:

```txt
backend/.env
```

and should not be committed.

## Backend Flow

```txt
User taps Click
        |
        v
Flutter captures camera image
        |
        v
Flutter sends multipart image to local backend
        |
        v
Backend uploads image to Supabase Storage bucket "Omni"
        |
        v
Backend creates signed URL
        |
        v
Backend sends signed image URL to SerpApi Google Lens
        |
        v
SerpApi returns visual/product matches
        |
        v
Backend normalizes results
        |
        v
Backend categorizes products by domain
        |
        v
Backend returns products + grouped categories
        |
        v
Flutter shows category result UI
```

Temporary Supabase images are deleted after search.

Debug JSONs are kept locally and are not auto-deleted:

```txt
backend/debug/<requestId>-serpapi-lens-raw.json
backend/debug/<requestId>-omni-products.json
```

## Backend Runtime

Run backend:

```cmd
cd C:\Projects\omni_app\backend
npm run dev
```

Health check:

```txt
http://localhost:3000/health
http://<laptop-ip>:3000/health
```

Example Flutter run:

```cmd
cd C:\Projects\omni_app
flutter run --dart-define=OMNI_BACKEND_URL=http://192.168.1.11:3000/api/visual-search
```

For a real phone, the laptop and phone must be on the same network, unless the backend is deployed publicly or exposed with ngrok.

## API Performance Observed

For one successful Acer mouse scan, backend logs showed:

```txt
Received image: 132 KB
Supabase upload: about 1 second
Signed URL creation: about 0.06 second
SerpApi Google Lens: about 6.9 seconds
Total backend time: about 8 seconds
Products found: 10
```

Google Lens native app is faster because it talks directly to Google’s internal systems, while Omni currently goes:

```txt
Phone -> laptop backend -> Supabase -> SerpApi -> Google Lens -> backend -> phone
```

Suggested future speed improvement:

```txt
Crop scanner square before upload
Compress consistently before upload
```

## Category Strategy

Final categories:

```txt
Local
Quick
Bulk
Global
Refurb
Other
```

Internal IDs:

```txt
indian_ecommerce -> Local
quick_commerce   -> Quick
bulk             -> Bulk
international    -> Global
second_hand      -> Refurb
other            -> Other
```

No delivery or availability check is performed for now.

Current logic:

```txt
Only check visually exact/similar product results returned by Lens.
Classify by domain.
```

Unknown domains:

```txt
If domain is unmapped and not .in/.co.in, put in Other.
If domain is unmapped but .in/.co.in, infer Local.
```

## Domain Map

User supplied five messy text files:

```txt
Bulk.txt
International.txt
Local.txt
Quick.txt
Refurbished.txt
```

Domains were extracted from these and converted into:

```txt
backend/config/domainMap.js
```

Approx current map size:

```txt
Local: 221 domains
Quick: 47 domains
Bulk: 129 domains
Global: 138 domains
Refurb: 48 domains
```

Some conflict corrections:

```txt
amazon.in -> Local
flipkart.com -> Local
myntra.com -> Local
indiamart.com -> Bulk
cashify.in -> Refurb
blinkit.com -> Quick
zeptonow.com -> Quick
swiggy.com -> Quick
ebay.com -> Global
```

## Result UI

Chosen design:

```txt
Option 4: Horizontal Category Rails
```

Bottom sheet after products found:

```txt
Plum background #360816
White product cards
White headings/counts
Category rails with horizontal scrolling
Small count beside each category name
Up to 8 cards in each rail
Arrow button at end of rail
```

Text sketch:

```txt
Similar Products Found                        X

Local  3
[card] [card] [card] [arrow]

Quick  0
[No matches in this category]

Bulk  2
[card] [card] [arrow]

Global  4
[card] [card] [card] [arrow]

Refurb  1
[card] [arrow]

Other  5
[card] [card] [card] [arrow]
```

Arrow opens a category page:

```txt
Plum background
Back arrow
Category title
Result count
2-column grid
White product cards
Max 25 results
```

## Current Product DTO

Backend product contains:

```json
{
  "title": "...",
  "image": "...",
  "price": "...",
  "source": "...",
  "shoppingLink": "...",
  "domain": "...",
  "categoryId": "...",
  "categoryTitle": "..."
}
```

Backend grouped response contains:

```json
{
  "products": [],
  "categorySummary": [],
  "categories": [
    {
      "id": "indian_ecommerce",
      "title": "Local",
      "products": []
    }
  ]
}
```

## Networking Notes

If phone cannot open:

```txt
http://<laptop-ip>:3000/health
```

then the app cannot reach backend.

Likely causes:

```txt
Laptop IP changed
Windows Firewall
Phone and laptop not on same Wi-Fi
PG/hostel Wi-Fi client isolation
Guest network isolation
```

Laptop IP can be checked with:

```cmd
ipconfig
```

## Git Notes

Important files to commit:

```txt
.gitignore
android/app/src/main/AndroidManifest.xml
android/gradle.properties
lib/main.dart
pubspec.yaml
pubspec.lock
backend/package.json
backend/package-lock.json
backend/server.js
backend/README.md
backend/.env.example
backend/config/categories.js
backend/config/domainMap.js
docs/omni-discussion-export.md
```

Do not commit:

```txt
backend/.env
backend/node_modules/
backend/debug/
backend/omni-backend.log
```

Commit command suggestion:

```cmd
git add .gitignore android/app/src/main/AndroidManifest.xml android/gradle.properties lib/main.dart pubspec.yaml pubspec.lock backend/package.json backend/package-lock.json backend/server.js backend/README.md backend/.env.example backend/config/categories.js backend/config/domainMap.js docs/omni-discussion-export.md
git commit -m "Add Omni visual search backend and category results UI"
git push
```

## Storage Notes

The large storage usage was not mainly from Omni.

Large folders found:

```txt
C:\Users\Prekshit\Downloads\push              67.25 GB
C:\Users\Prekshit\Downloads\DCIM              25.57 GB
C:\Users\Prekshit\Downloads\DCIM.zip          25.23 GB
C:\Users\Prekshit\Downloads\Download_1        19.56 GB
C:\Users\Prekshit\Downloads\Download.zip      19.25 GB
C:\Users\Prekshit\Downloads\WA                15.48 GB
C:\Users\Prekshit\Downloads\Media             15.22 GB
C:\Users\Prekshit\Downloads\Media.zip         14.76 GB
```

Project build folder:

```txt
C:\Projects\omni_app\build                    about 1.17 GB
```

Safe project cleanup:

```cmd
cd C:\Projects\omni_app
flutter clean
```

## Suggested Next Improvements

High-priority:

```txt
Make View button open shoppingLink
Hide empty categories or keep them based on demo preference
Crop scanner square before upload
Improve product scoring/sorting within each category
Add deployed backend/ngrok for phone demos beyond local Wi-Fi
```

Possible later:

```txt
PhonePe merchant registry
AI classifier only for unknown domains
Category-specific follow-up searches for empty categories
Location permission and delivery checking
```
