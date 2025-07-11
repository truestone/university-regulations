# frozen_string_literal: true

namespace :embedding do
  desc "Generate embeddings for all articles"
  task :generate_all => :environment do
    puts "🚀 모든 조문에 대한 임베딩 생성 시작"
    puts "=" * 60
    
    total_articles = Article.count
    processed = 0
    
    if total_articles == 0
      puts "❌ 임베딩을 생성할 조문이 없습니다."
      exit 0
    end
    
    puts "📊 총 #{total_articles}개 조문에 대한 임베딩 생성을 시작합니다."
    
    Article.find_each(batch_size: 100) do |article|
      if article.needs_embedding_update?
        EmbeddingJob.perform_async(article.id)
        processed += 1
        
        if processed % 10 == 0
          puts "  진행률: #{processed}/#{total_articles} (#{(processed.to_f / total_articles * 100).round(1)}%)"
        end
      end
    end
    
    puts "\n✅ #{processed}개 조문에 대한 임베딩 생성 작업을 큐에 추가했습니다."
    puts "📋 Sidekiq 대시보드에서 진행 상황을 확인할 수 있습니다."
  end

  desc "Generate embeddings for articles without embeddings"
  task :generate_missing => :environment do
    puts "🔍 임베딩이 없는 조문에 대한 임베딩 생성"
    puts "=" * 50
    
    articles_without_embedding = Article.where(embedding: nil)
    total_count = articles_without_embedding.count
    
    if total_count == 0
      puts "✅ 모든 조문에 임베딩이 이미 생성되어 있습니다."
      exit 0
    end
    
    puts "📊 임베딩이 없는 조문: #{total_count}개"
    
    articles_without_embedding.find_each(batch_size: 50) do |article|
      EmbeddingJob.perform_async(article.id)
    end
    
    puts "✅ #{total_count}개 조문에 대한 임베딩 생성 작업을 큐에 추가했습니다."
  end

  desc "Update embeddings for recently modified articles"
  task :update_modified => :environment do
    puts "🔄 최근 수정된 조문의 임베딩 업데이트"
    puts "=" * 50
    
    # 최근 24시간 내 수정된 조문 중 임베딩 업데이트가 필요한 것들
    recently_modified = Article.where('updated_at > ?', 24.hours.ago)
                              .select(&:needs_embedding_update?)
    
    if recently_modified.empty?
      puts "✅ 업데이트가 필요한 조문이 없습니다."
      exit 0
    end
    
    puts "📊 업데이트가 필요한 조문: #{recently_modified.size}개"
    
    recently_modified.each do |article|
      EmbeddingJob.perform_async(article.id)
    end
    
    puts "✅ #{recently_modified.size}개 조문에 대한 임베딩 업데이트 작업을 큐에 추가했습니다."
  end

  desc "Check embedding generation status"
  task :status => :environment do
    puts "📊 임베딩 생성 현황"
    puts "=" * 40
    
    total_articles = Article.count
    with_embedding = Article.where.not(embedding: nil).count
    without_embedding = total_articles - with_embedding
    
    puts "총 조문 수: #{total_articles}"
    puts "임베딩 있음: #{with_embedding} (#{(with_embedding.to_f / total_articles * 100).round(1)}%)"
    puts "임베딩 없음: #{without_embedding} (#{(without_embedding.to_f / total_articles * 100).round(1)}%)"
    
    # 최근 임베딩 생성 통계
    recent_embeddings = Article.where('embedding_updated_at > ?', 24.hours.ago).count
    puts "최근 24시간 내 생성: #{recent_embeddings}개"
    
    # Sidekiq 큐 상태
    begin
      require 'sidekiq/api'
      embedding_queue = Sidekiq::Queue.new('embedding')
      puts "대기 중인 임베딩 작업: #{embedding_queue.size}개"
    rescue => e
      puts "Sidekiq 큐 상태 확인 실패: #{e.message}"
    end
  end

  desc "Test embedding generation for a single article"
  task :test, [:article_id] => :environment do |task, args|
    article_id = args[:article_id]
    
    unless article_id
      puts "❌ 사용법: rails embedding:test[ARTICLE_ID]"
      exit 1
    end
    
    article = Article.find_by(id: article_id)
    unless article
      puts "❌ ID #{article_id}인 조문을 찾을 수 없습니다."
      exit 1
    end
    
    puts "🧪 조문 #{article_id} 임베딩 생성 테스트"
    puts "=" * 50
    puts "제목: #{article.title}"
    puts "내용: #{article.content[0..100]}..."
    puts "컨텍스트: #{article.embedding_context}"
    puts ""
    
    # 동기적으로 임베딩 생성 (테스트용)
    begin
      EmbeddingJob.new.perform(article_id)
      puts "✅ 임베딩 생성 성공!"
      
      article.reload
      puts "임베딩 차원: #{article.embedding&.length}"
      puts "생성 시간: #{article.embedding_updated_at}"
      
    rescue => e
      puts "❌ 임베딩 생성 실패: #{e.message}"
      puts e.backtrace.first(3)
    end
  end

  desc "Clean up old embedding jobs"
  task :cleanup => :environment do
    puts "🗑️ 오래된 임베딩 작업 정리"
    puts "=" * 40
    
    begin
      require 'sidekiq/api'
      
      # 실패한 작업 정리
      failed_set = Sidekiq::FailedSet.new
      embedding_failures = failed_set.select { |job| job.klass == 'EmbeddingJob' }
      
      if embedding_failures.any?
        puts "실패한 임베딩 작업 #{embedding_failures.size}개 발견"
        
        embedding_failures.each do |job|
          # 24시간 이상 된 실패 작업 삭제
          if job.failed_at < 24.hours.ago
            job.delete
          end
        end
        
        puts "✅ 오래된 실패 작업 정리 완료"
      else
        puts "✅ 정리할 실패 작업이 없습니다."
      end
      
    rescue => e
      puts "❌ 정리 작업 실패: #{e.message}"
    end
  end

  desc "Show embedding help"
  task :help do
    puts "🤖 임베딩 생성 도구 사용법"
    puts "=" * 50
    puts ""
    puts "사용 가능한 작업:"
    puts ""
    puts "1. 모든 조문 임베딩 생성:"
    puts "   rails embedding:generate_all"
    puts ""
    puts "2. 임베딩이 없는 조문만 생성:"
    puts "   rails embedding:generate_missing"
    puts ""
    puts "3. 최근 수정된 조문 업데이트:"
    puts "   rails embedding:update_modified"
    puts ""
    puts "4. 임베딩 생성 현황 확인:"
    puts "   rails embedding:status"
    puts ""
    puts "5. 단일 조문 테스트:"
    puts "   rails embedding:test[ARTICLE_ID]"
    puts ""
    puts "6. 오래된 작업 정리:"
    puts "   rails embedding:cleanup"
    puts ""
    puts "7. 도움말:"
    puts "   rails embedding:help"
    puts ""
    puts "💡 팁:"
    puts "- Sidekiq 워커가 실행 중이어야 임베딩이 생성됩니다."
    puts "- OpenAI API 키가 설정되어 있어야 합니다."
    puts "- 대량 생성 시 API 요금에 주의하세요."
    puts ""
  end
end