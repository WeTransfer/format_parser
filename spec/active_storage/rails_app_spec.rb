require 'spec_helper'

def skip_reason
  if RUBY_ENGINE == 'jruby'
    'Skipping because JRuby have randon failing issue'
  elsif RUBY_VERSION.to_f < 2.5
    'Skipping because Rails testing script use Rails 6, who does not support Ruby bellow 2.5'
  else
    'Skipping because this test randomly started failing for every version - mismatching default gem versions.'
  end
end

# TODO: Investigate and fix this test
describe 'Rails app with ActiveStorage and format-parser', skip: skip_reason do
  describe 'local hosting with ActiveStorage disk adapter' do
    it 'parse local file with format_parser' do
      clean_env do
        cmd = 'ruby spec/integration/active_storage/rails_app.rb'
        cmd_status = ruby_script_runner(cmd)
        expect(cmd_status[:stdout].last).to match(/1 runs, 3 assertions, 0 failures, 0 errors, 0 skips/)
        expect(cmd_status[:exitstatus]).to eq(0)
      end
    end
  end

  def ruby_script_runner(cmd)
    require 'open3'
    cmd_status = { stdout: [], exitstatus: nil }
    Open3.popen2(cmd) do |_stdin, stdout, wait_thr|
      frame_stdout do
        while line = stdout.gets
          puts "|  #{line}"
          cmd_status[:stdout] << line
        end
      end
      cmd_status[:exitstatus] = wait_thr.value.exitstatus
    end
    cmd_status
  end

  def frame_stdout
    puts
    puts '-' * 50
    yield
    puts '-' * 50
  end

  def clean_env
    if Bundler.respond_to?(:with_unbundled_env)
      Bundler.with_unbundled_env do
        yield
      end
    else
      Bundler.with_clean_env do
        yield
      end
    end
  end
end
