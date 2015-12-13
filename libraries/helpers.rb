class Chef
  class Resource
    def as_user_in_app_dir(command)
      user     = node['rails_app_server']['user']
      app_name = node['rails_app_server']['name']

      %(su #{user} -l -c "cd #{app_name}/current && #{command}")
    end

    def postgres_psql(command)
      %(sudo -u postgres psql -c "#{command}")
    end
  end
end
