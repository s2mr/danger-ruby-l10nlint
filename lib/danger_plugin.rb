# frozen_string_literal: true

require 'shellwords'
require_relative '../ext/l10nlint/l10nlint'

module Danger
  # This is your plugin class. Any attributes or methods you expose here will
  # be available from within your Dangerfile.
  #
  # To be published on the Danger plugins site, you will need to have
  # the public interface documented. Danger uses [YARD](http://yardoc.org/)
  # for generating documentation from your plugin source, and you can verify
  # by running `danger plugins lint` or `bundle exec rake spec`.
  #
  # You should replace these comments with a public description of your library.
  #
  # @example Ensure people are well warned about merging on Mondays
  #
  #          my_plugin.warn_on_mondays
  #
  # @see  Kazumasa Shimomura/danger-l10nlint
  # @tags monday, weekends, time, rattata
  #
  class DangerL10nlint < Plugin
    # The path to L10nLint's execution
    # @return [String] binary_path
    attr_accessor :binary_path

    # The path to L10nLint's configuration file
    # @return [String] config_file
    attr_accessor :config_file

    # Maximum number of issues to be reported.
    # @return [Integer] max_num_violations
    attr_accessor :max_num_violations

    # Provides additional logging diagnostic information.
    # @return [Boolean] verbose
    attr_accessor :verbose

    # Whether we should fail on warnings
    # @return [Boolean] strict
    attr_accessor :strict

    # Warnings found
    # @return [Array<Hash>] warnings
    attr_accessor :warnings

    # Errors found
    # @return [Array<Hash>] errors
    attr_accessor :errors

    # All issues found
    # @return [Array<Hash>] issues
    attr_accessor :issues

    # Rules for not wanting to make inline comments
    # @return [Array<String>] rule identifiers
    attr_accessor :inline_except_rules

    # Lints Localizable.strings
    # @return [void]
    #
    def lint_files(inline_mode: false, fail_on_error: false, additional_l10nlint_args: '')
      raise 'l10nlint is not installed' unless l10nlint.installed?

      config_file_path = config_file
      if config_file_path
        log "Using config file: #{config_file_path}"
      else
        log 'config file was not specified'
      end

      # Prepare l10nlint options
      options = {
        # Make sure we don't fail when config path has spaces
        config: config_file_path ? Shellwords.escape(config_file_path) : nil,
        reporter: 'json'
      }

      log "linting with options: #{options}"

      issues = run_l10nlint(options, additional_l10nlint_args)

      @issues = issues
      other_issues_count = 0
      unless @max_num_violations.nil? || no_comment
        other_issues_count = issues.count - @max_num_violations if issues.count > @max_num_violations
        issues = issues.take(@max_num_violations)
      end

      log "Received issues from L10nLint: #{issues.count}"

      # Filter warnings and errors
      @warnings = issues.select { |issue| issue['severity'] == 'warning' }
      @errors = issues.select { |issue| issue['severity'] == 'error' }

      if inline_mode
        # Separate each warnings and errors by inline_except_rules
        if inline_except_rules
          markdown_warnings = warnings.select { |issue| inline_except_rules.include?(issue['ruleIdentifier']) }
          inline_warnings = warnings - markdown_warnings
          markdown_errors = @errors.select { |issue| inline_except_rules.include?(issue['ruleIdentifier']) }
          inline_errors = @errors - markdown_errors
        end

        # Report with inline comment
        send_inline_comment(inline_warnings, strict ? :fail : :warn)
        send_inline_comment(inline_errors, (fail_on_error || strict) ? :fail : :warn)

        if markdown_warnings.count > 0 || markdown_errors.count > 0
          message = "### L10nLint found issues\n\n".dup
          message << markdown_issues(markdown_warnings, 'Warnings') unless markdown_warnings.empty?
          message << markdown_issues(markdown_errors, 'Errors') unless markdown_errors.empty?
          markdown message
        end

        warn other_issues_message(other_issues_count) if other_issues_count > 0

      elsif warnings.count > 0 || errors.count > 0
        # Report if any warning or error
        message = "### L10nLint found issues\n\n".dup
        message << markdown_issues(warnings, 'Warnings') unless warnings.empty?
        message << markdown_issues(errors, 'Errors') unless errors.empty?
        message << "\n#{other_issues_message(other_issues_count)}" if other_issues_count > 0
        markdown message

        # Fail danger on errors
        should_fail_by_errors = fail_on_error && errors.count > 0
        # Fail danger if any warnings or errors and we are strict
        should_fail_by_strict = strict && (errors.count > 0 || warnings.count > 0)
        if should_fail_by_errors || should_fail_by_strict
          fail 'Failed due to L10nLint errors'
        end
      end
    end

    # Make L10nLint object for binary_path
    #
    # @return [L10nLint]
    def l10nlint
      L10nLint.new(binary_path)
    end

    def log(text)
      puts text if @verbose
    end

    # Run l10nlint on all files and returns the issues
    #
    # @return [Array] l10nlint issues
    def run_l10nlint(options, additional_l10nlint_args)
      result = l10nlint.lint(options, additional_l10nlint_args)
      if result == ''
        {}
      else
        JSON.parse(result)
      end
    end

    # Create a markdown table from l10nlint issues
    #
    # @return  [String]
    def markdown_issues(results, heading)
      message = "#### #{heading}\n\n".dup

      message << "File | Line | Reason |\n"
      message << "| --- | ----- | ----- |\n"

      results.each do |r|
        filename = r['location']['file'].split('/').last(2).join("/")
        line = r['location']['line']
        reason = r['reason']
        rule = r['ruleIdentifier']
        # Other available properties can be found int L10nLint/…/JSONReporter.swift
        message << "#{filename} | #{line} | #{reason} (#{rule})\n"
      end

      message
    end

    # Send inline comment with danger's warn or fail method
    #
    # @return [void]
    def send_inline_comment(results, method)
      dir = "#{Dir.pwd}/"
      results.each do |r|
        github_filename = r['location']['file'].gsub(dir, '')
        message = "#{r['reason']}".dup

        # extended content here
        filename = r['location']['file'].split('/').last(2).join("/")
        message << "\n"
        message << "`#{r['ruleIdentifier']}`"
        message << " `#{filename}:#{r['location']['line']}`" # file:line for pasting into Xcode Quick Open

        send(method, message, file: github_filename, line: r['location']['line'])
      end
    end

    def other_issues_message(issues_count)
      violations = issues_count == 1 ? 'violation' : 'violations'
      "L10nLint also found #{issues_count} more #{violations} with this PR."
    end
  end
end
