import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// 규정 임포트 진행률을 실시간으로 표시하는 Stimulus 컨트롤러
export default class extends Controller {
  static values = { 
    jobId: String, 
    userId: String 
  }
  
  static targets = [
    "percentage", "progressBar", "message", "status", "startTime", 
    "elapsedTime", "connectionStatus", "lastUpdate", "resultSection",
    "totalRecords", "successCount", "errorCount", "duration",
    "logContainer", "logContent", "cancelButton"
  ]

  connect() {
    console.log("ImportProgressController connected")
    this.logs = []
    this.startTime = new Date()
    
    // ActionCable 연결 설정
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { 
        channel: "RegulationImportChannel", 
        user_id: this.userIdValue 
      },
      {
        connected: this.connected.bind(this),
        disconnected: this.disconnected.bind(this),
        received: this.received.bind(this)
      }
    )
    
    // 초기 상태 요청
    setTimeout(() => {
      this.requestStatus()
    }, 1000)
  }

  disconnect() {
    console.log("ImportProgressController disconnected")
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.consumer) {
      this.consumer.disconnect()
    }
  }

  connected() {
    console.log("ActionCable connected")
    this.updateConnectionStatus("연결됨", "green")
    this.addLog("✅ 실시간 연결이 설정되었습니다.")
  }

  disconnected() {
    console.log("ActionCable disconnected")
    this.updateConnectionStatus("연결 끊김", "red")
    this.addLog("❌ 연결이 끊어졌습니다. 재연결을 시도합니다...")
  }

  received(data) {
    console.log("Received data:", data)
    
    switch (data.type) {
      case 'subscription_confirmed':
        this.addLog(`📡 ${data.message}`)
        break
        
      case 'status_response':
        this.handleStatusResponse(data)
        break
        
      case 'job_cancelled':
        this.handleJobCancelled(data)
        break
        
      case 'job_cancel_failed':
      case 'job_cancel_error':
        this.handleJobCancelError(data)
        break
        
      default:
        // 일반 진행률 업데이트
        this.updateProgress(data)
        break
    }
  }

  updateProgress(data) {
    // 진행률 바 업데이트
    if (data.percentage !== undefined) {
      this.percentageTarget.textContent = `${data.percentage}%`
      this.progressBarTarget.style.width = `${data.percentage}%`
    }
    
    // 메시지 업데이트
    if (data.message) {
      this.messageTarget.textContent = data.message
      this.addLog(`📊 ${data.percentage}% - ${data.message}`)
    }
    
    // 상태 업데이트
    if (data.status) {
      this.statusTarget.textContent = `상태: ${this.getStatusText(data.status)}`
    }
    
    // 경과 시간 업데이트
    if (data.elapsed_time) {
      this.elapsedTimeTarget.textContent = `${data.elapsed_time.toFixed(1)}초`
    }
    
    // 마지막 업데이트 시간
    this.lastUpdateTarget.textContent = new Date().toLocaleTimeString()
    
    // 완료 상태 처리
    if (data.status === 'completed') {
      this.handleCompletion(data)
    } else if (data.status === 'failed') {
      this.handleFailure(data)
    }
  }

  handleCompletion(data) {
    this.addLog("🎉 임포트가 성공적으로 완료되었습니다!")
    
    // 취소 버튼 숨기기
    this.cancelButtonTarget.style.display = 'none'
    
    // 결과 섹션 표시
    if (data.data) {
      this.showResults(data.data)
    }
    
    // 진행률 바 색상 변경
    this.progressBarTarget.classList.remove('bg-blue-600')
    this.progressBarTarget.classList.add('bg-green-600')
  }

  handleFailure(data) {
    this.addLog(`❌ 임포트가 실패했습니다: ${data.message}`)
    
    // 취소 버튼 숨기기
    this.cancelButtonTarget.style.display = 'none'
    
    // 진행률 바 색상 변경
    this.progressBarTarget.classList.remove('bg-blue-600')
    this.progressBarTarget.classList.add('bg-red-600')
  }

  showResults(resultData) {
    this.resultSectionTarget.classList.remove('hidden')
    
    if (resultData.total_records) {
      this.totalRecordsTarget.textContent = resultData.total_records
    }
    
    if (resultData.import_stats) {
      const stats = resultData.import_stats
      let successCount = 0
      let errorCount = 0
      
      Object.values(stats).forEach(stat => {
        if (typeof stat === 'object' && stat.created !== undefined) {
          successCount += stat.created + stat.updated
          errorCount += stat.failed
        }
      })
      
      this.successCountTarget.textContent = successCount
      this.errorCountTarget.textContent = errorCount
    }
    
    if (resultData.duration) {
      this.durationTarget.textContent = `${resultData.duration.toFixed(1)}s`
    }
  }

  handleStatusResponse(data) {
    if (data.status === 'not_found') {
      this.addLog("⚠️ 진행률 정보를 찾을 수 없습니다.")
    } else {
      this.updateProgress(data)
    }
  }

  handleJobCancelled(data) {
    this.addLog(`🛑 작업이 취소되었습니다: ${data.message}`)
    this.cancelButtonTarget.style.display = 'none'
    this.progressBarTarget.classList.remove('bg-blue-600')
    this.progressBarTarget.classList.add('bg-gray-600')
  }

  handleJobCancelError(data) {
    this.addLog(`❌ 작업 취소 실패: ${data.message}`)
  }

  requestStatus() {
    if (this.subscription) {
      this.subscription.send({
        action: 'request_status',
        job_id: this.jobIdValue
      })
    }
  }

  cancelJob() {
    if (confirm('정말로 작업을 취소하시겠습니까?')) {
      this.addLog("🛑 작업 취소를 요청합니다...")
      
      if (this.subscription) {
        this.subscription.send({
          action: 'cancel_job',
          job_id: this.jobIdValue
        })
      }
    }
  }

  downloadResult() {
    // 결과 파일 다운로드
    const url = `/regulation_imports/${this.jobIdValue}/download`
    window.open(url, '_blank')
  }

  addLog(message) {
    const timestamp = new Date().toLocaleTimeString()
    const logEntry = `[${timestamp}] ${message}`
    
    this.logs.push(logEntry)
    
    // 최대 100개 로그만 유지
    if (this.logs.length > 100) {
      this.logs = this.logs.slice(-100)
    }
    
    // 로그 표시 업데이트
    this.logContentTarget.innerHTML = this.logs.join('\n')
    
    // 스크롤을 맨 아래로
    this.logContainerTarget.scrollTop = this.logContainerTarget.scrollHeight
  }

  updateConnectionStatus(status, color) {
    const statusElement = this.connectionStatusTarget.querySelector('span')
    if (statusElement) {
      statusElement.textContent = status
      statusElement.className = `inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium`
      
      if (color === 'green') {
        statusElement.classList.add('bg-green-100', 'text-green-800')
      } else if (color === 'red') {
        statusElement.classList.add('bg-red-100', 'text-red-800')
      } else {
        statusElement.classList.add('bg-gray-100', 'text-gray-800')
      }
    }
  }

  getStatusText(status) {
    const statusMap = {
      'started': '시작됨',
      'loading': '로딩 중',
      'analyzing': '분석 중',
      'parsing': '파싱 중',
      'parsing_complete': '파싱 완료',
      'importing': '임포트 중',
      'completed': '완료',
      'failed': '실패',
      'cancelled': '취소됨'
    }
    
    return statusMap[status] || status
  }
}