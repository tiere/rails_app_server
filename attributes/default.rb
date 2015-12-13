# Application
default['rails_app_server']['database']['name'] = nil
default['rails_app_server']['name']             = nil
default['rails_app_server']['repo']             = nil
default['rails_app_server']['user']             = nil

# Rbenv and Ruby
default['rbenv']['group_users'] = [node['rails_app_server']['user']]
default['ruby']['version']      = '2.2.3'

# Nginx
default['nginx']['default_site_enabled'] = false
default['nginx']['group']                = node['rails_app_server']['user']
default['nginx']['user']                 = node['rails_app_server']['user']
