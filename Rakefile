require 'pp'
require 'bundler'
require 'rake/testtask'

Bundler::GemHelper.install_tasks

task default: 'test'

Rake::TestTask.new do |t|
  t.test_files = Dir['test/*'].select do |file|
    File.basename(file).match(/^test_.+\.rb$/)
  end

  t.warning    = true
end

desc 'Add or update rdoc'
task :doc do
  `rdoc lib/`
end
