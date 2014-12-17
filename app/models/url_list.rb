class UrlList < ActiveRecord::Base
  belongs_to :user, inverse_of: :url_lists
end
