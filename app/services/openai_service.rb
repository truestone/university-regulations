require 'openai'

class OpenaiService
  EMBEDDING_MODEL = 'text-embedding-3-small'
  CHAT_MODEL = 'gpt-4o-mini'
  
  # Pricing per 1K tokens (as of 2024)
  PRICING = {
    'text-embedding-3-small' => { input: 0.00002 },
    'gpt-4o-mini' => { input: 0.00015, output: 0.0006 }
  }.freeze

  def initialize(ai_setting)
    @ai_setting = ai_setting
    @client = OpenAI::Client.new(access_token: ai_setting.api_key)
  end

  def get_embedding(text)
    response = @client.embeddings(
      parameters: {
        model: EMBEDDING_MODEL,
        input: text
      }
    )

    if response['error']
      raise "OpenAI API Error: #{response['error']['message']}"
    end

    embedding = response.dig('data', 0, 'embedding')
    tokens_used = response.dig('usage', 'total_tokens') || estimate_tokens(text)
    
    # Calculate and update cost
    cost = calculate_cost(tokens_used, EMBEDDING_MODEL, 'input')
    AiService.update_usage(@ai_setting.provider, cost)

    {
      embedding: embedding,
      tokens_used: tokens_used,
      cost: cost,
      model: EMBEDDING_MODEL
    }
  rescue => e
    Rails.logger.error "OpenAI Embedding Error: #{e.message}"
    raise "Failed to get embedding: #{e.message}"
  end

  def chat_completion(messages)
    response = @client.chat(
      parameters: {
        model: CHAT_MODEL,
        messages: messages,
        max_tokens: 1000,
        temperature: 0.7
      }
    )

    if response['error']
      raise "OpenAI API Error: #{response['error']['message']}"
    end

    content = response.dig('choices', 0, 'message', 'content')
    input_tokens = response.dig('usage', 'prompt_tokens') || 0
    output_tokens = response.dig('usage', 'completion_tokens') || 0
    
    # Calculate cost
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
    Rails.logger.error "OpenAI Chat Error: #{e.message}"
    raise "Failed to get chat completion: #{e.message}"
  end

  def estimate_cost(text, operation = 'embedding')
    tokens = estimate_tokens(text)
    
    case operation
    when 'embedding'
      calculate_cost(tokens, EMBEDDING_MODEL, 'input')
    when 'chat'
      # Estimate both input and output for chat
      input_cost = calculate_cost(tokens, CHAT_MODEL, 'input')
      output_cost = calculate_cost(tokens * 0.5, CHAT_MODEL, 'output') # Assume 50% output ratio
      input_cost + output_cost
    else
      0
    end
  end

  private

  def calculate_cost(tokens, model, type)
    price_per_1k = PRICING.dig(model, type.to_sym) || 0
    (tokens / 1000.0) * price_per_1k
  end

  def estimate_tokens(text)
    # Rough estimation: 1 token ≈ 4 characters for English
    # For more accuracy, could use tiktoken gem
    (text.length / 4.0).ceil
  end
end