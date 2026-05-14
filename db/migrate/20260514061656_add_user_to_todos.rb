class AddUserToTodos < ActiveRecord::Migration[8.1]
  def change
    add_reference :todos, :user, null: false, foreign_key: true
  end
end
