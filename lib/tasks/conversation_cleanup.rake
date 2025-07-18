# frozen_string_literal: true

namespace :conversations do
  desc "Clean up expired conversations and their messages"
  task cleanup: :environment do
    puts "🧹 Starting conversation cleanup..."
    
    # 만료된 대화 찾기
    expired_conversations = Conversation.expired.includes(:messages)
    expired_count = expired_conversations.count
    
    if expired_count == 0
      puts "✅ No expired conversations found."
      next
    end
    
    puts "📊 Found #{expired_count} expired conversations"
    
    # 메시지 수 계산
    total_messages = expired_conversations.sum { |conv| conv.messages.count }
    puts "📊 Total messages to be deleted: #{total_messages}"
    
    # 삭제 실행 (dependent: :destroy로 메시지도 함께 삭제됨)
    deleted_count = 0
    expired_conversations.find_each do |conversation|
      message_count = conversation.messages.count
      conversation.destroy!
      deleted_count += 1
      
      puts "🗑️  Deleted conversation #{conversation.id} (#{message_count} messages)"
    end
    
    puts "✅ Cleanup completed!"
    puts "📊 Summary:"
    puts "   - Deleted conversations: #{deleted_count}"
    puts "   - Deleted messages: #{total_messages}"
    puts "   - Remaining active conversations: #{Conversation.active.count}"
  end

  desc "Show conversation statistics"
  task stats: :environment do
    puts "📊 Conversation Statistics"
    puts "=" * 50
    
    total_conversations = Conversation.count
    active_conversations = Conversation.active.count
    expired_conversations = Conversation.expired.count
    total_messages = Message.count
    
    puts "Total conversations: #{total_conversations}"
    puts "Active conversations: #{active_conversations}"
    puts "Expired conversations: #{expired_conversations}"
    puts "Total messages: #{total_messages}"
    
    if total_conversations > 0
      puts "\n📈 Breakdown by age:"
      
      # 나이별 분류
      today = Conversation.where('created_at >= ?', 1.day.ago).count
      week = Conversation.where('created_at >= ? AND created_at < ?', 1.week.ago, 1.day.ago).count
      month = Conversation.where('created_at >= ? AND created_at < ?', 1.month.ago, 1.week.ago).count
      older = Conversation.where('created_at < ?', 1.month.ago).count
      
      puts "  - Last 24 hours: #{today}"
      puts "  - Last week: #{week}"
      puts "  - Last month: #{month}"
      puts "  - Older: #{older}"
      
      puts "\n💬 Message statistics:"
      avg_messages = total_messages.to_f / total_conversations
      puts "  - Average messages per conversation: #{avg_messages.round(2)}"
      
      # 가장 활발한 대화들
      top_conversations = Conversation.joins(:messages)
                                    .group('conversations.id')
                                    .order('COUNT(messages.id) DESC')
                                    .limit(5)
                                    .pluck('conversations.id', 'conversations.title', 'COUNT(messages.id)')
      
      if top_conversations.any?
        puts "\n🏆 Most active conversations:"
        top_conversations.each_with_index do |(id, title, count), index|
          puts "  #{index + 1}. #{title} (ID: #{id}) - #{count} messages"
        end
      end
    end
  end

  desc "Force cleanup all conversations older than specified days (DANGEROUS)"
  task :force_cleanup, [:days] => :environment do |t, args|
    days = args[:days]&.to_i || 30
    
    puts "⚠️  WARNING: This will delete ALL conversations older than #{days} days!"
    puts "⚠️  This action cannot be undone!"
    
    if Rails.env.production?
      puts "❌ This task cannot be run in production environment for safety."
      next
    end
    
    old_conversations = Conversation.where('created_at < ?', days.days.ago)
    count = old_conversations.count
    
    if count == 0
      puts "✅ No conversations older than #{days} days found."
      next
    end
    
    puts "📊 Found #{count} conversations to delete"
    
    # 확인 없이 삭제 (rake 태스크이므로)
    old_conversations.destroy_all
    
    puts "✅ Force cleanup completed!"
    puts "📊 Deleted #{count} conversations"
  end
end