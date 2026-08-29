# Architecture

Ce document explique les décisions structurantes du projet — le
**pourquoi**, pas le **quoi** (le code parle pour lui-même). À mettre à
jour quand une de ces décisions change.

## Principe directeur

CardioLens est une **aide à la décision**, jamais un diagnostic
autonome. Cette contrainte n'est pas qu'un avertissement affiché à
l'écran — elle façonne l'architecture :

- Chaque alerte porte sa **source** (`AlertSource.RULE` ou `AlertSource.AI`)
  et ne se mélange jamais avec les autres dans l'affichage.
- Une alerte "règle" est **toujours explicable** : elle vient d'une
  mesure directe comparée à un seuil publié, jamais d'une boîte noire.
- Le pipeline **échoue bruyamment** (`ECGProcessingError`) plutôt que de
  renvoyer une mesure approximative en silence — un chiffre faux mais
  plausible est plus dangereux qu'une erreur explicite.

## Pourquoi les règles cliniques avant le ML

Le moteur de règles (`rules.py`) couvre les mesures directes (FC, PR,
QRS, QTc, axe) avec des seuils publiés (littérature ESC/AHA). Aucune
donnée d'entraînement n'est nécessaire, le comportement est entièrement
explicable, et c'est suffisant pour valider le concept avec un médecin
avant d'investir dans du ML.

Le ML (pas encore implémenté) est prévu comme un **complément**, pas un
remplacement — pour les cas que des seuils simples ne peuvent pas
capturer (fibrillation atriale, ischémie). Voir `AlertSource.AI` dans
`models.py`, déjà prévu dans le modèle de données.

## Pourquoi les seuils sont paramétrables (`GuidelineThresholds`)

Les seuils cliniques ne sont pas universels : l'ESC (Europe) et l'AHA
(États-Unis) publient des recommandations légèrement différentes, et la
formule de correction du QT varie (Bazett, Fridericia...). Coder les
seuils en dur aurait rendu toute expansion à un autre pays/référentiel
coûteuse. `GuidelineThresholds` est une donnée, pas de la logique — un
nouveau référentiel est un nouveau profil, pas une réécriture.

## Limite actuelle : mono-dérivation

`measure_ecg` ne traite qu'**une seule dérivation** (DII) pour l'instant.
C'est une simplification délibérée pour le POC, mais elle a un coût réel :

