require "vagrant/util/retryable"
require "vagrant/util/subprocess"

require "vagrant-lxc/errors"

module Vagrant
  module LXC
    class Driver
      class CLI
        attr_accessor :executor

        class TransitionBlockNotProvided < RuntimeError; end
        class TargetStateNotReached < RuntimeError
          def initialize(target_state, state)
            msg = "Target state '#{target_state}' not reached, currently on '#{state}'"
            super(msg)
          end
        end

        def initialize(executor)
          @executor     = executor
          @logger       = Log4r::Logger.new("vagrant::provider::lxc::container::cli")
        end

        def list
          run(:ls).split(/\s+/).uniq
        end

        def version
          return @version if @version
          @version = support_version_command? ? run(:version) : run(:create, '--version')
          if @version =~ /(lxc version:\s+|)(.+)\s*$/
            @version = $2.downcase
          else
            # TODO: Raise an user friendly error
            raise 'Unable to parse lxc version!'
          end
        end

        def config(param)
          if support_config_command?
            run(:config, param).gsub("\n", '')
          else
            raise Errors::CommandNotSupported, name: 'config', available_version: '> 1.x.x', version: version
          end
        end

        def state(name)
          # TODO: Check if there are calls to this without the argument)
          return :not_created if not (name and list.include? name)
          info = run(:info, '--name', name, retryable: true)
          if info =~ /^state:[^A-Z]+([A-Z]+)$/i
            state = $1.downcase
            # Possible states: "STARTING", "RUNNING", "STOPPING", "STOPPED", "ABORTING", "FREEZING", "FROZEN", "THAWED"
            return state.to_sym if ["RUNNING", "STOPPED", "STARTING", "STOPPING"].map { |s| s.downcase }.include? state
          else
            return :unknown
          end
        end

        def create(params)
          if params[:config_file]
            config_opts = ['-f', params[:config_file]]
          end

          extra = params[:template_opts].to_a.flatten
          extra.unshift '--' unless extra.empty?

          run :create,
              '-B',         params[:backingstore],
              '--template', params[:template],
              '--name',     params[:name],
              *(params[:backingstore_options].to_a.flatten),
              *(config_opts),
              *extra
        rescue Errors::ExecuteError => e
          if e.stderr =~ /already exists/i
            raise Errors::ContainerAlreadyExists, name: params[:name]
          else
            raise
          end
        end

        def destroy(name)
          run :destroy, '--name', name
        end

        def start(name, options = [])
          run :start, '-d', '--name', name, *Array(options)
        end

        def stop(name)
          attach(name, '/sbin/halt') if supports_attach?
          run :stop, '--name', name
        end

        def attach(name, *cmd)
          cmd = ['--'] + cmd

          if cmd.last.is_a?(Hash)
            opts       = cmd.pop
            namespaces = Array(opts[:namespaces]).map(&:upcase).join('|')

            # TODO: Make this work with executor
            # HACK: The wrapper script should be able to handle this
            if @executor.wrapper_path
              namespaces = "'#{namespaces}'"
            end

            if namespaces
              if supports_attach_with_namespaces?
                extra = ['--namespaces', namespaces]
              else
                raise LXC::Errors::NamespacesNotSupported
              end
            end
          end

          run :attach, '--name', name, *((extra || []) + cmd)
        end

        def transition_to(name, target_state, tries = 30, timeout = 1, &block)
          raise TransitionBlockNotProvided unless block_given?

          yield self

          while (last_state = state(name)) != target_state && tries > 0
            @logger.debug "Target state '#{target_state}' not reached, currently on '#{last_state}'"
            sleep timeout
            tries -= 1
          end

          unless last_state == target_state
            # TODO: Raise an user friendly message
            raise TargetStateNotReached.new target_state, last_state
          end
        end

        def supports_attach?(name)
          unless defined?(@supports_attach)
            begin
              @supports_attach = true
              run(:attach, '--name', name, '--', '/bin/true')
            rescue LXC::Errors::ExecuteError
              @supports_attach = false
            end
          end

          return @supports_attach
        end

        def support_config_command?
          version[0].to_i >= 1
        end

        def support_version_command?
          @executor.execute('which', 'lxc-version').strip.chomp != ''
        rescue Vagrant::LXC::Errors::ExecuteError
          return false
        end

        private

        def run(command, *args)
          @executor.run("lxc-#{command}", *args)
        end

        def supports_attach_with_namespaces?
          unless defined?(@supports_attach_with_namespaces)
            @supports_attach_with_namespaces = run(:attach, '-h', :show_stderr => true).values.join.include?('--namespaces')
          end

          return @supports_attach_with_namespaces
        end
      end
    end
  end
end
