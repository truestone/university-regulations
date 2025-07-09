require 'anthropic'

class AnthropicService
  CHAT_MODEL = 'claude-3-5-sonnet-20241022'
  
  # Pricing per 1M tokens (as of 2024)
  PRICING = {
    'claude-3-5-sonnet-20241022' => { input: 3.0, output: 15.0 }
  }.freeze

  def initialize(ai_setting)
    @ai_setting = ai_setting
    @client = Anthropic::Client.new(access_token: ai_setting.api_key)
  end

  def chat_completion(messages)
    # Convert OpenAI format to Anthropic format
    anthropic_messages = convert_messages(messages)
    
    response = @client.messages(
      model: CHAT_MODEL,
      max_tokens: 1000,
      messages: anthropic_messages
    )

    if response['error']
      raise "Anthropic API Error: #{response['error']['message']}"
    end

    content = response.dig('content', 0, 'text')
    input_tokens = response.dig('usage', 'input_tokens') || 0
    output_tokens = response.dig('usage', 'output_tokens') || 0
    
    # Calculate cost (Anthropic pricing is per 1M tokens)
    input_cost = calculate_cost(input_tokens, CHAT_MODEL, 'input')
    output_cost = calculate_cost(output_tokens, CHAT_MODEL, 'output')
    total_cost = input_cost + output_cost
    
    AiService.update_usage(@ai_setting.provider, total_cost)

    {
      content: content,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      total_tokens: input_tokens + output_tokens,
      cost: total_cost,
      model: CHAT_MODEL
    }
  rescue => e
    Rails.logger.error "Anthropic Chat Error: #{e.message}"
    raise "Failed to get chat completion: #{e.message}"
  end

  def estimate_cost(text, operation = 'chat')
    tokens = estimate_tokens(text)
    
    case operation
    when 'chat'
      # Estimate both input and output for chat
      input_cost = calculate_cost(tokens, CHAT_MODEL, 'input')
      output_cost = calculate_cost(tokens * 0.5, CHAT_MODEL, 'output') # Assume 50% output ratio
      input_cost + output_cost
    when 'embedding'
      # Anthropic doesn't provide embeddings
      0
    else
      0
    end
  end

  private

  def convert_messages(openai_messages)
    anthropic_messages = []
    
    openai_messages.each do |msg|
      case msg[:role] || msg['role']
      when 'system'
        # Anthropic handles system messages differently
        # We'll prepend it to the first user message
        next
      when 'user', 'assistant'
        anthropic_messages << {
          role: msg[:role] || msg['role'],
          content: msg[:content] || msg['content']
        }
      end
    end
    
    # Add system message to first user message if exists
    system_msg = openai_messages.find { |m| (m[:role] || m['role']) == 'system' }
    if system_msg && anthropic_messages.any?
      first_user_msg = anthropic_messages.find { |m| m[:role] == 'user' }
      if first_user_msg
        system_content = system_msg[:content] || system_msg['content']
        first_user_msg[:content] = "#{system_content}\n\n#{first_user_msg[:content]}"
      end
    end
    
    anthropic_messages
  end

  def calculate_cost(tokens, model, type)
    price_per_1m = PRICING.dig(model, type.to_sym) || 0
    (tokens / 1_000_000.0) * price_per_1m
  end

  def estimate_tokens(text)
    # Rough estimation: 1 token ≈ 4 characters
    (text.length / 4.0).ceil
  end
end