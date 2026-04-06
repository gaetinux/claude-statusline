# Status Line v2 : Layout Intelligent Contextuel

## Objectif

Réécrire le script `statusline-command.sh` pour exploiter toutes les données JSON disponibles de Claude Code, avec un layout qui s'adapte à la largeur du terminal et qui met en avant les infos critiques dynamiquement.

## Structure des segments

Le layout est composé de segments séparés par `│` (U+2502). Chaque segment a un niveau de priorité et des conditions d'apparition.

### Segments et priorités

| Segment | Priorité | Condition d'apparition |
|---|---|---|
| `➜ user dir` | Toujours | Toujours |
| Modèle | Toujours | Toujours |
| Barre ctx % | Tier 2 | Toujours (si donnée présente) |
| Barre 5h % | Toujours | Dès que la donnée existe |
| Barre 7j % | Tier 3 | Seulement si > 50% |
| Coût `$X.XX` | Tier 2 | Seulement si > $0.10 |
| Durée session | Tier 3 | Seulement si > 10min |
| Lignes +/- | Tier 3 | Seulement si > 0 lignes modifiées |
| Peak/Off-Peak | Toujours | Toujours |
| Worktree tag | Tier 2 | Seulement si en worktree |
| Agent tag | Tier 2 | Seulement si agent actif |

## Couleurs et seuils

### Barres de progression (ctx, 5h, 7j)

5 segments Unicode (`█` rempli, `░` vide). Couleur par seuil :

- `< 50%` : vert (`\033[32m`)
- `50-79%` : jaune (`\033[33m`)
- `≥ 80%` : rouge (`\033[31m`)

### Coût session

Blanc, pas de couleur. Format `$X.XX` (2 décimales).

### Peak/Off-Peak

- **Peak** : rouge gras (`\033[1;31m`) + `⚡ PEAK` + temps restant relatif (`~Xh left`)
- **Off-Peak** : vert gras (`\033[1;32m`) + `✦ OFF-PEAK` + contexte :
  - `(weekend)` le vendredi soir, samedi, dimanche
  - `(until 8am ET)` en soirée de semaine
  - `(peak in ~Xh)` le matin avant 8am ET

Peak hours = 8am-2pm Eastern Time, lundi-vendredi.

### Tags worktree/agent

Cyan (`\033[36m`), texte court (juste le nom), pas d'icône.

### Durée session

Gris (`\033[90m`).
- `< 1h` : `XXm` (ex: `32m`)
- `≥ 1h` : `XhXXm` (ex: `1h24m`)

### Lignes modifiées

Vert pour ajouts, rouge pour suppressions : `+156 -23`

## Seuils d'apparition contextuelle

| Segment | Apparaît quand | Disparaît quand |
|---|---|---|
| Rate limit 7j | `used_percentage > 50` | `≤ 50` ou donnée absente |
| Coût | `total_cost_usd > 0.10` | `≤ 0.10` |
| Durée | `total_duration_ms > 600000` (10min) | `≤ 10min` |
| Lignes +/- | `lines_added + lines_removed > 0` | Aucune modif |
| Worktree | champ `worktree` présent dans le JSON | Absent |
| Agent | champ `agent` présent dans le JSON | Absent |

## Algorithme d'adaptation largeur

1. Construire tous les segments visibles (après filtrage par seuils contextuels)
2. Calculer la largeur totale en caractères (sans les codes ANSI)
3. Comparer à `tput cols`
4. Si dépassement : drop les segments Tier 3 un par un
5. Si dépassement encore : drop les segments Tier 2 un par un
6. Les segments "Toujours" ne sont jamais supprimés

### Ordre de suppression Tier 3 (premier supprimé en premier)

1. Lignes +/-
2. Durée session
3. Rate limit 7j

### Ordre de suppression Tier 2

1. Coût
2. Context window
3. Agent tag
4. Worktree tag

Worktree et agent sont supprimés en dernier car quand ils sont présents, c'est une info importante de contexte.

## Exemples de rendu

```
# Session tranquille, off-peak, terminal large
➜ adev orvi │ Opus 4.6 │ ██░░░ ctx 42% │ █░░░░ 5h 18% │ $0.42 │ 32m │ +156 -23 │ ✦ OFF-PEAK (weekend)

# Session chaude, peak, rate limit tendu
➜ adev orvi │ Opus 4.6 │ ████░ ctx 78% │ ████░ 5h 81% │ ███░░ 7j 55% │ $3.21 │ ⚡ PEAK (~1h left)

# En worktree avec agent
➜ adev orvi │ Opus 4.6 │ ██░░░ ctx 35% │ █░░░░ 5h 12% │ ✦ OFF-PEAK (until 8am ET) │ my-feature │ security

# Terminal étroit (tier 1 seul)
➜ adev orvi │ Opus 4.6 │ █░░░░ 5h 18% │ ⚡ PEAK (~3h left)
```

## Contraintes techniques

- Script POSIX sh (pas de bashisms)
- Dépendance unique : `jq`
- `tput cols` pour la largeur terminal
- Pas de fichier externe, tout dans un seul `.sh`
- Codes ANSI pour les couleurs (compatibilité terminal standard)
