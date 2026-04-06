# Claude Code Status Line : Peak / Off-Peak Hours

Personnalisez la status line de Claude Code pour afficher en temps réel si vous êtes en heures pleines (Peak) ou creuses (Off-Peak), avec des barres de progression colorées pour le contexte et le rate limit.

## Le rendu

```
➜ user project │ Opus 4.6 │ ██░░░ ctx 42% │ █░░░░ 5h 18% │ ⚡ PEAK (~4h left)
```

- Les barres changent de couleur : vert (< 50%), jaune (50-80%), rouge (> 80%)
- En Peak : rouge avec le temps restant
- En Off-Peak : vert avec le contexte (weekend, heure du prochain peak, etc.)

## Pour rappel

- **Peak Hours** : 8h - 14h Eastern Time (14h - 20h heure de Paris), du lundi au vendredi
- **Off-Peak** : soirées + weekends

En peak, votre usage se consomme plus vite. Donc c'est bien de savoir d'un coup d'oeil où on en est.

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

> Prérequis : `jq` doit être installé (`brew install jq` sur Mac, `sudo apt install jq` sur Linux).
