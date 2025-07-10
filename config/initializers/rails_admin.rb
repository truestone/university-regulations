RailsAdmin.config do |config|
  config.asset_source = :sprockets

  ### Popular gems integration

  ## == Devise ==
  # config.authenticate_with do
  #   warden.authenticate! scope: :user
  # end
  # config.current_user_method(&:current_user)

  ## == CancanCan ==
  # config.authorize_with :cancancan

  ## == Pundit ==
  # config.authorize_with :pundit

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/railsadminteam/rails_admin/wiki/Base-configuration

  ## == Gravatar integration ==
  ## To disable Gravatar integration in Navigation Bar set to false
  # config.show_gravatar = true

  # Navigation configuration for hierarchical structure
  config.navigation_static_links = {
    'Regulation Management' => '/admin',
  }

  # Model navigation groups and weights for tree-like structure
  config.model 'Edition' do
    navigation_label '1. Editions'
    weight 1
  end

  config.model 'Chapter' do
    navigation_label '2. Chapters'
    weight 2
  end

  config.model 'Regulation' do
    navigation_label '3. Regulations'
    weight 3
  end

  config.model 'Article' do
    navigation_label '4. Articles'
    weight 4
  end

  config.model 'Clause' do
    navigation_label '5. Clauses'
    weight 5
  end

  config.model 'User' do
    navigation_label 'Administration'
    weight 10
  end

  config.model 'AiSetting' do
    navigation_label 'Administration'
    weight 11
  end

  config.model 'Conversation' do
    navigation_label 'Administration'
    weight 12
  end

  config.model 'Message' do
    navigation_label 'Administration'
    weight 13
  end

  # Hide Active Storage models from navigation
  config.model 'ActiveStorage::Attachment' do
    visible false
  end

  config.model 'ActiveStorage::Blob' do
    visible false
  end

  config.model 'ActiveStorage::VariantRecord' do
    visible false
  end

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
    show_in_app

    ## With an audit adapter, you can add:
    # history_index
    # history_show
  end
end