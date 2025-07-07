# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Starting seed data creation..."

# Clear existing data in development/test environments
if Rails.env.development? || Rails.env.test?
  puts "🧹 Cleaning existing data..."
  [Message, Conversation, Clause, Article, Regulation, Chapter, Edition, User, AiSetting].each do |model|
    model.delete_all
  end
  
  # Reset sequences
  ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('users', 'id'), 1, false)")
  ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('editions', 'id'), 1, false)")
  ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('chapters', 'id'), 1, false)")
  ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('regulations', 'id'), 1, false)")
  ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('articles', 'id'), 1, false)")
  ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('clauses', 'id'), 1, false)")
  ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('conversations', 'id'), 1, false)")
  ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('messages', 'id'), 1, false)")
  ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('ai_settings', 'id'), 1, false)")
end

# 1. Create Admin Users
puts "👤 Creating admin users..."
admin_user = User.create!(
  email: 'admin@regulations.edu',
  password: 'password123',
  name: 'System Administrator',
  role: 'super_admin',
  last_login_at: 1.day.ago
)

regular_admin = User.create!(
  email: 'editor@regulations.edu', 
  password: 'password123',
  name: 'Regulation Editor',
  role: 'admin',
  last_login_at: 2.hours.ago
)

puts "✅ Created #{User.count} users"

# 2. Create AI Settings
puts "🤖 Creating AI settings..."
openai_setting = AiSetting.create!(
  provider: 'openai',
  model_id: 'gpt-4',
  api_key: 'sk-test-key-openai',
  monthly_budget: 1000.00,
  usage_this_month: 250.50,
  is_active: true,
  last_used_at: 1.hour.ago
)

anthropic_setting = AiSetting.create!(
  provider: 'anthropic',
  model_id: 'claude-3-sonnet',
  monthly_budget: 500.00,
  usage_this_month: 0.00,
  is_active: false
)

google_setting = AiSetting.create!(
  provider: 'google',
  model_id: 'gemini-pro',
  api_key: 'test-key-google',
  monthly_budget: 300.00,
  usage_this_month: 75.25,
  is_active: true,
  last_used_at: 3.hours.ago
)

puts "✅ Created #{AiSetting.count} AI settings"

# 3. Create Editions (규정집 편)
puts "📚 Creating editions..."
editions_data = [
  { number: 1, title: '학교법인', description: '학교법인 관련 규정', sort_order: 1 },
  { number: 2, title: '학칙', description: '대학 학칙 및 기본 규정', sort_order: 2 },
  { number: 3, title: '행정규정', description: '대학 행정 관련 규정', sort_order: 3 },
  { number: 4, title: '위원회규정', description: '각종 위원회 운영 규정', sort_order: 4 },
  { number: 5, title: '부속기관', description: '부속기관 운영 규정', sort_order: 5 },
  { number: 6, title: '산학협력단', description: '산학협력단 관련 규정', sort_order: 6 }
]

editions = editions_data.map do |data|
  Edition.create!(data)
end

puts "✅ Created #{Edition.count} editions"

# 4. Create Chapters (장)
puts "📖 Creating chapters..."
chapters_data = [
  # 제1편 학교법인
  { edition: editions[0], number: 1, title: '정관', description: '학교법인 정관', sort_order: 1 },
  { edition: editions[0], number: 2, title: '이사회', description: '이사회 운영 규정', sort_order: 2 },
  
  # 제2편 학칙
  { edition: editions[1], number: 1, title: '학칙', description: '대학 학칙', sort_order: 1 },
  { edition: editions[1], number: 2, title: '학사운영', description: '학사 운영 규정', sort_order: 2 },
  
  # 제3편 행정규정
  { edition: editions[2], number: 1, title: '조직', description: '조직 및 직제', sort_order: 1 },
  { edition: editions[2], number: 2, title: '인사', description: '인사 관련 규정', sort_order: 2 }
]

chapters = chapters_data.map do |data|
  Chapter.create!(data)
end

puts "✅ Created #{Chapter.count} chapters"

