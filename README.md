<div align="center">

<img src="assets/icon-1024.png" width="120" alt="Icône PandaPointer : un panda roux">

# PandaPointer

**Ton téléphone Android devient la souris de ton PC.**
Gyroscope, pavé tactile avec les gestes Windows, télécommande de diaporama et pointeur laser, le tout chiffré sur ton Wi-Fi.

[![Release](https://github.com/the-panda-roux-38/pandapointer/actions/workflows/release.yml/badge.svg)](https://github.com/the-panda-roux-38/pandapointer/actions/workflows/release.yml)
![Android 7+](https://img.shields.io/badge/Android-7%2B-3DDC84)
![Windows 10/11](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4)
![Rust](https://img.shields.io/badge/PC-Rust-DEA584)
![Flutter](https://img.shields.io/badge/Mobile-Flutter-02569B)

[Installer](#installer) · [Utiliser](#utiliser) · [Sécurité](#sécurité) · [Dépannage](#dépannage) · [Développer](#développer)

</div>

---

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Installer](#installer)
- [Utiliser](#utiliser)
- [Sécurité](#sécurité)
- [Dépannage](#dépannage)
- [Développer](#développer)
- [Architecture et protocole](#architecture-et-protocole)
- [Publier une version](#publier-une-version)
- [Limites connues](#limites-connues)
- [Crédits et licences](#crédits-et-licences)

## Fonctionnalités

| | |
| --- | --- |
| **Gyro** | Tu maintiens un bouton et tu bouges le poignet : le curseur suit. Sensibilité, stabilité (anti-tremblement) et précision des petits mouvements réglables. |
| **Pavé tactile** | Un vrai touchpad de portable Windows : tap, double-tap, cliquer-glisser, scroll à deux doigts avec inertie, zoom par pincement, gestes à 3 et 4 doigts. |
| **Slides** | Suivant, précédent, démarrer, quitter pour PowerPoint ou un PDF, plus un pointeur gyro. |
| **Laser** | Un point rouge lumineux par-dessus ton diaporama, qui suit le téléphone **sans bouger le vrai curseur**. |
| **Appairage par QR code** | Un scan, une fois. Le téléphone est ensuite reconnu comme appareil de confiance. |
| **Reconnexion automatique** | Wi-Fi coupé, PC en veille, appli relancée : la liaison se rétablit toute seule, et le PC est retrouvé même si son adresse change. |
| **Chiffré** | Chaque téléphone a sa propre clé. Les messages sont chiffrés et protégés contre le rejeu. |
| **Icône dans la barre des tâches** | Statut, appairage, liste des téléphones, lancement avec Windows. Pas de fenêtre. |

### Gestes du pavé

| Geste | Action sur le PC |
| --- | --- |
| 1 doigt glisse | Déplace le curseur (accélération réglable) |
| Tap / double-tap | Clic gauche / double-clic |
| Double-tap puis glisser | Cliquer-glisser (déplacer une fenêtre, sélectionner du texte) |
| 2 doigts glissent | Scroll vertical et horizontal, avec inertie |
| 2 doigts pincent / écartent | Zoom (Ctrl + molette) |
| Tap à 2 doigts | Clic droit |
| 3 doigts : haut / bas | Vue des tâches (Win+Tab) / bureau (Win+D) |
| 3 doigts : gauche / droite | Appli précédente / suivante (Alt+Tab) |
| Tap à 3 doigts | Recherche (Win+S) |
| 4 doigts : gauche / droite | Bureau virtuel précédent / suivant |
| Tap à 4 doigts | Centre de notifications (Win+A) |

## Installer

Il n'y a rien à compiler. Il te faut un PC Windows 10 ou 11, un téléphone Android 7 ou plus, et les deux sur **le même réseau** (Wi-Fi de la maison, ou partage de connexion du téléphone).

1. Ouvre la page **[Releases](https://github.com/the-panda-roux-38/pandapointer/releases)** du dépôt et télécharge `PandaPointer-PC.exe` et `PandaPointer.apk`.
2. **Sur le PC** : double-clique `PandaPointer-PC.exe`.
   - Un panda apparaît près de l'horloge (clique sur `^` s'il est caché).
   - Windows demande d'autoriser le pare-feu : coche **Réseaux privés**.
   - SmartScreen peut afficher « application non reconnue » : *Informations complémentaires* → *Exécuter quand même*. Le programme n'est pas signé numériquement (un certificat de signature coûte cher pour un projet perso).
3. **Sur le téléphone** : ouvre `PandaPointer.apk`. Android demande d'autoriser l'installation d'applications inconnues pour ton navigateur ou ton gestionnaire de fichiers, une seule fois.
4. **Appairer** : au premier lancement, le PC ouvre un QR code. Dans l'appli, touche **Scanner le QR code**. C'est fait : l'appli se connecte toute seule.

Pour appairer un autre téléphone plus tard : clic sur le panda → **Appairer un téléphone…**.

### Le menu du panda (PC)

| Entrée | Rôle |
| --- | --- |
| Statut (grisé) | « Connecté : Téléphone 1 », « En attente du téléphone » ou « Aucun téléphone appairé » |
| Appairer un téléphone… | Ouvre un QR code valable 5 minutes |
| Téléphones appairés | Liste, avec **Oublier** pour chacun |
| Lancer avec Windows | Démarre PandaPointer à l'ouverture de ta session |
| Quitter PandaPointer | Ferme le programme |

## Utiliser

L'appli a trois onglets. Le statut de connexion et la roue dentée (réglages) restent en haut.

**Gyro.** Tiens le téléphone à plat, bord du haut vers l'écran, **maintiens** le grand bouton et tourne le poignet. Le gyroscope mesure une vitesse de rotation (pas une direction absolue) : c'est pour ça que ça ne bouge que bouton maintenu. Trois réglages :

| Réglage | Effet |
| --- | --- |
| Sensibilité | Distance parcourue par le curseur pour un même geste |
| Stabilité | Lisse le tremblement quand tu bouges à peine. Trop haut, les gestes lents semblent mous |
| Précision | Démultiplie les gestes lents pour viser au pixel près |

**Pavé.** Voir le tableau des gestes plus haut. Les réglages (vitesse, accélération, scroll naturel) sont dans « Réglages du pavé ».

**Slides.** Le diaporama doit être la fenêtre active du PC (les touches vont à la fenêtre au premier plan).
- *Suivant* = flèche droite, *Précédent* = flèche gauche, *Démarrer* = F5, *Quitter* = Échap.
- **Pointeur** : mode *Maintenu* (le curseur suit tant que tu tiens le bouton) ou *Toujours* (il suit en continu ; repart éteint à chaque ouverture par sécurité).
- **Curseur ou Laser** : *Curseur* bouge la vraie souris. *Laser* affiche un point rouge par-dessus tout, dans une fenêtre transparente que les clics traversent : elle ne gêne rien et ne vole pas le focus. Il s'éteint quand tu relâches, ou après 3 s sans nouvelles du téléphone.

**Réglages (roue dentée).** Connecter / déconnecter, chercher le PC, saisir une adresse à la main, **Oublier ce PC** (pour réappairer).

### Avec le partage de connexion du téléphone

Pratique sans Wi-Fi : le PC portable se connecte au point d'accès du téléphone.

1. Active le partage de connexion Wi-Fi sur le téléphone, connecte le PC dessus.
2. Lance PandaPointer sur le PC et appaire-le (le QR code contient l'adresse actuelle du PC).
3. À l'avenir, l'adresse change à chaque partage : l'appli retrouve le PC par son nom si l'ancienne adresse ne répond plus.

## Sécurité

Le but : quelqu'un qui est sur le même Wi-Fi que toi ne doit pas pouvoir piloter ta souris ni rejouer tes gestes.

- **Appairage.** Pour chaque téléphone, le PC fabrique un identifiant (8 octets) et une clé secrète aléatoire (32 octets), placés dans le QR code. Le lien est valable **5 minutes** et n'est mémorisé par le PC qu'une fois qu'un message authentique est arrivé.
- **Session.** À chaque connexion, le téléphone et le PC échangent des nombres aléatoires et en tirent une clé de session (HMAC-SHA256). Le PC prouve aussi qu'il connaît la clé : un faux PC est refusé.
- **Messages.** Chaque message est chiffré et authentifié (ChaCha20-Poly1305) avec un compteur qui ne fait qu'augmenter : un message enregistré puis rejoué est rejeté.
- **Stockage.** Les clés du PC sont dans `%APPDATA%\PandaPointer\devices.txt` ; celles du téléphone dans le stockage privé de l'appli. Ne partage pas ton QR code et ne le photographie pas.
- **Oublier un téléphone** : menu du panda → *Téléphones appairés* → *Oublier*. Sa clé cesse de fonctionner.

Ce que ça ne fait pas : ça ne protège pas contre quelqu'un qui a déjà accès à ton PC ou à ton téléphone déverrouillé, et la recherche automatique du PC (diffusion « HELLO ») est en clair : elle révèle seulement le nom de ton PC sur le réseau. Le programme PC n'est pas signé numériquement. Le détail du protocole est en tête de `pc-companion/src/secure.rs`.

## Dépannage

| Symptôme | Piste |
| --- | --- |
| « Aucun PC trouvé » | Vérifie que le panda est présent sur le PC, que les deux appareils sont sur le même réseau, puis le pare-feu (ci-dessous). Tu peux aussi saisir l'adresse du PC à la main (roue dentée). |
| Ça marche en Wi-Fi maison mais pas en partage de connexion | Windows classe souvent ce réseau en « Public » et bloque tout. Paramètres → Réseau et Internet → Wi-Fi → ton réseau → *Type de profil réseau* : **Privé**. |
| Le pare-feu n'a rien demandé | PowerShell **en administrateur** : `New-NetFirewallRule -DisplayName "PandaPointer" -Direction Inbound -Protocol UDP -LocalPort 4210 -Action Allow -Profile Any` |
| « Scanne un nouveau QR code » dans l'appli | Le PC a oublié ce téléphone (ou le QR a expiré). Dans l'appli : roue dentée → *Oublier ce PC*, puis réappaire. |
| Le curseur va dans le mauvais sens | Utilise les interrupteurs « Inverser » de l'onglet Gyro. |
| Le curseur dérive téléphone posé | Onglet Gyro → *Recalibrer le zéro du capteur*. |
| « Gyroscope indisponible » | Le téléphone n'a pas de gyroscope exploitable. Le pavé et les slides marchent quand même. |
| Le port 4210 est déjà utilisé | Lance le programme avec `--port 4211` (et appaire de nouveau). |
| Pas d'icône du panda | Clique sur `^` près de l'horloge, ou *Paramètres → Personnalisation → Barre des tâches* pour l'afficher. |

## Développer

| Outil | Pourquoi | Où |
| --- | --- | --- |
| Rust (avec les Build Tools Visual Studio) | Programme du PC | https://rustup.rs |
| Flutter + Android Studio | Appli du téléphone | https://docs.flutter.dev/install |

**PC** (`pc-companion/`) :

```
cargo run -- --pair                # avec l'icône ; --pair montre aussi le QR code dans la console
cargo run -- --dry-run --no-tray   # console seule, la souris ne bouge pas
cargo test
cargo build --release              # produit target\release\pandapointer-pc.exe
```

| Option | Effet |
| --- | --- |
| `--dry-run` | N'agit pas sur la souris, affiche seulement |
| `--no-tray` | Pas d'icône, mode console |
| `--pair` | Fabrique un QR code d'appairage dès le démarrage |
| `--port <n>` | Change le port (4210 par défaut) |
| `--data-dir <dossier>` | Autre dossier pour `devices.txt` |
| `--insecure` | **Sans chiffrement**, pour les tests uniquement |

**Téléphone** (`mobile/`) : téléphone en mode développeur (Paramètres → À propos → touche 7 fois « Numéro de build » → débogage USB), puis :

```
flutter pub get
flutter run
flutter analyze --no-fatal-infos lib test
flutter test
```

### Organisation du dépôt

```
PandaPointer/
├── pc-companion/        Programme du PC (Rust)
│   ├── src/main.rs        démarrage, boucle réseau
│   ├── src/protocol.rs    format des messages en clair
│   ├── src/secure.rs      appairage, clés, chiffrement, QR code
│   ├── src/cursor.rs      souris, clavier, gestes (enigo)
│   ├── src/laser.rs       fenêtre transparente du laser
│   ├── src/tray.rs        icône et menu de la barre des tâches
│   └── src/state.rs       échanges entre le réseau et le menu
├── mobile/              Appli Android (Flutter)
│   ├── lib/link.dart      liaison réseau, session, reconnexion
│   ├── lib/secure.dart    chiffrement côté téléphone
│   ├── lib/*_page.dart    écrans (gyro, pavé, slides, appairage, scan)
│   └── assets/            polices et icônes
├── assets/              Icône du panda roux (et le script qui la dessine)
└── .github/workflows/   Fabrication automatique du .exe et de l'APK
```

## Architecture et protocole

```
 Téléphone (Flutter)                           PC (Rust)
┌───────────────────────┐   UDP, chiffré   ┌─────────────────────────┐
│ gyro / pavé / slides  │ ───────────────► │ réseau → souris, clavier │
│ appairage, reconnexion│ ◄─────────────── │ laser, icône + menu      │
└───────────────────────┘   ping / pong    └─────────────────────────┘
```

Les messages voyagent en **UDP** : comme des cartes postales, très rapides, sans garantie d'arrivée. Pour un curseur c'est idéal (un mouvement perdu sur cinquante ne se voit pas) alors qu'une connexion fiable (TCP) ferait attendre le curseur à chaque perte.

- Un message = un type (1 octet), un numéro de séquence (2 octets), puis ses données. Types : déplacement, bouton, scroll, diaporama, geste, zoom, laser, recherche, ping.
- Les messages sont ensuite **scellés** (compteur + ChaCha20-Poly1305). Le PC ignore les anciens numéros de séquence.
- Si le téléphone disparaît bouton enfoncé, le PC relâche tout seul après 3 s.
- Les vecteurs de test du chiffrement sont partagés entre Rust, Dart et un script Python indépendant : les trois produisent les mêmes octets.

## Publier une version

Le fichier `.github/workflows/release.yml` teste puis fabrique `PandaPointer-PC.exe` et `PandaPointer.apk`, et les attache à une Release.

```
git tag v0.1.0
git push --tags
```

**Signature de l'APK (une seule fois).** Sans clé, l'APK est signé avec une clé de test : il s'installe, mais une future mise à jour obligera à désinstaller l'ancienne version. Le script `tools/make-android-key.ps1` fabrique la vraie clé, la range hors du dépôt (`%USERPROFILE%\PandaPointer-signing\`) et ajoute les secrets GitHub `ANDROID_KEYSTORE_B64` et `ANDROID_KEYSTORE_PASSWORD` (automatiquement avec GitHub CLI, sinon il te dit quoi coller) :

```
powershell -ExecutionPolicy Bypass -File tools\make-android-key.ps1
```

**Sauvegarde le dossier de la clé** (clé USB, cloud perso) et ne le mets jamais dans le dépôt : sans lui, plus de mises à jour possibles pour les téléphones qui ont l'appli.

## Limites connues

- PC : **Windows seulement** pour l'instant (le code de la souris compile aussi sur macOS, non testé ; le laser est propre à Windows). Téléphone : **Android seulement**.
- Les deux appareils doivent être sur le même réseau local (pas d'accès par Internet).
- Certains réseaux (Wi-Fi d'entreprise, d'invités, ou avec « isolation des clients ») bloquent la communication entre appareils : dans ce cas, utilise le partage de connexion du téléphone.
- Pas de signature de code pour le `.exe` : SmartScreen avertit au premier lancement.
- Le gyroscope donne une vitesse de rotation, pas une direction absolue : pas de « pointage » de l'écran comme une télécommande de console.

## Crédits et licences

- Polices **Bricolage Grotesque** : licence SIL OFL (textes dans `mobile/assets/fonts/`).
- Icônes **Papicons** : licence MIT (`mobile/assets/icons/LICENSE-Papicons.txt`).
- Côté PC : [enigo](https://crates.io/crates/enigo), [windows-sys](https://crates.io/crates/windows-sys), [chacha20poly1305](https://crates.io/crates/chacha20poly1305), [qrcode](https://crates.io/crates/qrcode) et leurs dépendances. Côté téléphone : Flutter, [mobile_scanner](https://pub.dev/packages/mobile_scanner), [pointycastle](https://pub.dev/packages/pointycastle), [sensors_plus](https://pub.dev/packages/sensors_plus) et d'autres.
- Le code et l'icône du projet ont été écrits avec l'aide de Claude (Anthropic).
- Projet de **Panda** ([the-panda-roux-38](https://github.com/the-panda-roux-38)).
- **Licence** : les applications compilées sont gratuites (téléchargement et usage libres) ; le code source reste réservé à son auteur. Voir [`LICENSE`](LICENSE).
