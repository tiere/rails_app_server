# Application
default['rails_app_server']['database']['name']     = nil
default['rails_app_server']['database']['password'] = nil
default['rails_app_server']['name']                 = nil
default['rails_app_server']['repo']                 = nil
default['rails_app_server']['user']                 = nil
default['rails_app_server']['deploy_public_key']    = nil
default['rails_app_server']['deploy_private_key']   = nil
default['rails_app_server']['secret_key_base']      = nil
default['rails_app_server']['attachment_hash']      = nil
default['rails_app_server']['ssl_key']              = nil
default['rails_app_server']['ssl_cert']             = nil
default['rails_app_server']['devise_secret_key']    = nil
default['rails_app_server']['mail_domain']          = nil
default['rails_app_server']['mail_user_name']       = nil
default['rails_app_server']['mail_password']        = nil

# Rbenv and Ruby
default['rbenv']['group_users'] = [node['rails_app_server']['user']]
default['ruby']['version']      = '2.2.3'

# Nginx
default['nginx']['default_site_enabled'] = false
default['nginx']['group']                = node['rails_app_server']['user']
default['nginx']['user']                 = node['rails_app_server']['user']
