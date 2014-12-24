require "securerandom"
require "digest/sha2"

class User < ActiveRecord::Base
  has_many :url_lists, inverse_of: :user

  before_create do
    self.uuid = SecureRandom.uuid
    self.api_key = Digest::SHA512.hexdigest(SecureRandom.uuid)
  end

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable
end
