class Staff < ApplicationRecord
  # Relationships
  belongs_to :account
  has_many :appointments, dependent: :destroy

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true
  validates :home_latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :home_longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :max_travel_radius_km, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :background_checked, -> { where(background_check_passed: true) }
  scope :not_background_checked, -> { where(background_check_passed: false) }
  scope :with_home_location, -> { where.not(home_latitude: nil, home_longitude: nil) }
  scope :available_for_radius, ->(km) { where("max_travel_radius_km >= ?", km) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def has_home_location?
    home_latitude.present? && home_longitude.present?
  end

  def home_coordinates
    return nil unless has_home_location?
    { lat: home_latitude.to_f, lng: home_longitude.to_f }
  end

  def can_travel_to?(distance_km)
    return true if max_travel_radius_km.nil?
    distance_km <= max_travel_radius_km
  end

  def eligible_for_service?(service_type)
    return true unless service_type.requires_background_check?
    background_check_passed?
  end
end
