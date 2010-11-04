def wget(uri, destination)
  run "wget --no-check-certificate #{uri} -O #{destination}"
end

run "git init" unless File.exist?(".git")

@root = File.expand_path(File.directory?('') ? '' : File.join(Dir.pwd, ''))
@project = @root.split("/").last

@after_blocks = []
def after_bundler(&block); @after_blocks << block; end

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
create_file ".rvmrc", "rvm --create ree-1.8.7-2010.02@#{@project}"

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
elsif yes?("Or PostgreSql?")
  gem 'pg', '0.9.0', :group => :test
end

if yes?("Do you want RR?")
  @test_gems.push("gem 'rr', '1.0.2'")
elsif yes?("Or mocha?")
  @test_gems.push("gem 'mocha', '0.9.9'")
end

if yes?("Do you want to use Webrat with Sauce Labs support?")
  @dev_test_gems.push("gem 'webrat', '0.7.2'")
  @dev_test_gems.push("gem 'net-ssh', '2.0.23'")
  @dev_test_gems.push("gem 'net-ssh-gateway', '1.0.1'")
  @dev_test_gems.push("gem 'rest-client', '1.6.1'")
  @dev_test_gems.push("gem 'saucelabs-adapter', '0.8.22'")

  after_bundler do
    generate 'saucelabs_adapter'
  end
elsif yes?("Or Cucumber with Capybara (doesn't work with Sauce Labs)?")
  @dev_test_gems.push("gem 'cucumber-rails', '0.3.2'")
  @dev_test_gems.push("gem 'capybara', '0.4.0'")

  after_bundler do
    generate "cucumber:install --capybara --rspec"
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
  gem 'jasmine', '1.0.1'
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

say "Running Bundler install. This will take a while."
run 'bundle install'
say "Running after Bundler callbacks."
@after_blocks.each{|b| b.call}
