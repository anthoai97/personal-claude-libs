# Update Documentation

Automatically analyze recent changes and update project documentation to reflect current state.

## Core Documentation Principle: Document Current State Only

**CRITICAL: Always document the current "is" state of the system. Never reference legacy implementations, describe improvements made, or explain what changed. Documentation should read as if the current implementation has always existed.**

### Documentation Anti-Patterns to Avoid:
- ❌ "Refactored the notification system to use sounddevice instead of platform-specific commands"
- ❌ "Improved setup.sh by adding platform detection"
- ❌ "Previously used X, now uses Y for better results"
- ❌ "Legacy implementation has been replaced with..."

### Documentation Best Practices:
- ✅ "The notification system uses sounddevice for cross-platform audio playback"
- ✅ "setup.sh detects OS for platform-specific uv installation"
- ✅ "Uses PEP 723 inline metadata for dependency management"
- ✅ "The hook architecture integrates with Claude Code lifecycle events"

## Workflow

### Step 1: Analyze Changes

Determine what changed based on input parameter:

**No input (default):** Analyze recent conversation context
**Git commit ID:** Analyze specific commit (`git show`, `git diff`)
**"uncommitted"/"staged":** Analyze working directory changes
**"last N commits":** Analyze recent commit range

**Look for documentation-relevant changes:**
- New features or components (new hooks, commands, scripts)
- Architecture decisions (new patterns, structural changes)
- Technology changes (new dependencies, frameworks)
- File structure changes (new directories, reorganized code)

**Exclude from documentation:**
- Performance optimizations without architectural impact
- Bug fixes that don't change interfaces
- Code cleanup or refactoring without usage changes
- Minor test additions

### Step 2: Understand Project Structure

This project uses a simplified documentation structure:

**Primary Documentation:**
- `README.md` - User-facing quick start and component overview
- `CLAUDE.md` - AI-facing development guidelines and technical details
- `.claude/commands/*.md` - Slash command definitions

**Documentation Mapping:**
- Hook changes → Update CLAUDE.md Technical Details + README.md Components
- Setup script changes → Update README.md Installation + CLAUDE.md Development Flow
- New slash commands → Update CLAUDE.md Commands table + create `.claude/commands/*.md`
- Directory structure → Update CLAUDE.md Repository Structure + README.md Structure
- Dependency changes → Update CLAUDE.md Technical Details + README.md Requirements

### Step 3: Decide Update Strategy

**For simple changes (0-1 files affected):**
Proceed with direct updates

**For complex changes (2+ major areas):**
Use sub-agents for parallel analysis:
- Change impact analysis
- Architecture validation
- Dependency mapping
- Documentation accuracy assessment

### Step 4: Update Documentation

**Update Priority Order:**
1. **CLAUDE.md** - AI-facing technical details (primary reference)
2. **README.md** - User-facing quick start (secondary)
3. **Slash command docs** - Only if new commands added

**Update Guidelines:**
- **Be concise** (max 3 sentences unless major architectural change)
- **Be specific** (include file names, technologies, key benefits)
- **Follow existing patterns** in each document
- **Avoid redundancy** (don't repeat what's already documented)
- **Use present tense** ("The system uses..." not "Now uses...")

### Step 5: Validation

Before completing:
- ✓ All documented file paths exist
- ✓ Code examples match actual implementation
- ✓ Command examples are executable
- ✓ No references to "old" vs "new" implementations
- ✓ Documentation describes current state only

## When NOT to Update Documentation

Skip documentation updates for:
- Bug fixes (unless they change architecture)
- Minor tweaks or cleanup
- Debugging or temporary changes
- Code formatting or comments
- Trivial modifications
- Environment-specific configuration changes

## Example Update Patterns

**Adding a new hook:**
```markdown
CLAUDE.md update:
- Add to Repository Structure
- Add to Commands section with usage example
- Add to Hook Lifecycle Integration if needed

README.md update:
- Add to Components section
- Add installation/usage example
```

**Modifying setup.sh:**
```markdown
CLAUDE.md update:
- Update Setup Script Platform Detection section
- Update Multi-OS Compatibility Guidelines if relevant

README.md update:
- Update "What the Setup Script Does" section
```

**Adding a slash command:**
```markdown
Create: .claude/commands/[command-name].md
Update CLAUDE.md: Add to Slash Commands table
README.md: Usually no update needed
```

## Guidelines

- Document the "is" state, never the "was" → "is now" transition
- Only update sections that are actually outdated
- Keep documentation concise and actionable
- Preserve existing style and formatting conventions
- Optimize for AI consumption (clear file paths, structure markers)
- Report what was updated and why
