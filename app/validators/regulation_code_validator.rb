class RegulationCodeValidator < ActiveModel::EachValidator
  # Validates regulation code format: X-Y-Z (edition-chapter-regulation)
  def validate_each(record, attribute, value)
    return if value.blank?
    
    unless value.match?(/\A\d+-\d+-\d+\z/)
      record.errors.add(attribute, 'must be in format X-Y-Z (edition-chapter-regulation)')
      return
    end
    
    parts = value.split('-')
    edition_num, chapter_num, regulation_num = parts.map(&:to_i)
    
    # Validate edition number (1-6)
    unless (1..6).include?(edition_num)
      record.errors.add(attribute, 'edition number must be between 1 and 6')
    end
    
    # Validate chapter and regulation numbers are positive
    unless chapter_num > 0 && regulation_num > 0
      record.errors.add(attribute, 'chapter and regulation numbers must be positive')
    end
    
    # Validate consistency with actual chapter relationship
    if record.chapter_id.present?
      chapter = record.chapter
      if chapter&.edition&.number != edition_num || chapter&.number != chapter_num
        record.errors.add(attribute, 'does not match chapter hierarchy')
      end
    end
  end
end