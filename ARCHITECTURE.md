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

- L'axe électrique reste `None` — il faut au moins 2 dérivations (I, aVF).
- Une vraie lecture clinique (ischémie, localisation d'un infarctus)
  nécessite les 12 dérivations.
- La délinéation par dérivation unique est plus bruitée qu'un consensus
  multi-dérivations (voir la méthode `_robust_interval_ms`, qui existe
  précisément pour compenser ce bruit).

**Ne pas retro-adapter du multi-dérivation sur cette base mono-dérivation
en bricolage.** Quand le format d'entrée réel (SCP-ECG, 12 dérivations)
sera intégré, `measure_ecg` doit être repensé pour prendre un
enregistrement multi-dérivations dès la signature de la fonction.

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
9. **Pas encore fait** : le problème d'étiquette ci-dessus, et la
   robustesse au bruit d'une vraie photo prise au téléphone (éclairage
   variable, papier froissé, document qui ne se détache pas clairement de
   son arrière-plan).

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

**Limite à ne jamais perdre de vue** : PTB-XL ne contient que **48
enregistrements** avec un diagnostic de fibrillation atriale confirmé à
100% (c'est un dataset généraliste, pas centré sur les arythmies). Le
modèle entraîné dessus atteint une AUC ~0.99 en validation croisée — un
chiffre **optimiste**, pas un chiffre validé cliniquement : l'échantillon
est petit, et composé uniquement de cas "francs" (diagnostic confirmé à
100%, aucun cas limite comme une FA paroxystique ou de simples
extrasystoles fréquentes qui pourraient tromper le modèle). C'est un
signal encourageant que l'approche (irrégularité RR) va dans le bon sens
— cohérent avec la littérature publiée sur la détection de FA par HRV —
pas une preuve de fiabilité clinique.

**Comment cette limite est reflétée dans le produit**, pas juste dans un
commentaire de code :
- Toujours `AlertSource.AI`, jamais mélangé aux alertes RÈGLE
- Toujours accompagné d'un score de confiance (`confidence`)
- Message explicite "prédiction algorithmique, à corréler cliniquement"
- Seuil de décision (`AFIB_ALERT_THRESHOLD` dans `api.py`) resté à la
  valeur par défaut du classifieur (0.5), pas retouché pour améliorer
  artificiellement des métriques sur un si petit échantillon

**Robustesse** : si la prédiction IA échoue pour une raison quelconque
(modèle introuvable, erreur interne), `api.py` l'avale et renvoie quand
même les alertes RÈGLE — la couche IA ne doit jamais casser la couche
règles, qui reste la plus fiable.

**Prochaine étape, pas encore faite** : élargir le jeu d'entraînement au
maximum de cas AFIB disponibles ailleurs (PTB-XL seul est trop petit pour
une vraie confiance), et valider sur des cas limites (FA paroxystique,
extrasystoles fréquentes) avant d'envisager un usage au-delà du POC.
