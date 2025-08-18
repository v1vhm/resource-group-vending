# Agent Instructions: Reliable Error Handling for GitHub Workflows

**Role:** You are configuring GitHub Actions to be **reliable, debuggable, and safe**.
**Output:** Valid YAML, POSIX shell (bash), PowerShell, and Node snippets that follow the rules below.

## 0) Global rules (apply to every workflow you generate)

* Prefer **failing fast**: do **not** use `continue-on-error` unless explicitly asked.
* Add **timeouts** on every job: `timeout-minutes: <sensible value>`.
* Use **concurrency** to cancel superseded runs:

  ```yaml
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  ```
* For scripts, enable strict modes:

  * **bash:** `set -euo pipefail; IFS=$'\n\t'`
  * **pwsh:** `$ErrorActionPreference = "Stop"`
* Always route cleanup with `if: ${{ always() }}` and capture diagnostics with `if: ${{ failure() }}`.
* Write outputs to `$GITHUB_OUTPUT` (never `set-output`).

## 1) Standard job skeleton (use this as default)

```yaml
name: CI
on:
  push:
    branches: [ main ]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-test:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install deps (retry)
        shell: bash
        run: |
          set -euo pipefail
          for i in {1..3}; do
            if npm ci; then exit 0; fi
            sleep $(( i * 10 ))
          done
          echo "::error::npm ci failed after 3 attempts"
          exit 1

      - name: Build
        shell: bash
        run: |
          set -euo pipefail
          npm run build 2>&1 | tee build.log

      - name: Test (JUnit)
        shell: bash
        run: |
          set -euo pipefail
          npm test -- --reporter=junit --reporter-options output=reports/junit.xml

      - name: Upload diagnostics on failure
        if: ${{ failure() }}
        uses: actions/upload-artifact@v4
        with:
          name: diagnostics
          path: |
            build.log
            reports/
            **/*.log

      - name: Cleanup (always)
        if: ${{ always() }}
        run: ./scripts/cleanup.sh
```

## 2) Step conditions you must use

* On failure only:

  ```yaml
  if: ${{ failure() }}
  ```
* Always (like `finally`):

  ```yaml
  if: ${{ always() }}
  ```
* Skip when cancelled:

  ```yaml
  if: ${{ !cancelled() }}
  ```

## 3) Robust retries (portable snippet)

**Use for flaky externals (network, package registries, cloud APIs).**

```yaml
- name: Retryable command (exponential backoff)
  shell: bash
  run: |
    set -euo pipefail
    for i in {1..5}; do
      if your_command_here; then exit 0; fi
      sleep $(( 2 ** i ))
    done
    echo "::error::your_command_here failed after retries"
    exit 1
```

## 4) Structured logs & annotations

Use GitHub log groups and error annotations to make failures obvious.

```bash
echo "::group::Build logs"
# build output here
echo "::endgroup::"
echo "::error file=build.sh,line=42::Compilation failed (missing dep)"
```

## 5) Job outputs and dependencies

* Emit outputs:

  ```yaml
  - id: meta
    shell: bash
    run: echo "tag=1.2.${{ github.run_number }}" >> "$GITHUB_OUTPUT"
  ```
* Consume safely:

  ```yaml
  jobs:
    build:
      outputs:
        image_tag: ${{ steps.meta.outputs.tag }}
    deploy:
      needs: build
      if: ${{ needs.build.result == 'success' }}
      steps:
        - run: echo "Deploying ${{ needs.build.outputs.image_tag }}"
  ```

## 6) Matrix safety

Disable fail-fast to avoid cancelling siblings; cap parallelism.

```yaml
strategy:
  fail-fast: false
  max-parallel: 3
  matrix:
    node: [18, 20, 22]
```

## 7) Lint workflows & scripts (catch issues early)

```yaml
- uses: actions/checkout@v4
- uses: actions/setup-go@v5
- name: Install actionlint
  run: go install github.com/rhysd/actionlint/cmd/actionlint@latest
- name: Lint workflows
  run: actionlint
# Optional: shellcheck / eslint as needed
```

## 8) PowerShell and Node “try/catch”

**PowerShell**

```yaml
- name: Robust PowerShell
  shell: pwsh
  run: |
    $ErrorActionPreference = "Stop"
    try {
      ./do-stuff.ps1
    } catch {
      Write-Error "Failed: $($_.Exception.Message)"
      exit 1
    }
```

**Node (for custom JS actions)**

```js
const core = require('@actions/core');

async function run() {
  try {
    // ... your awaits here
  } catch (err) {
    core.setFailed(err instanceof Error ? err.message : String(err));
  }
}
run();
```

## 9) Reusable workflow pattern (centralize failure handling)

Create `.github/workflows/common-ci.yml`:

```yaml
on:
  workflow_call:
    inputs:
      test_cmd:
        required: true
        type: string

jobs:
  ci:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        shell: bash
        run: |
          set -euo pipefail
          ${{ inputs.test_cmd }}
      - name: Notify on failure
        if: ${{ failure() }}
        run: ./scripts/notify.sh
```

Call it from projects:

```yaml
jobs:
  call-common:
    uses: ./.github/workflows/common-ci.yml
    with:
      test_cmd: "npm test"
```

## 10) Composite action with `post` (finally block)

`action.yml` (composite):

```yaml
name: safe-task
runs:
  using: composite
  steps:
    - id: main
      shell: bash
      run: |
        set -euo pipefail
        ./do-main.sh
    - id: teardown
      if: ${{ always() }}
      shell: bash
      run: ./teardown.sh
```

## 11) Secrets handling

* Do **not** echo secrets or enable `set -x` around them.
* If you must print partial context, mask it:

  ```bash
  echo "::add-mask::$TOKEN"
  ```

## 12) Idempotency & precondition guards

* Treat “already exists” as success.
* Fail early on missing inputs:

  ```bash
  [[ -n "${REQUIRED_VAR:-}" ]] || { echo "::error::REQUIRED_VAR missing"; exit 2; }
  ```

## 13) Environment protections (reduce impact of missed errors)

* Use GitHub **Environments** with required reviewers / wait timers for deploy jobs.
* Gate releases via **branch protection** + required status checks.

---

## Quick templates (copy/paste)

### Bash strict step

```yaml
- name: Strict bash step
  shell: bash
  run: |
    set -euo pipefail
    IFS=$'\n\t'
    # your commands
```

### Upload artifacts on failure

```yaml
- name: Upload artifacts on failure
  if: ${{ failure() }}
  uses: actions/upload-artifact@v4
  with:
    name: diagnostics
    path: |
      logs/**
      **/*.log
      **/junit*.xml
```

### Guarded deploy job

```yaml
deploy:
  needs: build
  if: ${{ needs.build.result == 'success' && !cancelled() }}
  environment: production
  runs-on: ubuntu-latest
  timeout-minutes: 30
  steps:
    - run: ./deploy.sh
```

---

## Checklist for the agent (validate before finishing)

* [ ] Every job has `timeout-minutes`.
* [ ] `concurrency` with `cancel-in-progress: true` is set at workflow root.
* [ ] Script steps use strict modes (bash/pwsh).
* [ ] Retries added around flaky external calls.
* [ ] `failure()` artifact upload + `always()` cleanup present.
* [ ] Outputs written via `$GITHUB_OUTPUT` and consumed safely.
* [ ] Matrix uses `fail-fast: false` where appropriate.
* [ ] Linting step (`actionlint`) included for CI workflows handling.
* [ ] Secrets are not printed; masking used if needed.
* [ ] Deploys gated via environments or required checks.

**End of instructions.**
