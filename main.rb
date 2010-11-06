def wget(uri, destination)
  run "wget --no-check-certificate #{uri} -O #{destination}"
end

@root = File.expand_path(File.directory?('') ? '' : File.join(Dir.pwd, ''))
@project = @root.split("/").last

@after_blocks = []
def after_bundler(&block); @after_blocks << block; end

@rvm_envs = [
  "PATH=/Users/pivotal/.rvm/gems/ree-1.8.7-2010.02@#{@project}/bin:/Users/pivotal/.rvm/gems/ree-1.8.7-2010.02@global/bin:/Users/pivotal/.rvm/rubies/ree-1.8.7-2010.02/bin:/Users/pivotal/.rvm/bin:$PATH",
  "GEM_HOME=/Users/pivotal/.rvm/gems/ree-1.8.7-2010.02@#{@project}",
  "GEM_PATH=/Users/pivotal/.rvm/gems/ree-1.8.7-2010.02@#{@project}:/Users/pivotal/.rvm/gems/ree-1.8.7-2010.02@global",
  "BUNDLE_PATH=/Users/pivotal/.rvm/gems/ree-1.8.7-2010.02@#{@project}",
  "MY_RUBY_HOME=/Users/pivotal/.rvm/rubies/ree-1.8.7-2010.02",
  "IRBRC=/Users/pivotal/.rvm/rubies/ree-1.8.7-2010.02/.irbc"
  ].join(' ')
@rvm_envs = ''

# git
run "git init" unless File.exist?(".git")

# jquery
inside "public/javascripts" do
  wget "http://github.com/rails/jquery-ujs/raw/master/src/rails.js", "rails.js"
  FileUtils.mkdir_p('jquery')
  wget "http://code.jquery.com/jquery-1.4.2.min.js",                 "jquery/jquery.min.js"
end

application do
  "\n    config.action_view.javascript_expansions[:defaults] = %w(jquery.min rails)\n"
end

gsub_file "config/application.rb", /# JavaScript.*\n/, ""
gsub_file "config/application.rb", /# config\.action_view\.javascript.*\n/, ""

# gems
#create_file ".rvmrc", "rvm --create ree-1.8.7-2010.02@#{@project}"

# clean up Gemfile
gsub_file 'Gemfile', /gem 'sqlite/, "# gem 'sqlite"
gsub_file 'Gemfile', /#.*$/, ''
gsub_file 'Gemfile', /\n[\n]+$/, ''

# default gems
inject_into_file 'Gemfile', :after => /gem 'rails'.*$/ do
  " \n"
end

gem 'bundler'
gem 'auto_tagger', '0.2.2'
gem 'json', '1.4.6'
gem 'heroku'

# choices
@test_gems = []
@dev_gems = []
@dev_test_gems = []

if yes?("Do you want to use MySQL?")
  gem 'mysql2', '0.2.6'
  @database = 'mysql'
elsif yes?("Or PostgreSql?")
  gem 'pg', '0.9.0'
  @database = 'postgresql'
end

if yes?("Do you want RR?")
  @test_gems.push("gem 'rr', '1.0.2'")
  @mock_framework = 'rr'
elsif yes?("Or mocha?")
  @test_gems.push("gem 'mocha', '0.9.9'")
  @mock_framework = 'mocha'
end

if yes?("Do you want to use Webrat with Sauce Labs support?")
  @dev_test_gems.push("gem 'webrat', '0.7.2'")
  @dev_test_gems.push("gem 'net-ssh', '2.0.23'")
  @dev_test_gems.push("gem 'net-ssh-gateway', '1.0.1'")
  @dev_test_gems.push("gem 'rest-client', '1.6.1'")
  @dev_test_gems.push("gem 'saucelabs_adapter', :git => 'git://github.com/pivotal/saucelabs-adapter.git', :branch => 'rails3', :submodules => true")
  
  after_bundler do
    run "#{@rvm_envs} rails g saucelabs_adapter"
    gsub_file "config/selenium.yml", "YOUR-SAUCELABS-USERNAME", "pivotallabs"
    gsub_file "config/selenium.yml", "YOUR-SAUCELABS-ACCESS-KEY", "YOURSAUCEAPIKEY"
  end
elsif yes?("Or Cucumber with Capybara (doesn't work with Sauce Labs)?")
  @dev_test_gems.push("gem 'cucumber-rails', '0.3.2'")
  @dev_test_gems.push("gem 'capybara', '0.4.0'")

  after_bundler do
    run "#{@rvm_envs} rails g cucumber:install --capybara --rspec"
  end
end

@haml_installed = false
if yes?("Do you want to use HAML?")
  gem 'haml', '>= 3.0.0'
  gem 'haml-rails'
  @haml_installed = true
end

if yes?("Do you want to use SASS?")
  unless @haml_installed
    gem 'haml', '>= 3.0.0'
  end  
end

# gemfile injections

append_file "Gemfile" do
  delimiter = "  \n"
  <<-GROUPS

group :development, :test do
  gem 'mongrel', '1.1.5'
  gem 'rspec-rails', '2.0.1'
  gem 'jasmine', :git => "git://github.com/pivotal/jasmine-gem.git",
    :branch => "rspec2-rails3",
    :submodules => true

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

after_bundler do
  run "#{@rvm_envs} rails g rspec:install"

  # jasmine rails 3 hack
  jasmine_path = `#{@rvm_envs} bundle show jasmine`.chomp
  copy_file File.join(jasmine_path, 'generators', 'jasmine', 'templates', 'spec', 'javascripts', 'support', 'jasmine-rails.yml'), 'spec/javascripts/support/jasmine.yml'
  copy_file File.join(jasmine_path, 'generators', 'jasmine', 'templates', 'spec', 'javascripts', 'support', 'jasmine_runner.rb'), 'spec/javascripts/support/jasmine_runner.rb'
  copy_file File.join(jasmine_path, 'lib', 'jasmine', 'tasks', 'jasmine.rake'), 'lib/tasks/jasmine.rake'

  copy_file File.join(jasmine_path, 'jasmine', 'example', 'src', 'Player.js'), 'public/javascripts/Player.js'
  copy_file File.join(jasmine_path, 'jasmine', 'example', 'src', 'Song.js'), 'public/javascripts/Song.js'
  copy_file File.join(jasmine_path, 'jasmine', 'example', 'spec', 'SpecHelper.js'), 'spec/javascripts/helpers/SpecHelper.js'
  copy_file File.join(jasmine_path, 'jasmine', 'example', 'spec', 'PlayerSpec.js'), 'spec/javascripts/PlayerSpec.js'

end

run "#{@rvm_envs} gem install bundler"

say "Running Bundler install. This will take a while."
run "#{@rvm_envs} bundle install"

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
  file "config/database.yml" do <<-EOS
  development: &development
    adapter: #{@database == 'mysql' ? 'mysql2' : 'postgresql'}
    database: #{@project}_dev
    username: #{@database == 'mysql' ? 'root' : 'postgres'}
    password: #{@database == 'mysql' ? 'password' : ''}
    host: localhost
    #socket: /tmp/mysql.sock

  # Warning: The database defined as 'test' will be erased and
  # re-generated from your development database when you run 'rake'.
  # Do not set this db to the same as development or production.
  test:
    <<: *development
    database: #{@project}_test

  production:
    <<: *development
    database: #{@project}_production
  EOS
  end
end

# setup database
run "#{@rvm_envs} rake db:create:all db:migrate"

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
