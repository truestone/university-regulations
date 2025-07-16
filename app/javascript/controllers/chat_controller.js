import { Controller } from "@hotwired/stimulus"

// 채팅 인터페이스 Stimulus 컨트롤러
export default class extends Controller {
  static targets = ["messages", "input", "submit", "form"]
  static values = { conversationId: String }

  connect() {
    this.scrollToBottom()
    this.focusInput()
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
    if (this.hasSubmitTarget && this.hasInputTarget) {
      const content = this.inputTarget.value.trim()
      if (content) {
        this.submitTarget.click()
      }
    }
  }

  // 폼 전송 후 처리
  afterSubmit() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }
    this.scrollToBottom()
  }

  // 새 메시지가 추가되었을 때 호출
  messageAdded() {
    this.scrollToBottom()
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

  // 컨트롤러 해제 시 정리
  disconnect() {
    if (this.connectionCheckInterval) {
      clearInterval(this.connectionCheckInterval)
    }
  }
}