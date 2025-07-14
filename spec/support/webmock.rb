# frozen_string_literal: true

require 'webmock/rspec'

# Configure WebMock
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before(:each) do
    # Reset WebMock before each test
    WebMock.reset!
    
    # Stub OpenAI API calls by default
    stub_openai_embeddings_api
  end
end

def stub_openai_embeddings_api(response: nil)
  response ||= {
    'data' => [
      {
        'embedding' => Array.new(1536, 0.1),
        'index' => 0,
        'object' => 'embedding'
      }
    ],
    'model' => 'text-embedding-3-small',
    'object' => 'list',
    'usage' => {
      'prompt_tokens' => 10,
      'total_tokens' => 10
    }
  }

  stub_request(:post, 'https://api.openai.com/v1/embeddings')
    .to_return(
      status: 200,
      body: response.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
end

def stub_openai_embeddings_api_error(status: 500, message: 'Internal Server Error')
  stub_request(:post, 'https://api.openai.com/v1/embeddings')
    .to_return(
      status: status,
      body: { error: { message: message } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
end

def stub_openai_chat_completions_api(response: nil)
  response ||= {
    'choices' => [
      {
        'message' => {
          'role' => 'assistant',
          'content' => 'This is a test response from GPT.'
        },
        'finish_reason' => 'stop',
        'index' => 0
      }
    ],
    'model' => 'gpt-4',
    'object' => 'chat.completion',
    'usage' => {
      'prompt_tokens' => 20,
      'completion_tokens' => 10,
      'total_tokens' => 30
    }
  }

  stub_request(:post, 'https://api.openai.com/v1/chat/completions')
    .to_return(
      status: 200,
      body: response.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
end