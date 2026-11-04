# 13 — Git & GitHub Production Mastery for DevOps Engineers

> **Module:** 13 — Git & GitHub Internals, Team Workflows, and Enterprise Governance  
> **Target Audience:** DevOps Engineers, Cloud Architects, and SREs  
> **Philosophy:** Understanding Git under the hood (Objects, Hashes, Directed Acyclic Graphs) to solve high-stakes merge conflicts, recover lost commits, and enforce production-grade branch security.

---

## 📑 Table of Contents
1. [Core Mental Model: Git as an Object Database](#1-core-mental-model-git-as-an-object-database)
2. [The 4 Fundamental Git Objects](#2-the-4-fundamental-git-objects)
3. [Plumbing Commands: Inspecting Git's Brain](#3-plumbing-commands-inspecting-gits-brain)
4. [Branching & HEAD Internals](#4-branching--head-internals)
5. [Merging Architecture: Fast-Forward vs 3-Way Merge](#5-merging-architecture-fast-forward-vs-3-way-merge)
6. [Merge Conflicts & The 3-Stage Index](#6-merge-conflicts--the-3-stage-index)
7. [Enterprise Conflict Resolution Strategies](#7-enterprise-conflict-resolution-strategies)
8. [Disaster Recovery: The Git Time Machine (`git reflog`)](#8-disaster-recovery-the-git-time-machine-git-reflog)
9. [Commit Hygiene & Interactive Rebase (`git rebase -i`)](#9-commit-hygiene--interactive-rebase-git-rebase--i)
10. [Hotfix Surgery: Precise Commit Slicing (`git cherry-pick`)](#10-hotfix-surgery-precise-commit-slicing-git-cherry-pick)
11. [Semantic Versioning & Annotated Tags](#11-semantic-versioning--annotated-tags)
12. [Secret Hygiene & Emergency Leak Protocol](#12-secret-hygiene--emergency-leak-protocol)
13. [Enterprise Governance: Branch Protection Rules](#13-enterprise-governance-branch-protection-rules)
14. [GitHub CLI (`gh`) Automation Toolbelt](#14-github-cli-gh-automation-toolbelt)
15. [Master DevOps Git Command Reference](#15-master-devops-git-command-reference)

---

## 1. Core Mental Model: Git as an Object Database

Git is **not** a traditional file-tracking system or delta-differential tracker.  
Git is a **Content-Addressable Key-Value Object Store** with a VCS (Version Control System) interface layered on top.

```mermaid
flowchart TD
    subgraph WorkingTree ["1. Working Directory (Local Disk)"]
        RawFiles["Actual files on disk (devops.txt, Dockerfile)"]
    end

    subgraph StagingArea ["2. Staging Area / Index (.git/index)"]
        IndexTable["Binary tracking table mapping filenames to SHA-1 Hashes"]
    end

    subgraph ObjectDatabase ["3. Git Object Database (.git/objects)"]
        CommitObj["Commit Object<br/>(Snapshot + Author + Parent Hash)"]
        TreeObj["Tree Object<br/>(Permissions + Names + Blob Hashes)"]
        BlobObj["Blob Object<br/>(Zlib-compressed raw file payload)"]
    end

    RawFiles -->|git add| IndexTable
    IndexTable -->|creates| BlobObj
    IndexTable -->|git commit| TreeObj
    TreeObj -->|packaged into| CommitObj
```

### The 40-Character SHA-1 Checksum
Every single piece of data in Git is hashed using SHA-1 (or SHA-256 in newer versions):
- Git takes the object type, size, a null byte, and the content.
- Generates a 40-character hexadecimal string (e.g., `86440c133ff1baa99089c8b401acc1e628b39c83`).
- The **first 2 characters** become the subdirectory name in `.git/objects/86/`.
- The **remaining 38 characters** become the filename `440c133ff1baa99089c8b401acc1e628b39c83`.

---

## 2. The 4 Fundamental Git Objects

Everything inside `.git/objects/` belongs to one of these four immutable types:

| Object Type | Purpose | Contains Filename? | Key Attributes |
| :--- | :--- | :---: | :--- |
| **`blob`** | Stores raw file data / payload. | ❌ No | Zlib compressed, pure file content. |
| **`tree`** | Represents a directory/folder. | ✅ Yes | File mode (100644/100755), blob SHA, filename. |
| **`commit`** | Snapshot of the repository at a point in time. | ❌ No | Top-level tree SHA, parent commit SHA(s), author, timestamp, message. |
| **`tag`** | Permanent release marker pointing to a commit. | ❌ No | Target commit SHA, tagger, release notes, GPG signature. |

```mermaid
flowchart TD
    Commit["Commit Object (147a1ba...)<br/>tree: 2c0cc34...<br/>parent: 86346af...<br/>author: Dev<br/>msg: feat: add api"] -->|points to| Tree["Tree Object (2c0cc34...)<br/>100644 blob 86440c... devops.txt<br/>100644 blob dcb85b... Dockerfile"]
    Tree -->|maps to| Blob1["Blob (86440c...)<br/>Content: 'Hello DevOps World'"]
    Tree -->|maps to| Blob2["Blob (dcb85b...)<br/>Content: 'FROM node:20-alpine'"]
```

---

## 3. Plumbing Commands: Inspecting Git's Brain

Standard user-facing commands (`add`, `commit`, `checkout`, `merge`) are known as **Porcelain Commands**.  
Low-level commands that directly query or manipulate the `.git` database are known as **Plumbing Commands**.

### A. Discovering Raw Objects on Disk
```bash
# List all object files currently stored in the Git database
find .git/objects -type f
```
> **Explanation:** `-type f` ensures Linux lists only actual regular object files, filtering out directory trees (`pack`, `info`).

### B. Inspecting Object Type (`-t`)
```bash
git cat-file -t <hash>
# Example: git cat-file -t 86440c1
# Output: blob
```

### C. Pretty-Printing Object Content (`-p`)
```bash
git cat-file -p <hash>
# Example on a Tree object:
# 100644 blob 86440c133ff1baa99089c8b401acc1e628b39c83    devops.txt
```

### D. Inspecting the Staging Area / Index
```bash
git ls-files
git ls-files -s  # Shows file mode, SHA-1 blob hash, stage number, and filename
```

---

## 4. Branching & HEAD Internals

### What is a Branch?
In Git, a branch is **not** a copy of your codebase. It is literally a **41-byte plain-text file** located at:
```text
.git/refs/heads/<branch-name>
```
Inside this file is nothing more than the **40-character SHA-1 commit hash** that the branch currently points to.

### What is HEAD?
`HEAD` is a symbolic pointer that tells Git which branch you are currently working on:
```bash
cat .git/HEAD
# Output: ref: refs/heads/master
```
When you run `git switch <branch>`, Git simply rewrites that single line in `.git/HEAD`.

### What is a "Detached HEAD"?
If you checkout a commit directly (`git checkout <commit-hash>`) instead of a branch name:
- `cat .git/HEAD` will contain the raw commit hash instead of `ref: refs/heads/...`.
- Any new commits made in this state are orphaned and will eventually be cleaned up by Git Garbage Collection (`git gc`) unless saved to a branch.

---

## 5. Merging Architecture: Fast-Forward vs 3-Way Merge

```mermaid
flowchart TD
    subgraph FastForward ["Fast-Forward Merge"]
        direction LR
        FF_Base["Base Commit (A)"] --> FF_Tip["Feature Tip (B)"]
        FF_Master["master (moves A -> B)"]
    end

    subgraph ThreeWayMerge ["3-Way Merge (True Merge Commit)"]
        direction TB
        Base["Common Ancestor (A)"] --> MasterTip["Master Commit (B)"]
        Base --> FeatTip["Feature Commit (C)"]
        MasterTip --> MergeCommit["Merge Commit (M)<br/>Parent 1: B<br/>Parent 2: C"]
        FeatTip --> MergeCommit
    end
```

### 1. Fast-Forward Merge
- Occurs when the target branch (`master`) has had **no new commits** since the feature branch diverged.
- Git does not create a new merge commit.
- It simply slides the pointer in `.git/refs/heads/master` forward to the feature branch's latest commit hash.

### 2. 3-Way Merge (The 'ort' Strategy)
- Occurs when both `master` and `feature` branches have moved forward with independent commits.
- Git evaluates three points:
  1. **Common Ancestor** (Base)
  2. **Current Target Tip** (`ours` / HEAD)
  3. **Incoming Feature Tip** (`theirs` / MERGE_HEAD)
- Generates a **Merge Commit** containing **TWO PARENT POINTERS**:
  ```text
  parent 86346afa2beaaae1319e13fd3f027642d0bd1972  (Parent 1: Master)
  parent 535c3868526fcc8561cf6b16cb2939d3eab65631  (Parent 2: Feature)
  ```

---

## 6. Merge Conflicts & The 3-Stage Index

A merge conflict occurs **strictly** when both branches modify the **exact same lines of the exact same file** since their common ancestor.

### Conflict Markers Explained
```text
<<<<<<< HEAD
DATABASE_PORT=28000
=======
DATABASE_PORT=27019
>>>>>>> conflict-test
```
- `<<<<<<< HEAD`: The code existing on your current branch.
- `=======`: The boundary separator.
- `>>>>>>> <branch>`: The incoming code attempting to merge.

### The 3 Stages of an Unmerged File (`git ls-files -u`)
During a conflict, Git stores three separate versions in `.git/index`:
- **Stage 1 (Base):** The file state at the common ancestor before the branches diverged.
- **Stage 2 (Ours):** The file state on the current branch (`HEAD`).
- **Stage 3 (Theirs):** The file state on the incoming branch (`MERGE_HEAD`).

```bash
git ls-files -u
# Shows:
# 100644 2528345... 1    config.env  (Ancestor)
# 100644 716c32e... 2    config.env  (Ours)
# 100644 047b2df... 3    config.env  (Theirs)
```

### The Resolution Signal: `git add`
Simply editing the file in the working directory does not resolve the conflict.  
Running **`git add <file>`** is the mandatory operational signal that wipes Stages 1, 2, and 3 from `.git/index` and commits the resolved file as **Stage 0**.

---

## 7. Enterprise Conflict Resolution Strategies

In multi-thousand-line enterprise codebases, manual terminal editing is impractical. Use these industry-standard methods:

### Strategy 1: The Golden DevOps Rule (Merge Main into Feat First)
Never merge directly into `main` when conflicts exist.
```bash
# 1. Switch to your feature branch
git switch feat/my-feature

# 2. Pull or merge main into your feature branch
git merge main

# 3. Resolve conflicts, run unit tests, and build Docker image safely
# 4. Once verified, merge feat into main with ZERO conflicts on main
git switch main
git merge feat/my-feature
```

### Strategy 2: Automated Override Flags (`-X theirs` / `-X ours`)
When you know incoming feature code must unconditionally overwrite the legacy version:
```bash
# Accept all incoming changes from feature branch automatically:
git merge -X theirs feat/my-feature

# Checkout single file directly from incoming branch:
git checkout --theirs path/to/large-file.js
git add path/to/large-file.js
```

### Strategy 3: VS Code 3-Way Merge Editor
Click **"Resolve in Merge Editor"** at the bottom right of VS Code to inspect:
- Left pane: Incoming changes
- Right pane: Current changes
- Bottom pane: Live compiled result with 1-click accept buttons

---

## 8. Disaster Recovery: The Git Time Machine (`git reflog`)

> **DevOps Law:** Once a commit is created in Git, it is almost impossible to lose unless explicitly garbage collected (`git gc --prune=now`).

Even if a developer executes a destructive command:
```bash
git reset --hard HEAD~5  # Wipes 5 commits and all local working tree changes
```

### The Recovery Protocol
```bash
# 1. Inspect the Flight Recorder (Reflog tracks EVERY movement of HEAD)
git reflog

# Output example:
# a1b2c3d HEAD@{0}: reset: moving to HEAD~5
# 9f8e7d6 HEAD@{1}: commit: feat(security): add secret keys

# 2. Time-travel directly back to the commit before the accidental reset:
git reset --hard HEAD@{1}
# OR: git reset --hard 9f8e7d6
```
**Result:** The lost commits, files, and history are restored immediately.

---

## 9. Commit Hygiene & Interactive Rebase (`git rebase -i`)

Dirty commit histories (`wip`, `fix typo`, `tested again`) clutter Git history and trigger confusing GitOps rollbacks.

```text
DIRTY HISTORY:
* 31a3eba fix typo
* 9265796 added logout
* 769063d wip login

CLEAN HISTORY (AFTER SQUASH):
* 2e8a1de feat(auth): implement complete user authentication flow
```

### Interactive Rebase Workflow
```bash
# Open the last 3 commits in interactive mode:
git rebase -i HEAD~3
```

In the editor:
- Leave the first line as **`pick`** (anchor commit).
- Change subsequent lines from `pick` to **`s`** (`squash`) or **`f`** (`fixup` — discards commit message).
```text
pick 769063d wip login
s 9265796 added logout
s 31a3eba fix typo
```
- Save and exit. In the next prompt, enter a clean, semantic commit message.

### Safe Abort
If an interactive rebase runs into unexpected conflicts:
```bash
git rebase --abort
```
Returns your repository to the exact clean state prior to running rebase.

### Amending the Latest Commit
To modify the message or include missed files without creating a new commit:
```bash
git commit --amend -m "feat(auth): new updated message"
```

---

## 10. Hotfix Surgery: Precise Commit Slicing (`git cherry-pick`)

When a critical bug fix commit is buried inside an unmerged, work-in-progress feature branch:

```text
feature-branch:
  Commit A -> Commit B (CRITICAL HOTFIX) -> Commit C (broken) -> Commit D (broken)
```

```bash
# 1. Locate the exact commit hash
git log feature-branch --oneline

# 2. Switch to target production branch
git switch master

# 3. Pluck ONLY that single commit and apply it to master:
git cherry-pick <commit-hash-of-B>

# Optional: Apply changes without making a commit (for review):
git cherry-pick -n <commit-hash>
```

---

## 11. Semantic Versioning & Annotated Tags

### Semantic Versioning (SemVer) Standard: `vMAJOR.MINOR.PATCH`
- **PATCH (`v1.0.0` ➡️ `v1.0.1`):** Backward-compatible bug/security fixes.
- **MINOR (`v1.0.1` ➡️ `v1.1.0`):** New backward-compatible functionality.
- **MAJOR (`v1.1.0` ➡️ `v2.0.0`):** Incompatible API / breaking changes.

### Creating Production Annotated Tags
Annotated tags store the tagger, date, message, and cryptographic signature:
```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0: Initial production launch"

# Push tags to remote (triggers automated CI/CD Docker image release)
git push origin --tags

# Inspect tag metadata
git show v1.0.0
```

---

## 12. Secret Hygiene & Emergency Leak Protocol

### Removing Tracked Files Safely (`git rm --cached`)
If a file was added to `.gitignore` after being tracked, Git continues tracking it.
```bash
# Stops tracking file while PRESERVING it on your local disk:
git rm --cached .env
git commit -m "security: untrack .env file"
```

### 🚨 Emergency SOP: If Secrets are Pushed to GitHub
1. **P0 Action — REVOKE / ROTATE IMMEDIATELY:**  
   Automated scrapers index GitHub in seconds. The secret must be treated as compromised. Deactivate AWS keys, rotate database passwords, and reissue tokens immediately.
2. **Purge Commit from History (Recent Commit):**
   ```bash
   git reset --hard HEAD~1
   git push origin <branch> --force
   ```
3. **Purge Across Deep History (`git-filter-repo`):**
   ```bash
   git filter-repo --invert-paths --path .env
   git push origin --force --all
   git push origin --force --tags
   ```
4. **Enable GitHub Push Protection:**  
   GitHub Repo ➡️ Settings ➡️ Code security ➡️ Enable **Secret Scanning Push Protection**.

---

## 13. Enterprise Governance: Branch Protection Rules

In enterprise production environments, direct pushes to `main` or `master` are strictly prohibited.

```mermaid
flowchart LR
    Dev([Developer]) -->|Direct Push Attempt| MainBranch["master / main (Protected)"]
    MainBranch -.->|BLOCKED: GH006 Hook Declined| Dev

    Dev -->|Push to Feature Branch| FeatBranch["feat/new-service"]
    FeatBranch -->|Create Pull Request| PR["Pull Request #3"]
    PR -->|Automated CI Tests Pass| Checks["CI Checks: PASS"]
    Checks -->|Merge PR| MainBranch
```

### Essential Production Protection Settings
- ✅ **Require a pull request before merging:** Blocks direct CLI pushes.
- ✅ **Require status checks to pass before merging:** Blocks merge until automated GitHub Actions pass.
- ✅ **Require approvals:** Requires peer code reviews (keep unchecked for solo sandbox testing).
- ✅ **Block force pushes:** Prevents destructive `--force` history rewrites.
- ✅ **Restrict deletions:** Prevents accidental branch deletion.

---

## 14. GitHub CLI (`gh`) Automation Toolbelt

DevOps engineers manage GitHub directly from the terminal without context-switching to a web browser.

### Authentication & Remote Binding
```bash
# Authenticate CLI with browser or token
gh auth login

# Create a remote repository from local directory and push immediately
gh repo create my-repo --public --source=. --remote=origin --push
```

### Pull Request Lifecycle via CLI
```bash
# 1. Create a Pull Request
gh pr create --title "feat(api): add express api service" --body "Detailed PR notes"

# 2. View Open PRs and Status
gh pr list
gh pr status

# 3. View Diffs of a PR
gh pr diff <pr-number>

# 4. Merge PR (Squash and delete branch automatically)
gh pr merge --squash --delete-branch

# 5. Emergency Admin Override Merge
gh pr merge --squash --delete-branch --admin
```

---

## 15. Master DevOps Git Command Reference

| Operational Need | Command |
| :--- | :--- |
| **Inspect raw object type** | `git cat-file -t <hash>` |
| **Pretty-print object content** | `git cat-file -p <hash>` |
| **Inspect staged files & SHAs** | `git ls-files -s` |
| **Inspect unmerged conflict stages** | `git ls-files -u` |
| **Graph-based visual log** | `git log --oneline --graph --all` |
| **View entire action history** | `git reflog` |
| **Undo hard reset disaster** | `git reset --hard HEAD@{n}` |
| **Squash last N commits** | `git rebase -i HEAD~N` |
| **Abort failing rebase** | `git rebase --abort` |
| **Amend commit message** | `git commit --amend -m "new message"` |
| **Pluck single commit** | `git cherry-pick <hash>` |
| **Untrack file without deleting** | `git rm --cached <file>` |
| **Create annotated release tag** | `git tag -a v1.0.0 -m "Release notes"` |
| **Push all branches & tags** | `git push origin --all && git push origin --tags` |
| **CLI PR creation** | `gh pr create --title "..." --body "..."` |
| **CLI PR squash & merge** | `gh pr merge --squash --delete-branch` |
| **Purge file from history** | `git filter-repo --invert-paths --path <file>` |

