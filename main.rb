TEMPLATE_RUBY_VERSION = "ruby-1.9.3-p125"

@root = File.expand_path(File.directory?('') ? '' : File.join(Dir.pwd, ''))
@project = @root.split("/").last

def wget(uri, destination)
  run "wget --no-check-certificate #{uri} -O #{destination}"
end

@after_blocks = []
def after_bundler(&block); @after_blocks << block; end

RUN_RUBY_PREFIX = "MY_RUBY_HOME=$HOME/.rvm/bin/#{@project}_ruby"
def run_ruby(command)
  run "#{RUN_RUBY_PREFIX} #{command}"
end

# set RVM wrapper to switch environments
run "rvm wrapper #{TEMPLATE_RUBY_VERSION}@#{@project} #{@project}"

# setup mocks for ccrb
if ENV["CRUISE"]
  puts "Mocking responses for Cruise.rb"
  @responses = {
    "Do you want to use MySQL?" => true,
    "Do you want RR?" => true,
    "Do you want to use Webrat with Sauce Labs support?" => false,
    "Do you want the HAML gem?" => true
  }

  if (ENV['TEMPLATE_DB'] == 'postgresql')
    @responses['Do you want to use MySQL?'] = false
    @responses["Or PostgreSql?"]  = true
  end

  def yes?(question)
    log '', question
    log 'Response mocked - ', @responses[question]
    @responses[question]
  end
end

# git
run "git init" unless File.exist?(".git")

# jquery
inside "public/javascripts" do
  wget "http://github.com/rails/jquery-ujs/raw/master/src/rails.js", "rails.js"
  FileUtils.mkdir_p('jquery')
  wget "http://code.jquery.com/jquery-1.4.4.min.js",                 "jquery/jquery.min.js"
end

application do
  "\n    config.action_view.javascript_expansions[:defaults] = %w(jquery.min rails)\n"
end

gsub_file "config/application.rb", /# JavaScript.*\n/, ""
gsub_file "config/application.rb", /# config\.action_view\.javascript.*\n/, ""

# gems
create_file ".rvmrc", "rvm --create #{TEMPLATE_RUBY_VERSION}@#{@project}"

# clean up Gemfile
gsub_file 'Gemfile', /gem 'sqlite/, "# gem 'sqlite"
gsub_file 'Gemfile', /#.*$/, ''
gsub_file 'Gemfile', /\n[\n]+$/, "\n"

# default gems
inject_into_file 'Gemfile', :after => /gem 'rails'.*$/ do
  " \n"
end

gem 'bundler'
gem 'auto_tagger', '0.2.3'
gem 'heroku'

# gemfile groups
@test_gems = []
@dev_gems = []
@dev_test_gems = []

# gem choices
if yes?("Do you want to use MySQL?")
  gem 'mysql2'
  @database = 'mysql'
elsif yes?("Or PostgreSql?")
  gem 'pg'
  @database = 'postgresql'
end

if yes?("Do you want RR?")
  @test_gems.push("gem 'rr'")
  @mock_framework = 'rr'
elsif yes?("Or mocha?")
  @test_gems.push("gem 'mocha'")
  @mock_framework = 'mocha'
end

if yes?("Do you want to use Webrat with Sauce Labs support?")
  @sauce = true
  @dev_test_gems.push("gem 'webrat'")
  @dev_test_gems.push("gem 'net-ssh'")
  @dev_test_gems.push("gem 'net-ssh-gateway'")
  @dev_test_gems.push("gem 'rest-client'")
  @dev_test_gems.push("gem 'saucelabs_adapter', :git => 'git://github.com/pivotal/saucelabs-adapter.git', :branch => 'rails3', :submodules => true")

  after_bundler do
    run_ruby "rails g saucelabs_adapter"
    gsub_file "config/selenium.yml", "YOUR-SAUCELABS-USERNAME", "pivotallabs"
    gsub_file "config/selenium.yml", "YOUR-SAUCELABS-ACCESS-KEY", "YOURSAUCEAPIKEY"
  end
elsif yes?("Or Cucumber with Capybara (doesn't work with Sauce Labs)?")
  @cucumber = true
  @dev_test_gems.push("gem 'cucumber-rails'")
  @dev_test_gems.push("gem 'capybara'")
  @dev_test_gems.push("gem 'database_cleaner'")

  after_bundler do
    run_ruby "rails g cucumber:install --capybara --rspec"
  end
end

if yes?("Do you want the HAML gem?")
  gem 'haml'
  gem 'haml-rails'
end

# insert gemfile groups
append_file "Gemfile" do
  delimiter = "\n  "
  <<-GROUPS

group :development, :test do
  gem 'rspec-rails'
  gem 'jasmine'
  gem "headless"

  #{@dev_test_gems.join(delimiter)}
end

group :development do
  #{@dev_gems.join(delimiter)}
end

group :test do
  #{@test_gems.join(delimiter)}
end

  GROUPS
end

# installation scripts for default gems
after_bundler do
  run_ruby "rails g rspec:install"
  run_ruby "bundle exec jasmine init"
end

# run bundler
run_ruby "gem install bundler"

say "Running Bundler install. This will take a while."
run_ruby "bundle install"

say "Running after Bundler callbacks."
@after_blocks.each{|b| b.call}

# final cleanups
remove_dir "test"

# update rspec mocking framework
if @mock_framework
  gsub_file 'spec/spec_helper.rb', "# config.mock_with :#{@mock_framework}", "config.mock_with :#{@mock_framework}"
  gsub_file 'spec/spec_helper.rb', "config.mock_with :rspec", "# config.mock_with :rspec"
end

# update database.yml
if @database
  remove_file "config/database.yml"
  database_yml_content = ""

  def database_environment(env_name, env_suffix)
    <<-EOC
  #{env_name}:
    adapter: #{@database == 'mysql' ? 'mysql2' : 'postgresql'}
    database: #{@project}_#{env_suffix}
    username: #{@database == 'mysql' ? 'root' : 'postgres'}
    password: #{@database == 'mysql' || ENV['CRUISE'] ? 'password' : ''}
    host: localhost
    #{ENV['CRUISE'] && @database == 'mysql' ? 'socket: /tmp/mysql.sock' : ''}

    EOC
  end

  database_yml_content << database_environment("development", "dev")
  database_yml_content << <<-EOS
  # Warning: The database defined as 'test' will be erased and
  # re-generated from your development database when you run 'rake'.
  # Do not set this db to the same as development or production.
  EOS
  database_yml_content << database_environment("test", "test")
  database_yml_content << database_environment("production", "production")

  file "config/database.yml" do
    database_yml_content
  end
end

# setup database
run_ruby "rake db:create:all db:migrate"

# create tests
file "spec/models/dummy_spec.rb" do <<-EOS
require 'spec_helper'

describe "Dummy spec" do
  it "should pass" do
    1.should == 1
  end

  xit "It supports disabled specs" do
    1.should == 1
  end

  it "supports unimplemented specs"
end
EOS
end
