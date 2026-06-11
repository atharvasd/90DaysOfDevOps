# Lab 03: Building Custom JavaScript Actions

**Topic:** GitHub Actions — Extending the platform with custom JS Actions

---

## Overview

While you can write scripts directly in `run` steps, or group them using **Composite Actions**, sometimes you need complex logic, API integrations, or cross-platform compatibility (Windows, macOS, Linux). **JavaScript Actions** run directly on the runner machine via Node.js and are the standard way to build robust, reusable actions.

---

## 🛠️ Hands-on Tasks

### Task 1: Setup the Action Repository
Custom actions usually live in their own repository so they can be versioned and shared. For this lab, you can create a folder in your current repo.

```bash
mkdir hello-world-javascript-action
cd hello-world-javascript-action
npm init -y
npm install @actions/core @actions/github
```
- `@actions/core`: Provides functions to read inputs, set outputs, and fail the action.
- `@actions/github`: Provides an authenticated Octokit client and context about the workflow run.

### Task 2: Create the `action.yml` Metadata File

This file tells GitHub how to run your action and defines its inputs/outputs.

```yaml
# hello-world-javascript-action/action.yml
name: 'Hello World JS Action'
description: 'Greets someone and records the time'
inputs:
  who-to-greet:  
    description: 'Who to greet'
    required: true
    default: 'World'
outputs:
  time: # id of output
    description: 'The time we greeted you'
runs:
  using: 'node20'
  main: 'index.js'
```

### Task 3: Write the JavaScript Logic

Create `index.js`:

```javascript
// hello-world-javascript-action/index.js
const core = require('@actions/core');
const github = require('@actions/github');

try {
  // `who-to-greet` input defined in action.yml
  const nameToGreet = core.getInput('who-to-greet');
  console.log(`Hello ${nameToGreet}!`);

  // Get the current time and set it as an output
  const time = (new Date()).toTimeString();
  core.setOutput("time", time);

  // Get the JSON webhook payload for the event that triggered the workflow
  const payload = JSON.stringify(github.context.payload, undefined, 2);
  console.log(`The event payload: ${payload}`);
  
} catch (error) {
  // If anything fails, tell GitHub Actions to mark the step as failed
  core.setFailed(error.message);
}
```

### Task 4: Package the Action

GitHub Actions runners don't run `npm install` for you. You must check in the `node_modules` directory, OR use a tool like `@vercel/ncc` to compile your code and dependencies into a single file.

```bash
# We will use ncc to compile it into a single file
npm install -g @vercel/ncc
ncc build index.js --license licenses.txt

# Update action.yml to point to the compiled file
# Change: main: 'index.js' -> main: 'dist/index.js'
```

Update your `action.yml`:
```yaml
runs:
  using: 'node20'
  main: 'dist/index.js'
```

Commit the `action.yml`, `package.json`, and the `dist/` directory.

### Task 5: Use Your Custom Action

Create a workflow to test it: `.github/workflows/test-js-action.yml`:

```yaml
name: Test Custom JS Action
on: [push]

jobs:
  test-action:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Uses the action from the local directory
      - name: Run my custom action
        id: hello
        uses: ./hello-world-javascript-action
        with:
          who-to-greet: 'DevOps Engineer'

      # Prints the output from the previous step
      - name: Get the output time
        run: echo "The time was ${{ steps.hello.outputs.time }}"
```

---

## ✅ Best Practices
- **Use TypeScript:** For production actions, use TypeScript. The `@actions/core` types make it much easier to avoid bugs.
- **Always Package:** Never rely on checking in `node_modules`. Always compile with `ncc` or `esbuild` to keep the action fast and the repository clean.
- **Version Tags:** When releasing an action publicly, use major version tags (e.g., `v1`). Move the `v1` tag to point to `v1.2.3` whenever you release non-breaking changes, so users can pin to `@v1` and get automatic patches.
