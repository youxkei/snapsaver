require "git"

# FIXME: BREAKPOINTSのために別のコントローラのヘルパーを使ってる
include HomeHelper

class LatestImagesController < ApplicationController
  def latest_images
    if user_signed_in?
      if user_session["current_url_list_name"]
        url_list_name = user_session["current_url_list_name"]
      else
        @http_status_code = 400
        @error_message = "User session does not have current URL list"
        render status: 400, template: "error/error"
        return
      end

      url_list = current_user.url_lists.find_by name: url_list_name

      if url_list.nil?
        @http_status_code = 400
        @error_message = "User session has invalid current URL list"
        render status: 400, template: "error/error"
        return
      end

      repository_name = "#{current_user.uuid}-#{url_list.name}"
    else
      if params[:url_list_name]
        url_list_name = params[:url_list_name]
      else
        @http_status_code = 400
        @error_message = "URL list not specified"
        render status: 400, template: "error/error"
        return
      end

      url_list = UrlList.find_by name: url_list_name

      if url_list.nil?
        @http_status_code = 400
        @error_message = "URL list not found"
        render status: 400, template: "error/error"
        return
      end

      repository_name = url_list.name
    end

    repository = Git.open("repo/#{repository_name}")

    if repository.branches.size > 0
      head_sha = repository.gcommit("HEAD").sha
    else
      @http_status_code = 400
      @error_message = "Empty repository"
      render status: 400, template: "error/error"
    end

    @url_list_name = url_list_name
    @latest_images = url_list.urls.split("\n").map{ |url|
      BREAKPOINTS.map{ |breakpoint|
        {
          breakpoint: breakpoint,
          url: url,
          url_to_image: "https://bytebucket.org/snapsaver/#{repository_name}/raw/#{head_sha}/#{url.gsub "/", "_"}.#{breakpoint}.png"
        }
      }
    }
  end
end
