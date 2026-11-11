# PandaPointer : étape 2, pavé tactile, scroll et slides

**Étape 2 :** l'appli a maintenant 3 onglets (Gyro, Pavé, Slides). Voir la section « Étape 2 » plus bas
pour savoir quoi tester. Le reste de ce guide (installation, lancement) est inchangé.

**But de l'étape 1 (déjà validée) :** vérifier la sensation. Tu penches le téléphone, le curseur bouge,
et on regarde si c'est fluide. Pas d'appairage, pas de design, pas de sécurité : ça viendra après,
quand on saura que le cœur du projet tient la route.

## Ce qu'il y a dans le dossier

```
PandaPointer/
├── pc-companion/   Programme du PC (Rust) : reçoit les messages et bouge la souris
└── mobile/         Appli du téléphone (Flutter) : lit le gyroscope et envoie les messages
```

Comment ça parle : le téléphone envoie de petits messages en **UDP** par le Wi-Fi.
L'UDP, c'est lancer des cartes postales : très rapide, mais aucune garantie qu'elles arrivent
toutes, ni dans l'ordre. Pour un curseur, c'est parfait (un mouvement perdu sur cinquante,
personne ne le voit), alors qu'un appel téléphonique (TCP) ferait attendre le curseur à chaque
perte. La forme exacte des messages est décrite en tête de `pc-companion/src/protocol.rs`.

## 1. Installer les outils (une seule fois)

| Outil | Pourquoi | Où |
| --- | --- | --- |
| Rust | Compiler le programme du PC | https://rustup.rs (accepte l'installation des « Build Tools Visual Studio » si elle est proposée) |
| Flutter | Compiler l'appli mobile | https://docs.flutter.dev/install (choisis Windows puis Android) |
| Android Studio | Fournit les outils Android à Flutter | https://developer.android.com/studio |

Ensuite, dans un terminal : `flutter doctor`. Il liste ce qui manque encore, une ligne par problème.
Tout doit être vert pour la partie Android.

Sur ton téléphone Android : Paramètres → À propos → touche 7 fois « Numéro de build »
(ça active le mode développeur), puis active le **débogage USB**.

## 2. Lancer le programme du PC

```
cd pc-companion
cargo run -- --dry-run
```

`--dry-run` = mode test : le programme affiche ce qu'il ferait sans toucher à ta souris.
Il t'indique l'adresse IP à taper dans l'appli. La première fois, Windows demande
d'autoriser le pare-feu : accepte pour les **réseaux privés**.

Quand tout marche, relance sans `--dry-run` pour piloter la vraie souris :

```
cargo run
```

(Si la souris s'affole : ferme la fenêtre du terminal, ou Ctrl+C.)

## 3. Lancer l'appli du téléphone

PC et téléphone doivent être sur **le même Wi-Fi**.

```
cd mobile
flutter create . --platforms=android
flutter pub get
flutter run
```

`flutter create .` génère les dossiers Android autour de notre code (il ne touche pas à `lib/main.dart`).
Téléphone branché en USB, `flutter run` installe et lance l'appli.

Dans l'appli : tape l'IP affichée par le PC → **Connecter** → tiens le téléphone à plat, bord du haut
pointé vers l'écran → **maintiens** le gros bouton et tourne le poignet.

## 4. Ce que j'aimerais que tu observes

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
