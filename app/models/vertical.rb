# frozen_string_literal: true

class Vertical < ApplicationRecord
  # Relationships
  has_many :accounts, dependent: :destroy
  has_many :service_types, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :active, inclusion: { in: [ true, false ] }

  # Scopes
  scope :active, -> { where(active: true) }

  # Vertical type checks
  def cleaning?
    slug&.match?(/cleaning/i)
  end

  def elderly_care?
    slug&.match?(/elderly_care/i)
  end

  def tutoring?
    slug&.match?(/tutoring/i)
  end

  def home_repair?
    slug&.match?(/home_repair/i)
  end

  # Compliance requirements
  def requires_compliance_tracking?
    elderly_care?
  end

  def requires_background_checks?
    elderly_care? || tutoring?
  end

  # Display helpers
  def display_name
    name.presence || slug&.titleize
  end
end
