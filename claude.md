# Claude Code Instructions

## Git Commit Policy

After completing each task:

1. **Stage only the files related to that task** — use `git add <specific files>` rather than `git add .`
2. **Write a clear commit message** following this format:
   ```
   <type>: <short description>

   Task #<N>: <task subject>

   - Bullet points of what was done
   - Keep it concise but informative

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   ```

3. **Commit types**:
   - `feat` — new feature or functionality
   - `chore` — setup, config, dependencies
   - `refactor` — code changes that don't add features
   - `fix` — bug fixes
   - `docs` — documentation only

4. **Example commit**:
   ```
   chore: scaffold Rails 8 app with PostgreSQL and Tailwind

   Task #1: Scaffold Rails 8 app with PostgreSQL, Solid Queue, and Tailwind

   - Generated Rails 8 app with PostgreSQL and Tailwind
   - Added solid_queue, dotenv-rails, ruby-openai, anthropic gems
   - Configured Solid Queue as ActiveJob adapter
   - Removed Rails credentials in favor of ENV vars

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   ```

5. **Do not**:
   - Combine multiple tasks into one commit
   - Commit broken or incomplete work
   - Commit files unrelated to the current task

## Task Workflow

1. Mark task as `in_progress` before starting
2. Complete the work
3. Test that it works (run server, check in browser if applicable)
4. Commit with message referencing the task
5. Mark task as `completed`
6. Move to next unblocked task

## Code Style

- Follow Rails conventions
- Use Tailwind utility classes for styling
- Keep controllers thin, models handle business logic
- Use service objects for external API integrations
- Write clear, self-documenting code
