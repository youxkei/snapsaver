include HomeHelper

require "securerandom"

class HomeController < ApplicationController
  def home
    if params[:orphan_url_list_name]
      @orphan_url_list = true
      @url_list_name = params[:orphan_url_list_name]
      @urls = UrlList.find_by(name: @url_list_name).urls

      if @urls.empty?
        @urls_size = 0
      else
        @urls_size = @urls.count("\n") + 1
      end
    elsif user_signed_in?
      url_lists = current_user.url_lists

      if url_lists.empty?
        begin
          uuid = current_user.uuid
          create_bitbucket_repository "#{uuid}-default"
        rescue BitbucketAPIException
          @status = 400
          @message = "cannot create repository"
          render template: "error/error"
          return
        end

        repo = Git.clone "git@bitbucket.org:#{ENV["BITBUCKET_USER"]}/#{uuid}-default.git", "repo/#{uuid}-default"
        repo.config "user.name", ENV["BITBUCKET_USER"]
        repo.config "user.email", ENV["BITBUCKET_USER"]

        url_lists.create! name: "default", urls: ""
        user_session["current_url_list_name"] = "default"
      end

      @url_list_names = url_lists.map{ |url_list| url_list.name }

      if user_session["current_url_list_name"].nil?
        user_session["current_url_list_name"] = @url_list_names[0]
      end

      @url_list_name = user_session["current_url_list_name"]
      @urls = url_lists.find_by(name: @url_list_name).urls

      if @urls.empty?
        @urls_size = 0
      else
        @urls_size = @urls.count("\n") + 1
      end

      @uuid = current_user.uuid
    end

    @breakpoints = BREAKPOINTS
  end

  def add_url_list
    if not user_signed_in?
      @http_status_code = 401
      @error_message = "Login required"
      render status: 401, template: "error/error"
      return
    end

    if params[:url_list_name].nil?
      @http_status_code = 400
      @error_message = "URL list not specified"
      render status: 400, template: "error/error"
      return
    end

    adding_url_list_name = params[:url_list_name]
    uuid = current_user.uuid

    begin
      create_bitbucket_repository "#{uuid}-#{adding_url_list_name}"
    rescue BitbucketAPIException
      @http_status_code = 400
      @error_message = "Invalid URL list name"
      render status: 400, template: "error/error"
      return
    end

    repo = Git.clone "git@bitbucket.org:#{ENV["BITBUCKET_USER"]}/#{uuid}-#{adding_url_list_name}.git", "repo/#{uuid}-#{adding_url_list_name}"
    repo.config "user.name", ENV["BITBUCKET_USER"]
    repo.config "user.email", ENV["BITBUCKET_USER"]

    current_user.url_lists.create! name: adding_url_list_name, urls: ""
    user_session["current_url_list_name"] = adding_url_list_name
    redirect_to "/"
  end

  def change_current_url_list
    if not user_signed_in?
      @http_status_code = 401
      @error_message = "Login required"
      render status: 401, template: "error/error"
      return
    end

    if params[:url_list_name].nil?
      @http_status_code = 400
      @error_message = "URL list not specified"
      render status: 400, template: "error/error"
      return
    end

    user_session["current_url_list_name"] = params[:url_list_name]
    redirect_to "/"
  end
end
