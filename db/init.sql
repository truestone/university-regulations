-- pgvector 확장 초기화
CREATE EXTENSION IF NOT EXISTS vector;

-- 확장 설치 확인
SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';
