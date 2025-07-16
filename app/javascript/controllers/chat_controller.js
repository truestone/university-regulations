import { Controller } from "@hotwired/stimulus"

// 채팅 인터페이스 Stimulus 컨트롤러
export default class extends Controller {
  static targets = ["messages", "input", "submit", "form", "loadingIndicator"]
  static values = { conversationId: String }

  connect() {
    this.scrollToBottom()
    this.focusInput()
    this.startConnectionCheck()
    this.setupNetworkListeners()
    this.isSubmitting = false
    
    // 이벤트 핸들러 바인딩 저장 (메모리 누수 방지)
    this.boundHandleSubmitStart = this.handleSubmitStart.bind(this)
    this.boundHandleSubmitEnd = this.handleSubmitEnd.bind(this)
    this.boundHandleBeforeFetch = this.handleBeforeFetch.bind(this)
    this.boundHandleError = this.handleError.bind(this)
    this.boundHandleOnline = this.handleOnline.bind(this)
    this.boundHandleOffline = this.handleOffline.bind(this)
    
    // 폼 제출 이벤트 리스너 추가
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('turbo:submit-start', this.boundHandleSubmitStart)
      this.formTarget.addEventListener('turbo:submit-end', this.boundHandleSubmitEnd)
      this.formTarget.addEventListener('turbo:before-fetch-request', this.boundHandleBeforeFetch)
      this.formTarget.addEventListener('turbo:frame-missing', this.boundHandleError)
    }
  }

  // 메시지 영역을 맨 아래로 스크롤
  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  // 입력 필드에 포커스
  focusInput() {
    if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }

  // 키보드 이벤트 처리 (Ctrl+Enter로 전송)
  handleKeydown(event) {
    if (event.ctrlKey && event.key === "Enter") {
      event.preventDefault()
      this.submitForm()
    }
  }

  // 폼 전송
  submitForm() {
    if (!this.validateBeforeSubmit()) {
      return
    }
    
    if (this.hasSubmitTarget && this.hasInputTarget) {
      const content = this.inputTarget.value.trim()
      if (content) {
        this.submitTarget.click()
      }
    }
  }

  // 폼 제출 시작 처리
  handleSubmitStart(event) {
    this.isSubmitting = true
    this.showLoadingState()
    this.disableForm()
  }

  // 폼 제출 완료 처리
  handleSubmitEnd(event) {
    this.isSubmitting = false
    this.hideLoadingState()
    this.enableForm()
    
    // 성공적인 제출 후 폼 리셋
    if (event.detail.success !== false) {
      this.resetForm()
    }
  }

  // 요청 전 처리
  handleBeforeFetch(event) {
    // 요청 헤더에 세션 ID 추가
    const sessionId = this.getSessionId()
    if (sessionId) {
      event.detail.fetchOptions.headers = {
        ...event.detail.fetchOptions.headers,
        'X-Chat-Session-ID': sessionId
      }
    }
  }

  // 폼 리셋
  resetForm() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }
    this.scrollToBottom()
  }

  // 폼 전송 후 처리 (레거시 메서드)
  afterSubmit() {
    this.resetForm()
  }

  // 새 메시지가 추가되었을 때 호출
  messageAdded() {
    this.scrollToBottom()
  }

  // 로딩 상태 표시
  showLoadingState() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove('hidden')
    } else {
      this.createLoadingIndicator()
    }
  }

  // 로딩 상태 숨김
  hideLoadingState() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add('hidden')
    }
  }

  // 로딩 인디케이터 생성 (템플릿에 이미 있는 경우 활용)
  createLoadingIndicator() {
    // 템플릿에 이미 로딩 인디케이터가 있으면 표시만 하고 종료
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove('hidden')
      this.scrollToBottom()
      return
    }
    
    // 템플릿에 없는 경우에만 동적 생성 (폴백)
    if (this.hasMessagesTarget) {
      const loadingDiv = document.createElement('div')
      loadingDiv.className = 'flex justify-start mb-4'
      loadingDiv.setAttribute('data-chat-target', 'loadingIndicator')
      loadingDiv.innerHTML = `
        <div class="bg-gray-100 rounded-lg px-4 py-2 max-w-xs">
          <div class="flex items-center space-x-2">
            <div class="flex space-x-1">
              <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
              <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
              <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
            </div>
            <span class="text-sm text-gray-600">AI가 답변을 생성 중입니다...</span>
          </div>
        </div>
      `
      this.messagesTarget.appendChild(loadingDiv)
      this.scrollToBottom()
    }
  }

  // 폼 비활성화
  disableForm() {
    if (this.hasInputTarget) {
      this.inputTarget.disabled = true
      this.inputTarget.placeholder = "메시지 전송 중..."
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
    }
  }

  // 폼 활성화
  enableForm() {
    if (this.hasInputTarget) {
      this.inputTarget.disabled = false
      this.inputTarget.placeholder = "규정에 대해 궁금한 것을 물어보세요..."
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
    }
  }

  // 에러 처리
  handleError(event) {
    this.isSubmitting = false
    this.hideLoadingState()
    this.enableForm()
    this.showErrorMessage("메시지 전송 중 오류가 발생했습니다. 다시 시도해주세요.", 'submit')
  }

  // 에러 메시지 표시
  showErrorMessage(message, type = 'general') {
    if (this.hasMessagesTarget) {
      // 기존 동일 타입 에러 메시지 제거
      this.removeErrorMessagesByType(type)
      
      const errorDiv = document.createElement('div')
      errorDiv.className = 'text-center text-red-600 py-4 border border-red-200 bg-red-50 rounded-lg mb-4'
      errorDiv.setAttribute('data-error-type', type)
      errorDiv.setAttribute('data-chat-error', 'true')
      errorDiv.innerHTML = `
        <p class="font-medium">⚠️ ${message}</p>
        <button class="mt-2 text-sm text-red-800 underline hover:no-underline" onclick="this.parentElement.remove()">
          닫기
        </button>
      `
      this.messagesTarget.appendChild(errorDiv)
      this.scrollToBottom()
    }
  }

  // 특정 타입의 에러 메시지 제거
  removeErrorMessagesByType(type) {
    if (this.hasMessagesTarget) {
      const errorMessages = this.messagesTarget.querySelectorAll(`[data-error-type="${type}"]`)
      errorMessages.forEach(msg => msg.remove())
    }
  }

  // 연결 상태 확인
  checkConnection() {
    fetch(`/api/conversations/${this.conversationIdValue}/status`, {
      headers: {
        'Accept': 'application/json',
        'X-Chat-Session-ID': this.getSessionId()
      }
    })
    .then(response => response.json())
    .then(data => {
      if (!data.active) {
        this.showExpiredMessage()
      }
    })
    .catch(error => {
      console.error('Connection check failed:', error)
    })
  }

  // 세션 ID 가져오기
  getSessionId() {
    return document.querySelector('meta[name="chat-session-id"]')?.content || 
           sessionStorage.getItem('chat-session-id')
  }

  // 세션 만료 메시지 표시
  showExpiredMessage() {
    if (this.hasMessagesTarget) {
      const expiredMessage = document.createElement('div')
      expiredMessage.className = 'text-center text-red-600 py-4 border-t'
      expiredMessage.innerHTML = `
        <p class="font-medium">세션이 만료되었습니다.</p>
        <p class="text-sm">새로운 대화를 시작하려면 페이지를 새로고침하세요.</p>
      `
      this.messagesTarget.appendChild(expiredMessage)
      this.scrollToBottom()
    }

    // 입력 폼 비활성화
    if (this.hasInputTarget) {
      this.inputTarget.disabled = true
      this.inputTarget.placeholder = "세션이 만료되었습니다."
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
    }
  }

  // 주기적으로 연결 상태 확인 (5분마다)
  startConnectionCheck() {
    this.connectionCheckInterval = setInterval(() => {
      this.checkConnection()
    }, 5 * 60 * 1000) // 5분
  }

  // 네트워크 상태 확인
  checkNetworkStatus() {
    if (!navigator.onLine) {
      this.showErrorMessage("인터넷 연결을 확인해주세요.", 'network')
      this.disableForm()
      return false
    }
    return true
  }

  // 온라인/오프라인 이벤트 리스너
  setupNetworkListeners() {
    window.addEventListener('online', this.boundHandleOnline)
    window.addEventListener('offline', this.boundHandleOffline)
  }

  // 온라인 상태 처리
  handleOnline() {
    this.enableForm()
    this.removeErrorMessagesByType('network')
  }

  // 오프라인 상태 처리
  handleOffline() {
    this.disableForm()
    this.showErrorMessage("인터넷 연결이 끊어졌습니다. 연결을 확인해주세요.", 'network')
  }

  // 에러 메시지들 숨김 (레거시 메서드)
  hideErrorMessages() {
    this.removeErrorMessagesByType('network')
  }

  // 폼 제출 전 유효성 검사
  validateBeforeSubmit() {
    if (!this.checkNetworkStatus()) {
      return false
    }
    
    if (this.isSubmitting) {
      return false
    }
    
    if (!this.hasInputTarget || !this.inputTarget.value.trim()) {
      this.showErrorMessage("메시지를 입력해주세요.", 'validation')
      return false
    }
    
    // 유효성 검사 통과 시 이전 에러 메시지 제거
    this.removeErrorMessagesByType('validation')
    return true
  }

  // 컨트롤러 해제 시 정리
  disconnect() {
    // 인터벌 정리
    if (this.connectionCheckInterval) {
      clearInterval(this.connectionCheckInterval)
      this.connectionCheckInterval = null
    }
    
    // 폼 이벤트 리스너 정리
    if (this.hasFormTarget && this.boundHandleSubmitStart) {
      this.formTarget.removeEventListener('turbo:submit-start', this.boundHandleSubmitStart)
      this.formTarget.removeEventListener('turbo:submit-end', this.boundHandleSubmitEnd)
      this.formTarget.removeEventListener('turbo:before-fetch-request', this.boundHandleBeforeFetch)
      this.formTarget.removeEventListener('turbo:frame-missing', this.boundHandleError)
    }
    
    // 네트워크 이벤트 리스너 정리
    if (this.boundHandleOnline) {
      window.removeEventListener('online', this.boundHandleOnline)
      window.removeEventListener('offline', this.boundHandleOffline)
    }
    
    // 바인딩된 함수 참조 정리
    this.boundHandleSubmitStart = null
    this.boundHandleSubmitEnd = null
    this.boundHandleBeforeFetch = null
    this.boundHandleError = null
    this.boundHandleOnline = null
    this.boundHandleOffline = null
  }
}