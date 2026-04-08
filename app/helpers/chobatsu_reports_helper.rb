module ChobatsuReportsHelper
  GRID_COLUMNS = 10

  def serial_number_rows(total_serial_count)
    return [] if total_serial_count.to_i <= 0

    (1..total_serial_count).each_slice(GRID_COLUMNS).to_a
  end

  def color_map_for_reports(reports)
    reports.each_with_object({}) do |report, map|
      color = report.evangelism_meeting.color_code
      (report.serial_number_from..report.serial_number_to).each do |number|
        map[number] = color
      end
    end
  end
end
