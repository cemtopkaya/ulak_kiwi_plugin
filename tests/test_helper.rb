unless ActionController::TestCase.included_modules.include?(Redmine::PluginFixturesLoader)
  ActionController::TestCase.send :include, Redmine::PluginFixturesLoader
end

unless ActiveSupport::TestCase.included_modules.include?(Redmine::PluginFixturesLoader)
  ActiveSupport::TestCase.send :include, Redmine::PluginFixturesLoader
end
