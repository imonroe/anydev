You are in a large, decoupled Drupal 11 application.  The frontend is a NextJS app which is located in the
`frontend-library/` directory.  This particular instance uses the site defined in the `docroot/sites/library/` directory,
and the installation profile is located in the `docroot/profiles/lagunita/sul_profile/` directory.

This Drupal site uses the `config_split` module to ensure clean separation of configuration.  Specifically, the `library` site 
uses the `library` configuration split.
