require 'rails_helper'

include InnerApiHelper

RSpec.describe ApiController, :type => :controller do
  describe "POST #shoot_and_push" do
    it "returns an error without api_key parameter" do
      post :shoot_and_push

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("API key not specified")
    end

    it "returns an error with invalid api_key parameter" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      post :shoot_and_push, api_key: user.api_key + "salt"

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("Invalid API key")
    end

    it "returns an error without url_list_name" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      post :shoot_and_push, api_key: user.api_key

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL list name not specified")
    end

    it "returns an error with invalid url_list_name" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      post :shoot_and_push, api_key: user.api_key, url_list_name: url_list.name + "suger"

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL list name not specified")
    end

    it "returns an error without any changes" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      create_bitbucket_repository "#{user.uuid}-#{url_list.name}"
      repository = Git.clone "git@bitbucket.org:snapsaver/#{user.uuid}-#{url_list.name}.git", "repo/#{user.uuid}-#{url_list.name}"
      repository.config "user.name", ENV["BITBUCKET_USER"]
      repository.config "user.email", ENV["BITBUCKET_USER"]

      begin
        post :shoot_and_push, api_key: user.api_key, url_list_name: url_list.name
        post :shoot_and_push, api_key: user.api_key, url_list_name: url_list.name

        expect(response).to have_http_status(400)
        expect(JSON.parse(response.body)["error"]).to eq("No changes")
      ensure
        FileUtils.rm_rf "repo/#{user.uuid}-#{url_list.name}"
        delete_bitbucket_repository "#{user.uuid}-#{url_list.name}"
      end
    end

    it "takes screenshots and pushes them into bitbucket repository" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      create_bitbucket_repository "#{user.uuid}-#{url_list.name}"
      repository = Git.clone "git@bitbucket.org:snapsaver/#{user.uuid}-#{url_list.name}.git", "repo/#{user.uuid}-#{url_list.name}"
      repository.config "user.name", ENV["BITBUCKET_USER"]
      repository.config "user.email", ENV["BITBUCKET_USER"]

      begin
        post :shoot_and_push, api_key: user.api_key, url_list_name: url_list.name

        expect(response).to have_http_status(200)
      ensure
        FileUtils.rm_rf "repo/#{user.uuid}-#{url_list.name}"
        delete_bitbucket_repository "#{user.uuid}-#{url_list.name}"
      end
    end
  end
end
