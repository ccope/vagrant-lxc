module Vagrant
  module LXC
    module Action
      class Create
        def initialize(app, env)
          @app = app
        end

        def call(env)
          @env             = env
          @machine         = env[:machine]
          @provider_config = @machine.provider_config
          @machine_config  = @machine.config
          @driver          = @machine.provider.driver

          params = create_params

          @driver.create(params)
          @machine.id = container_name

          @app.call env
        end

        def create_params
          container_name = @provider_config.container_name
          if !container_name
            container_name = "#{@env[:root_path].basename.to_s}_#{@machine.name}"
            container_name.gsub!(/[^-a-z0-9_]/i, "")

            # milliseconds + random number suffix to allow for simultaneous
            # `vagrant up` of the same box in different dirs
            container_name << "_#{(Time.now.to_f * 1000.0).to_i}_#{rand(100000)}"

            # Trim container name to 64 chars, keeping "randomness"
            trim_point = container_name.size > 64 ? -64 : -(container_name.size)
            container_name.slice!(0..trim_point-1)
          end

          {
            env:                  @provider_config.env,
            hostname:             @machine_config.vm.hostname,
            name:                 container_name,
            backingstore:         @provider_config.backingstore,
            backingstore_options: @provider_config.backingstore_options,
            template_config:      @env[:lxc_template_config],
            template_opts:        @env[:lxc_template_opts],
            template_src:         @env[:lxc_template_src],
            #ports:               forwarded_ports(@provider_config.has_ssh),
            # TODO: Support unprivileged containers
            #privileged:          @provider_config.privileged,
          }
        end
      end
    end
  end
end
