Redmine::Plugin.register :redmine_working_hours do
  name 'Redmine Working Hours plugin'
  author 'Pirmin Kalberer, Mathias Walker'
  description 'A plugin for integration of working time in Redmine'
  version '1.0'
  url 'https://github.com/sourcepole/redmine_working_hours'
  author_url 'http://sourcepole.ch'

  menu :account_menu, :working_hours,
    {:controller => 'working_hours', :action => 'index'},
    :caption => :working_hours,
    :before => :logout,
    :if => Proc.new { User.current.logged? }
end
