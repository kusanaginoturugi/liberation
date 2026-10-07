module ChobatsuReportsHelper
  GRID_COLUMNS = 10

  def serial_number_rows(total_serial_count)
    return [] if total_serial_count.to_i <= 0

    (1..total_serial_count).each_slice(GRID_COLUMNS).to_a
  end

  def color_map_for_reports(reports)
    reports.each_with_object({}) do |report, map|
      report.number_range_contributions.each do |fellowship, from, to|
        (from..to).each { |number| map[number] = fellowship.color_code }
      end
    end
  end

  def used_serial_count(reports)
    reports.sum(&:usage_count)
  end

  def remaining_serial_count(total_serial_count, reports)
    [ total_serial_count.to_i - used_serial_count(reports), 0 ].max
  end
end
