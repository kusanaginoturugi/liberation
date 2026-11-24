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

  def unused_serial_number_range_lines(total_serial_count, reports)
    unused_serial_number_ranges(total_serial_count, reports).map do |range_start, range_end|
      "#{range_start}〜#{range_end}"
    end
  end

  def unused_serial_number_count(total_serial_count, reports)
    unused_serial_number_ranges(total_serial_count, reports).sum do |range_start, range_end|
      range_end - range_start + 1
    end
  end

  def unused_serial_number_ranges(total_serial_count, reports)
    total = total_serial_count.to_i
    return [] if total <= 0

    used_ranges = reports.flat_map(&:number_ranges).filter_map do |from, to|
      next if from.blank? || to.blank?

      range_start = [ from, 1 ].max
      range_end = [ to, total ].min
      [ range_start, range_end ] if range_start <= range_end
    end.sort_by(&:first)

    merged_ranges = used_ranges.each_with_object([]) do |(range_start, range_end), ranges|
      previous = ranges.last
      if previous && range_start <= previous.last + 1
        previous[1] = [ previous.last, range_end ].max
      else
        ranges << [ range_start, range_end ]
      end
    end

    unused_ranges = []
    next_number = 1
    merged_ranges.each do |range_start, range_end|
      unused_ranges << [ next_number, range_start - 1 ] if next_number < range_start
      next_number = [ next_number, range_end + 1 ].max
    end
    unused_ranges << [ next_number, total ] if next_number <= total

    unused_ranges
  end

  def yen_amount(amount)
    number_to_currency(amount, unit: "円", format: "%n%u", precision: 0)
  end
end
