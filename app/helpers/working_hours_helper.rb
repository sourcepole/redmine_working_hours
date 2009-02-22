module WorkingHoursHelper

  def duration(minutes)
    str = ''
    unless minutes.nil? then
      days = minutes / (24*60)
      hours = (minutes % (24*60)) / 60
      minutes = minutes % 60
      str << days.to_s << "d " if days > 0
      str << hours .to_s << "h " if hours > 0
      str << minutes.to_s << "'" if minutes > 0 || hours+days == 0
    end
    str
  end

  def to_time_s(timestamp, workday)
    include_date = (timestamp.to_date != workday)
    format_time(timestamp, include_date)
  end
end
