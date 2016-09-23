module Dapp
  # Project
  class Project
    module Shellout
      # System
      module System
        SYSTEM_SHELLOUT_IMAGE = 'ubuntu:14.04'.freeze
        SYSTEM_SHELLOUT_VERSION = 2

        def system_shellout_container_name
          "dapp_system_shellout_#{hashsum [SYSTEM_SHELLOUT_VERSION,
                                           SYSTEM_SHELLOUT_IMAGE,
                                           Deps::Gitartifact::GITARTIFACT_IMAGE,
                                           Deps::Base::BASE_VERSION]}"
        end

        def system_shellout_container
          @system_shellout_container ||= begin
            lock(system_shellout_container_name) do
              if shellout("docker inspect #{system_shellout_container_name}").exitstatus.nonzero?
                volumes_from = [base_container, gitartifact_container]
                log_secondary_process(t(code: 'process.system_shellout_container_loading'), short: true) do
                  shellout! ['docker run --detach --privileged', '--restart always',
                             "--name #{system_shellout_container_name}",
                             *volumes_from.map { |container| "--volumes-from #{container}" },
                             '--volume /:/.system_shellout_root',
                             "#{SYSTEM_SHELLOUT_IMAGE} #{bash_path} -ec 'while true ; do sleep 1 ; done'"].join(' ')

                  shellout! ["docker exec #{system_shellout_container_name}",
                             "bash -ec '#{[
                               'mkdir -p /.system_shellout_root/.dapp',
                               'mount --rbind /.dapp /.system_shellout_root/.dapp'
                             ].join(' && ')}'"].join(' ')
                end
              end
            end

            system_shellout_container_name
          end
        end

        def system_shellout(command, **kwargs)
          shellout _to_system_shellout_command(command), **kwargs
        end

        def system_shellout!(command, **kwargs)
          shellout! _to_system_shellout_command(command), **kwargs
        end

        private

        def _to_system_shellout_command(command)
          cmd = shellout_pack ["cd #{Dir.pwd}", command].join(' && ')
          "docker exec #{system_shellout_container} chroot /.system_shellout_root bash -ec '#{[
            *System.default_env_keys.map do |env_key|
              env_key = env_key.to_s.upcase
              "export #{env_key}=#{ENV[env_key]}"
            end, cmd
          ].join(' && ')}'"
        end

        public

        class << self
          def default_env_keys
            @default_env_keys ||= []
          end
        end # << self
      end # System
    end
  end # Project
end # Dapp
