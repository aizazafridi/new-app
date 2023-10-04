class Clip < ApplicationRecord
  belongs_to :actress
  scope :newest, lambda {order("created_at DESC")}
end
