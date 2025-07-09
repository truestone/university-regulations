class AiService
  class << self
    def get_active_setting(provider = nil)
      if provider
        AiSetting.active.by_provider(provider).first
      else
        AiSetting.active.first
      end
    end

    def available_providers
      AiSetting.active.pluck(:provider).uniq
    end

    def can_use_provider?(provider)
      setting = get_active_setting(provider)
      setting&.can_use?
    end

    def get_embedding(text, provider: 'openai')
      setting = get_active_setting(provider)
      raise "No active AI setting found for provider: #{provider}" unless setting&.can_use?

      case provider
      when 'openai'
        OpenaiService.new(setting).get_embedding(text)
      when 'anthropic'
        # Anthropic doesn't provide embeddings, fallback to OpenAI
        openai_setting = get_active_setting('openai')
        raise "OpenAI not available for embeddings" unless openai_setting&.can_use?
        OpenaiService.new(openai_setting).get_embedding(text)
      when 'google'
        GoogleService.new(setting).get_embedding(text)
      else
        raise "Unsupported provider: #{provider}"
      end
    end

    def chat_completion(messages, provider: nil)
      provider ||= available_providers.first
      setting = get_active_setting(provider)
      raise "No active AI setting found for provider: #{provider}" unless setting&.can_use?

      case provider
      when 'openai'
        OpenaiService.new(setting).chat_completion(messages)
      when 'anthropic'
        AnthropicService.new(setting).chat_completion(messages)
      when 'google'
        GoogleService.new(setting).chat_completion(messages)
      else
        raise "Unsupported provider: #{provider}"
      end
    end

    def estimate_cost(text, provider: 'openai', operation: 'embedding')
      setting = get_active_setting(provider)
      return 0 unless setting

      case provider
      when 'openai'
        OpenaiService.new(setting).estimate_cost(text, operation)
      when 'anthropic'
        AnthropicService.new(setting).estimate_cost(text, operation)
      when 'google'
        GoogleService.new(setting).estimate_cost(text, operation)
      else
        0
      end
    end

    def update_usage(provider, cost)
      setting = get_active_setting(provider)
      return unless setting

      setting.increment!(:usage_this_month, cost)
      
      # Check budget and send warning if needed
      if setting.budget_exceeded?
        BudgetWarningService.new(setting).send_warning
      end
    end
  end
end