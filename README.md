# CodexWrapper

Wrapper for codex.

## Install
Linux/macOS:
```
./install.sh
```
Windows PowerShell:
```
pwsh ./install.ps1
# or if PowerShell Core isn't available
powershell -File install.ps1
```
If neither `pwsh` nor `powershell` is present, install PowerShell from
[Microsoft's documentation](https://learn.microsoft.com/powershell/).
These installers place the Bash wrappers (`cx`, `cx5`) or PowerShell scripts (`Invoke-Codex.ps1`, `Compress-CX5.ps1`) in a `bin` directory
under your home folder and seed `~/.cx` with a starter dictionary plus metrics, context, offline, responses, prompts, and topics folders along with a relations file and the decompression spec. The installer also ensures the Python `tiktoken` library is available so `--estimate` can report accurate token counts.

### Install into an active virtualenv (WSL/Kali)
If you're running under WSL or Kali and want the tools scoped to a Python virtualenv, activate it and run:

```
python3 -m venv .venv
source .venv/bin/activate
./install_venv.sh
```

This drops `cx` and `cx5` into the virtualenv's `bin` and seeds `.cx` assets inside the environment so the wrapper can act as the API layer between Codex and the user.

## Usage

### Expand to a full prompt
```
cx role=@dev goal='demo' cons='^mm,^st{3}' reason='^ts' out='code' --estimate
# or in PowerShell
Invoke-Codex role=@dev goal='demo' cons='^mm,^st{3}' reason='^ts' out='code' --estimate
```
`role=` and `goal=` are required. Optional `cons=`, `reason=`, and `out=` populate constraint, reasoning, and output blocks. Use `topic=foo,bar` to label the run for topic tracking.

### Compress to CX5 format
```
cx5 role='You are a seasoned developer.' goal='demo' \
    cons='Use minimal tokens; compress phrasing, keep meaning.,Provide at most 3 bullet points.' \
    reason='Think step-by-step and verify each step.' out='code'
# or in PowerShell
Compress-CX5 role='You are a seasoned developer.' goal='demo' \
    cons='Use minimal tokens; compress phrasing, keep meaning.,Provide at most 3 bullet points.' \
    reason='Think step-by-step and verify each step.' out='code'
```
Both emit a single-line `CX5|...` string using dictionary entries where possible.

### Review the dictionary

```bash
cx --dict
```

Prints the combined global and project dictionaries with usage counts so you can monitor symbol growth.

Flags:

- `--dry` preview the expanded prompt without sending it.
- `--estimate` report raw vs compressed token counts and log `[ISO timestamp] raw=X compressed=Y savings=Z%` under `~/.cx/metrics/<project>.log`. Uses the `tiktoken` tokenizer when available and falls back to word counts. This flag implies `--dry`.
- `--offline` skip the API call and save the expanded prompt under `~/.cx/offline/<project>/<timestamp>.txt` for later use.
- `--replay` send any queued prompts from project subdirectories under `~/.cx/offline` once an API key is available.
- `--dict` display the combined dictionary with usage counts and exit.
- `--help` show usage.

The dictionary accepts both symbolic tags like `@dev` and numeric macros such as `#42` that expand to preset bundles.
When a plain phrase repeats, `cx` will offer to mint a new `@domain` tag so it can be reused in future prompts.
Symbol usage counts are tracked and the wrapper reports both the top and least-used symbols after each run for context.
Usage summaries also show average uses and how many symbols remain unused. Dictionary pruning no longer enforces a hard limit—set `CX_DICT_MAX` only as a hint. When the limit is exceeded, the wrapper presents usage statistics and lets you choose how many entries to keep or skip pruning entirely.
Each time a symbol is expanded, its final text is appended to `~/.cx/context/<symbol>.log`, letting the wrapper build richer context histories that can seed smarter prompts in the future. Symbol co-occurrences are tracked in `~/.cx/relations` as triads drawn from up to nine symbols, mimicking quantum-like pairing; when a triad recurs, the wrapper reports it and can prompt you to mint a combined `@tag` so compound concepts compress cleanly.
Those same symbols populate a neuron-like grid stored per project under `~/.cx/grid/<project>.grid`, where each entry starts at the center of a 3×3 block and lists up to eight neighboring symbols, letting relationships evolve and explain context like connected neurons.
Review queued prompts under `~/.cx/offline` and these context logs regularly to mine recurring phrases and mint new symbols so the dictionary keeps growing.
Responses from Codex are saved under `~/.cx/responses/<project>.log` and scanned for repeated phrases, prompting you to mint new tags from model feedback. Each run also mines the entire responses log so recurring phrases across sessions can be symbolized, letting the dictionary grow over time.
Prompts are likewise appended to `~/.cx/prompts/<project>.log` and mined across runs so recurring instructions you write become reusable tags.

You can also tag runs with `topic=alpha,beta`. Each symbol expanded during the prompt is logged under `~/.cx/topics/<topic>.log`, building a growing map of which symbols relate to which topics.

### API calls

To send the expanded prompt to OpenAI, set the `OPENAI_API_KEY` environment variable. The wrappers post the prompt to the
`chat/completions` endpoint using `gpt-3.5-turbo` and print the model's reply. If the key is missing or you run with `--offline`,
the prompt is saved to `~/.cx/offline/<project>/<timestamp>.txt` so it can be replayed later. When prompted for a key, pressing Enter
queues the prompt offline. Network or HTTP failures likewise store the prompt in the offline queue. Run `cx --replay` after a
key is available to send and remove queued prompts.

`cx5` folds any `raw=` fragments like `g:foo` or `c:bar` into goals or constraints before symbol replacement so compressed CX5 strings capture those directives.
