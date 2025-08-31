class Appointment < ApplicationRecord
  belongs_to :account
  belongs_to :customer
  belongs_to :service_type
  belongs_to :staff
end
