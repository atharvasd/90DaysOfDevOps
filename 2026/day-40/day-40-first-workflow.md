# Day 40: My First GitHub Actions Workflow

## The Workflow File (`hello.yml`)
```yaml
name: My First Workflow
on: [push]
jobs:
    greet:
        runs-on: ubuntu-latest

        steps:
            - name: Check out code
              uses: actions/checkout@v4

            - name: Say Hello
              run: echo "Hello from GitHub Actions!"
```

---

## Anatomy of the Workflow

*   **`on:`** The Trigger. This tells GitHub exactly when to run this pipeline. In our case, `[push]` means it runs every single time someone pushes code to the repository.
*   **`jobs:`** A pipeline is made up of one or more jobs. A job is a group of steps that execute on the same runner. We named our job `greet`.
*   **`runs-on:`** The Runner. This tells GitHub what kind of virtual machine we need to borrow to run our code. `ubuntu-latest` gives us a fresh Linux machine.
*   **`steps:`** The sequential list of tasks that the job will execute, one by one.
*   **`uses:`** This allows us to use an "Action" (a pre-written, reusable piece of code) that someone else built. `actions/checkout@v4` is an official GitHub action that clones our repository onto the runner machine so we can interact with our files.
*   **`run:`** This command tells the runner to execute a raw shell command (just like typing `echo` or `ls` into your own terminal).
*   **`name:`** (on a step) An optional, human-readable title for the step that shows up in the GitHub Actions UI to make the logs easier to read.

---

## Proof of Execution
*(Paste the screenshot of your green checkmark from the GitHub Actions tab here!)*
