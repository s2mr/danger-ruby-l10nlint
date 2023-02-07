# frozen_string_literal: true

class L10nLint
  def initialize(l10nlint_path = nil)
    @l10nlint_path = l10nlint_path
  end

  def installed?
    File.exist?(l10nlint_path)
  end

  def l10nlint_path
    @l10nlint_path || default_l10nlint_path
  end

  def default_l10nlint_path
    File.expand_path(File.join(File.dirname(__FILE__), 'bin', 'l10nlint'))
  end

  # Shortcut for running the lint command
  def lint(options, additional_l10nlint_args, env = nil)
    run('lint', additional_l10nlint_args, options, env)
  end

  def run(cmd = 'lint', additional_l10nlint_args = '', options = {}, env = nil)
    # allow for temporary change to pwd before running l10nlint
    pwd = options.delete(:pwd)
    command = "#{l10nlint_path} #{cmd} #{l10nlint_arguments(options, additional_l10nlint_args)}"

    # Add `env` to environment
    update_env(env)
    begin
      # run l10nlint with provided options
      if pwd
        Dir.chdir(pwd) do
          `#{command}`
        end
      else
        `#{command}`
      end
    ensure
      # Remove any ENV variables we might have added
      restore_env()
    end
  end

  # Parse options into shell arguments how swift expect it to be
  # more information: https://github.com/Carthage/Commandant
  # @param options (Hash) hash containing l10nlint options
  def l10nlint_arguments(options, additional_l10nlint_args)
    (options.
      # filter not null
      reject { |_key, value| value.nil? }.
      # map booleans arguments equal true
      map { |key, value| value.is_a?(TrueClass) ? [key, ''] : [key, value] }.
      # map booleans arguments equal false
      map { |key, value| value.is_a?(FalseClass) ? ["no-#{key}", ''] : [key, value] }.
      # replace underscore by hyphen
      map { |key, value| [key.to_s.tr('_', '-'), value] }.
      # prepend '--' into the argument
      map { |key, value| ["--#{key}", value] }.
      # reduce everything into a single string
      reduce('') { |args, option| "#{args} #{option[0]} #{option[1]}" } +
      " #{additional_l10nlint_args}").
      # strip leading spaces
      strip
  end

  # Adds `env` to shell environment as variables
  # @param env (Hash) hash containing environment variables to add
  def update_env(env)
    return if !env || env.empty?
    # Keep the same @original_env if we've already set it, since that would mean
    # that we're adding more variables, in which case, we want to make sure to
    # keep the true original when we go to restore it.
    @original_env = ENV.to_h if @original_env.nil?
    # Add `env` to environment
    ENV.update(env)
  end

  # Restores shell environment to values in `@original_env`
  # All environment variables not in `@original_env` will be removed
  def restore_env()
    if !@original_env.nil?
      ENV.replace(@original_env)
      @original_env = nil
    end
  end
end