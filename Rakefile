task :cruise => 'rails3_templates:test'

namespace :rails3_templates do
  task :test do
    def run(cmd)
      IO.popen("#{cmd} 2>&1") do |f|
        while line = f.gets do
          puts line
        end
      end
      raise "Build failed" if $? != 0
    end

    test_project_dir="/tmp/rails3_templates_test_projects"
    test_project_filename="testproject_#{Time.now.strftime("%Y%m%d_%H%S")}"
    test_project_path="#{test_project_dir}/#{test_project_filename}"
    unless ENV['NO_DELETE_TEST_PROJECTS']
      # delete and recreate test project dir.
      # This keeps it from growing forever on CI, but still leaves the last run to be inspected
      FileUtils.rm_rf(test_project_dir)
    end
    FileUtils.mkdir_p(test_project_dir)
    begin
      template_project_path = File.dirname(__FILE__)
      cd test_project_dir do
        run "CRUISE=true " +
            "rails new #{test_project_filename} -m #{template_project_path}/main.rb -J -T"
      end
      run "rvm rvmrc trust #{test_project_path}"
      cd test_project_path do
        run 'bundle install'
        run "rake spec"
        run "nohup Xvfb #{ENV['DISPLAY']} -screen 0 1024x768x8 &"
p "======================#{ENV['DISPLAY']}================="
        run "DISPLAY=:5.0 rake jasmine:ci"
        run "DISPLAY=:5.0 rake spec:selenium"
        run "DISPLAY=:5.0 rake spec:selenium:sauce"
      end
    end
  end
end
