# frozen_string_literal: true

require File.expand_path("spec_helper", __dir__)

module Danger
  describe Danger::DangerL10nLint do
    it "should be a plugin" do
      expect(Danger::DangerL10nLint.new(nil)).to be_a Danger::Plugin
    end

    #
    # You should test your custom attributes and methods here
    #
    describe "with Dangerfile" do
      before do
        @dangerfile = testing_dangerfile
        @l10nlint = @dangerfile.l10nlint

        # mock the PR data
        # you can then use this, eg. github.pr_author, later in the spec
        json = File.read("#{File.dirname(__FILE__)}/support/fixtures/github_pr.json") # example json: `curl https://api.github.com/repos/danger/danger-plugin-template/pulls/18 > github_pr.json`
        allow(@l10nlint.github).to receive(:pr_json).and_return(json)
      end

      it 'handles l10nlint not being installed' do
        allow_any_instance_of(L10nLint).to receive(:installed?).and_return(false)
        expect { @l10nlint.lint_files }.to raise_error('l10nlint is not installed')
      end
    end
  end
end