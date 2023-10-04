class Actress < ApplicationRecord
  has_many :clips

  def full_name
    "#{first_name} #{last_name}"
  end

  #scopes
  scope :newest, lambda {order("created_at DESC")}

end
