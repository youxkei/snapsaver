require 'rails_helper'


RSpec.describe LatestImagesController, :type => :controller do
  include InnerApiHelper

  describe "get #latest_images" do
    it "returns error without an url_list_name parameter without login" do
      get :latest_images

      expect(response).to have_http_status(400)
      expect(response).to render_template("error/error")

      expect(assigns(:http_status_code)).to eq(400)
      expect(assigns(:error_message)).to eq("URL list not specified")
    end

    it "returns error without user_session[current_url_list_name] with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      get :latest_images

      expect(response).to have_http_status(400)
      expect(response).to render_template("error/error")

      expect(assigns(:http_status_code)).to eq(400)
      expect(assigns(:error_message)).to eq("User session does not have current URL list")
    end

    it "returns error with invalid url_list_name parameter without login" do
      url_list = FactoryGirl.create :url_list

      get :latest_images, url_list_name: url_list.name + "salt"

      expect(response).to have_http_status(400)
      expect(response).to render_template("error/error")

      expect(assigns(:http_status_code)).to eq(400)
      expect(assigns(:error_message)).to eq("URL list not found")
    end

    it "returns error with invalid user_session[current_url_list_name] with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      session["warden.user.user.session"] = {"current_url_list_name" => url_list.name + "sugar"}

      get :latest_images

      expect(response).to have_http_status(400)
      expect(response).to render_template("error/error")

      expect(assigns(:http_status_code)).to eq(400)
      expect(assigns(:error_message)).to eq("User session has invalid current URL list")
    end

    it "returns error with empty repository with an url_list_name parameter without login" do
      url_list = FactoryGirl.create :url_list

      create_bitbucket_repository url_list.name

      begin
        repository = Git.clone "git@bitbucket.org:snapsaver/#{url_list.name}.git", "repo/#{url_list.name}"
        repository.config "user.name", ENV["BITBUCKET_USER"]
        repository.config "user.email", ENV["BITBUCKET_USER"]

        get :latest_images, url_list_name: url_list.name

        expect(response).to have_http_status(400)
        expect(response).to render_template("error/error")

        expect(assigns(:http_status_code)).to eq(400)
        expect(assigns(:error_message)).to eq("Empty repository")
      ensure
        FileUtils.rm_rf "repo/#{url_list.name}"
        delete_bitbucket_repository url_list.name
      end
    end

    it "returns error with empty repository with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      create_bitbucket_repository "#{user.uuid}-#{url_list.name}"

      begin
        repository = Git.clone "git@bitbucket.org:snapsaver/#{user.uuid}-#{url_list.name}.git", "repo/#{user.uuid}-#{url_list.name}"
        repository.config "user.name", ENV["BITBUCKET_USER"]
        repository.config "user.email", ENV["BITBUCKET_USER"]

        session["warden.user.user.session"] = {"current_url_list_name" => url_list.name}

        get :latest_images

        expect(response).to have_http_status(400)
        expect(response).to render_template("error/error")

        expect(assigns(:http_status_code)).to eq(400)
        expect(assigns(:error_message)).to eq("Empty repository")
      ensure
        FileUtils.rm_rf "repo/#{user.uuid}-#{url_list.name}"
        delete_bitbucket_repository "#{user.uuid}-#{url_list.name}"
      end
    end

    it "displays latest images of an orphan URL list with url_list_name parameter without login" do
      url_list = FactoryGirl.create :url_list

      create_bitbucket_repository url_list.name

      begin
        repository = Git.clone "git@bitbucket.org:snapsaver/#{url_list.name}.git", "repo/#{url_list.name}"
        repository.config "user.name", ENV["BITBUCKET_USER"]
        repository.config "user.email", ENV["BITBUCKET_USER"]

        File.open "repo/#{url_list.name}/piyo", "w" do end
        repository.add all: true
        repository.commit "this is a commit"

        head_sha = repository.gcommit("HEAD").sha

        get :latest_images, url_list_name: url_list.name

        expect(response).to have_http_status(200)
        expect(response).to render_template(:latest_images)

        expect(assigns(:url_list_name)).to eq(url_list.name)
        expect(assigns(:latest_images)).to eq(url_list.urls.split("\n").map { |url|
          ["lg", "md", "sm", "xs"].map { |breakpoint|
            {
              breakpoint: breakpoint,
              url: url,
              url_to_image: "https://bytebucket.org/snapsaver/#{url_list.name}/raw/#{head_sha}/#{url.gsub "/", "_"}.#{breakpoint}.png"
            }
          }
        })
      ensure
        FileUtils.rm_rf "repo/#{url_list.name}"
        delete_bitbucket_repository url_list.name
      end
    end
  end
end
