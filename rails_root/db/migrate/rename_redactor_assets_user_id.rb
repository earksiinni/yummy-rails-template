class RenameRedactorAssetsUserId < ActiveRecord::Migration
  def up
    rename_column :redactor_assets, :user_id, :<%= @opts[:user_model].underscore %>_id
  end

  def down
    rename_column :redactor_assets, :<%= @opts[:user_model].underscore %>_id, :user_id
  end
end
