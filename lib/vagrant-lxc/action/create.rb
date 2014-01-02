module Vagrant
  module LXC
    module Action
      class Create
        def initialize(app, env)
          @app = app
        end

        def call(env)
          config = env[:machine].provider_config

          container_name = "#{env[:root_path].basename}_#{env[:machine].name}"
          container_name.gsub!(/[^-a-z0-9_]/i, "")
          container_name << "-#{Time.now.to_i}"

          if config.existing_container_name
            env[:machine].provider.driver.clone(config.existing_container_name, container_name)
          else
            env[:machine].provider.driver.create(
              container_name,
              config.backingstore,
              config.backingstore_options,
              env[:lxc_template_src],
              env[:lxc_template_config],
              env[:lxc_template_opts])
          end

          env[:machine].id = container_name

          @app.call env
        end
      end
    end
  end
end
