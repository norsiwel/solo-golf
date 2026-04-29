# Project Status — Solo Golf (AI Agent Version)

## Purpose

This document is intended for **AI coding agents** working on the Solo Golf project. It provides current project context, priorities, and **operational rules that must be followed** during any modification or development work.

---

## ⚠️ CRITICAL OPERATING RULES (READ FIRST)

### 1. **Backup Before Any Change (MANDATORY)**

* **DO NOT modify, overwrite, or delete any file without creating a backup first.**
* Acceptable methods:

  * Use `commit-backup.sh` if available
  * Create timestamped copies of modified files
  * Commit to version control before changes
* If backup cannot be confirmed → **DO NOT PROCEED**

---

### 2. **Preserve Working Functionality**

* Do not break existing gameplay systems
* If a change risks regression:

  * Isolate it
  * Test incrementally
* If uncertain → prefer **non-destructive additions** over edits

---

### 3. **Make Small, Reversible Changes**

* Avoid large refactors unless explicitly required
* Prefer:

  * Incremental improvements
  * Clearly scoped edits
* Ensure each change can be rolled back easily

---

### 4. **Do Not Remove Code Without Justification**

* Comment out instead of deleting when unsure
* Maintain compatibility with existing systems

---

### 5. **Respect Project Structure**

* Follow existing file organization
* Do not arbitrarily rename or relocate core files

---

## Project Overview

**Solo Golf** is a Godot-based single-player golf simulation focused on:

* Realistic ball physics
* Player-driven shot mechanics
* Course-based gameplay

---

## Current Status

**Stage:** Early–Mid Development
**State:** Functional core systems, incomplete integration and polish

The project currently supports a basic gameplay loop but requires refinement and expansion.

---

## Implemented Systems

### Core Gameplay

* Ball physics (`ball.gd`)
* Player control (`player.gd`)
* Tee system (`tee.gd`)
* Green logic (`green.gd`)
* Address/aim system (`address_screen.gd`)

### Game Structure

* Main scene (`main.tscn`)
* 3D scene framework (`node_3d.tscn`)
* Project configuration (`project.godot`)

### Scoring

* Score tracking (`scorecard.gd`)

### Tools

* Course converter (`pg_converter.py`)
* Backup helper (`commit-backup.sh`)

---

## In Progress

* Physics tuning (realism improvements)
* Course data integration
* UI/UX improvements
* Scene organization

---

## Known Limitations

* UI is minimal / unpolished
* Course rendering incomplete
* No audio implementation
* Limited testing and edge-case handling
* Performance not optimized

---

## Development Priorities

### High Priority

* Stabilize gameplay loop (tee → shot → ball → scoring)
* Improve physics consistency
* Ensure course data loads correctly

### Medium Priority

* Add player feedback (visual + numeric)
* Improve camera behavior
* Begin UI layering (HUD, menus)

### Low Priority (For Now)

* AI opponents
* Advanced visuals
* Extended features

---

## Safe Modification Guidelines

When making changes:

1. **Backup first**
2. Identify the smallest possible change
3. Modify only relevant files
4. Test immediately after change
5. Revert if unintended behavior occurs

---

## Suggested Workflow for AI Agent

1. Read relevant scripts before editing
2. Trace dependencies (what calls what)
3. Backup affected files
4. Apply minimal change
5. Validate behavior
6. Document what was changed (if applicable)

---

## Red Flags (Stop and Reassess)

* You are about to modify multiple core systems at once
* You do not fully understand how a system interacts with others
* A change requires deleting large sections of code
* You cannot confirm a backup exists

---

## Summary

The Solo Golf project has a solid foundation but is still evolving.
Your role as an AI agent is to:

* **Preserve stability**
* **Improve incrementally**
* **Avoid destructive changes**
* **Always back up before modifying anything**

Failure to follow these rules risks breaking the project.

---
