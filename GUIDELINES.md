# Project Guidelines for AI Assistants

This project's documentation is split across several files:

- GUIDELINES.md (this file) - Guidelines for AI assistants and developers
- SPECS.md - Core requirements and system architecture
- IMPLEMENTATION.md - Detailed implementation guidance and algorithms

Please read ALL three files before proceeding.

Note: README.md contains installation and usage instructions which are not relevant for AIs.

## Purpose

This document guides AI assistants in working on small-to-medium sized data processing tools. For project-specific
technical details, always refer to SPEC.md.

## AI Development Approach

### Understanding Requirements

- Always check SPEC.md first for exact requirements
- Don't make assumptions about data formats or processing rules
- Ask for clarification if requirements seem ambiguous
- Remember that simpler is usually better

## Code Quality Principles

- Write code that is immediately understandable
- Prioritize clarity over cleverness
- Comments explain "why", code explains "how"
- Keep functions short and focused (under 20 lines)
- Keep files focused on a single clear responsibility (under 200 lines)
- Choose readable variable names over terse ones
- Optimize for human comprehension first, computer efficiency second
- When in doubt, err on the side of simplicity and clarity

## Defensive Programming Principles

- Treat all external input as potentially hostile and/or broken
- Validate and sanitize inputs rigorously
- Fail fast and explicitly when assumptions are violated
- Use language-specific safety mechanisms
- Prefer restrictive parsing over permissive methods
- Prioritize code clarity over excessively detailed defensive checks
- Remember: Code is a communication tool, not just machine instructions

### Code Development

- Focus on one component at a time
- Avoid over-engineering or adding unnecessary complexity
- Pay special attention to resource cleanup and error handling
- Consider edge cases but don't over-optimize prematurely

### Process Management

- Handle external processes carefully (initialization, cleanup)
- Use proper error handling for system calls
- Ensure resources are released appropriately
- Consider signal handling where appropriate

### Data Processing

- Follow specified rules exactly - don't add "improvements" without discussion
- Watch for assumptions about input formats
- Be careful with memory usage for larger datasets
- Consider rate limits when accessing external services

### Testing & Development

- Use limit parameters during development when available
- Test with small datasets first
- Verify output formats carefully
- Check resource cleanup during normal and error conditions

## Common AI Pitfalls to Avoid

- Adding complexity that wasn't requested
- Making assumptions about "standard" ways to process data
- Trying to optimize too early
- Missing cleanup of external resources
- Over-commenting obvious code
- Under-documenting complex logic (comments explain why, code should explain how)

## Communication

- Ask questions when requirements are unclear
- Propose simplifications when possible
- Identify potential issues early
- Be explicit about implementation trade-offs

Remember: The AI's role is to implement the specified requirements accurately and simply, not to enhance them without
discussion.
