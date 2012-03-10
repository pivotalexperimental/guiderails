Guiderails: Pivotal's Rails 3 Templates
================================

# How?
rails new APPNAME -m https://github.com/pivotal/guiderails/raw/master/main.rb

# What are my choices?
* Mysql or Postgres
* RR or Mocha
* Webrat with Saucelabs support
* Cucumber with Capybara (no suacelabs support)
* SASS (with HAML)

# What else do I get?
* A ci_build.sh script for running your project in CI.
* A local git repo
* An rvmrc
* Bundler, auto-tagger, JSON, Heroku, rspec-rails, Jasmine, and Headless gems (in the global or development groups)
* Jasmine initialized for JavaScript testing
* Rspec installed
* Some testing related rake tasks

# Contributions
Guiderails is how we start rails projects, thus it has our defaults embedded in it.  Pull requests to fix bugs will gladly be accepted, see the rakefile for the tests we run and add one if necessary.  Pull requests to add features will be considered, but may be rejected on the basis of us not needing it.

# License
Guiderails is MIT licensed.  See MIT-LICENSE for details.
