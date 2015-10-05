module Vagrant
  module LXC
    module Action
      # Shortcuts
      Builtin = Vagrant::Action::Builtin
      Builder = Vagrant::Action::Builder

      # This action is responsible for reloading the machine, which
      # brings it down, sucks in new configuration, and brings the
      # machine back up with the new configuration.
      def self.action_reload
        Builder.new.tap do |b|
          b.use Builtin::Call, Builtin::IsState, :not_created do |env1, b2|
            if env1[:result]
              b2.use Builtin::Message, I18n.t("vagrant_lxc.messages.not_created")
              next
            end

            b2.use Builtin::ConfigValidate
            b2.use action_halt
            b2.use action_start
          end
        end
      end

      # This action boots the VM, assuming the VM is in a state that requires
      # a bootup (i.e. not saved).
      def self.action_boot
        Builder.new.tap do |b|
          b.use Builtin::Provision
          b.use Builtin::EnvSet, :port_collision_repair => true
          b.use Builtin::HandleForwardedPortCollisions
          b.use PrepareNFSValidIds
          b.use Builtin::SyncedFolderCleanup
          b.use Builtin::SyncedFolders
          b.use PrepareNFSSettings
          b.use Builtin::SetHostname
          b.use WarnNetworks
          b.use ForwardPorts
          b.use PrivateNetworks
          b.use Boot
          b.use Builtin::WaitForCommunicator
        end
      end

      # This action just runs the provisioners on the machine.
      def self.action_provision
        Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::Call, Builtin::IsState, :not_created do |env1, b2|
            if env1[:result]
              b2.use Builtin::Message, I18n.t("vagrant_lxc.messages.not_created")
              next
            end

            b2.use Builtin::Call, Builtin::IsState, :running do |env2, b3|
              if !env2[:result]
                b3.use Builtin::Message, I18n.t("vagrant_lxc.messages.not_running")
                next
              end

              b3.use Builtin::Provision
            end
          end
        end
      end

      # This action starts a container, assuming it is already created and exists.
      # A precondition of this action is that the container exists.
      def self.action_start
        Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::BoxCheckOutdated
          b.use Builtin::Call, Builtin::IsState, :running do |env, b2|
            # If the VM is running, then our work here is done, exit
            next if env[:result]
            b2.use action_boot
          end
        end
      end

      # This action brings the machine up from nothing, including creating the
      # container, configuring metadata, and booting.
      def self.action_up
        Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::Call, Builtin::IsState, :not_created do |env, b2|
            # If the VM is NOT created yet, then do the setup steps
            if env[:result]
              b2.use Builtin::HandleBox
              b2.use HandleBoxMetadata
              b2.use Create
            end
          end
          b.use action_start
        end
      end

      # This is the action that is primarily responsible for halting
      # the virtual machine, gracefully or by force.
      def self.action_halt
        Builder.new.tap do |b|
          b.use Builtin::Call, Builtin::IsState, :not_created do |env, b2|
            if env[:result]
              b2.use Builtin::Message, I18n.t("vagrant_lxc.messages.not_created")
              next
            end

            b2.use ClearForwardedPorts
            b2.use GcPrivateNetworkBridges
            b2.use Builtin::Call, Builtin::GracefulHalt, :stopped, :running do |env2, b3|
              if !env2[:result]
                b3.use ForcedHalt
              end
            end
          end
        end
      end

      # This is the action that is primarily responsible for completely
      # freeing the resources of the underlying virtual machine.
      def self.action_destroy
        Builder.new.tap do |b|
          b.use Builtin::Call, Builtin::IsState, :not_created do |env1, b2|
            if env1[:result]
              b2.use Builtin::Message, I18n.t("vagrant_lxc.messages.not_created")
              next
            end

            b2.use Builtin::Call, DestroyConfirm do |env2, b3|
              if env2[:result]
                b3.use Builtin::ConfigValidate
                b3.use Builtin::EnvSet, :force_halt => true
                b3.use action_halt
                b3.use Destroy
                b3.use Builtin::ProvisionerCleanup
              else
                b3.use Builtin::Message, I18n.t("vagrant_lxc.messages.will_not_destroy")
              end
            end
          end
        end
      end

      # This action packages the virtual machine into a single box file.
      def self.action_package
        Builder.new.tap do |b|
          b.use Builtin::Call, Builtin::IsState, :not_created do |env1, b2|
            if env1[:result]
              b2.use Builtin::Message, I18n.t("vagrant_lxc.messages.not_created")
              next
            end

            b2.use action_halt
            b2.use CompressRootFS
            b2.use SetupPackageFiles
            b2.use Vagrant::Action::General::Package
          end
        end
      end

      # This action is called to read the IP of the container. The IP found
      # is expected to be put into the `:machine_ip` key.
      def self.action_ssh_ip
        Builder.new.tap do |b|
          b.use Builtin::Call, Builtin::ConfigValidate do |env, b2|
            b2.use FetchIpWithLxcAttach if env[:machine].provider.driver.supports_attach?
            b2.use FetchIpFromDnsmasqLeases
          end
        end
      end

      # This is the action that will exec into an SSH shell.
      def self.action_ssh
        Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::Call, Builtin::IsState, :not_created do |env, b2|
            if env[:result]
              b2.use Builtin::Message, I18n.t("vagrant_lxc.messages.not_created")
              next
            end

            b2.use Builtin::Call, Builtin::IsState, :running do |env1, b3|
              if !env1[:result]
                b3.use Builtin::Message, I18n.t("vagrant_lxc.messages.not_running")
                next
              end

              b3.use Builtin::SSHExec
            end
          end
        end
      end

      # This is the action that will run a single SSH command.
      def self.action_ssh_run
        Builder.new.tap do |b|
          b.use Builtin::ConfigValidate
          b.use Builtin::Call, Builtin::IsState, :not_created do |env, b2|
            if env[:result]
              b2.use Builtin::Message, I18n.t("vagrant_lxc.messages.not_created")
              next
            end

            b2.use Builtin::Call, Builtin::IsState, :running do |env1, b3|
              if !env1[:result]
                raise Vagrant::Errors::VMNotRunningError
                next
              end

              b3.use Builtin::SSHRun
            end
          end
        end
      end

      # The autoload farm
      action_root = Pathname.new(File.expand_path("../action", __FILE__))
      autoload :Boot, action_root.join('boot')
      autoload :ClearForwardedPorts, action_root.join('clear_forwarded_ports')
      autoload :CompareSyncedFolders, action_root.join("compare_synced_folders")
      autoload :Create, action_root.join('create')
      autoload :Destroy, action_root.join('destroy')
      autoload :DestroyConfirm, action_root.join('destroy_confirm')
      autoload :CompressRootFS, action_root.join('compress_rootfs')
      autoload :FetchIpWithLxcAttach, action_root.join('fetch_ip_with_lxc_attach')
      autoload :FetchIpFromDnsmasqLeases, action_root.join('fetch_ip_from_dnsmasq_leases')
      autoload :ForcedHalt, action_root.join('forced_halt')
      autoload :ForwardedPorts, action_root.join('forward_ports')
      autoload :GcPrivateNetworkBridges, action_root.join('gc_private_network_bridges')
      autoload :HandleBoxMetadata, action_root.join('handle_box_metadata')
      autoload :HostMachine, action_root.join("host_machine")
      autoload :HostMachineConfigDir, action_root.join("host_machine_config_dir")
      autoload :HostMachineRequired, action_root.join("host_machine_required")
      autoload :HostMachineSyncFolders, action_root.join("host_machine_sync_folders")
      autoload :HostMachineSyncFoldersDisable, action_root.join("host_machine_sync_folders_disable")
      autoload :InitState, action_root.join("init_state")
      autoload :IsHostMachineCreated, action_root.join("is_host_machine_created")
      autoload :PrepareNFSSettings, action_root.join('prepare_nfs_settings')
      autoload :PrepareNFSValidIds, action_root.join('prepare_nfs_valid_ids')
      autoload :PrivateNetworks, action_root.join('private_networks')
      autoload :SetupPackageFiles, action_root.join('setup_package_files')
      autoload :WarnNetworks, action_root.join('warn_networks')

    end
  end
end
