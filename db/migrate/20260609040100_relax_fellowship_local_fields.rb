# frozen_string_literal: true

class RelaxFellowshipLocalFields < ActiveRecord::Migration[8.0]
  # master 同期で取り込む新規行は color_code が未設定の可能性がある。
  # NOT NULL を解除して NULL を許容する。
  def up
    change_column_null :fellowships, :color_code, true
    add_column :fellowships, :enabled, :boolean, null: false, default: false
    execute "UPDATE fellowships SET enabled = 1"
  end

  def down
    change_column_null :fellowships, :color_code, false
    remove_column :fellowships, :enabled
  end
end
