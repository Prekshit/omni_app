# Omni Visual Search Backend

Local Node.js backend for the Omni Flutter proof of concept.

## Setup

```bash
npm install
npm run dev
```

The server starts on:

```txt
http://localhost:3000
```

Health check:

```txt
GET http://localhost:3000/health
```

Visual search:

```txt
POST http://localhost:3000/api/visual-search
multipart/form-data image=<camera photo>
```

The backend now does two SerpApi passes:

```txt
1. Google Lens on the uploaded image
2. Google Shopping using the inferred query from Lens
```

The response includes merged `products`, grouped `categories`, `categorySummary`,
`sourceSummary`, and `timingMs`.

## Flutter Backend URL

Android emulator default:

```bash
flutter run
```

Real phone on the same Wi-Fi as laptop:

```bash
flutter run --dart-define=OMNI_BACKEND_URL=http://YOUR_LAPTOP_IP:3000/api/visual-search
```

The phone and laptop must be on the same network while the backend is local.
