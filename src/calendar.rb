require 'dotenv'
Dotenv.load

# Initialize the API
service = Google::Apis::CalendarV3::CalendarService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

# Fetch the next 10 events for the user
calendar_id = "primary"
response = service.list_events(calendar_id,
                               max_results:   10,
                               single_events: true,
                               order_by:      "startTime",
                               time_min:      DateTime.now.rfc3339)
puts "Upcoming events:"
puts "No upcoming events found" if response.items.empty?
response.items.each do |event|
  start = event.start.date || event.start.date_time
  puts "- #{event.summary} (#{start})"
end




# 1週間先まで空き時間を検索
start_date = Date.today
end_date = start_date.next_day(7)

item = Google::Apis::CalendarV3::FreeBusyRequestItem.new(id: ENV['CALENDAR_ID'])
free_busy_request = Google::Apis::CalendarV3::FreeBusyRequest.new(
  calendar_expansion_max: 50,
  time_min: DateTime.new(start_date.year, start_date.month, start_date.day, 00, 0, 0),
  time_max: DateTime.new(end_date.year, end_date.month, end_date.day, 00, 0, 0),
  items: [item],
  time_zone: "UTC+9"
)

response = service.query_freebusy(free_busy_request)
calendars = response.calendars
busy_list = calendars[ENV['CALENDAR_ID']].busy

# 空き時間を検索する時間の範囲
start_hour = 9
end_hour = 20

puts "Free time:"

result = {}
(start_date..end_date).each do |date|
  result[date] ||= {}

  start_work_time = Time.new(date.year, date.month, date.day, start_hour, 0, 0)
  end_work_time = Time.new(date.year, date.month, date.day, end_hour, 0, 0)
  
  start_work_time.to_i.step(end_work_time.to_i, 60*60).each_cons(2) do |c_time_int, n_time__int|
    current_time = Time.at(c_time_int)
    next_time = Time.at(n_time__int)
    free = true
    result[date][current_time] = {}

    busy_list.each do |busy|
      busy_start = busy.start
      busy_end = busy.end
      current_datetime = current_time.to_datetime
      next_datetime = next_time.to_datetime

      if current_datetime < busy_end && busy_start < next_datetime
        free = false
        break
      end
    end

    result[date][current_time][:free] = free
  end
end


# 出力
result.each do |date, times|
  min_time = max_time = nil
  spans = []
  times.each do |time, info|
    min_time ||= time
    max_time = time
    if info[:free]
      next
    else
      if min_time && max_time && min_time < max_time
        spans << "#{min_time.strftime("%-H:%M")}-#{max_time.strftime("%-H:%M")}"
      end
      min_time = max_time = nil
    end
  end

  if min_time && max_time && min_time < max_time
    spans << "#{min_time.strftime("%-H:%M")}-#{max_time.strftime("%-H:%M")}"
  end
  puts "#{date.strftime("%Y/%m/%d")} #{spans.join(", ")}"
end