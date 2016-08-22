module Dapp
  # Application
  class Application
    include Helper::Log
    include Helper::Shellout
    include Helper::I18n
    include Helper::Sha256
    include Logging
    include GitArtifact
    include Path
    include Tags

    attr_reader :config
    attr_reader :cli_options
    attr_reader :ignore_git_fetch
    attr_reader :is_artifact
    attr_reader :project

    def initialize(config:, project:, cli_options:, ignore_git_fetch: false, is_artifact: false)
      @config = config
      @project = project
      @cli_options = cli_options

      @tmp_path = Dir.mktmpdir(cli_options[:tmp_dir_prefix] || 'dapp-')

      @last_stage = Build::Stage::DockerInstructions.new(self)
      @ignore_git_fetch = ignore_git_fetch
      @is_artifact = is_artifact
    end

    def build!
      with_introspection do
        project.lock("#{config._basename}.images", shared: true) do
          last_stage.build_lock! do
            last_stage.build!
            last_stage.save_in_cache!
          end
        end
      end
    ensure
      FileUtils.rm_rf(tmp_path)
    end

    def export!(repo, format:)
      raise Error::Application, code: :application_not_built unless last_stage.image.tagged? || dry_run?

      project.lock("#{config._basename}.images", shared: true) do
        tags.each do |tag|
          image_name = format % { repo: repo, application_name: config._name, tag: tag }
          if dry_run?
            log_state(image_name, state: t(code: 'state.push'), styles: { status: :success })
          else
            project.lock("image.#{image_name.gsub('/', '__')}") do
              Dapp::Image::Stage.cache_reset(image_name)
              log_process(image_name, process: t(code: 'status.process.pushing')) do
                last_stage.image.export!(image_name, log_verbose: log_verbose?,
                                                     log_time: log_time?,
                                                     force: cli_options[:force])
              end
            end
          end
        end
      end
    end

    def run(docker_options, command)
      raise Error::Application, code: :application_not_built unless last_stage.image.tagged?
      cmd = "docker run #{[docker_options, last_stage.image.name, command].flatten.compact.join(' ')}"
      if dry_run?
        log_info(cmd)
      else
        system(cmd) || raise(Error::Application, code: :application_not_run)
      end
    end

    def signature
      last_stage.send(:signature)
    end

    def stage_cache_format
      "#{project.cache_format % { application_name: config._basename }}:%{signature}"
    end

    def stage_dapp_label
      project.stage_dapp_label_format % { application_name: config._basename }
    end

    def builder
      @builder ||= Builder.const_get(config._builder.capitalize).new(self)
    end

    protected

    def with_introspection
      yield
    rescue Exception::IntrospectImage => e
      data = e.net_status[:data]
      cmd = "docker run -ti --rm --entrypoint /bin/bash #{data[:options]} #{data[:built_id]}"
      system(cmd).tap do |res|
        shellout!("docker rmi #{data[:built_id]}") if data[:rmi]
        res || raise(Error::Application, code: :application_not_run)
      end
      exit 0
    end

    attr_reader :last_stage
  end # Application
end # Dapp
