# frozen_string_literal: true

module Api
  # 벡터 검색 API 컨트롤러
  class SearchController < ApplicationController
    before_action :validate_search_params, only: [:vector_search, :hybrid_search]
    
    # 벡터 유사도 검색
    def vector_search
      search_service = VectorSearchService.new(search_params[:query], search_options)
      results = search_service.search
      
      render json: {
        success: true,
        query: search_params[:query],
        results: format_search_results(results),
        stats: search_service.search_stats,
        timestamp: Time.current.iso8601
      }
    end

    # 하이브리드 검색 (벡터 + 키워드)
    def hybrid_search
      search_service = VectorSearchService.new(search_params[:query], search_options)
      results = search_service.hybrid_search
      
      render json: {
        success: true,
        query: search_params[:query],
        results: format_hybrid_results(results),
        stats: search_service.search_stats,
        timestamp: Time.current.iso8601
      }
    end

    # 유사 조문 검색
    def similar_articles
      article_id = params[:article_id]
      limit = [params[:limit].to_i, 20].min
      limit = 5 if limit <= 0
      
      article = Article.find(article_id)
      search_service = VectorSearchService.new('')
      similar_articles = search_service.find_similar_articles(article_id, limit: limit)
      
      render json: {
        success: true,
        source_article: format_article_summary(article),
        similar_articles: format_similar_articles(similar_articles),
        count: similar_articles.size,
        timestamp: Time.current.iso8601
      }
      
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        error: "Article with ID #{article_id} not found"
      }, status: 404
    end

    # 검색 제안 (자동완성)
    def suggestions
      query = params[:query].to_s.strip
      
      if query.length < 2
        render json: { suggestions: [] }
        return
      end
      
      # 제목과 내용에서 부분 일치하는 조문들의 제목 추출
      suggestions = Article.joins(:regulation)
                          .where('articles.title ILIKE ? OR articles.content ILIKE ?', 
                                 "%#{query}%", "%#{query}%")
                          .where(is_active: true)
                          .limit(10)
                          .pluck(:title)
                          .uniq
                          .sort
      
      render json: { suggestions: suggestions }
    end

    # 검색 통계
    def stats
      stats = {
        total_articles: Article.where(is_active: true).count,
        articles_with_embeddings: Article.where(is_active: true).where.not(embedding: nil).count,
        recent_searches: get_recent_search_stats,
        popular_queries: get_popular_queries
      }
      
      render json: {
        success: true,
        stats: stats,
        timestamp: Time.current.iso8601
      }
    end

    private

    def search_params
      params.permit(:query, :limit, :similarity_threshold, :include_context, :boost_recent, :filter_active_only)
    end

    def search_options
      options = {}
      
      options[:limit] = [search_params[:limit].to_i, 50].min if search_params[:limit].present?
      options[:limit] = 10 if options[:limit] <= 0
      
      if search_params[:similarity_threshold].present?
        threshold = search_params[:similarity_threshold].to_f
        options[:similarity_threshold] = [[threshold, 0.0].max, 1.0].min
      end
      
      options[:include_context] = search_params[:include_context] != 'false'
      options[:boost_recent] = search_params[:boost_recent] == 'true'
      options[:filter_active_only] = search_params[:filter_active_only] != 'false'
      
      options
    end

    def validate_search_params
      if search_params[:query].blank?
        render json: {
          success: false,
          error: "Query parameter is required"
        }, status: 400
        return
      end
      
      if search_params[:query].length > 1000
        render json: {
          success: false,
          error: "Query is too long (maximum 1000 characters)"
        }, status: 400
        return
      end
    end

    def format_search_results(results)
      results.map do |article|
        {
          id: article.id,
          title: article.title,
          content: truncate_content(article.content),
          highlighted_content: article.respond_to?(:highlighted_content) ? article.highlighted_content : nil,
          similarity_score: article.respond_to?(:similarity_score) ? article.similarity_score : nil,
          context_path: article.respond_to?(:context_path) ? article.context_path : nil,
          regulation: {
            title: article.respond_to?(:regulation_title) ? article.regulation_title : article.regulation&.title,
            code: article.respond_to?(:regulation_code) ? article.regulation_code : article.regulation&.regulation_code
          },
          article_number: article.number,
          updated_at: article.updated_at.iso8601
        }
      end
    end

    def format_hybrid_results(results)
      results.map do |article|
        {
          id: article.id,
          title: article.title,
          content: truncate_content(article.content),
          highlighted_content: article.respond_to?(:highlighted_content) ? article.highlighted_content : nil,
          scores: {
            vector: article.respond_to?(:vector_score) ? article.vector_score : nil,
            keyword: article.respond_to?(:keyword_score) ? article.keyword_score : nil,
            combined: article.respond_to?(:combined_score) ? article.combined_score : nil
          },
          ranks: {
            vector: article.respond_to?(:vector_rank) ? article.vector_rank : nil,
            keyword: article.respond_to?(:keyword_rank) ? article.keyword_rank : nil
          },
          context_path: article.respond_to?(:context_path) ? article.context_path : nil,
          regulation: {
            title: article.respond_to?(:regulation_title) ? article.regulation_title : article.regulation&.title,
            code: article.respond_to?(:regulation_code) ? article.regulation_code : article.regulation&.regulation_code
          },
          article_number: article.number,
          updated_at: article.updated_at.iso8601
        }
      end
    end

    def format_similar_articles(articles)
      articles.map do |article|
        {
          id: article.id,
          title: article.title,
          content: truncate_content(article.content),
          similarity_score: article.respond_to?(:similarity_score) ? article.similarity_score : nil,
          regulation: {
            title: article.respond_to?(:regulation_title) ? article.regulation_title : article.regulation&.title,
            code: article.respond_to?(:regulation_code) ? article.regulation_code : article.regulation&.regulation_code
          },
          article_number: article.number,
          updated_at: article.updated_at.iso8601
        }
      end
    end

    def format_article_summary(article)
      {
        id: article.id,
        title: article.title,
        content: truncate_content(article.content),
        regulation: {
          title: article.regulation&.title,
          code: article.regulation&.regulation_code
        },
        article_number: article.number
      }
    end

    def truncate_content(content, length: 200)
      return content if content.blank? || content.length <= length
      
      "#{content[0...length]}..."
    end

    def get_recent_search_stats
      # 실제 구현에서는 검색 로그를 저장하고 분석
      # 여기서는 더미 데이터 반환
      {
        last_24_hours: 0,
        last_week: 0,
        last_month: 0
      }
    end

    def get_popular_queries
      # 실제 구현에서는 검색 로그에서 인기 쿼리 추출
      # 여기서는 더미 데이터 반환
      []
    end
  end
end