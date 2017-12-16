require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yard'

YARD::Rake::YardocTask.new(:doc) do |t|
  # The dash has to be between the two to "divide" the source files and
  # miscellaneous documentation files that contain no code
  t.files = ['lib/**/*.rb', '-', 'LICENSE.txt', 'IMPLEMENTATION_DETAILS.md']
end

RSpec::Core::RakeTask.new(:spec)
task default: :spec

Rake::Task['release'].clear

desc "Pick up the .gem file from pkg/ and push it to Gemfury"
task :release do
  # IMPORTANT: You need to have the `fury` gem installed, and you need to be logged in.
  # Please DO READ about "impersonation", which is how you push to your company account instead
  # of your personal account!
  # https://gemfury.com/help/collaboration#impersonation
  paths = Dir.glob(__dir__ + '/pkg/*.gem')
  if paths.length != 1
    raise "Must have found only 1 .gem path, but found %s" % paths.inspect
  end
  escaped_gem_path = Shellwords.escape(paths.shift)
  sh("fury push #{escaped_gem_path} --as=wetransfer")
end
