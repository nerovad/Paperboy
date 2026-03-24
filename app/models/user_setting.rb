class UserSetting < ApplicationRecord
  validates :employee_id, presence: true, uniqueness: true
end
