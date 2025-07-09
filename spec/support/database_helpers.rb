# frozen_string_literal: true

module DatabaseHelpers
  # DB 인덱스 존재 여부를 확인하는 헬퍼 메서드
  def index_exists?(table_name, column_names)
    connection = ActiveRecord::Base.connection
    indexes = connection.indexes(table_name)
    
    case column_names
    when String, Symbol
      # 단일 컬럼 인덱스
      indexes.any? { |index| index.columns == [column_names.to_s] }
    when Array
      # 복합 인덱스
      column_names_str = column_names.map(&:to_s)
      indexes.any? { |index| index.columns == column_names_str }
    else
      false
    end
  end

  # 특정 타입의 인덱스 존재 여부 확인 (예: vector 인덱스)
  def vector_index_exists?(table_name, column_name)
    connection = ActiveRecord::Base.connection
    indexes = connection.indexes(table_name)
    
    indexes.any? do |index|
      index.columns.include?(column_name.to_s) && 
      index.using&.to_s&.downcase == 'ivfflat'
    end
  end

  # 외래키 제약조건 존재 여부 확인
  def foreign_key_exists?(from_table, to_table, column: nil)
    connection = ActiveRecord::Base.connection
    foreign_keys = connection.foreign_keys(from_table)
    
    if column
      foreign_keys.any? { |fk| fk.column == column.to_s && fk.to_table == to_table.to_s }
    else
      foreign_keys.any? { |fk| fk.to_table == to_table.to_s }
    end
  end

  # 확장(extension) 활성화 여부 확인
  def extension_enabled?(extension_name)
    connection = ActiveRecord::Base.connection
    result = connection.execute("SELECT 1 FROM pg_extension WHERE extname = '#{extension_name}'")
    result.any?
  end

  # 테이블 존재 여부 확인
  def table_exists?(table_name)
    ActiveRecord::Base.connection.table_exists?(table_name)
  end

  # 컬럼 존재 여부 및 타입 확인
  def column_exists_with_type?(table_name, column_name, expected_type)
    return false unless ActiveRecord::Base.connection.column_exists?(table_name, column_name)
    
    column = ActiveRecord::Base.connection.columns(table_name).find { |c| c.name == column_name.to_s }
    column&.type&.to_s == expected_type.to_s
  end
end

RSpec.configure do |config|
  config.include DatabaseHelpers
end