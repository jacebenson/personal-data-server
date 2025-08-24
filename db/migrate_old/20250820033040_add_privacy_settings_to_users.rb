class AddPrivacySettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :setting_privacy_mode, :boolean, default: false, null: false
  end
end
