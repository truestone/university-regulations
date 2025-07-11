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
    
    # Form customization
    edit do
      field :number do
        label 'Edition Number'
        help 'Edition number (1-6)'
        html_attributes { { min: 1, max: 6 } }
      end
      field :title do
        label 'Title'
        help 'Descriptive title for this edition'
        required true
      end
      field :description do
        label 'Description'
        help 'Detailed description of this edition'
      end
      field :sort_order do
        label 'Sort Order'
        help 'Order for display (unique)'
        required true
      end
      field :is_active do
        label 'Active'
        help 'Whether this edition is currently active'
      end
    end
    
    list do
      field :number
      field :title
      field :sort_order
      field :is_active
      field :created_at
    end
  end

  config.model 'Chapter' do
    navigation_label '2. Chapters'
    weight 2
    
    # Form customization
    edit do
      field :edition do
        label 'Edition'
        help 'Select the parent edition'
        required true
      end
      field :number do
        label 'Chapter Number'
        help 'Chapter number within the edition'
        required true
      end
      field :title do
        label 'Title'
        help 'Chapter title'
        required true
      end
      field :description do
        label 'Description'
        help 'Chapter description'
      end
      field :sort_order do
        label 'Sort Order'
        help 'Order within the edition'
        required true
      end
      field :is_active do
        label 'Active'
        help 'Whether this chapter is active'
      end
    end
    
    list do
      field :edition
      field :number
      field :title
      field :sort_order
      field :is_active
      field :created_at
    end
  end

  config.model 'Regulation' do
    navigation_label '3. Regulations'
    weight 3
    
    # Form customization
    edit do
      field :chapter do
        label 'Chapter'
        help 'Select the parent chapter'
        required true
      end
      field :number do
        label 'Regulation Number'
        help 'Regulation number within the chapter'
        required true
      end
      field :title do
        label 'Title'
        help 'Regulation title'
        required true
      end
      field :content do
        label 'Content'
        help 'Full text content of the regulation'
      end
      field :rich_content, :action_text do
        label 'Rich Content'
        help 'Rich text content with formatting, images, and links'
      end
      field :regulation_code do
        label 'Regulation Code'
        help 'Unique regulation identifier code'
        required true
      end
      field :status, :enum do
        label 'Status'
        help 'Current status of the regulation'
        enum do
          ['active', 'inactive', 'abolished']
        end
        required true
      end
      field :sort_order do
        label 'Sort Order'
        help 'Order within the chapter'
        required true
      end
      field :is_active do
        label 'Active'
        help 'Whether this regulation is active'
      end
    end
    
    list do
      field :chapter
      field :number
      field :title
      field :regulation_code
      field :status
      field :is_active
      field :created_at
    end
  end

  config.model 'Article' do
    navigation_label '4. Articles'
    weight 4
    
    # Form customization
    edit do
      field :regulation do
        label 'Regulation'
        help 'Select the parent regulation'
        required true
      end
      field :number do
        label 'Article Number'
        help 'Article number within the regulation'
        required true
      end
      field :title do
        label 'Title'
        help 'Article title'
        required true
      end
      field :content do
        label 'Content'
        help 'Article content text'
      end
      field :rich_content, :action_text do
        label 'Rich Content'
        help 'Rich text content with formatting, images, and links'
      end
      field :sort_order do
        label 'Sort Order'
        help 'Order within the regulation'
        required true
      end
      field :is_active do
        label 'Active'
        help 'Whether this article is active'
      end
      # Hide embedding field from form
      field :embedding do
        visible false
      end
    end
    
    list do
      field :regulation
      field :number
      field :title
      field :sort_order
      field :is_active
      field :created_at
    end
  end

  config.model 'Clause' do
    navigation_label '5. Clauses'
    weight 5
    
    # Form customization
    edit do
      field :article do
        label 'Article'
        help 'Select the parent article'
        required true
      end
      field :number do
        label 'Clause Number'
        help 'Clause number within the article'
        required true
      end
      field :content do
        label 'Content'
        help 'Clause content text'
        required true
      end
      field :clause_type, :enum do
        label 'Clause Type'
        help 'Type of clause'
        enum do
          ['paragraph', 'subparagraph', 'item', 'subitem']
        end
        required true
      end
      field :sort_order do
        label 'Sort Order'
        help 'Order within the article'
        required true
      end
      field :is_active do
        label 'Active'
        help 'Whether this clause is active'
      end
    end
    
    list do
      field :article
      field :number
      field :clause_type
      field :sort_order
      field :is_active
      field :created_at
    end
  end

  config.model 'User' do
    navigation_label 'Administration'
    weight 10
    
    # Form customization
    edit do
      field :email do
        label 'Email Address'
        help 'User email address (must be unique)'
        required true
      end
      field :name do
        label 'Full Name'
        help 'User full name'
        required true
      end
      field :role, :enum do
        label 'Role'
        help 'User role in the system'
        enum do
          ['user', 'admin', 'super_admin']
        end
        required true
      end
      field :password do
        label 'Password'
        help 'Leave blank to keep current password'
      end
      field :password_confirmation do
        label 'Password Confirmation'
        help 'Confirm the password'
      end
      # Hide sensitive fields
      field :password_digest do
        visible false
      end
      field :password_reset_token do
        visible false
      end
      field :failed_attempts do
        visible false
      end
      field :locked_until do
        visible false
      end
    end
    
    list do
      field :email
      field :name
      field :role
      field :last_login_at
      field :failed_attempts
      field :created_at
    end
  end

  config.model 'AiSetting' do
    navigation_label 'Administration'
    weight 11
    
    # Form customization
    edit do
      field :provider, :enum do
        label 'AI Provider'
        help 'AI service provider'
        enum do
          ['openai', 'anthropic', 'google']
        end
        required true
      end
      field :model_id do
        label 'Model ID'
        help 'Specific model identifier'
        required true
      end
      field :monthly_budget do
        label 'Monthly Budget'
        help 'Monthly budget limit in USD'
      end
      field :usage_this_month do
        label 'Usage This Month'
        help 'Current month usage in USD'
        read_only true
      end
      field :is_active do
        label 'Active'
        help 'Whether this AI setting is active'
      end
      # Hide sensitive API key
      field :api_key do
        visible false
      end
    end
    
    list do
      field :provider
      field :model_id
      field :monthly_budget
      field :usage_this_month
      field :is_active
      field :last_used_at
    end
  end

  config.model 'Conversation' do
    navigation_label 'Administration'
    weight 12
    
    # Form customization
    edit do
      field :session_id do
        label 'Session ID'
        help 'Unique session identifier'
        read_only true
      end
      field :title do
        label 'Title'
        help 'Conversation title'
      end
      field :last_message_at do
        label 'Last Message At'
        help 'Timestamp of last message'
        read_only true
      end
      field :expires_at do
        label 'Expires At'
        help 'When this conversation expires'
      end
    end
    
    list do
      field :session_id
      field :title
      field :last_message_at
      field :expires_at
      field :created_at
    end
  end

  config.model 'Message' do
    navigation_label 'Administration'
    weight 13
    
    # Form customization
    edit do
      field :conversation do
        label 'Conversation'
        help 'Parent conversation'
        required true
      end
      field :role, :enum do
        label 'Role'
        help 'Message sender role'
        enum do
          ['user', 'assistant', 'system']
        end
        required true
      end
      field :content do
        label 'Content'
        help 'Message content'
        required true
      end
      field :tokens_used do
        label 'Tokens Used'
        help 'Number of tokens consumed'
        read_only true
      end
    end
    
    list do
      field :conversation
      field :role
      field :tokens_used
      field :created_at
    end
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