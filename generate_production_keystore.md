# Generate Production Keystore Instructions

## Step 1: Generate Production Keystore
Run this command in your project's android folder:
```bash
keytool -genkey -v -keystore yang_chow-release.keystore -alias yang_chow -keyalg RSA -keysize 2048 -validity 10000
```

## Step 2: Get SHA-1 from Production Keystore
```bash
keytool -list -v -keystore yang_chow-release.keystore -alias yang_chow
```

## Step 3: Update build.gradle.kts
Add signing configuration to android/app/build.gradle.kts:

```kotlin
android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## Step 4: Add Production SHA-1 to Google Cloud Console
Add the SHA-1 from production keystore to Google Cloud Console credentials.

## Step 5: Build Signed APK
```bash
flutter build apk --release
```
