module Vagrant
  module LXC
    class Config < Vagrant.plugin("2", :config)
      # An array of container's configuration overrides to be provided to `lxc-start`.
      #
      # @return [Array]
      attr_reader :customizations

      # custom code to pass user-specified options to lxc-create
      attr_reader :lxc_template_options

      # A String that points to a file that acts as a wrapper for sudo commands.
      #
      # This allows us to have a single entry when whitelisting NOPASSWD commands
      # on /etc/sudoers
      attr_accessor :sudo_wrapper

      # A String that names the container to clone from
      attr_accessor :existing_container_name

      # A String that forces an explicit name
      attr_accessor :explicit_name

      def initialize
        @existing_container_name = UNSET_VALUE
        @customizations = []
        @lxc_template_options = []
        @sudo_wrapper   = UNSET_VALUE
        @explicit_name = UNSET_VALUE
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

      # custom code to add support for lvm
      def lxc_create_options(key, value)
        @lxc_template_options << [key, value]
      end

      def finalize!
        @sudo_wrapper = nil if @sudo_wrapper == UNSET_VALUE
        @existing_container_name = nil if @existing_container_name == UNSET_VALUE
        @explicit_name = nil if @explicit_name == UNSET_VALUE
      end

      def validate(machine)
        errors = []

        if @sudo_wrapper
          hostpath = Pathname.new(@sudo_wrapper).expand_path(machine.env.root_path)
          if ! hostpath.file?
            errors << I18n.t('vagrant_lxc.sudo_wrapper_not_found', path: hostpath.to_s)
          elsif ! hostpath.executable?
            errors << I18n.t('vagrant_lxc.sudo_wrapper_not_executable', path: hostpath.to_s)
          end
        end

        { "lxc provider" => errors }
      end
    end
  end
end
