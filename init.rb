require 'redmine'

Redmine::Plugin.register :redmine_working_hours do
  name 'Redmine Working Hours plugin'
 author 'Pirmin Kalberer'
  description 'A plugin for working time integration in Redmine.'
  version '0.2'

  menu :account_menu, "Working hours", :controller => 'working_hours', :action => 'index'
end
