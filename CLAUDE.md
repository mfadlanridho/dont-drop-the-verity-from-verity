# Don't Drop the Verity

Roblox game built with Rojo. Design: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md). Task tracker: [docs/PROGRESS.md](docs/PROGRESS.md).

## Working rules

- **Commit after every change.** When a piece of work changes files in this repo, commit it without asking first. Commit directly to `master`, one commit per task or logical change, with the task ID in the message when there is one (for example `B-01: graybox map`). Do not push unless asked.
- The Studio place file is not in git. After Studio work, update the tracker, commit that, and remind the user to save the place in Studio.
- Scripts live in `src/` and are synced by Rojo. Never edit scripts inside Studio.
- **Ask other agents directly.** Each role runs as its own desktop session titled `Verity: <role> agent`. When you need a fact from another agent (an instance path, a remote name, a config field), find its session with `mcp__ccd_session_mgmt__list_sessions` (load it with ToolSearch if it is deferred), pick the one whose `cwd` is this project and whose title starts with `Verity:`, and send the question with `SendMessage`, putting that session's `sessionId` (`local_...`) in `to`. Never message a session from another project. Do not use `ListAgents` to find the target: it shows only sessions that are running right now, and a message sent by `sessionId` also reaches one that is not. To reply to a question, use the `from` of the incoming message as `to`. Make the message self-contained: who is asking, the task ID, the context, the exact question, and the form of answer you need. Limits:
  - One question, one answer. If the answer raises a follow-up, or the two of you disagree, stop and bring it to the user.
  - Facts only. Design decisions and anything that changes scope go to the user, not to another agent.
  - When you receive a question, reply to the sender in a few lines, change nothing on its behalf, and go back to your own task.
  - Mention the exchange and what you learned in your next report to the user.
- **Fallback: copy-paste block.** If the target agent has no open session, or the message is not delivered, end your message with one fenced code block per target agent, labelled with that agent's name just above it. The block must be a self-contained prompt the user can paste as is: say which agent is asking and for which task ID, give the context and file paths needed, ask the exact question, and say what form the answer should take. When you answer such a prompt, put the answer in a fenced block addressed back to the asking agent the same way.
