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
    match 'vacation/new' => 'working_hours#new_vacation', :via => :get, :as => 'new_vacation'
    match 'vacation' => 'working_hours#create_vacation', :via => :post
    get 'statistics'
  end
end

resources :holidays
resources :working_hours_snapshots
