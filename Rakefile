DISPLAY_VAR = 'DISPLAY=:5.0'
TEST_PROJECT_DIR = "/tmp/rails3_templates_test_projects"

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

    def run_test_project(run_vars = '')
      test_project_filename="testproject_#{Time.now.strftime("%Y%m%d_%H%S")}"
      test_project_path="#{TEST_PROJECT_DIR}/#{test_project_filename}"

      begin
        template_project_path = File.dirname(__FILE__)
        cd TEST_PROJECT_DIR do
          run "CRUISE=true #{run_vars} " +
              "rails new #{test_project_filename} -m #{template_project_path}/main.rb -J -T"
        end
        run "rvm rvmrc trust #{test_project_path}"
        cd test_project_path do
          run 'bundle install'
          run "rake spec"
          # can't work when run as an init.d; call each time before build to make sure it's running
          run "pidof Xvfb && nohup Xvfb :5.0 -screen 0 1024x768x8 &"

          # have to explicitly set DISPLAY env var. the shell-out can't can't reference it in the bash.rc.
          run "#{DISPLAY_VAR} rake jasmine:ci"
          run "#{DISPLAY_VAR} rake spec:selenium"
          run "#{DISPLAY_VAR} rake spec:selenium:sauce"
        end
      end
    end

    unless ENV['NO_DELETE_TEST_PROJECTS']
      # delete and recreate test project dir.
      # This keeps it from growing forever on CI, but still leaves the last run to be inspected
      FileUtils.rm_rf(TEST_PROJECT_DIR)
    end
    FileUtils.mkdir_p(TEST_PROJECT_DIR)

    run_test_project
  end
end
