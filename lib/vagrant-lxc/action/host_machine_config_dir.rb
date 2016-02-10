require "digest/md5"

require "log4r"

module Vagrant
  module LXC
    module Action
      class HostMachineConfigDir
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::lxc::hostmachineconfigdir")
        end

        def call(env)
          machine   = env[:machine]

          # If we're not on a host VM, we're done
          return @app.call(env) if !machine.provider.host_vm?

          config_dir = machine.provider_config.config_dir
          config_dir = File.expand_path(config_dir, env[:machine].env.root_path)
          env[:config_dir] = config_dir

          # We're on a host VM, so we need to move our build dir to
          # that machine. We do this by putting the synced folder on
          # ourself and letting HostMachineSyncFolders handle it.
          new_config_dir = "/var/lib/lxc/lxc_synced_#{Digest::MD5.hexdigest(config_dir)}"
          options       = {
            lxc__ignore: true,
            lxc__exact: true,
          }.merge(machine.provider_config.host_vm_config_dir_options || {})
          machine.config.vm.synced_folder(config_dir, new_config_dir, options)

          # Set the build dir to be the correct one
          env[:config_dir] = new_config_dir

          @app.call(env)
        end
      end
    end
  end
end
