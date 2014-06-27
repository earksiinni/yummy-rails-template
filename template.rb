def source_paths
  Array(super) + [File.join(File.expand_path(File.dirname(__FILE__)),'rails_root')]
end

def last_modified_file(dir)
  Dir.glob(File.join(dir, '*')).max_by {|f| File.mtime(f)}
end

def view_suffix
  @opts[:template_engine].to_s
end

def copy_view_file(file)
  copy_file "#{file}.html.#{view_suffix}"
end

def template_view_file(file)
  template "#{file}.html.#{view_suffix}"
end

def test_for_imagemagick
  unless `convert --version` =~ /ImageMagick/
    puts
    puts "ImageMagick not found, please install first."
    exit 1
  end
end

def test_for_mailcatcher
  unless `mailcatcher --version` =~ /^mailcatcher/
    puts
    puts "Mailcatcher not found, please run the following commands (if you're using RVM):"
    puts "  rvm default@mailcatcher --create do gem install mailcatcher"
    puts "  rvm wrapper default@mailcatcher --no-prefix mailcatcher catchmail"
    exit 1
  end
end

# Options
@opts = Hash.new
@opts[:authentication] = ask("
Authentication?
  1) Devise (default)
  2) Omniauth
  3) None
  >").to_i
case @opts[:authentication]
when 2
  @opts[:authentication] = :omniauth
when 3
  @opts[:authentication] = :none
else
  test_for_mailcatcher
  @opts[:authentication] = :devise
  @opts[:user_model] = ask("Name of initial user model for Devise (default == User)?")
  @opts[:user_model] = "User" if @opts[:user_model].empty?
end

@opts[:cssjs] = ask("
CSS/JS framework?
  1) Foundation (default)
  2) Bootstrap
  3) HTML5 Boilerplate
  4) None
  >").to_i
case @opts[:cssjs]
when 2
  @opts[:cssjs] = :bootstrap
when 3
  @opts[:cssjs] = :html5
else
  @opts[:cssjs] = :none
end

@opts[:template_engine] = ask("
Template engine?
  1) Slim (default)
  2) Haml
  3) ERB
  >").to_i
case @opts[:template_engine]
when 2
  @opts[:template_engine] = :haml
when 3
  @opts[:template_engine] = :erb
else
  @opts[:template_engine] = :slim
end

@opts[:cms] = ask("
CMS?
  1) None (default)
  2) Refinery
  3) Monologue
  >").to_i
case @opts[:cms]
when 2
  @opts[:cms] = :refinery
when 3
  @opts[:cms] = :monologue
  test_for_imagemagick
else
  @opts[:cms] = :none
end

@opts[:text_editor] = ask("
Text editor?
  1) None (default)
  2) Redactor
  >").to_i
case @opts[:text_editor]
when 2
  @opts[:text_editor] = :redactor
  test_for_imagemagick
else
  @opts[:text_editor] = :none
end

# Gems
gem 'pg'
if @opts[:authentication] == :omniauth
  gem 'omniauth'
  gem 'omniauth-oauth2'
end
gem 'slim' if @opts[:template_engine] == :slim
gem 'haml' if @opts[:template_engine] == :haml
gem 'redcarpet'
gem 'foundation-rails' if @opts[:cssjs] == :foundation
gem 'bootstrap-sass' if @opts[:cssjs] == :bootstrap
gem 'modernizr-rails' if @opts[:cssjs] != :foundation  # Already included with Foundation
gem 'normalize-rails' if @opts[:cssjs] == :html5
gem 'devise' if @opts[:authentication] == :devise
gem 'refinerycms', '~> 2.1' if @opts[:cms] == :refinery
gem 'monologue', github: 'jipiboily/monologue' if @opts[:cms] == :monologue
if @opts[:text_editor] == :redactor
  gem 'redactor-rails'
  gem 'carrierwave'
  gem 'mini_magick'
end

gem_group :development, :test do
  gem 'rspec-rails'
  gem 'pry'
end

gem_group :development do
  gem 'better_errors'
  gem 'guard-rails'
  gem 'guard-rspec'
  gem 'guard-cucumber'
  gem 'spring-commands-rspec'
  gem 'spring-commands-cucumber'
  gem 'rb-fsevent' if `uname` =~ /Darwin/
end

gem_group :test do
  gem 'capybara'
  gem 'factory_girl_rails'
  gem 'ruby_gntp'
  gem 'cucumber-rails', require: false
  gem 'database_cleaner'
end

gem_group :production do
  gem 'rails_12factor'
end

#insert_into_file 'Gemfile', "\nruby '2.1.1'", after: "source 'https://rubygems.org'\n"

