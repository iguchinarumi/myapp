class TodosController < ApplicationController
    before_action :require_login

    def index
      @todos = current_user.todos
    end

    def new
      @todo = current_user.todos.build
    end

    def create
      @todo = current_user.todos.build(todo_params)
      if @todo.save
        redirect_to todos_path
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @todo = current_user.todos.find(params[:id])
    end

    def edit
      @todo = current_user.todos.find(params[:id])
    end

    def update
      @todo = current_user.todos.find(params[:id])
      if @todo.update(todo_params)
        redirect_to @todo
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @todo = current_user.todos.find(params[:id])
      @todo.destroy
      redirect_to todos_path
    end

    private

    def todo_params
      params.require(:todo).permit(:title, :completed)
    end
end
