# Claude Code Status Line v2 : Layout Intelligent Contextuel

Personnalisez la status line de Claude Code avec un layout qui s'adapte automatiquement : Peak/Off-Peak, barres de progression colorées, coût de session, worktree, et plus encore.

## Le rendu

```
# Terminal large - toutes les infos
➜ adev orvi │ Opus 4.6 │ █░░░░ 5h 18% │ ✦ OFF-PEAK (weekend) │ ██░░░ ctx 42% │ $0.42 │ 32m │ +156 -23

# Session chaude - rate limits tendus
➜ adev serfac │ Opus 4.6 │ ████░ 5h 81% │ ⚡ PEAK (~1h left) │ ████░ ctx 85% │ $3.21 │ ███░░ 7j 55%

# Avec worktree et agent
➜ adev orvi │ Opus 4.6 │ █░░░░ 5h 12% │ ✦ OFF-PEAK (until 8am ET) │ ██░░░ ctx 35% │ my-feature │ security

# Terminal étroit - seulement l'essentiel
➜ adev orvi │ Opus 4.6 │ █░░░░ 5h 18% │ ⚡ PEAK (~3h left)
```

## Fonctionnalites

| Segment | Description |
|---|---|
| **Peak / Off-Peak** | 8h-14h ET en semaine = Peak (usage se consomme plus vite) |
| **Rate limit 5h** | Barre de progression avec couleur vert/jaune/rouge |
| **Rate limit 7j** | Apparait seulement quand > 50% |
| **Context window** | Pourcentage du contexte utilise |
| **Cout session** | Apparait quand > $0.10 |
| **Duree session** | Apparait quand > 10 minutes |
| **Lignes modifiees** | +ajouts -suppressions en couleur |
| **Worktree** | Nom du worktree actif |
| **Agent** | Nom de l'agent actif |

### Adaptation largeur

Le layout s'adapte automatiquement a la largeur du terminal :
- **Large** : tous les segments visibles
- **Moyen** : segments essentiels + contextuels
- **Etroit** : seulement modele, rate limit 5h, et peak/off-peak

Les segments sont supprimes par ordre de priorite : d'abord les stats (lignes, duree, 7j), puis les infos secondaires (cout, contexte), en gardant toujours le worktree/agent en dernier.

### Couleurs des barres

- Vert : < 50%
- Jaune : 50-79%
- Rouge : >= 80%

## Installation

**1.** Copiez `statusline-command.sh` dans `~/.claude/`

```sh
curl -o ~/.claude/statusline-command.sh https://raw.githubusercontent.com/Para-FR/claude-statusline/master/statusline-command.sh
```

**2.** Ajoutez dans votre `~/.claude/settings.json` :

```json
{
  "statusLine": {
    "type": "command",
    "command": "sh ~/.claude/statusline-command.sh"
  }
}
```

**3.** Relancez Claude Code. C'est tout !

> Prerequis : `jq` doit etre installe (`brew install jq` sur Mac, `sudo apt install jq` sur Linux).
