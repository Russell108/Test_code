module Joinable
  extend ActiveSupport::Concern

  included do
    has_many :memberships, :as => :joinable
  end
end