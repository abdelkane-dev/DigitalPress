# 🚀 Guide de publication — DigitalPress (Play Store, App Store, Windows, macOS)

Config actuelle de l'app (vérifiée) :

| Élément | Valeur |
|---|---|
| Version | `2.0.0+1` (`pubspec.yaml`) |
| Application ID Android | `com.digitalpress.app` |
| Bundle ID iOS | `com.digitalpress.app` |
| Icônes | `assets/app_icon.png` → générées Android + iOS (`flutter_launcher_icons`) |
| Serveur API prod | `https://www.digitalpress-ml.com/api/` (déjà câblé en release) |

---

## 1. Android — Play Store

### 1.1 Créer la clé de signature RELEASE (obligatoire)

⚠️ **Actuellement le build release est signé avec la clé de DEBUG** (`signingConfig = debug` dans `android/app/build.gradle.kts`) — Google Play REFUSE ce type de build. Il faut une vraie clé :

```bash
# Génère la clé (gardez précieusement le mot de passe !)
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Crée le fichier de config (jamais commité)
# android/key.properties
storePassword=LE_MOT_DE_PASSE
keyPassword=LE_MOT_DE_PASSE
keyAlias=upload
storeFile=upload-keystore.jks
```

### 1.2 Brancher la signature dans `android/app/build.gradle.kts`

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    signingConfigs {
        create("release") {
            if (keystoreProperties["storeFile"] != null) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### 1.3 Générer les builds

```bash
flutter build apk --release            # test direct (installable)
flutter build appbundle --release      # pour le Play Store (.aab)
```

Sorties :
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

### 1.4 Publier sur la Play Console

1. Aller sur https://play.google.com/console → **Créer une application** (nom : DigitalPress).
2. **Configurer la fiche** : description FR + EN, captures d'écran (téléphone/tablette), icône 512×512, bannière, catégories (Actualités / Magazines).
3. **Suivre la checklist** « Politique » : formulaire de confidentialité (URL → ajouter une page sur le site), déclaration des autorisations.
4. **Version de production** → importer `app-release.aab`.
5. **Test interne / test fermé** (optionnel mais recommandé) avant la production.
6. Publier après validation (généralement 1–7 jours la première fois).

---

## 2. iOS — App Store (sur un Mac avec Xcode)

```bash
# Sur le Mac : installer Flutter + Xcode, puis
flutter build ios --release --no-codesign   # test
flutter build ipa                            # archive signée
```

1. Sur https://developer.apple.com : créer l'App ID `com.digitalpress.app` et les certificats (Development + Distribution).
2. Dans Xcode → `ios/Runner.xcworkspace` → Signing & Capabilities : sélectionner l'équipe.
3. `flutter build ipa --release` → archive `.ipa` → upload via **Transporter** ou Xcode Organizer.
4. App Store Connect : configurer la fiche, captures d'écran iPhone + iPad, privacy policy.
5. Soumettre à validation (App Review).

---

## 3. Windows (desktop)

⚠️ **Blocage actuel** : l'installation Visual Studio sur ce PC est incomplète — il manque le workload « Développement Desktop en C++ » (et le SDK Windows 10/11).

**À faire une seule fois** :
1. Ouvrir **Visual Studio Installer** (menu Démarrer).
2. Cliquer **Modifier** sur « Visual Studio Community 2026 ».
3. Cocher **« Développement Desktop en C++ »** (+ « Composants CMake » dans l'onglet Composants individuels si absent).
4. **Installer** (téléchargement de plusieurs Go, 15–30 min), puis redémarrer.

Ensuite :
```bash
flutter build windows --release
# Sortie : build/windows/x64/runner/Release/DigitalPress.exe (+ dossier à zipper)
```

---

## 4. macOS (desktop) — sur un Mac

```bash
flutter build macos --release
# Sortie : build/macos/Build/Products/Release/DigitalPress.app
```

Publication hors store : notarisation + `.dmg` (outil `create-dmg`). Store : Mac App Store via Xcode.

---

## 5. Web (déjà en production)

Le web est déjà déployé sur https://www.digitalpress-ml.com (nginx + backend Django sur le VPS).
Rebuild + redéploiement :
```bash
flutter build web --release
DP_VPS_PASSWORD='...' python deploy_web_vps.py
```

---

## 6. Checklist avant publication (recette)

- [ ] Se connecter (lecteur / éditeur / admin) sur chaque plateforme.
- [ ] Notifications temps réel (WebSocket) + badge cloche.
- [ ] Paiement : simulation fonctionnelle partout ; passer CinetPay en réel quand les clés marchand sont dans le `.env` du VPS.
- [ ] Retraits éditeur/admin : sélection du moyen + montant + suivi.
- [ ] « Mon niveau » : s'affiche (palier Basique/Standard/Premium + progression).
- [ ] Taux de commission par palier sur le profil public.
- [ ] Gestion des abonnés (retirer / bannir).
- [ ] Upload des documents de vérification (PDF/JPG/PNG ≤ 50 Mo).
- [ ] Médias : couverture (photo ≤ 5 Mo, vidéo ≤ 15 s silencieuse) et contenu (photo ≤ 15 Mo, vidéo ≤ 45 min, PDF ≤ 50 pages).
- [ ] Plein écran image / vidéo / PDF.
- [ ] Aucune mention « 0 F » sur les cartes (→ « gratuit »), aucune mention « gratuit » ailleurs.
- [ ] Suppression des notifications une à une (tous rôles).
