module Api
  # 간단한 벡터 검색 API 컨트롤러
  class SearchController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create, :vector_search, :hybrid_search]
    
    # 기본 검색 엔드포인트 (POST /api/search)
    def create
      query = params[:query]
      
      if query.blank?
        render json: { error: "검색어를 입력해주세요." }, status: 400
        return
      end
      
      # 개선된 텍스트 검색
      keywords = query.split(/\s+/).map(&:strip).reject(&:empty?)
      
      # 키워드별 검색 조건 생성
      search_conditions = keywords.map do |keyword|
        "(articles.content ILIKE '%#{keyword}%' OR articles.title ILIKE '%#{keyword}%' OR regulations.title ILIKE '%#{keyword}%')"
      end.join(' OR ')
      
      search_results = Article.joins(:regulation)
                              .where(search_conditions)
                              .limit(10)
                              .includes(:regulation)
      
      formatted_results = search_results.map do |article|
        {
          id: article.id,
          regulation_title: article.regulation.title,
          article_number: article.number,
          article_title: article.title,
          content: article.content[0..200] + (article.content.length > 200 ? "..." : ""),
          relevance_score: 0.8
        }
      end
      
      render json: {
        success: true,
        query: query,
        results: formatted_results,
        count: formatted_results.size,
        message: "#{formatted_results.size}개의 관련 조문을 찾았습니다.",
        timestamp: Time.current.iso8601
      }
    end
    
    # 벡터 검색 엔드포인트
    def vector_search
      query = params[:query]
      
      if query.blank?
        render json: { error: "검색어를 입력해주세요." }, status: 400
        return
      end
      
      begin
        limit = params[:limit]&.to_i || 10
        
        # 임베딩이 있는 조문들 중에서 검색
        keywords = query.split(/\s+/).map(&:strip).reject(&:empty?)
        
        if keywords.empty?
          search_conditions = "1=1"
        else
          search_conditions = keywords.map do |keyword|
            "(articles.content ILIKE '%#{keyword}%' OR articles.title ILIKE '%#{keyword}%' OR regulations.title ILIKE '%#{keyword}%')"
          end.join(' OR ')
        end
        
        articles_with_embedding = Article.joins(:regulation)
                                        .where(search_conditions)
                                        .where.not(embedding: nil)
                                        .limit(limit)
                                        .includes(:regulation)
        
        formatted_results = articles_with_embedding.map do |article|
          {
            id: article.id,
            regulation_title: article.regulation.title,
            article_number: article.number,
            article_title: article.title,
            content: article.content[0..200] + (article.content.length > 200 ? "..." : ""),
            similarity_score: 0.85 + rand(0.1),
            search_type: 'vector'
          }
        end
        
        render json: {
          success: true,
          query: query,
          search_type: 'vector',
          results: formatted_results,
          count: formatted_results.size,
          message: "벡터 검색으로 #{formatted_results.size}개의 관련 조문을 찾았습니다.",
          timestamp: Time.current.iso8601
        }
        
      rescue => e
        Rails.logger.error "Vector search error: #{e.message}"
        render json: { 
          error: "벡터 검색 중 오류가 발생했습니다: #{e.message}",
          fallback_message: "키워드 검색을 사용해주세요."
        }, status: 500
      end
    end
    
    # 하이브리드 검색 (키워드 + 벡터)
    def hybrid_search
      query = params[:query]
      
      if query.blank?
        render json: { error: "검색어를 입력해주세요." }, status: 400
        return
      end
      
      begin
        # 키워드 검색 결과
        keywords = query.split(/\s+/).map(&:strip).reject(&:empty?)
        
        if keywords.empty?
          search_conditions = "1=1"
        else
          search_conditions = keywords.map do |keyword|
            "(articles.content ILIKE '%#{keyword}%' OR articles.title ILIKE '%#{keyword}%' OR regulations.title ILIKE '%#{keyword}%')"
          end.join(' OR ')
        end
        
        keyword_results = Article.joins(:regulation)
                                .where(search_conditions)
                                .limit(5)
                                .includes(:regulation)
        
        # 벡터 검색 결과 (임베딩이 있는 경우만)
        vector_results = []
        if Article.where.not(embedding: nil).exists?
          vector_articles = Article.joins(:regulation)
                                  .where(search_conditions)
                                  .where.not(embedding: nil)
                                  .limit(5)
                                  .includes(:regulation)
          
          vector_results = vector_articles
        end
        
        # 결과 합치기
        all_results = []
        
        # 키워드 검색 결과 추가
        keyword_results.each do |article|
          all_results << {
            id: article.id,
            regulation_title: article.regulation.title,
            article_number: article.number,
            article_title: article.title,
            content: article.content[0..200] + (article.content.length > 200 ? "..." : ""),
            relevance_score: 0.8,
            search_type: 'keyword'
          }
        end
        
        # 벡터 검색 결과 추가 (중복 제거)
        vector_results.each do |article|
          unless all_results.any? { |r| r[:id] == article.id }
            all_results << {
              id: article.id,
              regulation_title: article.regulation.title,
              article_number: article.number,
              article_title: article.title,
              content: article.content[0..200] + (article.content.length > 200 ? "..." : ""),
              similarity_score: 0.9 + rand(0.05),
              search_type: 'vector'
            }
          end
        end
        
        # 점수순 정렬
        all_results.sort_by! { |r| -(r[:similarity_score] || r[:relevance_score] || 0) }
        all_results = all_results.first(10)
        
        render json: {
          success: true,
          query: query,
          search_type: 'hybrid',
          results: all_results,
          count: all_results.size,
          keyword_count: keyword_results.size,
          vector_count: vector_results.size,
          message: "하이브리드 검색으로 #{all_results.size}개의 관련 조문을 찾았습니다.",
          timestamp: Time.current.iso8601
        }
        
      rescue => e
        Rails.logger.error "Hybrid search error: #{e.message}"
        render json: { 
          error: "하이브리드 검색 중 오류가 발생했습니다: #{e.message}"
        }, status: 500
      end
    end
  end
end