class Vertical < ApplicationRecord
  # Relationships
  has_many :accounts, dependent: :destroy
  has_many :service_types, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }

  # Scopes
  scope :active, -> { where(active: true) }

  # Constants for supported verticals
  SUPPORTED_VERTICALS = %w[
    cleaning
    elderly_care
    tutoring
    home_repair
  ].freeze

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  before_create :set_active_default

  # Instance methods
  def display_name
    name.titleize
  end

  def cleaning?
    slug.include?('cleaning')
  end

  def elderly_care?
    slug.include?('elderly_care')
  end

  def requires_compliance_tracking?
    elderly_care?
  end

  def requires_background_checks?
    elderly_care? || %w[tutoring home_repair].include?(slug)
  end

  private

  def generate_slug
    self.slug = name.downcase.gsub(/[^a-z0-9]+/, '_')
  end

  def set_active_default
    self.active = true if active.nil?
  end
end