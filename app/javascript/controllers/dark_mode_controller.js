import { Controller } from "@hotwired/stimulus"

// 다크 모드 토글 컨트롤러
export default class extends Controller {
  static targets = ["toggle", "icon"]
  
  connect() {
    // 저장된 테마 설정 확인 (기본값: 라이트 모드)
    const savedTheme = localStorage.getItem('theme')
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    
    // 명시적으로 다크 모드가 설정된 경우에만 다크 모드 활성화
    if (savedTheme === 'dark') {
      this.enableDarkMode()
    } else if (savedTheme === 'light') {
      this.enableLightMode()
    } else {
      // 저장된 설정이 없으면 라이트 모드를 기본값으로
      this.enableLightMode()
      localStorage.setItem('theme', 'light')
    }
    
    // 시스템 테마 변경 감지
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem('theme')) {
        if (e.matches) {
          this.enableDarkMode()
        } else {
          this.enableLightMode()
        }
      }
    })
  }
  
  toggle() {
    if (document.documentElement.classList.contains('dark')) {
      this.enableLightMode()
      localStorage.setItem('theme', 'light')
    } else {
      this.enableDarkMode()
      localStorage.setItem('theme', 'dark')
    }
  }
  
  enableDarkMode() {
    document.documentElement.classList.add('dark')
    this.updateToggleState(true)
  }
  
  enableLightMode() {
    document.documentElement.classList.remove('dark')
    this.updateToggleState(false)
  }
  
  updateToggleState(isDark) {
    if (this.hasToggleTarget) {
      this.toggleTarget.checked = isDark
    }
    
    if (this.hasIconTarget) {
      if (isDark) {
        this.iconTarget.innerHTML = `
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
            <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z"></path>
          </svg>
        `
      } else {
        this.iconTarget.innerHTML = `
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z" clip-rule="evenodd"></path>
          </svg>
        `
      }
    }
  }
}