- Une vraie lecture clinique (ischémie, localisation d'un infarctus)
  nécessite les 12 dérivations.
- La délinéation par dérivation unique est plus bruitée qu'un consensus
  multi-dérivations (voir la méthode `_robust_interval_ms`, qui existe
  précisément pour compenser ce bruit).

**Ne pas retro-adapter du multi-dérivation sur cette base mono-dérivation
en bricolage.** Quand le format d'entrée réel (SCP-ECG, 12 dérivations)
sera intégré, `measure_ecg` doit être repensé pour prendre un
enregistrement multi-dérivations dès la signature de la fonction.

**Exception délibérée, pas une contradiction de ce qui précède** : l'axe
électrique (`electrical_axis_deg`) peut désormais être calculé —
`signal_processing.compute_electrical_axis(lead_i, lead_avf,
sampling_rate)`, méthode hexaxiale standard à deux dérivations
(`angle = atan2(net_aVF, net_I)`, chaque dérivation délinéée
indépendamment, amplitude nette approximée par R-peak moins S-peak par
battement, médiane sur tous les battements). C'est **additif, pas une
refonte** : `measure_ecg` garde exactement sa signature mono-dérivation
et son comportement inchangé ; `/analyze` accepte juste deux champs
optionnels `lead_i`/`lead_avf`, et ne calcule l'axe que si les deux sont
fournis (sinon `None`, jamais fabriqué). L'app mobile ne collecte pas
encore d'entrée multi-dérivations — l'axe reste donc `None` de bout en
bout côté app aujourd'hui, la brique backend est prête mais pas
branchée.

## Pourquoi `_robust_interval_ms` utilise la médiane, pas la moyenne

Sur de vrais ECG (PTB-XL), la délinéation NeuroKit2 par battement est
bruitée : quelques battements mal détectés suffisent à fausser une
simple moyenne (déjà observé : un ECG étiqueté "normal" ressortait avec
un QRS de 168-208 ms avec la méthode `dwt` + moyenne). La médiane,
combinée à un rejet des valeurs hors plage physiologique, est robuste à
ces valeurs aberrantes résiduelles. Voir l'historique git de
`signal_processing.py` pour le diagnostic complet.

## Statut de `api.py`

Le module FastAPI existe mais n'est **branché à rien** pour l'instant —
prévu pour l'app mobile, pas encore construite. Il est testé
(`tests/test_api.py`) pour ne pas devenir du code mort silencieux, mais
son design n'est pas figé tant que l'app mobile n'impose pas de vraies
contraintes d'intégration.

## Outil de test web (`webapp.py`)

Interface Streamlit délibérément séparée du reste : elle importe
directement le package `cardiolens` (mêmes fonctions que l'API), sans
dupliquer de logique. Son seul rôle est de permettre une validation
clinique rapide avant que l'app mobile existe — pas un second produit à
maintenir. Exclue de la mesure de couverture de tests (`pyproject.toml`,
`[tool.coverage.run]`) : c'est de la glue d'interface, pas de la
logique métier.

## Numérisation d'image (`image_digitization.py`) — chantier en cours

Extraction d'un tracé ECG depuis une photo de papier imprimé. Volontairement
découpé en incréments séparés, chacun validé avant le suivant, plutôt que
construit d'un bloc :

1. **Fait** : suivi du tracé colonne par colonne sur une image **propre**
   (fond clair, trait sombre net) — `extract_trace_from_image` /
   `trace_to_signal`. Validé par un test qui dessine une courbe connue et
   vérifie que la forme récupérée corrèle à >0.9 avec l'originale.
2. **Fait** : détection de l'espacement du quadrillage millimétré (couleur
   connue, grille carrée supposée) par autocorrélation, et calibration
   pixels → ms/mV à partir de cet espacement + des standards papier ECG
   (25 mm/s, 10 mm/mV) — `detect_grid_spacing_px` / `calibrate_trace`.
   Validé sur une grille synthétique d'espacement connu (retrouvé à ±1px).
3. **Fait** : segmentation d'une page complète en panneaux par dérivation
   (grille rows×cols, typiquement 6×2) — `segment_grid_panels`. Chaque
   frontière naïve (division égale) est affinée en cherchant, dans une
   marge autour d'elle, la ligne/colonne la moins encrée — le vrai espace
   entre panneaux plutôt qu'une division pixel-parfaite supposée. Validé
   sur une page synthétique 3×2 à courbes distinctes par case (corrélation
   >0.85 entre chaque case extraite et la courbe qui lui était destinée).
4. **Fait** : correction de perspective (photo prise de biais) —
   `find_document_corners` (détection de contour via OpenCV : Canny +
   contours + approximation polygonale, avec rejet si le contour n'est pas
   convexe, pas assez rectangulaire, ou couvre quasiment tout le cadre —
   ce dernier cas a été un vrai faux positif rencontré sur une image de
   bruit pur, pas juste une précaution théorique) et `correct_perspective`
   (transformation homographique vers une page à plat). Validé en
   simulant une "photo prise de biais" (page synthétique projetée sur un
   canevas plus grand via une transformation connue), puis en vérifiant
   que l'espacement de grille redétecté après correction retombe à ±2px
   de la valeur d'origine.
5. **Premier test sur une vraie image (pas synthétique) — enseignements
   concrets.** Testé sur une image d'ECG 12 dérivations trouvée en ligne
   (pas une photo de patient, mais un vrai rendu, avec vraie compression
   JPEG et vraie grille) :
   - **Confirmé faux** : l'hypothèse de grille rose/rouge. Cette image a
     une grille **grise** (~240,240,240) — `detect_grid_spacing_px` avec
     `grid_rgb` par défaut échoue silencieusement (lève l'erreur prévue,
     donc pas dangereux, mais confirme qu'il faudra détecter la couleur
     plutôt que la supposer).
   - **Bug réel trouvé et corrigé** dans `extract_trace_from_image` : une
     ligne sombre persistante (bordure/grille majeure) à une hauteur fixe
     attirait le tracé extrait vers elle dans chaque colonne — une simple
     moyenne des pixels sombres ne distingue pas un élément immobile du
     vrai tracé qui bouge. Corrigé en excluant d'abord les lignes sombres
     dans >85% des colonnes (forcément pas le tracé, qui varie), puis en
     prenant le plus grand amas restant par colonne. Test de non-
     régression ajouté (`test_extract_trace_ignores_persistent_decoy_line`)
     avant même de revalider sur la vraie image.
   - Après correction : le tracé extrait sur cette image réelle correspond
     visuellement aux vrais complexes QRS (mêmes pics, même rythme) —
     première validation sur du contenu non synthétique.
6. **Fait** : détection automatique de la couleur de grille —
   `detect_grid_color`. Principe : le fond (papier) domine largement en
   luminosité, le tracé est la population la plus sombre (son **minimum**,
   pas un percentile — un tracé fin peut représenter moins de 1% des
   pixels, et un seuil par percentile retombait alors sur la couleur de la
   grille elle-même plutôt que sur le noir réel, bug trouvé en écrivant le
   test). La grille est la couleur médiane de ce qui reste entre les deux.
   Revalidé sur la vraie image de l'incrément 5, **sans lui donner aucun
   indice de couleur** : détecte (235,235,235), tolérance 27 — cohérent
   avec la mesure manuelle faite précédemment (~240,240,240) — et retrouve
   le même espacement de grille (23px) qu'avec la couleur donnée à la
   main.
8. **Testé sur un jeu d'images réelles externe (ecg-image-kit, BSD-3,
   github.com/alphanumericslab/ecg-image-kit)** — pas des photos de
   patient, mais un vrai jeu de recherche avec de vraies images
   compressées/scannées, pas synthétiques. Deux enseignements :
   - **Confirmé** : la disposition en grille varie dans la vraie vie
     (3×4 avec bande de rythme, 6×2, etc.) — `segment_grid_panels`
     accepte déjà `rows`/`cols` en paramètre, pas de changement
     nécessaire, juste une confirmation qu'il ne faut jamais supposer
     une disposition fixe sans la connaître.
   - **Tentative de correctif abandonnée, documentée pour ne pas la
     retenter** : un nom de dérivation imprimé dans le panneau ("aVR",
     "V2"...) peut corrompre le tracé extrait juste à son emplacement (le
     texte est aussi sombre que le tracé). Essayé : ne garder que les
     composantes connexes assez larges pour être le vrai tracé — a
     complètement cassé l'extraction sur les vraies images, car le vrai
     tracé s'y fragmente en morceaux de taille comparable au texte
     (compression JPEG, trait fin). Testé aussi une variante par
     dimensions (largeur ET hauteur) : les fragments de tracé et les
     lettres du texte ont des tailles trop proches sur ce jeu de données
     pour être séparés de façon fiable. **Retiré** plutôt que de garder
     un correctif qui casse plus qu'il ne répare — reste un problème
     ouvert.
