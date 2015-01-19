# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

resources :working_hours do
  member do
    put 'update_comments'
  end
  collection do
    get 'startstop'
    post 'break'
    get 'project_issues'
  end
end

resources :holidays
