class EmbeddingValidator < ActiveModel::EachValidator
  # Validates embedding vector format and dimensions
  def validate_each(record, attribute, value)
    return if value.blank? && options[:allow_blank]
    
    if value.present?
      # Check if it's a valid vector format (array of floats)
      begin
        if value.is_a?(String)
          # Parse string representation of vector
          parsed = JSON.parse(value) if value.start_with?('[')
          unless parsed.is_a?(Array) && parsed.all? { |v| v.is_a?(Numeric) }
            record.errors.add(attribute, 'must be a valid vector array')
            return
          end
          
          # Check dimensions (should be 1536 for OpenAI embeddings)
          expected_dim = options[:dimensions] || 1536
          unless parsed.length == expected_dim
            record.errors.add(attribute, "must have exactly #{expected_dim} dimensions")
          end
        end
      rescue JSON::ParserError
        record.errors.add(attribute, 'must be a valid JSON array')
      end
    end
  end
end