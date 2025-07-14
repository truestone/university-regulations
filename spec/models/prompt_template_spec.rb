# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptTemplate, type: :model do
  let(:valid_attributes) do
    {
      name: 'test_template',
      template_type: 'system',
      content: 'Hello {{name}}, welcome to {{system}}!',
      version: 1,
      description: 'Test template',
      is_active: true
    }
  end

  describe 'validations' do
    it 'validates presence of required fields' do
      template = PromptTemplate.new
      expect(template).not_to be_valid
      expect(template.errors[:name]).to include("can't be blank")
      expect(template.errors[:template_type]).to include("can't be blank")
      expect(template.errors[:content]).to include("can't be blank")
      expect(template.errors[:version]).to include("can't be blank")
    end

    it 'validates uniqueness of name and version combination' do
      PromptTemplate.create!(valid_attributes)
      
      duplicate = PromptTemplate.new(valid_attributes)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end

    it 'validates template_type inclusion' do
      template = PromptTemplate.new(valid_attributes.merge(template_type: 'invalid'))
      expect(template).not_to be_valid
      expect(template.errors[:template_type]).to include('is not included in the list')
    end

    it 'validates version is positive' do
      template = PromptTemplate.new(valid_attributes.merge(version: 0))
      expect(template).not_to be_valid
      expect(template.errors[:version]).to include('must be greater than 0')
    end
  end

  describe 'scopes' do
    let!(:active_template) { create(:prompt_template, is_active: true) }
    let!(:inactive_template) { create(:prompt_template, is_active: false) }
    let!(:system_template) { create(:prompt_template, template_type: 'system') }
    let!(:user_template) { create(:prompt_template, template_type: 'user') }

    describe '.active' do
      it 'returns only active templates' do
        expect(PromptTemplate.active).to include(active_template)
        expect(PromptTemplate.active).not_to include(inactive_template)
      end
    end

    describe '.by_type' do
      it 'returns templates of specified type' do
        expect(PromptTemplate.by_type('system')).to include(system_template)
        expect(PromptTemplate.by_type('system')).not_to include(user_template)
      end
    end

    describe '.latest_version' do
      it 'orders by version descending' do
        old_version = create(:prompt_template, name: 'test', version: 1)
        new_version = create(:prompt_template, name: 'test_v2', version: 2)
        
        expect(PromptTemplate.latest_version.first.version).to be >= PromptTemplate.latest_version.last.version
      end
    end
  end

  describe '#render' do
    let(:template) { PromptTemplate.new(valid_attributes) }

    it 'renders template with provided variables' do
      result = template.render(name: 'John', system: 'University')
      expect(result).to eq('Hello John, welcome to University!')
    end

    it 'warns about unused placeholders' do
      expect(Rails.logger).to receive(:warn).with(/Unused placeholders/)
      
      template.render(name: 'John')  # Missing 'system' variable
    end

    it 'handles missing variables gracefully' do
      result = template.render(name: 'John')
      expect(result).to include('{{system}}')  # Placeholder remains
    end
  end

  describe '#create_new_version' do
    let!(:template) { create(:prompt_template, name: 'test', version: 1) }

    it 'creates a new version with incremented version number' do
      new_version = template.create_new_version('New content', created_by: 'admin')
      
      expect(new_version.name).to eq(template.name)
      expect(new_version.version).to eq(2)
      expect(new_version.content).to eq('New content')
      expect(new_version.created_by).to eq('admin')
      expect(new_version.is_active).to be false
    end
  end

  describe '#activate!' do
    let!(:template1) { create(:prompt_template, name: 'test', version: 1, is_active: true) }
    let!(:template2) { create(:prompt_template, name: 'test', version: 2, is_active: false) }

    it 'activates current template and deactivates others with same name' do
      template2.activate!
      
      template1.reload
      template2.reload
      
      expect(template1.is_active).to be false
      expect(template2.is_active).to be true
    end
  end

  describe '#extract_variables' do
    let(:template) { PromptTemplate.new(content: 'Hello {{name}}, your {{role}} is {{status}}.') }

    it 'extracts all placeholder variables' do
      variables = template.extract_variables
      expect(variables).to contain_exactly('name', 'role', 'status')
    end

    it 'returns unique variables only' do
      template.content = 'Hello {{name}}, {{name}} is your {{name}}.'
      variables = template.extract_variables
      expect(variables).to eq(['name'])
    end
  end

  describe '#validate_template' do
    it 'validates correct template syntax' do
      template = PromptTemplate.new(valid_attributes)
      errors = template.validate_template
      expect(errors).to be_empty
    end

    it 'detects mismatched brackets' do
      template = PromptTemplate.new(valid_attributes.merge(content: 'Hello {{name, missing bracket'))
      errors = template.validate_template
      expect(errors).to include('Mismatched placeholder brackets')
    end

    it 'detects missing required variables for system templates' do
      template = PromptTemplate.new(
        valid_attributes.merge(
          template_type: 'system',
          content: 'Simple content without required variables'
        )
      )
      errors = template.validate_template
      expect(errors.first).to include('Missing required variables')
    end
  end

  describe '.create_default_templates' do
    it 'creates default templates' do
      expect {
        PromptTemplate.create_default_templates
      }.to change(PromptTemplate, :count).by(3)
      
      expect(PromptTemplate.find_by(name: 'default_system')).to be_present
      expect(PromptTemplate.find_by(name: 'default_user')).to be_present
      expect(PromptTemplate.find_by(name: 'default_context')).to be_present
    end

    it 'creates active templates' do
      PromptTemplate.create_default_templates
      
      PromptTemplate.where(name: ['default_system', 'default_user', 'default_context']).each do |template|
        expect(template.is_active).to be true
      end
    end
  end

  describe 'default template content' do
    it 'generates valid system template' do
      content = PromptTemplate.default_system_template
      expect(content).to include('대학교 규정 전문가')
      expect(content).to include('{{safety_guidelines}}')
      expect(content).to include('{{response_format}}')
    end

    it 'generates valid user template' do
      content = PromptTemplate.default_user_template
      expect(content).to include('{{context}}')
      expect(content).to include('{{question}}')
    end

    it 'generates valid context template' do
      content = PromptTemplate.default_context_template
      expect(content).to include('{{regulation_title}}')
      expect(content).to include('{{article_number}}')
      expect(content).to include('{{content}}')
    end
  end
end