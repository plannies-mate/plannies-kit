# Project Guidelines for AI Assistants

## Purpose

This document guides AI assistants in working on small-to-medium sized data processing tools. For project-specific
technical details, always refer to SPEC.md.

## AI Development Approach

### Understanding Requirements

- Always check SPEC.md first for exact requirements
- Don't make assumptions about data formats or processing rules
- Ask for clarification if requirements seem ambiguous
- Remember that simpler is usually better

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
- Under-documenting complex logic

## Communication

- Ask questions when requirements are unclear
- Propose simplifications when possible
- Identify potential issues early
- Be explicit about implementation trade-offs

Remember: The AI's role is to implement the specified requirements accurately and simply, not to enhance them without
discussion.
