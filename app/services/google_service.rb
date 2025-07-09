require 'google/apis/aiplatform_v1'

class GoogleService
  CHAT_MODEL = 'gemini-1.5-flash'
  EMBEDDING_MODEL = 'text-embedding-004'
  
  # Pricing per 1M tokens (as of 2024)
  PRICING = {
    'gemini-1.5-flash' => { input: 0.075, output: 0.30 },
    'text-embedding-004' => { input: 0.025 }
  }.freeze

  def initialize(ai_setting)
    @ai_setting = ai_setting
    @api_key = ai_setting.api_key
  end

  def get_embedding(text)
    # Google AI Platform embedding endpoint
    url = "https://generativelanguage.googleapis.com/v1beta/models/#{EMBEDDING_MODEL}:embedContent"
    
    payload = {
      content: {
        parts: [{ text: text }]
      }
    }
    
    response = make_request(url, payload)
    
    if response['error']
      raise "Google AI Error: #{response['error']['message']}"
    end

    embedding = response.dig('embedding', 'values')
    tokens_used = estimate_tokens(text)
    
    # Calculate cost
    cost = calculate_cost(tokens_used, EMBEDDING_MODEL, 'input')
    AiService.update_usage(@ai_setting.provider, cost)

    {
      embedding: embedding,
      tokens_used: tokens_used,
      cost: cost,
      model: EMBEDDING_MODEL
    }
  rescue => e
    Rails.logger.error "Google AI Embedding Error: #{e.message}"
    raise "Failed to get embedding: #{e.message}"
  end

  def chat_completion(messages)
    url = "https://generativelanguage.googleapis.com/v1beta/models/#{CHAT_MODEL}:generateContent"
    
    # Convert OpenAI format to Google format
    google_messages = convert_messages(messages)
    
    payload = {
      contents: google_messages,
      generationConfig: {
        maxOutputTokens: 1000,
        temperature: 0.7
      }
    }
    
    response = make_request(url, payload)
    
    if response['error']
      raise "Google AI Error: #{response['error']['message']}"
    end

    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    input_tokens = response.dig('usageMetadata', 'promptTokenCount') || estimate_tokens(messages.map { |m| m[:content] || m['content'] }.join(' '))
    output_tokens = response.dig('usageMetadata', 'candidatesTokenCount') || estimate_tokens(content || '')
    
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
    Rails.logger.error "Google AI Chat Error: #{e.message}"
    raise "Failed to get chat completion: #{e.message}"
  end

  def estimate_cost(text, operation = 'chat')
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

  def make_request(url, payload)
    uri = URI(url)
    uri.query = URI.encode_www_form(key: @api_key)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json
    
    response = http.request(request)
    JSON.parse(response.body)
  end

  def convert_messages(openai_messages)
    google_messages = []
    
    openai_messages.each do |msg|
      role = msg[:role] || msg['role']
      content = msg[:content] || msg['content']
      
      case role
      when 'system'
        # Google handles system messages as user messages with special formatting
        google_messages << {
          role: 'user',
          parts: [{ text: "System: #{content}" }]
        }
      when 'user'
        google_messages << {
          role: 'user',
          parts: [{ text: content }]
        }
      when 'assistant'
        google_messages << {
          role: 'model',
          parts: [{ text: content }]
        }
      end
    end
    
    google_messages
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