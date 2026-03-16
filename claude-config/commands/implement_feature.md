# Feature Implementation Pipeline

You are coordinating a complete feature implementation using our specialized subagents. Follow this structured approach, taking into account any documentation which currently exists for this project:

## Phase 1: Requirements & Design

1. **Use the product manager subagent** to:

   - Analyze and refine the feature requirements from: $ARGUMENTS
   - Define acceptance criteria and success metrics
   - Identify potential edge cases and user scenarios
   - Create a brief product specification

2. **Use the ux-ui designer subagent** to:

   - Design the user interface and user experience, taking in to account any style guide documentation.
   - Create wireframes or mockups if needed
   - Define the user flow and interaction patterns
   - Specify design system components to use

3. **Use the technical lead-architect subagent** to:
   - Review the requirements and design
   - Design the overall technical architecture
   - Identify components that need to be built/modified
   - Define the data models and API contracts
   - Create implementation strategy and identify dependencies

## Phase 2: Implementation Planning

4. **Use the data engineer subagent** to:

   - Design any required database schema changes
   - Plan data migration scripts if needed
   - Define data processing pipelines
   - Specify analytics and monitoring data points

5. **Use the devops engineer subagent** to:
   - Review infrastructure requirements
   - Plan deployment strategy
   - Identify configuration changes needed
   - Set up monitoring and alerting for the new feature

## Phase 3: Development

6. **Use the backend developer subagent** to:

   - Implement the server-side logic and APIs
   - Create database migrations
   - Implement business logic and data validation
   - Add proper error handling and logging

7. **Use the frontend developer subagent** to:

   - Implement the user interface components
   - Integrate with backend APIs
   - Implement client-side validation and error handling
   - Ensure responsive design and accessibility

8. **Use the full stack developer subagent** to:
   - Review integration between frontend and backend
   - Implement any missing pieces or glue code
   - Ensure proper data flow throughout the system
   - Handle any cross-cutting concerns

## Phase 4: Quality Assurance

9. **Use the quality assurance engineer subagent** to:

   - Create comprehensive test cases
   - Implement automated tests (unit, integration, e2e)
   - Perform manual testing of the feature
   - Validate against acceptance criteria
   - Test edge cases and error scenarios

10. **Use the security engineer subagent** to:
    - Review code for security vulnerabilities
    - Validate input sanitization and authentication
    - Check for proper authorization controls
    - Review data handling and privacy compliance

## Phase 5: Site Reliability & Monitoring

11. **Use the site reliability engineer subagent** to:
    - Add appropriate monitoring and alerting
    - Review performance implications
    - Ensure proper logging and observability
    - Validate scalability considerations
    - Create runbooks for operational procedures

## Phase 6: Final Review & PR Preparation

12. **Use the technical lead-architect subagent** to:
    - Conduct final code review
    - Ensure architectural consistency
    - Validate that all requirements are met
    - Create comprehensive PR description with:
      - Feature overview and business justification
      - Technical implementation details
      - Testing strategy and results
      - Deployment notes and rollback plan
      - Screenshots/demos if applicable

## Coordination Instructions

- After each phase, summarize what was accomplished before moving to the next
- If any subagent identifies blockers or dependencies, pause and address them
- Ensure all code follows our established patterns and conventions
- Make sure all changes are properly tested and documented
- Create atomic, well-structured commits throughout the process
- The final output should be a complete, review-ready pull request

Begin by acknowledging the feature request: "$ARGUMENTS" and then proceed through each phase systematically.
