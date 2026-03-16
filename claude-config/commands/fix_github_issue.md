Please analyze and fix the GitHub issue: $ARGUMENTS.

Follow this structured approach across four phases:

## Phase 1: Plan

1. Use `gh issue view` to get the issue details and understand the problem thoroughly
2. Analyze the issue requirements, acceptance criteria, and any linked discussions
3. Search the codebase to identify relevant files, modules, and dependencies
4. If there are UI/UX implications for the changes, refer to the documentation in the style guide file.
5. Determine the scope of changes needed and potential impact areas
6. Create a new feature branch using `gh` or `git checkout -b` with a descriptive name (e.g., `fix/issue-123-description`)
7. Document your understanding and planned approach in comments

## Phase 2: Implement

1. Implement the necessary code changes to address the issue
2. Follow existing code patterns, style guidelines, and architectural decisions
3. Make incremental commits with clear, descriptive messages
4. Ensure your implementation handles edge cases and error scenarios
5. Add appropriate documentation, comments, or README updates if needed
6. Verify the implementation addresses all aspects of the original issue

## Phase 3: Test

1. Write comprehensive tests appropriate for the codebase (unit, integration, or end-to-end as needed)
2. Ensure tests cover both happy path and edge cases for your changes
3. Run the full test suite to verify no existing functionality is broken
4. Perform any necessary linting, formatting, and type checking
5. Test your changes manually if applicable (UI changes, CLI tools, etc.)
6. Verify that all CI/CD checks would pass before pushing

## Phase 4: Deploy

1. Push your branch to the remote repository
2. Use `gh pr create` to create a pull request with:
   - Clear title referencing the issue (e.g., "Fix: Resolve issue #123 - description")
   - Detailed description explaining what was changed and why
   - Reference to the original issue using "Closes #123" or "Fixes #123"
   - Any additional context, screenshots, or testing notes
3. Ensure the PR is ready for review with all checks passing
4. Do NOT merge to main directly - the PR must go through the proper review process

Throughout all phases, maintain clean commit history and ensure each commit represents a logical unit of work. If you encounter any blockers or need clarification, document them clearly in your PR description.
