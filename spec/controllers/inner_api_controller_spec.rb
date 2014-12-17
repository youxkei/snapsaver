require 'rails_helper'

RSpec.describe InnerApiController, :type => :controller do
  describe "POST #make_orphan_url_list" do
    it "returns error with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      post :make_orphan_url_list

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("Should not log in")
    end

    it "makes new orphan URL list and its bitbucket repository without login" do
      post :make_orphan_url_list

      expect(response).to have_http_status(302)
      expect(UrlList.count).to eq(1)

      url_list_name = UrlList.first.name

      expect(url_list_name).to match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
      expect{ delete_bitbucket_repository url_list_name }.not_to raise_error
    end
  end

  describe "POST #save_urls" do
    it "returns an error without url_list_name parameter without login" do
      post :save_urls

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL list not specified")
    end

    it "returns an error without user_session[current_url_list_name] with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      post :save_urls

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("User session does not have current URL list")
    end

    it "returns an error with invalid url_list_name parameter without login" do
      url_list = FactoryGirl.create :url_list

      post :save_urls, url_list_name: url_list.name + "oops"

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL list not found")
    end

    it "returns an error with invalid user_session[current_url_list_name] with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      session["warden.user.user.session"] = {"current_url_list_name" => url_list.name + "oops"}

      post :save_urls

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("User session has invalid current URL list")
    end

    it "saves URL into database with url_list_name parameter without login" do
      url_list = FactoryGirl.create :url_list

      post :save_urls, url_list_name: url_list.name, urls: "http://www.example.com\nhttps://www.google.com\nfile:///etc/passwd"

      expect(response).to have_http_status(200)
      expect(url_list.urls).to eq("http://www.example.com\nhttps://www.google.com")
    end

    it "saves URL into database with user_session[current_url_list_name] with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      session["warden.user.user.session"] = {"current_url_list_name" => url_list.name}

      post :save_urls, urls: "http://www.example.com\nhttps://www.google.com\nfile:///etc/passwd"

      expect(response).to have_http_status(200)
      expect(url_list.urls).to eq("http://www.example.com\nhttps://www.google.com")
    end
  end

  describe "POST #shoot" do
    it "returns an error without url_list_name parameter without login" do
      post :shoot
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL list not specified")
    end

    it "returns an error without user_session[current_url_list_name] with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      post :shoot

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("User session does not have current URL list")
    end

    it "returns an error with invalid url_list_name parameter without login" do
      url_list = FactoryGirl.create :url_list

      post :shoot, url_list_name: url_list.name + "oops"

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL list not found")
    end

    it "returns an error with invalid user_session[current_url_list_name] with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      session["warden.user.user.session"] = {"current_url_list_name" => url_list.name + "oops"}

      post :shoot

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("User session has invalid current URL list")
    end

    it "returns an error without url_index parameter" do
      url_list = FactoryGirl.create :url_list

      post :shoot, url_list_name: url_list.name

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL index not specified")
    end

    it "returns an error with invalid url_index parameter" do
      url_list = FactoryGirl.create :url_list

      post :shoot, url_list_name: url_list.name, url_index: -1

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL index out of range")

      post :shoot, url_list_name: url_list.name, url_index: url_list.urls.count("\n") + 2

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL index out of range")
    end

    it "returns an error with empty urls without login" do
      url_list = FactoryGirl.create :url_list
      url_list.urls = ""
      url_list.save

      post :shoot, url_list_name: url_list.name

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("Empty URL list")
    end

    it "takes snapshot and saves them to the url_list's repository without login" do
      url_list = FactoryGirl.create :url_list

      Dir.mkdir "repo/#{url_list.name}"

      begin
        post :shoot, url_list_name: url_list.name, url_index: 0, breakpoint: "all"
        expect(response).to have_http_status(200)

        post :shoot, url_list_name: url_list.name, url_index: 1, breakpoint: "lg"
        expect(response).to have_http_status(200)
      ensure
        FileUtils.rm_rf "repo/#{url_list.name}"
      end
    end

    it "takes snapshot and saves them to the url_list's repository with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      session["warden.user.user.session"] = {"current_url_list_name" => url_list.name}

      Dir.mkdir "repo/#{user.uuid}-#{url_list.name}"

      begin
        post :shoot, url_index: 0, breakpoint: "sm"
        expect(response).to have_http_status(200)

        post :shoot, url_index: 1, breakpoint: "md"
        expect(response).to have_http_status(200)
      ensure
        FileUtils.rm_rf "repo/#{user.uuid}-#{url_list.name}"
      end
    end
  end

  describe "POST #push_repository" do
    it "returns an error without url_list_name parameter without login" do
      post :push_repository

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL list not specified")
    end

    it "returns an error without user_session[current_url_list_name] with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      post :push_repository
      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("User session does not have current URL list")
    end

    it "returns an error with invalid url_list_name parameter without login" do
      url_list = FactoryGirl.create :url_list

      post :push_repository, url_list_name: url_list.name + "oops"

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("URL list not found")
    end

    it "returns an error with invalid user_session[current_url_list_name] with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      session["warden.user.user.session"] = {"current_url_list_name" => url_list.name + "oops"}

      post :push_repository

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("User session has invalid current URL list")
    end

    it "returns an error without commit message" do
      url_list = FactoryGirl.create :url_list

      post :push_repository, url_list_name: url_list.name

      expect(response).to have_http_status(400)
      expect(JSON.parse(response.body)["error"]).to eq("Commit message not specified")
    end

    it "returns an error with empty repository" do
      url_list = FactoryGirl.create :url_list

      create_bitbucket_repository url_list.name
      repository = Git.clone "git@bitbucket.org:snapsaver/#{url_list.name}.git", "repo/#{url_list.name}"
      repository.config "user.name", ENV["BITBUCKET_USER"]
      repository.config "user.email", ENV["BITBUCKET_USER"]

      begin
        post :push_repository, url_list_name: url_list.name, commit_message: ""

        expect(response).to have_http_status(400)
        expect(JSON.parse(@response.body)["error"]).to eq("No changes")
      ensure
        FileUtils.rm_rf "repo/#{url_list.name}"
        delete_bitbucket_repository url_list.name
      end
    end

    it "returns an error with a repository which has no changes from HEAD" do
      url_list = FactoryGirl.create :url_list

      create_bitbucket_repository url_list.name
      repository = Git.clone "git@bitbucket.org:snapsaver/#{url_list.name}.git", "repo/#{url_list.name}"
      repository.config "user.name", ENV["BITBUCKET_USER"]
      repository.config "user.email", ENV["BITBUCKET_USER"]

      File.open "repo/#{url_list.name}/piyo", "w" do end

      repository.add all: true
      repository.commit "this is a pen"

      begin
        post :push_repository, url_list_name: url_list.name, commit_message: ""

        expect(response).to have_http_status(400)
        expect(JSON.parse(response.body)["error"]).to eq("No changes")
      ensure
        FileUtils.rm_rf "repo/#{url_list.name}"
        delete_bitbucket_repository url_list.name
      end
    end

    it "pushes contents in repository to bitbucket without login" do
      url_list = FactoryGirl.create :url_list

      create_bitbucket_repository url_list.name
      repository = Git.clone "git@bitbucket.org:snapsaver/#{url_list.name}.git", "repo/#{url_list.name}"
      repository.config "user.name", ENV["BITBUCKET_USER"]
      repository.config "user.email", ENV["BITBUCKET_USER"]

      File.open "repo/#{url_list.name}/piyo", "w" do end

      begin
        post :push_repository, url_list_name: url_list.name, commit_message: ""

        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)["url"]).to eq("https://bitbucket.org/#{ENV["BITBUCKET_USER"]}/#{url_list.name}/commits/#{repository.gcommit("HEAD").sha}")
      ensure
        FileUtils.rm_rf "repo/#{url_list.name}"
        delete_bitbucket_repository url_list.name
      end
    end

    it "pushes contents in repository to bitbucket with login" do
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

      File.open "repo/#{user.uuid}-#{url_list.name}/piyo", "w" do end

      session["warden.user.user.session"] = {"current_url_list_name" => url_list.name}

      begin
        post :push_repository, url_list_name: url_list.name, commit_message: ""

        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)["url"]).to eq("https://bitbucket.org/#{ENV["BITBUCKET_USER"]}/#{user.uuid}-#{url_list.name}/commits/#{repository.gcommit("HEAD").sha}")
      ensure
        FileUtils.rm_rf "repo/#{user.uuid}-#{url_list.name}"
        delete_bitbucket_repository "#{user.uuid}-#{url_list.name}"
      end
    end
  end
end
