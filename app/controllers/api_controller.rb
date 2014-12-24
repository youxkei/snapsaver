class ApiController < ApplicationController
  def shoot_and_push
    api_key = params[:api_key]

    if api_key.nil?
      render status: 400, json: { error: "API key not specified" }
      return
    end

    user = User.find_by(api_key: api_key)

    if user.nil?
      render status: 400, json: { error: "Invalid API key" }
      return
    end

    url_list_name = params[:url_list_name]

    if url_list_name.nil?
      render status: 400, json: { error: "URL list name not specified" }
      return
    end

    url_list = user.url_lists.find_by(name: url_list_name)

    if url_list.nil?
      render status: 400, json: { error: "Invalid URL list name" }
      return
    end

    
  end
end
