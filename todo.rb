require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

configure do
  set :erb, :escape_html => true
end

helpers do
  def list_complete?(list)
    todo_count(list) > 0 && remaining_todo_count(list) == 0
  end
  
  def list_class(list)
    "complete" if list_complete?(list)
  end
  
  def todo_count(list)
    list[:todos].size
  end
  
  def remaining_todo_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end
  
  def order_lists(lists)
    sorted_lists = lists.sort_by { |list| list_complete?(list) ? 1 : 0 }
    sorted_lists.each { |list| yield list, lists.index(list) }
  end
  
  def order_todos(todos)
    sorted_todos = todos.sort_by { |todo| todo[:completed] ? 1 : 0 }
    sorted_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
end

def load_list(idx)
  list = session[:lists][idx]
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# Return an error message if the name is invalid. Return `nil` if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size then
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Update an existing todo list
post "/lists/:list_id" do
  list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been renamed."
    redirect "/lists/#{@list_id}"
  end
end

get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Delete a todo list
post "/lists/:list_id/delete" do
  session[:lists].delete_at(params[:list_id].to_i)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo_name(list, todo_name)
  if !(1..100).cover? todo_name.size then
    "Todo must be between 1 and 100 characters."
  end
end

# Add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_name = params[:todo].strip
  
  error = error_for_todo_name(@list, todo_name)
  if  error then
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo_name, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  load_list(list_id)[:todos].delete_at(todo_id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{list_id}"
  end
end

# Check all todos in a list complete
post "/lists/:list_id/complete" do
  list_id = params[:list_id].to_i
  load_list(list_id)[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos marked complete."
  redirect "/lists/#{list_id}"
end

# Toggle a todo complete/uncomplete
post '/lists/:list_id/todos/:todo_id' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  todo = load_list(list_id)[:todos][todo_id]
  todo[:completed] = params[:completed] == 'true'
  session[:success] = "The todo has been updated."
  redirect "/lists/#{list_id}"
end
