# ApexHUD

A cyberpunk HUD dashboard for controlling the ApexHUD rover.

## Android release signing

Release APKs are signed using the keystore described by
`android/key.properties`. Keep that file and the keystore out of version
control, and back them up securely: future APKs must use the same key to update
existing installations.

The properties file must define `storeFile`, `storePassword`, `keyAlias`, and
`keyPassword`. Build the signed APK from this directory with:

```sh
flutter build apk --release
```

The APK is written to
`build/app/outputs/flutter-apk/app-release.apk`.
