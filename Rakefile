require 'rake/testtask'

Rake::TestTask.new do |t|
  t.test_files = FileList['server_test.rb']
  t.verbose = true
end

task default: 'test'