# 5. Create Regulations (규정)
puts "📋 Creating regulations..."
regulations_data = [
  # 1-1 정관
  { chapter: chapters[0], number: 1, title: '학교법인 동의학원 정관', regulation_code: '1-1-1', status: 'active', sort_order: 1,
    content: '학교법인 동의학원의 설립 목적과 운영에 관한 기본 사항을 정한다.' },
  
  # 1-2 이사회
  { chapter: chapters[1], number: 1, title: '이사회 운영 규정', regulation_code: '1-2-1', status: 'active', sort_order: 1,
    content: '이사회의 구성, 운영 및 의사결정 절차에 관한 사항을 정한다.' },
  
  # 2-1 학칙
  { chapter: chapters[2], number: 1, title: '동의대학교 학칙', regulation_code: '2-1-1', status: 'active', sort_order: 1,
    content: '동의대학교의 교육 목적, 조직, 학사 운영에 관한 기본 사항을 정한다.' },
  
  # 2-2 학사운영
  { chapter: chapters[3], number: 1, title: '학사운영 규정', regulation_code: '2-2-1', status: 'active', sort_order: 1,
    content: '학사 과정의 입학, 수업, 시험, 졸업에 관한 세부 사항을 정한다.' },
  
  # 3-1 조직
  { chapter: chapters[4], number: 1, title: '조직 및 직제 규정', regulation_code: '3-1-1', status: 'active', sort_order: 1,
    content: '대학의 조직 구성과 각 부서의 업무 분장에 관한 사항을 정한다.' },
  
  # 3-2 인사
  { chapter: chapters[5], number: 1, title: '교직원 인사 규정', regulation_code: '3-2-1', status: 'active', sort_order: 1,
    content: '교직원의 채용, 승진, 전보, 징계에 관한 사항을 정한다.' }
]

regulations = regulations_data.map do |data|
  Regulation.create!(data)
end

puts "✅ Created #{Regulation.count} regulations"

# 6. Create Articles (조)
puts "📄 Creating articles..."
articles_data = [
  # 학교법인 정관 - 1-1-1
  { regulation: regulations[0], number: 1, title: '목적', sort_order: 1,
    content: '이 법인은 교육기본법 및 고등교육법에 따라 고등교육기관을 설치·경영함으로써 국가와 인류사회 발전에 필요한 인재를 양성함을 목적으로 한다.' },
  { regulation: regulations[0], number: 2, title: '명칭', sort_order: 2,
    content: '이 법인의 명칭은 학교법인 동의학원이라 한다.' },
  
  # 이사회 운영 규정 - 1-2-1
  { regulation: regulations[1], number: 1, title: '구성', sort_order: 1,
    content: '이사회는 이사장 1명을 포함하여 7명 이상 11명 이하의 이사로 구성한다.' },
  
  # 동의대학교 학칙 - 2-1-1
  { regulation: regulations[2], number: 1, title: '목적', sort_order: 1,
    content: '동의대학교는 교육기본법과 고등교육법에 따라 학술의 이론과 응용방법을 교수·연구하고 인격을 도야하여 국가와 인류사회 발전에 기여할 수 있는 인재양성을 목적으로 한다.' },
  { regulation: regulations[2], number: 2, title: '자주성', sort_order: 2,
    content: '본 대학교는 학문의 자유와 대학의 자율성을 바탕으로 진리탐구와 지식창조에 매진한다.' },
  
  # 학사운영 규정 - 2-2-1
  { regulation: regulations[3], number: 1, title: '입학자격', sort_order: 1,
    content: '본 대학교에 입학할 수 있는 자는 고등학교를 졸업한 자 또는 법령에 의하여 이와 동등 이상의 학력이 있다고 인정된 자로 한다.' },
  
  # 조직 및 직제 규정 - 3-1-1
  { regulation: regulations[4], number: 1, title: '조직', sort_order: 1,
    content: '본 대학교에 총장을 두고, 그 밑에 부총장, 대학원장, 단과대학장, 처장, 실장, 부서장을 둔다.' },
  
  # 교직원 인사 규정 - 3-2-1
  { regulation: regulations[5], number: 1, title: '적용범위', sort_order: 1,
    content: '이 규정은 본 대학교 교원 및 직원의 인사에 관하여 적용한다.' }
]