10. **Deuxième tentative sur le problème d'étiquette — OCR, pas de la
    géométrie** (`mask_text_regions`, `pytesseract` + le moteur
    `tesseract` en dépendance système, pas juste une lib Python — donc un
    vrai ajout aux prérequis de déploiement, pas gratuit). Contrairement
    à la première tentative (taille/forme des composantes connexes,
    abandonnée ci-dessus), celle-ci pose la vraie question : "est-ce que
    ce sont des caractères imprimés", plutôt que de deviner à partir de
    la forme. Peint en couleur de fond toute région où l'OCR détecte du
    texte, avant l'extraction du tracé.

    **Marche, avec une limite précise trouvée en la testant, pas
    supposée** : sur une image synthétique où "aVR" est placé assez près
    du tracé pour le contaminer (colonnes partagées) mais sans que les
    lettres soient visuellement traversées par le trait de courbe,
    `mask_text_regions` corrige entièrement la contamination (erreur
    moyenne 32.7px → 0px sur la zone affectée). **Mais** : quand le trait
    de la courbe traverse visuellement une lettre (ex. juste au sommet
    d'un complexe QRS — le cas le plus gênant, pas un cas rare),
    `tesseract` lui-même échoue à détecter le texte — testé avec la même
    police, la même taille : "aVR" lu correctement (confiance ~87)
    isolé ou à quelques pixels du trait, mais retourne une chaîne vide
    dès que le trait croise une lettre. Le masquage ne fait alors
    silencieusement rien. Voir le test de non-régression dans
    `test_image_digitization.py` pour le placement exact qui marche et
    celui qui ne marche pas.
11. **Pas encore fait** : la robustesse au bruit d'une vraie photo prise
    au téléphone (éclairage variable, papier froissé, document qui ne se
    détache pas clairement de son arrière-plan) — toujours jamais testée
    sur une vraie photo, synthétique et jeux de recherche seulement.

**Hypothèses fortes à garder en tête** — la grille est supposée carrée
(même espacement horizontal/vertical) et sa couleur doit être connue
d'avance (`grid_rgb`, un rose/rouge par défaut) ; aucune des deux n'a
encore été vérifiée sur une vraie photo, seulement sur du synthétique. La
détection de contour (`find_document_corners`) suppose aussi que le
document se distingue nettement de son arrière-plan — pas garanti sur une
vraie photo (bureau blanc, mauvais éclairage, etc.).

**Ne pas brancher ce module sur le parcours "Scanner via photo" de l'app
tant que l'étape 2 n'est pas faite** — aujourd'hui ce parcours mobile
affiche un cas de démonstration, pas une vraie analyse de la photo, et
c'est délibéré (voir `mobile/lib/screens/scanning_screen.dart`). Le
brancher prématurément referait exactement l'erreur déjà rencontrée avec
la délinéation NeuroKit2 : un résultat qui a l'air plausible mais qui est
silencieusement faux.

## Détection IA — premier modèle (fibrillation atriale)

Premier composant `AlertSource.AI` réellement branché (jusqu'ici la
section "IA" de l'interface était vide, prête mais sans modèle derrière).

**Approche** : features HRV classiques (SDNN, RMSSD, pNN50, coefficient de
variation RR) calculées à partir des mêmes pics R déjà validés dans
`signal_processing.py`, puis régression logistique — volontairement pas
un modèle profond sur signal brut. Un physicien peut se voir expliquer
exactement ce que mesure chaque feature ; une boîte noire, non. Voir
`afib_features.py`, `afib_detection.py`, `scripts/train_afib_model.py`.

**Données d'entraînement — deux versions, la seconde bien plus fiable.**
Une première version utilisait PTB-XL (48 cas confirmés seulement — trop
petit, cas "francs" uniquement). Remplacée par la **MIT-BIH Atrial
Fibrillation Database (AFDB, PhysioNet, licence Open Data Commons
Attribution v1.0)** : 23 patients réels, chacun avec plusieurs heures
d'ECG continu et le rythme annoté dans le temps (épisodes FA/normal qui
s'enchaînent), découpé en fenêtres de 30s → **3342 fenêtres, 1543 FA /
1799 normales**. Bien plus représentatif qu'une poignée de cas isolés.

**Une source d'ECG "à but pédagogique" a été explicitement écartée** —
un collègue a suggéré un site (e-cardiogram.com) qui publie des exemples
ECG avec interprétation. Ses mentions légales interdisent formellement
toute reproduction hors usage strictement personnel ("La reproduction de
tout ou partie de ce site... est formellement interdite sauf autorisation
expresse"). Nourrir un modèle avec n'entre pas dans l'exception "usage
personnel" — refusé, malgré l'insistance, en faveur d'AFDB (licence
ouverte, faite pour cet usage).

**Piège méthodologique évité, pas juste une note en bas de page** : les
fenêtres d'un même patient sont fortement corrélées (même physiologie,
mêmes conditions d'enregistrement). Une validation croisée par fenêtre
aurait mélangé des fenêtres du même patient entre entraînement et test —
fuite de données qui gonfle artificiellement les métriques. La validation
croisée est faite **par patient** (`GroupKFold` sur l'identifiant
d'enregistrement) : chaque pli de test contient des patients que le
modèle n'a jamais vus à l'entraînement. C'est la façon honnête d'estimer
la généralisation, pas la plus flatteuse.

**Résultat (validation croisée par patient)** : AUC 0.975 (± 0.017),
sensibilité 96.3%, spécificité 90.0%. Toujours un POC — 23 patients reste
modeste, et aucun cas limite (FA paroxystique, extrasystoles fréquentes)
n'a été testé spécifiquement — mais un signal bien plus solide que la
version PTB-XL, obtenu avec une méthodologie qui ne se trompe pas
elle-même sur ses propres résultats.

**Comment cette limite est reflétée dans le produit**, pas juste dans un
commentaire de code :
- Toujours `AlertSource.AI`, jamais mélangé aux alertes RÈGLE
- Toujours accompagné d'un score de confiance (`confidence`)
- Message explicite "prédiction algorithmique, à corréler cliniquement"
- Seuil de décision (`AFIB_ALERT_THRESHOLD` dans `api.py`) resté à la
  valeur par défaut du classifieur (0.5), pas retouché pour améliorer
  artificiellement les métriques

**Robustesse** : si la prédiction IA échoue pour une raison quelconque
(modèle introuvable, erreur interne), `api.py` l'avale et renvoie quand
même les alertes RÈGLE — la couche IA ne doit jamais casser la couche
règles, qui reste la plus fiable.

**Cas limites — un premier test fait, résultat honnête** (pas la
validation FA paroxystique idéale, mais la meilleure disponible sans
dataset dédié — `scripts/evaluate_afib_edge_cases.py`). Aucun dataset de
FA paroxystique n'est disponible sous une licence utilisable ici (voir
plus haut pourquoi e-cardiogram.com a été écarté). AFDB offre un proxy
réel, pas inventé : ses enregistrements continus de plusieurs heures par
patient contiennent de vraies transitions N↔FA dans le temps. Le script
compare, avec le même protocole de validation croisée par patient que
l'entraînement, les fenêtres les plus proches d'une transition de rythme
(premier/dernier segment extrait) aux fenêtres bien à l'intérieur d'un
rythme stable.

**Résultat, surprenant** : les fenêtres proches d'une transition ne sont
pas moins bien classées — légèrement mieux, même (exactitude 0.948 contre
0.926, AUC 0.977 contre 0.966, sur 746 fenêtres de transition contre 2596
stables). Pas de preuve de dégradation près des changements de rythme
dans ce proxy. À interpréter prudemment : "proche d'une transition" dans
le découpage par annotation ne veut pas forcément dire "contient des
battements réellement mixtes" — une vraie validation sur de la FA
paroxystique annotée battement par battement reste la référence, non
disponible ici.

**Prochaine étape, pas encore faite** : une vraie validation FA
paroxystique si un dataset licencié adéquat devient disponible ;
extrasystoles fréquentes, jamais testées spécifiquement.

## Comptes et authentification

Construit plus tôt que prévu — pas un raccourci, un vrai problème trouvé
en construisant le compte-rendu PDF : le champ "Validé par" affichait un
placeholder texte (`[Dr. Nom Prénom]`), non relié à personne. N'importe
qui pouvait taper n'importe quel nom. Ce n'est pas un problème de
protection d'accès (l'authentification classique), c'est un problème
d'**identité** — qui a réellement validé cette interprétation.

**Modèle cible** : un médecin, son propre téléphone, son propre compte —
pas de connexions partagées. Ce modèle a une conséquence importante :
une fois que chaque médecin a son propre appareil, l'essentiel du besoin
("qui valide ce compte-rendu") est déjà couvert par une identité propre à
l'appareil ; un vrai compte avec serveur n'ajoute de valeur que pour la
synchronisation entre appareils, la sauvegarde centralisée, et une
supervision multi-médecins plus tard.

**Implémentation** : FastAPI + SQLite (`db.py`, `auth_models.py`,
`auth.py`) — explicitement pas Firebase. Mots de passe hashés avec
`bcrypt` directement (pas `passlib`, incompatible avec les versions
récentes de `bcrypt` — `AttributeError: module 'bcrypt' has no attribute
'__about__'`, bug connu, contourné en appelant `bcrypt` sans la couche de
compatibilité). Tokens JWT (30 jours — un téléphone personnel, pas un
kiosque partagé). Routes : `POST /auth/register`, `POST /auth/login`,
`GET /auth/me` (protégée, sert de preuve que l'authentification protège
vraiment quelque chose).

Le secret JWT par défaut (`dev-only-insecure-secret-change-me`) est
volontairement voyant : un vrai déploiement doit le remplacer via
`CARDIOLENS_JWT_SECRET`, non négociable.

**Depuis étoffé côté mobile et backend** : écrans de connexion/inscription,
menu compte + écran Profil, changement de mot de passe (`POST
/auth/me/password`), et un profil de cabinet — nom de cabinet/hôpital
(`PATCH /auth/me`) et logo uploadé par médecin (`POST`/`GET`/`DELETE
/auth/me/logo`, stocké dans `user_logos/` — gitignored, même raisonnement
que la base SQLite : contenu propre au médecin, pas à committer). Le
compte-rendu affiche désormais le vrai nom du médecin connecté et son
logo/cabinet à la place des anciens placeholders `[Dr. Nom Prénom]` et
`[Cabinet médical]`.

**Import réel et export PDF, aussi ajoutés** : "Importer un ECG" ouvre un
vrai sélecteur de fichier (au lieu de proposer un cas de démo) et parse le
CSV côté client de façon tolérante (en-tête, colonne temps — même logique
que `io_utils.load_signal_from_csv` côté backend), avant d'envoyer le
signal à `/analyze`. Aucun repli sur des données de démo en cas d'échec —
il n'y a pas de données de démo honnêtes pour un fichier que le médecin a
réellement apporté. "Télécharger PDF" / "Partager" génèrent un vrai PDF
(paquets `pdf` + `printing`) et l'envoient à la feuille de partage du
système — pas d'API de téléchargement direct sur mobile sans permissions
de stockage supplémentaires.
