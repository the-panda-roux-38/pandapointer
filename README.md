# PandaPointer

Ton téléphone Android devient la souris de ton PC Windows : gyroscope, pavé tactile avec les gestes
Windows, scroll, zoom, télécommande de diaporama et pointeur laser. Tout passe par ton Wi-Fi, chiffré.

```
PandaPointer/
├── pc-companion/   Programme du PC (Rust) : icône dans la barre des tâches, bouge la souris
├── mobile/         Appli du téléphone (Flutter)
├── assets/         Icône du panda roux (+ le script qui la dessine)
└── .github/        Fabrication automatique du .exe et de l'APK
```

## Installer (sans rien compiler)

1. Va dans **Releases** sur GitHub et télécharge `PandaPointer-PC.exe` et `PandaPointer.apk`.
2. **PC** : double-clique `PandaPointer-PC.exe`. Un panda apparaît près de l'horloge (clique sur `^` s'il est
   caché). La première fois, Windows demande d'autoriser le pare-feu : accepte pour les **réseaux privés**.
   Windows Defender SmartScreen peut dire « application non reconnue » : *Informations complémentaires* → *Exécuter quand même*
   (le programme n'est pas signé, ça coûte cher).
3. **Téléphone** : ouvre `PandaPointer.apk` (autorise « installer des applications inconnues » pour ton navigateur
   ou ton gestionnaire de fichiers, une seule fois).
4. **Appairer** : au premier lancement le PC affiche un QR code. Dans l'appli, touche *Scanner le QR code*.
   Plus tard : clic sur le panda → *Appairer un téléphone…*. C'est fait une fois pour toutes :
   ensuite l'appli retrouve le PC toute seule et se reconnecte après une coupure.

Le menu du panda : état de la connexion, *Appairer un téléphone…*, *Téléphones appairés* (pour en oublier un),
*Lancer avec Windows*, *Quitter*.

## Sécurité, en bref

Chaque téléphone appairé a sa propre clé secrète (dans le QR code, valable 5 minutes, à ne pas photographier
ni partager). Les messages sont chiffrés (ChaCha20-Poly1305) et protégés contre le rejeu : quelqu'un sur le même
Wi-Fi ne peut ni te piloter la souris, ni rejouer tes gestes. Les clés du PC sont dans `%APPDATA%\PandaPointer\devices.txt`.
Pour retirer un téléphone : menu du panda → *Téléphones appairés* → *Oublier*.

## Fabriquer les versions (pour toi)

Le fichier `.github/workflows/release.yml` fabrique le `.exe` et l'APK sur GitHub.

```
git tag v0.1.0
git push --tags
```

Après quelques minutes, une *Release* apparaît avec les deux fichiers.

**Signature de l'APK (recommandé, une seule fois).** Sans clé, l'APK est signé avec une clé de test : ça marche,
mais une mise à jour future exigera de désinstaller l'ancienne version. Pour avoir une vraie clé :

```
keytool -genkeypair -v -keystore release.jks -alias pandapointer -keyalg RSA -keysize 2048 -validity 10000
```

Puis sur GitHub : *Settings → Secrets and variables → Actions* : ajoute `ANDROID_KEYSTORE_PASSWORD`
(le mot de passe choisi, identique pour le magasin et la clé) et `ANDROID_KEYSTORE_B64`
(le contenu de `release.jks` en base64 : `[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.jks"))`).
**Garde `release.jks` en lieu sûr, hors du dépôt** : si tu le perds, tu ne pourras plus mettre à jour l'appli installée.

## Développer

| Outil | Pourquoi | Où |
| --- | --- | --- |
| Rust | Compiler le programme du PC | https://rustup.rs |
| Flutter + Android Studio | Compiler l'appli | https://docs.flutter.dev/install |

PC :

```
cd pc-companion
cargo run -- --pair             # avec icône ; --pair montre aussi le QR dans la console
cargo run -- --dry-run --no-tray   # console seule, la souris ne bouge pas
cargo test
```

Options : `--dry-run` (ne bouge pas la souris), `--no-tray` (pas d'icône, console), `--pair` (QR au démarrage),
`--port 4211`, `--data-dir <dossier>`, `--insecure` (sans chiffrement, **pour les tests uniquement**).

Téléphone :

```
cd mobile
flutter pub get
flutter run
```

Dans la version de développement (USB), l'appli demande aussi le QR code : lance `cargo run -- --pair` sur le PC.
Messages : de petits paquets UDP décrits en tête de `pc-companion/src/protocol.rs` et `secure.rs`.

---
## Ce que j'aimerais que tu observes

1. **Les axes** : droite = curseur à droite ? haut = curseur en haut ? Sinon, utilise les deux
   interrupteurs « Inverser » (je n'ai pas pu le tester sur un vrai téléphone, c'est le point le plus probable à corriger).
2. **La fluidité** : curseur saccadé ? Retard entre le geste et le curseur ?
3. **La dérive** : quand tu relâches le bouton, le curseur s'arrête-t-il net ?
4. **La sensibilité** : le curseur de sensibilité, c'est comme le DPI de la souris dans Overwatch.
   Quelle valeur te convient pour traverser ton écran confortablement ?
5. **Les clics** : gauche et droit, y compris un clic maintenu pour glisser un fichier.

Note ce que tu vois (même en vrac) : c'est la matière de l'étape 2.

## Étape 2 : quoi tester

**Pour appliquer la mise à jour :** relance le programme du PC (`cargo run`, **sans** `--dry-run`),
puis relance l'appli (`flutter run` dans `mobile`). Rien d'autre à installer.

L'adresse IP et le bouton **Connecter** restent en haut, quel que soit l'onglet.

**Onglet Pavé** (touchpad de portable Windows) :

| Geste | Action |
| --- | --- |
| 1 doigt glisse | curseur (avec accélération réglable) |
| tap | clic gauche |
| double-tap | double-clic |
| double-tap puis glisser | cliquer-glisser (déplacer une fenêtre, sélectionner du texte) |
| 2 doigts glissent | scroll vertical et horizontal, avec inertie |
| 2 doigts pincent / écartent | zoom (Ctrl + molette : navigateur, Word, photos...) |
| tap à 2 doigts | clic droit |
| 3 doigts : haut / bas | vue des tâches (Win+Tab) / bureau (Win+D) |
| 3 doigts : gauche / droite | appli précédente / suivante (Alt+Tab) |
| tap à 3 doigts | recherche (Win+S) |
| 4 doigts : gauche / droite | bureau virtuel précédent / suivant |
| tap à 4 doigts | notifications (Win+A) |

Dans « Réglages du pavé » : vitesse, accélération, scroll naturel.

**Onglet Slides** (ouvre un PowerPoint ou un PDF en plein écran sur le PC) :
- Suivant = flèche droite, Précédent = flèche gauche, Démarrer = F5, Quitter = Échap.
- Le diaporama doit être la fenêtre active sur le PC : les touches vont à la fenêtre au premier plan.
- **Pointeur gyro** : deux modes. *Maintenu* : tu tiens le bouton et le curseur suit le téléphone.
  *Toujours* : tu allumes « Pointeur actif » et le curseur suit en continu (ça ne marche que sur l'onglet Slides,
  et ça repart éteint à chaque fois par sécurité). La sensibilité est la même que sur l'onglet Gyro.
- **Curseur ou Laser** : *Curseur* = ça bouge la vraie souris. *Laser* = un point rouge lumineux apparaît par-dessus
  ton diaporama et suit le téléphone, **sans bouger le vrai curseur** (il apparaît là où se trouve le curseur,
  puis se déplace tout seul). Il s'éteint quand tu relâches le bouton (ou après 3 s sans nouvelles du téléphone).
  Le laser est dessiné par une fenêtre transparente que les clics traversent : il ne gêne rien et ne vole pas le focus.
  Windows seulement pour l'instant (sur Mac, le « laser » bougerait le curseur).

**À observer pour le laser :** le point est-il bien visible par-dessus PowerPoint en plein écran ? Sur tes deux écrans ?
Bien centré sur le curseur au moment où il s'allume ? Pas de décalage de position ?

**À observer :** tap bien reconnu (pas de clic en glissant) ? Scroll trop rapide ou trop lent ?
Le zoom est-il confondu avec le scroll ? Les gestes 3 et 4 doigts partent-ils tout seuls par erreur ?

## Gyro plus précis : quoi régler et tester

L'onglet **Gyro** a maintenant trois réglages (partagés avec Slides) :

| Réglage | Ce que ça fait | Si tu constates... |
| --- | --- | --- |
| **Sensibilité** | Distance parcourue par le curseur pour un geste donné | curseur trop lent ou trop rapide |
| **Stabilité** | Lisse le tremblement quand tu bouges à peine (le lissage disparaît dès que tu bouges vraiment) | ça tremble : monte. Ça semble mou sur les gestes lents : baisse |
| **Précision petits mouvements** | Démultiplie les gestes lents pour viser au pixel près | trop de mal à viser un petit bouton : monte |

Et « Recalibrer le zéro du capteur » si le curseur dérive tout seul téléphone posé (il se corrige déjà
tout seul quand le téléphone est quasi immobile).

Ce qui a changé sous le capot : le gyroscope est lu 200 fois par seconde (au lieu de 50), avec l'heure
donnée par le capteur lui-même, et les mouvements sont envoyés par petits groupes d'environ 7 ms.

**À observer :** compare avec l'ancienne version. Le tremblement a-t-il diminué ? Le retard a-t-il changé ?
Arrives-tu à viser un petit bouton avec le laser ? Si le gyro ne répond plus du tout, la barre d'état
affiche « Gyroscope indisponible » : préviens-moi avec le message exact.

## Utiliser PandaPointer avec le partage de connexion de ton téléphone

Pratique quand il n'y a pas de Wi-Fi : le PC portable se connecte au point d'accès Wi-Fi de ton téléphone.

1. Sur le téléphone : active le **partage de connexion Wi-Fi** (point d'accès).
2. Sur le PC : connecte-toi à ce Wi-Fi.
3. **Une seule fois sur le PC** : Windows classe souvent ce réseau en « Public » et bloque alors tout ce qui arrive. Deux solutions (une suffit) :
   - Paramètres → Réseau et Internet → Wi-Fi → clique sur le réseau du téléphone → Type de profil réseau : **Privé** ;
   - ou, dans PowerShell **ouvert en administrateur** :
     `New-NetFirewallRule -DisplayName "PandaPointer (UDP 4210)" -Direction Inbound -Protocol UDP -LocalPort 4210 -Action Allow -Profile Any`
4. Sur le PC : `cargo run` dans `pc-companion`.
5. Sur le téléphone : appuie sur **Chercher mon PC**. Il le trouve tout seul et se connecte (l'adresse IP du PC change à chaque fois sur un partage de connexion, c'est pour ça que la recherche est utile).

Si rien n'est trouvé : le programme tourne-t-il ? le PC est-il bien sur le Wi-Fi du téléphone ? la règle de pare-feu est-elle faite ? Tu peux aussi taper l'adresse à la main (la dernière utilisée est retenue).

## Limites connues (volontaires)

- Aucune sécurité : toute personne sur ton Wi-Fi qui connaît l'IP pourrait envoyer des messages. À utiliser chez toi.
- Android + Windows seulement, pas de calibrage ni de lissage avancé (c'est justement ce qu'on veut améliorer ensuite).
- Le gyroscope mesure une **vitesse de rotation** (comme un compteur de vitesse, pas une boussole) :
  le téléphone ne sait pas « vers où il pointe », il sait seulement « à quelle vitesse il tourne ».
  C'est pour ça que le bouton maintenu est important : on ne cumule que pendant le geste.
- Si le téléphone disparaît bouton enfoncé, le PC relâche tout seul après 3 secondes.

## Git

```
git init
git add .
git commit -m "Étape 2 : pavé tactile, scroll et slides"
```
