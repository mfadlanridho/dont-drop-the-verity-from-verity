# Don't Drop the Verity

Roblox game built with Rojo. Design: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md). Task tracker: [docs/PROGRESS.md](docs/PROGRESS.md).

## Working rules

- **Commit after every change.** When a piece of work changes files in this repo, commit it without asking first. Commit directly to `master`, one commit per task or logical change, with the task ID in the message when there is one (for example `B-01: graybox map`). Do not push unless asked.
- The Studio place file is not in git. After Studio work, update the tracker, commit that, and remind the user to save the place in Studio.
- Scripts live in `src/` and are synced by Rojo. Never edit scripts inside Studio.
- **Questions for another agent go in a copy-paste block.** Agents cannot message each other; the user relays by hand. When you need clarification from another agent, end your message with one fenced code block per target agent, labelled with that agent's name just above it. The block must be a self-contained prompt the user can paste as is: say which agent is asking and for which task ID, give the context and file paths needed, ask the exact question, and say what form the answer should take. When you answer such a prompt, put the answer in a fenced block addressed back to the asking agent the same way.
