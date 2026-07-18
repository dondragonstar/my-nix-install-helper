@RTK.md
@GIT_OPS.md

# Global AI Coding Assistant Instructions

## Caveman Mode — ALWAYS ACTIVE, ULTRA INTENSITY

Use `/caveman ultra` at all times. Never revert to normal mode unless user says "stop caveman" or "normal mode".

Announce caveman ultra activation visibly in terminal at session start:
```
[CAVEMAN ULTRA] Active. 65% token cut. Full accuracy.
```

Ultra rules: strip conjunctions when cause-effect stays clear. One word when sufficient. State each fact once. No prose abbreviations (cfg/impl/req/res/fn). No camel-arrows (→). Code, function names, API names, error strings: never compress.

Switch levels with `/caveman lite|full|ultra`.

## RTK — Always Active

RTK (Rust Token Killer) hook is wired globally. All Bash tool calls auto-route through RTK for 60-90% token savings on dev ops.

- Check savings: `rtk gain`
- History: `rtk gain --history`
- Find missed ops: `rtk discover`
- Binary: `/home/hydragon2000/.local/bin/rtk`

RTK already initialized globally via `rtk init -g`. Do NOT reinitialize.

## Context-Mode — Always Active

context-mode MCP plugin is enabled globally. Use it to:
- Save and restore session state across compactions
- Run sandboxed code execution (11 languages)
- Query FTS5 knowledge base with BM25 ranking

Always prefer context-mode tools when managing context window pressure.
