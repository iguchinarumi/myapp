class AddNullConstraintToTodosTitle < ActiveRecord::Migration[8.1]
  def change
    change_column_null :todos, :title, false
  end
end
