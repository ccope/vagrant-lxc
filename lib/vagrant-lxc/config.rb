module Vagrant
  module LXC
    class Config < Vagrant.plugin("2", :config)
      # An array of container's configuration overrides to be provided to `lxc-start`.
      #
      # @return [Array]
      attr_reader :customizations

      # A string that contains the backing store type used with lxc-create -B
      attr_accessor :backingstore

      # Optional arguments for the backing store, such as --fssize, --fstype, ...
      #
      # @return [Array]
      attr_accessor :backingstore_options

      # A string to explicitly set the container name. To use the vagrant
      # machine name, set this to :machine
      attr_accessor :container_name

      # Force using a proxy VM, even on Linux hosts.
      #
      # @return [Boolean]
      attr_accessor :force_host_vm

      # The directory with an lxc container configuration file
      # for this container.
      #
      # @return [String]
      attr_accessor :config_dir

      # Options for the config dir synced folder if a host VM is in use.
      #
      # @return [Hash]
      attr_accessor :host_vm_config_dir_options

      # The name of the machine in the Vagrantfile set with
      # "vagrant_vagrantfile" that will be the LXC host. Defaults
      # to "default"
      #
      # See the "vagrant_vagrantfile" docs for more info.
      #
      # @return [String]
      attr_accessor :vagrant_machine

      # The path to the Vagrantfile that contains a VM that will be
      # started as the Docker host if needed (Windows, OS X, Linux
      # without container support).
      #
      # Defaults to a built-in Vagrantfile that will load the proxy vm.
      #
      # NOTE: This only has an effect if Vagrant needs an LXC host.
      # Vagrant determines this automatically based on the environment
      # it is running in.
      #
      # @return [String]
      attr_accessor :vagrant_vagrantfile

      def initialize
        @backingstore = UNSET_VALUE
        @backingstore_options = []
        @config_dir = UNSET_VALUE
        @container_name = UNSET_VALUE
        @customizations = []
        @force_host_vm = UNSET_VALUE
        @host_vm_build_dir_options = UNSET_VALUE
        @sudo_wrapper   = UNSET_VALUE
        @vagrant_machine = UNSET_VALUE
        @vagrant_vagrantfile = UNSET_VALUE
      end

      # Customize the container by calling `lxc-start` with the given
      # configuration overrides.
      #
      # For example, if you want to set the memory limit, you can use it
      # like: config.customize 'cgroup.memory.limit_in_bytes', '400M'
      #
      # When `lxc-start`ing the container, vagrant-lxc will pass in
      # "-s lxc.cgroup.memory.limit_in_bytes=400M" to it.
      #
      # @param [String] key Configuration key to override
      # @param [String] value Configuration value to override
      def customize(key, value)
        @customizations << [key, value]
      end

      # Stores options for backingstores like lvm, btrfs, etc
      def backingstore_option(key, value)
        @backingstore_options << [key, value]
      end

      def finalize!
        @backingstore = "best" if @backingstore == UNSET_VALUE
        @container_name = nil if @container_name == UNSET_VALUE
        @config_dir = nil if @config_dir == UNSET_VALUE
        @existing_container_name = nil if @existing_container_name == UNSET_VALUE
        @force_host_vm = false if @force_host_vm == UNSET_VALUE
        @host_vm_build_dir_options = nil if @host_vm_build_dir_options == UNSET_VALUE
        @sudo_wrapper = nil if @sudo_wrapper == UNSET_VALUE
        @vagrant_machine = nil if @vagrant_machine == UNSET_VALUE
        @vagrant_vagrantfile = nil if @vagrant_machine == UNSET_VALUE
        # The machine name must be a symbol
        @vagrant_machine = @vagrant_machine.to_sym if @vagrant_machine
      end

      def validate(machine)
        errors = _detected_errors

        if @config_dir
          config_dir_pn = Pathname.new(@config_dir)
          if !config_dir_pn.directory?
            errors << I18n.t("lxc.errors.config.config_dir_invalid")
          end
        end

        if @vagrant_vagrantfile
          vf_pn = Pathname.new(@vagrant_vagrantfile)
          if !vf_pn.file?
            errors << I18n.t("lxc.errors.config.invalid_vagrantfile")
          end
        end

        { "lxc provider" => errors }
      end

    end
  end
end
