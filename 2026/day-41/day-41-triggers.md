# Day 41: Triggers & Matrix Builds

## Task 2: Cron Schedule
**Question:** What is the cron expression for every Monday at 9 AM?
**Answer:** `0 9 * * 1` (Minute 0, Hour 9, Every Day of Month, Every Month, Day 1 which is Monday).

## Task 5: Fail-Fast
**Question:** What does `fail-fast: true` do vs `false`?
**Answer:** `fail-fast: true` (the default setting) tells GitHub to immediately cancel all other running jobs in a matrix if a single job fails. This saves cloud compute time and money. `fail-fast: false` tells GitHub to ignore failures and let all the other jobs in the matrix finish running.

---

## My Workflow Snippets
*(You can paste your workflows or screenshots here!)*
