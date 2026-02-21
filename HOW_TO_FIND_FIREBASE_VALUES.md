# How to Find Your Firebase Configuration Values

## Method 1: From Firebase Console (Easiest)

1. **Go to Firebase Console:** https://console.firebase.google.com
2. Select your project: **"noise-pollution-mapper-9ad3d"**
3. Click the **gear icon** (⚙️) → **Project settings**
4. Scroll down to **"Your apps"** section
5. Click on your **Android app**
6. You'll see all values:

### What You'll Find:
- **App ID:** `1:185708456928:android:84881c81b95eafd4191985` (you already have this!)
- **API Key:** Look for a field labeled "Web API Key" or in the config snippet
- **Project ID:** `noise-pollution-mapper-9ad3d` (you already know this!)
- **Messaging Sender ID:** `185708456928` (it's the first number in your App ID!)

---

## Method 2: From google-services.json (Android)

1. In Firebase Console → Your Android app
2. Download **google-services.json**
3. Open it in a text editor
4. Look for these values:

```json
{
  "project_info": {
    "project_id": "noise-pollution-mapper-9ad3d",
    "firebase_url": "...",
    "project_number": "185708456928",  // ← MESSAGING_SENDER_ID
    "storage_bucket": "..."
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:185708456928:android:84881c81b95eafd4191985",  // ← APP_ID
        "android_client_info": {
          "package_name": "com.noisemapper.noise_pollution_mapper"
        }
      },
      "api_key": [
        {
          "current_key": "AIzaSyD..."  // ← API_KEY
        }
      ]
    }
  ]
}
```

---

## YOUR VALUES (Based on Screenshot):

From your screenshot, I can already tell you some values:

```env
FIREBASE_APP_ID=1:185708456928:android:84881c81b95eafd4191985
FIREBASE_PROJECT_ID=noise-pollution-mapper-9ad3d
FIREBASE_MESSAGING_SENDER_ID=185708456928
```

**You only need to find:** FIREBASE_API_KEY (starts with "AIzaSy...")

---

## Where to Find API Key Specifically:

**Option A:** Firebase Console
- Project Settings → General → Web API Key section

**Option B:** Download google-services.json
- Look for "current_key" field

**Option C:** In your existing code
- Check `android/app/google-services.json` if it exists
- Or check `lib/firebase_options.dart` (might have it)

---

## What to Do Next:

1. Find the API Key using one of the methods above
2. Create your `.env` file with the simplified template below
3. Run the app
