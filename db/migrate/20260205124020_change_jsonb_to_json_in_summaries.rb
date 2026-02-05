class ChangeJsonbToJsonInSummaries < ActiveRecord::Migration[8.1]
  def change
    change_column :summaries, :sections, :json
    change_column :summaries, :quotes, :json
  end
end
