module Vagrant
  module LXC
    module Action
      class Create
        def initialize(app, env)
          @app = app
        end

        def call(env)

          config = env[:machine].provider_config

          container_name = "#{env[:root_path].basename.to_s}_#{env[:machine].name}"
          container_name.gsub!(/[^-a-z0-9_]/i, "")
          container_name << "-#{Time.now.to_i}"

          # example Vagrantfile snippit:
          #config.create_clone = true
          #config.existing_container = "foobar"
          #config.new_container_name = "bazlol"

          if config.existing_container_name

            existing_container_name = config.existing_container
            env[:machine].provider.driver.clone(existing_container_name, container_name)
            env[:machine].id = container_name
            @app.call env
          end

          env[:machine].provider.driver.create(
            container_name,
            config.lxc_template_options,
            env[:lxc_template_src],
            env[:lxc_template_config],
            env[:lxc_template_opts]
          )

          env[:machine].id = container_name

          @app.call env
        end
      end
    end
  end
end
