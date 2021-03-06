require File.expand_path('../spec_helper', __FILE__)

module Danger
  describe DangerRubocop do
    it 'is a plugin' do
      expect(Danger::DangerRubocop < Danger::Plugin).to be_truthy
    end

    describe 'with Dangerfile' do
      before do
        @dangerfile = testing_dangerfile
        @rubocop = testing_dangerfile.rubocop
      end

      describe :lint_files do
        let(:response_ruby_file) do
          {
            'files' => [
              {
                'path' => 'spec/fixtures/ruby_file.rb',
                'offenses' => [
                  {
                    'message' => "Don't do that!",
                    'location' => { 'line' => 13 }
                  }
                ]
              }
            ]
          }.to_json
        end

        let(:response_another_ruby_file) do
          {
            'files' => [
              {
                'path' => 'spec/fixtures/another_ruby_file.rb',
                'offenses' => [
                  {
                    'message' => "Don't do that!",
                    'location' => { 'line' => 23 }
                  }
                ]
              }
            ]
          }.to_json
        end

        it 'handles a rubocop report for specified files' do
          allow(@rubocop).to receive(:`)
            .with('bundle exec rubocop -f json spec/fixtures/ruby_file.rb')
            .and_return(response_ruby_file)

          # Do it
          @rubocop.lint(files: 'spec/fixtures/ruby*.rb')

          output = @rubocop.status_report[:markdowns].first.message

          # A title
          expect(output).to include('Rubocop violations')
          # A warning
          expect(output).to include("spec/fixtures/ruby_file.rb | 13   | Don't do that!")
        end

        it 'handles a rubocop report for specified files (legacy)' do
          allow(@rubocop).to receive(:`)
            .with('bundle exec rubocop -f json spec/fixtures/ruby_file.rb')
            .and_return(response_ruby_file)

          # Do it
          @rubocop.lint('spec/fixtures/ruby*.rb')

          output = @rubocop.status_report[:markdowns].first.message

          # A title
          expect(output).to include('Rubocop violations')
          # A warning
          expect(output).to include("spec/fixtures/ruby_file.rb | 13   | Don't do that!")
        end

        it 'appends --force-exclusion argument when force_exclusion is set' do
          allow(@rubocop).to receive(:`)
            .with('bundle exec rubocop -f json --force-exclusion spec/fixtures/ruby_file.rb')
            .and_return(response_ruby_file)

          # Do it
          @rubocop.lint(files: 'spec/fixtures/ruby*.rb', force_exclusion: true)

          output = @rubocop.status_report[:markdowns].first.message

          # A title
          expect(output).to include('Rubocop violations')
          # A warning
          expect(output).to include("spec/fixtures/ruby_file.rb | 13   | Don't do that!")
        end

        it 'handles a rubocop report for files changed in the PR' do
          allow(@rubocop.git).to receive(:added_files).and_return([])
          allow(@rubocop.git).to receive(:modified_files)
            .and_return(["spec/fixtures/another_ruby_file.rb"])

          allow(@rubocop).to receive(:`)
            .with('bundle exec rubocop -f json spec/fixtures/another_ruby_file.rb')
            .and_return(response_another_ruby_file)

          @rubocop.lint

          output = @rubocop.status_report[:markdowns].first.message

          expect(output).to include('Rubocop violations')
          expect(output).to include("spec/fixtures/another_ruby_file.rb | 23   | Don't do that!")
        end

        it 'is formatted as a markdown table' do
          allow(@rubocop.git).to receive(:modified_files)
            .and_return(['spec/fixtures/ruby_file.rb'])
          allow(@rubocop.git).to receive(:added_files).and_return([])
          allow(@rubocop).to receive(:`)
            .with('bundle exec rubocop -f json spec/fixtures/ruby_file.rb')
            .and_return(response_ruby_file)

          @rubocop.lint

          formatted_table = <<-EOS
### Rubocop violations\n
| File                       | Line | Reason         |
|----------------------------|------|----------------|
| spec/fixtures/ruby_file.rb | 13   | Don't do that! |
EOS
          expect(@rubocop.status_report[:markdowns].first.message).to eq(formatted_table.chomp)
          expect(@rubocop).not_to receive(:fail)
        end

        context 'with inline_comment option' do
          context 'without fail_on_inline_comment option' do
            it 'reports violations as line by line warnings' do
              allow(@rubocop.git).to receive(:modified_files)
                .and_return(['spec/fixtures/ruby_file.rb'])
              allow(@rubocop.git).to receive(:added_files).and_return([])
              allow(@rubocop).to receive(:`)
                .with('bundle exec rubocop -f json spec/fixtures/ruby_file.rb')
                .and_return(response_ruby_file)

              @rubocop.lint(inline_comment: true)

              expect(@rubocop.violation_report[:warnings].first.to_s)
                .to eq("Violation Don't do that! { sticky: false, file: spec/fixtures/ruby_file.rb, line: 13 }")
            end
          end

          context 'with fail_on_inline_comment option' do
            it 'reports violations as line by line failures' do
              allow(@rubocop.git).to receive(:modified_files)
                .and_return(['spec/fixtures/ruby_file.rb'])
              allow(@rubocop.git).to receive(:added_files).and_return([])
              allow(@rubocop).to receive(:`)
                .with('bundle exec rubocop -f json spec/fixtures/ruby_file.rb')
                .and_return(response_ruby_file)

              @rubocop.lint(fail_on_inline_comment: true, inline_comment: true)

              expect(@rubocop.violation_report[:errors].first.to_s)
                .to eq("Violation Don't do that! { sticky: false, file: spec/fixtures/ruby_file.rb, line: 13 }")
            end
          end
        end

        describe 'a filename with special characters' do
          it 'is shell escaped' do
            modified_files = [
              'spec/fixtures/shellescape/ruby_file_with_parens_(abc).rb',
              'spec/fixtures/shellescape/ruby_file with spaces.rb',
              'spec/fixtures/shellescape/ruby_file\'with_quotes.rb'
            ]
            allow(@rubocop.git).to receive(:modified_files)
              .and_return(modified_files)
            allow(@rubocop.git).to receive(:added_files).and_return([])

            expect { @rubocop.lint }.not_to raise_error
          end
        end

        describe 'report to danger' do
          let(:fail_msg) { %{spec/fixtures/ruby_file.rb | 13 | Don't do that!} }
          it 'reports to danger' do
            allow(@rubocop.git).to receive(:modified_files)
              .and_return(['spec/fixtures/ruby_file.rb'])
            allow(@rubocop.git).to receive(:added_files).and_return([])
            allow(@rubocop).to receive(:`)
              .with('bundle exec rubocop -f json spec/fixtures/ruby_file.rb')
              .and_return(response_ruby_file)

            expect(@rubocop).to receive(:fail).with(fail_msg)
            @rubocop.lint(report_danger: true)
          end
        end
      end
    end
  end
end
