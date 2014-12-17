class CreateUrlLists < ActiveRecord::Migration
  def change
    create_table :url_lists do |t|
      t.string :name
      t.string :urls
      t.integer :user_id

      t.timestamps
    end
  end
end
