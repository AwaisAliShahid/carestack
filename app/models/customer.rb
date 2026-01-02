class Customer < ApplicationRecord
  # Relationships
  belongs_to :account
  has_many :appointments, dependent: :destroy

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true

  # Scopes
  scope :with_location, -> { where.not(latitude: nil, longitude: nil) }
  scope :without_location, -> { where(latitude: nil).or(where(longitude: nil)) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def has_location?
    latitude.present? && longitude.present?
  end

  def location_coordinates
    return nil unless has_location?
    { lat: latitude.to_f, lng: longitude.to_f }
  end
end
