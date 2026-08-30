require "prawn"
require "prawn/table"

class CeremonySchedulePdf
  FONT_PATH = Rails.root.join("app/assets/fonts/NotoSansCJKjp-Regular.otf").freeze

  def initialize(event:, schedules:, allocation_rows:)
    @event = event
    @schedules = schedules
    @allocation_rows = allocation_rows
  end

  def render
    document = Prawn::Document.new(page_size: "A4", margin: 28)
    document.font(FONT_PATH.to_s)

    document.text "挙行予定表・番号割り振り", size: 15
    document.move_down 2
    document.text @event.name, size: 9, align: :right
    document.stroke_horizontal_rule
    document.move_down 7

    draw_section_heading(document, "予定表", "霊数合計 #{number(@schedules.sum(&:spirit_count))}")
    draw_schedule_table(document)
    document.move_down 10
    draw_section_heading(document, "番号割り振り", "伝道会ごとの霊数合計")
    draw_allocation_table(document)

    document.render
  end

  private

  def draw_section_heading(document, title, detail)
    document.table(
      [ [ title, detail ] ],
      column_widths: [ 250, document.bounds.width - 250 ],
      cell_style: { borders: [], padding: [ 0, 0, 3, 0 ], size: 9 }
    ) do
      columns(1).align = :right
    end
  end

  def draw_schedule_table(document)
    rows = [ [ "伝道会名", "挙行日時", "場所", "引保師数", "霊数", "超抜点伝師" ] ]
    rows += if @schedules.empty?
      [ [ "挙行予定はまだありません", "", "", "", "", "" ] ]
    else
      @schedules.map do |schedule|
        [
          schedule.fellowship.name,
          I18n.l(schedule.ceremony_at, format: :schedule),
          schedule.place,
          number(schedule.assistant_count),
          number(schedule.spirit_count),
          schedule.minister_name.presence || "-"
        ]
      end
    end

    document.table(rows, header: true, column_widths: [ 75, 104, 125, 58, 48, 92 ]) do
      cells.style(size: 7, padding: [ 3, 3 ], border_width: 0.5)
      row(0).align = :center
      columns(3..4).align = :right
    end
  end

  def draw_allocation_table(document)
    rows = [ [ "伝道会名", "霊数", "番号" ] ]
    rows += if @allocation_rows.empty?
      [ [ "番号を割り振る予定はまだありません", "", "" ] ]
    else
      @allocation_rows.map do |row|
        [
          row[:fellowship].name,
          number(row[:spirit_count]),
          "#{number(row[:serial_number_from])} 〜 #{number(row[:serial_number_to])}"
        ]
      end
    end

    document.table(rows, header: true, column_widths: [ 220, 105, 177 ]) do
      cells.style(size: 7.5, padding: [ 3, 3 ], border_width: 0.5)
      row(0).align = :center
      column(1).align = :right
      column(2).align = :center
    end
  end

  def number(value)
    ActiveSupport::NumberHelper.number_to_delimited(value)
  end
end
