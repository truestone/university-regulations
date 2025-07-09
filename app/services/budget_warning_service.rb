class BudgetWarningService
  def initialize(ai_setting)
    @ai_setting = ai_setting
  end

  def send_warning
    return unless should_send_warning?

    # Log the warning
    Rails.logger.warn "Budget exceeded for #{@ai_setting.provider}: #{@ai_setting.usage_this_month} / #{@ai_setting.budget_limit}"
    
    # Send notification to admins
    notify_admins
    
    # Update last warning time
    @ai_setting.update(last_warning_sent_at: Time.current)
    
    # Optionally disable the setting if severely over budget
    disable_if_critical
  end

  private

  def should_send_warning?
    return false unless @ai_setting.budget_exceeded?
    
    # Don't send warning more than once per day
    return false if @ai_setting.last_warning_sent_at && @ai_setting.last_warning_sent_at > 1.day.ago
    
    true
  end

  def notify_admins
    admin_users = User.where(role: ['admin', 'super_admin'])
    
    admin_users.each do |admin|
      # In a real app, you might send email or create notifications
      Rails.logger.info "Notifying admin #{admin.email} about budget exceeded for #{@ai_setting.provider}"
      
      # Create a simple notification record (if you have a notifications system)
      # Notification.create(
      #   user: admin,
      #   title: "AI Budget Warning",
      #   message: budget_warning_message,
      #   category: 'budget_warning'
      # )
    end
  end

  def budget_warning_message
    usage_percentage = (@ai_setting.usage_this_month / @ai_setting.budget_limit * 100).round(1)
    
    "AI 서비스 예산 초과 경고: #{@ai_setting.provider} 서비스의 이번 달 사용량이 " \
    "예산 한도를 초과했습니다. (사용량: $#{@ai_setting.usage_this_month.round(4)}, " \
    "한도: $#{@ai_setting.budget_limit}, #{usage_percentage}%)"
  end

  def disable_if_critical
    # If usage is 150% of budget, disable the setting
    if @ai_setting.usage_this_month > (@ai_setting.budget_limit * 1.5)
      @ai_setting.update(is_active: false)
      Rails.logger.error "Disabled AI setting #{@ai_setting.provider} due to critical budget overrun"
      
      # Notify about disabling
      admin_users = User.where(role: ['admin', 'super_admin'])
      admin_users.each do |admin|
        Rails.logger.info "Notifying admin #{admin.email} about AI service #{@ai_setting.provider} being disabled"
      end
    end
  end
end