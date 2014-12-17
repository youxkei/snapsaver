require 'rails_helper'

RSpec.describe HomeController, :type => :controller do
  include InnerApiHelper

  describe "GET #home" do
    it "returns the home page without login" do
      get :home

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)
    end

    it "returns an orphan URL list page with orphan_url_list parameter without login" do
      url_list = FactoryGirl.create :url_list

      get :home, orphan_url_list_name: url_list.name

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)

      expect(assigns(:orphan_url_list)).to be_truthy
      expect(assigns(:url_list_name)).to eq(url_list.name)
      expect(assigns(:urls)).to eq(url_list.urls)
      expect(assigns(:urls_size)).to eq(url_list.urls.count("\n") + 1)
    end

    it "returns an orphan URL list page with orphan_url_list parameter even with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.urls = ""
      url_list.save

      get :home, orphan_url_list_name: url_list.name

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)

      expect(assigns(:orphan_url_list)).to be_truthy
      expect(assigns(:url_list_name)).to eq(url_list.name)
      expect(assigns(:urls)).to eq(url_list.urls)
      expect(assigns(:urls_size)).to eq(0)
    end

    it "makes a default URL list with logging in user who have no URL list, and returns the URL list page" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      get :home

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)

      expect(assigns(:orphan_url_list)).to be_falsey
      expect(assigns(:url_list_names)).to eq(["default"])
      expect(assigns(:url_list_name)).to eq("default")
      expect(assigns(:urls)).to eq("")
      expect(assigns(:urls_size)).to eq(0)

      expect(session["warden.user.user.session"]["current_url_list_name"]).to eq("default")

      expect(UrlList.count).to eq(1)
      expect(UrlList.first.name).to eq("default")
      expect(UrlList.first.urls).to eq("")

      expect(Dir.exist? "repo/#{user.uuid}-default").to be_truthy
      expect{delete_bitbucket_repository "#{user.uuid}-default"}.not_to raise_error
    end

    it "returns a first URL list page with logging in an user who have some URL lists" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list = FactoryGirl.create :url_list
      url_list.user = user
      url_list.save

      get :home

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)

      expect(session["warden.user.user.session"]["current_url_list_name"]).to eq(url_list.name)

      expect(assigns(:orphan_url_list)).to be_falsey
      expect(assigns(:url_list_names)).to eq([url_list.name])
      expect(assigns(:url_list_name)).to eq(url_list.name)
      expect(assigns(:urls)).to eq(url_list.urls)
      expect(assigns(:urls_size)).to eq(url_list.urls.count("\n") + 1)
    end

    it "returns a URL list page selected in session with logging in an user who have some URL lists" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list1 = FactoryGirl.create :url_list
      url_list1.user = user
      url_list1.save

      url_list2 = FactoryGirl.create :url_list
      url_list2.name = "piyo_list"
      url_list2.user = user
      url_list2.save

      session["warden.user.user.session"] = {"current_url_list_name" => url_list2.name}

      get :home

      expect(response).to have_http_status(200)
      expect(response).to render_template(:home)

      expect(session["warden.user.user.session"]["current_url_list_name"]).to eq(url_list2.name)

      expect(assigns(:orphan_url_list)).to be_falsey
      expect(assigns(:url_list_names)).to eq([url_list1.name, url_list2.name])
      expect(assigns(:url_list_name)).to eq(url_list2.name)
      expect(assigns(:urls)).to eq(url_list2.urls)
      expect(assigns(:urls_size)).to eq(url_list2.urls.count("\n") + 1)
    end
  end

  describe "POST #add_url_list" do
    it "returns error without login" do
      post :add_url_list

      expect(response).to have_http_status(401)
      expect(response).to render_template("error/error")

      expect(assigns(:http_status_code)).to eq(401)
      expect(assigns(:error_message)).to eq("Login required")
    end

    it "returns error without url_list_name parameter with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      post :add_url_list

      expect(response).to have_http_status(400)
      expect(response).to render_template("error/error")

      expect(assigns(:http_status_code)).to eq(400)
      expect(assigns(:error_message)).to eq("URL list not specified")
    end

    it "returns error with invalid URL list name and with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      post :add_url_list, url_list_name: "例えばこんなの"
      expect(assigns(:http_status_code)).to eq(400)
      expect(assigns(:error_message)).to eq("Invalid URL list name")
    end

    it "makes new url list and redirects to home page with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      post :add_url_list, url_list_name: "this_is_list_name"

      expect(response).to redirect_to("/")

      expect(session["warden.user.user.session"]["current_url_list_name"]).to eq("this_is_list_name")

      expect(UrlList.count).to eq(1)
      expect(UrlList.first.name).to eq("this_is_list_name")
      expect(UrlList.first.urls).to eq("")

      expect(Dir.exist? "repo/#{user.uuid}-this_is_list_name").to be_truthy
      expect{delete_bitbucket_repository "#{user.uuid}-this_is_list_name"}.not_to raise_error
    end
  end

  describe "POST #change_current_url_list" do
    it "returns error without login" do
      post :change_current_url_list

      expect(response).to have_http_status(401)
      expect(response).to render_template("error/error")

      expect(assigns(:http_status_code)).to eq(401)
      expect(assigns(:error_message)).to eq("Login required")
    end

    it "returns error without url_list_name parameter with login" do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      post :change_current_url_list

      expect(response).to have_http_status(400)
      expect(response).to render_template("error/error")

      expect(assigns(:http_status_code)).to eq(400)
      expect(assigns(:error_message)).to eq("URL list not specified")
    end

    it "changes current url list and redirects " do
      user = FactoryGirl.create :user
      user.confirm!
      sign_in user

      url_list1 = FactoryGirl.create :url_list
      url_list1.user = user
      url_list1.save

      url_list2 = FactoryGirl.create :url_list
      url_list2.name = "piyo_list"
      url_list2.user = user
      url_list2.save

      session["warden.user.user.session"] = {"current_url_list_name" => url_list1.name}

      post :change_current_url_list, url_list_name: url_list2.name

      expect(response).to redirect_to("/")

      expect(session["warden.user.user.session"]["current_url_list_name"]).to eq(url_list2.name)
    end
  end
end
