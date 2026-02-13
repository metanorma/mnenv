# Proposal: Extract mnenv into a Standalone Gem

## Background

The `mnenv` codebase currently resides within the `metanorma/versions` repository. This creates a coupling between:

1. **mnenv** - A version manager tool for Metanorma (like rbenv/pyenv)
2. **versions** - A registry of Metanorma version metadata and Gemfiles

These two concerns should be separated for better maintainability and clearer responsibility.

## Current State

### Repository: `metanorma/versions`

Contains:
- `lib/mnenv/` - The mnenv gem code
- `data/gemfile/` - Gemfile registry with version metadata
- `spec/` - Test suite for mnenv
- `.github/workflows/` - CI/CD workflows

### Proposed State

#### Repository: `metanorma/mnenv` (NEW)

A standalone Ruby gem containing:
- Version management logic
- Installation methods (gemfile/binary)
- Shell integration (shims)
- CLI commands

#### Repository: `metanorma/versions` (SIMPLIFIED)

A static data registry containing:
- `data/gemfile/versions.yaml` - Version metadata
- `data/gemfile/v*/` - Gemfile and Gemfile.lock for each version
- `.github/workflows/` - Workflows to update version data

## Architecture

### mnenv Gem Structure

```
mnenv/
├── lib/
│   ├── mnenv/
│   │   ├── cli.rb                    # Thor CLI entry point
│   │   ├── commands/
│   │   │   ├── available_command.rb  # List available versions
│   │   │   ├── install_command.rb    # Install a version
│   │   │   ├── uninstall_command.rb  # Uninstall a version
│   │   │   ├── version_command.rb    # Show mnenv version
│   │   │   ├── global_command.rb     # Set global version
│   │   │   ├── local_command.rb      # Set local version
│   │   │   ├── use_command.rb        # Set shell session version
│   │   │   ├── versions_command.rb   # List installed versions
│   │   │   └── snap_command.rb       # Snap package support
│   │   ├── shells/
│   │   │   ├── base.rb               # Abstract shell base class
│   │   │   ├── bash.rb               # Bash/Unix shell
│   │   │   ├── power_shell.rb        # PowerShell (Windows)
│   │   │   ├── cmd.rb                # CMD (Windows)
│   │   │   └── factory.rb            # Shell detection factory
│   │   ├── installers/
│   │   │   ├── base.rb               # Abstract installer base
│   │   │   ├── gemfile_installer.rb  # Gemfile-based installation
│   │   │   └── binary_installer.rb   # Binary installation
│   │   ├── installer.rb              # Installer factory
│   │   ├── shim_manager.rb           # Shim generation
│   │   ├── resolver                  # Version resolution script
│   │   ├── logger.rb                 # Logging utilities
│   │   └── version.rb                # Gem version
│   └── mnenv.rb                      # Main entry point
├── spec/
│   └── ...                           # Test suite
├── exe/
│   └── mnenv                         # Executable
├── mnenv.gemspec
├── Gemfile
├── Gemfile.lock
├── Rakefile
├── .rubocop.yml
└── README.adoc
```

### versions Registry Structure

```
versions/
├── data/
│   └── gemfile/
│       ├── versions.yaml             # Version metadata
│       └── v1.14.3/
│           ├── Gemfile
│           └── Gemfile.lock.archived
├── .github/
│   └── workflows/
│       ├── fetch-gemfile.yml         # Extract Gemfiles from Docker
│       ├── fetch-chocolatey.yml      # Update Chocolatey versions
│       ├── fetch-homebrew.yml        # Update Homebrew versions
│       └── fetch-snap.yml            # Update Snap versions
├── scripts/
│   └── update_versions_yaml.rb       # Utility script
├── Gemfile
├── Gemfile.lock
└── README.adoc
```

## Version Data Access

### Option A: Git Submodule (Recommended)

The `mnenv` gem includes the `versions` repository as a data source:

```ruby
# In mnenv, versions data is accessed via submodule
DATA_DIR = File.expand_path('../versions/data', __dir__)
```

### Option B: Remote Fetch

The `mnenv` gem fetches version data from GitHub:

```ruby
# Fetch versions.yaml from GitHub
VERSIONS_URL = 'https://raw.githubusercontent.com/metanorma/versions/main/data/gemfile/versions.yaml'
```

### Option C: RubyGems Distribution

Version data is packaged with the `mnenv` gem and updated via gem releases.

## Migration Plan

### Phase 1: Create mnenv Repository

1. Create new repository `metanorma/mnenv`
2. Copy mnenv code from `versions` repository
3. Update gemspec and dependencies
4. Set up CI/CD workflows

### Phase 2: Simplify versions Repository

1. Remove mnenv code from `versions`
2. Keep only version data and fetch workflows
3. Update documentation

### Phase 3: Update Dependencies

1. Update any projects depending on `versions` to use `mnenv`
2. Ensure backward compatibility during transition

## Benefits

### Separation of Concerns

- **mnenv**: Tool development and releases
- **versions**: Data registry and updates

### Independent Versioning

- mnenv can be versioned independently
- Version data can be updated without releasing a new gem

### Cleaner Architecture

- Single responsibility for each repository
- Easier testing and maintenance

### Better Distribution

- mnenv as a standard Ruby gem
- Version data as static files accessible via HTTP

## Implementation Checklist

- [ ] Create `metanorma/mnenv` repository
- [ ] Copy lib/mnenv/* to new repository
- [ ] Copy spec/* to new repository
- [ ] Copy exe/mnenv to new repository
- [ ] Update mnenv.gemspec
- [ ] Create README.adoc for mnenv
- [ ] Set up GitHub Actions for mnenv
- [ ] Remove mnenv code from versions repository
- [ ] Update versions README.adoc
- [ ] Test mnenv installation from new repository
- [ ] Publish mnenv gem to RubyGems

## Timeline

Estimated effort: 2-3 hours for migration and testing.

## Questions

1. Should mnenv fetch version data remotely or bundle it?
2. How to handle the transition period for existing users?
3. Should we maintain backward compatibility in the versions repository?
