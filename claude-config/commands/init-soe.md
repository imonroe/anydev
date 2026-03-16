# Initial Context

You are in a large Drupal 10 site, which runs in a local development environment using Lando.

- the `docroot` folder holds the drupal application.
- the `docroot/profiles/custom/engineering` profile is the installation profile and holds all the configs.
- the theme is in `docroot/profiles/custom/engineering_profile/themes/engineering`

**Key Components:**

- **Profile**: `su-soe/engineering_profile` - The main installation profile for Stanford Engineering sites
- **Stack Base**: ACE Gryphon stack architecture
- **Configuration Management**: Uses config-split strategy with environment-specific configurations
- **Authentication**: SimpleSAMLphp integration for Stanford SSO
- **Multisite**: Currently single-site but architecture supports multisite expansion

**Directory Structure:**

- `docroot/` - Drupal web root containing core, modules, themes, and profiles
- `blt/` - BLT configuration and custom commands
- `lando/` - Local development environment configuration
- `simplesamlphp/` - SAML authentication configuration
- `tests/` - Codeception and other testing configurations

## Development Commands

### Lando (Local Development)

```bash
# Initial setup
./lando/setup_lando.sh
lando composer sync-soe  # Sync database and files from Stage

# Common operations
lando drush [command]     # Run Drush commands
lando blt [command]       # Run BLT commands
lando composer [command]  # Run Composer commands

# Site-specific Drush aliases
lando drush -y @default.local cr  # Clear caches on local

# Testing and quality
lando codeception         # Run Codeception tests
lando phpcs [path]        # Run PHP CodeSniffer
lando phpunit [options]   # Run PHPUnit tests
```

### BLT Commands

```bash
vendor/bin/blt blt:init:settings      # Initialize Drupal settings
vendor/bin/blt source:build:simplesamlphp-config  # Build SAML config
vendor/bin/blt sws:keys               # Download secret keys and certificates
vendor/bin/blt drupal:install         # Install Drupal
vendor/bin/blt tests:codeception:run  # Run Codeception tests
vendor/bin/blt sync                   # Sync database from cloud
vendor/bin/blt drupal:sync:files      # Sync files from cloud
```

### Testing and Code Quality

```bash
# PHP CodeSniffer (follows Drupal standards)
vendor/bin/phpcs --standard=Drupal,DrupalPractice [path]

# PHPUnit testing
vendor/bin/phpunit -c docroot/core

# Static analysis
vendor/bin/phpstan

# Codeception functional/acceptance testing
vendor/bin/codecept run
```

### Composer Scripts

```bash
composer sync-soe-dev    # Sync from test environment
composer sync-soe-prod   # Sync from production
composer init-stack      # Full stack initialization
composer local-install   # Local development setup
```

## Environment Configuration

**BLT Configuration**: Core settings in `blt/blt.yml`

- Project prefix: `soegryphon`
- Default branch: `2.x`
- Profile: `engineering_profile`
- Config strategy: `config-split`

**Local Development**:

- Copy `lando/example.local.blt.yml` to `blt/local.blt.yml`
- Copy `lando/example.php.ini` to `lando/php.ini`
- Local site URL: `http://soegryphon.lndo.site`

**Drush Aliases**:

- Local: `@default.local`
- Development: `@soegryphon.dev`
- Test: `@soegryphon.test`
- Production: `@soegryphon.prod`

## Code Standards

- Follows Drupal coding standards (enforced via phpcs.xml.dist)
- Custom modules: `docroot/modules/custom/` (currently none)
- Custom themes: `docroot/themes/custom/` (currently none)
- Tests: `tests/` directory with Codeception configuration

## Key Dependencies

- Drupal 10.4
- BLT 13.7+ for build automation
- SimpleSAMLphp for authentication
- Stanford profiles and modules (`su-soe/engineering_profile`, `su-sws/stanford_profile`)
- Codeception for functional testing

## Git Workflow

- Main development branch: `2.x`
- Current working branch: `lando-update`
- Remote: Acquia Git repository
- Deploy directory: `deploy/` (excluded from main repo)

## Important Notes

- Always use Lando prefix for local commands (`lando drush`, `lando blt`)
- SAML configuration requires secret keys from `blt sws:keys`
- Database syncing pulls from Stage environment by default
- SimpleSAMLphp config is built automatically via BLT
- Config management uses split strategy for environment-specific settings
