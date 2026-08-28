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
5. **Pas encore fait** : robustesse au bruit d'une vraie photo (éclairage
   variable, papier froissé, grille dont la couleur réelle diffère de
   l'hypothèse `grid_rgb`, document qui ne se détache pas clairement de
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
