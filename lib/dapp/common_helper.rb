module Dapp
  # CommonHelper
  module CommonHelper
    def log(message = '')
      return unless defined? cli_options
      puts message.to_s.lines.map { |line| ' ' * 2 * cli_options[:log_indent].to_i + line }.join unless cli_options[:log_quiet]
    end

    def log_with_indent(message = '')
      with_log_indent do
        log(message)
      end
    end

    def with_log_indent(with = true)
      log_indent_next if with
      yield
      log_indent_prev if with
    end

    def log_indent_next
      return unless defined? cli_options
      cli_options[:log_indent] += 1
    end

    def log_indent_prev
      return unless defined? cli_options
      if cli_options[:log_indent] <= 0
        cli_options[:log_indent] = 0
      else
        cli_options[:log_indent] -= 1
      end
    end

    def shellout(*args, log_verbose: false, **kwargs)
      do_shellout = proc do
        log_verbose = (log_verbose && cli_options[:log_verbose]) if defined? cli_options
        kwargs[:live_stream] = STDOUT if log_verbose
        Mixlib::ShellOut.new(*args, timeout: 3600, **kwargs).run_command
      end

      if defined? ::Bundler
        ::Bundler.with_clean_env { do_shellout.call }
      else
        do_shellout.call
      end
    end

    def shellout!(*args, **kwargs)
      shellout(*args, **kwargs).tap(&:error!)
    end

    def hashsum(arg)
      sha256(arg)
    end

    def sha256(arg)
      Digest::SHA256.hexdigest Array(arg).compact.map(&:to_s).join(':::')
    end

    def kwargs(args)
      args.last.is_a?(Hash) ? args.pop : {}
    end

    def delete_file(path)
      path = Pathname(path)
      path.delete if path.exist?
    end

    def to_mb(bytes)
      (bytes / 1024.0 / 1024.0).round(2)
    end

    def error!(*args)
      raise(::Dapp::Error, *args)
    end

    def self.included(base)
      base.extend(self)
    end
  end # CommonHelper
end # Dapp