articles = articles_data.map do |data|
  Article.create!(data)
end

puts "✅ Created #{Article.count} articles"

# 7. Create Clauses (항)
puts "📝 Creating clauses..."
clauses_data = [
  # 학교법인 정관 제1조 목적
  { article: articles[0], number: 1, content: '이 법인은 교육기본법 제9조 및 고등교육법 제3조에 따라 설치된다.', clause_type: 'paragraph', sort_order: 1 },
  { article: articles[0], number: 2, content: '이 법인이 설치·경영하는 학교는 동의대학교로 한다.', clause_type: 'paragraph', sort_order: 2 },
  
  # 이사회 구성
  { article: articles[2], number: 1, content: '이사장은 이사회에서 호선한다.', clause_type: 'paragraph', sort_order: 1 },
  { article: articles[2], number: 2, content: '이사의 임기는 4년으로 하되 연임할 수 있다.', clause_type: 'paragraph', sort_order: 2 },
  
  # 대학교 목적
  { article: articles[3], number: 1, content: '본 대학교는 진리·창조·봉사의 건학이념을 바탕으로 한다.', clause_type: 'paragraph', sort_order: 1 },
  
  # 입학자격
  { article: articles[5], number: 1, content: '외국인의 경우 별도의 자격 요건을 적용할 수 있다.', clause_type: 'paragraph', sort_order: 1 }
]

clauses = clauses_data.map do |data|
  Clause.create!(data)
end

puts "✅ Created #{Clause.count} clauses"

# 8. Create Sample Conversations
puts "💬 Creating sample conversations..."
conversation1 = Conversation.create!(
  session_id: 'demo_session_001',
  title: '입학 관련 문의',
  last_message_at: 2.hours.ago,
  expires_at: 5.days.from_now
)

conversation2 = Conversation.create!(
  session_id: 'demo_session_002', 
  title: '학사 운영 규정 질문',
  last_message_at: 1.day.ago,
  expires_at: 6.days.from_now
)

# 9. Create Sample Messages
puts "💭 Creating sample messages..."
Message.create!([
  # Conversation 1
  { conversation: conversation1, role: 'user', content: '동의대학교 입학 자격이 어떻게 되나요?', tokens_used: 15 },
  { conversation: conversation1, role: 'assistant', content: '동의대학교에 입학할 수 있는 자는 고등학교를 졸업한 자 또는 법령에 의하여 이와 동등 이상의 학력이 있다고 인정된 자입니다. 외국인의 경우 별도의 자격 요건을 적용할 수 있습니다.', tokens_used: 85 },
  { conversation: conversation1, role: 'user', content: '외국인 입학 절차는 어떻게 되나요?', tokens_used: 18 },
  { conversation: conversation1, role: 'assistant', content: '외국인 입학에 대한 구체적인 절차는 학사운영 규정에 따라 별도로 정해집니다. 자세한 사항은 입학처에 문의하시기 바랍니다.', tokens_used: 65 },
  
  # Conversation 2  
  { conversation: conversation2, role: 'user', content: '대학교의 건학이념이 무엇인가요?', tokens_used: 16 },
  { conversation: conversation2, role: 'assistant', content: '동의대학교는 진리·창조·봉사의 건학이념을 바탕으로 합니다. 이는 학술의 이론과 응용방법을 교수·연구하고 인격을 도야하여 국가와 인류사회 발전에 기여할 수 있는 인재양성을 목적으로 합니다.', tokens_used: 95 }
])

puts "✅ Created #{Message.count} messages in #{Conversation.count} conversations"

puts "🌱 Seed data creation completed successfully!"
puts "📊 Final counts:"
puts "   Users: #{User.count}"
puts "   AI Settings: #{AiSetting.count}"
puts "   Editions: #{Edition.count}"
puts "   Chapters: #{Chapter.count}"
puts "   Regulations: #{Regulation.count}"
puts "   Articles: #{Article.count}"
puts "   Clauses: #{Clause.count}"
puts "   Conversations: #{Conversation.count}"
puts "   Messages: #{Message.count}"