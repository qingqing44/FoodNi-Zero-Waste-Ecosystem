# Kills the stale ADB server then launches the Flutter app
& "C:\Users\HP\AppData\Local\Android\Sdk\platform-tools\adb.exe" kill-server
Start-Sleep -Seconds 1
flutter run
