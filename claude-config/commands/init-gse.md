# Initial Context

ACE-GSE is a Drupal 10 multisite project for Stanford Graduate School of Education legacy sites. It manages four distinct sites: `ed`, `edtech`, `gardnercenter`, and `psc` within a single Drupal codebase.

## Development Commands

### Local Development (Lando)

```bash
# Setup local environment
./lando/setup_lando.sh

# Load data from DEV server
./lando/load_data_from_dev.sh

# Start Lando environment
lando start

# Access sites locally:
# - ed.lndo.site (main)
# - edtech.lndo.site
# - gardnercenter.lndo.site
# - psc.lndo.site
```

### Drush Commands

```bash
# Use site-specific aliases for multisite:
drush @ed.lando status
drush @edtech.lando status
drush @gardnercenter.lando status
drush @psc.lando status

# For development server aliases (when available):
drush @ed.dev status
```

### Code Quality

```bash
# Run PHPCS (Drupal coding standards)
lando phpcs docroot/modules/custom
lando phpcs docroot/themes/custom

# Run PHPUnit tests
lando phpunit

# Prettier (for JS/CSS in code-server)
lando prettier
```

### Composer

```bash
# Install dependencies
composer install

# Add Drupal modules
composer require drupal/module_name

# Update dependencies
composer update
```

## Architecture

### Multisite Structure

- **Web Root**: `docroot/` (not standard `web/`)
- **Sites Directory**: `docroot/sites/`
  - `docroot/sites/all/` - Shared multisite configuration
  - `docroot/sites/ed/` - ED site-specific config
  - `docroot/sites/edtech/` - EdTech site-specific config
  - `docroot/sites/gardnercenter/` - Gardner Center site-specific config
  - `docroot/sites/psc/` - PSC site-specific config

### Custom Code

- **Custom Modules**: `docroot/modules/custom/`
  - `stanford_samlauth/` - Stanford SAML authentication integration
  - `stanford_syndication/` - Content syndication system
- **Custom Themes**: `docroot/themes/custom/` (none currently)
- **Libraries**: `docroot/libraries/`

### Key Configuration

- **Composer**: Uses `composer.libraries.json` for additional library definitions
- **PHPCS**: Configured for Drupal standards, excludes line length rules
- **Lando**: Multi-service setup with PHP 8.3, MySQL 8.0, Adminer, ChromeDriver, and code-server

### Site-Specific Notes

- **ED site**: Administrator role has no permissions; use `webmaster` role for admin access
- Each site maintains separate configuration in `docroot/sites/{site}/config/sync/`

### Deployment

- **Acquia Pipelines**: Configured for Acquia Cloud deployment
- **Hooks**: Located in `hooks/` directory for deployment automation
- **Branch Strategy**: `1.x` for development, `main` for tagged releases

## Development Environment

### Code Server Integration

The Lando setup includes a code-server instance accessible at `code-server.gse.lndo.site:9999` providing:

- Full VSCode in browser
- Node.js/npm tooling
- SSH key access for GitHub/Acquia
- All development dependencies pre-installed

### Docker Services

- **appserver**: PHP 8.3 with Drupal
- **database**: MySQL 8.0
- **adminer**: Database administration at `adminer.gse.lndo.site`
- **chromedriver**: For browser testing
- **code-server**: VSCode in browser

## Testing

- PHPUnit configuration located in `docroot/core`
- Codeception available via BLT integration
- Chrome driver available for browser testing at port 4444
