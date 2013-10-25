module Vagrant
  module LXC
    module Action
      class Create
        def initialize(app, env)
          @app = app
        end

        def call(env)

          config = env[:machine].provider_config

          # example Vagrantfile snippit:
          #config.create_clone = true
          #config.existing_container = "foobar"
          #config.new_container_name = "bazlol"

          if config.create_clone

            existing_container_name = config.existing_container
            new_container_name      = config.new_container_name

            # fail here if we don't have the required params
            unless existing_container_name && new_container_name
              env[:ui].error "You must specify both an 'existing_container' and a 'new_container_name'!"
              exit
            end

            # ensure the container is shut down before we clone it
            if env[:machine].provider.state.id == :running
              env[:ui].info I18n.t("vagrant_lxc.messages.force_shutdown")
              env[:machine].provider.driver.forced_halt
            end

            env[:machine].provider.driver.clone(existing_container_name, new_container_name)
            env[:machine].id = existing_container_name
            @app.call env
          end

          container_name = "#{env[:root_path].basename.to_s}_#{env[:machine].name}"
          container_name.gsub!(/[^-a-z0-9_]/i, "")
          container_name << "-#{Time.now.to_i}"

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