# Delete unnecessary gems
gsub_file "Gemfile", /^gem\s+["']sqlite3["'].*$/, ''
gsub_file "Gemfile", /^gem\s+["']turbolinks["'].*$/, ''

# Run bundle install before proceeding
run 'bundle install'

# Config files
environment "config.active_record.schema_format = :sql"
inside 'config' do
  inside 'initializers' do
    template 'secret_token.rb'
  end

  remove_file 'database.yml'
  template 'database.yml'
end

# Assets
inside 'app' do
  inside 'assets' do
    inside 'stylesheets' do
      remove_file 'application.css'
      template 'application.scss'
    end
    inside 'javascripts' do
      remove_file 'application.js'
      template 'application.coffee'
    end
  end
end

# Layouts and shared views
inside 'app' do
  inside 'views' do
    inside 'layouts' do
      remove_file 'application.html.erb'
      template_view_file "application"
    end
    inside 'shared' do
      copy_view_file "_alert_danger"
      copy_view_file "_alert_info"
      copy_view_file "_alert_success"
      copy_view_file "_alert_warning"
      copy_view_file "_alerts"
    end
  end
end

# Static pages (initial controller and views)
inside 'app' do
  inside 'controllers' do
    copy_file 'static_pages_controller.rb'
  end
  inside 'views' do
    inside 'static_pages' do
      copy_file "index.html.#{view_suffix}"
    end
  end
end
route "root 'static_pages#index'"

# Database
run "createuser #{@app_name.underscore}"
run "createdb -O #{@app_name.underscore} #{@app_name.underscore}_development"
run "createdb -O #{@app_name.underscore} #{@app_name.underscore}_test"

# Devise
if @opts[:authentication] == :devise
  run 'bundle exec rails g devise:install'
  run "bundle exec rails g devise #{@opts[:user_model]}"
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: 'development'
  run 'bundle exec rails g devise:views'
  gsub_file last_modified_file("db/migrate"), /^# t/, 't'  # Enable all options in user model
  gsub_file last_modified_file("db/migrate"), /^# add_index/, 'add_index'
  inside 'config' do
    inside 'initializers' do
      copy_file 'devise.rb'
    end
  end
  route 'devise_for :user'
end

# Foundation
case @opts[:cssjs]
when :slim
  run 'bundle exec rails g foundation:install --slim'
when :foundation
  run 'bundle exec rails g foundation:install --foundation'
when :erb
  run 'bundle exec rails g foundation:install'
end
# N.B.: CSS/JS includes inside application.scss/coffee templates

# Mailcatcher
environment "config.action_mailer.delivery_method = :smtp", env: 'development'
environment "config.action_mailer.smtp_settings = { :address => 'localhost', :port => 1025 }", env: 'development'

# HAML and Redcarpet
if @opts[:template_engine] == :haml
  environment "Haml::Template.options[:ugly] = false", env: 'development'
  environment "Haml::Template.options[:ugly] = true", env: 'production'
  inside 'config' do
    inside 'initializers' do
      copy_file 'haml.rb'
    end
  end
end

# Slim (Redcarpet automatically detected)
if @opts[:template_engine] == :slim
  environment "Slim::Engine.set_default_options pretty: true, sort_attrs: false", env: 'development'
  environment "Slim::Engine.set_default_options pretty: false, sort_attrs: true", env: 'production'
end

# RSpec and Cucumber
run 'bundle exec rails g rspec:install'
run 'bundle exec rails g cucumber:install'
run 'bundle exec guard init rails'
run 'bundle exec guard init rspec'
run 'bundle exec guard init cucumber'
gsub_file 'Guardfile', /^guard :rspec do$/, "guard :rspec, cmd: 'spring rspec --color' do"
gsub_file 'Guardfile', /^guard 'cucumber' do$/, "guard 'cucumber', cmd: 'spring cucumber -c' do"
inside 'spec' do
  gsub_file 'spec_helper.rb', /use_transactional_fixtures = true/, "use_transactional_fixtures = false"
end

# Refinery
run 'bundle exec rails g refinery:cms --fresh-installation' if @opts[:cms] == :refinery

# Monologue
if @opts[:cms] == :monologue
  route "mount Monologue::Engine, at: '/blog'"
  run 'bundle exec rake monologue:install:migrations'
end

# Redactor
if @opts[:text_editor] == :redactor
  suffix = (@opts[:authentication] == :devise ? "--devise" : "")
  run "bundle exec rails g redactor:install #{suffix}"
  run 'bundle exec rails g redactor:config'
  if @opts[:authentication] == :devise && @opts[:user_model] != 'User'  # Default Redactor user model is User
    run 'bundle exec rails g migration rename_redactor_assets_user_id'
    mig = File.basename(last_modified_file("db/migrate"))
    inside 'db' do
      inside 'migrate' do
        remove_file mig
        template 'rename_redactor_assets_user_id.rb', mig
      end
    end
    inside 'app' do
      inside 'controllers' do
        remove_file 'application_controller.rb'
        template 'application_controller.rb'
      end
    end
    inside 'config' do
      inside 'initializers' do
        template 'redactor.rb'
      end
    end 
  end
end

# Normalize.css
if @opts[:cssjs] == :html5
  inside 'config' do
    inside 'initializers' do
      template 'assets.rb'
    end
  end
  inside 'app' do
    inside 'assets' do
      copy_file 'normalize.scss'
    end
  end
end

# Migrations
rake 'db:migrate'

# Init git
git :init
remove_file '.gitignore'
copy_file '.gitignore'
git add: '.'
git commit: "-a -m 'Initial commit.'"
