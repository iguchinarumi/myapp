class TodosController < ApplicationController
  def index
    @todos = Todo.all
  end

  def new
    @todo = Todo.new
  end

  def create
    @todo = Todo.new(todo_params)
    if @todo.save
      redirect_to todos_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def todo_params
    params.require(:todo).permit(:title, :completed)
  end
end
