#
# Cookbook Name:: rails_app_server
# Recipe:: default
#
# Copyright (C) 2015 tiere
#
# All rights reserved - Do Not Redistribute
#

app_user  = node['rails_app_server']['user']
app_name  = node['rails_app_server']['name']
user_home = "/home/#{app_user}"
app_path  = "#{user_home}/#{app_name}"

db_name     = node['rails_app_server']['database']['name']
db_password = node['rails_app_server']['database']['password']

deploy_public_key  = node['rails_app_server']['deploy_public_key']
deploy_private_key = node['rails_app_server']['deploy_private_key']
secret_key_base    = node['rails_app_server']['secret_key_base']
attachment_hash    = node['rails_app_server']['attachment_hash']
ssl_key            = node['rails_app_server']['ssl_key']
ssl_cert           = node['rails_app_server']['ssl_cert']
devise_secret_key  = node['rails_app_server']['devise_secret_key']
mail_domain        = node['rails_app_server']['mail_domain']
mail_user_name     = node['rails_app_server']['mail_user_name']
mail_password      = node['rails_app_server']['mail_password']

include_recipe 'apt'

chef_gem 'foreman'

%w(nodejs-legacy
   npm
   libffi-dev
   postgresql-contrib
   imagemagick).each do |pkg|
  package pkg do
    action :install
  end
end

execute 'install bower' do
  command 'npm install -g bower'
  not_if 'command -v bower | grep -c bower'
end

execute 'npm update -g bower' do
  only_if 'command -v bower | grep -c bower'
end

user app_user do
  supports manage_home: true
  home     user_home
  action   :create
end

%W(#{user_home}
   #{user_home}/.ssh).each do |dir|
  directory dir do
    owner  app_user
    group  app_user
    mode   0700
    action :create
  end
end

template "#{user_home}/.ssh/wrap-ssh4git.sh" do
  source 'wrap-ssh4git.sh.erb'
  owner  app_user
  group  app_user
  mode   0700
end

template "#{user_home}/.ssh/id_rsa.pub" do
  source    'deploy_public_key.pub.erb'
  owner     app_user
  group     app_user
  mode      0600
  variables deploy_public_key: deploy_public_key
end

template "/home/#{app_user}/.ssh/id_rsa" do
  source    'deploy_private_key.erb'
  owner     app_user
  group     app_user
  mode      0600
  variables deploy_private_key: deploy_private_key
end

include_recipe 'rbenv::default'
include_recipe 'rbenv::ruby_build'

rbenv_ruby node['ruby']['version'] do
  global true
end

rbenv_gem 'bundler' do
  ruby_version node['ruby']['version']
end

include_recipe 'postgresql::server'

execute 'create postgres user' do
  user_exists = "#{postgres_psql("SELECT * FROM pg_user WHERE usename='#{app_user}'")} | " \
                "grep -c #{app_user}"

  command postgres_psql("CREATE USER #{app_user} WITH PASSWORD '#{db_password}'")

  not_if user_exists
end

execute 'add superuser privileges to user' do
  command postgres_psql("ALTER ROLE #{app_user} SUPERUSER")
end

execute 'create database' do
  command postgres_psql("CREATE DATABASE #{db_name}")

  not_if "#{postgres_psql('\\l')} | grep -c #{db_name}"
end

%W(#{app_path}
   #{app_path}/shared
   #{app_path}/shared/config
   #{app_path}/shared/log
   #{app_path}/shared/tmp
   #{app_path}/shared/tmp/pids
   #{app_path}/shared/tmp/sockets
   #{app_path}/shared/system).each do |dir|
  directory dir do
    owner  app_user
    group  app_user
    action :create
  end
end

template "#{app_path}/shared/config/database.yml" do
  source 'database.yml.erb'
  owner  app_user
  group  app_user
  mode   0600
end

template "#{app_path}/shared/config/puma.rb" do
  source 'puma.rb.erb'
  owner  app_user
  group  app_user
  mode   0600
end

template "#{app_path}/shared/.env" do
  source    '.env.erb'
  owner     app_user
  group     app_user
  mode      0600
  variables rbenv_path_prefix: node['rbenv']['install_prefix'],
            secret_key_base:   secret_key_base,
            attachment_hash:   attachment_hash,
            devise_secret_key: devise_secret_key,
            mail_domain:       mail_domain,
            mail_user_name:    mail_user_name,
            mail_password:     mail_password
end

deploy app_path do
  repo node['application']['repo']
  user app_user

  symlinks 'tmp/pids'       => 'tmp/pids',
           'tmp/sockets'    => 'tmp/sockets',
           'config/puma.rb' => 'config/puma.rb',
           '.env'           => '.env',
           'log'            => 'log',
           'system'         => 'public/system'

  before_restart do
    execute 'run bundle' do
      command as_user_in_app_dir('bundle install')
    end

    execute 'precompile assets' do
      command as_user_in_app_dir('bundle exec rake assets:precompile RAILS_ENV=production')
    end

    execute 'migrate database' do
      command as_user_in_app_dir('bundle exec rake db:migrate RAILS_ENV=production')
    end

    execute 'add PATH to .env' do
      command as_user_in_app_dir('echo PATH=${PATH} >> .env')
    end

    execute 'export foreman scripts' do
      cwd     "#{app_path}/current"
      command "foreman export upstart /etc/init -a #{app_name} -u #{app_user}"
    end
  end

  restart do
    service    app_name do
      provider Chef::Provider::Service::Upstart
      action   :start
      not_if   { File.exist? "#{app_path}/shared/tmp/pids/puma.pid" }
    end

    service app_name do
      provider Chef::Provider::Service::Upstart
      action   :restart
      only_if  { File.exist? "#{app_path}/shared/tmp/pids/puma.pid" }
    end
  end

  action :deploy
  ssh_wrapper "#{user_home}/.ssh/wrap-ssh4git.sh"
end

execute 'take superuser rights away from database user' do
  command postgres_psql("ALTER ROLE #{app_user} NOSUPERUSER")
end

execute 'grant all privileges for database user for database' do
  command postgres_psql("GRANT ALL ON DATABASE #{db_name} TO #{app_user}")
end

include_recipe 'nginx'

template "/etc/nginx/sites-available/#{app_name}" do
  source    'nginx_configuration.erb'
  variables socket_file: "#{app_path}/shared/tmp/sockets/puma.sock",
            app_path:    app_path
end

directory '/etc/nginx/ssl' do
  action :create
end

template '/etc/nginx/ssl/server.key' do
  source    'ssl_key.erb'
  variables ssl_key: ssl_key
end

template '/etc/nginx/ssl/server.crt' do
  source    'ssl_cert.erb'
  variables ssl_cert: ssl_cert
end

nginx_site app_name do
  enable true
end

service 'nginx' do
  action :restart
end
