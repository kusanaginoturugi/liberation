class FellowshipsController < ApplicationController
  before_action :require_admin!
  before_action :set_fellowship, only: [ :edit, :update ]
  before_action :load_regions, only: [ :new, :create, :edit, :update ]

  def index
    @fellowships = Fellowship.includes(:region).where(enabled: true).display_sorted
    @all_fellowships = Fellowship.includes(:region).order(:display_order, :name).load
  end

  def sync
    result = MasterSync.run
    redirect_to fellowships_path, notice: "マスタから #{result.count} 件を同期しました。"
  rescue MasterSync::FetchError => e
    redirect_to fellowships_path, alert: "マスタ同期に失敗しました: #{e.message}"
  end

  def bulk_update_enabled
    enabled_ids = Array(params[:enabled]).map(&:to_i).to_set
    Fellowship.transaction do
      Fellowship.find_each do |fellowship|
        want = enabled_ids.include?(fellowship.id)
        fellowship.update!(enabled: want) if fellowship.enabled != want
      end
    end
    redirect_to fellowships_path, notice: "対象伝道会を更新しました。"
  end

  def new
    @fellowship = Fellowship.new(active: true)
  end

  def edit
  end

  def create
    @fellowship = Fellowship.new(fellowship_params)

    if @fellowship.save
      redirect_to fellowships_path, notice: "伝道会を追加しました"
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @fellowship.update(fellowship_params)
      redirect_to fellowships_path, notice: "伝道会を更新しました"
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_fellowship
    @fellowship = Fellowship.find(params[:id])
  end

  def load_regions
    @regions = Region.order(:name)
  end

  def fellowship_params
    params.require(:fellowship).permit(:name, :color_code, :region_id, :display_order, :active)
  end
end
