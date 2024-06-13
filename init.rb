# encoding: utf-8

require "redmine"

def init
  begin
    Dir::foreach(File.join(File.dirname(__FILE__), "lib")) do |file|
      next unless /\.rb$/ =~ file
      require_dependency file
    end
  rescue LoadError => le
    puts "--- Error: init.rb içinde store.rb yüklenirken hata: #{le.message}"
  end
end

if Rails::VERSION::MAJOR >= 5
  ActiveSupport::Reloader.to_prepare do
    init
  end
elsif Rails::VERSION::MAJOR >= 3
  ActionDispatch::Callbacks.to_prepare do
    init
  end
else
  Dispatcher.to_prepare :redmine_closed_date do
    init
  end
end

# Günlük seviyesini DEBUG olarak ayarlayın
# https://www.mintbit.com/blog/ruby-on-rails-log-levels-examples-and-best-practices
Rails.logger.level = Logger::DEBUG

$NAME_KIWI_TESTS = :kiwi_plugin
$PLUGIN_NAME_KIWI_TESTS = "plugin_#{$NAME_KIWI_TESTS}".to_sym

Redmine::Plugin.register $NAME_KIWI_TESTS do
  name "Ulak Kiwi Test Plugin - Test Plan Based"
  author "Cem Topkaya"
  description "Kiwi TCMS integration for Redmine"
  version "1.0.0"
  url "https://github.com/cemtopkaya/ulak_test"
  author_url "https://cemtopkaya.com"
  requires_redmine :version_or_higher => "5.0.0"

  PLUGIN_ROOT_KIWI_TESTS = Pathname.new(__FILE__).join("..").realpath.to_s
  yaml_settings = YAML::load(File.open(File.join(PLUGIN_ROOT_KIWI_TESTS + "/config", "settings.yml")))

  settings :default => {
    "jenkins_url" => yaml_settings["jenkins_url"],
    "jenkins_job_url" => yaml_settings["jenkins_job_url"],
    "jenkins_job_auth_token" => yaml_settings["jenkins_job_auth_token"],

    "kiwi_url" => yaml_settings["kiwi_url"],
    "rest_api_url" => yaml_settings["rest_api_url"],
    "rest_api_username" => yaml_settings["rest_api_username"],
    "rest_api_password" => yaml_settings["rest_api_password"],
  }, partial: "settings/ulak_test_eklenti_settings.html"

  project_module $NAME_KIWI_TESTS do
    # "Test Results" sekme başlığını
    permission :view_tab_issue_test_results_tab, {}

    # Testleri koşturmak için düğmeye yetki verilmeli
    permission :view_run_test_button, issue_test: :view_run_test_button, :public => true
    permission :view_issue_test_plans, issue_test: :view_issue_test_plans, :public => true
    permission :view_changeset_tags, issue_test: :view_changeset_tags, :public => true
    permission :view_changeset_tag_artifacts_runs, issue_test: :view_changeset_tag_artifacts_runs, :public => true
    permission :view_tag_runs, issue_test: :view_tag_runs, :public => true
    permission :get_issue_tests, issue_test: :get_issue_tests, :public => true

    permission :edit_issue_tests, { :issue_test => [:add_test_to_issue, :remove_test_from_issue] }, :require => :member
  end
end
