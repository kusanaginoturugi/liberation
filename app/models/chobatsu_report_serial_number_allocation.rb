class ChobatsuReportSerialNumberAllocation < ApplicationRecord
  belongs_to :chobatsu_report
  belongs_to :event
  belongs_to :fellowship
end
