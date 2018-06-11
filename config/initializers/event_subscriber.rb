module EventSubscriber
end

if Rails.env == 'production'
  ActiveSupport::Notifications.subscribe "process_action.action_controller" do |*args| 
  	event = ActiveSupport::Notifications::Event.new *args
    event.name      # => "process_action.action_controller"
    event.duration  # => 10 (in milliseconds)
    event.payload   # => {:extra=>information}
  	#Rails.configuration.request_counter.increment({status: 
    route = event.payload[:controller] + '#' + event.payload[:action]
    duration_in_ms = event.duration
    status = event.payload[:status]
  	Rails.configuration.request_latencies.observe(duration_in_ms.to_f, { route: route, status: status }) if status != 500
  	Rails.configuration.api_server_response_time.observe(duration_in_ms.to_f, { route: route, status: status }) if status != 500

    if event.payload[:exception]
      exception = event.payload[:exception].map{ |t| t.downcase }.join(' ').gsub(/[^a-zA-Z0-9 ]/, '')
      FailureAlertWorker.perform_async(exception, route)
    end
  end
end

