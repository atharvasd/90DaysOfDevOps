# Day 38: YAML Basics

## What I Learned

**Task 2 Question:** What are the two ways to write a list in YAML?
**Answer:** 
1. **Block sequence:** Using a dash and a space (`- `) on a new line for each item. This is the most common and readable format.
2. **Flow sequence:** Using square brackets and separating items with commas (e.g., `[item1, item2]`). This is useful for short, simple lists to save space.

**Task 4 Question:** When would you use `|` vs `>`?
**Answer:**
1. **Literal (`|`)**: Use this when you want to preserve every newline and exact formatting. This is mostly used when embedding shell scripts or configuration files directly into your YAML.
2. **Folded (`>`)**: Use this when you want to write a long string over multiple lines so it's easier for humans to read, but you want the computer to read it as one continuous line with spaces.

**Task 6 Question:** Why is Block 2 broken?
**Answer:** Inconsistent indentation! YAML relies entirely on spaces for its structure. In Block 2, `- docker` has 0 spaces of indentation, but `- kubernetes` has 2 spaces of indentation. YAML requires list items at the same level to align perfectly. As the linter says: *"All mapping items must start at the same column"*.

---

## My YAML Files

*(You can copy and paste the contents of your `person.yaml` and `server.yaml` here when you are ready to submit!)*
