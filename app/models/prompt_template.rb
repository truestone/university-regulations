# frozen_string_literal: true

# 프롬프트 템플릿 관리 모델
class PromptTemplate < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :template_type, presence: true, inclusion: { in: %w[system user context] }
  validates :content, presence: true
  validates :version, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :latest_version, -> { order(version: :desc) }

  # 템플릿 렌더링
  def render(variables = {})
    rendered_content = content.dup
    
    variables.each do |key, value|
      placeholder = "{{#{key}}}"
      rendered_content.gsub!(placeholder, value.to_s)
    end
    
    # 사용되지 않은 플레이스홀더 확인
    unused_placeholders = rendered_content.scan(/\{\{(\w+)\}\}/).flatten
    if unused_placeholders.any?
      Rails.logger.warn "Unused placeholders in template #{name}: #{unused_placeholders.join(', ')}"
    end
    
    rendered_content
  end

  # 새 버전 생성
  def create_new_version(new_content, created_by: nil)
    new_version = self.class.create!(
      name: name,
      template_type: template_type,
      content: new_content,
      version: (self.class.where(name: name).maximum(:version) || 0) + 1,
      description: "Updated version of #{name}",
      created_by: created_by,
      is_active: false
    )
    
    new_version
  end

  # 활성화
  def activate!
    transaction do
      # 같은 이름의 다른 템플릿들 비활성화
      self.class.where(name: name).update_all(is_active: false)
      # 현재 템플릿 활성화
      update!(is_active: true)
    end
  end

  # 템플릿 변수 추출
  def extract_variables
    content.scan(/\{\{(\w+)\}\}/).flatten.uniq
  end

  # 템플릿 검증
  def validate_template
    errors = []
    
    # 기본 구문 검증
    if content.count('{{') != content.count('}}')
      errors << "Mismatched placeholder brackets"
    end
    
    # 필수 변수 확인 (타입별)
    required_vars = required_variables_for_type
    missing_vars = required_vars - extract_variables
    
    if missing_vars.any?
      errors << "Missing required variables: #{missing_vars.join(', ')}"
    end
    
    errors
  end

  # 사용 통계
  def usage_stats(period: 30.days)
    # 실제 구현에서는 사용 로그 테이블에서 조회
    {
      total_uses: 0, # PromptUsageLog.where(template_id: id, created_at: period.ago..).count
      avg_quality_score: 0,
      last_used_at: nil
    }
  end

  private

  def required_variables_for_type
    case template_type
    when 'system'
      %w[response_format safety_guidelines]
    when 'user'
      %w[question context]
    when 'context'
      %w[regulation_title regulation_code article_number article_title content]
    else
      []
    end
  end

  # 기본 템플릿 생성
  def self.create_default_templates
    templates = [
      {
        name: 'default_system',
        template_type: 'system',
        content: default_system_template,
        description: 'Default system prompt for regulation Q&A'
      },
      {
        name: 'default_user',
        template_type: 'user',
        content: default_user_template,
        description: 'Default user prompt template'
      },
      {
        name: 'default_context',
        template_type: 'context',
        content: default_context_template,
        description: 'Default context formatting template'
      }
    ]

    templates.each do |template_data|
      create!(
        **template_data,
        version: 1,
        is_active: true,
        created_by: 'system'
      )
    end
  end

  def self.default_system_template
    <<~TEMPLATE
      당신은 대학교 규정 전문가입니다. 제공된 규정 내용을 바탕으로 정확하고 도움이 되는 답변을 제공해야 합니다.

      ## 답변 원칙:
      1. 제공된 규정 내용만을 근거로 답변하세요
      2. 규정에 명시되지 않은 내용은 추측하지 마세요
      3. 답변이 불확실한 경우 "제공된 규정에서는 명확하지 않습니다"라고 명시하세요
      4. 관련 조문 번호와 규정명을 함께 제시하세요
      5. 학생이 이해하기 쉬운 언어로 설명하세요

      {{safety_guidelines}}

      {{response_format}}
    TEMPLATE
  end

  def self.default_user_template
    <<~TEMPLATE
      ## 관련 규정 내용:

      {{context}}

      ## 질문:
      {{question}}

      위의 규정 내용을 바탕으로 질문에 대해 정확하고 도움이 되는 답변을 제공해 주세요.
    TEMPLATE
  end

  def self.default_context_template
    <<~TEMPLATE
      ### {{regulation_title}} ({{regulation_code}})
      **제{{article_number}}조 {{article_title}}**

      {{content}}

      *유사도: {{similarity}}%*
    TEMPLATE
  end
end