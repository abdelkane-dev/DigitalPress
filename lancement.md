backend :

cd backend

./start_backend.sh

frontend :

C:/Users/Lenovo/AppData/Local/Android/Sdk/platform-tools/adb.exe reverse tcp:8000 tcp:8000

flutter clean &&

flutter pub get &&

flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/
