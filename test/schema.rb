ActiveRecord::Schema.define(:version => 1) do
  
  create_table :data_manager_ones, :force => true do |t|
    t.column :name, :string
  end             
  
  create_table :data_manager_twos, :force => true do |t|
    t.column :name, :string
    t.column :data_manager_one_id, :integer
  end
  
  create_table :data_manager_threes, :force => true do |t|
    t.column :name, :string
    t.column :data_manager_two_id, :integer
    t.column :parent_id, :integer
  end
  
end